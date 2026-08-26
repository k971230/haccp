/**
 * DocumentApprovalRequest — 문서 결재 처리 요청.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 상신·검토·승인·반려가 한 계약으로 문서 상태를 전이할 때 사용한다
 *   2) 결재자·회사코드는 본문으로 받지 않고 JWT LoginUserContext에서만 읽는다
 *   3) 반려일 때 opinion을 필수로 검사하는 최종 판단은 SP가 맡는다
 *
 * PIPELINE[HB80] doc DTO
 * PIPELINE[HB72] 연관 모듈
 */
package com.haccp.docs.documents.dto;

// 역할 — Lombok getter/setter
import lombok.Data;

/** 문서 결재 상태 전이 요청 */
@Data
public class DocumentApprovalRequest {
    // 대상 문서 대리키
    private Long docIdx;
    // REQUEST/CANCEL/REVIEW/APPROVE/REJECT 중 하나
    private String actionCd;
    // 결재 의견 — 반려 사유·검토 의견
    private String opinion;
}
