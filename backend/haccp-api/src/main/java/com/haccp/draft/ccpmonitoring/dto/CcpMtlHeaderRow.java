/**
 * CcpMtlHeaderRow — 금속검출 헤더 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) sp_tbl_ccp_metal_monitor_r_001 컬럼과 1:1
 *   2) hdrIdx 로 감도·통과량 표를 읽는다
 *   3) 없으면 신규
 *
 * PIPELINE[HB140] CCP 금속검출 작성 DTO
 */
package com.haccp.draft.ccpmonitoring.dto;

import java.math.BigDecimal;
import lombok.Data;

/** 금속검출 헤더 */
@Data
public class CcpMtlHeaderRow {
    private Long docIdx;
    private Long hdrIdx;
    private String docNo;
    private String baseDt;
    private String ccpCd;
    private BigDecimal feSize;
    private BigDecimal stsSize;
    private String mngUserId;
    private String mngNm;
    private String status;
}
