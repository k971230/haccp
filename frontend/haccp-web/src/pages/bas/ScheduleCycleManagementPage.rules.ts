/**
 * ScheduleCycleManagementPage.rules — 작성주기 그리드 잠금 규칙.
 *
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) 좌측 양식코드(tmplCd)는 신규 행(미사용 등록)에서만 입력한다
 *   2) 우측 주기는 tmplCd 콤보 없이 좌측 선택으로 고정한다
 *   3) ProcessPage.rules와 같은 ScreenGridRules 형식을 사용한다
 *
 * PIPELINE[HF101] 작성주기 그리드 규칙
 * PIPELINE[HF89, HF96] 연관 모듈
 */
// 역할 — 그리드 잠금 규칙 타입
import type { ScreenGridRules } from "@/shell/gridRules/types";

/** 작성주기 좌측 문서 그리드 — 양식코드는 신규 전용 */
export const SCHEDULE_CYCLE_GRID_RULES: ScreenGridRules = {
  newOnly: ["tmplCd"],
};
