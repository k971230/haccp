/**
 * tabRoute — 화면코드와 계층형 URL 경로를 서로 변환한다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 화면 식별자는 계속 tbl_screen.scrn_cd(kebab). 주소창만 대/중/소 계층으로 보여 준다
 *   2) basename /haccp/ 는 Vite·BrowserRouter 가 담당한다. 여기 경로는 /docs/html/... 처럼 접두 없이 둔다
 *   3) /screen/{scrnCd} 는 쓰지 않는다. 맵에 없는 주소는 셸이 오늘 할 일로 보낸다
 *      Jenkins는 DB migrate를 안 돌린다. 메뉴 클릭은 scrnCd → routeOf 이라 120 menu_cd 개명 전에도 화면은 연다
 *
 * PIPELINE[HF68] 셸 인프라
 * PIPELINE[HF49] 연관 모듈
 */

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 같은 중분류 아래 화면코드를 접두+scrnCd 경로로 펼친다
 *   2) SCREEN_PATH 조립 때 호출한다
 *   3) 마지막 세그먼트는 항상 scrnCd 와 같다
 */
function paths(
  // 중분류까지 포함 — 예: /docs/html · /sys/logs. 문서주기는 /docs/sch
  prefix: string,
  // 이 접두 아래 둘 화면코드 목록
  cds: readonly string[]
): Record<string, string> {
  return Object.fromEntries(cds.map((cd) => [cd, `${prefix}/${cd}`]));
}

/**
 * 화면코드 → 라우터 pathname 정본.
 * URL taxonomy 와 pages/{대}/{중}/ · tbl_menu.menu_cd 가 1:1 이다. 새 화면은 레지스트리 키와 여기 한 줄을 같이 넣는다.
 */
export const SCREEN_PATH: Record<string, string> = {
  // 랜딩 — 중분류 없음
  "today-tasks": "/today-tasks",

  // 문서 주기 — 문서 기준관리 대분류 아래 중분류 sch
  ...paths("/docs/sch", ["schedule-cycle-management"]),

  // 문서 기준 — HWP·HTML 양식. 중분류 hwp / html
  ...paths("/docs/hwp", ["hwp-template-management"]),
  ...paths("/docs/html", [
    "hyg-process-template",
    "ccp-verify-template",
    "ccp-pkg-template",
    "ccp-htg-template",
    "ccp-mtl-template",
  ]),

  // 문서 작성 — CCP / PRP / 물류 / 운영·법정
  ...paths("/docs/ccp", [
    "ccp-cold-monitor",
    "ccp-metal-monitor",
    "ccp-heat-monitor",
    "ccp-sanitize-monitor",
    "ccp-filter-monitor",
    "ccp-verification-check",
    "process-hwp",
  ]),
  ...paths("/docs/prp", [
    "hygiene-process-check",
    "daily-hygiene-check",
    "pest-control-check",
    "health-cert-record",
    "facility-equipment-check",
    "calibration-target-management",
    "equipment-history",
    "pest-device-history",
    "equipment-management",
    "pest-device-management",
    "visual-insp-standard",
    "calib-self-hwp",
    "calib-ext-hwp",
    "waste-hwp",
    "verify-ca-hwp",
    "personal-hyg-hwp",
    "area-hyg-hwp",
    "water-hwp",
    "verify-plan-hwp",
    "verify-check-hwp",
    "verify-report-hwp",
    "prod-test-hwp",
    "surface-test-hwp",
  ]),
  ...paths("/docs/logis", [
    "receiving-insp-hwp",
    "submaterial-recv-hwp",
    "shipment-log-hwp",
    "inventory-hwp",
    "vehicle-hwp",
  ]),
  ...paths("/docs/admin", [
    "visitor-log",
    "edu-plan-hwp",
    "edu-log-hwp",
    "bad-product-hwp",
    "claim-hwp",
    "recall-hwp",
    "eval-hwp",
    "handover-hwp",
  ]),

  // 문서 현황 — 문서함 / 결재함 / 개선조치 (결재선 sys/code 와 구분)
  ...paths("/flow/box", ["document-inbox", "legal-document-upload"]),
  ...paths("/flow/appr", ["approval-inbox", "approval-history"]),
  ...paths("/flow/ca", ["corrective-action-management"]),

  // 기초정보
  ...paths("/bas/master", [
    "product-management",
    "material-management",
    "partner-management",
    "storage-management",
    "measuring-device-management",
    "vehicle-management",
    "work-area-management",
  ]),

  // 시스템 — 코드·권한 묶음 / 로그 묶음
  ...paths("/sys/code", [
    "common-code-management",
    "menu-management",
    "role-management",
    "department-management",
    "user-management",
    "approval-line-management",
  ]),
  ...paths("/sys/logs", ["login-history", "screen-usage-statistics", "audit-log"]),
};

/** pathname → scrnCd 역조회 — 기동 시 한 번 */
const PATH_SCREEN: Record<string, string> = Object.fromEntries(
  Object.entries(SCREEN_PATH).map(([scrnCd, path]) => [path, scrnCd])
);

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 끝 슬래시만 떼어 맵 키와 맞춘다
 *   2) parseRoute 가 호출한다
 *   3) "/" 는 그대로 둔다 — 홈과 구분해야 한다
 */
function normalizePath(
  // 라우터 pathname — 쿼리스트링 없음
  pathname: string
): string {
  if (!pathname) return "/";
  if (pathname.length > 1 && pathname.endsWith("/")) return pathname.slice(0, -1);
  return pathname;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 화면 식별자를 계층 경로로 바꾼다
 *   2) 메뉴·탭 클릭·문서 딥링크에서 호출한다
 *   3) 빈 값은 홈("/"). 맵에 없는 코드는 /today-tasks 로 보내 /screen/ 이 다시 생기지 않게 한다
 */
export function routeOf(
  // 이동할 화면코드 — tbl_screen.scrn_cd와 문자 그대로 같아야 한다
  scrnCd: string,
  // 선택 쿼리 — 문서 열기 docIdx 등. 빈 값은 붙이지 않는다
  query?: Record<string, string | number | null | undefined>
): string {
  if (!scrnCd) return "/";
  const path = SCREEN_PATH[scrnCd] ?? "/today-tasks";
  if (!query) return path;
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(query)) {
    if (value == null || value === "") continue;
    params.set(key, String(value));
  }
  const qs = params.toString();
  return qs ? `${path}?${qs}` : path;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) URL 경로에서 화면코드를 뽑는다
 *   2) 셸이 주소 변경을 감지해 어떤 탭을 열지 정할 때 호출한다
 *   3) SCREEN_PATH 정확 일치만 인정한다. /screen/... · 위조 접두 · 홈("/") 은 null
 */
export function parseRoute(
  // 현재 주소의 pathname — 쿼리스트링은 포함하지 않는다
  pathname: string
): string | null {
  return PATH_SCREEN[normalizePath(pathname)] ?? null;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-21
 * 코멘트:
 *   1) 화면 API 경로를 SCREEN_PATH 와 같은 중분류/scrnCd 로 만든다. /haccp 는 넣지 않는다
 *   2) sys/docs API 파일이 BASE·동작 URL 을 조립할 때 호출한다
 *   3) 맵에 없는 코드면 throw. axios baseURL 은 호스트만이라 여기 /api/v1 을 붙인다
 */
export function apiOf(
  // tbl_screen.scrn_cd — SCREEN_PATH 키와 같아야 한다
  scrnCd: string,
  // 동작 칸 — list · save · validate-delete · delete · groups 등. 빈 값이면 화면 베이스만
  action = ""
): string {
  const path = SCREEN_PATH[scrnCd];
  if (!path) throw new Error(scrnCd);
  return action ? `/api/v1${path}/${action}` : `/api/v1${path}`;
}
