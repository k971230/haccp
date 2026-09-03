/**
 * DraftPaperStampTest — 지면 도장 헤더 조립.
 *
 * 개발자: 박승우
 * 일자: 2026-08-31
 * 코멘트:
 *   1) SP 행이 헤더에 writer·approver 키로 실리는지 고정한다
 *   2) npm 이 아니라 ./mvnw test 로 실행한다
 *   3) 실패하면 CCP 문서함 미리보기에 이름이 안 찍힌다
 *
 * PIPELINE[HB135] 양식 작성 공용 유틸
 */
package com.haccp.draft;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import java.util.LinkedHashMap;
import java.util.Map;
import org.junit.jupiter.api.Test;

class DraftPaperStampTest {

    @Test
    void apply_putsWriterAndApprover() {
        ObjectNode header = new ObjectMapper().createObjectNode();
        Map<String, Object> stamp = new LinkedHashMap<>();
        stamp.put("writer_id", "hacppt");
        stamp.put("writer_nm", "해썹팀원");
        stamp.put("writer_sign_yn", "Y");
        stamp.put("approver_id", "haccpm");
        stamp.put("approver_nm", "해썹팀장");
        stamp.put("approver_sign_yn", "Y");

        DraftPaperStamp.apply(header, stamp);

        assertEquals("hacppt", header.get("writerId").asText());
        assertEquals("해썹팀원", header.get("writerNm").asText());
        assertEquals("Y", header.get("writerSignYn").asText());
        assertEquals("haccpm", header.get("approverId").asText());
        assertEquals("해썹팀장", header.get("approverNm").asText());
        assertEquals("Y", header.get("approverSignYn").asText());
    }

    @Test
    void apply_fillsCheckerFromWriterWhenEmpty() {
        ObjectNode header = new ObjectMapper().createObjectNode();
        header.put("checkerNm", "");
        Map<String, Object> stamp = new LinkedHashMap<>();
        stamp.put("writer_id", "hacppt");
        stamp.put("writer_nm", "해썹팀원");
        stamp.put("writer_sign_yn", "N");
        stamp.put("approver_id", "haccpm");
        stamp.put("approver_nm", "해썹팀장");
        stamp.put("approver_sign_yn", "N");

        DraftPaperStamp.apply(header, stamp);

        assertEquals("해썹팀원", header.get("checkerNm").asText());
        assertEquals("hacppt", header.get("checkerId").asText());
    }

    @Test
    void apply_keepsExistingChecker() {
        ObjectNode header = new ObjectMapper().createObjectNode();
        header.put("checkerNm", "점검담당");
        Map<String, Object> stamp = new LinkedHashMap<>();
        stamp.put("writer_nm", "해썹팀원");
        stamp.put("approver_nm", "해썹팀장");

        DraftPaperStamp.apply(header, stamp);

        assertEquals("점검담당", header.get("checkerNm").asText());
    }

    @Test
    void apply_nullDoesNothing() {
        ObjectNode header = new ObjectMapper().createObjectNode();
        DraftPaperStamp.apply(header, null);
        assertFalse(header.has("writerNm"));
    }
}
