/** 셀 표면 클래스 — locked > required empty > editable on active. 
 * PIPELINE[F168]
 */

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 필수 컬럼인데 값이 비어 있는지 판정
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 필수 컬럼인데 값이 비어 있는지 판정
export function isRequiredEmpty(val: unknown): boolean {
  return val === null || val === undefined || String(val).trim() === "";
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 잠금·필수·편집 상태에 따른 셀 표면 CSS 클래스 반환
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 설명 — 잠금·필수·편집 상태에 따른 셀 표면 CSS 클래스 반환
export function gridCellSurfaceClass(opts: {
  locked: boolean;
  required?: boolean;
  value: unknown;
  editableOnActive?: boolean;
}): string {
  const { locked, required, value, editableOnActive } = opts;
  if (locked) return "mes-cell-locked";
  if (required && isRequiredEmpty(value)) return "mes-cell-required";
  if (editableOnActive) return "mes-cell-editable";
  return "";
}
