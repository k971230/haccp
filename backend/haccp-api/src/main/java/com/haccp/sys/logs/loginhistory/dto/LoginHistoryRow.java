/**
 * LoginHistoryRow — 로그인 이력 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) sp_login_history_r_000 컬럼과 1:1
 *   2) 조인 컬럼 userNm 도 필드다
 *   3) resultCd 는 성공·실패·잠금
 *
 * PIPELINE[HB92] 로그인 이력 DTO
 */
package com.haccp.sys.logs.loginhistory.dto;

import java.time.LocalDateTime;
import lombok.Data;

/** 로그인 이력 행 */
@Data
public class LoginHistoryRow {
    private Long idx;
    private String userId;
    private String userNm;
    private String sid;
    private LocalDateTime loginDt;
    private LocalDateTime logoutDt;
    private String resultCd;
    private String failReason;
    private String ipAddr;
    private String deviceGbn;
}
