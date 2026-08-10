/** 필터 문자열 정규화 — 콤마 제거 + 소문자 (표시 1,234 ↔ 입력 1234). 
 * PIPELINE[F165]
 */

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 필터 입력 정규화 — 천단위 콤마 제거·소문자 통일
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 설명 — 필터 입력 정규화 — 천단위 콤마 제거·소문자 통일
export function normalizeFilterText(s: string): string {
  return s.replace(/,/g, "").toLowerCase();
}
