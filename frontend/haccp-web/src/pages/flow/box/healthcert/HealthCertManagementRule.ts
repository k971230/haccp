/**
 * HealthCertManagementRule — 보건증 화면 컬럼·식별자.
 *
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) Page 는 렌더·API 만. 컬럼·검색 거름은 여기
 *   2) persistId 는 폴더를 옮겨도 고정
 *   3) 상태 콤보는 공통코드 HC_STATUS. 검색어는 사원명만
 *
 * PIPELINE[HF215] 보건증 규칙
 */
import type { GridColumn } from "@/types/grid";
import type { ScreenGridRules } from "@/shell/gridRules/types";
import type { HealthCertEmp, HealthCertHist } from "@/api/flow/healthCertApi";
import { todayYmd } from "@/lib/docDateTime";

export const SCRN_CD = "health-cert-management" as const;
export const EMP_PERSIST_ID = "health-cert-emp" as const;
export const HIST_PERSIST_ID = "health-cert-hist" as const;
export const SPLIT_KEY = "haccp-split-health-cert-30";

/** 좌 사원 — 조회만. 등록은 우 행추가 팝업 */
export const EMP_RULES: ScreenGridRules = {};
/** 우 이력 — 셀 수정 없음. 추가는 팝업, 삭제는 체크 행 */
export const HIST_RULES: ScreenGridRules = {};

/** 검색 상태 공통코드 — 빈값=전체. sub_cd 는 거름 값과 같다 */
export const HC_STATUS_MAIN_CD = "HC_STATUS" as const;
export const EMP_STATUS_ALL = "";
export const EMP_STATUS_DUE = "DUE";
export const EMP_STATUS_EXPIRED = "EXPIRED";

/** YYYYMMDD 에 일수를 더한다 — 임박 창 끝 */
function addDaysYmd(ymd: string, days: number): string {
  const y = Number(ymd.slice(0, 4));
  const m = Number(ymd.slice(4, 6));
  const d = Number(ymd.slice(6, 8));
  const dt = new Date(y, m - 1, d);
  dt.setDate(dt.getDate() + days);
  const yy = dt.getFullYear();
  const mm = String(dt.getMonth() + 1).padStart(2, "0");
  const dd = String(dt.getDate()).padStart(2, "0");
  return `${yy}${mm}${dd}`;
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) 검색어는 사원명 부분일치. 서버 LIKE 가 없다
 *   2) 상태 임박은 오늘~오늘+N일. 만료는 오늘 이전. 만료일 없는 행은 전체에만 남는다
 *   3) 빈 검색·빈 상태는 통과
 */
export function matchEmp(
  // 대상 사원 한 행
  row: HealthCertEmp,
  // 사원명 검색어
  q: string,
  // 전체·임박·만료
  status: string,
  // 임박 창 일수 — 설정 MAX. 없으면 30
  windowDays: number | undefined,
): boolean {
  const needle = q.trim().toLowerCase();
  if (needle) {
    const nm = String(row.userNm ?? "").toLowerCase();
    if (!nm.includes(needle)) return false;
  }
  const exp = String(row.expireDt ?? "").replace(/-/g, "");
  if (status === EMP_STATUS_DUE || status === EMP_STATUS_EXPIRED) {
    if (exp.length !== 8) return false;
    const today = todayYmd();
    if (status === EMP_STATUS_EXPIRED) return exp < today;
    const n = windowDays && windowDays > 0 ? windowDays : 30;
    return exp >= today && exp <= addDaysYmd(today, n);
  }
  return true;
}

export function buildEmpColumns(): GridColumn<HealthCertEmp>[] {
  return [
    { field: "userNm", header: "사원명", width: 120, editable: false },
    { field: "deptNm", header: "부서", width: 120, editable: false },
    { field: "expireDt", header: "만료일", width: 100, editable: false, type: "date" },
    { field: "histCnt", header: "이력", width: 60, editable: false, align: "right" },
  ];
}

export function buildHistColumns(
  onView: (row: HealthCertHist) => void,
): GridColumn<HealthCertHist>[] {
  return [
    { field: "regDt", header: "등록일", width: 100, editable: false, type: "date" },
    { field: "expireDt", header: "만료일", width: 100, editable: false, type: "date" },
    {
      field: "fileNm",
      header: "파일",
      width: 220,
      editable: false,
      cellButton: { title: "열람", onClick: (row: HealthCertHist) => onView(row) },
    },
    { field: "insNm", header: "등록자", width: 100, editable: false },
  ];
}

export function empKey(row: HealthCertEmp): string {
  return String(row.userId ?? "");
}

export function histKey(row: HealthCertHist): string {
  return String(row.idx ?? "");
}
