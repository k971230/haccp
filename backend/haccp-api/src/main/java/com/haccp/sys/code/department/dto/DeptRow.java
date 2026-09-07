/**
 * DeptRow — 부서 목록 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 부서 목록 SP 컬럼과 1:1
 *   2) 상위부서명(hDeptNm) 조인 컬럼도 필드다
 *   3) 트리 조립은 화면이 hDeptCd 로 한다
 *
 * PIPELINE[HB93] 부서 관리 DTO
 */
package com.haccp.sys.code.department.dto;

import lombok.Data;

@Data
public class DeptRow {
    private Long idx;
    private String deptCd;
    private String deptNm;
    private String hDeptCd;
    private String hDeptNm;
    private Integer sortNo;
    private String useYn;
}
