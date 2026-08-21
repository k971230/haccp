/**
 * grid.ts — types 공통 grid.
 *
 * 주요 역할:
 *     1. 타입·순수 함수·스타일 헬퍼
 *     2. React/UI 의존 없음
 *
 * PIPELINE[F34] 공통 모듈
 */
// 역할 — gridRules 접근제어 타입
import type { GridAccessFns, LockReason } from "@/shell/gridRules/types";

export type { GridAccessFns, LockReason };

/** 행 변경 상태 — WinForms DataRowState(Added/Modified/Deleted) 대응 */
export type RowState = "C" | "U" | "D" | undefined; // Created / Updated / Deleted

/** 그리드 행 최소 제약 — 컬럼 field 키 접근용 (DTO 인덱스 시그니처 불필요) */
export type GridRowBase = object;

/** 그리드 셀 데이터 타입 — 렌더·편집기·포맷 결정 */
export type GridColumnType =
  | "text" | "number" | "amount" | "date" | "datetime" | "code" | "checkbox" | "radio";

/** 그리드 컬럼 정의 — 헤더·너비·편집·검증·셀버튼 등 */
export interface GridColumn<T> {
  field: keyof T & string;
  header: string;
  width?: number;
  align?: "left" | "center" | "right";
  editable?: boolean;
  /** 신규행에서만 편집 (mainCd/subCd 등 키 컬럼) */
  editableOnNew?: boolean;
  type?: GridColumnType;
  /** type==='code' 일 때 subCd→codeNm 표시용 코드맵 */
  codeMap?: Record<string, string>;
  /** code 컬럼 상태 배지 — true: 기본 purple(코드·팝업), 객체: 코드/라벨별 색 */
  badge?: boolean | Partial<Record<string, "blue" | "amber" | "green" | "gray" | "red" | "purple" | "dash">>;
  /** type==='code' 편집 시 <select> 옵션 */
  codeOptions?: { value: string; label: string }[];
  /** 터치 키오스크 NumPad 포맷 — time: HH:mm (4자리) */
  kioskFormat?: "time" | "decimal";
  /** 하드 숨김 — 항상 안 보임 + "열" 토글 메뉴에도 없음(사용자가 켤 수 없음). 내부용 컬럼. */
  hidden?: boolean;
  /** 기본 숨김 — 첫 화면엔 숨김이지만 "열" 메뉴로 사용자가 켤 수 있고, 켠 선택은 DB 에 저장됨. */
  defaultHidden?: boolean;
  /** 필수 컬럼 — 헤더에 * 표시 */
  required?: boolean;
  /** 푸터 집계 (number/amount 기본 sum). getFilteredRowModel 기준 */
  aggregationFn?: "sum" | "avg" | "min" | "max" | "count";
  /**
   * 셀 버튼 (WinForms UltraGrid "EBTN"/GridConBtn 대응) — 셀 안 우측 고정 "…" 버튼.
   * 클릭 시 onClick(row) 호출(검색팝업·LOT선택 등). showOnNew=true 면 신규행만.
   * popupField: 잠금 규칙 적용 시 사용할 필드(기본 field).
   */
  cellButton?: {
    icon?: string;
    title?: string;
    onClick: (row: T) => void;
    showOnNew?: boolean;
    popupField?: string;
  };
  /**
   * 셀 단위 검증 — 편집셀 값이 유효하지 않으면 오류 메시지(string) 반환, 유효하면 null.
   * 그리드가 변경 즉시 호출해 셀에 적색 표시·툴팁을 노출한다 (WinForms BeforeCellUpdate 대응).
   * 예: (v) => Number(v) < 0 ? "0 이상이어야 합니다." : null
   */
  validate?: (value: unknown, row: T) => string | null;
  /**
   * 입력 직전 sanitize — 텍스트 편집 onChange에서 호출 (예: filterDigitsOnly).
   * 우편번호·인증키 등 숫자만 허용 컬럼에 사용.
   */
  sanitize?: (raw: string) => string;
  /** 모바일 키보드 힌트 — 숫자만 컬럼은 "numeric" */
  inputMode?: "text" | "numeric" | "decimal" | "tel" | "email";
  /** HTML maxlength + 입력 상한 (sanitize와 함께 쓰면 이중 방어) */
  maxLength?: number;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 그리드 내부 code 콤보에 빈 option을 둘지 한곳에서 판정한다
 *   2) MesEditableGrid select 렌더에서 호출한다 — 검색영역 「전체」는 해당 없음
 *   3) required · useYn · 옵션이 Y/N뿐이면 빈칸 없이 사용/미사용만 둔다
 */
export function codeSelectHasEmptyOption(col: {
  required?: boolean;
  field: string;
  codeOptions?: { value: string; label?: string }[];
}): boolean {
  if (col.required) return false;
  if (col.field === "useYn") return false;
  const opts = col.codeOptions ?? [];
  if (opts.length === 0) return true;
  const vals = [...new Set(opts.map((o) => String(o.value).toUpperCase()))];
  if (vals.length > 0 && vals.every((v) => v === "Y" || v === "N")) return false;
  return true;
}

/** useGridAccess 결과 — 잠금 판정·잠금 시도 콜백 전달용 */
export interface GridAccessProps {
  access?: GridAccessFns;
  onLockedAttempt?: (reason: LockReason, field: string) => void;
}

/** 컬럼 정렬 상태 */
export interface GridSort { field: string; dir: "asc" | "desc"; }
/** 컬럼 필터(툴바 검색) */
export interface GridFilter { field: string; value: string; }

/** 저장 시 추출되는 변경셋 (GridFunc.GetModifiedRows 대응) */
export interface GridChangeSet<T> {
  createdRows: T[];
  updatedRows: T[];
  deletedRows: T[];
  selectedRows: T[];
}

/** MesDataGrid / MesEditableGrid 공통 props */
export interface MesDataGridProps<T> {
  rows: T[];
  columns: GridColumn<T>[];
  rowKey: keyof T | ((row: T) => string);
  loading?: boolean;
  height?: number | string;
  selectable?: boolean;
  /**
   * 단건 라디오 리드 열 — activeKey 행이 켜진다.
   * 행·라디오 클릭은 onRowClick만 탄다. selectable(다중 체크박스)과 같이 쓰지 않는다.
   */
  singleSelect?: boolean;
  editable?: boolean;
  /** 활성(선택) 행 강조 — WinForms ActiveRow 시각화. rowKey 와 비교. */
  activeKey?: string | null;
  /** 행번호 컬럼 표시 (기본 true). */
  showRowNum?: boolean;
  /** 행번호 헤더 텍스트 (기본 공백). */
  rowNumHeader?: string;
  /** 검색·필터·CSV 툴바 (기본 true). 터치 키오스크는 false. */
  showToolbar?: boolean;
  /** 하단 건수 푸터 (기본 true). */
  showFooter?: boolean;
  /** 헤더 정렬·리사이즈 (기본 true). */
  sortable?: boolean;
  /** CSV 파일명. */
  title?: string;
  onRowClick?: (row: T) => void;
  onRowDoubleClick?: (row: T) => void;
  /** 그리드 클릭/행선택 시 activeGrid 설정 (WinForms Enter/MouseDown) */
  onSetActive?: () => void;
  onCellChange?: (row: T, field: keyof T, value: unknown) => void;
  onSelectionChange?: (rows: T[]) => void;
  /** pref v2(hidden/order/sizing) 저장 키 — 화면 내 그리드 id (예: "h"/"d") */
  persistId?: string;
  /** pref 저장용 화면코드 — 없으면 PageScrnContext (MesEditableGrid와 동일) */
  scrnCd?: string;
}
