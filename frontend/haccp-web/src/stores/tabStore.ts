/**
 * tabStore — 열린 탭 목록·활성 탭 전역 상태.
 *
 * 개발자: 박승우
 * 일자: 2026-08-21
 * 코멘트:
 *   1) HaccpShell이 URL에서 화면코드를 읽어 openTab 하고, 탭 목록은 sessionStorage에 영속된다
 *   2) 우클릭 메뉴의 다른·왼쪽·오른쪽·모두 닫기도 여기 한곳에서 목록을 줄인다
 *   3) 활성 탭이 지워지면 오른쪽 → 왼쪽 → 없음 순으로 옮긴다. URL 맞춤은 셸이 한다. set() 안에서 navigate 하지 않는다
 *
 * PIPELINE[HF30] Zustand 스토어
 * PIPELINE[HF49] 연관 모듈
 */
// 역할 — 전역 스토어 생성
import { create } from "zustand";
// 역할 — persist 미들웨어·JSON 저장소
import { persist, createJSONStorage } from "zustand/middleware";

/** 열린 탭 1건 */
export interface OpenTab {
  /** 화면코드 — 탭을 구분하는 키 */
  scrnCd: string;
  /** 탭에 표시할 제목 — 메뉴명을 그대로 쓴다 */
  title: string;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-21
 * 코멘트:
 *   1) 목록을 한 번에 줄인다. closeTab 을 여러 번 부르지 않는다
 *   2) 활성 탭이 남으면 유지. 지워졌으면 옛 인덱스 기준 오른쪽 → 왼쪽 → 마지막
 *   3) closeTab/Others/Left/Right 가 공통으로 호출한다. set() 안에는 navigate 가 없다
 */
function afterRemove(
  // 줄이기 전 목록 — 이웃 인덱스를 계산할 때 쓴다
  prev: OpenTab[],
  // 줄인 뒤 목록
  next: OpenTab[],
  // 줄이기 전 활성 화면코드
  prevActive: string | null
): { tabs: OpenTab[]; activeCd: string | null } {
  if (prevActive && next.some((t) => t.scrnCd === prevActive)) {
    return { tabs: next, activeCd: prevActive };
  }
  const idx = prev.findIndex((t) => t.scrnCd === prevActive);
  const pick = next[idx] ?? next[idx - 1] ?? next[next.length - 1];
  return { tabs: next, activeCd: pick ? pick.scrnCd : null };
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
  /** 우클릭 탭만 남기고 나머지 닫기 */
  closeOthers: (scrnCd: string) => void;
  /** 우클릭 탭보다 왼쪽을 모두 닫기 */
  closeLeft: (scrnCd: string) => void;
  /** 우클릭 탭보다 오른쪽을 모두 닫기 */
  closeRight: (scrnCd: string) => void;
  /** 열린 탭 전부 닫기 — 셸이 "/" 로 보낸다 */
  closeAll: () => void;
  /** 전체 초기화 — 로그아웃 시 다른 사용자에게 탭이 남지 않게 한다 */
  reset: () => void;
  /**
   * 허용된 화면코드만 남기고 나머지 탭을 닫는다.
   *
   * 권한이 다른 계정으로 갈아타면 이전 계정이 열어 둔 탭이 남는다 —
   * 그 화면은 열려 있지만 API 는 전부 403 이라 사용자는 「고장났다」고 느낀다.
   */
  keepOnly: (allowed: Set<string>) => void;
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
          if (!s.tabs.some((t) => t.scrnCd === scrnCd)) return s;
          // 단건도 afterRemove 한 번 — navigate 는 스토어 밖에 둔다
          return afterRemove(
            s.tabs,
            s.tabs.filter((t) => t.scrnCd !== scrnCd),
            s.activeCd
          );
        }),
      closeOthers: (scrnCd) =>
        set((s) => {
          const keep = s.tabs.find((t) => t.scrnCd === scrnCd);
          if (!keep) return s;
          return afterRemove(s.tabs, [keep], s.activeCd);
        }),
      closeLeft: (scrnCd) =>
        set((s) => {
          const idx = s.tabs.findIndex((t) => t.scrnCd === scrnCd);
          if (idx <= 0) return s;
          return afterRemove(s.tabs, s.tabs.slice(idx), s.activeCd);
        }),
      closeRight: (scrnCd) =>
        set((s) => {
          const idx = s.tabs.findIndex((t) => t.scrnCd === scrnCd);
          if (idx < 0 || idx >= s.tabs.length - 1) return s;
          return afterRemove(s.tabs, s.tabs.slice(0, idx + 1), s.activeCd);
        }),
      closeAll: () => set({ tabs: [], activeCd: null }),
      reset: () => set({ tabs: [], activeCd: null }),

      keepOnly: (allowed) =>
        set((s) => {
          const next = s.tabs.filter((t) => allowed.has(t.scrnCd));
          if (next.length === s.tabs.length) return s;
          return afterRemove(s.tabs, next, s.activeCd);
        }),
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
