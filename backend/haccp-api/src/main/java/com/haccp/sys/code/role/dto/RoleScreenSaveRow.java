/**
 * RoleScreenSaveRow — 화면권한 저장 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 트리 체크 후 보내는 행 — scrnCd·readYn
 *   2) 조회권한이 Y 가 아니면 5권한 전부 N
 *   3) coCd·작업자는 JWT 만 쓴다
 *
 * PIPELINE[HB93] 권한그룹 DTO
 */
package com.haccp.sys.code.role.dto;

import lombok.Data;

/** 화면 조회권한 변경 */
@Data
public class RoleScreenSaveRow {
    // 화면코드
    private String scrnCd;
    // 조회권한 Y/N
    private String readYn;
}
