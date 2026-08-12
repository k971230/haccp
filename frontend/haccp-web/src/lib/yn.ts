/**
 * yn.ts — 사용여부(Y/N) 공용 옵션·맵.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 시스템·기초 화면 그리드·검색 콤보가 동일 Y/N 라벨을 쓰도록 한다
 *   2) 공통코드·권한·사용자 등 기초코드 화면에서 import 한다
 *   3) 값 변형 없이 옵션/맵만 반환한다
 *
 * PIPELINE[HF99] YN 공통
 */

/** 사용여부 기본값 — 검색·행추가 */
export const DEFAULT_USE_YN = "Y" as const;

/** 그리드 codeOptions / SearchSelect용 Y·N 옵션 */
export function ynOptions(): Array<{ value: string; label: string }> {
  return [
    { value: "Y", label: "사용" },
    { value: "N", label: "미사용" },
  ];
}

/** 그리드 codeMap — 코드→표시명 */
export function ynMap(): Record<string, string> {
  return { Y: "사용", N: "미사용" };
}
