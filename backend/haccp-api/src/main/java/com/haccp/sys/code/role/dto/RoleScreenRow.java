/**
 * RoleScreenRow — 권한그룹 화면권한 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) sp_role_management_screen_r_000 컬럼과 1:1
 *   2) 미설정 화면도 N 으로 내려온다
 *   3) 로그인 버튼 권한과 같은 SP 다
 *
 * PIPELINE[HB93] 권한그룹 DTO
 */
package com.haccp.sys.code.role.dto;

import lombok.Data;

/** 화면권한 목록 행 */
@Data
public class RoleScreenRow {
    private Long idx;
    private String scrnCd;
    private String scrnNm;
    private String moduleCd;
    private String readYn;
    private String writeYn;
    private String modifyYn;
    private String deleteYn;
    private String printYn;
    private Integer sortNo;
}
