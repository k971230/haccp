/**
 * authKeys — 로그인·세션 브라우저 저장 키 상수.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) localStorage / sessionStorage 키 문자열을 한곳에서만 정의한다
 *   2) mes-web과 접두사를 다르게(haccp-) 둔다 — 같은 도메인에 두 앱을 함께 배포해도 세션이 섞이지 않는다
 *   3) 비밀번호는 어떤 키에도 저장하지 않는다. 저장하는 것은 토큰·표시용 사용자 정보·화면 선호값뿐이다
 *
 * PIPELINE[HF160] 셸 인프라
 * PIPELINE[HF29, HF161, HF162] 연관 모듈
 */

/** Zustand persist — JWT·user·screens (자동 로그인 ON: localStorage / OFF: sessionStorage) */
export const AUTH_STORAGE_KEY = "haccp-auth";

/**
 * 크로스탭 로그아웃 신호 — 항상 localStorage에 쓴다.
 * storage 이벤트는 localStorage 변경만 다른 탭에 전달되므로,
 * 자동 로그인이 꺼져(sessionStorage) 있어도 이 키만은 localStorage를 쓴다.
 */
export const AUTH_LOGOUT_SIGNAL_KEY = "haccp-auth-logout-signal";

/** 아이디 저장·자동 로그인 체크 선호 (항상 localStorage — 로그인 전에도 읽어야 한다) */
export const LOGIN_PREFS_KEY = "haccp-login-prefs";

/** 401·보호 라우트 리다이렉트 전 복귀 경로 (sessionStorage — 탭을 닫으면 사라져야 한다) */
export const RETURN_URL_KEY = "haccp-return-url";

/** 401 구분 — UNAUTHENTICATED · SESSION_EXPIRED · UNAUTHORIZED. 로그인 화면이 읽고 지운다 */
export const AUTH_FAIL_CODE_KEY = "haccp-auth-fail-code";

/** 반려 문서 안내 토스트 — 세션당 1회. 로그아웃 때 지운다 */
export const REJECT_TOAST_KEY = "haccp-reject-toast";
