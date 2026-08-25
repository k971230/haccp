/**
 * DocumentBoxRule — 문서함·결재함·결재이력 그리드 규칙·컬럼.
 *
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) Page는 렌더·상태·API만 담당하고 화면코드·persistId·컬럼은 이 파일이 갖는다
 *   2) inbox/approval/history 세 화면이 같은 Page를 mode로 나눈다. persistId는 화면마다 다르다
 *   3) 키 값은 폴더를 옮겨도 바꾸지 않는다
 *
 * PIPELINE[HF83] 문서함 그리드 규칙
 */
// 역할 — 그리드 컬럼 타입
import type { GridColumn } from "@/types/grid";
// 역할 — 문서 목록·상세 타입
import type { DocumentDetail, DocumentListRow } from "@/api/documentApi";
// 역할 — 양식 유형 정본 상수
import { DOC_KIND_HTML, DOC_KIND_HWP } from "@/lib/docKind";

/** 문서함 / 결재함 / 결재이력 */
export type DocumentBoxMode = "inbox" | "approval" | "history";

/** 목록 행 — 상태·타입·작성자 표시열 */
export type ListRow = DocumentListRow & {
  _key: string;
  statusNm?: string;
  docKindNm?: string;
  writerDisp?: string;
};

/** 결재 단계 행 */
export type ApprRow = DocumentDetail["approvals"][number] & {
  _key: string;
  roleNm?: string;
  resultNm?: string;
};

/** 양식 타입 필터 — value는 DB 정본 소문자 */
export const DOC_KIND_OPTIONS = [
  { value: "", label: "전체" },
  { value: DOC_KIND_HTML, label: "DB형" },
  { value: DOC_KIND_HWP, label: "한글형" },
] as const;

/** 상세 패널 결재 이력 그리드 키 — 세 화면 공통 */
export const APPR_HIST_PERSIST_ID = "doc-box-approval-history" as const;

/**
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) mode별 tbl_screen.scrn_cd
 *   2) 권한 조회에 쓴다
 *   3) 결재 2화면은 2026-08-25 에 approval-inbox·approval-history 에서 개명했다 (마이그레이션 127)
 */
export function scrnCdOf(mode: DocumentBoxMode): string {
  if (mode === "approval") return "sign-ready";
  if (mode === "history") return "sign-ok";
  return "document-inbox";
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 목록 그리드 persistId — 문서함/결재대기/결재완료를 분리한다
 *   2) 열 너비 저장이 화면마다 달라야 해서 키를 나눈다
 *   3) 값 변경 금지 — 화면코드를 sign-ready·sign-ok 로 개명해도 이 키는 그대로 둔다.
 *      바꾸면 사용자가 저장해 둔 열 너비가 전부 초기화된다
 */
export function listPersistIdOf(mode: DocumentBoxMode): string {
  if (mode === "approval") return "doc-approval-inbox";
  if (mode === "history") return "doc-approval-history";
  return "doc-document-inbox";
}

/** byte → 사람이 읽는 크기 */
export function fileSize(size?: number | null): string {
  if (size == null) return "";
  return `${(size / 1024).toFixed(1)} KB`;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 목록 열 — 타입·기준일·양식·문서번호·제목·작성자·상태
 *   2) 조회 전용
 *   3) Page가 useMemo로 호출한다
 */
export function buildListColumns(): GridColumn<ListRow>[] {
  return [
    { field: "docKindNm", header: "타입", width: 80 },
    { field: "baseDt", header: "기준일", width: 100 },
    { field: "tmplNm", header: "양식", width: 140 },
    { field: "docNo", header: "문서번호", width: 130 },
    { field: "title", header: "제목", width: 160 },
    { field: "writerDisp", header: "작성자", width: 100 },
    { field: "statusNm", header: "상태", width: 90 },
  ];
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) 상세 결재 이력 열
 *   2) 조회 전용
 *   3) Page가 useMemo로 호출한다
 */
export function buildApprColumns(): GridColumn<ApprRow>[] {
  return [
    { field: "roleNm", header: "단계", width: 90 },
    { field: "approverNm", header: "담당자", width: 110 },
    { field: "resultNm", header: "결과", width: 90 },
    { field: "opinion", header: "의견", width: 180 },
  ];
}
