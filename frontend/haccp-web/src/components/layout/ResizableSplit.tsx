/**
 * ResizableSplit — 2패널 드래그 분할 레이아웃.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 가로·세로 분할과 localStorage 비율 저장을 제공한다
 *   2) 가로일 때 좌 그리드/트리는 30 또는 50만 쓴다. 20·32·40 금지
 *   3) 비율만 갱신하며 API는 호출하지 않는다
 *
 * PIPELINE[HF92] 레이아웃 분할
 */
import {
  useCallback,
  useRef,
  useState,
  type PointerEvent as ReactPointerEvent,
  type ReactNode,
} from "react";
import { cn } from "@/lib/cn";

const DEFAULT_MIN = 20;
const DEFAULT_MAX = 80;

function clamp(n: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, n));
}

function readPct(storageKey: string, fallback: number, min: number, max: number): number {
  try {
    const raw = localStorage.getItem(storageKey);
    const n = raw == null ? NaN : Number(raw);
    if (!Number.isFinite(n)) return clamp(fallback, min, max);
    return clamp(n, min, max);
  } catch {
    return clamp(fallback, min, max);
  }
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) primary/secondary 두 패널을 드래그로 나눈다
 *   2) PageCardSplit·권한·부서·공통코드 등에서 마운트한다
 *   3) storageKey로 비율을 복원한다
 */
export function ResizableSplit({
  // 가로=좌우, 세로=상하
  orientation,
  // localStorage 키 — haccp-split-* 권장
  storageKey,
  // 첫 패널(좌·상) 기본 비율 %
  defaultPrimaryPct,
  // 최소·최대 %
  minPct = DEFAULT_MIN,
  maxPct = DEFAULT_MAX,
  // 좌·상 패널
  primary,
  // 우·하 패널
  secondary,
  // 패널 카드 테두리 적용 여부
  panelClassName,
  className,
}: {
  orientation: "horizontal" | "vertical";
  storageKey: string;
  defaultPrimaryPct?: number;
  minPct?: number;
  maxPct?: number;
  primary: ReactNode;
  secondary: ReactNode;
  panelClassName?: string;
  className?: string;
}) {
  const isH = orientation === "horizontal";
  const fallback = defaultPrimaryPct ?? (isH ? 70 : 50);
  const [pct, setPct] = useState(() => readPct(storageKey, fallback, minPct, maxPct));
  const boxRef = useRef<HTMLDivElement>(null);

  const onPointerDown = useCallback(
    (e: ReactPointerEvent<HTMLDivElement>) => {
      e.preventDefault();
      const el = boxRef.current;
      if (!el) return;
      const rect = el.getBoundingClientRect();
      const size = isH ? rect.width : rect.height;
      if (size <= 0) return;
      const start = isH ? e.clientX : e.clientY;
      const startPct = pct;
      const target = e.currentTarget;
      target.setPointerCapture(e.pointerId);

      const onMove = (ev: PointerEvent) => {
        const cur = isH ? ev.clientX : ev.clientY;
        const deltaPct = ((cur - start) / size) * 100;
        setPct(clamp(startPct + deltaPct, minPct, maxPct));
      };
      const onUp = (ev: PointerEvent) => {
        target.releasePointerCapture(ev.pointerId);
        target.removeEventListener("pointermove", onMove);
        target.removeEventListener("pointerup", onUp);
        target.removeEventListener("pointercancel", onUp);
        setPct((v) => {
          try {
            localStorage.setItem(storageKey, String(Math.round(v * 10) / 10));
          } catch {
            // 저장 실패 무시
          }
          return v;
        });
      };
      target.addEventListener("pointermove", onMove);
      target.addEventListener("pointerup", onUp);
      target.addEventListener("pointercancel", onUp);
    },
    [isH, maxPct, minPct, pct, storageKey],
  );

  const panelBase = cn(
    "flex min-h-0 min-w-0 flex-col overflow-hidden",
    panelClassName,
  );

  return (
    <div
      ref={boxRef}
      className={cn(
        "flex min-h-0 flex-1 overflow-hidden [&>*]:min-h-0",
        isH ? "flex-row" : "flex-col",
        className,
      )}
    >
      <div
        className={panelBase}
        style={
          isH
            ? { width: `${pct}%`, flex: "none" }
            : { height: `${pct}%`, flex: "none" }
        }
      >
        {primary}
      </div>
      <div
        role="separator"
        aria-orientation={isH ? "vertical" : "horizontal"}
        aria-valuenow={Math.round(pct)}
        aria-valuemin={minPct}
        aria-valuemax={maxPct}
        title="드래그하여 패널 크기 조절"
        className={cn(
          "group relative z-[1] shrink-0 bg-transparent hover:bg-slate-300/60 active:bg-slate-400/70",
          isH ? "w-1.5 cursor-col-resize" : "h-1.5 cursor-row-resize",
        )}
        onPointerDown={onPointerDown}
      >
        <span
          className={cn(
            "pointer-events-none absolute bg-slate-200 group-hover:bg-slate-400",
            isH
              ? "inset-y-0 left-1/2 w-px -translate-x-1/2"
              : "inset-x-0 top-1/2 h-px -translate-y-1/2",
          )}
        />
      </div>
      <div className={cn(panelBase, "flex-1")}>{secondary}</div>
    </div>
  );
}
