/**
 * HtmlFormCopyResult — HTML 양식 복사 결과.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 화면이 새 행을 유지하도록 tmplCd 만 돌려준다
 *   2) JSON 키 tmplCd 는 그대로다
 *   3) 예전 Map.of 와 같은 모양
 *
 * PIPELINE[HB130] HTML양식 원본 DTO
 */
package com.haccp.docs.htmlform.htmltemplate.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/** 복사된 자사 양식코드 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class HtmlFormCopyResult {
    // 새 양식코드 — html_hyg_prc_NNN 등
    private String tmplCd;
}
