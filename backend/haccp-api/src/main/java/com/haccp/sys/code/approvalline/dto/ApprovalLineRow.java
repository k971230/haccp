/**
 * ApprovalLineRow — 결재선 헤더+단계.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 목록 조회·저장 Body 가 같은 키를 쓴다
 *   2) newYn 은 저장에만 싣는다 — 이 화면은 idx 로 신규를 가르지 않는다
 *   3) SP 가 만든 JSON 을 이 타입으로 읽는다
 *
 * PIPELINE[HB93] 결재선 관리 DTO
 */
package com.haccp.sys.code.approvalline.dto;

import java.util.List;
import lombok.Data;

@Data
public class ApprovalLineRow {
    // 헤더 대리키 — 조회에만 있다
    private Long idx;
    // 결재선 업무키
    private String apprLineCd;
    // 결재선명
    private String apprLineNm;
    // 사용여부 Y/N
    private String useYn;
    // 신규 행 여부 — 저장에만. Y 이면 같은 코드 UPSERT 를 막는다
    private String newYn;
    // 작성·승인 단계
    private List<ApprovalLineStepRow> steps;
}
