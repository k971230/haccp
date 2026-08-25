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
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
import com.haccp.draft.DraftSupport;
import com.haccp.docs.ccp.dto.DocCorrectiveDto;
import com.haccp.draft.dto.DraftDeleteItem;
import com.haccp.draft.dto.DraftFormRow;
import com.haccp.draft.dto.DraftListRow;
import com.haccp.draft.dto.DraftLogRow;
import com.haccp.draft.dto.DraftSaveRequest;
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
    public List<DraftFormRow> forms(
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
    public List<DraftListRow> list(
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
                LoginUserContext.coCd(), family.prefix(), DraftSupport.nvl(tmplCd), DraftSupport.nvl(tmplNm),
                DraftSupport.nvl(fromDt), DraftSupport.nvl(toDt), DraftSupport.nvl(writerId), DraftSupport.nvl(writerNm));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) 헤더·양식항목·기록행·개선조치를 한 JSON 으로 조립한다
     *   2) 좌측 행 클릭·양식 선택이 호출한다
     *   3) MyBatis Map 은 camelMap 한 뒤 읽는다. cells EAV 배열은 지면 맵으로 접는다
     */
    public JsonNode detail(
            // family: 포장·가열 구분
            Family family,
            // tmplCd: 신규일 때 항목을 깔 양식코드. 필수
            String tmplCd,
            // docIdx: tbl_document.idx. null·0 이면 신규
            Long docIdx
    ) {
        String tmpl = DraftSupport.requireUsrTmpl(tmplCd, family.prefix(), family.std());
        String coCd = LoginUserContext.coCd();
        ObjectNode root = objectMapper.createObjectNode();
        ObjectNode header = objectMapper.createObjectNode();

        Map<String, Object> saved = (docIdx != null && docIdx > 0)
                ? DraftSupport.camelMap(mapper.selectDetail(coCd, docIdx))
                : null;
        // 저장된 문서일 때(= docIdx 있음) 헤더·기록행을 서버 값으로 채운다
        if (saved != null) {
            header.put("docIdx", DraftSupport.asLong(saved.get("docIdx")));
            header.put("docNo", DraftSupport.asText(saved.get("docNo")));
            header.put("status", DraftSupport.asText(saved.get("status")));
            header.put("baseDt", DraftSupport.asText(saved.get("baseDt")));
            header.put("tmplCd", DraftSupport.asText(saved.get("tmplCd")));
            header.put("checkerNm", DraftSupport.asText(saved.get("mngNm")));
            // SP cells 는 EAV 배열 — 지면은 itemCd → 값 맵. 저장 toGenericRows 의 역변환
            root.set("logRows", foldCellsToMap(readJson(saved.get("rowsJson"))));
        } else {
            header.putNull("docIdx");
            header.put("docNo", "");
            header.putNull("status");
            header.put("baseDt", "");
            header.put("tmplCd", tmpl);
            header.put("checkerNm", "");
            // 신규 — 구간별 라벨 행 1줄씩 깔아 준다. 행이 0건이면 좌측 저장 SP 가 막는다
            root.set("logRows", objectMapper.valueToTree(DraftSupport.seedLogRows("BEFORE", "AFTER")));
        }
        // 양식 항목 — 한계기준·주기·방법·개선조치. Map 도 camelCase 로 맞춘다
        root.set("items", objectMapper.valueToTree(DraftSupport.camelMaps(
                mapper.selectFormItems(coCd, family.key(), tmpl, saved == null ? 1 : verNoOf(saved)))));
        // 지면 하단 4칸 — 저장할 컬럼이 없어 개선조치 테이블에서 읽는다
        DocCorrectiveDto ca = (docIdx != null && docIdx > 0) ? correctiveSupport.load(coCd, docIdx) : null;
        header.put("specialNote", ca == null ? "" : DraftSupport.nvl(ca.getDeviationDesc()));
        header.put("improveNote", ca == null ? "" : DraftSupport.nvl(ca.getActionDesc()));
        header.put("actionNm", ca == null ? "" : DraftSupport.nvl(ca.getActionUserNm()));
        header.put("confirmNm", ca == null ? "" : DraftSupport.nvl(ca.getConfirmUserNm()));
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
            DraftSaveRequest req
    ) {
        if (req == null || DraftSupport.nvl(req.getBaseDt()).length() != 8) {
            throw new BizException("일자를 입력하세요.");
        }
        String tmpl = DraftSupport.requireUsrTmpl(req.getTmplCd(), family.prefix(), family.std());
        List<DraftLogRow> rows = req.getLogRows() == null ? List.of() : req.getLogRows();
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
                    DraftSupport.nvl(req.getCheckerNm()),
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
            List<DraftLogRow> rows
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
            List<Map<String, Object>> cells = new ArrayList<>();
            if (row.getCells() != null) {
                for (Map.Entry<String, String> cell : row.getCells().entrySet()) {
                    String val = DraftSupport.nvl(cell.getValue());
                    Map<String, Object> one2 = new LinkedHashMap<>();
                    one2.put("itemCd", cell.getKey());
                    // 숫자로 읽히면 numVal, 아니면 txtVal — 지면 온도·분·초는 숫자다
                    if (DraftSupport.isNumeric(val)) {
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
            List<DraftDeleteItem> keys
    ) {
        DraftSupport.assertDeletable(keys, (ids) -> mapper.selectDeleteBlocker(LoginUserContext.coCd(), ids));
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
            List<DraftDeleteItem> keys
    ) {
        DraftSupport.assertDeletable(keys, (ids) -> mapper.selectDeleteBlocker(LoginUserContext.coCd(), ids));
        for (DraftDeleteItem key : keys) {
            mapper.delete(LoginUserContext.coCd(), key.getDocIdx(), LoginUserContext.userId());
        }
        return keys.size();
    }


    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) rows_json 을 JSON 배열로 읽는다. SP 가 문자열·PGobject 둘 다 줄 수 있다
     *   2) 상세 조회가 호출한다
     *   3) 비거나 파싱 실패면 빈 배열 — 지면이 시드 없이 미리보기로 떨어지지 않게 호출부가 본다
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
            // PGobject.toString 이 jsonb 본문이다. valueToTree 하면 타입 래퍼가 나와 행이 비다
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
     * 일자: 2026-08-25
     * 코멘트:
     *   1) 행의 cells EAV 배열을 지면 맵으로 접는다 — toGenericRows 의 역변환
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
            // 배열일 때(= SP EAV) 맵으로 접는다. 맵이면 이미 지면 계약
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
    private static int verNoOf(Map<String, Object> saved) {
        Object v = saved.get("verNo");
        if (v == null) return 1;
        try {
            return Integer.parseInt(String.valueOf(v));
        } catch (NumberFormatException e) {
            return 1;
        }
    }
}
