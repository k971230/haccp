/**
 * ApprovalLineDeleteItem — 결재선 삭제 업무키.
 *
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 왼쪽 삭제 버튼이 [{ apprLineCd }] 배열을 보낸다
 *   2) HTTP DELETE·스칼라 배열 금지
 *   3) coCd·작업자는 이 DTO에 두지 않는다
 *
 * PIPELINE[HB90] 결재선 삭제 DTO
 */
package com.haccp.sys.approvalline.dto;

// 역할 — Lombok 접근자
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class ApprovalLineDeleteItem {
    // 결재선 업무키 — UI 단건이어도 배열 원소 1건
    private String apprLineCd;
}
