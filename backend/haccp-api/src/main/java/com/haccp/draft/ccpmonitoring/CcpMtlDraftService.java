/**
 * CcpMtlDraftService — CCP 금속검출 모니터링일지 작성 업무.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 데이터는 기존 tbl_ccp_metal_monitor(+_sens_row·_pass_row). 신규 테이블을 만들지 않았다
 *   2) 감도표는 phaseCd(BEFORE·AFTER) 로 작업 전/작업 후를 가르고, 통과량표는 별도 행 배열이다
 *   3) 지면 하단 4칸은 DocCorrectiveSupport, 작성자·승인자는 DraftPaperStamp(문서·결재 스냅샷)
 *
 * 감도 5칸(Fe만·SUS만·제품만·Fe+제품·SUS+제품)은 화면 cells 맵으로 오고 여기서 컬럼으로 편다.
 *
 * PIPELINE[HB140] CCP 금속검출 작성 Service
 */
package com.haccp.draft.ccpmonitoring;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
import com.haccp.draft.DraftSupport;
import com.haccp.draft.DraftPaperStamp;
import com.haccp.draft.DraftPaperStampMapper;
import com.haccp.flow.ca.dto.DocCorrectiveDto;
import com.haccp.draft.dto.DraftDeleteItem;
import com.haccp.draft.dto.DraftFormRow;
import com.haccp.draft.dto.DraftListRow;
import com.haccp.draft.dto.DraftPassRow;
import com.haccp.draft.dto.DraftLogRow;
import com.haccp.draft.dto.DraftSaveRequest;
import com.haccp.flow.ca.DocCorrectiveSupport;
import com.haccp.sys.logs.auditlog.AuditWriter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CcpMtlDraftService {
    /** 계열 예시 양식코드 — 목록 SP 가 이 값으로 tbl_tml_ccp_mtl_ver 를 가른다 */
    private static final String STD_TMPL_CD = "tml_ccp_mtl_000";
    /** 자사 양식 접두 — 이 화면이 다루는 범위 */
    private static final String USR_TMPL_PREFIX = "tml_ccp_mtl_";

    /** 감도 5칸 — 지면 감도열 item_cd(MTL_HDR)와 DB 컬럼(camelCase) 대응 */
    /** 신규 문서 통과량 기본 줄 수 — 지면 CcpMtlPaper.PASS_CNT 와 같은 값 */
    private static final int PASS_ROW_CNT = 4;

    private static final String[][] SENS_CELLS = {
        { "hdr-fe", "feOnlyCd" },
        { "hdr-sus", "stsOnlyCd" },
        { "hdr-prod", "prodOnlyCd" },
        { "hdr-fe-prod", "feProdCd" },
        { "hdr-sus-prod", "stsProdCd" },
    };

    private final CcpMtlDraftMapper mapper;
    private final ObjectMapper objectMapper;
    private final DocCorrectiveSupport correctiveSupport;
    // 작성 저장·삭제 이력 — 이탈 자동생성은 같은 저장의 부수라 따로 안 남긴다
    private final AuditWriter auditWriter;
    // 지면 작성자·승인자 칸 — 문서함 미리보기가 같은 detail 을 쓴다
    private final DraftPaperStampMapper paperStampMapper;

    /** 감사 로그 대상 표 — 헤더. 감도·통과량 행은 남기지 않는다 */
    private static final String AUDIT_TBL = "tbl_document";

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 작성에 쓸 수 있는 자사 양식(사용여부 예)만 반환한다
     *   2) 화면 진입 시 한 번 호출한다
     *   3) 없으면 빈 목록 — 화면이 양식관리 등록을 안내한다
     */
    public List<DraftFormRow> forms() {
        return mapper.selectForms(LoginUserContext.coCd(), STD_TMPL_CD);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 좌측 작성 목록을 조회한다 — 상단 검색 6개 중 서버 조건 5개
     *   2) 조회 버튼·초기 로드·저장/삭제/전송 후 호출한다
     *   3) 결재 여부는 파생값이라 화면이 거른다
     */
    public List<DraftListRow> list(
            String tmplCd, String tmplNm, String fromDt, String toDt, String writerId, String writerNm,
            // title: 제목 부분검색 — tbl_document.title
            String title
    ) {
        return mapper.selectList(
                LoginUserContext.coCd(), DraftSupport.nvl(tmplCd), DraftSupport.nvl(tmplNm),
                DraftSupport.nvl(fromDt), DraftSupport.nvl(toDt), DraftSupport.nvl(writerId), DraftSupport.nvl(writerNm),
                DraftSupport.nvl(title));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) 헤더·양식항목·감도행·통과량행·개선조치를 한 JSON 으로 조립한다
     *   2) 좌측 행 클릭·양식 선택이 호출한다
     *   3) MyBatis Map 은 camelMap 한 뒤 읽는다. 감도행은 phaseCd 를 그대로 내려 화면이 작업 전/후에 붙인다
     */
    public JsonNode detail(
            // tmplCd: 신규일 때 항목을 깔 양식코드. 필수
            String tmplCd,
            // docIdx: tbl_document.idx. null·0 이면 신규
            Long docIdx
    ) {
        String tmpl = DraftSupport.requireUsrTmpl(tmplCd, USR_TMPL_PREFIX, STD_TMPL_CD);
        String coCd = LoginUserContext.coCd();
        ObjectNode root = objectMapper.createObjectNode();
        ObjectNode header = objectMapper.createObjectNode();
        ArrayNode logRows = objectMapper.createArrayNode();
        ArrayNode passRows = objectMapper.createArrayNode();

        Map<String, Object> head = (docIdx != null && docIdx > 0)
                ? DraftSupport.camelMap(mapper.selectHeader(coCd, docIdx, tmpl))
                : null;
        // 저장된 문서일 때(= docIdx 있음) 헤더·감도행·통과량행을 서버 값으로 채운다
        if (head != null) {
            Long hdrIdx = DraftSupport.asLong(head.get("hdrIdx"));
            header.put("docIdx", DraftSupport.asLong(head.get("docIdx")));
            header.put("docNo", DraftSupport.asText(head.get("docNo")));
            header.put("status", DraftSupport.asText(head.get("status")));
            header.put("baseDt", DraftSupport.asText(head.get("baseDt")));
            header.put("tmplCd", tmpl);
            header.put("checkerNm", DraftSupport.asText(head.get("mngNm")));
            // 작성자·승인자 — 금속 모니터 헤더에 컬럼이 없어 문서·결재 스냅샷을 붙인다
            DraftPaperStamp.apply(header, paperStampMapper.selectPaperStamp(coCd, docIdx));
            for (Map<String, Object> row : DraftSupport.camelMaps(mapper.selectSensRows(coCd, hdrIdx))) {
                logRows.add(toLogRowNode(row));
            }
            for (Map<String, Object> row : DraftSupport.camelMaps(mapper.selectPassRows(coCd, hdrIdx))) {
                ObjectNode one = objectMapper.createObjectNode();
                one.put("rowSeq", DraftSupport.asInt(row.get("rowSeq")));
                one.put("productNm", DraftSupport.asText(row.get("productNm")));
                one.put("passQty", DraftSupport.asText(row.get("passQty")));
                one.put("detectQty", DraftSupport.asText(row.get("detectQty")));
                one.put("remark", DraftSupport.asText(row.get("remark")));
                passRows.add(one);
            }
        } else {
            header.putNull("docIdx");
            header.put("docNo", "");
            header.putNull("status");
            header.put("baseDt", "");
            header.put("tmplCd", tmpl);
            header.put("checkerNm", "");
            // 신규 — 감도 구간별 1줄, 통과량 기본 4줄. 행이 0건이면 좌측 저장 SP 가 막는다
            logRows.addAll((ArrayNode) objectMapper.valueToTree(DraftSupport.seedLogRows("BEFORE", "AFTER")));
            passRows.addAll((ArrayNode) objectMapper.valueToTree(DraftSupport.seedPassRows(PASS_ROW_CNT)));
        }
        // 양식 항목 — 한계기준·주기·방법·감도열·개선조치. Map 도 camelCase 로 맞춘다
        root.set("items", objectMapper.valueToTree(DraftSupport.camelMaps(mapper.selectFormItems(coCd, tmpl, 1))));
        // 지면 하단 4칸 — 저장할 컬럼이 없어 개선조치 테이블에서 읽는다
        DocCorrectiveDto ca = (docIdx != null && docIdx > 0) ? correctiveSupport.load(coCd, docIdx) : null;
        header.put("specialNote", ca == null ? "" : DraftSupport.nvl(ca.getDeviationDesc()));
        header.put("improveNote", ca == null ? "" : DraftSupport.nvl(ca.getActionDesc()));
        header.put("actionNm", ca == null ? "" : DraftSupport.nvl(ca.getActionUserNm()));
        header.put("confirmNm", ca == null ? "" : DraftSupport.nvl(ca.getConfirmUserNm()));
        root.set("header", header);
        root.set("logRows", logRows);
        root.set("passRows", passRows);
        root.set("corrective", objectMapper.valueToTree(ca));
        return root;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 감도행 1건을 지면 계약(cells 맵)으로 바꾼다
     *   2) 상세 조회가 호출한다
     *   3) 5칸 O/X 는 cells 로 접는다 — 화면은 계열과 무관하게 같은 행 타입을 쓴다
     */
    private ObjectNode toLogRowNode(Map<String, Object> row) {
        ObjectNode one = objectMapper.createObjectNode();
        one.put("rowSeq", DraftSupport.asInt(row.get("rowSeq")));
        one.put("phaseCd", DraftSupport.asText(row.get("phaseCd")));
        one.put("productNm", DraftSupport.asText(row.get("productNm")));
        one.put("checkTime", DraftSupport.asText(row.get("checkTime")));
        one.put("judgeCd", DraftSupport.asText(row.get("judgeCd")));
        one.put("judgeModYn", DraftSupport.asText(row.get("judgeModYn")));
        one.put("checkerId", DraftSupport.asText(row.get("checkerId")));
        one.put("checkerNm", DraftSupport.asText(row.get("checkerNm")));
        one.put("signYn", "N");
        ObjectNode cells = objectMapper.createObjectNode();
        for (String[] pair : SENS_CELLS) {
            cells.put(pair[0], DraftSupport.asText(row.get(pair[1])));
        }
        one.set("cells", cells);
        return one;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 헤더·감도행·통과량행을 저장한다. 전송 전이라 필수값은 검사하지 않는다
     *   2) 저장 버튼이 호출한다
     *   3) 하단 4칸은 개선조치로 넘긴다. 부적합(F) 행이 있으면 이탈을 자동 생성한다
     */
    @Transactional(timeout = 60)
    public Long save(
            // req: 양식코드·일자·점검자·감도행·통과량행·하단 4칸
            DraftSaveRequest req
    ) {
        if (req == null || DraftSupport.nvl(req.getBaseDt()).length() != 8) {
            throw new BizException("일자를 입력하세요.");
        }
        String tmpl = DraftSupport.requireUsrTmpl(req.getTmplCd(), USR_TMPL_PREFIX, STD_TMPL_CD);
        List<DraftLogRow> rows = req.getLogRows() == null ? List.of() : req.getLogRows();
        if (rows.isEmpty()) {
            throw new BizException("감도 점검 행이 없습니다.");
        }
        String coCd = LoginUserContext.coCd();
        try {
            Long docIdx = mapper.save(
                    coCd,
                    req.getDocIdx(),
                    req.getBaseDt().trim(),
                    // ccp_cd 는 NOT NULL — 자사 양식은 양식코드를 그대로 넣는다
                    tmpl,
                    DraftSupport.nvl(req.getCheckerNm()),
                    objectMapper.writeValueAsString(toSensRows(rows)),
                    objectMapper.writeValueAsString(toPassRows(req.getPassRows())),
                    LoginUserContext.userId(),
                    tmpl,
                    DraftSupport.nvl(req.getTitle())
            );
            if (docIdx == null || docIdx <= 0) {
                throw new BizException("저장에 실패했습니다.");
            }
            // 감도·통과량 행은 안 남긴다 — 헤더만
            auditWriter.record(AUDIT_TBL, docIdx, req.getDocIdx() == null ? "I" : "U",
                    Map.of("docIdx", docIdx, "tmplCd", tmpl, "baseDt", req.getBaseDt().trim()));
            DocCorrectiveDto ca = req.getCorrective();
            if (ca == null) {
                ca = new DocCorrectiveDto();
                ca.setDeviationDesc(DraftSupport.note(req.getSpecialNote()));
                ca.setActionDesc(DraftSupport.note(req.getImproveNote()));
                ca.setActionUserNm(DraftSupport.nvl(req.getActionNm()));
                ca.setConfirmUserNm(DraftSupport.nvl(req.getConfirmNm()));
            }
            boolean hasNg = rows.stream().anyMatch(r -> "F".equalsIgnoreCase(DraftSupport.nvl(r.getJudgeCd())));
            boolean keepCa = hasNg || "Y".equalsIgnoreCase(DraftSupport.nvl(req.getDeviationYn()));
            correctiveSupport.saveAutoIfNg(
                    coCd, docIdx, tmpl, req.getBaseDt().trim(), ca, keepCa, LoginUserContext.userId());
            return docIdx;
        } catch (JsonProcessingException e) {
            throw new BizException("작성 자료를 저장 형식으로 변환하지 못했습니다.");
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 지면 감도행을 금속 SP 가 받는 모양으로 편다 — cells 맵을 5칸 컬럼으로 되돌린다
     *   2) 저장이 호출한다
     *   3) rowSeq 는 1부터 다시 매긴다. SP 가 0 이하를 거부한다
     */
    private List<Map<String, Object>> toSensRows(List<DraftLogRow> rows) {
        List<Map<String, Object>> out = new ArrayList<>();
        int seq = 0;
        for (DraftLogRow row : rows) {
            seq += 1;
            Map<String, Object> one = new LinkedHashMap<>();
            one.put("rowSeq", seq);
            // 작업 전/작업 후 — 안 넘기면 SP 가 DURING 으로 넣는다
            one.put("phaseCd", DraftSupport.nvl(row.getPhaseCd()));
            one.put("productNm", DraftSupport.nvl(row.getProductNm()));
            one.put("checkTime", DraftSupport.nvl(row.getCheckTime()));
            one.put("judgeCd", DraftSupport.nvl(row.getJudgeCd()));
            one.put("judgeModYn", DraftSupport.nvl(row.getJudgeModYn()).isEmpty() ? "N" : row.getJudgeModYn());
            one.put("checkerId", DraftSupport.nvl(row.getCheckerId()));
            one.put("checkerNm", DraftSupport.nvl(row.getCheckerNm()));
            Map<String, String> cells = row.getCells() == null ? Map.of() : row.getCells();
            for (String[] pair : SENS_CELLS) {
                one.put(pair[1], DraftSupport.nvl(cells.get(pair[0])));
            }
            out.add(one);
        }
        return out;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 통과량 행을 금속 SP 가 받는 모양으로 편다
     *   2) 저장이 호출한다
     *   3) 빈 목록이면 빈 배열 — SP 가 COALESCE 로 받는다
     */
    private List<Map<String, Object>> toPassRows(List<DraftPassRow> rows) {
        List<Map<String, Object>> out = new ArrayList<>();
        if (rows == null) return out;
        int seq = 0;
        for (DraftPassRow row : rows) {
            seq += 1;
            Map<String, Object> one = new LinkedHashMap<>();
            one.put("rowSeq", seq);
            one.put("productNm", DraftSupport.nvl(row.getProductNm()));
            one.put("passQty", DraftSupport.nvl(row.getPassQty()));
            one.put("detectQty", DraftSupport.nvl(row.getDetectQty()));
            one.put("remark", DraftSupport.nvl(row.getRemark()));
            out.add(one);
        }
        return out;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 삭제 가능 여부만 검사한다
     *   2) 확인창 전에 호출한다
     *   3) 전송·결재완료 문서는 차단
     */
    public void validateDelete(List<DraftDeleteItem> keys) {
        DraftSupport.assertDeletable(keys, (ids) -> mapper.selectDeleteBlocker(LoginUserContext.coCd(), ids));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-24
     * 코멘트:
     *   1) 재검증 후 문서·감도행·통과량행을 삭제한다
     *   2) 삭제 버튼이 호출한다
     *   3) 성공 시 건수
     */
    @Transactional(timeout = 60)
    public int delete(
            // keys: [{ docIdx }] 객체 배열
            List<DraftDeleteItem> keys,
            // tmplCd: 삭제 대상 양식코드 — SP 가 문서를 이 코드로 찾는다
            String tmplCd
    ) {
        DraftSupport.assertDeletable(keys, (ids) -> mapper.selectDeleteBlocker(LoginUserContext.coCd(), ids));
        String tmpl = DraftSupport.requireUsrTmpl(tmplCd, USR_TMPL_PREFIX, STD_TMPL_CD);
        for (DraftDeleteItem key : keys) {
            mapper.delete(LoginUserContext.coCd(), key.getDocIdx(), LoginUserContext.userId(), tmpl);
            auditWriter.record(AUDIT_TBL, key.getDocIdx(), "D", null);
        }
        return keys.size();
    }

}
