/**
 * loginPrefs — 로그인 화면의 아이디 저장·자동 로그인 선호값.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 로그인 화면이 마운트될 때 아이디를 되살리고, 자동 로그인 체크 상태를 복원한다
 *   2) mes-web과 다른 점 — 회사 선택이 없어 coCd를 저장하지 않고, 이관할 구버전 키도 없다
 *   3) 비밀번호는 어떤 경우에도 저장하지 않는다. 자동 로그인은 토큰 보관 위치(local/session)만 바꾼다
 *
 * PIPELINE[HF162] 셸 인프라
 * PIPELINE[HF29, HF160] 연관 모듈
 */
// 역할 — 로그인 선호값 localStorage 키 상수
import { LOGIN_PREFS_KEY } from "@/shell/authKeys";

/** LoginPrefs — 아이디 저장·자동 로그인·저장된 아이디 */
interface LoginPrefs {
  /** 아이디 저장 체크 여부 — ON이면 userId를 함께 보관한다 */
  saveId: boolean;
  /** 자동 로그인 체크 여부 — ON이면 토큰을 localStorage, OFF면 sessionStorage에 둔다 */
  autoLogin: boolean;
  /** 저장된 아이디 — saveId가 ON일 때만 값이 있다 */
  userId?: string;
}

/** 기본 선호값 — 공용 PC 사고를 피하려고 두 항목 모두 기본 OFF다 */
const DEFAULT_PREFS: LoginPrefs = {
  saveId: false,
  autoLogin: false,
};

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) localStorage에서 로그인 선호값을 읽어 반환한다
 *   2) 로그인 화면 마운트 시, 그리고 authStore가 토큰 보관 위치를 정할 때 호출한다
 *   3) 저장값이 없거나 JSON이 손상되었으면 기본값(둘 다 OFF)을 반환한다
 */
export function loadLoginPrefs(): LoginPrefs {
  try {
    const raw = localStorage.getItem(LOGIN_PREFS_KEY);
    // raw가 있을 때(= 이전에 저장한 선호값 존재) 파싱해 필드별로 검증한다
    if (raw) {
      const parsed = JSON.parse(raw) as Partial<LoginPrefs>;
      return {
        saveId: !!parsed.saveId,
        autoLogin: !!parsed.autoLogin,
        // 문자열이 아닌 값이 들어와 있으면 무시한다 — 손상된 저장값이 화면을 깨뜨리지 않게 한다
        userId: typeof parsed.userId === "string" ? parsed.userId : undefined,
      };
    }
  } catch {
    // JSON 손상·private mode 등 storage 접근 실패는 기본값으로 넘어간다
  }
  return { ...DEFAULT_PREFS };
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 로그인 선호값을 localStorage에 저장한다
 *   2) 로그인 성공 직후 체크박스 상태를 반영할 때 호출한다
 *   3) 아이디 저장이 OFF면 userId를 저장하지 않는다 — 체크를 끄는 것으로 흔적이 지워져야 한다
 */
export function saveLoginPrefs(
  // 저장할 선호값 — saveId가 OFF면 userId는 버려진다
  prefs: LoginPrefs
): void {
  const next: LoginPrefs = {
    saveId: prefs.saveId,
    autoLogin: prefs.autoLogin,
  };
  // saveId가 ON이고 아이디가 있을 때(= 다음 로그인에 되살릴 값) 함께 저장한다
  if (prefs.saveId && prefs.userId) next.userId = prefs.userId;
  try {
    localStorage.setItem(LOGIN_PREFS_KEY, JSON.stringify(next));
  } catch {
    // storage 실패는 선호값 보관 실패일 뿐이므로 로그인 자체를 막지 않는다
  }
}
