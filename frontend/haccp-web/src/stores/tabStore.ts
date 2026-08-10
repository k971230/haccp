/**
 * tabStore — 열린 탭 목록·활성 탭 전역 상태.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) HaccpShell이 URL에서 화면코드를 읽어 openTab 하고, 탭 목록은 sessionStorage에 영속된다
 *   2) mes-web tabStore를 그대로 가져왔다 — 여러 기록 화면을 동시에 열어두는 사용 방식이 동일하다
 *   3) 라우트(URL)는 활성 화면 하나를, 이 저장소는 열린 탭 전체를 기억한다. 새로고침해도 탭이 복원된다
 *
 * PIPELINE[HF30] Zustand 스토어
 * PIPELINE[HF49] 연관 모듈
 */
// 역할 — 전역 스토어 생성
import { create } from "zustand";
// 역할 — persist 미들웨어·JSON 저장소
import { persist, createJSONStorage } from "zustand/middleware";

/** 열린 탭 1건 */
interface OpenTab {
  /** 화면코드 — 탭을 구분하는 키 */
  scrnCd: string;
  /** 탭에 표시할 제목 — 메뉴명을 그대로 쓴다 */
  title: string;
}

/** 탭 상태와 조작 함수 */
interface TabState {
  /** 열린 탭 목록 — 사용자가 연 순서를 유지한다 */
  tabs: OpenTab[];
  /** 활성 탭 화면코드 — 탭이 없으면 null */
  activeCd: string | null;
  /** 탭 열기 — 같은 화면이 이미 열려 있으면 활성화만 한다 */
  openTab: (scrnCd: string, title: string) => void;
  /** 탭 닫기 — 활성 탭이면 인접 탭으로 옮긴다 */
  closeTab: (scrnCd: string) => void;
  /** 전체 초기화 — 로그아웃 시 다른 사용자에게 탭이 남지 않게 한다 */
  reset: () => void;
}

/** 열린 탭 전역 스토어 — 컴포넌트 밖에서도 getState로 최신값을 읽는다 */
export const useTabStore = create<TabState>()(
  persist(
    (set) => ({
      tabs: [],
      activeCd: null,
      openTab: (scrnCd, title) =>
        set((s) => {
          const existing = s.tabs.find((t) => t.scrnCd === scrnCd);
          if (existing) {
            // 이미 열려 있을 때 — 제목이 달라졌으면 갱신한다.
            // 메뉴가 늦게 도착해 제목 자리에 화면코드가 박힌 경우를 이 경로로 되살린다
            const tabs = existing.title === title
              ? s.tabs
              : s.tabs.map((t) => (t.scrnCd === scrnCd ? { ...t, title } : t));
            return { tabs, activeCd: scrnCd };
          }
          // 새 탭은 목록 끝에 붙이고 곧바로 활성화한다
          return { tabs: [...s.tabs, { scrnCd, title }], activeCd: scrnCd };
        }),
      closeTab: (scrnCd) =>
        set((s) => {
          const idx = s.tabs.findIndex((t) => t.scrnCd === scrnCd);
          const tabs = s.tabs.filter((t) => t.scrnCd !== scrnCd);
          let activeCd = s.activeCd;
          // 닫는 탭이 활성일 때만 활성 탭을 옮긴다
          if (s.activeCd === scrnCd) {
            // 오른쪽 → 왼쪽 → 마지막 순으로 고른다 — 브라우저 탭과 같은 감각을 준다
            const next = tabs[idx] ?? tabs[idx - 1] ?? tabs[tabs.length - 1];
            activeCd = next ? next.scrnCd : null;
          }
          return { tabs, activeCd };
        }),
      reset: () => set({ tabs: [], activeCd: null }),
    }),
    {
      // sessionStorage 저장 키 — mes-web과 접두사를 구분해 세션이 섞이지 않게 한다
      name: "haccp-tabs",
      // 탭은 브라우저 탭 단위로만 유지한다 — 새 창은 빈 상태로 시작한다
      storage: createJSONStorage(() => sessionStorage),
      // 함수는 저장하지 않는다
      partialize: (s) => ({ tabs: s.tabs, activeCd: s.activeCd }),
    }
  )
);
