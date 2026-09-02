/**
 * gridAccess — MES 셸 인프라 모듈.
 *
 * 주요 역할:
 *     1. MesShell(F49) / Page(F115~F156) 지원 유틸
 *     2. 탭·다이얼로그·메시지·검증·단축키 등 횡단 관심사
 *
 * 설계 기준:
 *     - 도메인 CRUD 없음.
 *     - *Page.tsx가 shell을 import(단방향).
 *
 * PIPELINE[F80] 셸 인프라
 * PIPELINE[F49, F52] 연관 모듈
 *
 * 구현내용: 전수 주석(레벨3).
 */
// 다이얼로그: mesAlert 잠금 사유 알림
import { mesAlert } from "@/shell/dialog";
// MES 메시지: 잠금·권한·상태 안내 문구
import { MES } from "@/shell/messages";
// 상태 규칙: 승인·편집/삭제 잠금·ERP·WO 마감 판정
import {
  isApproved,
  isDeleteLockedByCode,
  isEditLockedByCode,
  isErpPosted,
  isWoClosed,
} from "@/shell/statusRules";
// EditableRow 타입: 그리드 편집 행
import type { EditableRow } from "@/types/editable";
// gridRules 타입: AccessResult·GridAccessContext·GridAccessFns 등
import type { AccessResult, GridAccessContext, GridAccessFns, GridRow, LockReason, ScreenGridRules } from "./types";

/** LockReason → MES 메시지 문자열 매핑. */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) lockMessage — 인프라 export 함수/상수
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export function lockMessage(reason: LockReason): string {
  // 잠금 사유별 MES 메시지 분기
  switch (reason) {
    // 저장 행 잠금 메시지
    case "savedRow": return MES.savedRowLocked;
    // 승인 잠금 메시지
    case "approved": return MES.approvedLocked;
    // 마감 잠금 메시지
    case "closed": return MES.closedLocked;
    // ERP 반영 잠금 메시지
    case "erp": return MES.erpLocked;
    // 재고 조정 잠금 메시지
    case "stock": return MES.stockLocked;
    // 상위 행 미선택 메시지
    case "parent": return MES.parentRequired;
    // 팝업 전용 필드 메시지
    case "popup": return MES.popupLocked;
    // 읽기전용 메시지
    case "readOnly": return MES.lockedEdit;
    // 권한 부족 메시지
    case "permission": return MES.lockedEdit;
    // 탭 제한 메시지
    case "tab": return MES.lockedEdit;
    // 상태 잠금 기본 메시지
    case "status": return MES.lockedEdit;
    // 알 수 없는 사유 — 기본 잠금 메시지
    default: return MES.lockedEdit;
  }
}

/** 잠금 사유를 알림 다이얼로그로 표시. */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) showLockedMessage — 인프라 export 함수/상수
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export function showLockedMessage(reason: LockReason): void {
  // lockMessage 변환 후 알림 표시 (Promise 무시)
  void mesAlert(lockMessage(reason));
}

// 접근 허용/거부 헬퍼
// 접근 허용 결과 반환
function ok(): AccessResult { return { ok: true }; }
// 접근 거부 결과와 잠금 사유 반환
function deny(reason: LockReason): AccessResult { return { ok: false, reason }; }

// 신규행(_rowState === "C") 여부
function isNewRow(row: EditableRow<Record<string, unknown>>): boolean {
  // _rowState가 C이면 신규행
  return row._rowState === "C";
}

/** 팝업 규칙 필드 — 표시 컬럼명 → 기준 키 */
const POPUP_FIELD_ALIAS: Record<string, string> = {
  clientNm: "clientCd",
  itemNm: "itemCd",
};

// 팝업 필드명 → 실제 키 필드명 변환 (clientNm → clientCd 등)
function ruleField(field: string): string {
  // 별칭 맵에 있으면 키 필드명, 없으면 원본 field
  return POPUP_FIELD_ALIAS[field] ?? field;
}

// 행 단위 상태 잠금 판정 — 승인·마감·ERP·재고·권한·탭 등
function rowStatusLocked(
  row: EditableRow<Record<string, unknown>>,
  rules: ScreenGridRules,
  ctx: GridAccessContext,
): LockReason | null {
  // 화면 전체 읽기전용이면 readOnly
  if (ctx.readOnly) return "readOnly";

  // extra 컨텍스트 (권한·탭 등)
  const extra = ctx.extra ?? {};
  // 쓰기 권한 없음 또는 systemChild 비관리자면 permission
  if (extra.canWrite === false || extra.isAdmin === false && extra.gridRole === "systemChild") {
    return "permission";
  }
  // pending 탭에서 삭제 액션이면 tab 잠금
  if (extra.tab === "pending" && extra.action === "delete") return "tab";

  // 화면별 isRowEditLocked 규칙 적용
  if (rules.isRowEditLocked?.(row, ctx)) return "status";

  // 승인 필드가 승인 상태이면 approved
  if (rules.approveField && isApproved(String(row[rules.approveField] ?? ""))) {
    return "approved";
  }

  // statusFields 각각 codeMap 기준 편집 잠금 검사
  for (const sf of rules.statusFields ?? []) {
    // 상태 코드 값
    const cd = String(row[sf.field] ?? "");
    // 해당 codeMap 조회
    const map = ctx.codeMaps?.[sf.codeMapKey];
    // 코드 라벨이 편집 잠금이면 status
    if (isEditLockedByCode(cd, map)) return "status";
  }

  // 작업지시 상태 필드
  const woStat = row.woStat as string | undefined;
  // WO 마감이면 closed
  if (woStat !== undefined && isWoClosed(woStat)) return "closed";

  // ERP 반영 필드마다 전표 여부 검사
  for (const ef of rules.erpFields ?? []) {
    // ERP 전표 반영이면 erp 잠금
    if (isErpPosted(row[ef] as string | undefined)) return "erp";
  }

  // 재고 조정 유형 필드명 (기본 adjType)
  const adjField = rules.adjTypeField ?? "adjType";
  // editableAdjTypes가 있고 저장 행이면 조정 유형 화이트리스트 검사
  if (rules.editableAdjTypes && !isNewRow(row)) {
    // 현재 조정 유형
    const adj = String(row[adjField] ?? "");
    // 화이트리스트에 없으면 stock 잠금
    if (adj && !rules.editableAdjTypes.includes(adj)) return "stock";
  }

  // 잠금 사유 없음
  return null;
}

/** ScreenGridRules + 컨텍스트로 셀 편집·팝업 오픈 판정 함수 세트 생성. */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) buildGridAccess — 인프라 export 함수/상수
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export function buildGridAccess(
  rules: ScreenGridRules,
  ctx: GridAccessContext,
): GridAccessFns {
  // rules 별칭 (클로저 내부 참조용)
  const r = rules;

  // 셀 편집 가능 여부 — alwaysReadonly·newOnly·상태잠금·editableWhenLocked 순 검사
  const canEditCell = (row: EditableRow<GridRow>, field: string): AccessResult => {
    // detail/child가 아닌 역할이면 parentRow 검사 생략
    if (ctx.gridRole !== "single" && ctx.gridRole !== "header" && !ctx.parentRow && ctx.gridRole !== "child") {
      // detail/child인데 parentRow 없으면 parent 잠금
      if (["detail", "child"].includes(ctx.gridRole) && !ctx.parentRow) {
        return deny("parent");
      }
    }

    // 행 단위 상태 잠금 사유
    const rowLock = rowStatusLocked(row, r, ctx);
    // 신규행 여부
    const isNew = isNewRow(row);

    // alwaysReadonly 필드는 신규·저장 모두 편집 불가
    if ((r.alwaysReadonly ?? []).includes(field)) return deny(isNew ? "readOnly" : "savedRow");

    // newOnly 필드는 저장 행에서 편집 불가
    if ((r.newOnly ?? []).includes(field) && !isNew) return deny("savedRow");

    // 행이 상태 잠금이면
    if (rowLock) {
      // 잠금 중에도 편집 가능한 화이트리스트
      const whitelist = r.editableWhenLocked ?? [];
      // 화이트리스트에 없으면 rowLock 사유로 거부
      if (!whitelist.includes(field)) return deny(rowLock);
    }

    // 모든 검사 통과 — 편집 허용
    return ok();
  };

  // 팝업(검색피커) 오픈 가능 여부 — 편집 가능 + 저장된 키 필드 잠금 검사
  const canOpenPopup = (row: EditableRow<GridRow>, field: string): AccessResult => {
    // 표시 필드 → 규칙 키 필드 변환
    const rf = ruleField(field);
    // 먼저 셀 편집 가능 여부 검사
    const edit = canEditCell(row, field);
    // 편집 불가면 그 사유 그대로 반환
    if (!edit.ok) return edit;

    // 신규행 여부
    const isNew = isNewRow(row);

    // newOnly 키 필드는 저장 행에서 팝업 불가
    if ((r.newOnly ?? []).includes(rf) && !isNew) return deny("savedRow");

    // 저장 후 변경 불가 키 필드 목록
    const savedLock = ["itemCd", "lotNo", "locCd", "soNo", "empCd", "cItemCd", "clientCd"];
    // 저장 행에서 savedLock 키 필드는 팝업 불가
    if (!isNew && savedLock.includes(rf)) return deny("savedRow");

    // detail/child인데 parentRow 없으면 parent 잠금
    if (["detail", "child"].includes(ctx.gridRole) && !ctx.parentRow) return deny("parent");

    // 팝업 오픈 허용
    return ok();
  };

  // 편집·팝업 판정 함수 세트 반환
  return { canEditCell, canOpenPopup };
}

/** 행 삭제 가능 여부 — 신규행은 항상 허용, 저장 행은 상태·승인·ERP 등 검사. */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) canDeleteRow — 인프라 export 함수/상수
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export function canDeleteRow(
  rules: ScreenGridRules,
  ctx: GridAccessContext,
  row: EditableRow<GridRow>,
): AccessResult {
  // 신규(C) 행은 항상 삭제 허용
  if (isNewRow(row)) return ok();

  // 화면 읽기전용이면 삭제 불가
  if (ctx.readOnly) return deny("readOnly");

  // extra 컨텍스트
  const extra = ctx.extra ?? {};
  // pending 탭이면 삭제 불가
  if (extra.tab === "pending") return deny("tab");

  // 화면별 isRowDeleteLocked 규칙
  if (rules.isRowDeleteLocked?.(row, ctx)) return deny("status");

  // 승인 필드가 승인 상태이면 삭제 불가
  if (rules.approveField && isApproved(String(row[rules.approveField] ?? ""))) {
    return deny("approved");
  }

  // statusFields 각각 codeMap 기준 삭제 잠금 검사
  for (const sf of rules.statusFields ?? []) {
    // 상태 코드 값
    const cd = String(row[sf.field] ?? "");
    // 해당 codeMap
    const map = ctx.codeMaps?.[sf.codeMapKey];
    // 삭제 잠금 코드이면 status
    if (isDeleteLockedByCode(cd, map)) return deny("status");
  }

  // 작업지시 상태
  const woStat = row.woStat as string | undefined;
  // WO 마감이면 삭제 불가
  if (woStat !== undefined && isWoClosed(woStat)) return deny("closed");

  // ERP 반영 필드마다 전표 여부 검사
  for (const ef of rules.erpFields ?? []) {
    // ERP 전표 반영이면 삭제 불가
    if (isErpPosted(row[ef] as string | undefined)) return deny("erp");
  }

  // 재고 조정 유형 필드명
  const adjField = rules.adjTypeField ?? "adjType";
  // editableAdjTypes가 있으면 조정 유형 화이트리스트 검사
  if (rules.editableAdjTypes) {
    // 현재 조정 유형
    const adj = String(row[adjField] ?? "");
    // 화이트리스트에 없으면 stock 잠금
    if (adj && !rules.editableAdjTypes.includes(adj)) return deny("stock");
  }

  // 모든 검사 통과 — 삭제 허용
  return ok();
}

/** 행 저장 가능 여부 — 전체 잠금 상태에서 수정(U) 시도 차단. */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) canSaveRow — 인프라 export 함수/상수
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export function canSaveRow(
  rules: ScreenGridRules,
  ctx: GridAccessContext,
  row: EditableRow<GridRow>,
): AccessResult {
  // _rowState 없으면 변경 행이 아니므로 통과
  if (!row._rowState) return ok();
  // 행 단위 상태 잠금 사유
  const rowLock = rowStatusLocked(row, rules, ctx);
  // 수정(U) 행이 전체 잠금이면 — 화이트리스트 칸만 바뀐 경우는 저장한다
  if (rowLock && row._rowState === "U") {
    const whitelist = rules.editableWhenLocked ?? [];
    const orig = row._original as Record<string, unknown> | undefined;
    const dirty = Object.keys(row).filter((k) => {
      if (k.startsWith("_")) return false;
      return String(row[k] ?? "") !== String(orig?.[k] ?? "");
    });
    // 잠긴 칸만 고쳤을 때(= 목록 비고 같은 제목) 저장을 연다
    if (whitelist.length > 0 && dirty.length > 0 && dirty.every((f) => whitelist.includes(f))) {
      return ok();
    }
    return deny(rowLock);
  }
  // 저장 허용
  return ok();
}
