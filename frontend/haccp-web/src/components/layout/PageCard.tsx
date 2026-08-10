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
// 역할 — HTML div 속성·ReactNode
import type { HTMLAttributes, ReactNode } from "react";
// 역할 — className 병합
import { cn } from "@/lib/cn";

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
 * 일자: 2026-07-11
 * 코멘트:
 *   1) 좌 트리 10% · 우 본문 1fr (ADR-036)
 *   2) Tree+Grid 화면(Bom·단가·품목군·부서 등)
 *   3) grid 자식 사이 // 주석 금지 — 텍스트 노드로 열 깨짐
 */
export function PageCardTree({
  // 좌측 트리 슬롯 — TreePanel
  tree,
  // 우측 본문 — 그리드·PageCardSplit
  children,
}: {
  tree: ReactNode;
  children: ReactNode;
}) {
  return (
    <div className="grid min-h-0 flex-1 grid-cols-[minmax(180px,10%)_1fr] gap-4 overflow-hidden [&>*]:min-h-0">
      <div className="flex min-h-0 min-w-0 flex-col overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm">{tree}</div>
      <div className="flex min-h-0 min-w-0 flex-col overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm [&>*]:min-h-0 [&>*]:flex-1">{children}</div>
    </div>
  );
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-11
 * 코멘트:
 *   1) 세로 50/50 분할 — 마스터·디테일
 *   2) 단가 현행+이력, BOM 모품+자품 등
 *   3) mes-page-split 클래스로 균등 높이
 */
export function PageCardSplit({ children }: { children: ReactNode }) {
  return (
    <div className="mes-page-split flex min-h-0 flex-1 flex-col gap-4 overflow-hidden [&>*]:min-h-0 [&>*]:flex-1">
      {children}
    </div>
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
