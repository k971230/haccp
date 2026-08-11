/**
 * authPaths — Vite base(/haccp/)를 반영한 로그인·복귀 경로 헬퍼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-11
 * 코멘트:
 *   1) window.location 은 BrowserRouter basename 을 모른다 — /haccp/login 과 /login 을 구분해야 한다
 *   2) handleUnauthorized·멀티탭 구독이 location.replace 할 때 이 모듈의 절대 경로를 쓴다
 *   3) React Router 의 useLocation().pathname 은 이미 base 가 제거된 값이므로 라우터 내비에는 쓰지 않는다
 *
 * PIPELINE[HF161] 셸 인프라 — G-22 Path basename 정합
 * PIPELINE[HF74] 연관 — authCrossTab
 */

/**
 * 개발자: 박승우
 * 일자: 2026-08-11
 * 코멘트:
 *   1) Vite BASE_URL 을 trailing slash 하나로 정규화한다
 *   2) 로그인 절대 경로·browser→router 변환이 공통으로 호출한다
 *   3) 빈·비정상 값은 "/" 로 본다 — 로컬 dev 기본과 동일하다
 */
export function normalizeAppBaseUrl(
  // Vite base — 보통 "/" 또는 "/haccp/". 테스트에서 주입 가능
  baseUrl: string = import.meta.env.BASE_URL || "/"
): string {
  const trimmed = (baseUrl || "/").trim() || "/";
  return trimmed.endsWith("/") ? trimmed : `${trimmed}/`;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-11
 * 코멘트:
 *   1) location.replace 에 넣을 로그인 pathname 을 만든다 (/login 또는 /haccp/login)
 *   2) 401·타 탭 로그아웃에서 React Router 밖 이동이 필요할 때 호출한다
 *   3) 성공 시 base+login, base 가 비어도 최소 "/login"
 */
export function loginBrowserPath(
  // Vite base — 생략 시 import.meta.env.BASE_URL
  baseUrl?: string
): string {
  return `${normalizeAppBaseUrl(baseUrl)}login`;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-11
 * 코멘트:
 *   1) 현재(또는 인자) browser pathname 이 로그인 화면인지 판정한다
 *   2) 멀티탭 구독·handleUnauthorized 가 중복 리다이렉트를 막을 때 호출한다
 *   3) 로그인 경로(끝 슬래시 허용)이면 true
 */
export function isLoginBrowserPath(
  // window.location.pathname — React Router 의 pathname 이 아님
  pathname: string,
  // Vite base — 생략 시 env
  baseUrl?: string
): boolean {
  const login = loginBrowserPath(baseUrl);
  return pathname === login || pathname === `${login}/`;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-11
 * 코멘트:
 *   1) browser 전체 경로(search 포함)에서 Vite base 를 벗겨 라우터 경로로 만든다
 *   2) handleUnauthorized 가 returnUrl 을 저장할 때 호출한다 — nav() 는 basename 상대 경로만 받는다
 *   3) base 밖 경로면 원본 pathname 을 유지하되 선행 "/" 를 보장한다
 */
export function toRouterPath(
  // location.pathname + location.search 형태
  browserPathAndSearch: string,
  // Vite base — 생략 시 env
  baseUrl?: string
): string {
  const baseNoSlash = normalizeAppBaseUrl(baseUrl).replace(/\/$/, "");
  const q = browserPathAndSearch.indexOf("?");
  const path = q >= 0 ? browserPathAndSearch.slice(0, q) : browserPathAndSearch;
  const search = q >= 0 ? browserPathAndSearch.slice(q) : "";

  let routerPath = path;
  // base 가 "" 이 아닐 때(= /haccp) 접두를 제거한다
  if (baseNoSlash && (path === baseNoSlash || path.startsWith(`${baseNoSlash}/`))) {
    routerPath = path.slice(baseNoSlash.length) || "/";
  }
  if (!routerPath.startsWith("/")) routerPath = `/${routerPath}`;
  return `${routerPath}${search}`;
}
