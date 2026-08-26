/**
 * PageCard.tsx — layout UI 컴포넌트.
 *
 * 주요 역할:
 *     1. Page에서 조합해 사용하는 presentational/behavior component
 *     2. layout 영역 재사용 UI
 *
 * 설계 기준:
 *     - API 호출 없음(Page/훅 위임).
 *     - Props: [Name]Props 명명.
 *
 * PIPELINE[HF92] UI 컴포넌트 — mes-web PageCard와 동일 계약
 */
// 역할 — HTML div 속성·ReactNode·Children
import { Children, type HTMLAttributes, type ReactNode } from "react";
// 역할 — className 병합
import { cn } from "@/lib/cn";
// 역할 — 2패널 드래그 분할
import { ResizableSplit } from "@/components/layout/ResizableSplit";

/**
 * 개발자: 박승우
 * 일자: 2026-07-11
 * 코멘트:
 *   1) 업무 화면 외곽 — 검색 + 선택 툴바 + 본문
 *   2) Page 루트에서 SearchArea·본문 슬롯 조합 시
 *   3) 레이아웃만 렌더 (API 없음)
 */
export function PageCard({
  // 상단 검색 영역 슬롯(SearchArea 등)
  search,
  // 검색과 본문 사이 툴바 슬롯
  toolbar,
  // 본문 — PageCardTree / PageCardPanel 등
  children,
}: {
  search?: ReactNode;
  toolbar?: ReactNode;
  children: ReactNode;
}) {
  return (
    <div className="flex min-h-0 flex-1 flex-col gap-4 overflow-hidden">
      {search}
      {toolbar}
      <div className="flex min-h-0 flex-1 flex-col gap-4 overflow-hidden">{children}</div>
    </div>
  );
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 좌 트리 · 우 본문 — 드래그로 좌폭 조절
 *   2) Tree+Grid 화면에서 사용한다. 기본 좌 30
 *   3) storageKey로 비율을 저장한다
 */
export function PageCardTree({
  // 좌측 트리 슬롯 — TreePanel
  tree,
  // 우측 본문 — 그리드·PageCardSplit
  children,
  // localStorage 키 — 화면별 고유
  storageKey = "haccp-split-page-tree-30",
}: {
  tree: ReactNode;
  children: ReactNode;
  storageKey?: string;
}) {
  const card =
    "flex min-h-0 min-w-0 flex-1 flex-col overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm [&>*]:min-h-0 [&>*]:flex-1";
  return (
    <ResizableSplit
      // 좌우 분할
      orientation="horizontal"
      storageKey={storageKey}
      // 좌 트리 30 · 우 본문 70 — 가로 분할은 30 또는 50만
      defaultPrimaryPct={30}
      panelClassName={card}
      primary={tree}
      secondary={children}
    />
  );
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 세로 마스터·디테일 — 드래그로 상단 높이 조절
 *   2) 결재선·주기·이력 M-D 등에서 사용한다
 *   3) storageKey 필수 — 화면별 비율 분리
 */
export function PageCardSplit({
  // 상·하 두 패널(자식 정확히 2)
  children,
  // localStorage 키 — 화면별 고유
  storageKey,
}: {
  children: ReactNode;
  storageKey: string;
}) {
  const kids = Children.toArray(children);
  const top = kids[0] ?? null;
  const bottom = kids[1] ?? null;
  return (
    <ResizableSplit
      orientation="vertical"
      storageKey={storageKey}
      defaultPrimaryPct={50}
      minPct={25}
      maxPct={75}
      className="mes-page-split min-h-0 h-full flex-1 gap-0"
      primary={top}
      secondary={bottom}
    />
  );
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-11
 * 코멘트:
 *   1) 단일 그리드 패널 — border·shadow 카드
 *   2) Tree 없는 Single 화면 본문
 *   3) className으로 추가 스타일 병합
 */
export function PageCardPanel({
  // 패널 본문
  children,
  // 추가 className
  className = "",
  ...rest
}: { children: ReactNode; className?: string } & HTMLAttributes<HTMLDivElement>) {
  return (
    <div className={cn("flex min-h-0 flex-1 flex-col overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm", className)} {...rest}>
      {children}
    </div>
  );
}
