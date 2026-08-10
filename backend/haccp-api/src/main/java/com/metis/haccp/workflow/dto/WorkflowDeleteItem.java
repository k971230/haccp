/**
 * WorkflowDeleteItem — 워크플로 관리 삭제 업무키.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 결재선은 apprLineCd, 작성주기는 idx, 점검항목은 tmplCd+itemCd를 객체 배열로 전달한다
 *   2) HTTP DELETE와 스칼라 배열을 쓰지 않아 복합 업무키 확장에 대비한다
 *   3) coCd와 작업자 정보는 이 DTO에 두지 않고 LoginUserContext에서만 읽는다
 *
 * PIPELINE[HB90] 워크플로 삭제 DTO
 * PIPELINE[HB88, HB91] 연관 모듈
 */
package com.metis.haccp.workflow.dto;

// 역할 — Lombok 접근자
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class WorkflowDeleteItem {
    // 결재선 삭제 업무키 — schedule API에서는 null
    private String apprLineCd;
    // 작성주기 삭제 대리키 — approval-line API에서는 null
    private Long idx;
    // 회사 사용양식·점검항목 삭제 업무키 — company-templates / company-check-items
    private String tmplCd;
    // 점검항목 삭제 업무키 — company-check-items API에서만 사용 (tmplCd와 쌍)
    private String itemCd;
}
