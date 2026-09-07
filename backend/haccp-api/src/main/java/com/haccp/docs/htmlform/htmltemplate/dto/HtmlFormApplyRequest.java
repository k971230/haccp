/**
 * HtmlFormApplyRequest — HTML 양식 적용 본문.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 작성 신규가 쓸 적용 버전을 고른다
 *   2) verNo=0 이면 표준
 *   3) coCd·작업자는 JWT 만 쓴다
 *
 * PIPELINE[HB130] HTML양식 원본 DTO
 */
package com.haccp.docs.htmlform.htmltemplate.dto;

import lombok.Data;

/** 작성 신규 적용 버전 */
@Data
public class HtmlFormApplyRequest {
    // 양식코드
    private String tmplCd;
    // 적용 순번. 0 이면 표준
    private Integer verNo;
}
