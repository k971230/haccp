/**
 * GridChrome — 그리드 툴바·헤더·필터행·푸터.
 * useMesTable 뷰 API 연동 (IME debounce, multi-sort, 열 DnD, pin).
 *
 * 열 너비(ADR-032): GridHeadCell·GridFilterRow th에 colWidthStyle(view.widthOf) —
 *   width=min=max 고정. 출처는 pref sizing → col.width → 120(데이터 글자수 무관).
 *
 * PIPELINE[F83] 그리드 크롬
 * PIPELINE[F90, F75, F163] 연관 모듈 — 열 메뉴 숨김은 pref v2 hidden
 */
// 역할 — React effect·ref·state
import { useEffect, useLayoutEffect, useRef, useState } from "react";
// 역할 — 열 메뉴를 body에 렌더 — mes-grid-wrap overflow-hidden 잘림 방지
import { createPortal } from "react-dom";
// 역할 — 정렬·필터·CSV·열·핀 아이콘
import { ArrowDown, ArrowUp, Download, Filter, LayoutGrid, Pin, Search } from "lucide-react";
// 역할 — 그리드 컬럼 정의 타입
import type { GridColumn } from "@/types/grid";
// 역할 — className 병합
import { cn } from "@/lib/cn";
// 역할 — 검색 input 공통 스타일
import { searchInputClass } from "@/components/ui/Input";
// 역할 — useMesTable 뷰 API 타입
import type { MesTableViewApi } from "./useMesTable";
// 역할 — 열 너비 고정 스타일 (width=min=max)
import { colWidthStyle } from "./gridUtils";
// 역할 — MES 통일 버튼
import { MesButton } from "@/components/ui/MesButton";

type View<T extends Record<string, any>> = MesTableViewApi<T>;

// IME 조합 중 필터 debounce 지연(ms)
const FILTER_DEBOUNCE_MS = 250;

/** 행번호·선택열 sticky 폭 합 — 데이터 열 left-pin 시작 offset */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 행번호(32px)·선택열(36px) 합산 — pin left 기준
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 설명 — 행번호(32px)·선택열(36px) 합산 — pin left 기준
export function gridLeadLeftPx(opts: { showRowNum?: boolean; selectable?: boolean }): number {
  return (opts.showRowNum ? 32 : 0) + (opts.selectable ? 36 : 0);
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-11
 * 코멘트:
 *   1) 그리드 상단 툴바 — 전역 검색·필터 토글·열 표시(portal)·CSV
 *   2) MesEditableGrid/MesDataGrid 상단에서 호출될 때
 *   3) 성공 시 메뉴·필터 동작, 실패 시 가드 없이 닫기만
 */
// 설명 — 그리드 상단 툴바 — 전역 검색·필터 토글·열 표시·CSV
export function GridToolbar<T extends Record<string, any>>(props: {
  view: View<T>; columns: GridColumn<T>[]; onExport: () => void; right?: React.ReactNode;
}) {
  const { view, columns } = props;
  const [colMenu, setColMenu] = useState(false);
  // 열 메뉴 fixed 좌표 — 「열」버튼 getBoundingClientRect 기준 (right=뷰포트 우측 여백)
  const [menuPos, setMenuPos] = useState<{ top: number; right: number } | null>(null);
  const [localQuery, setLocalQuery] = useState(view.query);
  const composing = useRef(false);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  // 열 버튼 래퍼 — 바깥 클릭 판별·메뉴 앵커
  const colMenuWrapRef = useRef<HTMLDivElement>(null);
  // portal 메뉴 패널 — 바깥 클릭 시 버튼·패널 모두 포함해 판별
  const colMenuPanelRef = useRef<HTMLDivElement>(null);

  useEffect(() => { setLocalQuery(view.query); }, [view.query]);
  useEffect(() => () => { if (timer.current) clearTimeout(timer.current); }, []);

  // 열 메뉴 열릴 때 버튼 위치 → fixed 좌표 (스크롤·리사이즈 시 재계산)
  useLayoutEffect(() => {
    if (!colMenu) {
      setMenuPos(null);
      return;
    }
    const place = () => {
      const el = colMenuWrapRef.current;
      // 버튼 래퍼가 없을 때(= 언마운트) 좌표 비움
      if (!el) { setMenuPos(null); return; }
      const r = el.getBoundingClientRect();
      setMenuPos({ top: r.bottom + 4, right: Math.max(8, window.innerWidth - r.right) });
    };
    place();
    window.addEventListener("resize", place);
    window.addEventListener("scroll", place, true);
    return () => {
      window.removeEventListener("resize", place);
      window.removeEventListener("scroll", place, true);
    };
  }, [colMenu]);

  // 열 메뉴 바깥 클릭·Escape 시 닫기 (portal 패널 포함 — mouseLeave 대체)
  useEffect(() => {
    if (!colMenu) return;
    const onDoc = (e: MouseEvent) => {
      const t = e.target as Node;
      // 버튼 래퍼·portal 패널 안 클릭일 때(= 메뉴 조작) 닫지 않음
      if (colMenuWrapRef.current?.contains(t) || colMenuPanelRef.current?.contains(t)) return;
      setColMenu(false);
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setColMenu(false);
    };
    document.addEventListener("mousedown", onDoc);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onDoc);
      document.removeEventListener("keydown", onKey);
    };
  }, [colMenu]);

  // IME 조합 중이 아닐 때만 debounce 후 view.setQuery 호출
  const pushQuery = (v: string) => {
    if (composing.current) return;
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => view.setQuery(v), FILTER_DEBOUNCE_MS);
  };

  // hard-hidden·coCd 제외 — 「열」메뉴에 표시할 컬럼 (숨김 상태여도 체크 가능)
  const menuColumns = columns.filter((c) => !c.hidden && c.field !== "coCd");

  return (
    <div className="flex min-h-9 shrink-0 flex-wrap items-center gap-1.5 border-b border-slate-200 bg-slate-50/70 px-3 py-2">
      <div className="relative">
        <Search className="pointer-events-none absolute left-2 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-slate-400" aria-hidden />
        <input
          // 추가 Tailwind/CSS 클래스
          // 기본 스타일 위에 병합(cn)
          className={cn(searchInputClass, "w-[180px] bg-white pl-7")}
          // 빈 값일 때 안내 문구
          // 입력 힌트용
          placeholder="결과 내 검색…"
          // 제어 컴포넌트 현재 값
          // 부모 state와 양방향 동기화
          value={localQuery}
          // 값 변경 콜백
          // 입력·체크·셀렉트 공통
          onChange={(e) => { setLocalQuery(e.target.value); pushQuery(e.target.value); }}
          onCompositionStart={() => { composing.current = true; }}
          onCompositionEnd={(e) => {
            composing.current = false;
            setLocalQuery(e.currentTarget.value);
            pushQuery(e.currentTarget.value);
          }}
        />
      </div>
      <div className="ml-auto flex flex-wrap items-center gap-1">
        <MesButton
          // 버튼 크기(sm/md/touch)
          // 그리드 헤더는 보통 sm, 키오스크는 touch
          size="sm"
          // 버튼 시각·의미 variant(search/save/add/danger 등)
          // buttonVariants cva와 매핑
          variant="secondary"
          // 좌측 아이콘 — MesIconName 문자열 또는 LucideIcon
          // loading 중에는 스피너로 대체
          icon={Filter}
          // 추가 Tailwind/CSS 클래스
          // 기본 스타일 위에 병합(cn)
          className={view.showFilter ? "ring-1 ring-brand-700/30" : undefined}
          // 클릭 핸들러
          // 비동기면 run/useAsyncAction으로 중복 클릭 방지 권장
          onClick={() => view.setShowFilter(!view.showFilter)}
          // 그리드 툴바/헤더에 표시할 제목
          // 비우면 제목 영역 생략 가능
          title="컬럼별 필터"
        >
          필터
        </MesButton>
        <div className="relative" ref={colMenuWrapRef}>
          <MesButton
            // 버튼 크기(sm/md/touch)
            size="sm"
            // 버튼 시각·의미 variant
            variant="secondary"
            // 좌측 아이콘 — 열 표시 메뉴
            icon={LayoutGrid}
            // 열 메뉴 열기/닫기 — portal 좌표는 useLayoutEffect가 맞춤
            onClick={() => setColMenu((v) => !v)}
            // 툴팁 — 열 표시/숨김
            title="열 표시/숨김"
          >
            열
          </MesButton>
          {colMenu && menuPos && createPortal(
            <div
              // portal 패널 ref — 바깥 클릭 판별에 사용
              ref={colMenuPanelRef}
              // mes-grid-wrap overflow-hidden에 잘리지 않도록 body+fixed (ADR-034)
              className="fixed z-[200] max-h-72 min-w-40 overflow-auto rounded-mes border border-slate-200 bg-white p-1.5 shadow-lg"
              // 버튼 하단·우측에 맞춤 — right는 뷰포트 우측에서의 거리
              style={{ top: menuPos.top, right: menuPos.right }}
              // 패널 ag.bind 캡처 클릭과 분리 — 체크 토글만 처리
              onClick={(e) => e.stopPropagation()}
              onMouseDown={(e) => e.stopPropagation()}
            >
              {menuColumns.map((c) => (
                <label
                  // 열 표시 한 줄 — 체크=표시, 해제=숨김(pref hidden)
                  key={c.field}
                  className="flex cursor-pointer items-center gap-1.5 rounded px-1.5 py-1 text-mes-ui hover:bg-slate-50"
                >
                  <input
                    // 체크박스 — 열 표시 여부
                    type="checkbox"
                    // 숨기지 않은 열이면 체크 — view.hidden[field]===true 이면 미체크
                    checked={!view.hidden[c.field]}
                    // 열 숨김 토글 — pref v2 hidden으로 debounce 저장
                    onChange={() => view.setHidden((h) => ({ ...h, [c.field]: !h[c.field] }))}
                  />
                  {c.header}
                </label>
              ))}
            </div>,
            // portal 마운트 대상 — wrap 밖 document.body (overflow 잘림 방지)
            document.body,
          )}
        </div>
        <MesButton
          // 버튼 크기 — 툴바 sm
          size="sm"
          // CSV 내보내기 variant
          variant="excel"
          // 다운로드 아이콘
          icon={Download}
          // CSV보내기 — MesEditableGrid/MesDataGrid가 넘긴 onExport
          onClick={props.onExport}
          // 툴팁
          title="CSV보내기"
        >
          CSV
        </MesButton>
        {props.right}
      </div>
    </div>
  );
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 헤더 셀 — 정렬·리사이즈·DnD 재정렬·왼쪽 pin
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 설명 — 헤더 셀 — 정렬·리사이즈·DnD 재정렬·왼쪽 pin
export function GridHeadCell<T extends Record<string, any>>(props: {
  col: GridColumn<T>;
  view: View<T>;
  sortable?: boolean;
  enableReorder?: boolean;
  leadLeftPx?: number;
}) {
  const { col, view, sortable = true, enableReorder = true, leadLeftPx = 0 } = props;
  const sortIdx = view.table.getState().sorting.findIndex((s) => s.id === col.field);
  const sorted = sortIdx >= 0
    ? (view.table.getState().sorting[sortIdx].desc ? "desc" : "asc")
    : null;
  const pinned = view.columnPinning.left?.includes(col.field)
    || view.columnPinning.right?.includes(col.field);

  // 마우스 드래그로 열 너비 조절
  const onResize = (e: React.MouseEvent) => {
    if (!sortable) return;
    e.preventDefault(); e.stopPropagation();
    const startX = e.clientX; const startW = view.widthOf(col);
    const move = (ev: MouseEvent) => view.setWidth(col.field, startW + (ev.clientX - startX));
    const up = () => {
      document.removeEventListener("mousemove", move);
      document.removeEventListener("mouseup", up);
    };
    document.addEventListener("mousemove", move);
    document.addEventListener("mouseup", up);
  };

// 설명 — 헤더 DnD — 열 순서 변경
  const onDragStart = (e: React.DragEvent) => {
    if (!enableReorder) return;
    e.dataTransfer.setData("text/mes-col", col.field);
    e.dataTransfer.effectAllowed = "move";
  };
  const onDragOver = (e: React.DragEvent) => {
    if (!enableReorder) return;
    e.preventDefault();
    e.dataTransfer.dropEffect = "move";
  };
  const onDrop = (e: React.DragEvent) => {
    if (!enableReorder) return;
    e.preventDefault();
    const from = e.dataTransfer.getData("text/mes-col");
    if (!from || from === col.field) return;
    // getColumn("__select") 금지 — 미존재 시 TanStack이 console.error → DnD/pref 저장 흐름 방해
    // getAllColumns().some 은 경고 없이 선택열 정의 여부만 판정
    const hasSelectCol = view.table.getAllColumns().some((c) => c.id === "__select");
    view.setColumnOrder((order) => {
      // order 비어 있을 때(= 초기·리셋) visibleCols 필드로 재구성
      const next = order.length ? [...order] : view.visibleCols.map((c) => c.field);
      for (const c of view.visibleCols) {
        if (!next.includes(c.field)) next.push(c.field);
      }
      // 행선택열(__select)이 정의돼 있으면 항상 선두 유지
      if (hasSelectCol && !next.includes("__select")) {
        next.unshift("__select");
      }
      const fi = next.indexOf(from);
      const ti = next.indexOf(col.field);
      // from/to 중 하나라도 order에 없을 때(= 드래그 데이터 불일치) 기존 order 유지
      if (fi < 0 || ti < 0) return order;
      next.splice(fi, 1);
      next.splice(ti, 0, from);
      return next;
    });
  };

// 설명 — 왼쪽 pin 토글 — left 배열에 추가/제거
  const togglePin = (e: React.MouseEvent) => {
    e.stopPropagation();
    view.setColumnPinning((prev) => {
      const left = [...(prev.left ?? [])];
      const right = [...(prev.right ?? [])];
      if (left.includes(col.field)) {
        return { left: left.filter((x) => x !== col.field), right };
      }
      if (right.includes(col.field)) {
        return { left, right: right.filter((x) => x !== col.field) };
      }
      return { left: [...left, col.field], right };
    });
  };

  const leftPins = view.columnPinning.left ?? [];
  const pinIdx = leftPins.indexOf(col.field);
  let pinLeft: number | undefined;
// 설명 — pin된 열의 sticky left offset 누적 계산
  if (pinIdx >= 0) {
    pinLeft = leadLeftPx;
    for (let i = 0; i < pinIdx; i++) {
      const id = leftPins[i];
      if (id === "__select") continue;
      const c = view.visibleCols.find((x) => x.field === id);
      if (c) pinLeft += view.widthOf(c);
    }
  }

  return (
    <th
      // 추가 Tailwind/CSS 클래스
      // 기본 스타일 위에 병합(cn)
      className={cn("relative p-0 group/th", pinIdx >= 0 && "mes-col-pinned")}
      style={{
        // 열 너비 고정(ADR-032) — colWidthStyle: width=min=max=widthOf(pref→col.width→120). 데이터 길이와 무관
        ...colWidthStyle(view.widthOf(col)),
        ...(pinLeft !== undefined ? { position: "sticky" as const, left: pinLeft, zIndex: 4 } : undefined),
      }}
      draggable={enableReorder}
      onDragStart={onDragStart}
      onDragOver={onDragOver}
      onDrop={onDrop}
    >
      <div
        // 추가 Tailwind/CSS 클래스
        // 기본 스타일 위에 병합(cn)
        className={cn("mes-th-inner", !sortable && "cursor-default")}
        // 클릭 핸들러
        // 비동기면 run/useAsyncAction으로 중복 클릭 방지 권장
        onClick={(e) => sortable && view.toggleSort(col.field, e.shiftKey)}
      >
        <span className={cn(col.required && "after:ml-0.5 after:font-bold after:text-rose-600 after:content-['*']")}>{col.header}</span>
        {sorted && (
          <span className="mes-th-sort">
            {sorted === "asc" ? <ArrowUp className="inline h-2.5 w-2.5" /> : <ArrowDown className="inline h-2.5 w-2.5" />}
            {view.table.getState().sorting.length > 1 && sortIdx >= 0 && (
              <span className="ml-0.5 text-[9px]">{sortIdx + 1}</span>
            )}
          </span>
        )}
        <button
          // HTML button/input type
          // 폼 안 조회 버튼은 submit
          type="button"
          // 추가 Tailwind/CSS 클래스
          // 기본 스타일 위에 병합(cn)
          className={cn(
            "mes-th-pin ml-0.5 inline-flex h-4 w-4 items-center justify-center rounded text-slate-400 hover:bg-slate-200 hover:text-slate-700",
            "opacity-0 group-hover/th:opacity-100 focus-visible:opacity-100",
            pinned && "opacity-100 text-blue-600",
          )}
          // 그리드 툴바/헤더에 표시할 제목
          // 비우면 제목 영역 생략 가능
          title={pinned ? "틀 고정 해제" : "왼쪽 틀 고정"}
          // 클릭 핸들러
          // 비동기면 run/useAsyncAction으로 중복 클릭 방지 권장
          onClick={togglePin}
        >
          <Pin className="h-2.5 w-2.5" aria-hidden />
        </button>
      </div>
      {sortable && (
        <div className="absolute right-0 top-0 z-[1] h-full w-1 cursor-col-resize hover:bg-slate-400/40" onMouseDown={onResize} />
      )}
    </th>
  );
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 다중선택 헤더 — 전체 선택 체크박스(indeterminate 지원)
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 설명 — 다중선택 헤더 — 전체 선택 체크박스(indeterminate 지원)
export function GridSelectHeadCell<T extends Record<string, any>>(props: {
  view: View<T>;
  leftOffset?: number;
}) {
  const { view, leftOffset = 0 } = props;
  const rows = view.table.getRowModel().rows;
  const all = rows.length > 0 && rows.every((r) => r.getIsSelected());
  const some = rows.some((r) => r.getIsSelected()) && !all;
  return (
    <th
      // 추가 Tailwind/CSS 클래스
      // 기본 스타일 위에 병합(cn)
      className="mes-rownum mes-col-pinned mes-col-select p-0"
      style={{ width: 36, position: "sticky", left: leftOffset, zIndex: 4 }}
    >
      <div className="mes-th-inner justify-center">
        <input
          // HTML button/input type
          // 폼 안 조회 버튼은 submit
          type="checkbox"
          // 추가 Tailwind/CSS 클래스
          // 기본 스타일 위에 병합(cn)
          className="h-3.5 w-3.5 rounded border-slate-300"
          // 체크박스 선택 여부
          // 제어 컴포넌트 value
          checked={all}
          // DOM/컴포넌트 ref
          // 포커스·측정용 forwardRef
          ref={(el) => { if (el) el.indeterminate = some; }}
          // 값 변경 콜백
          // 입력·체크·셀렉트 공통
          onChange={view.table.getToggleAllRowsSelectedHandler()}
          // 그리드 툴바/헤더에 표시할 제목
          // 비우면 제목 영역 생략 가능
          title="전체 선택 (표시 행)"
        />
      </div>
    </th>
  );
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 컬럼별 필터 입력 행 — 열마다 debounce 필터
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 설명 — 컬럼별 필터 입력 행 — 열마다 debounce 필터
export function GridFilterRow<T extends Record<string, any>>(props: {
  cols: GridColumn<T>[]; view: View<T>; leadCols?: number;
}) {
  const { cols, view } = props;
  const [local, setLocal] = useState<Record<string, string>>(view.colFilters);
  const composing = useRef<Record<string, boolean>>({});
  const timers = useRef<Record<string, ReturnType<typeof setTimeout>>>({});

  useEffect(() => { setLocal(view.colFilters); }, [view.colFilters]);

// 설명 — 컬럼별 필터 debounce — IME 조합 중 스킵
  const push = (field: string, value: string) => {
    if (composing.current[field]) return;
    if (timers.current[field]) clearTimeout(timers.current[field]);
    timers.current[field] = setTimeout(() => {
      view.setColFilters((f) => ({ ...f, [field]: value }));
    }, FILTER_DEBOUNCE_MS);
  };

  return (
    <thead>
      <tr className="border-b border-grid-border bg-grid-head">
        {Array.from({ length: props.leadCols ?? 0 }).map((_, i) => <th key={`l${i}`} />)}
        {cols.map((c) => (
          // 필터 th — 헤더와 동일 열 너비 고정(ADR-032), 긴 필터 입력으로 열 안 늘어남
          <th key={c.field} className="p-0.5" style={colWidthStyle(view.widthOf(c))}>
            <input
              // 추가 Tailwind/CSS 클래스
              // 기본 스타일 위에 병합(cn)
              className="h-[22px] w-full rounded border border-slate-200 px-1 text-[11px]"
              // 제어 컴포넌트 현재 값
              // 부모 state와 양방향 동기화
              value={local[c.field] ?? ""}
              // 빈 값일 때 안내 문구
              // 입력 힌트용
              placeholder="…"
              // 값 변경 콜백
              // 입력·체크·셀렉트 공통
              onChange={(e) => {
                const v = e.target.value;
                setLocal((s) => ({ ...s, [c.field]: v }));
                push(c.field, v);
              }}
              onCompositionStart={() => { composing.current[c.field] = true; }}
              onCompositionEnd={(e) => {
                composing.current[c.field] = false;
                const v = e.currentTarget.value;
                setLocal((s) => ({ ...s, [c.field]: v }));
                push(c.field, v);
              }}
            />
          </th>
        ))}
      </tr>
    </thead>
  );
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 하단 푸터 — 총/표시 건수·숫자열 집계 요약
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 설명 — 하단 푸터 — 총/표시 건수·숫자열 집계 요약
export function GridFooter<T extends Record<string, any>>(props: {
  cols: GridColumn<T>[];
  total: number;
  shown: number;
  aggregates?: Record<string, number | null>;
}) {
  const agg = props.aggregates ?? {};
  const parts = props.cols
    .filter((c) => agg[c.field] !== undefined && agg[c.field] !== null && c.field !== "seq")
    .map((c) => {
      const v = agg[c.field] as number;
      const fn = c.aggregationFn
        ?? ((c.type === "number" || c.type === "amount") && c.field !== "seq" ? "sum" : "");
      if (!fn) return null;
      const label = fn === "avg" ? "평균" : fn === "min" ? "최소" : fn === "max" ? "최대" : fn === "count" ? "건" : "합";
      const text = fn === "avg"
        ? v.toLocaleString(undefined, { maximumFractionDigits: 2 })
        : v.toLocaleString(undefined, { maximumFractionDigits: 4 });
      return `${c.header} ${label} ${text}`;
    })
    .filter(Boolean);

  return (
    <div className="flex min-h-8 shrink-0 items-center gap-2 overflow-hidden whitespace-nowrap border-t border-slate-200 bg-slate-100 px-3 py-1 text-[12px] text-slate-700">
      <span>총 <b className="font-semibold text-blue-600">{props.total}</b>건{props.shown !== props.total && <> · 표시 <b className="font-semibold text-blue-600">{props.shown}</b>건</>}</span>
      {parts.length > 0 && <span className="truncate text-slate-600">| {parts.join(" · ")}</span>}
    </div>
  );
}
