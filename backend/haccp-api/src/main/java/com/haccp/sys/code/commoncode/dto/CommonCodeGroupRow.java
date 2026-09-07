/**
 * CommonCodeGroupRow — 공통코드 대분류 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) sp_common_code_management_r_000 컬럼과 1:1
 *   2) 대분류는 sub_cd='*'
 *   3) 표준분은 업체 생성 시 복제된 자기 행이다
 *
 * PIPELINE[HB93] 공통코드 DTO
 */
package com.haccp.sys.code.commoncode.dto;

import lombok.Data;

/** 대분류 목록 행 */
@Data
public class CommonCodeGroupRow {
    private Long idx;
    private String coCd;
    private String mainCd;
    private String subCd;
    private String codeNm;
    private Integer sortNo;
    private String sysYn;
    private String useYn;
}
