/**
 * UserRow — 사용자 목록 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) sp_user_management_r_000 컬럼과 1:1
 *   2) 비밀번호 해시는 목록에 없다. 서명은 보유여부만
 *   3) 조인 컬럼 usrgrpNm·deptNm 도 필드다
 *
 * PIPELINE[HB93] 사용자 관리 DTO
 */
package com.haccp.sys.code.user.dto;

import java.time.LocalDateTime;
import lombok.Data;

@Data
public class UserRow {
    private Long idx;
    private String userId;
    private String coCd;
    private String empCd;
    private String userNm;
    private String usrgrpCd;
    private String usrgrpNm;
    private String deptCd;
    private String deptNm;
    private String email;
    private String mobile;
    private String signYn;
    private String gridsaveYn;
    private LocalDateTime lastLoginDt;
    private Integer loginFailCnt;
    private String lockYn;
    private String useYn;
}
