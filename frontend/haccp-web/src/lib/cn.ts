/**
 * cn — 조건부 className을 Tailwind 충돌 없이 합친다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) clsx로 조건부 클래스를 펼치고, tailwind-merge로 같은 속성의 뒤 클래스가 이기게 정리한다
 *   2) 컴포넌트 기본 스타일 위에 화면별 className을 덮어쓸 때 항상 이 함수를 거친다
 *   3) 그냥 문자열을 이어붙이면 "px-2 px-4"처럼 둘 다 남아 어느 쪽이 적용될지 예측할 수 없다
 *
 * PIPELINE[HF36] 공통 모듈
 */
// 역할 — 조건부·배열 className 평탄화
import { clsx, type ClassValue } from "clsx";
// 역할 — 중복 Tailwind 속성 정리 (뒤에 온 클래스 우선)
import { twMerge } from "tailwind-merge";

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 여러 className 조각을 하나의 문자열로 합친다
 *   2) 모든 공통 컴포넌트가 className prop을 처리할 때 호출한다
 *   3) false·null·undefined는 무시되므로 조건식을 그대로 넘겨도 된다
 */
export function cn(
  // className 조각들 — 문자열·배열·조건식 결과를 섞어 넘길 수 있다
  ...inputs: ClassValue[]
) {
  return twMerge(clsx(inputs));
}
