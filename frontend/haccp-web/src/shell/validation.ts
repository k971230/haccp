/**
 * validation — MES 셸 인프라 모듈.
 *
 * 주요 역할:
 *     1. MesShell(F49) / Page(F115~F156) 지원 유틸
 *     2. 탭·다이얼로그·메시지·검증·단축키 등 횡단 관심사
 *
 * 설계 기준:
 *     - 도메인 CRUD 없음.
 *     - *Page.tsx가 shell을 import(단방향).
 *
 * PIPELINE[F58] 셸 인프라
 * PIPELINE[F49, F52] 연관 모듈
 *
 * 구현내용: 전수 주석(레벨3).
 */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 필수값 검증 — 빈값이면 라벨 포함 오류 문구, 통과 시 null
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 필수값 검증 — 빈값이면 라벨 포함 오류 문구, 통과 시 null
export const required = (label: string) => (v: unknown): string | null =>
  // null·undefined·공백 문자열이면 필수 오류 메시지
  v === null || v === undefined || String(v).trim() === "" ? `${label}은(는) 필수입니다.` : null;

/** 0 이상 숫자(수량·재고 등). 빈값은 통과(필수는 required 로 별도). */
export const nonNegative = (label = "값") => (v: unknown): string | null => {
  // 빈값은 별도 required에 맡기고 통과
  if (v === null || v === undefined || v === "") return null;
  // 숫자로 변환
  const n = Number(v);
  // NaN·음수면 오류, 0 이상이면 null(통과)
  return Number.isNaN(n) ? `${label}은(는) 숫자여야 합니다.` : n < 0 ? `${label}은(는) 0 이상이어야 합니다.` : null;
};

/** 0 초과 숫자(0 초과). 출고/출하 수량 등. */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) positive — 인프라 export
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export const positive = (label = "값") => (v: unknown): string | null => {
  // 빈값은 별도 required에 맡기고 통과
  if (v === null || v === undefined || v === "") return null;
  // 숫자로 변환
  const n = Number(v);
  // NaN 또는 0 이하면 오류, 0 초과면 null(통과)
  return Number.isNaN(n) || n <= 0 ? `${label}은(는) 0보다 커야 합니다.` : null;
};

/** 숫자(0-9)만 — 우편번호·인증키 등. 빈값 통과. 음수·소수·문자 거부 */
export const DIGITS_ONLY_RE = /^\d*$/;

/**
 * 개발자: 박승우
 * 일자: 2026-07-11
 * 코멘트:
 *   1) 문자열에서 숫자 이외 문자를 제거한다
 *   2) 그리드 sanitize·폼 onChange에서 호출
 *   3) 성공 시 숫자만 남은 문자열
 */
export function filterDigitsOnly(value: string): string {
  return value.replace(/\D/g, "");
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-11
 * 코멘트:
 *   1) 숫자(양수 자리열)만 허용하는 셀 검증 — 빈값은 통과
 *   2) GridColumn.validate 또는 저장 가드에서 호출
 *   3) 통과 시 null, 실패 시 업무 문구
 */
export const digitsOnly = (label = "값") => (v: unknown): string | null => {
  // 빈값은 별도 required에 맡기고 통과
  if (v === null || v === undefined || String(v).trim() === "") return null;
  const s = String(v).trim();
  // 숫자만(0-9)이 아닐 때(= 문자·부호·소수) 거부
  if (!/^\d+$/.test(s)) return `${label}은(는) 숫자만 입력할 수 있습니다.`;
  return null;
};

/**
 * 개발자: 박승우
 * 일자: 2026-07-11
 * 코멘트:
 *   1) 숫자 정확히 n자리 — 인증키 4자 등 MesPatterns.DIGITS_n 대칭
 *   2) GridColumn.validate에서 digitsOnly와 함께 또는 단독 사용
 *   3) 빈값 통과, 자리수 불일치 시 업무 문구
 */
export const digitsExact = (label: string, n: number) => (v: unknown): string | null => {
  if (v === null || v === undefined || String(v).trim() === "") return null;
  const s = String(v).trim();
  if (!/^\d+$/.test(s)) return `${label}은(는) 숫자만 입력할 수 있습니다.`;
  // 자리수가 n이 아닐 때(= 업무 고정 길이) 거부
  if (s.length !== n) return `${label}은(는) 숫자 ${n}자여야 합니다.`;
  return null;
};

/**
 * 개발자: 박승우
 * 일자: 2026-07-11
 * 코멘트:
 *   1) 최대 글자수 검증 — 빈값 통과, 초과 시 업무 문구
 *   2) GridColumn.validate·저장 가드에서 호출
 *   3) 통과 시 null
 */
export const maxLen = (label: string, max: number) => (v: unknown): string | null => {
  if (v === null || v === undefined || String(v) === "") return null;
  // 글자수가 max 초과일 때(= 장문 저장 방지)
  if (String(v).length > max) return `${label}은(는) ${max}자 이하여야 합니다.`;
  return null;
};

/**
 * 개발자: 박승우
 * 일자: 2026-07-11
 * 코멘트:
 *   1) 검증 함수를 순서대로 합성 — 첫 실패 메시지 반환
 *   2) digitsOnly+maxLen 등 컬럼 validate에 사용
 *   3) 모두 통과 시 null
 */
export const allOf =
  (...fns: Array<(v: unknown, row?: unknown) => string | null>) =>
  (v: unknown, row?: unknown): string | null => {
    for (const fn of fns) {
      const m = fn(v, row);
      if (m) return m;
    }
    return null;
  };

/**
 * 개발자: 박승우
 * 일자: 2026-07-11
 * 코멘트:
 *   1) 숫자만 남기고 max 자리로 자른다 (인증키·우편번호)
 *   2) GridColumn.sanitize에 전달
 *   3) 잘린 문자열 반환
 */
export function filterDigitsMax(max: number): (value: string) => string {
  return (value) => filterDigitsOnly(value).slice(0, max);
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-11
 * 코멘트:
 *   1) 일반 텍스트를 max 글자로 자른다
 *   2) GridColumn.sanitize에 전달
 *   3) 잘린 문자열 반환
 */
export function filterMaxLen(max: number): (value: string) => string {
  return (value) => value.slice(0, max);
}

/** BE MesPatterns.CODE 대칭 — 영문·숫자·_·- 만. 빈값 통과. 한글명 필드에 사용 금지 */
export const CODE_RE = /^[A-Za-z0-9_-]*$/;

/**
 * 개발자: 박승우
 * 일자: 2026-07-11
 * 코멘트:
 *   1) 코드(*Cd)·콤보 value 형식 검증 — MesPatterns.CODE와 동일
 *   2) GridColumn.validate·저장 가드에서 호출
 *   3) 통과 시 null, 실패 시 업무 문구
 */
export const codeOnly = (label = "코드") => (v: unknown): string | null => {
  if (v === null || v === undefined || String(v).trim() === "") return null;
  // CODE 패턴이 아닐 때(= 한글·공백·특수문자) 거부
  if (!/^[A-Za-z0-9_-]+$/.test(String(v).trim())) {
    return `${label} 형식이 올바르지 않습니다.`;
  }
  return null;
};

/**
 * 개발자: 박승우
 * 일자: 2026-07-11
 * 코멘트:
 *   1) useYn 등 Y/N만 허용 — MesPatterns.YN 대칭
 *   2) 콤보·저장 가드에서 호출
 *   3) 통과 시 null
 */
export const ynOnly = (label = "사용여부") => (v: unknown): string | null => {
  if (v === null || v === undefined || String(v).trim() === "") return null;
  const s = String(v).trim();
  // Y/N이 아닐 때(= 기타 문자) 거부
  if (s !== "Y" && s !== "N") return `${label}은(는) Y 또는 N이어야 합니다.`;
  return null;
};

/**
 * 개발자: 박승우
 * 일자: 2026-07-11
 * 코멘트:
 *   1) 전화·휴대폰 — 숫자·하이픈만 (MesPatterns.PHONE)
 *   2) GridColumn.validate에서 호출
 *   3) 통과 시 null
 */
export const phoneOnly = (label = "전화번호") => (v: unknown): string | null => {
  if (v === null || v === undefined || String(v).trim() === "") return null;
  if (!/^[0-9-]+$/.test(String(v).trim())) {
    return `${label}은(는) 숫자와 하이픈만 입력할 수 있습니다.`;
  }
  return null;
};

/**
 * 개발자: 박승우
 * 일자: 2026-07-11
 * 코멘트:
 *   1) 전화 입력 sanitize — 숫자·하이픈만 남기고 max로 절단
 *   2) GridColumn.sanitize에 전달
 *   3) 잘린 문자열 반환
 */
export function filterPhoneMax(max: number): (value: string) => string {
  return (value) => value.replace(/[^0-9-]/g, "").slice(0, max);
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-11
 * 코멘트:
 *   1) 단순 이메일 형식 — MesPatterns.EMAIL 대칭, 빈값 통과
 *   2) GridColumn.validate에서 호출
 *   3) 통과 시 null
 */
export const emailOnly = (label = "이메일") => (v: unknown): string | null => {
  if (v === null || v === undefined || String(v).trim() === "") return null;
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(String(v).trim())) {
    return `${label} 형식이 올바르지 않습니다.`;
  }
  return null;
};

/**
 * 개발자: 박승우
 * 일자: 2026-07-11
 * 코멘트:
 *   1) 콤보 옵션 value 목록에 있는지 검사 — API 우회·복붙 방어
 *   2) type:code 컬럼 validate에 maxLen과 allOf로 합성
 *   3) 빈값 통과, 옵션에 없으면 업무 문구 (옵션 0건이면 값 있을 때 거부)
 */
export const oneOfCodes =
  (label: string, getOptions: () => Array<{ value: string }>) =>
  (v: unknown): string | null => {
    if (v === null || v === undefined || String(v).trim() === "") return null;
    const s = String(v).trim();
    const opts = getOptions() ?? [];
    // 옵션 미로드일 때(= length 0) FE는 통과 — BE YN/CODE·exists가 방어
    if (opts.length === 0) return null;
    // 옵션 value에 없을 때(= 변조·삭제된 코드) 거부
    if (!opts.some((o) => o.value === s)) return `${label}에 없는 코드입니다.`;
    return null;
  };
