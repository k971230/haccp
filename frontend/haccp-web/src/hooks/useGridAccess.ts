/**
 * useGridAccess — 화면 그리드 잠금·권한 접근 훅.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) ScreenGridRules와 컨텍스트로 셀 편집·삭제 가능 여부를 판정한다
 *   2) MesEditableGrid의 access·onLockedAttempt에 바로 연결한다
 *   3) ProcessPage와 동일한 규칙을 HACCP 관리 화면에 이식한다
 *
 * PIPELINE[HF96] 그리드 접근 훅
 * PIPELINE[HF90, F42] 연관 모듈
 */
// 역할 — React 메모·콜백
import { useCallback, useMemo } from "react";
// 역할 — 그리드 잠금 규칙 타입
import type { GridAccessContext, GridAccessFns, LockReason, ScreenGridRules } from "@/shell/gridRules/types";
// 역할 — 규칙→접근함수 빌드·잠금 안내
import { buildGridAccess, showLockedMessage } from "@/shell/gridRules/gridAccess";

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 화면별 rules와 권한 컨텍스트로 access 함수를 만든다
 *   2) 시스템·기준정보·작성주기 관리 그리드에서 호출한다
 *   3) 잠금 시도는 업무 토스트로만 안내한다
 */
export function useGridAccess(
  // 화면별 newOnly·required·locked 규칙
  rules: ScreenGridRules,
  // 화면코드·읽기전용·추가 권한 플래그
  ctx: Omit<GridAccessContext, "scrnCd"> & { scrnCd?: string },
) {
  const fullCtx: GridAccessContext = useMemo(
    () => ({ scrnCd: ctx.scrnCd ?? "", ...ctx }),
    [ctx.scrnCd, ctx.gridRole, ctx.readOnly, ctx.parentRow, ctx.codeMaps, ctx.extra],
  );

  const access: GridAccessFns = useMemo(
    () => buildGridAccess(rules, fullCtx),
    [rules, fullCtx],
  );

  const onLockedAttempt = useCallback((reason: LockReason) => {
    showLockedMessage(reason);
  }, []);

  return { access, rules, onLockedAttempt, ctx: fullCtx };
}

export type { GridAccessContext, LockReason };
