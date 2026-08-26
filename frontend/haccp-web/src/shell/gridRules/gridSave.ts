/**
 * gridSave — 편집 그리드 저장 절차 공통.
 *
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 시스템 기준정보 6화면이 같은 순서를 25줄씩 복제하고 있었다 —
 *      권한 → 변경분 → 잠금 규칙 → 필수값 → 확인창 → 저장 → 재조회.
 *      한 화면만 고치면 나머지가 조용히 어긋난다
 *   2) 순서와 문구를 여기 한곳에 둔다. 화면은 「무엇이 필수인가」와 「무엇을 부를 것인가」만 준다
 *   3) 업무 판단(어떤 칸이 필수인지)은 화면 몫이라 콜백으로 받는다 — 여기서 추측하지 않는다
 *
 * PIPELINE[HF200] 편집 그리드 저장 공통
 */
import { MES } from "@/shell/messages";
import { mesConfirm, mesToast } from "@/shell/dialog";
import { mesError } from "@/shell/errors";
import { guardSaveWithKey } from "@/shell/gridRules/pageGuard";
import type { GridAccessContext, GridRow, ScreenGridRules } from "@/shell/gridRules/types";
import type { GridColumn } from "@/types/grid";
import type { EditableRow } from "@/types/editable";

/** 편집 메타 — 서버로 보내면 안 되는 칸 */
const META_KEYS = ["_key", "_rowState", "_original"] as const;

/**
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 저장 payload 에서 편집 메타를 걷어낸다
 *   2) 저장 직전에 행마다 호출한다
 *   3) 화면 전용 표시열(대·중·소분류처럼 서버가 안 받는 칸)은 extra 로 더 준다
 */
export function stripRowMeta<T extends object>(
  // row: 편집 중인 행
  row: EditableRow<T>,
  // extra: 이 화면에서만 쓰는 표시열 이름
  extra: readonly string[] = [],
): T {
  const next = { ...row } as Record<string, unknown>;
  for (const k of [...META_KEYS, ...extra]) delete next[k];
  return next as T;
}

/** 저장 절차에 필요한 것들 — 화면이 채워 넘긴다 */
export interface GridSaveSpec<T extends object> {
  /** 등록·수정 권한. 둘 다 없으면 시작도 안 한다 */
  canWrite: boolean;
  canModify: boolean;
  /** 변경된 행 — useEditableRows.getSaveRows() */
  dirty: EditableRow<T>[];
  /** 잠금·업무키 규칙 */
  rules: ScreenGridRules;
  ctx: GridAccessContext;
  columns: GridColumn<T>[];
  /** 활성 행을 옮긴다 — 막힌 행을 사용자에게 보여 주려고 */
  focusRow: (rowKey: string) => void;
  /**
   * 행 하나의 필수값을 본다. 문제가 있으면 안내 문구를 돌려준다.
   * 무엇이 필수인지는 화면마다 달라 여기서 추측하지 않는다.
   */
  requiredOf: (row: EditableRow<T>) => string | null;
  /** 실제 저장 — API 호출 */
  save: (rows: EditableRow<T>[]) => Promise<void>;
  /** 저장 뒤 재조회 */
  reload: () => Promise<void>;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 저장 버튼 한 번의 처리를 끝까지 한다 — 막히면 안내하고 멈춘다
 *   2) 시스템 기준정보 6화면의 저장 버튼이 호출한다
 *   3) 저장했으면 true. 권한·검증·취소로 안 보냈으면 false
 */
export async function runGridSave<T extends object>(spec: GridSaveSpec<T>): Promise<boolean> {
  if (!spec.canWrite && !spec.canModify) {
    mesToast("수정 권한이 없습니다.", "warn");
    return false;
  }
  if (spec.dirty.length === 0) {
    mesToast(MES.noChange, "warn");
    return false;
  }

  // 잠긴 칸을 고쳤거나 업무키가 겹치는지 — 규칙이 먼저 본다
  const guard = guardSaveWithKey(spec.rules, spec.ctx, spec.dirty, spec.columns);
  if (guard) {
    mesToast(guard.message, "warn");
    if (guard.rowKey) spec.focusRow(guard.rowKey);
    return false;
  }

  // 필수값 — 막힌 행으로 커서를 옮겨 준다. 어느 행이 문제인지 모르면 고칠 수 없다
  for (const row of spec.dirty) {
    const message = spec.requiredOf(row);
    if (message) {
      mesToast(message, "warn");
      if (row._key) spec.focusRow(row._key);
      return false;
    }
  }

  if (!(await mesConfirm(MES.saveConfirm))) return false;

  try {
    await spec.save(spec.dirty);
    mesToast(MES.saveDone, "success");
    await spec.reload();
    return true;
  } catch (e) {
    mesError(e);
    return false;
  }
}

/** GridRow 제약이 필요한 자리에서 쓰는 별칭 — 화면이 캐스팅을 반복하지 않게 */
export type EditableGridRow = EditableRow<GridRow>;
