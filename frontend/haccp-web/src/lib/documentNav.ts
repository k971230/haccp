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

/** tmpl_cd → 작성 화면코드 — html_sys / hwp_sys 키. 옛 kebab 은 기존 문서용 */
const TMPL_SCREEN: Record<string, string> = {
  html_sys_001: "hygiene-process-check",
  html_sys_012: "ccp-cold-monitor",
  html_sys_002: "ccp-metal-monitor",
  html_sys_003: "ccp-heat-monitor",
  html_sys_004: "ccp-sanitize-monitor",
  html_sys_005: "ccp-filter-monitor",
  html_sys_006: "ccp-verification-check",
  html_sys_007: "daily-hygiene-check",
  html_sys_008: "pest-control-check",
  html_sys_009: "facility-equipment-check",
  html_sys_010: "calibration-target-management",
  html_sys_011: "health-cert-record",
  hwp_sys_001: "visitor-log",
  hwp_sys_002: "handover-hwp",
  hwp_sys_003: "verify-plan-hwp",
  hwp_sys_004: "verify-check-hwp",
  hwp_sys_005: "verify-report-hwp",
  hwp_sys_006: "verify-ca-hwp",
  hwp_sys_007: "edu-plan-hwp",
  hwp_sys_008: "edu-log-hwp",
  hwp_sys_009: "personal-hyg-hwp",
  hwp_sys_010: "area-hyg-hwp",
  hwp_sys_014: "calib-self-hwp",
  hwp_sys_015: "waste-hwp",
  hwp_sys_016: "inventory-hwp",
  hwp_sys_017: "receiving-insp-hwp",
  hwp_sys_018: "prod-test-hwp",
  hwp_sys_019: "surface-test-hwp",
  hwp_sys_020: "bad-product-hwp",
  hwp_sys_021: "water-hwp",
  hwp_sys_022: "claim-hwp",
  hwp_sys_023: "vehicle-hwp",
  hwp_sys_025: "recall-hwp",
  hwp_sys_026: "visual-insp-standard",
  hwp_sys_028: "process-hwp",
  hwp_sys_029: "submaterial-recv-hwp",
  hwp_sys_030: "calib-ext-hwp",
  hwp_sys_031: "shipment-log-hwp",
  hwp_sys_032: "eval-hwp",
  hwp_sys_033: "legal-document-upload",
  hwp_sys_034: "legal-document-upload",
  hwp_sys_035: "legal-document-upload",
  hwp_sys_036: "legal-document-upload",
  hwp_sys_037: "legal-document-upload",
  hwp_sys_038: "legal-document-upload",
  // 설비이력은 DB형 M-D. 옛 문서 tmpl_cd 가 남아 있으면 여기로 연다
  "tmpl_prp-equip-card": "equipment-history",
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
