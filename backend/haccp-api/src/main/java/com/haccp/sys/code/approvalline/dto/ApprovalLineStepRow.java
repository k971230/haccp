/**
 * ApprovalLineStepRow — 결재선 단계 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) SP JSON 키와 같은 camelCase
 *   2) 역할은 WRITE·APPROVE 고정 2단
 *   3) 결재자는 비어 있어도 저장된다 — 첫 저장에서 줄을 만들기 위함
 *
 * PIPELINE[HB93] 결재선 관리 DTO
 */
package com.haccp.sys.code.approvalline.dto;

import lombok.Data;

@Data
public class ApprovalLineStepRow {
    // 단계 대리키 — 조회에만 있다
    private Long idx;
    // 단계 순번 — 1작성 2승인
    private Integer stepNo;
    // 역할코드 WRITE/APPROVE
    private String roleCd;
    // 결재자 로그인 아이디 — 비어 있어도 저장
    private String approverId;
    // 결재자명 — 조회 조인
    private String approverNm;
    // 결재자 부서코드
    private String deptCd;
    // 결재자 부서명 — 조회 조인
    private String deptNm;
    // 사용여부 Y/N
    private String useYn;
}
