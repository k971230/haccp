/**
 * DraftPaperStamp — 지면 작성자·승인자 칸을 detail 헤더에 붙인다.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) CCP 포장·가열·금속 detail 이 checkerNm 만 넣고 도장 필드를 빼 문서함이 비었다
 *   2) hyg·ccp-verify 와 같은 출처(sp_tbl_document_paper_stamp_r_000)를 헤더에 싣는다
 *   3) 점검자 칸이 비면 작성자명을 넣는다. 스탬프 행이 없으면 헤더를 건드리지 않는다
 *
 * PIPELINE[HB135] 양식 작성 공용 유틸
 */
package com.haccp.draft;

import com.fasterxml.jackson.databind.node.ObjectNode;
import java.util.Map;

public final class DraftPaperStamp {

    private DraftPaperStamp() {
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-03
     * 코멘트:
     *   1) SP 한 행을 camelCase 로 헤더에 넣는다
     *   2) CCP detail 이 저장된 문서를 조립할 때 호출한다
     *   3) 점검자가 비어 있을 때(= mngNm 없음) 작성자명을 넣는다. stamp 가 null·비면 아무 것도 안 한다
     */
    public static void apply(
            // header: detail JSON 의 header 노드
            ObjectNode header,
            // stamp: sp_tbl_document_paper_stamp_r_000 한 행(snake 또는 camel)
            Map<String, Object> stamp
    ) {
        // 문서가 없을 때(= 신규·조회 실패) 칸을 비워 두지 말고 그냥 둔다
        if (stamp == null || stamp.isEmpty()) {
            return;
        }
        Map<String, Object> row = DraftSupport.camelMap(stamp);
        String writerId = DraftSupport.asText(row.get("writerId"));
        String writerNm = DraftSupport.asText(row.get("writerNm"));
        header.put("writerId", writerId);
        header.put("writerNm", writerNm);
        header.put("writerSignYn", signYn(row.get("writerSignYn")));
        header.put("approverId", DraftSupport.asText(row.get("approverId")));
        header.put("approverNm", DraftSupport.asText(row.get("approverNm")));
        header.put("approverSignYn", signYn(row.get("approverSignYn")));
        // 점검자 칸이 비었을 때(= CCP 헤더에 점검자 컬럼이 없거나 빈 값) 작성자와 같은 이름을 쓴다
        String checkerNm = "";
        if (header.has("checkerNm") && !header.get("checkerNm").isNull()) {
            checkerNm = header.get("checkerNm").asText("");
        }
        if (checkerNm.isBlank() && !writerNm.isBlank()) {
            header.put("checkerNm", writerNm);
            String checkerId = "";
            if (header.has("checkerId") && !header.get("checkerId").isNull()) {
                checkerId = header.get("checkerId").asText("");
            }
            if (checkerId.isBlank() && !writerId.isBlank()) {
                header.put("checkerId", writerId);
            }
        }
    }

    private static String signYn(Object raw) {
        String v = DraftSupport.asText(raw);
        return "Y".equalsIgnoreCase(v) ? "Y" : "N";
    }
}
