/**
 * DraftPassRow — 금속검출 통과량 표 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) CCP 포장·가열·금속검출 작성 3화면이 같은 DTO 를 쓴다. 화면마다 복제하지 않는다
 *   2) MTL 두 번째 표 전용 — 품명·통과량·검출량·특이사항
 *   3) 기본 4행은 지면이 깔고, 「제품 통과 행 추가」로 만든 행만 삭제 버튼이 붙는다
 *
 * FE 대응 타입은 components/form/htmlFormPaperShared.tsx 의 HtmlFormPassRow 다.
 *
 * PIPELINE[HB139] CCP 모니터링 작성 DTO
 */
package com.haccp.draft.dto;

import lombok.Data;

@Data
public class DraftPassRow {
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
