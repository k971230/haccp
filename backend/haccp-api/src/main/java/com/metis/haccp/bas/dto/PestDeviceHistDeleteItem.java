/**
 * PestDeviceHistDeleteItem — 방충설비 이력 삭제 키.
 *
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) UI 단건 삭제도 [{ idx }] 배열로 받아 OPS_DELETE 계약을 지킨다
 *   2) idx는 테넌트 범위 SP 조건과 함께만 사용한다
 *   3) validate-delete와 delete가 같은 DTO를 사용해 검증 차이를 없앤다
 *
 * PIPELINE[HB97] 설비이력 DTO
 * PIPELINE[HB94, HB95, HB96] 연관 모듈
 */
package com.metis.haccp.bas.dto;

// 역할 — getter/setter
import lombok.Data;

/** 방충설비 이력 삭제 요청의 대리키 객체다. */
@Data
public class PestDeviceHistDeleteItem {
    // 삭제 대상 대리키 — 0 이하이면 Service가 업무 오류로 차단
    private Long idx;
}
