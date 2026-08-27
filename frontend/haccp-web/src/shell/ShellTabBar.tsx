/**
 * ShellTabBar — 셸 상단 열린 탭 줄. 제목은 선택이 안 되고 우클릭으로 닫는다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-21
 * 코멘트:
 *   1) I-빔·드래그 선택을 막기 위해 select-none 탭 칩만 둔다. 편집 가능한 요소는 쓰지 않는다
 *   2) 우클릭 메뉴는 TabContextMenu 가 Portal 로 그린다
 *   3) 닫기 후 URL 은 셸이 넘긴 onClosed 가 맞춘다
 *
 * PIPELINE[HF49] 앱 셸
 */
// 역할 — 우클릭 메뉴 좌표·열림 · 활성 탭 스크롤
import { useCallback, useEffect, useRef, useState } from "react";
// 역할 — className 병합
import { cn } from "@/lib/cn";
// 역할 — 열린 탭·단건 닫기. 배치 닫기는 TabContextMenu → store
import { useTabStore } from "@/stores/tabStore";
// 역할 — 우클릭 Portal 메뉴. 배치 닫기는 store afterRemove 한 번
import { TabContextMenu, type TabCtxMenu } from "./TabContextMenu";

/**
 * 개발자: 박승우
 * 일자: 2026-08-21
 * 코멘트:
 *   1) 탭 목록과 활성 코드를 받아 칩을 그린다
 *   2) 셸이 탭바만 이 컴포넌트에 맡길 때 마운트한다
 *   3) 탭이 없으면 셸이 이 컴포넌트를 그리지 않는다
 */
export function ShellTabBar({
  // 칩 좌클릭 — 해당 화면 경로로 이동
  onSelect,
  // 닫기 직후 URL 맞춤 — 스토어 activeCd 를 읽고 이동한다
  onClosed,
}: {
  onSelect: (scrnCd: string) => void;
  onClosed: () => void;
}) {
  const tabs = useTabStore((s) => s.tabs);
  const activeCd = useTabStore((s) => s.activeCd);
  const closeTab = useTabStore((s) => s.closeTab);

  /*
   * 탭이 스무 개를 넘으면 탭바가 가로로 넘친다(overflow-x-auto).
   * 스크롤은 되는데 화면을 옮겨도 탭바가 제자리라, 지금 보고 있는 화면의 탭이
   * 화면 밖에 남아 사용자가 직접 밀어서 찾아야 했다 — 「탭이 화면 밖으로 나간다」는 보고가 그것이다.
   * 활성 탭이 바뀔 때 그 칩을 보이는 자리로 끌어온다.
   */
  const barRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    // 활성 탭이 없을 때(= 탭을 전부 닫은 직후) 옮길 자리가 없다
    if (!activeCd) return;
    const chip = barRef.current?.querySelector<HTMLElement>(`[data-tab-cd="${CSS.escape(activeCd)}"]`);
    // 칩이 아직 안 그려졌을 때(= 탭 추가 직후) 다음 렌더에서 다시 온다
    chip?.scrollIntoView({ block: "nearest", inline: "nearest" });
  }, [activeCd, tabs.length]);

  const [ctx, setCtx] = useState<TabCtxMenu | null>(null);
  const onReposition = useCallback((x: number, y: number) => {
    setCtx((prev) => (prev ? { ...prev, x, y } : prev));
  }, []);
  const onDismiss = useCallback(() => setCtx(null), []);

  /**
   * 개발자: 박승우
   * 일자: 2026-08-21
   * 코멘트:
   *   1) 스토어 닫기를 먼저 하고 셸에 URL 맞춤을 맡긴다
   *   2) 칩 × 클릭에서 호출한다
   *   3) 메뉴는 바로 접는다
   */
  const runClose = (fn: () => void) => {
    fn();
    setCtx(null);
    onClosed();
  };

  return (
    <>
      <div
        // 활성 탭을 보이는 자리로 끌어올 때 기준이 되는 스크롤 상자
        ref={barRef}
        className="flex min-h-8 shrink-0 select-none items-stretch gap-1 overflow-x-auto border-b border-slate-200 bg-white/90 px-2 pt-1.5 shadow-sm"
      >
        {tabs.map((t) => {
          const active = t.scrnCd === activeCd;
          return (
            <div
              key={t.scrnCd}
              // 활성 탭을 찾아 스크롤할 때 쓰는 손잡이
              data-tab-cd={t.scrnCd}
              role="tab"
              aria-selected={active}
              className={cn(
                "relative top-px flex min-h-7 cursor-pointer select-none items-center gap-1.5 whitespace-nowrap rounded-t-lg border border-b-0 border-slate-200 px-3 text-mes-ui [&_*]:cursor-pointer [&_*]:select-none",
                active
                  ? "border-b-white bg-white font-semibold text-blue-600 shadow-sm"
                  : "bg-slate-50/80 text-slate-500 hover:bg-white",
              )}
              onClick={() => onSelect(t.scrnCd)}
              onContextMenu={(e) => {
                e.preventDefault();
                e.stopPropagation();
                setCtx({ x: e.clientX, y: e.clientY, scrnCd: t.scrnCd });
              }}
            >
              <span className={cn("h-1.5 w-1.5 rounded-full", active ? "bg-blue-600" : "bg-slate-300")} />
              <span>{t.title}</span>
              <span
                className="rounded px-0.5 text-sm text-slate-400 hover:bg-slate-100 hover:text-slate-600"
                // 닫기 클릭이 탭 선택으로도 처리되지 않게 전파를 막는다
                onClick={(e) => {
                  e.stopPropagation();
                  runClose(() => closeTab(t.scrnCd));
                }}
              >
                ×
              </span>
            </div>
          );
        })}
      </div>
      <TabContextMenu
        ctx={ctx}
        tabs={tabs}
        onReposition={onReposition}
        onDismiss={onDismiss}
        onClosed={onClosed}
      />
    </>
  );
}
