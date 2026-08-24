/**
 * CcpLogDraftService — CCP 포장·가열 모니터링일지 작성 업무.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 포장(pkg)·가열(htg)은 업무가 같고 양식군만 다르다. Family 하나로 두 화면이 이 서비스를 공유한다
 *   2) 데이터는 기존 tbl_ccp_generic_monitor(+_row·_cell). 신규 테이블을 만들지 않았다
 *   3) 지면 하단 4칸은 저장할 컬럼이 없어 DocCorrectiveSupport(tbl_corrective_action)로 넘긴다
 *
 * 작업 전/작업 종료는 행의 phaseCd 로만 가른다. 전송·전송취소는 문서 허브 결재 API 를 그대로 쓴다.
 *
 * PIPELINE[HB139] CCP 모니터링 작성 Service
 */
package com.haccp.draft.ccpmonitoring;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
import com.haccp.common.validation.DeleteValidation;
import com.haccp.docs.ccp.dto.DocCorrectiveDto;
import com.haccp.draft.ccpmonitoring.dto.CcpLogDraftDeleteItem;
import com.haccp.draft.ccpmonitoring.dto.CcpLogDraftFormRow;
import com.haccp.draft.ccpmonitoring.dto.CcpLogDraftListRow;
import com.haccp.draft.ccpmonitoring.dto.CcpLogDraftRow;
import com.haccp.draft.ccpmonitoring.dto.CcpLogDraftSaveRequest;
import com.haccp.flow.ca.DocCorrectiveSupport;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CcpLogDraftService {

    /**
     * 양식군 — 포장·가열이 이 값만 다르다.
     * family 는 XML choose 키, prefix 는 목록 SP 의 접두, std 는 예시 양식코드다.
     */
    public enum Family {
        PKG("pkg", "tml_ccp_pkg_", "tml_ccp_pkg_000"),
        HTG("htg", "tml_ccp_htg_", "tml_ccp_htg_000");

        private final String key;
        private final String prefix;
        private final String std;

        Family(String key, String prefix, String std) {
            this.key = key;
            this.prefix = prefix;
            this.std = std;
        }

        public String key() {
            return key;
        }

        public String prefix() {
            return prefix;
        }

        public String std() {
            return std;
        }
    }

    private final CcpLogDraftMapper mapper;
    private final ObjectMapper objectMapper;
    private final DocCorrectiveSupport correctiveSupport;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 작성에 쓸 수 있는 자사 양식(사용여부 예)만 반환한다
     *   2) 화면 진입 시 한 번 호출한다
     *   3) 없으면 빈 목록 — 화면이 양식관리 등록을 안내한다
     */
    public List<CcpLogDraftFormRow> forms(
            // family: 포장·가열 구분
            Family family
    ) {
        return mapper.selectForms(LoginUserContext.coCd(), family.key(), family.std());
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 좌측 작성 목록을 조회한다 — 상단 검색 6개 중 서버 조건 5개
     *   2) 조회 버튼·초기 로드·저장/삭제/전송 후 호출한다
     *   3) 결재 여부는 파생값이라 화면이 거른다
     */
    public List<CcpLogDraftListRow> list(
            // family: 포장·가열 구분
            Family family,
            // tmplCd: 양식코드 부분검색
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
            String writerNm
    ) {
        return mapper.selectList(
                LoginUserContext.coCd(), family.prefix(), nvl(tmplCd), nvl(tmplNm),
                nvl(fromDt), nvl(toDt), nvl(writerId), nvl(writerNm));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 헤더·양식항목·기록행·개선조치를 한 JSON 으로 조립한다
     *   2) 좌측 행 클릭·양식 선택이 호출한다
     *   3) docIdx 가 없으면 신규 — 양식 항목만 싣고 기록행은 빈 배열이다
     */
    public JsonNode detail(
            // family: 포장·가열 구분
            Family family,
            // tmplCd: 신규일 때 항목을 깔 양식코드. 필수
            String tmplCd,
            // docIdx: tbl_document.idx. null·0 이면 신규
            Long docIdx
    ) {
        String tmpl = requireUsrTmpl(family, tmplCd);
        String coCd = LoginUserContext.coCd();
        ObjectNode root = objectMapper.createObjectNode();
        ObjectNode header = objectMapper.createObjectNode();

        Map<String, Object> saved = (docIdx != null && docIdx > 0)
                ? mapper.selectDetail(coCd, docIdx)
                : null;
        // 저장된 문서일 때(= docIdx 있음) 헤더·기록행을 서버 값으로 채운다
        if (saved != null) {
            header.put("docIdx", asLong(saved.get("docIdx")));
            header.put("docNo", asText(saved.get("docNo")));
            header.put("status", asText(saved.get("status")));
            header.put("baseDt", asText(saved.get("baseDt")));
            header.put("tmplCd", asText(saved.get("tmplCd")));
            header.put("checkerNm", asText(saved.get("mngNm")));
            root.set("logRows", readJson(asText(saved.get("rowsJson"))));
        } else {
            header.putNull("docIdx");
            header.put("docNo", "");
            header.putNull("status");
            header.put("baseDt", "");
            header.put("tmplCd", tmpl);
            header.put("checkerNm", "");
            root.set("logRows", objectMapper.createArrayNode());
        }
        // 양식 항목 — 한계기준·주기·방법·개선조치. 지면 상단이 쓴다
        root.set("items", objectMapper.valueToTree(
                mapper.selectFormItems(coCd, family.key(), tmpl, saved == null ? 1 : verNoOf(saved))));
        // 지면 하단 4칸 — 저장할 컬럼이 없어 개선조치 테이블에서 읽는다
        DocCorrectiveDto ca = (docIdx != null && docIdx > 0) ? correctiveSupport.load(coCd, docIdx) : null;
        header.put("specialNote", ca == null ? "" : nvl(ca.getDeviationDesc()));
        header.put("improveNote", ca == null ? "" : nvl(ca.getActionDesc()));
        header.put("actionNm", ca == null ? "" : nvl(ca.getActionUserNm()));
        header.put("confirmNm", ca == null ? "" : nvl(ca.getConfirmUserNm()));
        root.set("header", header);
        root.set("corrective", objectMapper.valueToTree(ca));
        // 이 계열은 통과량 표가 없다 — 화면이 빈 배열을 그대로 받는다
        root.set("passRows", objectMapper.createArrayNode());
        return root;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 헤더·기록행을 저장한다. 전송 전이라 필수값은 검사하지 않는다
     *   2) 저장 버튼이 호출한다
     *   3) 하단 4칸은 개선조치로 넘긴다. 부적합(F) 행이 있으면 이탈을 자동 생성한다
     */
    @Transactional(timeout = 60)
    public Long save(
            // family: 포장·가열 구분
            Family family,
            // req: 양식코드·일자·점검자·기록행·하단 4칸
            CcpLogDraftSaveRequest req
    ) {
        if (req == null || nvl(req.getBaseDt()).length() != 8) {
            throw new BizException("일자를 입력하세요.");
        }
        String tmpl = requireUsrTmpl(family, req.getTmplCd());
        List<CcpLogDraftRow> rows = req.getLogRows() == null ? List.of() : req.getLogRows();
        if (rows.isEmpty()) {
            throw new BizException("점검 행이 없습니다.");
        }
        String coCd = LoginUserContext.coCd();
        try {
            Long docIdx = mapper.save(
                    coCd,
                    req.getDocIdx(),
                    req.getBaseDt().trim(),
                    tmpl,
                    nvl(req.getCheckerNm()),
                    objectMapper.writeValueAsString(toGenericRows(rows)),
                    LoginUserContext.userId()
            );
            if (docIdx == null || docIdx <= 0) {
                throw new BizException("저장에 실패했습니다.");
            }
            saveFooter(coCd, docIdx, tmpl, req, rows);
            return docIdx;
        } catch (JsonProcessingException e) {
            throw new BizException("작성 자료를 저장 형식으로 변환하지 못했습니다.");
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 지면 기록행을 공통 CCP SP 가 받는 모양으로 편다
     *   2) 저장이 호출한다
     *   3) cells 는 item_cd → 값 맵이라 EAV 셀 배열로 바꾼다. 숫자로 읽히면 numVal 로 넣는다
     */
    private List<Map<String, Object>> toGenericRows(
            // rows: 화면 기록행 — 작업 전/종료가 phaseCd 로 섞여 있다
            List<CcpLogDraftRow> rows
    ) {
        List<Map<String, Object>> out = new ArrayList<>();
        int seq = 0;
        for (CcpLogDraftRow row : rows) {
            seq += 1;
            Map<String, Object> one = new LinkedHashMap<>();
            one.put("rowSeq", row.getRowSeq() == null || row.getRowSeq() <= 0 ? seq : row.getRowSeq());
            one.put("phaseCd", nvl(row.getPhaseCd()));
            one.put("checkTime", nvl(row.getCheckTime()));
            one.put("productNm", nvl(row.getProductNm()));
            one.put("equipNm", "");
            one.put("judgeCd", nvl(row.getJudgeCd()));
            one.put("judgeModYn", nvl(row.getJudgeModYn()).isEmpty() ? "N" : row.getJudgeModYn());
            one.put("checkerId", nvl(row.getCheckerId()));
            one.put("checkerNm", nvl(row.getCheckerNm()));
            one.put("signYn", nvl(row.getSignYn()).isEmpty() ? "N" : row.getSignYn());
            List<Map<String, Object>> cells = new ArrayList<>();
            if (row.getCells() != null) {
                for (Map.Entry<String, String> cell : row.getCells().entrySet()) {
                    String val = nvl(cell.getValue());
                    Map<String, Object> one2 = new LinkedHashMap<>();
                    one2.put("itemCd", cell.getKey());
                    // 숫자로 읽히면 numVal, 아니면 txtVal — 지면 온도·분·초는 숫자다
                    if (isNumeric(val)) {
                        one2.put("numVal", val);
                        one2.put("txtVal", "");
                    } else {
                        one2.put("numVal", "");
                        one2.put("txtVal", val);
                    }
                    cells.add(one2);
                }
            }
            one.put("cells", cells);
            out.add(one);
        }
        return out;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 지면 하단 4칸을 개선조치로 저장한다 — 신규 컬럼 없이 tbl_corrective_action 을 쓴다
     *   2) 저장 직후 호출한다
     *   3) 부적합(F) 행이 하나라도 있으면 이탈을 자동 생성한다
     */
    private void saveFooter(
            String coCd, Long docIdx, String tmplCd,
            CcpLogDraftSaveRequest req, List<CcpLogDraftRow> rows
    ) {
        DocCorrectiveDto ca = req.getCorrective();
        if (ca == null) {
            ca = new DocCorrectiveDto();
            ca.setDeviationDesc(note(req.getSpecialNote()));
            ca.setActionDesc(note(req.getImproveNote()));
            ca.setActionUserNm(nvl(req.getActionNm()));
            ca.setConfirmUserNm(nvl(req.getConfirmNm()));
        }
        boolean hasNg = rows.stream().anyMatch(r -> "F".equalsIgnoreCase(nvl(r.getJudgeCd())));
        correctiveSupport.saveAutoIfNg(
                coCd, docIdx, tmplCd, req.getBaseDt().trim(), ca, hasNg, LoginUserContext.userId());
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 삭제 가능 여부만 검사한다
     *   2) 확인창 전에 호출한다
     *   3) 전송·결재완료 문서는 차단
     */
    public void validateDelete(
            // keys: [{ docIdx }] 객체 배열
            List<CcpLogDraftDeleteItem> keys
    ) {
        assertDeletable(keys);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 재검증 후 문서·기록행을 삭제한다
     *   2) 삭제 버튼이 호출한다
     *   3) 성공 시 건수
     */
    @Transactional(timeout = 60)
    public int delete(
            // keys: [{ docIdx }] 객체 배열
            List<CcpLogDraftDeleteItem> keys
    ) {
        assertDeletable(keys);
        for (CcpLogDraftDeleteItem key : keys) {
            mapper.delete(LoginUserContext.coCd(), key.getDocIdx(), LoginUserContext.userId());
        }
        return keys.size();
    }

    /** 삭제 키 정규화·전송 이후 차단 Double Check. */
    private void assertDeletable(List<CcpLogDraftDeleteItem> keys) {
        DeleteValidation.requireItems(keys, "삭제할 문서를 선택하세요.");
        List<Long> docIdxs = new ArrayList<>();
        for (CcpLogDraftDeleteItem key : keys) {
            Long docIdx = DeleteValidation.requirePositive(key.getDocIdx(), "삭제할 문서번호가 올바르지 않습니다.");
            key.setDocIdx(docIdx);
            docIdxs.add(docIdx);
        }
        DeleteValidation.throwIfBlocked(
                mapper.selectDeleteBlocker(LoginUserContext.coCd(), docIdxs), "문서");
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 이 화면이 다루는 자사 양식코드인지 확인한다
     *   2) 상세·저장 진입에서 호출한다
     *   3) 빈값이거나 접두가 다르거나 예시(000)면 BizException
     */
    private static String requireUsrTmpl(Family family, String tmplCd) {
        String tmpl = nvl(tmplCd);
        // 예시 000 이거나 접두가 다를 때(= 이 화면 범위 밖) 거부한다
        if (tmpl.isEmpty() || !tmpl.startsWith(family.prefix()) || tmpl.equals(family.std())) {
            throw new BizException("작성할 양식을 선택하세요.");
        }
        return tmpl;
    }

    /** rows_json 문자열을 JSON 배열로 — SP 가 jsonb 를 문자열로 준다 */
    private JsonNode readJson(String raw) {
        if (raw == null || raw.isBlank()) return objectMapper.createArrayNode();
        try {
            return objectMapper.readTree(raw);
        } catch (JsonProcessingException e) {
            return objectMapper.createArrayNode();
        }
    }

    /** 저장 문서의 적용 버전 — 자사 양식은 1 고정이라 값이 없으면 1 */
    private static int verNoOf(Map<String, Object> saved) {
        Object v = saved.get("verNo");
        if (v == null) return 1;
        try {
            return Integer.parseInt(String.valueOf(v));
        } catch (NumberFormatException e) {
            return 1;
        }
    }

    private static boolean isNumeric(String value) {
        if (value == null || value.isBlank()) return false;
        try {
            Double.parseDouble(value.trim());
            return true;
        } catch (NumberFormatException e) {
            return false;
        }
    }

    private static Long asLong(Object v) {
        if (v == null) return null;
        try {
            return Long.valueOf(String.valueOf(v));
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private static String asText(Object v) {
        return v == null ? "" : String.valueOf(v);
    }

    private static String nvl(String value) {
        return value == null ? "" : value.trim();
    }

    /** 개행 보존 — 끝 공백 trim 금지 */
    private static String note(String value) {
        return value == null ? "" : value;
    }
}
