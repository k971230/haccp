/**
 * mesSec — 그리드·트리 패널 클릭 시 헤더(메뉴명) 초록 활성.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) mes-grid-head 를 직계 자식으로 둔 패널만 고른다. 중첩 분할에서 바깥 칸이 안쪽 헤더를 같이 칠하지 않는다
 *   2) data-mes-sec 은 React className 밖에 둔다. 조회·행클릭 setState 가 클래스를 덮어써도 초록이 유지된다
 *   3) 검색창 클릭은 패널이 아니므로 지우지 않는다. 다른 그리드·트리를 누를 때만 옮긴다
 *
 * PIPELINE[HF74] 패널 활성 — useActiveGrid 시각과 동일 emerald
 */
// 역할 — 캡처 클릭·포커스로 활성 패널을 고른다

/** 그리드·트리 제목 행 — global.css .mes-grid-head 계열 */
const HEAD_SEL =
  ":scope > .mes-grid-head, :scope > .mes-grid-block-head, :scope > .mes-grid-title-only";

/** 활성 표시 — CSS [data-mes-sec] . React className 과 섞이지 않는다 */
const ATTR = "data-mes-sec";

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 클릭 지점에서 헤더를 직계 자식으로 가진 가장 가까운 조상을 패널로 본다
 *   2) 헤더 자체를 눌렀을 때(= b·버튼) 부모를 반환한다
 *   3) 검색·사이드바처럼 헤더 패널이 아니면 null
 */
export function closestSecPanel(from: EventTarget | null): HTMLElement | null {
  let n: Element | null = from instanceof Element ? from : null;
  while (n) {
    if (
      n.classList.contains("mes-grid-head")
      || n.classList.contains("mes-grid-block-head")
      || n.classList.contains("mes-grid-title-only")
    ) {
      return n.parentElement;
    }
    if (n.querySelector(HEAD_SEL)) return n as HTMLElement;
    n = n.parentElement;
  }
  return null;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 같은 탭(또는 모달) 안에서만 활성을 옮긴다. hidden 탭 초록을 건드리지 않는다
 *   2) 패널에 data-mes-sec 을 단다
 *   3) 이전 패널 속성은 지운다
 */
export function activateSec(panel: HTMLElement): void {
  const root =
    panel.closest("[role='dialog']")
    ?? panel.closest("[data-mes-page]")
    ?? document.body;
  root.querySelectorAll(`[${ATTR}]`).forEach((el) => {
    if (el !== panel) el.removeAttribute(ATTR);
  });
  panel.setAttribute(ATTR, "");
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 캡처 click + focusin — 그리드 wrap·트리 버튼·헤더 클릭이 모두 들어온다
 *   2) HaccpShell 마운트 시 한 번 붙인다
 *   3) 언마운트에서 리스너를 뗀다
 */
export function bindMesSec(): () => void {
  const on = (e: Event) => {
    const panel = closestSecPanel(e.target);
    if (!panel) return;
    activateSec(panel);
  };
  document.addEventListener("click", on, true);
  document.addEventListener("focusin", on);
  return () => {
    document.removeEventListener("click", on, true);
    document.removeEventListener("focusin", on);
  };
}
