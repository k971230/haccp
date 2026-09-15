/**
 * HealthCertAlarmRow — 만료 알림 일수 3값.
 *
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) 기본 30·7·1. 담당자가 숫자를 고친다
 *   2) 임박 필터는 이 셋의 최댓값
 *   3) 크론이 같은 값을 본다
 *
 * PIPELINE[HB148] 보건증 DTO
 */
package com.haccp.flow.box.healthcert.dto;

import lombok.Data;

@Data
public class HealthCertAlarmRow {
    private Integer alarmDay1;
    private Integer alarmDay2;
    private Integer alarmDay3;
}
