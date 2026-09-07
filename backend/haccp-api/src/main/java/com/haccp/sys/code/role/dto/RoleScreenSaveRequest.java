/**
 * RoleScreenSaveRequest — 화면권한 저장 본문.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 컨트롤러 Body { usrgrpCd, rows }
 *   2) JSON 키를 바꾸지 않는다
 *   3) 그룹코드가 비면 서비스가 막는다
 *
 * PIPELINE[HB93] Map API DTO
 */
package com.haccp.sys.code.role.dto;

import lombok.Data;

@Data
public class RoleScreenSaveRequest {
    // 권한그룹코드
    private String usrgrpCd;
    // 변경 행
    private java.util.List<RoleScreenSaveRow> rows;
}
