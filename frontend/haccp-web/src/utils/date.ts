/**
 * date.ts — utils 공통 date.
 *
 * 주요 역할:
 *     1. 타입·순수 함수·스타일 헬퍼
 *     2. React/UI 의존 없음
 *
 * PIPELINE[F35] 공통 모듈
 */
// 역할 — 날짜 포맷 라이브러리
import dayjs from "dayjs";

/** yyyy-MM-dd — null/빈값이면 빈 문자열 */
export const fmtDate = (v?: string | null) => (v ? dayjs(v).format("YYYY-MM-DD") : "");
/** yyyy-MM-dd HH:mm:ss — 일시 컬럼 표시 */
export const fmtDateTime = (v?: string | null) =>
  v ? dayjs(v).format("YYYY-MM-DD HH:mm:ss") : "";
/** yyyy-MM-dd HH:mm — 로그인·감사 이력 표시 */
export const fmtDateTimeMinute = (v?: string | null) =>
  v ? dayjs(v).format("YYYY-MM-DD HH:mm") : "";
/** 오늘 날짜(로컬) — 검색 기본값·신규행 기본일 */
export const today = () => dayjs().format("YYYY-MM-DD");

/** 천단위 구분 숫자 — null/undefined/빈문자열이면 빈 문자열 */
export const fmtNumber = (v?: number | string | null) =>
  v === null || v === undefined || v === "" ? "" : Number(v).toLocaleString();
/** 금액 표시 — fmtNumber 와 동일 포맷 */
export const fmtAmount = fmtNumber;
