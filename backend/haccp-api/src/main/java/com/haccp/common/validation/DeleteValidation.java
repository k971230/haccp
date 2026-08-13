/**
 * DeleteValidation — 삭제 검증 공통 유틸.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) validate-delete·delete 양쪽 Double Check에서 같은 문구·같은 검사를 쓰게 한다
 *   2) mes-api DeleteValidation을 haccp 패키지로 옮겼다 — Str.nvl 의존은 제거했다
 *   3) 참조 차단 메시지는 OPS_DELETE 표준 문장을 그대로 쓴다
 *
 * PIPELINE[HB51] common 모듈
 * PIPELINE[HB50, HB8] 연관 모듈
 */
package com.haccp.common.validation;

// 역할 — 업무 예외
import com.haccp.common.exception.BizException;
// 역할 — 목록 타입
import java.util.List;

/** 삭제 검증 공통 유틸 */
public final class DeleteValidation {

    private DeleteValidation() {}

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 삭제 대상 목록이 비어 있지 않은지 검사한다
     *   2) validate-delete·delete 진입 시 공통으로 호출한다
     *   3) null·empty일 때(= 삭제 대상 없음) BizException
     */
    public static <T> void requireItems(
            // 삭제 대상 목록 — UI 단건이어도 1건 배열
            List<T> items,
            // 비었을 때 사용자 문구
            String message
    ) {
        if (items == null || items.isEmpty()) throw new BizException(message);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 필수 문자열을 trim 후 검증한다
     *   2) 삭제 복합키 필드를 정규화할 때 호출한다
     *   3) 비면 BizException, 있으면 trim 값 반환
     */
    public static String requireText(
            // 검증 대상
            String value,
            // 실패 문구
            String message
    ) {
        String normalized = value == null ? "" : value.trim();
        if (normalized.isEmpty()) throw new BizException(message);
        return normalized;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 필수 양수(Long)를 검증한다
     *   2) 문서 idx 등 대리키 삭제에 쓴다
     *   3) null·0 이하일 때 BizException
     */
    public static Long requirePositive(
            // 검증 대상
            Long value,
            // 실패 문구
            String message
    ) {
        if (value == null || value <= 0) throw new BizException(message);
        return value;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) OPS_DELETE 표준 참조 차단 문구를 조립한다
     *   2) throwIfBlocked에서만 호출한다
     *   3) 항상 사용자용 문자열을 반환한다
     */
    public static String referenced(
            // 삭제 대상 업무명
            String label,
            // 식별 키
            String key,
            // 참조·잠금 사유
            String target
    ) {
        return "선택한 항목 중 " + label + " '" + key + "'이(가) " + target + "에서 참조 중이므로 삭제할 수 없습니다.";
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) Mapper가 돌려준 첫 차단 행이 있으면 표준 예외를 던진다
     *   2) assertDeletable Double Check에서 호출한다
     *   3) blocker가 null일 때(= 삭제 가능) 통과
     */
    public static void throwIfBlocked(
            // 첫 차단 행 — null이면 통과
            DeleteBlocker blocker,
            // 업무명 라벨
            String label
    ) {
        if (blocker == null) return;
        String key = blocker.getRefKey() == null ? "" : blocker.getRefKey();
        String target = blocker.getTarget() == null ? "" : blocker.getTarget();
        throw new BizException(referenced(label, key, target));
    }
}
