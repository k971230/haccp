/**
 * documentNav — 문서 목록 행 → 작성/편집 화면 경로.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 홈·문서함에서 최근 문서를 열 때 tmplCd·docKind로 대상 화면을 고른다
 *   2) DB형·HWP문서만 모두 표에 등록된 scrn_cd로 보낸다
 *   3) 알 수 없는 양식은 문서함으로 보낸다
 *
 * PIPELINE[HF82] 문서 네비게이션
 */
// 역할 — 화면코드 → URL
import { routeOf } from "@/shell/tabRoute";

/** tmpl_cd → 작성 화면코드 — kebab 양식코드는 따옴표 키 */
const TMPL_SCREEN: Record<string, string> = {
  "tmpl_ccp-cold-log": "ccp-cold-monitor",
  "tmpl_ccp-metal-log": "ccp-metal-monitor",
  "tmpl_ccp-heat-log": "ccp-heat-monitor",
  "tmpl_ccp-sanitize-log": "ccp-sanitize-monitor",
  "tmpl_ccp-filter-log": "ccp-filter-monitor",
  "tmpl_ccp-verify-check": "ccp-verification-check",
  "tmpl_prp-hygiene-daily": "daily-hygiene-check",
  "tmpl_prp-pest-check": "pest-control-check",
  "tmpl_prp-facility-check": "facility-equipment-check",
  "tmpl_admin-law-health": "health-cert-record",
  "tmpl_prp-hygiene-personal": "personal-hyg-hwp",
  "tmpl_prp-hygiene-area": "area-hyg-hwp",
  "tmpl_prp-water-check": "water-hwp",
  "tmpl_prp-waste-check": "waste-hwp",
  "tmpl_logis-inventory-check": "inventory-hwp",
  "tmpl_logis-receive-inspect": "receiving-insp-hwp",
  "tmpl_ccp-process-check": "process-hwp",
  "tmpl_prp-verify-plan": "verify-plan-hwp",
  "tmpl_prp-verify-check": "verify-check-hwp",
  "tmpl_prp-verify-report": "verify-report-hwp",
  "tmpl_prp-verify-action": "verify-ca-hwp",
  "tmpl_admin-edu-plan": "edu-plan-hwp",
  "tmpl_admin-edu-log": "edu-log-hwp",
  "tmpl_admin-bad-product": "bad-product-hwp",
  "tmpl_admin-claim-log": "claim-hwp",
  "tmpl_admin-handover-doc": "handover-hwp",
  "tmpl_prp-equip-card": "equipment-history",
  "tmpl_logis-vehicle-log": "vehicle-hwp",
  "tmpl_prp-test-product": "prod-test-hwp",
  "tmpl_prp-test-surface": "surface-test-hwp",
  "tmpl_prp-calib-temp": "calib-self-hwp",
  "tmpl_prp-calib-weight": "calib-self-hwp",
  "tmpl_prp-calib-scale": "calib-self-hwp",
  "tmpl_admin-visitor-log": "visitor-log",
  "tmpl_prp-visual-inspect": "visual-insp-standard",
  "tmpl_logis-submat-receive": "submaterial-recv-hwp",
  "tmpl_prp-calib-ext": "calib-ext-hwp",
  "tmpl_logis-shipment-log": "shipment-log-hwp",
  "tmpl_admin-recall-report": "recall-hwp",
  "tmpl_admin-eval-check": "eval-hwp",
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
 * 일자: 2026-08-12
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
