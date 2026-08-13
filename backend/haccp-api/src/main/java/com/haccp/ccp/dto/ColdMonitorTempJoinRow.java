/**
 * ColdMonitorTempJoinRow — 헤더 단위 온도 조회용(행 연결키 포함).
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) sp_tbl_ccp_cold_monitor_temp_r_000 결과
 *   2) Service가 rowIdx로 점검행에 temps를 붙인다
 *   3) API 응답에는 ColdMonitorTempCell만 노출한다
 *
 * PIPELINE[HB64] ccp DTO
 */
package com.haccp.ccp.dto;

import java.math.BigDecimal;
import lombok.Data;

@Data
public class ColdMonitorTempJoinRow {
    private Long idx;
    private String coCd;
    private Long rowIdx;
    private Integer rowSeq;
    private String storageCd;
    private BigDecimal tempVal;
    private String judgeCd;
}
