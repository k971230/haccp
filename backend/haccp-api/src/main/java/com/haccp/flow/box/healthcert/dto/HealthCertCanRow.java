/**
 * HealthCertCanRow — 로그인 사용자의 담당·관리 여부와 임박 창.
 *
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) 캘린더·담당자 팝업 버튼을 그릴 때 쓴다
 *   2) expireWindowDays 는 설정 3값의 최댓값
 *   3) JWT actor 기준으로 SP 가 계산한다
 *
 * PIPELINE[HB151] 보건증 DTO
 */
package com.haccp.flow.box.healthcert.dto;

import lombok.Data;

@Data
public class HealthCertCanRow {
    private String mgrYn;
    private String adminYn;
    private Integer expireWindowDays;
    private Integer alarmDay1;
    private Integer alarmDay2;
    private Integer alarmDay3;
}
