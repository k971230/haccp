/**
 * RoleScreensSaveRequest — 화면권한 저장 본문.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) body { usrgrpCd, rows: [{ scrnCd, readYn }] }
 *   2) JSON 키는 그대로다
 *   3) 그룹코드는 JWT 가 아니라 좌측 선택값
 *
 * PIPELINE[HB93] 권한그룹 DTO
 */
package com.haccp.sys.code.role.dto;

import java.util.List;
import lombok.Data;

/** 화면권한 일괄 저장 */
@Data
public class RoleScreensSaveRequest {
    // 좌측 권한그룹코드
    private String usrgrpCd;
    // 변경 행
    private List<RoleScreenSaveRow> rows;
}
