/**
 * documentNav — 문서 목록 행 → 작성/편집 화면 경로.
 *
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 홈·문서함에서 최근 문서를 열 때 tmplCd·docKind로 대상 화면을 고른다
 *   2) DB형·HWP문서만 모두 표에 등록된 scrn_cd로 보낸다
 *   3) 알 수 없는 양식은 문서함으로 보낸다
 *
 * PIPELINE[HF82] 문서 네비게이션
 */
// 역할 — 화면코드 → URL
import { routeOf } from "@/shell/tabRoute";

/** tmpl_cd → 작성 화면코드 (IA·36 migrate 정합) */
const TMPL_SCREEN: Record<string, string> = {
  CCP_COLD: "ccp-cold-monitor",
  CCP_METAL: "ccp-metal-monitor",
  CCP_HEAT: "ccp-heat-monitor",
  CCP_SANITIZE: "ccp-sanitize-monitor",
  CCP_FILTER: "ccp-filter-monitor",
  CCP_VERIFY: "ccp-verification-check",
  DAILY_HYG: "daily-hygiene-check",
  PEST: "pest-control-check",
  FACILITY: "facility-equipment-check",
  LAW_HEALTH: "health-cert-record",
  PERSONAL_HYG: "personal-hyg-hwp",
  AREA_HYG: "area-hyg-hwp",
  WATER: "water-hwp",
  WASTE: "waste-hwp",
  INV_CHECK: "inventory-hwp",
  RECV_INSP: "receiving-insp-hwp",
  PROCESS: "process-hwp",
  VERIFY_PLAN: "verify-plan-hwp",
  VERIFY_CHECK: "verify-check-hwp",
  VERIFY_REPORT: "verify-report-hwp",
  VERIFY_CA: "verify-ca-hwp",
  EDU_PLAN: "edu-plan-hwp",
  EDU_LOG: "edu-log-hwp",
  BAD_PRODUCT: "bad-product-hwp",
  CLAIM: "claim-hwp",
  HANDOVER: "handover-hwp",
  EQUIP_CARD: "equipment-history",
  VEHICLE_LOG: "vehicle-hwp",
  PROD_TEST: "prod-test-hwp",
  SURFACE_TEST: "surface-test-hwp",
  CALIB_LOG_TEMP: "calib-self-hwp",
  CALIB_LOG_WGT: "calib-self-hwp",
  CALIB_LOG_SCL: "calib-self-hwp",
  VISITOR_LOG: "visitor-log",
  VISUAL_INSP: "visual-insp-standard",
  SUBMAT_RECV: "submaterial-recv-hwp",
  CALIB_EXT: "calib-ext-hwp",
  SHIPMENT: "shipment-log-hwp",
  RECALL: "recall-hwp",
  EVAL: "eval-hwp",
};

export interface DocumentNavInput {
  // 문서 대리키 — 쿼리 docIdx
  docIdx: number;
  // 양식코드 — 화면 매핑
  tmplCd: string;
  // DB | HWP
  docKind?: string | null;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 문서 행을 작성 화면 URL로 바꾼다 (?docIdx=)
 *   2) 홈 최근 문서·문서함 「작성화면」에서 호출한다
 *   3) 매핑 실패 시 문서함으로 보내고 같은 docIdx를 넘긴다
 */
export function routeForDocument(
  // 열 문서 — idx·양식·종류
  row: DocumentNavInput
): string {
  const scrn = TMPL_SCREEN[row.tmplCd];
  if (scrn) {
    return routeOf(scrn, { docIdx: String(row.docIdx) });
  }
  return routeOf("document-inbox", { docIdx: String(row.docIdx) });
}
