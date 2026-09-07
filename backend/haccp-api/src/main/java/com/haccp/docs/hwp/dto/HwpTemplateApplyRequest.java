/**
 * HwpTemplateApplyRequest — 사용양식 불러오기·초기화 본문.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 화면이 보내는 camelCase 키 — tmplCd·fileIdx
 *   2) fileIdx 가 없으면 초기화다
 *   3) coCd·작업자는 JWT 만 쓴다
 *
 * PIPELINE[HB123] 사용양식 DTO
 */
package com.haccp.docs.hwp.dto;

import lombok.Data;

/** 이력 적용 또는 기본 제공본 복원 */
@Data
public class HwpTemplateApplyRequest {
    // 적용 대상 양식코드
    private String tmplCd;
    // 적용할 이력 idx — 없으면 초기화
    private Long fileIdx;
}
