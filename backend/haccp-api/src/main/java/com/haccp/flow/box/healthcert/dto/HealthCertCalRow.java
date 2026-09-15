/**
 * HealthCertCalRow — 캘린더 만료 1건.
 *
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) 사원별 최신 이력의 만료일만
 *   2) 담당자만 조회
 *   3) 월 구간 from~to
 *
 * PIPELINE[HB148] 보건증 DTO
 */
package com.haccp.flow.box.healthcert.dto;

import lombok.Data;

@Data
public class HealthCertCalRow {
    private String userId;
    private String userNm;
    private String expireDt;
}
