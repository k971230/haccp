/**
 * HealthCertMgrRow — 보건증 담당자 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) 담당자 팝업 목록
 *   2) 저장은 userId 배열로 통째 교체
 *   3) 이름은 조인
 *
 * PIPELINE[HB148] 보건증 DTO
 */
package com.haccp.flow.box.healthcert.dto;

import lombok.Data;

@Data
public class HealthCertMgrRow {
    private String userId;
    private String userNm;
    private String deptNm;
}
