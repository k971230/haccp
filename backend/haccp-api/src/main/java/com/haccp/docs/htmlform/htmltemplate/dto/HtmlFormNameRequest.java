/**
 * HtmlFormNameRequest — HTML 양식명·사용여부 변경 본문.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 좌 저장이 이름·사용여부가 바뀐 저장행을 커밋할 때 보낸다
 *   2) 표준이면 서버가 거부한다
 *   3) coCd·작업자는 JWT 만 쓴다
 *
 * PIPELINE[HB130] HTML양식 원본 DTO
 */
package com.haccp.docs.htmlform.htmltemplate.dto;

import lombok.Data;

/** 자사 양식명·사용여부 */
@Data
public class HtmlFormNameRequest {
    // 자사 양식코드
    private String tmplCd;
    // 회사 순번. 0 이면 표준
    private Integer verNo;
    // 바꿀 양식명
    private String verNm;
    // 회사 양식 사용여부 Y/N
    private String useYn;
}
