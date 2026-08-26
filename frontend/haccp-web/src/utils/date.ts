/**
 * date — 날짜·숫자 표시 포맷.
 *
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 화면에 보이는 문자열만 만든다 — 저장값은 YYYYMMDD 원본 그대로 둔다
 *   2) 그리드 열 렌더러·검색 기본값이 호출한다
 *   3) null·빈값은 빈 문자열이다. 화면에 "Invalid Date" 가 뜨지 않게 한다
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
