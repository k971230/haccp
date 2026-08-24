/**
 * CcpLogDraftPassRow — 금속검출 통과량 표 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) CCP 포장·가열·금속검출 작성 3화면이 같은 DTO 를 쓴다. 화면마다 복제하지 않는다
 *   2) 모양은 HYG(draft.hyg)·CCP검증(draft.ccp)과 같다. 서버 테이블·SP 만 계열별로 다르다
 *   3) MTL 두 번째 표 전용 — 품명·통과량·검출량·특이사항
 *
 * PIPELINE[HB139] CCP 모니터링 작성 DTO
 */
package com.haccp.draft.ccpmonitoring.dto;

import lombok.Data;

@Data
public class CcpLogDraftPassRow {
    // 저장 순번
    private Integer rowSeq;
    // 품명
    private String productNm;
    // 통과량
    private String passQty;
    // 검출량
    private String detectQty;
    // 특이사항 — tbl_ccp_metal_pass_row.remark
    private String remark;
}
