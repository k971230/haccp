/**
 * DeptDeleteItem — 부서 삭제 키.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) OPS_DELETE 계약 — UI 단건도 [{ idx }] 배열
 *   2) validate-delete 와 delete 가 같은 타입을 쓴다
 *   3) coCd 는 JWT 에서만 읽는다
 *
 * PIPELINE[HB93] 부서 관리 DTO
 */
package com.haccp.sys.code.department.dto;

import lombok.Data;

@Data
public class DeptDeleteItem {
    // 삭제할 tbl_dept.idx
    private Long idx;
}
