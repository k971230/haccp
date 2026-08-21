/**
 * TabContextMenu — 탭 우클릭 메뉴. Portal·좌표만 담당한다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-21
 * 코멘트:
 *   1) 메뉴 DOM은 body Portal. 탭바 overflow 밖으로 띄운다
 *   2) 화면 밖이면 좌표만 안으로 민다. 닫기 액션은 useTabStore 그대로
 *   3) 배치 닫기는 closeTab 루프가 아니다. closeOthers/Left/Right/All 이 afterRemove 한 번
 *
 * PIPELINE[HF49] 앱 셸
 */
// 역할 — 메뉴 좌표 보정·바깥 클릭 접기
import { useEffect, useLayoutEffect, useRef } from "react";
// 역할 — 탭바 overflow 밖으로 메뉴를 띄운다
import { createPortal } from "react-dom";
// 역할 — 열린 탭·닫기 액션. activateTab 은 없다. openTab 이 활성화한다
import { useTabStore, type OpenTab } from "@/stores/tabStore";

/** 우클릭 메뉴가 붙은 탭과 화면 좌표 */
export interface TabCtxMenu {
  // 메뉴를 띄울 가로 위치 — clientX
  x: number;
  // 메뉴를 띄울 세로 위치 — clientY
  y: number;
  // 우클릭한 탭 화면코드
  scrnCd: string;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-21
 * 코멘트:
 *   1) ctx 가 없으면 그리지 않는다
 *   2) 탭바가 우클릭 좌표를 넘길 때 마운트한다
 *   3) 항목 클릭 후 onClosed 로 URL 맞춤을 셸에 맡긴다
 */
export function TabContextMenu({
  // 우클릭한 탭·좌표. 없으면 메뉴를 그리지 않는다
  ctx,
  // 열린 탭 — 왼쪽/오른쪽/다른 탭 활성 판정
  tabs,
  // 화면 밖이면 좌표만 갱신한다. 메뉴는 유지
  onReposition,
  // 메뉴를 접는다
  onDismiss,
  // 닫기 직후 URL 맞춤
  onClosed,
}: {
  ctx: TabCtxMenu | null;
  tabs: OpenTab[];
  onReposition: (x: number, y: number) => void;
  onDismiss: () => void;
  onClosed: () => void;
}) {
  const closeTab = useTabStore((s) => s.closeTab);
  const closeOthers = useTabStore((s) => s.closeOthers);
  const closeLeft = useTabStore((s) => s.closeLeft);
  const closeRight = useTabStore((s) => s.closeRight);
  const closeAll = useTabStore((s) => s.closeAll);
  const menuRef = useRef<HTMLDivElement>(null);

  // 바깥 클릭·스크롤·Esc 이면 메뉴를 접는다. window contextmenu 는 탭 우클릭과 충돌하므로 쓰지 않는다
  useEffect(() => {
    if (!ctx) return;
    const close = () => onDismiss();
    const onEsc = (e: KeyboardEvent) => {
      if (e.key === "Escape") close();
    };
    window.addEventListener("mousedown", close);
    window.addEventListener("scroll", close, true);
    window.addEventListener("keydown", onEsc);
    return () => {
      window.removeEventListener("mousedown", close);
      window.removeEventListener("scroll", close, true);
      window.removeEventListener("keydown", onEsc);
    };
  }, [ctx, onDismiss]);

  // 메뉴가 화면 밖으로 나가면 좌표를 안으로 민다
  useLayoutEffect(() => {
    if (!ctx || !menuRef.current) return;
    const rect = menuRef.current.getBoundingClientRect();
    const vw = window.innerWidth;
    const vh = window.innerHeight;
    let { x, y } = ctx;
    if (x + rect.width > vw) x = Math.max(8, vw - rect.width - 8);
    if (y + rect.height > vh) y = Math.max(8, vh - rect.height - 8);
    if (x !== ctx.x || y !== ctx.y) onReposition(x, y);
  }, [ctx, onReposition]);

  if (!ctx) return null;

  const ctxIdx = tabs.findIndex((t) => t.scrnCd === ctx.scrnCd);
  const hasOthers = ctxIdx >= 0 && tabs.length > 1;
  const hasLeft = ctxIdx > 0;
  const hasRight = ctxIdx >= 0 && ctxIdx < tabs.length - 1;

  /**
   * 개발자: 박승우
   * 일자: 2026-08-21
   * 코멘트:
   *   1) 스토어 닫기를 먼저 하고 셸에 URL 맞춤을 맡긴다
   *   2) 메뉴 항목 클릭에서 호출한다
   *   3) 메뉴는 바로 접는다
   */
  const run = (fn: () => void) => {
    fn();
    onDismiss();
    onClosed();
  };

  return createPortal(
    <div
      ref={menuRef}
      className="mes-tab-ctx"
      style={{ top: ctx.y, left: ctx.x }}
      onMouseDown={(e) => e.stopPropagation()}
    >
      <button type="button" className="mes-tab-ctx-item" onClick={() => run(() => closeTab(ctx.scrnCd))}>
        이 탭 닫기
      </button>
      <button
        type="button"
        className="mes-tab-ctx-item"
        disabled={!hasOthers}
        onClick={() => run(() => closeOthers(ctx.scrnCd))}
      >
        다른 탭 모두 닫기
      </button>
      <button
        type="button"
        className="mes-tab-ctx-item"
        disabled={!hasLeft}
        onClick={() => run(() => closeLeft(ctx.scrnCd))}
      >
        왼쪽 탭 모두 닫기
      </button>
      <button
        type="button"
        className="mes-tab-ctx-item"
        disabled={!hasRight}
        onClick={() => run(() => closeRight(ctx.scrnCd))}
      >
        오른쪽 탭 모두 닫기
      </button>
      <div className="mes-tab-ctx-divider" />
      <button type="button" className="mes-tab-ctx-item" onClick={() => run(() => closeAll())}>
        모든 탭 닫기
      </button>
    </div>,
    document.body,
  );
}
