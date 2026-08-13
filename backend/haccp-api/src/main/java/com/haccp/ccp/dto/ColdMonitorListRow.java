/**
 * ColdMonitorListRow — CCP 냉장보관 일지 목록 행.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) sp_tbl_ccp_cold_monitor_r_000 결과
 *   2) ngCnt > 0이면(= 부적합 행 있음) 목록에서 강조한다
 *   3) docIdx로 상세를 연다
 *
 * PIPELINE[HB62] ccp DTO
 */
package com.haccp.ccp.dto;

import java.time.LocalDateTime;
import lombok.Data;

@Data
public class ColdMonitorListRow {
    private Long docIdx;
    private Long hdrIdx;
    private String coCd;
    private String docNo;
    private String baseDt;
    private String ccpCd;
    private String title;
    private String status;
    private String mngUserId;
    private String mngNm;
    private String writerId;
    private LocalDateTime writeDt;
    private Integer rowCnt;
    private Integer ngCnt;
}
