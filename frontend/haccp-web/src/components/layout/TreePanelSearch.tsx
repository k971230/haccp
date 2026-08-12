/**
 * TreePanelSearch — 좌측 트리 「결과 내 검색」입력(검색 버튼 없음).
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 그리드 툴바(GridChrome)와 동일 h-9·테두리로 화면 전환 시 높이 흔들림을 막는다
 *   2) 메뉴·부서·로그·권한 트리에 공통으로 쓴다 — 입력만으로 필터한다
 *   3) action 슬롯에 권한저장 등 화면별 버튼을 둘 수 있다
 *
 * PIPELINE[HF92] 트리 검색
 */
import type { ReactNode } from "react";
import { Search } from "lucide-react";
import { searchInputClass } from "@/components/ui/Input";
import { cn } from "@/lib/cn";

/** 분할 패널 제목 행(좌 트리·우 그리드 공통) — 고정 h-9, wrap 금지로 화면 전환 시 흔들림 방지 */
export const treePanelHeadClass =
  "mes-grid-head flex h-9 shrink-0 items-center justify-between gap-2 overflow-hidden border-b border-slate-200 bg-slate-50/70 px-3 [&_b]:truncate [&_b]:text-mes-ui [&_b]:font-bold [&_b]:text-black";

/** 트리 노드 선택 — 사이드 메뉴 리프 활성(mes-sidebar-leaf-active)과 동일 */
export const treeNodeSelectedClass = "bg-blue-100 font-bold text-blue-700";
/** 트리 노드 비선택 */
export const treeNodeIdleClass = "text-slate-700 hover:bg-slate-100";

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 검색 입력만 렌더하고 필요 시 우측 action을 붙인다
 *   2) 트리 패널에서 제목 바로 아래에 둔다
 *   3) API 없이 부모 state만 갱신한다
 */
export function TreePanelSearch({
  // 검색어
  value,
  // 입력 변경 — 타이핑 즉시 필터
  onChange,
  // Enter — 펼침 등(선택). 검색 버튼은 두지 않는다
  onSearch,
  // 입력 우측 슬롯 — 권한저장 등
  action,
}: {
  value: string;
  onChange: (value: string) => void;
  onSearch?: () => void;
  action?: ReactNode;
}) {
  return (
    <div
      // 그리드 툴바와 동일 높이·패딩 — 화면 전환 시 검색바 위치 고정
      className="flex h-9 shrink-0 items-center gap-1.5 border-b border-slate-200 bg-slate-50/70 px-3"
    >
      <div className="relative min-w-0 flex-1">
        <Search
          className="pointer-events-none absolute left-2 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-slate-400"
          aria-hidden
        />
        <input
          // 트리 결과 내 검색 — 입력만으로 필터
          className={cn(searchInputClass, "h-7 w-full bg-white pl-7")}
          placeholder="결과 내 검색…"
          value={value}
          onChange={(e) => onChange(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") {
              e.preventDefault();
              onSearch?.();
            }
          }}
        />
      </div>
      {action}
    </div>
  );
}
