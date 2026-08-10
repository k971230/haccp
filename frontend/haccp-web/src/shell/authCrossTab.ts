/**
 * authCrossTab — 다른 탭의 로그아웃을 storage 이벤트로 따라간다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 한 탭에서 로그아웃하면 같은 브라우저의 나머지 탭도 즉시 로그인 화면으로 내려간다
 *   2) 현장 공용 PC에서 담당자가 교대할 때 이전 사용자 화면이 남아 있으면 기록 작성자가 뒤바뀐다 — 그 사고를 막는 장치다
 *   3) storage 이벤트는 localStorage 변경만 다른 탭에 전달된다. 그래서 세션 보관 위치와 무관하게
 *      로그아웃 신호만은 항상 localStorage에 쓴다
 *
 * PIPELINE[HF74] 셸 인프라
 * PIPELINE[HF160, HF161] 연관 모듈
 */
// 역할 — 세션 보관 키·로그아웃 신호 키
import { AUTH_LOGOUT_SIGNAL_KEY, AUTH_STORAGE_KEY } from "@/shell/authKeys";

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 다른 탭에 로그아웃을 알리는 신호를 localStorage에 기록한다
 *   2) clearAuthSession 안에서 세션을 비우기 직전에 호출한다
 *   3) 신호를 쓴 탭 자신에게는 storage 이벤트가 오지 않는다 — 무한 루프가 생기지 않는 이유다
 */
export function broadcastAuthLogout(): void {
  try {
    // 매번 값이 달라져야 이벤트가 발생하므로 현재 시각을 쓴다
    localStorage.setItem(AUTH_LOGOUT_SIGNAL_KEY, String(Date.now()));
  } catch {
    // 시크릿 모드 등 storage 접근 실패 — 멀티탭 동기화만 포기하고 로그아웃은 계속 진행한다
  }
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 다른 탭의 로그아웃 신호와 세션 키 삭제를 구독한다
 *   2) 앱 부트스트랩(main.tsx)에서 1회 호출한다
 *   3) 신호를 받으면 onForeignLogout을 호출하고, 반환된 함수로 구독을 해제한다
 */
export function subscribeAuthCrossTab(
  // 타 탭 로그아웃 감지 시 실행할 처리 — 보통 handleUnauthorized
  onForeignLogout: () => void
): () => void {
  const onStorage = (e: StorageEvent) => {
    // sessionStorage 변경은 애초에 타 탭으로 오지 않지만, 방어적으로 대상을 좁힌다
    if (e.storageArea !== localStorage) return;

    // 로그아웃 신호 키가 새로 쓰였을 때(= 타 탭에서 clearAuthSession 실행)
    if (e.key === AUTH_LOGOUT_SIGNAL_KEY && e.newValue != null) {
      onForeignLogout();
      return;
    }

    // 세션 보관 키가 바뀌었을 때 — 신호가 유실된 경우의 2차 감지
    if (e.key === AUTH_STORAGE_KEY) {
      // newValue가 null일 때(= 키 자체가 삭제됨)
      if (e.newValue == null) {
        onForeignLogout();
        return;
      }
      try {
        const parsed = JSON.parse(e.newValue) as { state?: { token?: string | null } };
        // 토큰이 비었을 때(= 로그아웃된 상태가 저장됨)
        if (!parsed?.state?.token) onForeignLogout();
      } catch {
        // 저장값이 깨졌으면 로그인 상태를 신뢰할 수 없으므로 안전한 쪽(로그아웃)을 택한다
        onForeignLogout();
      }
    }
  };

  window.addEventListener("storage", onStorage);
  return () => window.removeEventListener("storage", onStorage);
}
