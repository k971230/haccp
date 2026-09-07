/**
 * HwpTemplateRow — 사용양식 목록 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) sp_hwp_template_management_r_000 컬럼과 1:1
 *   2) 조인 컬럼 formFileNm·fileHistCnt 도 필드다
 *   3) 구분 sysYn 은 생성 이후 바꿀 수 없다
 *
 * PIPELINE[HB123] 사용양식 DTO
 */
package com.haccp.docs.hwp.dto;

import lombok.Data;

/** 사용양식 목록 행 */
@Data
public class HwpTemplateRow {
    private String tmplCd;
    private String tmplNm;
    private String sysYn;
    private String docKind;
    private String categoryCd;
    private String mngNo;
    private String formPath;
    private String formFileNm;
    private String useYn;
    private Long defaultFileIdx;
    private Long currentFileIdx;
    private Integer fileHistCnt;
}
