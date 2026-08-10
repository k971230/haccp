/**
 * types — MES 셸 인프라 모듈.
 *
 * 주요 역할:
 *     1. MesShell(F49) / Page(F115~F156) 지원 유틸
 *     2. 탭·다이얼로그·메시지·검증·단축키 등 횡단 관심사
 *
 * 설계 기준:
 *     - 도메인 CRUD 없음.
 *     - *Page.tsx가 shell을 import(단방향).
 *
 * PIPELINE[F79] 셸 인프라
 * PIPELINE[F49, F52] 연관 모듈
 *
 * 구현내용: 전수 주석(레벨3).
 */
// EditableRow 타입: 그리드 편집 행 _key/_rowState/_original
import type { EditableRow } from "@/types/editable";

/**
 * 그리드 접근·잠금 타입 정의 — ScreenGridRules·GridAccessContext 등.
 * gridAccess/validateGridSave/pageGuard 가 공유하는 계약.
 */

/** 그리드 잠금 사유 — 메시지 매핑용 */
export type LockReason =
  | "savedRow"
  | "approved"
  | "closed"
  | "erp"
  | "stock"
  | "parent"
  | "popup"
  | "readOnly"
  | "status"
  | "permission"
  | "tab";

/** 그리드 역할 — 헤더/디테일/단일/마스터/자식 */
export type GridRole = "header" | "detail" | "single" | "master" | "child";

/** 그리드 접근 판정에 필요한 화면·행 컨텍스트 */
export interface GridAccessContext {
  scrnCd: string;
  gridRole: GridRole;
  readOnly?: boolean;
  parentRow?: object | null;
  codeMaps?: Record<string, Record<string, string>>;
  /** 화면별 추가 컨텍스트 (탭, 권한 등) */
  extra?: Record<string, unknown>;
}

/** 셀/행 접근 판정 결과 */
export interface AccessResult {
  ok: boolean;
  reason?: LockReason;
}

/** 규칙·엔진에서 쓰는 느슨한 행 타입 (화면별 rules 사이드카와 호환) */
export type GridRow = Record<string, unknown>;

/** buildGridAccess 가 반환하는 편집·팝업 판정 함수 */
export interface GridAccessFns {
  canEditCell: (row: EditableRow<GridRow>, field: string) => AccessResult;
  canOpenPopup: (row: EditableRow<GridRow>, field: string) => AccessResult;
}

/** 화면별 그리드 잠금 규칙 — *.rules.ts 사이드카에서 정의 */
export interface ScreenGridRules {
  isRowEditLocked?: (row: EditableRow<GridRow>, ctx: GridAccessContext) => boolean;
  isRowDeleteLocked?: (row: EditableRow<GridRow>, ctx: GridAccessContext) => boolean;
  /** 항상 읽기전용 필드 */
  alwaysReadonly?: string[];
  /** 신규행에서만 편집 가능 */
  newOnly?: string[];
  /** 팝업 전용 필드 (직접 입력 차단은 컬럼 cellButton으로) */
  popupFields?: string[];
  /** 승인/마감 상태에서도 편집 가능한 필드 */
  editableWhenLocked?: string[];
  /** 상태 필드명 → codeMap 키 (ctx.codeMaps) */
  statusFields?: { field: string; codeMapKey: string }[];
  /** 승인 여부 필드 */
  approveField?: string;
  /** ERP 반영 필드 */
  erpFields?: string[];
  /** adjType 등 화이트리스트 (재고이력) */
  editableAdjTypes?: string[];
  adjTypeField?: string;
}

/** 저장 검증 오류 한 건 */
export interface SaveValidationError {
  rowKey: string;
  field?: string;
  message: string;
}

/** validateRowsForSave 반환 — ok·errors 배열 */
export interface SaveValidationResult {
  ok: boolean;
  errors: SaveValidationError[];
}
