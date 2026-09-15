/**
 * HealthCertDeleteItem — 이력 삭제 키.
 *
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) UI 단건이어도 배열
 *   2) HTTP DELETE 금지
 *   3) idx 만
 *
 * PIPELINE[HB148] 보건증 DTO
 */
package com.haccp.flow.box.healthcert.dto;

import lombok.Data;

@Data
public class HealthCertDeleteItem {
    private Long idx;
}
