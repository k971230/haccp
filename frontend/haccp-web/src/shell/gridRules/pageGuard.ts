/**
 * pageGuard — MES 셸 인프라 모듈.
 *
 * [BIZ_CRUD_4: guardSaveWithKey / guardDelete]
 * [P2_DELETE: FE 가드 — validate-delete는 Phase2]
 * 일자: 2026-07-09
 * 개발자: 박승우
 * 구현내용: 저장·삭제 전 FE 검증. 전수 주석(레벨3). 상세 docs/06_업무_CRUD.md.
 *
 * PIPELINE[F81] 셸 인프라
 * PIPELINE[F49, F52] 연관 모듈
 */
// GridColumn 타입: 컬럼 field·validate 정의
import type { GridColumn } from "@/types/grid";
// EditableRow 타입: 그리드 편집 행
import type { EditableRow } from "@/types/editable";
// gridRules 타입: GridRow
import type { GridRow } from "./types";
// gridAccess: canDeleteRow 행 삭제 가능 판정
import { canDeleteRow } from "./gridAccess";
// gridAccess: lockMessage 잠금 사유→MES 문구
import { lockMessage } from "./gridAccess";
// validateGridSave: validateRowsForSave 저장 전 일괄 검증
import { validateRowsForSave } from "./validateGridSave";
// gridRules 타입: GridAccessContext·ScreenGridRules
import type { GridAccessContext, ScreenGridRules } from "./types";

/** 저장 전 검증 — 첫 오류 메시지만 반환, 통과 시 null. */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) guardSave — 인프라 export
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export function guardSave<T extends object>(
  rules: ScreenGridRules,
  ctx: GridAccessContext,
  rows: EditableRow<T>[],
  columns?: GridColumn<T>[],
): string | null {
  // 변경 행 일괄 저장 검증 실행
  const result = validateRowsForSave(rules, ctx, rows as EditableRow<GridRow>[], columns as GridColumn<GridRow>[] | undefined);
  // 검증 통과 시 null 반환
  if (result.ok) return null;
  // 첫 번째 오류 메시지 반환 (없으면 null)
  return result.errors[0]?.message ?? null;
}

/** 저장 전 검증 — 오류 메시지와 해당 행 _key 를 함께 반환(그리드 포커스 이동용). */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) guardSaveWithKey — 인프라 export 함수/상수
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export function guardSaveWithKey<T extends object>(
  rules: ScreenGridRules,
  ctx: GridAccessContext,
  rows: EditableRow<T>[],
  columns?: GridColumn<T>[],
): { message: string; rowKey?: string } | null {
  // 변경 행 일괄 저장 검증 실행
  const result = validateRowsForSave(rules, ctx, rows as EditableRow<GridRow>[], columns as GridColumn<GridRow>[] | undefined);
  // 검증 통과 시 null 반환
  if (result.ok) return null;
  // 첫 번째 오류 항목 추출
  const e = result.errors[0];
  // 메시지와 rowKey를 함께 반환
  return { message: e.message, rowKey: e.rowKey };
}

/** 삭제 전 검증 — 삭제 불가 시 잠금 사유 메시지, 가능 시 null. */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) guardDelete — 인프라 export 함수/상수
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export function guardDelete<T extends object>(
  rules: ScreenGridRules,
  ctx: GridAccessContext,
  row: EditableRow<T>,
): string | null {
  // 행 삭제 가능 여부 판정
  const r = canDeleteRow(rules, ctx, row as EditableRow<GridRow>);
  // 삭제 가능 시 null 반환
  if (r.ok) return null;
  // 잠금 사유를 MES 메시지로 변환해 반환
  return lockMessage(r.reason ?? "status");
}
