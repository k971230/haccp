/**
 * HtmlFormDraftHeader — 작성 상세 header.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) FE HtmlFormDraftDetail.header 키와 1:1
 *   2) HTML 작성 SP 와 CCP 모니터가 같은 칸을 쓴다
 *   3) 없는 키는 null 로 나간다
 *
 * PIPELINE[HB135] 양식 작성 공용 DTO
 */
package com.haccp.draft.dto;

import lombok.Data;

/** 작성 지면 헤더 */
@Data
public class HtmlFormDraftHeader {
    private Long docIdx;
    private String docNo;
    private String tmplCd;
    private String tmplNm;
    private String status;
    private String baseDt;
    private String checkerNm;
    private String checkerId;
    private String checkerSignYn;
    private String approverNm;
    private String approverId;
    private String approverSignYn;
    private Integer verNo;
    private String specialNote;
    private String improveNote;
    private String actionNm;
    private String confirmNm;
    private String confirmId;
    private String confirmSignYn;
    private String writerNm;
    private String writerId;
    private String writerSignYn;
}
