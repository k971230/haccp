/**
 * HealthCertEmpRow — 보건증 대상 사원 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) 좌측 목록. 최신 만료일과 이력 건수
 *   2) 담당자면 대상 전원, 아니면 본인만
 *   3) 임박 필터는 SP 가 설정 N일을 쓴다
 *
 * PIPELINE[HB148] 보건증 DTO
 */
package com.haccp.flow.box.healthcert.dto;

import lombok.Data;

@Data
public class HealthCertEmpRow {
    private String userId;
    private String userNm;
    private String deptCd;
    private String deptNm;
    private String expireDt;
    private Integer histCnt;
}
