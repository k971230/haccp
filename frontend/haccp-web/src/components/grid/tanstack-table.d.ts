/** TanStack Table Meta / FilterFns / SortingFns 확장. */
// 역할 — FilterFn·RowData·SortingFn 타입
import type { FilterFn, RowData, SortingFn } from "@tanstack/react-table";
// 역할 — 그리드 컬럼 정의 — ColumnMeta 연동
import type { GridColumn } from "@/types/grid";

// 설명 — 편집 그리드 활성 셀 좌표·편집 모드 여부
export type MesActiveCell = {
  rowKey: string;
  field: string;
  isEditing: boolean;
} | null;

// 설명 — 푸터 집계 함수 종류
export type MesAggregationFn = "sum" | "avg" | "min" | "max" | "count";

// 설명 — TanStack Table 모듈 확장 — MES 그리드 전용 meta·필터·정렬
declare module "@tanstack/react-table" {
  interface FilterFns {
    mesText: FilterFn<unknown>;
  }
  interface SortingFns {
    mesNumeric: SortingFn<unknown>;
    mesTextSort: SortingFn<unknown>;
  }

  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  interface TableMeta<TData extends RowData> {
    mode?: "view" | "edit";
    updateCell?: (rowKey: string, field: string, value: unknown) => void;
    isCellEditable?: (row: TData, field: string) => boolean;
    getCellClassName?: (row: TData, field: string) => string;
    activeCell?: MesActiveCell;
    setActiveCell?: (cell: MesActiveCell) => void;
  }

  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  interface ColumnMeta<TData extends RowData, TValue> {
    col?: GridColumn<TData & Record<string, unknown>>;
    aggregationFn?: MesAggregationFn;
  }
}

export {};
