/**
 * HtmlFormVersionRow — HTML 양식 버전 목록 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) sp_tbl_html_*_ver_r_000 컬럼과 1:1
 *   2) 표준 가상행은 idx 가 비어 올 수 있다
 *   3) 다섯 가족이 같은 행을 쓴다
 *
 * PIPELINE[HB130] HTML양식 원본 DTO
 */
package com.haccp.docs.htmlform.htmltemplate.dto;

import lombok.Data;

/** 예시+자사 양식 1건 */
@Data
public class HtmlFormVersionRow {
    private Long idx;
    private String tmplCd;
    private Integer verNo;
    private String verCd;
    private String verNm;
    private String sysYn;
    private String applyYn;
    private String lockedYn;
    private String insNm;
    private String insDt;
    private String useYn;
}
