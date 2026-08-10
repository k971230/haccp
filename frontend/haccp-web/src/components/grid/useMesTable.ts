/**
 * useMesTable — TanStack Table v8 그리드 뷰 상태.
 *
 * - 정렬·필터·visibility·sizing·order·pin·rowSelection
 * - pref v2 DB: hidden + order + sizing (sorting/필터는 세션)
 * - dirty-pin / C-keep, columnsStructureKey로 컬럼 참조 안정화
 * - 데이터·잠금·저장은 페이지(useEditableRows / rules) 소유 — meta로만 연결
 * - 열 숨김 저장: layoutRef는 변경 핸들러·commit effect만 갱신(매 렌더 덮어쓰기 금지)
 
 * PIPELINE[F75]
 * PIPELINE[F163] pref v2 직렬화 연동
 */
// 역할 — React 상태·ref·effect·메모·콜백 훅
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
// 역할 — 서버 그리드 pref 조회·캐시용 React Query
import { useQuery, useQueryClient } from "@tanstack/react-query";
// 역할 — TanStack Table v8 — 테이블 인스턴스·정렬·필터·열 레이아웃
import {
  useReactTable,
  getCoreRowModel,
  getSortedRowModel,
  getFilteredRowModel,
  type ColumnDef,
  type ColumnFiltersState,
  type ColumnOrderState,
  type ColumnPinningState,
  type ColumnSizingState,
  type FilterFn,
  type RowSelectionState,
  type SortingFn,
  type SortingState,
  type VisibilityState,
  type Table,
  type Updater,
} from "@tanstack/react-table";
// 역할 — 그리드 컬럼·행 기본 타입
import type { GridColumn, GridRowBase } from "@/types/grid";
// 역할 — DB 저장 그리드 열 설정(pref v2) API
import { getGridPref, saveGridPref } from "@/api/prefApi";
// 역할 — pref JSON 파싱·직렬화
import { parseGridPref, serializeGridPref } from "./gridPref";
// 역할 — 필터 문자열 정규화(콤마·대소문자)
import { normalizeFilterText } from "./gridFilterNormalize";
// 역할 — TanStack Table meta 확장 타입(활성셀·집계)
import type { MesActiveCell, MesAggregationFn } from "./tanstack-table";

// 설명 — TanStack meta 확장 타입 재export
export type { MesActiveCell, MesAggregationFn };

/** GridChrome / Mes*Grid 가 쓰는 뷰 API */
export interface MesTableViewApi<T extends GridRowBase> {
  table: Table<T>;
  visibleCols: GridColumn<T>[];
  sort: { field: string | null; dir: "asc" | "desc" };
  toggleSort: (field: string, multi?: boolean) => void;
  query: string;
  setQuery: (q: string) => void;
  colFilters: Record<string, string>;
  setColFilters: (updater: Updater<Record<string, string>>) => void;
  hidden: Record<string, boolean>;
  setHidden: (updater: Updater<Record<string, boolean>>) => void;
  showFilter: boolean;
  setShowFilter: (v: boolean) => void;
  widthOf: (c: GridColumn<T>) => number;
  setWidth: (field: string, w: number) => void;
  columnOrder: ColumnOrderState;
  setColumnOrder: (updater: Updater<ColumnOrderState>) => void;
  columnPinning: ColumnPinningState;
  setColumnPinning: (updater: Updater<ColumnPinningState>) => void;
  rowSelection: RowSelectionState;
  setRowSelection: (updater: Updater<RowSelectionState>) => void;
  activeCell: MesActiveCell;
  setActiveCell: (c: MesActiveCell) => void;
  displayRows: T[];
  aggregates: Record<string, number | null>;
  totalCount: number;
  shownCount: number;
}

export interface UseMesTableOptions<T extends GridRowBase> {
  columns: GridColumn<T>[];
  data: T[];
  getRowId: (row: T) => string;
  persistId?: string;
  scrnCd?: string;
  /** 편집 그리드: C/U dirty-pin + C-keep 필터 */
  enableDirtyPin?: boolean;
  enableRowSelection?: boolean;
  enableMultiSort?: boolean;
  meta?: {
    mode?: "view" | "edit";
    updateCell?: (rowKey: string, field: string, value: unknown) => void;
    isCellEditable?: (row: T, field: string) => boolean;
  };
  cellText: (row: T, c: GridColumn<T>) => string;
}

// 설명 — 신규(C) 행 여부 — dirty-pin 필터에서 항상 표시
function isCreatedRow(row: { _rowState?: string }): boolean {
  return row._rowState === "C";
}
// 설명 — 변경(C/U) 행 여부 — dirty-pin 정렬 시 하단 고정 (행추가는 바닥)
function isDirtyRow(row: { _rowState?: string }): boolean {
  return row._rowState === "C" || row._rowState === "U";
}

// 설명 — TanStack Updater(값|함수) 해석
function resolveUpdater<T>(updater: Updater<T>, prev: T): T {
  return typeof updater === "function" ? (updater as (p: T) => T)(prev) : updater;
}

// 설명 — GridColumn[] → TanStack ColumnDef[] 변환(__select·coCd 제외)
function toColumnDefs<T extends GridRowBase>(
  columns: GridColumn<T>[],
  opts?: { enableRowSelection?: boolean },
): ColumnDef<T, unknown>[] {
  const defs: ColumnDef<T, unknown>[] = [];

  if (opts?.enableRowSelection) {
    defs.push({
      id: "__select",
      size: 36,
      minSize: 36,
      maxSize: 36,
      enableSorting: false,
      enableResizing: false,
      enableHiding: false,
    });
  }

  for (const col of columns) {
    if (col.hidden || col.field === "coCd") continue;
    const numeric = col.type === "number" || col.type === "amount";
    const defaultSum = numeric && col.field !== "seq" ? "sum" : undefined;
    const agg = col.aggregationFn ?? defaultSum;
    defs.push({
      id: col.field,
      accessorKey: col.field,
      size: col.width ?? 120,
      minSize: 50,
      enableSorting: true,
      enableResizing: true,
      enableHiding: true,
      enableMultiSort: true,
      filterFn: "mesText",
      sortingFn: numeric ? "mesNumeric" : "mesTextSort",
      meta: {
        col: col as GridColumn<T & Record<string, unknown>>,
        aggregationFn: agg,
      },
    });
  }
  return defs;
}

// 설명 — 초기 열 순서 — 선택열 있으면 __select 선두
function defaultColumnOrder<T extends GridRowBase>(
  columns: GridColumn<T>[],
  enableRowSelection: boolean,
): ColumnOrderState {
  const fields = columns.filter((c) => !c.hidden && c.field !== "coCd").map((c) => c.field);
  return enableRowSelection ? ["__select", ...fields] : fields;
}

/** 컬럼 구조 키 — 참조가 달라도 내용 같으면 동일 (cellButton 콜백 제외) */
// 설명 — columns 배열 참조 변경 시 불필요한 columnDefs 재생성 방지
function columnsStructureKey<T extends GridRowBase>(columns: GridColumn<T>[]): string {
  return columns
    .map((c) =>
      [
        c.field,
        c.header,
        c.width ?? "",
        c.type ?? "",
        c.hidden ? 1 : 0,
        c.defaultHidden ? 1 : 0,
        c.aggregationFn ?? "",
        c.editable ? 1 : 0,
        c.editableOnNew ? 1 : 0,
        c.required ? 1 : 0,
        c.align ?? "",
        c.codeOptions?.map((o) => o.value).join(",") ?? "",
      ].join("\u001f"),
    )
    .join("\u001e");
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 그리드 뷰 상태 훅 — 정렬·필터·열 레이아웃·선택·집계
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 설명 — 그리드 뷰 상태 훅 — 정렬·필터·열 레이아웃·선택·집계
export function useMesTable<T extends GridRowBase>(opts: UseMesTableOptions<T>): MesTableViewApi<T> {
  const {
    columns,
    data,
    getRowId,
    persistId,
    scrnCd = "",
    enableDirtyPin = false,
    enableRowSelection = false,
    enableMultiSort = true,
    meta: userMeta,
    cellText,
  } = opts;

// 설명 — persistId·scrnCd 둘 다 있을 때만 DB pref 저장
  const canPersist = !!persistId && !!scrnCd;

// 설명 — dirty-pin: 변경행 정렬 시 원본 순서 유지용 인덱스 맵
  const originalIndexMap = useMemo(() => {
    const m = new Map<string, number>();
    data.forEach((r, i) => m.set(getRowId(r), i));
    return m;
  }, [data, getRowId]);

// 설명 — 필터/정렬 콜백에서 최신 cellText 참조
  const cellTextRef = useRef(cellText);
  cellTextRef.current = cellText;
// 설명 — 필터/정렬 콜백에서 최신 columns 참조
  const columnsRef = useRef(columns);
  columnsRef.current = columns;
// 설명 — 컬럼 구조 변경 감지 시그니처
  const columnsSig = useMemo(() => columnsStructureKey(columns), [columns]);

// 설명 — TanStack 테이블 뷰 상태(세션 — DB 미저장)
  const [sorting, setSorting] = useState<SortingState>([]);
  const [globalFilter, setGlobalFilter] = useState("");
  const [columnFilters, setColumnFilters] = useState<ColumnFiltersState>([]);
  const [columnVisibility, setColumnVisibility] = useState<VisibilityState>(() => {
    const v: VisibilityState = {};
    for (const c of columns) {
      if (c.defaultHidden) v[c.field] = false;
    }
    return v;
  });
  const [columnSizing, setColumnSizing] = useState<ColumnSizingState>({});
  const [columnOrder, setColumnOrder] = useState<ColumnOrderState>(() =>
    defaultColumnOrder(columns, enableRowSelection),
  );
  const [columnPinning, setColumnPinning] = useState<ColumnPinningState>({
    left: enableRowSelection ? ["__select"] : [],
    right: [],
  });
  const [rowSelection, setRowSelection] = useState<RowSelectionState>({});
  const [showFilter, setShowFilter] = useState(false);
  const [activeCell, setActiveCell] = useState<MesActiveCell>(null);

// 설명 — DB에서 그리드 열 pref v2 로드
  const queryClient = useQueryClient();
  const prefQ = useQuery({
    queryKey: ["gridPref", scrnCd, persistId],
    queryFn: () => getGridPref(scrnCd, persistId as string),
    enabled: canPersist,
    staleTime: Infinity,
  });
  // pref 1회 적용 여부 — true 이후 사용자 변경만 persistLayout
  const loadedRef = useRef(false);
  // 로드 완료 전 사용자 변경이 있으면 로드 직후 1회 저장
  const pendingPersistRef = useRef(false);
  // 열 레이아웃 스냅샷 — 변경 핸들러·commit effect만 갱신 (매 렌더 덮어쓰기 금지 → 숨김 레이스 방지)
  const layoutRef = useRef({ columnVisibility, columnOrder, columnSizing });
  const saveTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  // persistLayout 최신 참조 — load effect에서 pending flush용
  const persistLayoutRef = useRef<() => void>(() => {});

  useEffect(() => {
    layoutRef.current = { columnVisibility, columnOrder, columnSizing };
  }, [columnVisibility, columnOrder, columnSizing]);

  /**
   * 개발자: 박승우
   * 일자: 2026-07-10
   * 코멘트:
   *   1) hidden·order·sizing → pref v2 DB 저장(500ms debounce)
   *   2) 열 숨김·DnD·리사이즈 직후
   *   3) 성공 시 RQ 캐시 갱신, 로드 전이면 pending 후 flush
   */
  const persistLayout = useCallback(() => {
    if (!canPersist) return;
    // pref 로드 전 변경 — 로드 완료 후 flush (숨김이 저장 누락되던 케이스)
    if (!loadedRef.current) {
      pendingPersistRef.current = true;
      return;
    }
    if (saveTimer.current) clearTimeout(saveTimer.current);
    saveTimer.current = setTimeout(() => {
      // debounce 만료 시점의 최신 스냅샷 (숨김·order·sizing 모두)
      const { columnVisibility: vis, columnOrder: order, columnSizing: sizing } = layoutRef.current;
      const hidden: Record<string, boolean> = {};
      for (const c of columns) {
        if (c.hidden || c.field === "coCd") continue;
        // false일 때만 숨김 — undefined/true는 표시
        if (vis[c.field] === false) hidden[c.field] = true;
      }
      const orderFields = order.filter((id) => id !== "__select");
      const prefJson = serializeGridPref({ hidden, order: orderFields, sizing });
      void saveGridPref(scrnCd, persistId as string, prefJson).then(() => {
        // 탭 keep-alive 재마운트 시 옛 캐시로 숨김이 되돌아오지 않게 RQ 캐시 동기화
        queryClient.setQueryData(["gridPref", scrnCd, persistId], prefJson);
      });
    }, 500);
  }, [canPersist, columns, persistId, scrnCd, queryClient]);
  persistLayoutRef.current = persistLayout;

  /**
   * 개발자: 박승우
   * 일자: 2026-07-11
   * 코멘트:
   *   1) DB pref v2 1회 적용 — hidden·order·sizing 복원 (ADR-035)
   *   2) 컬럼 정의에만 있는 신규열(예: useYn)은 order 뒤·visibility true로 병합
   *   3) 로드 전 사용자 숨김 변경은 pendingPersist로 flush
   */
  useEffect(() => {
    if (!canPersist || loadedRef.current) return;
    // 로드 실패 시에도 저장 허용
    if (prefQ.isError) {
      loadedRef.current = true;
      if (pendingPersistRef.current) {
        pendingPersistRef.current = false;
        persistLayoutRef.current();
      }
      return;
    }
    if (prefQ.isLoading || prefQ.data === undefined) return;
    const raw = prefQ.data;
    const parsed = parseGridPref(raw);
    // DB에 저장본이 있을 때(= 빈 문자열 아님) 숨김 집합을 전체 열에 대해 확정 적용
    // — defaultHidden 해제·부분 merge로 숨김이 복원 누락되던 문제 방지
    // — 신규 컬럼(예: useYn)은 pref.hidden에 없으면 표시(true)
    const hasSavedPref = !!raw.trim();
    // order: 저장 순서 유지 + 정의에만 있는 신규 필드(사용 등)를 뒤에 병합
    const known = new Set<string>(
      columns.filter((c) => !c.hidden && c.field !== "coCd").map((c) => c.field),
    );
    const fromPref = parsed.order.filter((id) => known.has(id));
    const missing = [...known].filter((id) => !fromPref.includes(id));
    setColumnVisibility((prev) => {
      if (!hasSavedPref) {
        // 저장 pref 없을 때(= 신규 persistId) — 정의에만 있는 필드도 표시 강제
        if (!missing.length) return prev;
        const next: VisibilityState = { ...prev };
        for (const id of missing) next[id] = true;
        return next;
      }
      const next: VisibilityState = { ...prev };
      for (const c of columns) {
        if (c.hidden || c.field === "coCd") continue;
        // pref.hidden에 있으면 숨김, 없으면 표시 — 정의에만 있는 신규 열도 메뉴·그리드에 포함
        next[c.field] = parsed.hidden[c.field] !== true;
      }
      // pref.order에 없던 신규 열(사용 등)은 숨김 저장이 있어도 최초 1회 표시 강제
      for (const id of missing) next[id] = true;
      return next;
    });
    {
      const order = fromPref.length || missing.length ? [...fromPref, ...missing] : [...known];
      if (enableRowSelection) setColumnOrder(["__select", ...order]);
      else setColumnOrder(order);
    }
    if (Object.keys(parsed.sizing).length) {
      setColumnSizing((prev) => ({ ...prev, ...parsed.sizing }));
    }
    loadedRef.current = true;
    // 로드 전 사용자 숨김·배치 변경 flush
    if (pendingPersistRef.current) {
      pendingPersistRef.current = false;
      queueMicrotask(() => persistLayoutRef.current());
    }
  }, [canPersist, prefQ.data, prefQ.isLoading, prefQ.isError, columns, enableRowSelection]);

  useEffect(() => () => {
    if (saveTimer.current) clearTimeout(saveTimer.current);
  }, []);

  const onColumnVisibilityChange = useCallback(
    (updater: Updater<VisibilityState>) => {
      setColumnVisibility((prev) => {
        const next = resolveUpdater(updater, prev);
        layoutRef.current = { ...layoutRef.current, columnVisibility: next };
        queueMicrotask(() => persistLayout());
        return next;
      });
    },
    [persistLayout],
  );

  const onColumnOrderChange = useCallback(
    (updater: Updater<ColumnOrderState>) => {
      setColumnOrder((prev) => {
        let next = resolveUpdater(updater, prev);
        // 선택열 미사용 시 order에 남은 __select 제거 — getColumn 경고·레이아웃 꼬임 방지
        if (!enableRowSelection) {
          next = next.filter((id) => id !== "__select");
        } else if (!next.includes("__select")) {
          // 행선택 사용 시 __select 항상 선두
          next = ["__select", ...next.filter((id) => id !== "__select")];
        }
        layoutRef.current = { ...layoutRef.current, columnOrder: next };
        queueMicrotask(() => persistLayout());
        return next;
      });
    },
    [persistLayout, enableRowSelection],
  );

  const onColumnSizingChange = useCallback(
    (updater: Updater<ColumnSizingState>) => {
      setColumnSizing((prev) => {
        const next = resolveUpdater(updater, prev);
        layoutRef.current = { ...layoutRef.current, columnSizing: next };
        queueMicrotask(() => persistLayout());
        return next;
      });
    },
    [persistLayout],
  );

// 설명 — 열별 텍스트 필터 — dirty-pin 시 신규행 항상 통과
  const mesTextFilter: FilterFn<T> = useCallback((row, columnId, filterValue) => {
    const q = normalizeFilterText(String(filterValue ?? ""));
    if (!q) return true;
    if (enableDirtyPin && isCreatedRow(row.original as { _rowState?: string })) return true;
    const col = columnsRef.current.find((c) => c.field === columnId);
    if (!col) return true;
    const text = cellTextRef.current(row.original, col);
    return normalizeFilterText(text).includes(q);
  }, [enableDirtyPin]);

// 설명 — 툴바 전역 검색 — 모든 visible 열 텍스트 매칭
  const globalFilterFn: FilterFn<T> = useCallback((row, _columnId, filterValue) => {
    const q = normalizeFilterText(String(filterValue ?? ""));
    if (!q) return true;
    if (enableDirtyPin && isCreatedRow(row.original as { _rowState?: string })) return true;
    return columnsRef.current.some((c) => {
      if (c.hidden || c.field === "coCd") return false;
      return normalizeFilterText(cellTextRef.current(row.original, c)).includes(q);
    });
  }, [enableDirtyPin]);

// 설명 — 숫자 정렬 — dirty-pin 시 변경행 하단·원본 순서 유지 (행추가는 바닥)
  const mesNumericSort: SortingFn<T> = useCallback((rowA, rowB, columnId) => {
    if (enableDirtyPin) {
      const da = isDirtyRow(rowA.original as { _rowState?: string });
      const db = isDirtyRow(rowB.original as { _rowState?: string });
      // 변경행(C/U)을 목록 바닥으로 — 신규 행추가가 위에서 끼어들지 않음
      if (da !== db) return da ? 1 : -1;
      if (da && db) {
        const ia = originalIndexMap.get(rowA.id) ?? 0;
        const ib = originalIndexMap.get(rowB.id) ?? 0;
        return ia - ib;
      }
    }
    const av = rowA.getValue(columnId);
    const bv = rowB.getValue(columnId);
    const an = av === null || av === undefined || av === "" ? null : Number(av);
    const bn = bv === null || bv === undefined || bv === "" ? null : Number(bv);
    if (an === null && bn === null) return 0;
    if (an === null) return 1;
    if (bn === null) return -1;
    return an - bn;
  }, [enableDirtyPin, originalIndexMap]);

// 설명 — 텍스트 정렬 — ko locale, dirty-pin 동일(변경행 하단)
  const mesTextSort: SortingFn<T> = useCallback((rowA, rowB, columnId) => {
    if (enableDirtyPin) {
      const da = isDirtyRow(rowA.original as { _rowState?: string });
      const db = isDirtyRow(rowB.original as { _rowState?: string });
      // 변경행(C/U)을 목록 바닥으로
      if (da !== db) return da ? 1 : -1;
      if (da && db) {
        const ia = originalIndexMap.get(rowA.id) ?? 0;
        const ib = originalIndexMap.get(rowB.id) ?? 0;
        return ia - ib;
      }
    }
    const av = rowA.getValue(columnId);
    const bv = rowB.getValue(columnId);
    if ((av === null || av === undefined || av === "") && (bv === null || bv === undefined || bv === "")) return 0;
    if (av === null || av === undefined || av === "") return 1;
    if (bv === null || bv === undefined || bv === "") return -1;
    return String(av).localeCompare(String(bv), "ko");
  }, [enableDirtyPin, originalIndexMap]);

// 설명 — columnsSig 변경 시에만 ColumnDef 재생성
  const columnDefs = useMemo(
    () => toColumnDefs(columnsRef.current, { enableRowSelection }),
    // eslint-disable-next-line react-hooks/exhaustive-deps -- columnsSig
    [columnsSig, enableRowSelection],
  );

// 설명 — TanStack Table 인스턴스 — 뷰 상태·필터·정렬·meta 연결
  const table = useReactTable({
    data,
    columns: columnDefs,
    getRowId: (row) => getRowId(row),
    state: {
      sorting,
      globalFilter,
      columnFilters,
      columnVisibility,
      columnSizing,
      columnOrder,
      columnPinning,
      rowSelection,
    },
    onSortingChange: setSorting,
    onGlobalFilterChange: setGlobalFilter,
    onColumnFiltersChange: setColumnFilters,
    onColumnVisibilityChange,
    onColumnSizingChange,
    onColumnOrderChange,
    onColumnPinningChange: setColumnPinning,
    onRowSelectionChange: setRowSelection,
    columnResizeMode: "onEnd",
    enableMultiSort,
    isMultiSortEvent: (e) => (e as MouseEvent).shiftKey,
    enableRowSelection,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    globalFilterFn,
    filterFns: {
      mesText: mesTextFilter,
    },
    sortingFns: {
      mesNumeric: mesNumericSort,
      mesTextSort: mesTextSort,
    },
    meta: {
      mode: userMeta?.mode ?? "view",
      updateCell: userMeta?.updateCell,
      isCellEditable: userMeta?.isCellEditable as ((row: unknown, field: string) => boolean) | undefined,
      activeCell,
      setActiveCell,
    },
  });

// 설명 — 현재 표시 중인 데이터 열 id 목록(__select 제외)
  const visibleFieldIds = useMemo(
    () =>
      table
        .getVisibleLeafColumns()
        .filter((c) => c.id !== "__select")
        .map((c) => c.id),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [table, columnVisibility, columnOrder, sorting, columnsSig],
  );
  const visibleCols = visibleFieldIds
    .map((id) => columns.find((x) => x.field === id))
    .filter((c): c is GridColumn<T> => !!c);

// 설명 — 1차 정렬 상태 — GridChrome 헤더 화살표용
  const primarySort = sorting[0];
  const sort = {
    field: primarySort?.id ?? null,
    dir: (primarySort?.desc ? "desc" : "asc") as "asc" | "desc",
  };

// 설명 — 헤더 클릭 정렬 토글 — shiftKey 시 다중 정렬
  const toggleSort = useCallback(
    (field: string, multi = false) => {
      const col = table.getColumn(field);
      if (!col) return;
      col.toggleSorting(undefined, multi);
    },
    [table],
  );

// 설명 — 열별 필터 — Record 형태로 GridChrome에 노출
  const colFilters = useMemo(() => {
    const rec: Record<string, string> = {};
    for (const f of columnFilters) rec[f.id] = String(f.value ?? "");
    return rec;
  }, [columnFilters]);

// 설명 — 열별 필터 설정 — 빈 값은 columnFilters에서 제거
  const setColFilters = useCallback((updater: Updater<Record<string, string>>) => {
    setColumnFilters((prev) => {
      const prevRec: Record<string, string> = {};
      for (const f of prev) prevRec[f.id] = String(f.value ?? "");
      const nextRec = resolveUpdater(updater, prevRec);
      return Object.entries(nextRec)
        .filter(([, v]) => v.trim() !== "")
        .map(([id, value]) => ({ id, value }));
    });
  }, []);

// 설명 — 숨김 열 맵 — 열 메뉴 체크박스용
  const hidden = useMemo(() => {
    const rec: Record<string, boolean> = {};
    for (const c of columns) {
      if (c.hidden || c.field === "coCd") continue;
      if (columnVisibility[c.field] === false) rec[c.field] = true;
    }
    return rec;
  }, [columns, columnVisibility]);

// 설명 — 열 표시/숨김 토글 — columnVisibility와 동기화
  const setHidden = useCallback(
    (updater: Updater<Record<string, boolean>>) => {
      onColumnVisibilityChange((prevVis) => {
        const prevHid: Record<string, boolean> = {};
        for (const c of columns) {
          if (c.hidden || c.field === "coCd") continue;
          if (prevVis[c.field] === false) prevHid[c.field] = true;
        }
        const nextHid = resolveUpdater(updater, prevHid);
        const nextVis: VisibilityState = { ...prevVis };
        for (const c of columns) {
          if (c.hidden || c.field === "coCd") continue;
          // 숨김이면 false, 표시면 키 제거(TanStack 기본 visible)
          if (nextHid[c.field]) nextVis[c.field] = false;
          else delete nextVis[c.field];
        }
        return nextVis;
      });
    },
    [columns, onColumnVisibilityChange],
  );

// 설명 — 열 너비 조회 — sizing 우선, 없으면 컬럼 기본 width
  const widthOf = useCallback(
    (c: GridColumn<T>) => columnSizing[c.field] ?? c.width ?? 120,
    [columnSizing],
  );

// 설명 — 열 너비 설정 — 최소 50px
  const setWidth = useCallback(
    (field: string, w: number) => {
      onColumnSizingChange((prev) => ({ ...prev, [field]: Math.max(50, w) }));
    },
    [onColumnSizingChange],
  );

// 설명 — 정렬·필터 적용 후 표시 행
  const displayRows = table.getRowModel().rows.map((r) => r.original);
// 설명 — 필터만 적용된 행 — 푸터 집계 기준
  const filteredRows = table.getFilteredRowModel().rows.map((r) => r.original);

// 설명 — visible 열 집계(sum/avg/min/max/count) — filteredRows 기준
  const aggregates = useMemo(() => {
    const acc: Record<string, number | null> = {};
    for (const c of visibleCols) {
      const defaultSum =
        (c.type === "number" || c.type === "amount") && c.field !== "seq" ? "sum" : undefined;
      const fn: MesAggregationFn | undefined = c.aggregationFn ?? defaultSum;
      if (!fn) continue;
      const vals = filteredRows
        .map((r) => Number((r as Record<string, unknown>)[c.field]))
        .filter((n) => !Number.isNaN(n));
      if (fn === "count") {
        acc[c.field] = vals.length;
        continue;
      }
      if (!vals.length) {
        acc[c.field] = null;
        continue;
      }
      if (fn === "sum") acc[c.field] = vals.reduce((s, n) => s + n, 0);
      else if (fn === "avg") acc[c.field] = vals.reduce((s, n) => s + n, 0) / vals.length;
      else if (fn === "min") acc[c.field] = Math.min(...vals);
      else if (fn === "max") acc[c.field] = Math.max(...vals);
    }
    return acc;
  }, [visibleCols, filteredRows]);

  return {
    table,
    visibleCols,
    sort,
    toggleSort,
    query: globalFilter,
    setQuery: setGlobalFilter,
    colFilters,
    setColFilters,
    hidden,
    setHidden,
    showFilter,
    setShowFilter,
    widthOf,
    setWidth,
    columnOrder,
    setColumnOrder: onColumnOrderChange,
    columnPinning,
    setColumnPinning,
    rowSelection,
    setRowSelection,
    activeCell,
    setActiveCell,
    displayRows,
    aggregates,
    totalCount: data.length,
    shownCount: displayRows.length,
  };
}
