/**
 * CommonCodeDetailRow — 공통코드 세부 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) sp_common_code_management_r_001 컬럼과 1:1
 *   2) ref1·ref2 는 그룹마다 의미가 다르다
 *   3) sysYn=Y 는 업체가 수정·삭제할 수 없다
 *
 * PIPELINE[HB93] 공통코드 DTO
 */
package com.haccp.sys.code.commoncode.dto;

import lombok.Data;

/** 세부코드 목록 행 */
@Data
public class CommonCodeDetailRow {
    private Long idx;
    private String coCd;
    private String mainCd;
    private String subCd;
    private String codeNm;
    private Integer sortNo;
    private String ref1;
    private String ref2;
    private String sysYn;
    private String useYn;
}
