/**
 * DocCycleDetailRow — 문서주기 반복 상세 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) details jsonb 원소와 1:1 — detailTy·val1·val2
 *   2) 예정일 생성기가 같은 키를 읽는다
 *   3) 빈 배열이면 반복 없음
 *
 * PIPELINE[HB99] 문서주기 DTO
 */
package com.haccp.docs.sch.dto;

import lombok.Data;

/** 반복 설정 1건 */
@Data
public class DocCycleDetailRow {
    // 상세 유형
    private String detailTy;
    // 값1
    private Integer val1;
    // 값2
    private Integer val2;
}
