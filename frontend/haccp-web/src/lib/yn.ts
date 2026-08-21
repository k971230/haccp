/**
 * yn.ts — 사용여부(Y/N) 공용 옵션·맵.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 시스템·기초 화면 그리드·검색 콤보가 동일 Y/N 라벨을 쓰도록 한다
 *   2) 공통코드·권한·사용자·HTML양식 목록에서 import 한다
 *   3) toYn 은 N으로 시작하면 미사용. 옵션/맵은 값 변형 없이 반환한다
 *
 * PIPELINE[HF99] YN 공통
 */

/** 사용여부 기본값 — 검색·행추가 */
export const DEFAULT_USE_YN = "Y" as const;

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 공통코드 y/n·그리드 Y/N·빈값을 저장값 Y/N으로 맞춘다
 *   2) HTML양식 목록 dirty 비교·asVerRow 에서 호출한다
 *   3) N으로 시작하지 않으면 사용(Y)
 */
export function toYn(
  // 셀·SP·공통코드 값
  value: unknown,
): "Y" | "N" {
  return String(value ?? "Y").trim().toUpperCase().startsWith("N") ? "N" : "Y";
}

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
