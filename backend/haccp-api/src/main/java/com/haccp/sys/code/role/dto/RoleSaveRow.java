/**
 * RoleSaveRow — 권한그룹 저장 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 화면 그리드 camelCase 키를 그대로 받는다
 *   2) Map 대신 타입을 고정한다
 *   3) coCd·작업자는 JWT 만
 *
 * PIPELINE[HB93] 권한그룹 관리 DTO
 */
package com.haccp.sys.code.role.dto;

import lombok.Data;

@Data
public class RoleSaveRow {
    // tbl_role.idx — 없으면 신규
    private Long idx;
    // 권한그룹코드
    private String usrgrpCd;
    // 권한그룹명
    private String usrgrpNm;
    // 설명
    private String descRmk;
    // 사용여부 Y/N
    private String useYn;
}
