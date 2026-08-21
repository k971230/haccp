/**
 * MasterDataPage.rules — 기준정보 8종 그리드 잠금 규칙.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 업무키는 신규 행에서만 입력하고 저장 뒤에는 잠근다
 *   2) 화면코드별로 keyField를 newOnly에 매핑한다
 *   3) ProcessPage.rules와 같은 ScreenGridRules 형식을 사용한다
 *   4) equipment-management / pest-device-management 는 History 화면으로 매핑되어
 *      MasterDataPage에 도달하지 않으므로 09 G-13 근거로 2026-08-10 제거했다
 *
 * PIPELINE[HF100] 기준정보 그리드 규칙
 * PIPELINE[HF85, HF96] 연관 모듈
 */
// 역할 — 그리드 잠금 규칙 타입
import type { ScreenGridRules } from "@/shell/gridRules/types";

/** 화면코드별 업무키 newOnly 규칙 */
export const MASTER_GRID_RULES: Record<string, ScreenGridRules> = {
  "product-management": { newOnly: ["productCd"] },
  "material-management": { newOnly: ["materialCd"] },
  "partner-management": { newOnly: ["partnerCd"] },
  "storage-management": { newOnly: ["storageCd"] },
  "measuring-device-management": { newOnly: ["deviceCd"] },
  "vehicle-management": { newOnly: ["vehicleCd"] },
  "work-area-management": { newOnly: ["areaCd"] },
  "ccp-limit-management": { newOnly: ["ccpCd"] },
};
