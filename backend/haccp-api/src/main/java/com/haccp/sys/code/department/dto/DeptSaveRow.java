/**
 * DeptSaveRow — 부서 저장 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 화면 그리드 camelCase 키를 그대로 받는다
 *   2) Map 대신 타입을 고정한다
 *   3) coCd·작업자는 JWT 만
 *
 * PIPELINE[HB93] 부서 관리 DTO
 */
package com.haccp.sys.code.department.dto;

import lombok.Data;

@Data
public class DeptSaveRow {
    // tbl_dept.idx — 없으면 신규
    private Long idx;
    // 부서코드
    private String deptCd;
    // 부서명
    private String deptNm;
    // 상위부서코드
    private String hDeptCd;
    // 정렬순서
    private Integer sortNo;
    // 사용여부 Y/N
    private String useYn;
}
