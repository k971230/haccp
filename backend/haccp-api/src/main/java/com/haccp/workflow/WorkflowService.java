/**
 * WorkflowService — 결재선·업체 양식/점검항목·작성주기 업무 로직.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 관리 화면 고정 입력 계약·양식 내보내기/불러오기·스마트일지 매핑을 SP 호출로 조정한다
 *   2) 요청 본문의 회사·사용자 값은 받지 않고 JWT 컨텍스트의 테넌트와 작업자만 사용한다
 *   3) 결재선·작성주기 삭제는 validate-delete와 delete에서 같은 검증을 두 번 수행한다
 *
 * PIPELINE[HB91] 워크플로 관리 Service
 * PIPELINE[HB88, HB92, HB90] 연관 모듈
 */
package com.haccp.workflow;

// 역할 — JSON 변환
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
// 역할 — JWT 로그인 정보·업무 예외·삭제 공통 검증
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
import com.haccp.common.validation.DeleteValidation;
// 역할 — 템플릿 볼륨 저장·한글 파일명 규칙 (S3 교체 시 Storage만 교체)
import com.haccp.doc.TemplateFileNames;
import com.haccp.doc.TemplateFileStorage;
import com.haccp.workflow.dto.WorkflowDeleteItem;
// 역할 — 컬렉션·시각 채번
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
// 역할 — Spring 서비스·트랜잭션
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
@RequiredArgsConstructor
public class WorkflowService {
    private final WorkflowMapper mapper;
    private final ObjectMapper objectMapper;
    // 템플릿 볼륨 — 자사 업로드가 문서 첨부 트리와 섞이지 않게 경계를 둔다
    private final TemplateFileStorage templateFileStorage;

    public List<Map<String, Object>> approvalLines() {
        List<Map<String, Object>> rows = new ArrayList<>();
        for (String payload : mapper.selectApprovalLines(LoginUserContext.coCd())) {
            rows.add(readJson(payload));
        }
        return rows;
    }

    @Transactional
    public void saveApprovalLine(Map<String, Object> row) {
        requireText(row, "apprLineCd", "결재선 코드를 입력하세요.");
        requireText(row, "apprLineNm", "결재선명을 입력하세요.");
        mapper.saveApprovalLine(LoginUserContext.coCd(), writeJson(row), LoginUserContext.userId());
    }

    public void validateApprovalLineDelete(List<WorkflowDeleteItem> keys) {
        assertApprovalLinesDeletable(LoginUserContext.coCd(), keys);
    }

    @Transactional
    public void deleteApprovalLines(List<WorkflowDeleteItem> keys) {
        String coCd = LoginUserContext.coCd();
        assertApprovalLinesDeletable(coCd, keys);
        for (WorkflowDeleteItem key : keys) {
            mapper.deleteApprovalLine(coCd, key.getApprLineCd(), LoginUserContext.userId());
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 업체 사용양식 목록을 조회한다
     *   2) 관리 화면 콤보·설정 패널이 진입 시 호출한다
     *   3) SP 컬럼명(snake_case)을 API 계약 camelCase로 바꿔 반환한다
     */
    public List<Map<String, Object>> templates() {
        return toCamelMaps(mapper.selectTemplates(LoginUserContext.coCd()));
    }

    @Transactional
    public void saveTemplate(Map<String, Object> row) {
        String tmplCd = requireText(row, "tmplCd", "양식 코드를 선택하세요.");
        mapper.saveCompanyTemplate(
                LoginUserContext.coCd(), tmplCd, text(row.get("tmplNmOvr")), text(row.get("apprLineCd")),
                text(row.get("cycleCd")), integer(row.get("retentionMonth")), defaultYn(row.get("useYn")),
                LoginUserContext.userId()
        );
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) 법적서류 업로드 유형을 신규 등록하거나 회사 표시명을 수정한다
     *   2) legal-document-upload 좌측 그리드 저장이 호출한다
     *   3) 카탈로그에 없는 코드만 신규 LAW 유형을 만들고, 있으면 명칭 오버라이드만 업서트한다
     */
    @Transactional
    public void saveLegalType(Map<String, Object> row) {
        String tmplCd = requireText(row, "tmplCd", "양식 코드를 입력하세요.");
        String tmplNm = requireText(row, "tmplNm", "양식 명칭을 입력하세요.");
        String coCd = LoginUserContext.coCd();
        String userId = LoginUserContext.userId();
        // 전역 카탈로그에 없을 때(= 회사 전용 신규 유형) SP로 카탈로그+company_template 생성
        if (mapper.countTemplateCatalog(tmplCd) <= 0) {
            mapper.createLegalType(coCd, tmplCd, tmplNm, userId);
            return;
        }
        // 이미 있는 코드 — 회사 사용분 명칭만 갱신(시스템 유형 포함)
        mapper.saveCompanyTemplate(
                coCd, tmplCd, tmplNm, "", "", null, "Y", userId
        );
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) 회사 사용양식 삭제 가능 여부만 검사한다
     *   2) 사용양식관리 삭제 확인창 직전에 호출한다
     *   3) 문서 참조·시스템 배포분(sys_yn=Y)이면 BizException
     */
    public void validateCompanyTemplateDelete(List<WorkflowDeleteItem> keys) {
        assertCompanyTemplatesDeletable(LoginUserContext.coCd(), keys);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) validate와 같은 assertDeletable을 다시 수행한 뒤 삭제 SP를 루프 호출한다
     *   2) 사용양식관리 삭제 확인 후 호출한다
     *   3) All-or-Nothing — 한 건이라도 차단이면 트랜잭션 롤백
     */
    @Transactional
    public void deleteCompanyTemplates(List<WorkflowDeleteItem> keys) {
        String coCd = LoginUserContext.coCd();
        assertCompanyTemplatesDeletable(coCd, keys);
        for (WorkflowDeleteItem key : keys) {
            mapper.deleteCompanyTemplate(coCd, key.getTmplCd().trim(), LoginUserContext.userId());
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) 업로드 HWP를 _template/{coCd}/{한글파일명}에 두고 company_template(sys_yn=N)에 연결한다
     *   2) 사용양식관리 「신규」업로드가 호출한다 — 파일명은 원본 한글명을 쓰고 번호 접두만 제거한다
     *   3) 성공 시 저장된 상대 form_path — DB에는 경로만, 바이너리는 볼륨
     */
    @Transactional
    public Map<String, Object> createCompanyTemplateCustom(
            // 기준 표준 양식 코드 — 카탈로그에 있어야 한다
            String tmplCd,
            // 표시명 오버라이드 — 공백이면 표준명 유지
            String tmplNmOvr,
            // 브라우저가 올린 HWP/HWPX — 원본 파일명 사용
            MultipartFile file
    ) {
        String code = requireText(tmplCd, "기준 양식 코드를 선택하세요.");
        if (file == null || file.isEmpty()) {
            throw new BizException("업로드할 양식 파일을 선택하세요.");
        }
        String coCd = LoginUserContext.coCd();
        String safeName = TemplateFileNames.safeTemplateFileName(file.getOriginalFilename());
        String formPath = TemplateFileNames.relativeFormPath(
                templateFileStorage.templateDirectory(), coCd, safeName
        );
        // 볼륨에 먼저 쓰고 DB 메타를 맞춘다 — 실패 시 트랜잭션 롤백(고아 파일은 운영 정리)
        templateFileStorage.create(formPath, file);
        mapper.createCompanyTemplateCustom(
                coCd, code, text(tmplNmOvr), formPath, LoginUserContext.userId()
        );
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("tmplCd", code);
        out.put("formPath", formPath);
        out.put("formFileNm", safeName);
        out.put("sysYn", "usr");
        return out;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 선택한 양식의 표준·업체 오버라이드 점검항목을 조회한다
     *   2) 사용양식·점검항목 관리 화면이 양식 선택 시 호출한다
     *   3) itemNm·itemNmOvr 등 camelCase로 변환해 긴 표준 문구가 화면에 보이도록 한다
     */
    public List<Map<String, Object>> checkItems(String tmplCd) {
        return toCamelMaps(mapper.selectCheckItems(LoginUserContext.coCd(), requireText(tmplCd, "양식 코드를 선택하세요.")));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) 표준 오버라이드 또는 회사 전용(CUST*) 점검항목을 업서트한다
     *   2) itemCd가 비었을 때(= 신규 행) CUSTyyyyMMddHHmmss 를 서버에서 채번한다
     *   3) CUST*는 업체 문구(itemNmOvr)가 필수이며 실패 시 BizException
     */
    @Transactional
    public void saveCheckItem(Map<String, Object> row) {
        String tmplCd = requireText(row, "tmplCd", "양식 코드를 선택하세요.");
        String itemCd = text(row.get("itemCd"));
        // 신규 행일 때(= 코드 없음·NEW 자리) 서버 채번 — 하드코딩 목록 금지
        if (itemCd.isBlank() || "NEW".equalsIgnoreCase(itemCd)) {
            itemCd = "CUST" + LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMddHHmmss"));
            row.put("itemCd", itemCd);
        }
        String itemNmOvr = text(row.get("itemNmOvr"));
        // 업체 문구가 비고 표준 문구가 있을 때(= 오버라이드 미입력) itemNm을 문구로 쓸 수 있게 한다
        if (itemNmOvr.isBlank() && itemCd.startsWith("CUST")) {
            itemNmOvr = text(row.get("itemNm"));
        }
        mapper.saveCheckItem(
                LoginUserContext.coCd(), tmplCd, itemCd, itemNmOvr,
                integer(row.get("sortNo")), defaultYn(row.get("useYn")), LoginUserContext.userId()
        );
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) 점검항목 삭제 키([{tmplCd,itemCd}])만 검사한다
     *   2) 문서별 admin 삭제 확인창 직전에 호출한다
     *   3) 표준 항목·미존재 CUST면 BizException
     */
    public void validateCheckItemDelete(List<WorkflowDeleteItem> keys) {
        assertCheckItemsDeletable(LoginUserContext.coCd(), keys);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) validate와 같은 assertDeletable을 다시 수행한 뒤 삭제 SP를 루프 호출한다
     *   2) 문서별 admin 삭제 확인 후 호출한다
     *   3) CUST*만 물리 삭제 — 표준은 SP·Service 양쪽에서 차단
     */
    @Transactional
    public void deleteCheckItems(List<WorkflowDeleteItem> keys) {
        String coCd = LoginUserContext.coCd();
        assertCheckItemsDeletable(coCd, keys);
        for (WorkflowDeleteItem key : keys) {
            mapper.deleteCheckItem(coCd, key.getTmplCd(), key.getItemCd(), LoginUserContext.userId());
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) 삭제 키·CUST 접두·회사 행 존재를 검증한다
     *   2) validate-delete와 delete에서 동일하게 호출한다
     *   3) 표준 항목이면 숨김 안내 BizException
     */
    private void assertCheckItemsDeletable(String coCd, List<WorkflowDeleteItem> keys) {
        DeleteValidation.requireItems(keys, "삭제할 점검항목을 선택하세요.");
        for (WorkflowDeleteItem key : keys) {
            if (key == null) {
                throw new BizException("삭제할 점검항목 키가 올바르지 않습니다.");
            }
            String tmplCd = text(key.getTmplCd());
            String itemCd = text(key.getItemCd());
            if (tmplCd.isBlank() || itemCd.isBlank()) {
                throw new BizException("삭제할 점검항목 키가 올바르지 않습니다.");
            }
            key.setTmplCd(tmplCd);
            key.setItemCd(itemCd);
            if (!itemCd.startsWith("CUST")) {
                throw new BizException("표준 점검항목은 삭제할 수 없습니다. 표시를 숨김으로 변경하세요.");
            }
            if (mapper.countCompanyCheckItem(coCd, tmplCd, itemCd) <= 0) {
                throw new BizException("삭제할 점검항목을 찾을 수 없습니다.");
            }
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 선택한 기본 양식에서 파생한 자사 양식 목록과 작성 활성 상태를 조회한다
     *   2) 사용양식 관리 하단 자사 양식 그리드가 양식 선택 시 호출한다
     *   3) 회사코드는 JWT로 고정하고 플랫폼 기본 양식 데이터는 반환만 하며 수정하지 않는다
     */
    public List<Map<String, Object>> companyForms(String tmplCd) {
        return toCamelMaps(mapper.selectCompanyForms(
                LoginUserContext.coCd(), requireText(tmplCd, "양식 코드를 선택하세요.")
        ));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 자사 양식 복제본의 독립 점검항목을 조회한다
     *   2) coFormIdx가 0 이하일 때(= 선택 자사 양식 없음) 업무 예외를 발생시킨다
     *   3) 기본 tbl_check_item과 섞지 않아 기본 양식 불변 규칙을 지킨다
     */
    public List<Map<String, Object>> companyFormItems(Long coFormIdx) {
        return toCamelMaps(mapper.selectCompanyFormItems(
                LoginUserContext.coCd(), positive(coFormIdx, "자사 양식을 선택하세요.")
        ));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 선택한 플랫폼 기본 양식과 점검항목을 새 자사 양식으로 스냅샷 복제한다
     *   2) 사용양식 관리의 자사 양식 추가 버튼에서만 호출한다
     *   3) 복제 실패 시 저장프로시저의 업무 예외를 사용자 문구로 전파한다
     */
    @Transactional
    public void cloneCompanyForm(Map<String, Object> row) {
        mapper.cloneCompanyForm(
                LoginUserContext.coCd(),
                requireText(row, "tmplCd", "복제할 기본 양식을 선택하세요."),
                text(row == null ? null : row.get("formNm")),
                LoginUserContext.userId()
        );
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 자사 양식 점검항목을 저장하며 기본 양식 항목 저장 경로와 분리한다
     *   2) coFormIdx가 선택된 업체 복제본일 때만 JSON payload를 저장프로시저에 전달한다
     *   3) 기본 양식의 표준 문구·구조는 이 메서드에서 변경할 수 없다
     */
    @Transactional
    public void saveCompanyFormItem(Map<String, Object> row) {
        Long coFormIdx = positive(longValue(row == null ? null : row.get("coFormIdx")), "자사 양식을 선택하세요.");
        mapper.saveCompanyFormItem(
                LoginUserContext.coCd(), coFormIdx, writeJson(row), LoginUserContext.userId()
        );
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 기본 양식 또는 지정 자사 양식을 신규 문서 작성 원본으로 전환한다
     *   2) coFormIdx가 null일 때(= 기본 양식 사용) 자사 복제본은 보존하고 활성만 해제한다
     *   3) 저장프로시저가 선택 자사본의 회사·원본 양식 일치 여부를 다시 검증한다
     */
    @Transactional
    public void activateCompanyForm(Map<String, Object> row) {
        mapper.activateCompanyForm(
                LoginUserContext.coCd(),
                requireText(row, "tmplCd", "양식 코드를 선택하세요."),
                longValue(row == null ? null : row.get("coFormIdx")),
                LoginUserContext.userId()
        );
    }

    // STEP 20 / G-14: smart-diary Service 경로 제거 (Controller·Mapper 동시 폐기)

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 회사별 양식 설정 내보내기 이력 목록을 조회한다
     *   2) 불러오기 팝업이 docKind 조건으로 호출한다
     *   3) payload 본문은 목록에서 제외하고 메타만 camelCase로 반환한다
     */
    public List<Map<String, Object>> templateExportHist(String docKind) {
        return toCamelMaps(mapper.selectTemplateExportHist(LoginUserContext.coCd(), text(docKind)));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 내보내기 이력 단건과 payload JSON을 조회한다
     *   2) 불러오기 전 미리보기·검증이 필요할 때 호출한다
     *   3) 타사·없는 idx일 때(= 조회 0건) 업무 예외를 발생시킨다
     */
    public Map<String, Object> templateExportHistOne(Long idx) {
        Map<String, Object> row = toCamelMap(mapper.selectTemplateExportHistOne(
                LoginUserContext.coCd(), positive(idx, "내보내기 이력을 선택하세요.")
        ));
        if (row == null || row.isEmpty()) {
            throw new BizException("내보내기 이력을 찾을 수 없습니다.");
        }
        Object payload = row.get("payload");
        if (payload instanceof String payloadText && !payloadText.isBlank()) {
            row.put("payload", readJsonObject(payloadText));
        }
        return row;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 현재 회사의 사용양식·점검항목 오버라이드를 JSON 패키지로 이력에 저장한다
     *   2) DB/HWP 설정 화면의 내보내기 버튼이 packNm·docKind로 호출한다
     *   3) 동일 트랜잭션에서 스냅샷을 만들고 이력 idx를 반환한다
     */
    @Transactional
    public Long exportTemplateHist(Map<String, Object> body) {
        String packNm = requireText(body, "packNm", "패키지명을 입력하세요.");
        String docKind = requireText(body, "docKind", "문서 유형(DB/HWP)을 선택하세요.").toUpperCase();
        String remk = text(body == null ? null : body.get("remk"));
        String coCd = LoginUserContext.coCd();

        List<Map<String, Object>> templates = new ArrayList<>();
        List<Map<String, Object>> checkItems = new ArrayList<>();
        for (Map<String, Object> tmpl : toCamelMaps(mapper.selectTemplates(coCd))) {
            if (!docKind.equalsIgnoreCase(text(tmpl.get("docKind")))) continue;
            String tmplCd = text(tmpl.get("tmplCd"));
            if (tmplCd.isBlank()) continue;
            Map<String, Object> tmplSnap = new LinkedHashMap<>();
            tmplSnap.put("tmplCd", tmplCd);
            // 조회 SP는 표준명 결합값만 주므로 표시명 오버라이드는 비워 표준명을 유지한다
            tmplSnap.put("tmplNmOvr", null);
            tmplSnap.put("apprLineCd", tmpl.get("apprLineCd"));
            tmplSnap.put("cycleCd", tmpl.get("cycleCd"));
            tmplSnap.put("retentionMonth", tmpl.get("retentionMonth"));
            tmplSnap.put("useYn", defaultYn(tmpl.get("useYn")));
            templates.add(tmplSnap);
            for (Map<String, Object> item : toCamelMaps(mapper.selectCheckItems(coCd, tmplCd))) {
                Map<String, Object> itemSnap = new LinkedHashMap<>();
                itemSnap.put("tmplCd", tmplCd);
                itemSnap.put("itemCd", item.get("itemCd"));
                itemSnap.put("itemNmOvr", item.get("itemNmOvr"));
                itemSnap.put("sortNo", item.get("sortNo"));
                itemSnap.put("useYn", defaultYn(item.get("useYn")));
                checkItems.add(itemSnap);
            }
        }

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("docKind", docKind);
        payload.put("templates", templates);
        payload.put("checkItems", checkItems);

        Long histIdx = mapper.insertTemplateExportHist(
                coCd, packNm, docKind, writeJson(payload), null, remk, LoginUserContext.userId()
        );
        if (histIdx == null || histIdx <= 0) {
            throw new BizException("양식 설정을 내보내지 못했습니다.");
        }
        return histIdx;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 서버 표준 또는 내보내기 이력으로 회사 오버라이드를 All-or-Nothing 복원한다
     *   2) 불러오기 팝업에서 source=SERVER 또는 histIdx를 선택해 호출한다
     *   3) 한 건이라도 실패하면 트랜잭션 롤백으로 부분 적용을 막는다
     */
    @Transactional
    public void importTemplateHist(Map<String, Object> body) {
        if (body == null || body.isEmpty()) {
            throw new BizException("불러올 대상을 선택하세요.");
        }
        String source = text(body.get("source")).toUpperCase();
        Long histIdx = longValue(body.get("histIdx"));
        String docKindFilter = text(body.get("docKind")).toUpperCase();

        if ("SERVER".equals(source)) {
            restoreServerOverlays(docKindFilter.isBlank() ? "DB" : docKindFilter);
            return;
        }
        if (histIdx == null) {
            throw new BizException("불러올 이력 또는 서버 템플릿을 선택하세요.");
        }
        Map<String, Object> hist = templateExportHistOne(histIdx);
        Object payloadObj = hist.get("payload");
        if (!(payloadObj instanceof Map<?, ?> rawPayload)) {
            throw new BizException("이력 설정 본문이 올바르지 않습니다.");
        }
        @SuppressWarnings("unchecked")
        Map<String, Object> payload = (Map<String, Object>) rawPayload;
        applyOverlayPayload(payload);
    }

    /** 서버 표준 — 선택 docKind 양식의 업체 오버라이드를 표준값으로 되돌린다 */
    private void restoreServerOverlays(String docKind) {
        String coCd = LoginUserContext.coCd();
        String userId = LoginUserContext.userId();
        for (Map<String, Object> tmpl : toCamelMaps(mapper.selectTemplates(coCd))) {
            if (!docKind.equalsIgnoreCase(text(tmpl.get("docKind")))) continue;
            String tmplCd = text(tmpl.get("tmplCd"));
            if (tmplCd.isBlank()) continue;
            // 표시명·결재선·주기·보존은 표준 기본으로, 사용여부는 유지
            mapper.saveCompanyTemplate(
                    coCd, tmplCd, null, null, null, null, defaultYn(tmpl.get("useYn")), userId
            );
            for (Map<String, Object> item : toCamelMaps(mapper.selectCheckItems(coCd, tmplCd))) {
                String itemCd = text(item.get("itemCd"));
                if (itemCd.isBlank()) continue;
                mapper.saveCheckItem(coCd, tmplCd, itemCd, null, null, "Y", userId);
            }
        }
    }

    /** 이력 payload의 templates·checkItems를 순차 업서트한다 */
    private void applyOverlayPayload(Map<String, Object> payload) {
        String coCd = LoginUserContext.coCd();
        String userId = LoginUserContext.userId();
        Object templatesObj = payload.get("templates");
        if (templatesObj instanceof List<?> templates) {
            for (Object one : templates) {
                if (!(one instanceof Map<?, ?> raw)) continue;
                @SuppressWarnings("unchecked")
                Map<String, Object> row = (Map<String, Object>) raw;
                String tmplCd = text(row.get("tmplCd"));
                if (tmplCd.isBlank()) continue;
                mapper.saveCompanyTemplate(
                        coCd, tmplCd, text(row.get("tmplNmOvr")), text(row.get("apprLineCd")),
                        text(row.get("cycleCd")), integer(row.get("retentionMonth")),
                        defaultYn(row.get("useYn")), userId
                );
            }
        }
        Object itemsObj = payload.get("checkItems");
        if (itemsObj instanceof List<?> items) {
            for (Object one : items) {
                if (!(one instanceof Map<?, ?> raw)) continue;
                @SuppressWarnings("unchecked")
                Map<String, Object> row = (Map<String, Object>) raw;
                String tmplCd = text(row.get("tmplCd"));
                String itemCd = text(row.get("itemCd"));
                if (tmplCd.isBlank() || itemCd.isBlank()) continue;
                mapper.saveCheckItem(
                        coCd, tmplCd, itemCd, text(row.get("itemNmOvr")),
                        integer(row.get("sortNo")), defaultYn(row.get("useYn")), userId
                );
            }
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 작성주기 규칙을 조회한다
     *   2) 작성주기 관리 화면이 목록을 그릴 때 호출한다
     *   3) SP 컬럼명을 camelCase로 변환한다
     */
    public List<Map<String, Object>> scheduleRules() {
        return toCamelMaps(mapper.selectScheduleRules(LoginUserContext.coCd()));
    }

    @Transactional
    public void saveScheduleRule(Map<String, Object> row) {
        requireText(row, "tmplCd", "양식 코드를 선택하세요.");
        requireText(row, "cycleCd", "작성주기를 선택하세요.");
        mapper.saveScheduleRule(LoginUserContext.coCd(), writeJson(row), LoginUserContext.userId());
    }

    public void validateScheduleRuleDelete(List<WorkflowDeleteItem> keys) {
        normalizeScheduleKeys(keys);
    }

    @Transactional
    public void deleteScheduleRules(List<WorkflowDeleteItem> keys) {
        normalizeScheduleKeys(keys);
        for (WorkflowDeleteItem key : keys) {
            mapper.deleteScheduleRule(LoginUserContext.coCd(), key.getIdx(), LoginUserContext.userId());
        }
    }

    private void assertApprovalLinesDeletable(String coCd, List<WorkflowDeleteItem> keys) {
        DeleteValidation.requireItems(keys, "삭제할 결재선을 선택하세요.");
        for (WorkflowDeleteItem key : keys) {
            if (key == null || text(key.getApprLineCd()).isBlank()) {
                throw new BizException("삭제할 결재선 코드가 올바르지 않습니다.");
            }
            Map<String, Object> blocker = mapper.selectApprovalLineBlocker(coCd, key.getApprLineCd().trim());
            if (blocker != null) {
                throw new BizException("선택한 결재선 '" + key.getApprLineCd().trim() + "'이(가) 사용양식 또는 문서에서 참조 중이므로 삭제할 수 없습니다.");
            }
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) 회사 양식 삭제 키·문서 참조·시스템분(sys_yn)을 검증한다
     *   2) validate-delete와 delete에서 동일하게 호출한다
     *   3) 차단이면 BizException — 시스템분은 SP 삭제 전에도 목록으로 선차단
     */
    private void assertCompanyTemplatesDeletable(String coCd, List<WorkflowDeleteItem> keys) {
        DeleteValidation.requireItems(keys, "삭제할 양식을 선택하세요.");
        List<Map<String, Object>> keyMaps = new ArrayList<>();
        for (WorkflowDeleteItem key : keys) {
            if (key == null || text(key.getTmplCd()).isBlank()) {
                throw new BizException("삭제할 양식 코드가 올바르지 않습니다.");
            }
            String tmplCd = key.getTmplCd().trim();
            key.setTmplCd(tmplCd);
            Map<String, Object> one = new LinkedHashMap<>();
            one.put("tmplCd", tmplCd);
            keyMaps.add(one);
        }
        // 시스템 배포분(sys_yn=Y) — 테이블 단건 확인 후 삭제 차단
        for (WorkflowDeleteItem key : keys) {
            String tmplCd = key.getTmplCd();
            String sysYn = mapper.selectCompanyTemplateSysYn(coCd, tmplCd);
            if (sysYn == null || sysYn.isBlank()) {
                throw new BizException("삭제할 양식을 찾을 수 없습니다.");
            }
            // sys / Y = 시스템 배포분 — 삭제 차단 (usr / N 만 삭제)
            String flag = sysYn.trim();
            if ("Y".equalsIgnoreCase(flag) || "sys".equalsIgnoreCase(flag)) {
                throw new BizException("시스템 배포 양식은 삭제할 수 없습니다.");
            }
        }
        String keysJson = writeJsonList(keyMaps);
        List<Map<String, Object>> blockers = mapper.selectCompanyTemplateDeleteBlockers(coCd, keysJson);
        if (blockers != null && !blockers.isEmpty()) {
            Map<String, Object> first = toCamelMap(blockers.get(0));
            throw new BizException(DeleteValidation.referenced(
                    "양식",
                    text(first.get("tmplCd")).isBlank() ? text(first.get("label")) : text(first.get("tmplCd")),
                    text(first.get("target")).isBlank() ? "문서" : text(first.get("target"))
            ));
        }
    }

    /** 삭제 키 배열 JSON — blocker SP jsonb 바인딩 */
    private String writeJsonList(List<Map<String, Object>> rows) {
        try {
            return objectMapper.writeValueAsString(rows);
        } catch (Exception e) {
            throw new BizException("삭제 검증 키를 변환하지 못했습니다.");
        }
    }

    private void normalizeScheduleKeys(List<WorkflowDeleteItem> keys) {
        DeleteValidation.requireItems(keys, "삭제할 작성주기를 선택하세요.");
        for (WorkflowDeleteItem key : keys) {
            if (key == null) throw new BizException("삭제할 작성주기 키가 올바르지 않습니다.");
            key.setIdx(DeleteValidation.requirePositive(key.getIdx(), "삭제할 작성주기 키가 올바르지 않습니다."));
        }
    }

    private Map<String, Object> readJson(String payload) {
        try {
            return objectMapper.readValue(payload, new TypeReference<LinkedHashMap<String, Object>>() {});
        } catch (Exception e) {
            throw new BizException("결재선 조회 결과를 변환하지 못했습니다.");
        }
    }

    /** 내보내기 이력 payload JSON 문자열 → Map — 실패 시 업무 문구 */
    private Map<String, Object> readJsonObject(String payload) {
        try {
            return objectMapper.readValue(payload, new TypeReference<LinkedHashMap<String, Object>>() {});
        } catch (Exception e) {
            throw new BizException("내보내기 설정 본문을 변환하지 못했습니다.");
        }
    }

    private String writeJson(Map<String, Object> row) {
        if (row == null) throw new BizException("저장할 데이터가 없습니다.");
        try {
            return objectMapper.writeValueAsString(row);
        } catch (Exception e) {
            throw new BizException("저장 데이터를 변환하지 못했습니다.");
        }
    }

    private String requireText(Map<String, Object> row, String key, String message) {
        if (row == null) throw new BizException(message);
        return requireText(text(row.get(key)), message);
    }

    private String requireText(String value, String message) {
        if (text(value).isBlank()) throw new BizException(message);
        return value.trim();
    }

    private Integer integer(Object value) {
        if (value == null || text(value).isBlank()) return null;
        try {
            return Integer.valueOf(text(value));
        } catch (NumberFormatException e) {
            throw new BizException("숫자 입력값이 올바르지 않습니다.");
        }
    }

    /** 숫자 키 — null이면 기본 양식 전환처럼 값 없음으로 유지하고 양수만 유효 키로 허용한다 */
    private Long longValue(Object value) {
        if (value == null || text(value).isBlank()) return null;
        try {
            return Long.valueOf(text(value));
        } catch (NumberFormatException e) {
            throw new BizException("선택한 자사 양식 키가 올바르지 않습니다.");
        }
    }

    /** 양수 대리키 — 0 이하일 때(= DB 대상 미선택) 업무 문구로 차단한다 */
    private Long positive(Long value, String message) {
        if (value == null || value <= 0) throw new BizException(message);
        return value;
    }

    private String defaultYn(Object value) {
        String yn = text(value).toUpperCase();
        return yn.isBlank() ? "Y" : yn;
    }

    private String text(Object value) {
        return value == null ? "" : String.valueOf(value).trim();
    }

    /** SP Map 결과의 snake_case 키를 API camelCase로 일괄 변환한다 */
    private List<Map<String, Object>> toCamelMaps(List<Map<String, Object>> rows) {
        List<Map<String, Object>> out = new ArrayList<>();
        if (rows == null) return out;
        for (Map<String, Object> row : rows) out.add(toCamelMap(row));
        return out;
    }

    private Map<String, Object> toCamelMap(Map<String, Object> row) {
        Map<String, Object> out = new LinkedHashMap<>();
        if (row == null) return out;
        for (Map.Entry<String, Object> entry : row.entrySet()) {
            out.put(toCamelKey(entry.getKey()), entry.getValue());
        }
        return out;
    }

    /** tmpl_cd → tmplCd, item_nm_ovr → itemNmOvr */
    private String toCamelKey(String key) {
        if (key == null || key.isBlank() || !key.contains("_")) return key;
        StringBuilder sb = new StringBuilder();
        boolean upper = false;
        for (int i = 0; i < key.length(); i++) {
            char ch = key.charAt(i);
            if (ch == '_') {
                upper = true;
                continue;
            }
            sb.append(upper ? Character.toUpperCase(ch) : ch);
            upper = false;
        }
        return sb.toString();
    }
}
