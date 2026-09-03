/**
 * HtmlFormVerDeleteItem — HTML 양식 버전 삭제 키.
 *
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) Body는 [{ tmplCd, verNo }] 객체 배열이다. 표준(000·시드)은 Service가 막는다
 *   2) 회사코드는 JWT에서만 읽는다
 *   3) HTTP DELETE는 쓰지 않는다. 실제 삭제는 use_yn=N
 *
 * PIPELINE[HB130] HTML양식 원본 DTO
 */
package com.haccp.docs.htmlform.htmltemplate.dto;

import lombok.Data;

@Data
public class HtmlFormVerDeleteItem {
    // 양식코드 — html_hyg_prc_001·html_ccp_chk_001 등. 예시는 *_000
    private String tmplCd;
    // 회사 버전번호 — 1 이상
    private Integer verNo;
}
