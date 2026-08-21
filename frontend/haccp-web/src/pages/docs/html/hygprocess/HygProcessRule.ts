/**
 * HygProcessRule — 일반위생관리 및 공정점검표 작성 상수·목록 컬럼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 컬럼·화면코드는 Page JSX에 하드코딩하지 않는다
 *   2) persistId는 폴더를 옮겨도 바꾸지 않는다
 *   3) 신규는 적용 버전 항목을 서버가 채운다
 *
 * PIPELINE[HF131] 공정점검 규칙
 */
// 역할 — 그리드 컬럼
import type { GridColumn } from "@/types/grid";

export const SCRN_CD = "hygiene-process-check" as const;
export const PERSIST_ID = "hygiene-process-check-list" as const;
export const PAPER_TITLE = "일반위생관리 및 공정점검표";
export const PAPER_SUBTITLE = "(매일 작성)";

export type HygProcessListRowView = {
  docNo?: string;
  baseDtDisp?: string;
  statusNm?: string;
  checkerNm?: string;
};

/**
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 좌측 문서 목록 컬럼을 만든다
 *   2) Page가 useMemo로 호출한다
 *   3) 신규 draft는 기준일만 편집
 */
export function buildListColumns(): GridColumn<HygProcessListRowView>[] {
  return [
    { field: "docNo", header: "문서번호", width: 140 },
    { field: "baseDtDisp", header: "점검일자", width: 110, editableOnNew: true, type: "date" },
    { field: "statusNm", header: "상태", width: 80 },
    { field: "checkerNm", header: "점검자", width: 90 },
  ];
}
