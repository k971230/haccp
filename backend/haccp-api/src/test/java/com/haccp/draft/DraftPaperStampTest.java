/**
 * DraftPaperStampTest — 지면 도장 헤더 조립.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) SP 행이 헤더에 writer·approver 키로 실리는지 고정한다
 *   2) npm 이 아니라 ./mvnw test 로 실행한다
 *   3) 실패하면 CCP 문서함 미리보기에 이름이 안 찍힌다
 *
 * PIPELINE[HB135] 양식 작성 공용 유틸
 */
package com.haccp.draft;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import com.haccp.draft.dto.HtmlFormDraftHeader;
import com.haccp.draft.dto.PaperStampRow;
import org.junit.jupiter.api.Test;

class DraftPaperStampTest {

    private static PaperStampRow stamp() {
        PaperStampRow row = new PaperStampRow();
        row.setWriterId("hacppt");
        row.setWriterNm("해썹팀원");
        row.setWriterSignYn("Y");
        row.setApproverId("haccpm");
        row.setApproverNm("해썹팀장");
        row.setApproverSignYn("Y");
        return row;
    }

    @Test
    void apply_putsWriterAndApprover() {
        HtmlFormDraftHeader header = new HtmlFormDraftHeader();

        DraftPaperStamp.apply(header, stamp());

        assertEquals("hacppt", header.getWriterId());
        assertEquals("해썹팀원", header.getWriterNm());
        assertEquals("Y", header.getWriterSignYn());
        assertEquals("haccpm", header.getApproverId());
        assertEquals("해썹팀장", header.getApproverNm());
        assertEquals("Y", header.getApproverSignYn());
    }

    @Test
    void apply_fillsCheckerFromWriterWhenEmpty() {
        HtmlFormDraftHeader header = new HtmlFormDraftHeader();
        header.setCheckerNm("");
        PaperStampRow row = stamp();
        row.setWriterSignYn("N");
        row.setApproverSignYn("N");

        DraftPaperStamp.apply(header, row);

        assertEquals("해썹팀원", header.getCheckerNm());
        assertEquals("hacppt", header.getCheckerId());
    }

    @Test
    void apply_keepsExistingChecker() {
        HtmlFormDraftHeader header = new HtmlFormDraftHeader();
        header.setCheckerNm("점검담당");
        PaperStampRow row = new PaperStampRow();
        row.setWriterNm("해썹팀원");
        row.setApproverNm("해썹팀장");

        DraftPaperStamp.apply(header, row);

        assertEquals("점검담당", header.getCheckerNm());
    }

    @Test
    void apply_nullDoesNothing() {
        HtmlFormDraftHeader header = new HtmlFormDraftHeader();
        DraftPaperStamp.apply(header, null);
        assertNull(header.getWriterNm());
    }
}
