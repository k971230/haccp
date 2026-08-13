/**
 * DeleteBlocker — 삭제 참조 차단 결과 DTO.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) Mapper 단일 IN 검증이 돌려준 첫 차단 행을 담는다
 *   2) Service assertDeletable에서 DeleteValidation.throwIfBlocked에 넘긴다
 *   3) refKey·target 별칭은 MyBatis mapUnderscoreToCamelCase와 맞춰 camelCase로 둔다
 *
 * PIPELINE[HB50] common 모듈
 * PIPELINE[HB51] 연관 모듈
 */
package com.haccp.common.validation;

// 역할 — getter/setter
import lombok.Data;

/** 삭제 불가 참조 1건 — refKey(업무키)·target(참조·잠금 사유) */
@Data
public class DeleteBlocker {
    // 차단된 삭제 대상 키 — 문서번호 등 사용자에게 보여줄 값
    private String refKey;
    // 차단 사유·참조 대상 표시명 — 사용자 메시지 {target}
    private String target;
}
