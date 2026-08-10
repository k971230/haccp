/**
 * authStore — Zustand 전역 인증 상태.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 토큰·사용자·화면권한을 보관하고, 자동 로그인 여부에 따라 localStorage/sessionStorage에 영속한다
 *   2) mes-web과 다른 점 — 권한이 RW/R 2단계가 아니라 조회·등록·수정·삭제·출력 5개 Y/N이며,
 *      관리자 판정도 아이디('admin')가 아닌 권한그룹(usrgrpCd='ADMIN') 기준이다
 *   3) 비밀번호는 저장하지 않는다. 서버 토큰 무효화 목록이 없는 무상태 JWT라 만료 전 강제 차단은 불가하다
 *
 * PIPELINE[HF29] Zustand 스토어
 * PIPELINE[HF160, HF161, HF162] 연관 모듈
 */
// 역할 — Zustand 스토어 생성
import { create } from "zustand";
// 역할 — persist 미들웨어·JSON storage 팩토리
import { persist, createJSONStorage } from "zustand/middleware";
// 역할 — 로그인 사용자·화면권한 타입
import type { LoginUser, ScreenAuth } from "@/types/common";
// 역할 — 자동 로그인 선호값 로드
import { loadLoginPrefs } from "@/shell/loginPrefs";
// 역할 — persist 저장 키 상수
import { AUTH_STORAGE_KEY } from "@/shell/authKeys";

/** 화면 권한 종류 — 백엔드 ScreenAuth의 Y/N 필드와 1:1 대응 */
export type ScreenPerm = "read" | "write" | "modify" | "delete" | "print";

/** AuthState — 토큰·사용자·화면권한과 조작 액션 */
interface AuthState {
  /** JWT — null이면 미로그인 */
  token: string | null;
  /** 로그인 사용자 — null이면 미로그인 */
  user: LoginUser | null;
  /** 화면 권한 목록 — 관리자는 빈 배열(전권) */
  screens: ScreenAuth[];
  /** 로그인 성공 시 토큰·사용자·권한을 적재 */
  setAuth: (token: string, user: LoginUser, screens: ScreenAuth[]) => void;
  /** 세션 무효화 — 메모리와 양쪽 storage를 모두 비운다 */
  logout: () => void;
  /** 업체 관리자(전권) 여부 */
  isAdmin: () => boolean;
  /** 해당 화면에 특정 권한이 있는지 — 관리자는 항상 true */
  can: (scrnCd: string, perm: ScreenPerm) => boolean;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 자동 로그인 여부에 맞는 Web Storage를 감싼 persist 저장소를 만든다
 *   2) 스토어 생성 시와 로그인 직전 저장소 전환 시 호출한다
 *   3) ON이면 localStorage(브라우저를 닫아도 유지), OFF면 sessionStorage(탭을 닫으면 소멸)
 */
function authPersistStorage(autoLogin: boolean) {
  return createJSONStorage(() => (autoLogin ? localStorage : sessionStorage));
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) localStorage·sessionStorage 양쪽의 인증 저장값을 지운다
 *   2) 로그아웃할 때와 저장소를 전환할 때 호출한다
 *   3) private mode 등 storage 접근이 막혀도 예외를 삼켜 로그아웃 흐름을 끊지 않는다
 */
function clearAuthPersistKeys() {
  try { localStorage.removeItem(AUTH_STORAGE_KEY); } catch { /* storage 접근 실패 무시 */ }
  try { sessionStorage.removeItem(AUTH_STORAGE_KEY); } catch { /* storage 접근 실패 무시 */ }
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 자동 로그인 체크 상태에 맞춰 토큰 보관 위치를 전환한다
 *   2) 로그인 성공 후 setAuth를 호출하기 직전에 실행한다
 *   3) 반대쪽 저장소의 값을 먼저 비워 두 곳에 세션이 동시에 남는 상황을 막는다
 */
export function applyAuthPersistStorage(
  // 자동 로그인 체크 여부 — true면 localStorage, false면 sessionStorage에 보관한다
  autoLogin: boolean
) {
  clearAuthPersistKeys();
  useAuthStore.persist.setOptions({ storage: authPersistStorage(autoLogin) });
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 화면 권한 객체에서 요청한 종류의 Y/N 값을 읽는다
 *   2) can() 판정 내부에서만 사용한다
 *   3) 'Y'면 true, 그 외(N·null·undefined)면 false다 — 값이 없으면 거부가 기본이다
 */
function hasPerm(row: ScreenAuth, perm: ScreenPerm): boolean {
  const flag =
    perm === "read" ? row.readYn
    : perm === "write" ? row.writeYn
    : perm === "modify" ? row.modifyYn
    : perm === "delete" ? row.deleteYn
    : row.printYn;
  return flag === "Y";
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      token: null,
      user: null,
      screens: [],
      // 로그인 성공 — 토큰·사용자·권한을 메모리와 persist 저장소에 함께 넣는다
      setAuth: (token, user, screens) => set({ token, user, screens }),
      logout: () => {
        set({ token: null, user: null, screens: [] });
        clearAuthPersistKeys();
      },
      // 권한그룹이 ADMIN일 때(= 업체 관리자) 전권으로 본다
      isAdmin: () => get().user?.usrgrpCd?.toUpperCase() === "ADMIN",
      // 관리자는 무조건 통과, 그 외는 해당 화면 권한 행의 Y/N을 확인한다(행이 없으면 거부)
      can: (scrnCd, perm) => {
        if (get().isAdmin()) return true;
        const row = get().screens.find((s) => s.scrnCd === scrnCd);
        return !!row && hasPerm(row, perm);
      },
    }),
    {
      name: AUTH_STORAGE_KEY,
      // 앱 기동 시 자동 로그인 선호값에 맞는 저장소에서 세션을 되살린다
      storage: authPersistStorage(loadLoginPrefs().autoLogin),
      // 함수는 직렬화 대상에서 제외한다 — 상태 값만 저장한다
      partialize: (s) => ({ token: s.token, user: s.user, screens: s.screens }),
    },
  ),
);
