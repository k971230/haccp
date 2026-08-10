/** 셀 정렬 — 명시 align 우선, 없으면 타입/포맷 기본값. 
 * PIPELINE[F88] 그리드 유틸
 * PIPELINE[F90] 연관 모듈
 */
// 역할 — 그리드 컬럼 타입·정렬 입력 타입
import type { GridColumn, GridColumnType } from "@/types/grid";

// 설명 — colAlign 입력 — align·type·kioskFormat만 필요한 경우
export type ColAlignInput = Pick<GridColumn<unknown>, "align" | "type" | "kioskFormat">;

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 컬럼 정의로 셀 좌·중·우 정렬 결정
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 설명 — 컬럼 정의로 셀 좌·중·우 정렬 결정
export function colAlign<T>(c: GridColumn<T> | ColAlignInput): "left" | "center" | "right" {
  if (c.align) return c.align;
  if (c.kioskFormat === "time") return "center";
  switch (c.type) {
    case "number":
    case "amount":
      return "right";
    case "date":
    case "datetime":
    case "code":
    case "checkbox":
      return "center";
    default:
      return "left";
  }
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 부분 컬럼 속성만으로 정렬 결정 — colAlign 위임
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 설명 — 부분 컬럼 속성만으로 정렬 결정 — colAlign 위임
export function colAlignOf(
  c: { align?: ColAlignInput["align"]; type?: GridColumnType; kioskFormat?: ColAlignInput["kioskFormat"] },
): "left" | "center" | "right" {
  return colAlign(c);
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-11
 * 코멘트:
 *   1) 열 너비를 width/minWidth/maxWidth 동일 값으로 고정한다(ADR-032)
 *   2) th·td·.mes-grid table-layout:fixed와 함께 — 셀 데이터 글자수와 무관, 가상스크롤 울렁임 방지
 *   3) 성공 시 스타일 객체 — 호출부는 pin sticky와 병합. w는 widthOf(pref→col.width→120)
 */
export function colWidthStyle(w: number): { width: number; minWidth: number; maxWidth: number } {
  // widthOf(컬럼) px — pref sizing → col.width → 기본 120. 리사이즈 하한 50. 데이터 길이 미반영
  return { width: w, minWidth: w, maxWidth: w };
}
