/**
 * HealthCertManagementRule — 보건증 화면 컬럼·식별자.
 *
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) Page 는 렌더·API 만. 컬럼은 여기
 *   2) persistId 는 폴더를 옮겨도 고정
 *   3) 임박 라벨은 설정 N일을 받아 만든다
 *
 * PIPELINE[HF215] 보건증 규칙
 */
import type { GridColumn } from "@/types/grid";
import type { ScreenGridRules } from "@/shell/gridRules/types";
import type { HealthCertEmp, HealthCertHist } from "@/api/flow/healthCertApi";

export const SCRN_CD = "health-cert-management" as const;
export const EMP_PERSIST_ID = "health-cert-emp" as const;
export const HIST_PERSIST_ID = "health-cert-hist" as const;
export const SPLIT_KEY = "haccp-split-health-cert-30";

/** 좌 사원 — 조회만. 등록은 우측 파일 칸 */
export const EMP_RULES: ScreenGridRules = {};
/** 우 이력 — 조회만. 삭제는 헤더 버튼 */
export const HIST_RULES: ScreenGridRules = {};

export function expiringLabel(days: number | undefined): string {
  const n = days && days > 0 ? days : 30;
  return `보건증 만료 ${n}일 전`;
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
