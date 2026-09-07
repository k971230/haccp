/**
 * RoleRow — 권한그룹 목록 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 권한그룹 목록 SP 컬럼과 1:1
 *   2) 조인 컬럼도 필드다
 *   3) 사용자 룩업이 같은 행을 쓴다
 *
 * PIPELINE[HB93] 권한그룹 관리 DTO
 */
package com.haccp.sys.code.role.dto;

import lombok.Data;

@Data
public class RoleRow {
    private Long idx;
    private String usrgrpCd;
    private String usrgrpNm;
    private String descRmk;
    private String useYn;
}
