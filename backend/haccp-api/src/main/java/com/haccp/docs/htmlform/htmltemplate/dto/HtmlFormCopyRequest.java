/**
 * HtmlFormCopyRequest — HTML 양식 복사 본문.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 좌 저장이 pending 행을 커밋할 때 보낸다
 *   2) verNm 은 필수. 번호는 SP 가 채번한다
 *   3) coCd·작업자는 JWT 만 쓴다
 *
 * PIPELINE[HB130] HTML양식 원본 DTO
 */
package com.haccp.docs.htmlform.htmltemplate.dto;

import lombok.Data;

/** 표준 시드 복사 요청 */
@Data
public class HtmlFormCopyRequest {
    // 가족 양식코드 — html_hyg_prc_000 등
    private String tmplCd;
    // 호환. 행추가는 표준만
    private Integer srcVerNo;
    // 호환. 번호는 SP 가 채번
    private String verCd;
    // 양식명 — 필수
    private String verNm;
}
