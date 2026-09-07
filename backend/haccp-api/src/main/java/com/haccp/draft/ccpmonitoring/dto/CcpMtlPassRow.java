/**
 * CcpMtlPassRow — 금속검출 통과량 표 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) sp_tbl_ccp_metal_monitor_r_003 컬럼과 1:1
 *   2) 상세에서 DraftPassRow 로 옮긴다
 *   3) 없으면 빈 목록
 *
 * PIPELINE[HB140] CCP 금속검출 작성 DTO
 */
package com.haccp.draft.ccpmonitoring.dto;

import java.math.BigDecimal;
import lombok.Data;

/** 통과량 행 */
@Data
public class CcpMtlPassRow {
    private Long idx;
    private Integer rowSeq;
    private String productCd;
    private String productNm;
    private BigDecimal passQty;
    private BigDecimal detectQty;
    private String unitNm;
    private String remark;
}
