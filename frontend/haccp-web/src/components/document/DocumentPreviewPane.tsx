/**
 * DocumentPreviewPane — 문서함·결재 상세의 본문 미리보기 상자.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 기본은 펼친 상태다. HTML 은 원본 높이 그대로 두고 바깥 패널이 스크롤한다
 *   2) 접어도 본문을 언마운트하지 않는다 — 다시 펼칠 때 rhwp·지면을 다시 받지 않게
 *   3) 하단 핸들로 높이를 드래그한다. 좌우 폭은 바깥 ResizableSplit 몫이다
 *
 * HWP(rhwp) 는 부모 overflow-auto 에서 빈 페이지를 그리는 제약이 있어
 * 호스트 높이를 고정하고 안에서만 스크롤한다. HTML 은 그 제약이 없다.
 *
 * PIPELINE[HF187] 문서 미리보기 패널
 * PIPELINE[HF184] 연관 — 결재 문서 미리보기
 */
// 역할 — 접힘·높이·드래그 시작점
import { useRef, useState, type PointerEvent as ReactPointerEvent, type ReactNode } from "react";
// 역할 — 그리드 헤더와 같은 파란 막대
import { gridHeadClass } from "@/components/layout/pageClasses";
// 역할 — 접기/펼치기 버튼
import { MesButton } from "@/components/ui/MesButton";

/** HTML 미리보기 최소·최대 높이(px) — 드래그 하한/상한 */
const HEIGHT_MIN = 200;
const HEIGHT_MAX = 2400;
/** HWP 호스트 기본 높이 — 원본이 보이게 넉넉히. 드래그로 줄이거나 늘린다 */
const HWP_DEFAULT_HEIGHT = 768;

interface DocumentPreviewPaneProps {
  // hwp 면 호스트 높이 고정, html 이면 문서 길이만큼 펼친다
  kind: "hwp" | "html";
  // 미리보기 본문 — ApprovalDocumentPreview
  children: ReactNode;
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 미리보기 헤더·본문·하단 드래그 핸들을 그린다
 *   2) 문서함·결재대기·결재완료 상세에서 호출한다
 *   3) 접기는 hidden 만 토글한다. 드래그 중 텍스트 선택을 막는다
 */
export function DocumentPreviewPane({
  // hwp=호스트 고정 높이, html=원본 높이. 드래그 뒤에는 둘 다 같은 높이 상자를 쓴다
  kind,
  // 읽기전용 문서 본문
  children,
}: DocumentPreviewPaneProps) {
  // 기본 펼침 — 접으면 본문만 숨긴다
  const [open, setOpen] = useState(true);
  // null 이면 HTML 은 원본 높이, HWP 는 기본 고정 높이. 드래그하면 px
  const [height, setHeight] = useState<number | null>(null);
  const bodyRef = useRef<HTMLDivElement>(null);
  const dragRef = useRef<{ startY: number; startH: number } | null>(null);

  const resolvedHeight = height ?? (kind === "hwp" ? HWP_DEFAULT_HEIGHT : null);
  const constrained = resolvedHeight != null;

  /**
   * 개발자: 박승우
   * 일자: 2026-09-03
   * 코멘트:
   *   1) 미리보기 하단을 잡아 높이를 바꾼다
   *   2) 핸들 pointerdown 에서 호출한다
   *   3) pointerup 에서 리스너를 반드시 뗀다
   */
  const onResizePointerDown = (event: ReactPointerEvent<HTMLDivElement>) => {
    event.preventDefault();
    const current = resolvedHeight ?? bodyRef.current?.offsetHeight ?? HWP_DEFAULT_HEIGHT;
    dragRef.current = { startY: event.clientY, startH: current };
    const move = (ev: PointerEvent) => {
      const start = dragRef.current;
      if (!start) return;
      const next = Math.min(HEIGHT_MAX, Math.max(HEIGHT_MIN, start.startH + (ev.clientY - start.startY)));
      setHeight(next);
    };
    const up = () => {
      dragRef.current = null;
      window.removeEventListener("pointermove", move);
      window.removeEventListener("pointerup", up);
    };
    window.addEventListener("pointermove", move);
    window.addEventListener("pointerup", up);
  };

  return (
    <section className="flex min-h-0 flex-col overflow-hidden rounded border border-slate-100">
      <div className={gridHeadClass}>
        <b>문서 미리보기</b>
        <MesButton
          // 접기/펼치기 — 본문 적재를 유지한다
          variant="ghost"
          size="sm"
          icon={open ? "chevronUp" : "chevronDown"}
          onClick={() => setOpen((v) => !v)}
          aria-expanded={open}
        >
          {open ? "접기" : "펼치기"}
        </MesButton>
      </div>
      <div className={open ? undefined : "hidden"}>
        <div
          ref={bodyRef}
          // HWP 는 호스트 안에서만 스크롤. HTML 원본은 높이 제한 없고, 드래그한 뒤에는 상자 안에서 스크롤
          className={
            kind === "hwp"
              ? "flex min-h-0 flex-col overflow-hidden"
              : constrained
                ? "min-h-0 overflow-auto"
                : "overflow-visible"
          }
          style={constrained ? { height: resolvedHeight } : undefined}
        >
          {children}
        </div>
        <div
          // 세로 크기 조절 핸들 — 좌우 분할과 별개
          role="separator"
          aria-orientation="horizontal"
          aria-label="미리보기 높이 조절"
          className="h-2 shrink-0 cursor-ns-resize border-t border-slate-200 bg-slate-50 hover:bg-slate-100"
          onPointerDown={onResizePointerDown}
        />
      </div>
    </section>
  );
}
