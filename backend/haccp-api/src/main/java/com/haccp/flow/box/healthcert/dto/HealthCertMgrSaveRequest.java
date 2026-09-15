/**
 * HealthCertMgrSaveRequest — 담당자 목록 + 알림 일수 저장.
 *
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) 팝업 저장 한 번에 둘 다 반영
 *   2) userIds 가 비면 담당자를 비운다
 *   3) 일수는 양수
 *
 * PIPELINE[HB148] 보건증 DTO
 */
package com.haccp.flow.box.healthcert.dto;

import java.util.List;
import lombok.Data;

@Data
public class HealthCertMgrSaveRequest {
    private List<String> userIds;
    private Integer alarmDay1;
    private Integer alarmDay2;
    private Integer alarmDay3;
}
