/**
 * validateGridSave — MES 셸 인프라 모듈.
 *
 * 주요 역할:
 *     1. MesShell(F49) / Page(F115~F156) 지원 유틸
 *     2. 탭·다이얼로그·메시지·검증·단축키 등 횡단 관심사
 *
 * 설계 기준:
 *     - 도메인 CRUD 없음.
 *     - *Page.tsx가 shell을 import(단방향).
 *
 * PIPELINE[F82] 셸 인프라
 * PIPELINE[F49, F52] 연관 모듈
 *
 * 구현내용: 전수 주석(레벨3).
 */
// GridColumn 타입: 컬럼 field·validate 정의
import type { GridColumn } from "@/types/grid";
// EditableRow 타입: 그리드 편집 행
import type { EditableRow } from "@/types/editable";
// required: col.required 시 빈값 거부 (헤더 * 와 저장 검증 정합)
import { required } from "@/shell/validation";
// gridAccess: buildGridAccess·canSaveRow·lockMessage
import { buildGridAccess, canSaveRow, lockMessage } from "./gridAccess";
// gridRules 타입: GridAccessContext·GridRow·SaveValidationResult·ScreenGridRules
import type { GridAccessContext, GridRow, SaveValidationResult, ScreenGridRules } from "./types";

// 행 필드 변경 여부 — _original 대비 값 비교, 신규행은 항상 변경으로 간주
function fieldChanged(
  row: EditableRow<Record<string, unknown>>,
  field: string,
): boolean {
  // 저장 시점 원본 스냅샷 참조
  const orig = row._original as Record<string, unknown> | undefined;
  // 원본 없으면 신규(C)·수정(U) 행은 변경으로 간주
  if (!orig) return row._rowState === "C" || row._rowState === "U";
  // 현재 값
  const a = row[field];
  // 원본 값
  const b = orig[field];
  // 문자열 비교로 변경 여부 판정
  return String(a ?? "") !== String(b ?? "");
}

/** 변경 행(_rowState 존재) 일괄 검증 — 잠금·컬럼 규칙 위반 시 errors 배열 반환. */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) validateRowsForSave — 인프라 export 함수/상수
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export function validateRowsForSave(
  rules: ScreenGridRules,
  ctx: GridAccessContext,
  rows: EditableRow<GridRow>[],
  columns?: GridColumn<GridRow>[],
): SaveValidationResult {
  // 규칙·컨텍스트로 셀 편집 판정 함수 생성
  const access = buildGridAccess(rules, ctx);
  // 누적 오류 목록
  const errors: SaveValidationResult["errors"] = [];
  // _rowState가 있는 변경 행만 필터
  const changed = rows.filter((r) => r._rowState);

  // 변경 행마다 잠금·컬럼 규칙 검사
  for (const row of changed) {
    // 행 단위 저장 가능 여부 판정
    const saveCheck = canSaveRow(rules, ctx, row);
    // 수정(U) 행이 전체 잠금이면 저장 차단
    if (!saveCheck.ok && row._rowState === "U") {
      // 잠금 사유 메시지를 오류에 추가
      errors.push({
        rowKey: row._key,
        message: lockMessage(saveCheck.reason ?? "status"),
      });
      // 해당 행의 나머지 검사 건너뜀
      continue;
    }

    // 컬럼 정의가 있으면 컬럼 field 목록, 없으면 행·원본 키 합집합
    const fieldsToCheck = columns
      ? columns.map((c) => c.field)
      : [
          ...new Set([
            ...Object.keys(row).filter((k) => !k.startsWith("_")),
            ...Object.keys((row._original as object) ?? {}),
          ]),
        ];

    // 신규행은 생성이므로 편집잠금(alwaysReadonly·상태잠금) 필드별 검사를 건너뛴다.
    // (신규행은 _original 이 없어 모든 필드가 '변경'으로 잡혀 woNo/prdtQty 등 서버·읽기전용
    //  컬럼까지 오탐 → 저장 차단되던 버그 방지). 값 검증기(col.validate)는 신규/수정 모두 적용.
    // 신규(C) 행 여부
    const isNew = row._rowState === "C";
    // 검사 대상 필드마다 변경·잠금·validate 검사
    for (const field of fieldsToCheck) {
      // 값이 바뀌지 않은 필드는 건너뜀
      if (!fieldChanged(row as EditableRow<Record<string, unknown>>, field)) continue;
      // 저장 행만 편집 잠금 검사 (신규행은 건너뜀)
      if (!isNew) {
        // 셀 편집 가능 여부 판정
        const edit = access.canEditCell(row, field);
        // 편집 불가 시 오류 추가
        if (!edit.ok) {
          errors.push({
            rowKey: row._key,
            field,
            message: lockMessage(edit.reason ?? "status"),
          });
        }
      }
      // 컬럼 정의가 있으면 required + col.validate 실행
      if (columns) {
        // 해당 field의 컬럼 정의 탐색
        const col = columns.find((c) => c.field === field);
        // 셀 값 — required·validate 공통 입력
        const cellVal = (row as Record<string, unknown>)[field];
        // col.required일 때(= 헤더 *) 빈값이면 필수 오류 — 드롭다운 빈 option 생략과 대칭
        if (col?.required) {
          const reqMsg = required(col.header)(cellVal);
          if (reqMsg) {
            errors.push({ rowKey: row._key, field, message: reqMsg });
          }
        }
        // 컬럼별 값 검증기가 있으면 실행
        if (col?.validate) {
          // validate가 반환한 오류 문구
          const msg = col.validate(cellVal, row);
          // 오류 문구가 있으면 errors에 추가
          if (msg) {
            errors.push({ rowKey: row._key, field, message: msg });
          }
        }
      }
    }
  }

  // 오류 없으면 ok:true, 있으면 ok:false와 errors 반환
  return { ok: errors.length === 0, errors };
}
