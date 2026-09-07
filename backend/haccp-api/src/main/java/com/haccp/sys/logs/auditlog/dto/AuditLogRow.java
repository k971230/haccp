/**
 * AuditLogRow — 변경 감사 이력 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) sp_audit_log_r_000 컬럼과 1:1
 *   2) beforeJson·afterJson 은 jsonb
 *   3) 조인 컬럼 userNm·menuNm 도 필드다
 *
 * PIPELINE[HB92] 감사 이력 DTO
 */
package com.haccp.sys.logs.auditlog.dto;

import java.time.LocalDateTime;
import lombok.Data;

/** 감사 이력 행 */
@Data
public class AuditLogRow {
    private Long idx;
    private String userId;
    private String userNm;
    private String menuNm;
    private String tblNm;
    private String scrnCd;
    private Long tgtIdx;
    private String actionCd;
    private Object beforeJson;
    private Object afterJson;
    private String reason;
    private String ipAddr;
    private LocalDateTime insDt;
}
