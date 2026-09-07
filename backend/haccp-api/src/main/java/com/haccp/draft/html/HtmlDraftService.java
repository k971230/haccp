/**
 * HtmlDraftService — HTML 작성 2화면(일반위생·공정점검 · CCP 검증점검) 공통 업무.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 두 화면은 업무 규칙이 같고 **양식군(Family)만** 다르다.
 *      쪼개 두었을 때 이름을 치환하면 224줄 중 17줄만 달랐다 — 그 17줄도 주석과 상수 둘뿐이다.
 *      복제해 두면 한 곳을 고칠 때 다른 하나가 조용히 어긋난다
 *      (`CcpLogDraftControllerBase` 가 포장·가열에 같은 이유로 먼저 적용한 규칙이다)
 *   2) 저장은 전송 전이라 필수값을 보지 않는다. 필수값은 전송(REQUEST) 직전에 화면이 검사한다
 *   3) validate-delete 와 delete 모두 assertDeletable Double Check — 전송·결재완료는 차단
 *
 * 전송·전송취소는 이 서비스가 아니라 문서 허브 결재 API(sp_tbl_document_approval_c_000)를 그대로 쓴다.
 *
 * PIPELINE[HB135] HTML 작성 공통 Service
 * PIPELINE[HB137] 연관 모듈
 */
package com.haccp.draft.html;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
import com.haccp.draft.DraftSeenGuard;
import com.haccp.draft.DraftSupport;
import com.haccp.draft.dto.DraftDeleteItem;
import com.haccp.draft.dto.DraftFormRow;
import com.haccp.draft.dto.DraftListRow;
import com.haccp.draft.dto.DraftSaveRequest;
import com.haccp.draft.dto.HtmlFormDraftDetail;
import com.haccp.flow.ca.DocCorrectiveSupport;
import com.haccp.sys.logs.auditlog.AuditWriter;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class HtmlDraftService {

    /**
     * 양식군 — 화면이 하나만 고른다.
     *
     * key 는 XML `<choose>` 가 보는 값이고, prefix·std 는 이 계열의 자사 양식 범위다.
     * 새 계열이 생기면 여기 한 줄과 XML 가지 하나만 늘린다.
     */
    public enum Family {
        /** 일반위생·공정점검 — sp_tbl_hyg_process_* */
        HYG("hyg", "html_hyg_prc_", "html_hyg_prc_000"),
        /** CCP 검증점검 — sp_ccp_verify_* */
        CHK("chk", "html_ccp_chk_", "html_ccp_chk_000");

        private final String key;
        private final String prefix;
        private final String std;

        Family(String key, String prefix, String std) {
            this.key = key;
            this.prefix = prefix;
            this.std = std;
        }

        /** XML choose 가 보는 값 */
        public String key() {
            return key;
        }

        /** 자사 양식 접두 — 이 화면이 다루는 범위 */
        public String prefix() {
            return prefix;
        }

        /** 계열 예시 양식코드 — 목록 SP 가 이 값으로 버전 표를 가른다 */
        public String std() {
            return std;
        }
    }

    private final HtmlDraftMapper mapper;
    private final ObjectMapper objectMapper;
    private final DocCorrectiveSupport correctiveSupport;
    // 작성 저장·삭제 이력 — 이탈 자동생성·서명 스냅샷은 같은 저장의 부수라 따로 안 남긴다
    private final AuditWriter auditWriter;
    // 초안 동시 저장 스탬프 — 상세에 붙이고 저장 직전에 대조한다
    private final DraftSeenGuard seenGuard;

    /** 감사 로그 대상 표 — 헤더. 본문 표는 남기지 않는다 */
    private static final String AUDIT_TBL = "tbl_document";

    /**
     * 개발자: 박승우
     * 일자: 2026-09-03
     * 코멘트:
     *   1) 작성에 쓸 수 있는 자사 양식(사용여부 예)만 반환한다
     *   2) 화면 진입 시 한 번 호출한다
     *   3) 없으면 빈 목록 — 화면이 양식관리 등록을 안내한다
     */
    public List<DraftFormRow> forms(
            // family: 이 화면이 다루는 양식군
            Family family
    ) {
        return mapper.selectForms(family.key(), LoginUserContext.coCd(), family.std());
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-03
     * 코멘트:
     *   1) 좌측 작성 목록을 조회한다 — 상단 검색 6개 중 서버 조건 5개 + 제목
     *   2) 조회 버튼·초기 로드·저장/삭제/전송 후 호출한다
     *   3) 공백 조건은 SP 가 전체로 본다. 결재 여부는 파생값이라 화면이 거른다
     */
    public List<DraftListRow> list(
            // family: 이 화면이 다루는 양식군
            Family family,
            // tmplCd: 양식코드 부분검색. 빈값이면 자사 양식 전체
            String tmplCd,
            // tmplNm: 양식명 부분검색
            String tmplNm,
            // fromDt: 일자 시작 YYYYMMDD
            String fromDt,
            // toDt: 일자 종료 YYYYMMDD
            String toDt,
            // writerId: 작성자 ID 부분검색
            String writerId,
            // writerNm: 작성자명 부분검색
            String writerNm,
            // title: 제목 부분검색 — tbl_document.title
            String title
    ) {
        return mapper.selectList(
                family.key(), LoginUserContext.coCd(), DraftSupport.nvl(tmplCd), DraftSupport.nvl(tmplNm),
                DraftSupport.nvl(fromDt), DraftSupport.nvl(toDt), DraftSupport.nvl(writerId), DraftSupport.nvl(writerNm),
                DraftSupport.nvl(title));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-03
     * 코멘트:
     *   1) 기존 상세 또는 선택 양식의 신규 기본행 JSON 을 반환한다
     *   2) 좌측 행 클릭·양식 선택이 호출한다
     *   3) 저장 문서면 이탈 푸터를 붙인다
     */
    public HtmlFormDraftDetail detail(
            // family: 이 화면이 다루는 양식군
            Family family,
            // tmplCd: 신규일 때 항목을 깔 양식코드. 필수
            String tmplCd,
            // docIdx: tbl_document.idx. null·0 이면 신규
            Long docIdx
    ) {
        String tmpl = DraftSupport.requireUsrTmpl(tmplCd, family.prefix(), family.std());
        try {
            String json = mapper.selectDetail(family.key(), LoginUserContext.coCd(), tmpl, docIdx);
            HtmlFormDraftDetail root = objectMapper.readValue(json, HtmlFormDraftDetail.class);
            if (root.getItems() == null) {
                root.setItems(List.of());
            }
            // 저장된 문서일 때(= docIdx 있음) 개선조치 푸터를 함께 내린다
            if (docIdx != null && docIdx > 0) {
                root.setCorrective(correctiveSupport.load(LoginUserContext.coCd(), docIdx));
            } else {
                root.setCorrective(null);
            }
            // 화면이 다시 저장할 때 대조할 스탬프
            seenGuard.attach(root, docIdx);
            return root;
        } catch (JsonProcessingException e) {
            throw new BizException("작성 자료를 읽지 못했습니다.");
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-03
     * 코멘트:
     *   1) 헤더·항목·하단 4칸을 저장한다. 전송 전이라 필수값은 검사하지 않는다
     *   2) 저장 버튼이 호출한다
     *   3) 아니오가 있으면 이탈을 자동 생성한다. 이름이 사용자와 같고 서명이 있으면 이미지를 복사한다
     */
    @Transactional(timeout = 60)
    public Long save(
            // family: 이 화면이 다루는 양식군
            Family family,
            // req: 양식코드·일자·점검자·항목·하단 4칸
            DraftSaveRequest req
    ) {
        if (req == null || DraftSupport.nvl(req.getBaseDt()).length() != 8) {
            throw new BizException("일자를 입력하세요.");
        }
        String tmpl = DraftSupport.requireUsrTmpl(req.getTmplCd(), family.prefix(), family.std());
        // 수정일 때(= docIdx 있음) 다른 탭이 먼저 저장했으면 여기서 막는다
        seenGuard.assertSeen(req);
        try {
            Map<String, Object> payload = new LinkedHashMap<>();
            payload.put("verNo", req.getVerNo() == null ? 0 : req.getVerNo());
            payload.put("items", req.getItems() == null ? List.of() : req.getItems());
            payload.put("specialNote", DraftSupport.note(req.getSpecialNote()));
            payload.put("improveNote", DraftSupport.note(req.getImproveNote()));
            payload.put("actionNm", DraftSupport.note(req.getActionNm()));
            payload.put("confirmNm", DraftSupport.note(req.getConfirmNm()));
            // 목록 제목 — 빈값이면 SP 가 신규는 양식명·수정은 기존값을 쓴다
            payload.put("title", DraftSupport.nvl(req.getTitle()));
            Long docIdx = mapper.save(
                    family.key(),
                    LoginUserContext.coCd(),
                    tmpl,
                    req.getDocIdx(),
                    req.getBaseDt().trim(),
                    DraftSupport.nvl(req.getCheckerNm()),
                    objectMapper.writeValueAsString(payload),
                    LoginUserContext.userId()
            );
            if (docIdx == null || docIdx <= 0) {
                throw new BizException("저장에 실패했습니다.");
            }
            // 점검행은 안 남긴다 — 헤더만. HWP DocumentService 와 같다
            auditWriter.record(AUDIT_TBL, docIdx, req.getDocIdx() == null ? "I" : "U",
                    Map.of("docIdx", docIdx, "tmplCd", tmpl, "baseDt", req.getBaseDt().trim()));
            // 서명 스냅샷 — 이름=사용자면 blob 복사, 없으면 이름만
            mapper.snapshotSigns(
                    family.key(),
                    LoginUserContext.coCd(),
                    docIdx,
                    DraftSupport.nvl(req.getCheckerNm()),
                    DraftSupport.nvl(req.getApproverNm()),
                    DraftSupport.nvl(req.getConfirmNm())
            );
            // 점검행에 아니오가 하나라도 있을 때(= 부적합) 개선조치를 자동 생성한다
            boolean hasNg = req.getItems() != null && req.getItems().stream().anyMatch(row -> {
                String yn = row.getYn();
                return yn != null && "N".equalsIgnoreCase(yn.trim());
            });
            boolean keepCa = hasNg || "Y".equalsIgnoreCase(DraftSupport.nvl(req.getDeviationYn()));
            correctiveSupport.saveAutoIfNg(
                    LoginUserContext.coCd(),
                    docIdx,
                    tmpl,
                    req.getBaseDt().trim(),
                    req.getCorrective(),
                    keepCa,
                    LoginUserContext.userId()
            );
            return docIdx;
        } catch (JsonProcessingException e) {
            throw new BizException("작성 자료를 저장 형식으로 변환하지 못했습니다.");
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-03
     * 코멘트:
     *   1) 삭제 가능 여부만 검사한다
     *   2) 확인창 전에 호출한다
     *   3) 전송·결재완료 문서는 차단
     */
    public void validateDelete(
            // keys: [{ docIdx }] 객체 배열
            List<DraftDeleteItem> keys
    ) {
        DraftSupport.assertDeletable(keys, (ids) -> mapper.selectDeleteBlocker(LoginUserContext.coCd(), ids));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-03
     * 코멘트:
     *   1) 재검증 후 문서·하위를 삭제한다
     *   2) 삭제 버튼이 호출한다
     *   3) 성공 시 건수
     */
    @Transactional(timeout = 60)
    public int delete(
            // family: 이 화면이 다루는 양식군
            Family family,
            // keys: [{ docIdx }] 객체 배열
            List<DraftDeleteItem> keys
    ) {
        DraftSupport.assertDeletable(keys, (ids) -> mapper.selectDeleteBlocker(LoginUserContext.coCd(), ids));
        for (DraftDeleteItem key : keys) {
            mapper.delete(family.key(), LoginUserContext.coCd(), key.getDocIdx(), LoginUserContext.userId());
            auditWriter.record(AUDIT_TBL, key.getDocIdx(), "D", null);
        }
        return keys.size();
    }
}
