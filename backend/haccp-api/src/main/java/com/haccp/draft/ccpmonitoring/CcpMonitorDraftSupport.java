/**
 * CcpMonitorDraftSupport — 포장·가열 작성 공통 조립.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 두 서비스의 저장·상세·삭제 흐름이 같다. 표·SP 만 매퍼가 가른다
 *   2) cells 는 계열 DTO 로 받은 뒤 EAV 배열로 편다
 *   3) 금속은 여기 안 넣는다 — 감도·통과량 표가 다르다
 *
 * PIPELINE[HB139] CCP 모니터링 작성 Support
 */
package com.haccp.draft.ccpmonitoring;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
import com.haccp.draft.DraftPaperStamp;
import com.haccp.draft.DraftPaperStampMapper;
import com.haccp.draft.DraftSeenGuard;
import com.haccp.draft.DraftSupport;
import com.haccp.docs.htmlform.htmltemplate.dto.HtmlFormItemRow;
import com.haccp.draft.ccpmonitoring.dto.CcpMonitorDetailRow;
import com.haccp.draft.dto.CcpMonitorDraftDetail;
import com.haccp.draft.dto.DraftDeleteItem;
import com.haccp.draft.dto.DraftFormRow;
import com.haccp.draft.dto.DraftListRow;
import com.haccp.draft.dto.DraftLogRow;
import com.haccp.draft.dto.DraftSaveRequest;
import com.haccp.draft.dto.HtmlFormDraftHeader;
import com.haccp.flow.ca.DocCorrectiveSupport;
import com.haccp.flow.ca.dto.DocCorrectiveDto;
import com.haccp.sys.logs.auditlog.AuditWriter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
@RequiredArgsConstructor
public class CcpMonitorDraftSupport {

    private final ObjectMapper objectMapper;
    private final DocCorrectiveSupport correctiveSupport;
    // 작성 저장·삭제 이력 — 이탈 자동생성은 같은 저장의 부수라 따로 안 남긴다
    private final AuditWriter auditWriter;
    // 지면 작성자·승인자 칸 — 문서함 미리보기가 같은 detail 을 쓴다
    private final DraftPaperStampMapper paperStampMapper;
    // 초안 동시 저장 스탬프 — 상세에 붙이고 저장 직전에 대조한다
    private final DraftSeenGuard seenGuard;

    /** 감사 로그 대상 표 — 헤더. 기록행은 남기지 않는다 */
    private static final String AUDIT_TBL = "tbl_document";

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 작성에 쓸 수 있는 자사 양식(사용여부 예)만 반환한다
     *   2) 화면 진입 시 한 번 호출한다
     *   3) 없으면 빈 목록
     */
    public List<DraftFormRow> forms(
            // store: 계열 매퍼
            CcpMonitorStore store,
            // stdTmplCd: 계열 예시코드
            String stdTmplCd
    ) {
        return store.selectForms(LoginUserContext.coCd(), stdTmplCd);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 좌측 작성 목록을 조회한다
     *   2) 조회 버튼·초기 로드·저장/삭제/전송 후 호출한다
     *   3) 결재 여부는 파생값이라 화면이 거른다
     */
    public List<DraftListRow> list(
            // store: 계열 매퍼
            CcpMonitorStore store,
            String tmplCd, String tmplNm, String fromDt, String toDt,
            String writerId, String writerNm, String title
    ) {
        return store.selectList(
                LoginUserContext.coCd(), DraftSupport.nvl(tmplCd), DraftSupport.nvl(tmplNm),
                DraftSupport.nvl(fromDt), DraftSupport.nvl(toDt), DraftSupport.nvl(writerId),
                DraftSupport.nvl(writerNm), DraftSupport.nvl(title));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 헤더·양식항목·기록행·개선조치를 한 JSON 으로 조립한다
     *   2) 좌측 행 클릭·양식 선택이 호출한다
     *   3) cells EAV 배열은 지면 맵으로 접는다
     */
    public CcpMonitorDraftDetail detail(
            // store: 계열 매퍼
            CcpMonitorStore store,
            // tmplPfx: 양식군 접두
            String tmplPfx,
            // stdTmplCd: 계열 예시코드
            String stdTmplCd,
            // tmplCd: 신규일 때 항목을 깔 양식코드
            String tmplCd,
            // docIdx: tbl_document.idx. null·0 이면 신규
            Long docIdx
    ) {
        String tmpl = DraftSupport.requireUsrTmpl(tmplCd, tmplPfx, stdTmplCd);
        String coCd = LoginUserContext.coCd();
        CcpMonitorDraftDetail root = new CcpMonitorDraftDetail();
        HtmlFormDraftHeader header = new HtmlFormDraftHeader();

        CcpMonitorDetailRow saved = (docIdx != null && docIdx > 0)
                ? store.selectDetail(coCd, docIdx)
                : null;
        // 저장된 문서일 때(= docIdx 있음) 헤더·기록행을 서버 값으로 채운다
        if (saved != null) {
            header.setDocIdx(saved.getDocIdx());
            header.setDocNo(DraftSupport.asText(saved.getDocNo()));
            header.setStatus(DraftSupport.asText(saved.getStatus()));
            header.setBaseDt(DraftSupport.asText(saved.getBaseDt()));
            header.setTmplCd(DraftSupport.asText(saved.getTmplCd()));
            header.setCheckerNm(DraftSupport.asText(saved.getMngNm()));
            DraftPaperStamp.apply(header, paperStampMapper.selectPaperStamp(coCd, docIdx));
            root.setLogRows(objectMapper.convertValue(
                    foldCellsToMap(readJson(saved.getRowsJson())),
                    new TypeReference<List<DraftLogRow>>() {}));
        } else {
            header.setDocIdx(null);
            header.setDocNo("");
            header.setStatus(null);
            header.setBaseDt("");
            header.setTmplCd(tmpl);
            header.setCheckerNm("");
            root.setLogRows(DraftSupport.seedLogRows("BEFORE", "AFTER"));
        }
        List<HtmlFormItemRow> items = store.selectFormItems(coCd, tmpl, saved == null ? 1 : verNoOf(saved));
        root.setItems(items == null ? List.of() : items);
        DocCorrectiveDto ca = (docIdx != null && docIdx > 0) ? correctiveSupport.load(coCd, docIdx) : null;
        header.setSpecialNote(ca == null ? "" : DraftSupport.nvl(ca.getDeviationDesc()));
        header.setImproveNote(ca == null ? "" : DraftSupport.nvl(ca.getActionDesc()));
        header.setActionNm(ca == null ? "" : DraftSupport.nvl(ca.getActionUserNm()));
        header.setConfirmNm(ca == null ? "" : DraftSupport.nvl(ca.getConfirmUserNm()));
        root.setHeader(header);
        root.setCorrective(ca);
        root.setPassRows(List.of());
        seenGuard.attach(root, docIdx);
        return root;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 헤더·기록행을 저장한다. 전송 전이라 필수값은 검사하지 않는다
     *   2) 저장 버튼이 호출한다
     *   3) cellsType 으로 계열 칸을 받은 뒤 EAV 로 편다
     */
    @Transactional(timeout = 60)
    public Long save(
            // store: 계열 매퍼
            CcpMonitorStore store,
            // tmplPfx: 양식군 접두
            String tmplPfx,
            // stdTmplCd: 계열 예시코드
            String stdTmplCd,
            // req: 양식코드·일자·점검자·기록행·하단 4칸
            DraftSaveRequest req,
            // cellsType: PkgLogCells 또는 HtgLogCells
            Class<?> cellsType
    ) {
        if (req == null || DraftSupport.nvl(req.getBaseDt()).length() != 8) {
            throw new BizException("일자를 입력하세요.");
        }
        String tmpl = DraftSupport.requireUsrTmpl(req.getTmplCd(), tmplPfx, stdTmplCd);
        List<DraftLogRow> rows = req.getLogRows() == null ? List.of() : req.getLogRows();
        if (rows.isEmpty()) {
            throw new BizException("점검 행이 없습니다.");
        }
        String coCd = LoginUserContext.coCd();
        seenGuard.assertSeen(req);
        try {
            Long docIdx = store.save(
                    coCd,
                    req.getDocIdx(),
                    req.getBaseDt().trim(),
                    tmpl,
                    DraftSupport.nvl(req.getCheckerNm()),
                    objectMapper.writeValueAsString(toEavRows(rows, cellsType)),
                    LoginUserContext.userId(),
                    DraftSupport.nvl(req.getTitle())
            );
            if (docIdx == null || docIdx <= 0) {
                throw new BizException("저장에 실패했습니다.");
            }
            auditWriter.record(AUDIT_TBL, docIdx, req.getDocIdx() == null ? "I" : "U",
                    Map.of("docIdx", docIdx, "tmplCd", tmpl, "baseDt", req.getBaseDt().trim()));
            saveFooter(coCd, docIdx, tmpl, req, rows);
            return docIdx;
        } catch (JsonProcessingException e) {
            throw new BizException("작성 자료를 저장 형식으로 변환하지 못했습니다.");
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 지면 기록행을 계열 저장 SP 가 받는 EAV 모양으로 편다
     *   2) 저장이 호출한다
     *   3) cells 는 계열 DTO 로 받은 뒤 item_cd 배열로 바꾼다. 숫자로 읽히면 numVal
     */
    private List<Map<String, Object>> toEavRows(
            // rows: 화면 기록행 — 작업 전/종료가 phaseCd 로 섞여 있다
            List<DraftLogRow> rows,
            // cellsType: 계열 칸 DTO
            Class<?> cellsType
    ) {
        List<Map<String, Object>> out = new ArrayList<>();
        int seq = 0;
        for (DraftLogRow row : rows) {
            seq += 1;
            Map<String, Object> one = new LinkedHashMap<>();
            one.put("rowSeq", row.getRowSeq() == null || row.getRowSeq() <= 0 ? seq : row.getRowSeq());
            one.put("phaseCd", DraftSupport.nvl(row.getPhaseCd()));
            one.put("checkTime", DraftSupport.nvl(row.getCheckTime()));
            one.put("productNm", DraftSupport.nvl(row.getProductNm()));
            one.put("equipNm", "");
            one.put("judgeCd", DraftSupport.nvl(row.getJudgeCd()));
            one.put("judgeModYn", DraftSupport.nvl(row.getJudgeModYn()).isEmpty() ? "N" : row.getJudgeModYn());
            one.put("checkerId", DraftSupport.nvl(row.getCheckerId()));
            one.put("checkerNm", DraftSupport.nvl(row.getCheckerNm()));
            one.put("signYn", DraftSupport.nvl(row.getSignYn()).isEmpty() ? "N" : row.getSignYn());
            one.put("cells", toEavCells(row.getCells(), cellsType));
            out.add(one);
        }
        return out;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 계열 DTO 로 알려진 칸을 먼저 받고, 나머지 키도 EAV 로 남긴다
     *   2) 저장 toEavRows 가 호출한다
     *   3) 숫자로 읽히면 numVal, 아니면 txtVal
     */
    private List<Map<String, Object>> toEavCells(
            // raw: 화면 cells 맵
            Map<String, String> raw,
            // cellsType: PkgLogCells 또는 HtgLogCells
            Class<?> cellsType
    ) {
        List<Map<String, Object>> cells = new ArrayList<>();
        if (raw == null) {
            return cells;
        }
        Map<String, Object> typed = objectMapper.convertValue(
                objectMapper.convertValue(raw, cellsType),
                new TypeReference<LinkedHashMap<String, Object>>() { });
        LinkedHashMap<String, String> ordered = new LinkedHashMap<>();
        if (typed != null) {
            for (Map.Entry<String, Object> e : typed.entrySet()) {
                if (e.getValue() == null) {
                    continue;
                }
                ordered.put(e.getKey(), String.valueOf(e.getValue()));
            }
        }
        for (Map.Entry<String, String> e : raw.entrySet()) {
            ordered.putIfAbsent(e.getKey(), DraftSupport.nvl(e.getValue()));
        }
        for (Map.Entry<String, String> cell : ordered.entrySet()) {
            String val = DraftSupport.nvl(cell.getValue());
            Map<String, Object> one2 = new LinkedHashMap<>();
            one2.put("itemCd", cell.getKey());
            if (DraftSupport.isNumeric(val)) {
                one2.put("numVal", val);
                one2.put("txtVal", "");
            } else {
                one2.put("numVal", "");
                one2.put("txtVal", val);
            }
            cells.add(one2);
        }
        return cells;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 지면 하단 4칸을 개선조치로 저장한다
     *   2) 저장 직후 호출한다
     *   3) 부적합(F) 행이 하나라도 있으면 이탈을 자동 생성한다
     */
    private void saveFooter(
            String coCd, Long docIdx, String tmplCd,
            DraftSaveRequest req, List<DraftLogRow> rows
    ) {
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
                coCd, docIdx, tmplCd, req.getBaseDt().trim(), ca, keepCa, LoginUserContext.userId());
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 삭제 가능 여부만 검사한다
     *   2) 확인창 전에 호출한다
     *   3) 전송·결재완료 문서는 차단
     */
    public void validateDelete(
            // store: 계열 매퍼
            CcpMonitorStore store,
            // keys: [{ docIdx }] 객체 배열
            List<DraftDeleteItem> keys
    ) {
        DraftSupport.assertDeletable(keys, (ids) -> store.selectDeleteBlocker(LoginUserContext.coCd(), ids));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 재검증 후 문서·기록행을 삭제한다
     *   2) 삭제 버튼이 호출한다
     *   3) 성공 시 건수
     */
    @Transactional(timeout = 60)
    public int delete(
            // store: 계열 매퍼
            CcpMonitorStore store,
            // keys: [{ docIdx }] 객체 배열
            List<DraftDeleteItem> keys
    ) {
        DraftSupport.assertDeletable(keys, (ids) -> store.selectDeleteBlocker(LoginUserContext.coCd(), ids));
        for (DraftDeleteItem key : keys) {
            store.delete(LoginUserContext.coCd(), key.getDocIdx(), LoginUserContext.userId());
            auditWriter.record(AUDIT_TBL, key.getDocIdx(), "D", null);
        }
        return keys.size();
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) rows_json 을 JSON 배열로 읽는다
     *   2) 상세 조회가 호출한다
     *   3) 비거나 파싱 실패면 빈 배열
     */
    private JsonNode readJson(
            // raw: camelMap 뒤 rowsJson 값
            Object raw
    ) {
        if (raw == null) return objectMapper.createArrayNode();
        if (raw instanceof JsonNode node) return node;
        try {
            if (raw instanceof String s) {
                if (s.isBlank()) return objectMapper.createArrayNode();
                return objectMapper.readTree(s);
            }
            String text = String.valueOf(raw);
            if (text.startsWith("[") || text.startsWith("{")) {
                return objectMapper.readTree(text);
            }
            return objectMapper.valueToTree(raw);
        } catch (JsonProcessingException e) {
            return objectMapper.createArrayNode();
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-07
     * 코멘트:
     *   1) 행의 cells EAV 배열을 지면 맵으로 접는다
     *   2) 상세 조회가 호출한다
     *   3) 이미 맵이면 그대로 둔다. numVal 이 있으면 그걸, 없으면 txtVal
     */
    private JsonNode foldCellsToMap(
            // rows: SP rows_json 배열
            JsonNode rows
    ) {
        if (rows == null || !rows.isArray()) return objectMapper.createArrayNode();
        ArrayNode out = objectMapper.createArrayNode();
        for (JsonNode row : rows) {
            if (!row.isObject()) {
                out.add(row);
                continue;
            }
            ObjectNode one = ((ObjectNode) row).deepCopy();
            JsonNode cells = one.get("cells");
            if (cells != null && cells.isArray()) {
                ObjectNode map = objectMapper.createObjectNode();
                for (JsonNode cell : cells) {
                    String itemCd = cell.path("itemCd").asText("");
                    if (itemCd.isEmpty()) continue;
                    JsonNode num = cell.get("numVal");
                    String numText = (num == null || num.isNull()) ? "" : num.asText("");
                    String txt = cell.path("txtVal").asText("");
                    map.put(itemCd, !numText.isBlank() ? numText : txt);
                }
                one.set("cells", map);
            }
            out.add(one);
        }
        return out;
    }

    /** 저장 문서의 적용 버전 — 자사 양식은 1 고정이라 값이 없으면 1 */
    private static int verNoOf(CcpMonitorDetailRow saved) {
        if (saved == null || saved.getVerNo() == null) return 1;
        return saved.getVerNo();
    }
}
