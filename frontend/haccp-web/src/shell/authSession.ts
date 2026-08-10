/**
 * authSession — JWT 유효성 판정·세션 정리·로그인 복귀 경로.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 토큰 만료 확인, 401 발생 시 세션 일괄 정리, 로그인 후 원래 화면으로 되돌리기를 담당한다
 *   2) http 인터셉터·ProtectedRoute·로그아웃 버튼이 공통으로 호출한다
 *   3) 서명 위변조는 검사하지 않는다 — 만료만 걸러 불필요한 호출을 줄이고, 최종 판정은 서버 JwtFilter가 한다
 *
 * PIPELINE[HF161] 셸 인프라
 * PIPELINE[HF74] 연관 — 멀티탭 로그아웃 신호
 */
// 역할 — 토큰·사용자·권한 보관 스토어 (logout)
import { useAuthStore } from "@/stores/authStore";
// 역할 — 열린 탭 목록 스토어 (reset)
import { useTabStore } from "@/stores/tabStore";
// 역할 — 복귀 경로 sessionStorage 키
import { RETURN_URL_KEY } from "@/shell/authKeys";
// 역할 — 타 탭에 로그아웃 알림
import { broadcastAuthLogout } from "@/shell/authCrossTab";

/**
 * 401 전용 예외 — 화면의 catch에서 "로그인이 필요합니다" 토스트를 중복 표시하지 않도록 구분하는 용도.
 * 이미 로그인 화면으로 이동시켰기 때문에 화면은 조용히 넘어가야 한다.
 */
export class UnauthorizedError extends Error {
  /** 타입 가드용 플래그 — instanceof가 번들 경계에서 깨질 때 대비 */
  readonly isUnauthorized = true;

  constructor(message = "로그인이 필요합니다.") {
    super(message);
    this.name = "UnauthorizedError";
  }
}

/** main.tsx가 등록하는 React Query 캐시 비우기 콜백 — 순환 import를 피하려고 주입 방식을 쓴다 */
let clearQueryCache: (() => void) | null = null;

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) React Query 캐시를 비우는 콜백을 등록한다
 *   2) main.tsx가 QueryClient를 만든 직후 1회 호출한다
 *   3) 등록하지 않아도 동작한다 — 그 경우 세션 정리 때 캐시만 남는다
 */
export function registerQueryCacheClear(
  // 캐시 비우기 함수 — 보통 () => queryClient.clear()
  fn: () => void
) {
  clearQueryCache = fn;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) JWT payload의 exp를 읽어 아직 유효한 토큰인지 판정한다
 *   2) 앱 시작 시 보관된 세션 복원 여부를 정할 때, 그리고 보호 라우트 진입마다 호출한다
 *   3) 유효하면 true, 토큰이 없거나 디코드 실패·exp 없음·만료면 false다
 */
export function isTokenValid(
  // 검사할 JWT 원문 — 없으면(= 로그인 이력 없음) 바로 false
  token: string | null
): boolean {
  if (!token) return false;
  try {
    // JWS의 두 번째 세그먼트가 payload다
    const part = token.split(".")[1];
    // URL-safe Base64를 표준 Base64로 바꾸고 4의 배수로 패딩
    const b64 = part.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(part.length / 4) * 4, "=");
    const payload = JSON.parse(atob(b64));
    // exp는 초 단위라 ms로 환산해 비교한다
    return typeof payload.exp === "number" && payload.exp * 1000 > Date.now();
  } catch {
    return false;
  }
}

/** 외부 사이트로 튀는 것(open redirect)을 막는다 — 앱 내부 상대 경로만 허용 */
function isSafeReturnPath(path: string): boolean {
  return !!path && path.startsWith("/") && !path.startsWith("//") && path !== "/login";
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 로그인 화면으로 보내기 전에 원래 보던 경로를 저장한다
 *   2) 401 처리와 보호 라우트 차단 시점에 호출한다
 *   3) 안전한 내부 경로만 저장하고, 그 밖의 값은 조용히 무시한다
 */
export function saveReturnUrl(
  // 복귀할 경로 — pathname + search 형태. 외부 URL이면 저장하지 않는다
  path: string
) {
  if (isSafeReturnPath(path)) sessionStorage.setItem(RETURN_URL_KEY, path);
}

/** 저장된 복귀 경로를 읽는다 (지우지 않음) */
function peekReturnUrl(): string | null {
  const v = sessionStorage.getItem(RETURN_URL_KEY);
  return v && isSafeReturnPath(v) ? v : null;
}

/** 복귀 경로를 읽고 즉시 지운다 — 1회성이라 다음 로그인에 재사용되지 않는다 */
function consumeReturnUrl(): string | null {
  const v = peekReturnUrl();
  if (v) sessionStorage.removeItem(RETURN_URL_KEY);
  return v;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 로그인 성공 후 이동할 경로를 정한다
 *   2) 로그인 화면과, 이미 로그인된 상태로 /login에 들어온 경우에 호출한다
 *   3) 저장된 복귀 경로가 있으면 그곳으로, 없으면 홈("/")으로 보낸다
 */
export function resolvePostLoginPath(
  // 라우터 state로 넘어온 원래 경로 — 없으면 sessionStorage 값을 소비한다
  fromState?: string | null
): string {
  const from = fromState && isSafeReturnPath(fromState) ? fromState : consumeReturnUrl();
  return from ?? "/";
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 탭·토큰·서버 캐시를 한 번에 정리하고 다른 탭에도 로그아웃을 알린다
 *   2) 수동 로그아웃과 401 처리가 공통으로 호출한다
 *   3) 화면 이동은 하지 않는다 — 이동 시점은 호출부가 정한다
 */
export function clearAuthSession() {
  // 같은 브라우저의 다른 탭도 함께 내려가도록 신호를 먼저 보낸다
  broadcastAuthLogout();
  useTabStore.getState().reset();
  useAuthStore.getState().logout();
  clearQueryCache?.();
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 세션을 정리하고 로그인 화면으로 강제 이동시킨다
 *   2) http 인터셉터가 401을 받았을 때, 그리고 만료 토큰을 발견했을 때 호출한다
 *   3) 이미 로그인 화면이면 복귀 경로 저장과 이동을 모두 생략한다
 */
export function handleUnauthorized(
  // 복귀할 경로 — 생략하면 현재 주소를 쓴다
  redirectPath?: string
) {
  const path = redirectPath ?? (location.pathname + location.search);
  if (location.pathname !== "/login") saveReturnUrl(path);
  clearAuthSession();
  // React Router가 아닌 location.replace를 쓴다 — 컴포넌트 밖(인터셉터)에서도 동작해야 한다
  if (location.pathname !== "/login") location.replace("/login");
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 잡은 예외가 401 계열인지 판정한다
 *   2) 화면 오류 문구를 만드는 errors.ts에서 토스트 억제 여부를 정할 때 호출한다
 *   3) 401이면 true — 이 경우 화면은 별도 안내 없이 넘어간다
 */
export function isUnauthorizedError(
  // 판정 대상 — catch로 받은 값이라 타입이 unknown이다
  e: unknown
): boolean {
  return e instanceof UnauthorizedError
    || (e instanceof Error && e.name === "UnauthorizedError");
}
