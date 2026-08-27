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
// 역할 — 저장형 YYYYMMDD → YYYY-MM-DD (구분자 없는 8자리는 dayjs 가 못 읽는다)
import { toInputDate } from "@/lib/docDateTime";

/**
 * dayjs 가 못 읽는 값을 화면에 그대로 흘리지 않는다.
 *
 * 이 저장소의 날짜 컬럼은 대부분 `varchar(8)` YYYYMMDD 인데 dayjs 는 구분자가 없으면
 * 파싱을 못 해 「Invalid Date」를 만든다. 양식 선택 팝업 일자 열이 전 행 Invalid Date 로
 * 나온 적이 있다. 8자리면 먼저 붙여 주고, 그래도 못 읽으면 원본을 보여 준다.
 */
function safeFormat(v: string, pattern: string): string {
  const d = dayjs(toInputDate(v) || v);
  return d.isValid() ? d.format(pattern) : v;
}

/** yyyy-MM-dd — null/빈값이면 빈 문자열 */
export const fmtDate = (v?: string | null) => (v ? safeFormat(v, "YYYY-MM-DD") : "");
/** yyyy-MM-dd HH:mm:ss — 일시 컬럼 표시 */
export const fmtDateTime = (v?: string | null) =>
  v ? safeFormat(v, "YYYY-MM-DD HH:mm:ss") : "";
/** yyyy-MM-dd HH:mm — 로그인·감사 이력 표시 */
export const fmtDateTimeMinute = (v?: string | null) =>
  v ? safeFormat(v, "YYYY-MM-DD HH:mm") : "";
/** 오늘 날짜(로컬) — 검색 기본값·신규행 기본일 */
export const today = () => dayjs().format("YYYY-MM-DD");

/** 천단위 구분 숫자 — null/undefined/빈문자열이면 빈 문자열 */
export const fmtNumber = (v?: number | string | null) =>
  v === null || v === undefined || v === "" ? "" : Number(v).toLocaleString();
/** 금액 표시 — fmtNumber 와 동일 포맷 */
export const fmtAmount = fmtNumber;
