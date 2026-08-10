/**
 * ApprovalLineManagementPage.rules — 결재선 그리드 잠금 규칙.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 결재선코드(apprLineCd)는 신규 행에서만 편집한다
 *   2) useGridAccess에 넘겨 MasterData·ScheduleCycle과 동일 패턴을 쓴다
 *   3) 저장 가드가 newOnly 위반을 막는다
 *
 * PIPELINE[HF87] 결재선 그리드 규칙
 */
// 역할 — 그리드 잠금 규칙 타입
import type { ScreenGridRules } from "@/shell/gridRules/types";

/** 결재선 헤더 — 업무키 newOnly */
export const APPROVAL_LINE_GRID_RULES: ScreenGridRules = {
  newOnly: ["apprLineCd"],
};
