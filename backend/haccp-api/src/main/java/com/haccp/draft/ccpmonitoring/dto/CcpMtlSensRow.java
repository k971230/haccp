/**
 * CcpMtlSensRow — 금속검출 감도 표 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) sp_tbl_ccp_metal_monitor_r_002 컬럼과 1:1
 *   2) phaseCd 로 작업 전/후를 가른다
 *   3) 5칸 O/X 는 상세에서 cells 로 접는다
 *
 * PIPELINE[HB140] CCP 금속검출 작성 DTO
 */
package com.haccp.draft.ccpmonitoring.dto;

import lombok.Data;

/** 감도 행 */
@Data
public class CcpMtlSensRow {
    private Long idx;
    private Integer rowSeq;
    private String phaseCd;
    private String productCd;
    private String productNm;
    private String checkTime;
    private String feOnlyCd;
    private String stsOnlyCd;
    private String prodOnlyCd;
    private String feProdCd;
    private String stsProdCd;
    private String judgeCd;
    private String judgeModYn;
    private String checkerId;
    private String checkerNm;
}
