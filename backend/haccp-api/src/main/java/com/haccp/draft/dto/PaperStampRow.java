/**
 * PaperStampRow — 지면 작성자·승인자 도장.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) sp_tbl_document_paper_stamp_r_000 컬럼과 1:1
 *   2) CCP detail 헤더에 붙인다
 *   3) 문서가 없으면 null
 *
 * PIPELINE[HB135] 양식 작성 공용 DTO
 */
package com.haccp.draft.dto;

import lombok.Data;

/** 지면 도장 1행 */
@Data
public class PaperStampRow {
    private String writerId;
    private String writerNm;
    private String writerSignYn;
    private String approverId;
    private String approverNm;
    private String approverSignYn;
}
