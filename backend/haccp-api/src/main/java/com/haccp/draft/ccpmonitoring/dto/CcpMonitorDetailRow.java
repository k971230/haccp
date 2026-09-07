/**
 * CcpMonitorDetailRow — 포장·가열 모니터 상세 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) sp_tbl_ccp_pkg/htg_monitor_r_000 컬럼과 1:1
 *   2) rowsJson 은 기록행·셀 EAV
 *   3) verNo 는 없으면 1
 *
 * PIPELINE[HB93] Map API DTO
 */
package com.haccp.draft.ccpmonitoring.dto;

import lombok.Data;

@Data
public class CcpMonitorDetailRow {
    // 문서 idx
    private Long docIdx;
    // 문서번호
    private String docNo;
    // 상태
    private String status;
    // 기준일
    private String baseDt;
    // 양식코드
    private String tmplCd;
    // CCP 코드
    private String ccpCd;
    // 일지번호
    private String diaryNo;
    // 한계항목
    private String limitItemKind;
    // 관리자 ID
    private String mngUserId;
    // 관리자·점검자명
    private String mngNm;
    // 기록행 jsonb
    private Object rowsJson;
    // 적용 버전 — 없으면 1
    private Integer verNo;
}
