/**
 * SystemManagementPage.rules — 시스템 관리 그리드 잠금 규칙.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 업무키는 신규 행에서만 입력하고 저장 뒤에는 잠근다
 *   2) 이력·통계 화면은 페이지에서 readOnly 컨텍스트로 잠근다
 *   3) ProcessPage.rules와 같은 ScreenGridRules 형식을 사용한다
 *
 * PIPELINE[HF98] 시스템 관리 그리드 규칙
 * PIPELINE[HF99, HF96] 연관 모듈
 */
// 역할 — 그리드 잠금 규칙 타입
import type { ScreenGridRules } from "@/shell/gridRules/types";
// 역할 — 시스템 화면코드
import type { SystemScreenCode } from "@/api/systemApi";

/** 화면코드별 newOnly 규칙 — 이력 화면은 빈 규칙 + 페이지 readOnly */
export const SYSTEM_GRID_RULES: Record<SystemScreenCode, ScreenGridRules> = {
  "company-management": { newOnly: [] },
  "user-management": { newOnly: ["userId"] },
  "department-management": { newOnly: ["deptCd"] },
  "role-management": { newOnly: ["usrgrpCd"] },
  "menu-management": { newOnly: ["menuCd"] },
  "common-code-management": { newOnly: ["mainCd", "subCd"] },
  "login-history": {},
  "screen-usage-statistics": {},
  "audit-log": {},
};

/** 이력·통계 화면 — 편집·추가·삭제 UI를 숨긴다 */
export const SYSTEM_HISTORY_SCREENS = new Set<SystemScreenCode>([
  "login-history",
  "screen-usage-statistics",
  "audit-log",
]);
