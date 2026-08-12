/**
 * SystemManagementPage.rules — 시스템 관리 그리드 잠금 규칙.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 업무키는 신규 행에서만 입력하고 저장 뒤에는 잠근다
 *   2) 메뉴관리는 추가 불가·메뉴명·사용여부만 수정 (alwaysReadonly)
 *   3) 로그 3화면은 LogManagementPage로 분리되어 여기에 두지 않는다
 *
 * PIPELINE[HF98] 시스템 관리 그리드 규칙
 * PIPELINE[HF99, HF96] 연관 모듈
 */
// 역할 — 그리드 잠금 규칙 타입
import type { ScreenGridRules } from "@/shell/gridRules/types";

/** 시스템 CRUD 화면코드 — 로그 화면 제외 */
export type SystemManageScreenCode =
  | "user-management"
  | "department-management"
  | "role-management"
  | "menu-management"
  | "common-code-management";

/** 화면코드별 newOnly 규칙 */
export const SYSTEM_GRID_RULES: Record<SystemManageScreenCode, ScreenGridRules> = {
  "user-management": { newOnly: ["userId"] },
  "department-management": { newOnly: ["deptCd"] },
  "role-management": { newOnly: ["usrgrpCd"] },
  // 메뉴관리 — 추가 불가·메뉴명·사용여부만 수정 (코드·상위·화면·정렬 잠금)
  "menu-management": {
    alwaysReadonly: ["grpANm", "grpBNm", "grpCNm", "menuCd", "hMenuCd", "scrnCd", "sortNo"],
  },
  "common-code-management": { newOnly: ["mainCd", "subCd"] },
};
