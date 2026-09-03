/**
 * DocumentBoxRule — 문서함·결재함·결재이력 그리드 규칙·컬럼.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) Page는 렌더·상태·API만 담당하고 화면코드·persistId·컬럼은 이 파일이 갖는다
 *   2) inbox/approval/history 세 화면이 같은 Page를 mode로 나눈다. persistId는 화면마다 다르다
 *   3) 상태 열은 DOC_STATUS_BADGE 색을 쓴다. 키 값은 폴더를 옮겨도 바꾸지 않는다
 *      결재 단계는 그리드가 아니라 첨부화면과 같은 순서형 스테퍼다
 *
 * PIPELINE[HF83] 문서함 그리드 규칙
 * PIPELINE[HF187] 연관 — 문서함 인쇄·결재 스테퍼
 */
// 역할 — 그리드 컬럼 타입
import type { GridColumn } from "@/types/grid";
// 역할 — 문서 목록·결재 단계 타입
import type { DocumentApprovalRow, DocumentListRow } from "@/api/documentApi";
// 역할 — 양식 유형 정본 상수
import { DOC_KIND_HTML, DOC_KIND_HWP } from "@/lib/docKind";
// 역할 — 문서상태 배지 색 — 오늘 할 일·결재첨부와 같다
import { DOC_STATUS_BADGE } from "@/lib/docStatus";
// 역할 — 결재 스테퍼 칸 타입 — 컴포넌트와 같은 계약
import type { ApprovalLineStepView, ApprovalLineTone } from "@/components/document/ApprovalLineSteps";

export type { ApprovalLineStepView, ApprovalLineTone };

/** 문서함 / 결재함 / 결재이력 */
export type DocumentBoxMode = "inbox" | "approval" | "history";

/** 목록 행 — 타입·작성자 표시열. 상태는 row.status + codeMap */
export type ListRow = DocumentListRow & {
  _key: string;
  docKindNm?: string;
  writerDisp?: string;
};

/** 양식 타입 필터 — value는 DB 정본 소문자 */
export const DOC_KIND_OPTIONS = [
  { value: "", label: "전체" },
  { value: DOC_KIND_HTML, label: "DB형" },
  { value: DOC_KIND_HWP, label: "한글형" },
] as const;

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

/**
 * 개발자: 박승우
 * 일자: 2026-09-02
 * 코멘트:
 *   1) 좌우 분할 비율 localStorage 키 — 세 화면이 비율을 따로 기억한다
 *   2) DocumentBoxPage ResizableSplit 이 마운트할 때 쓴다
 *   3) persistId 와 달리 이번에 처음 넣는 키라 화면코드(document-inbox·sign-ready·sign-ok)를 그대로 쓴다
 */
export function splitKeyOf(
  // inbox/approval/history — scrnCdOf 와 같은 세 값
  mode: DocumentBoxMode,
): string {
  return `haccp-split-${scrnCdOf(mode)}-50`;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 목록 열 — 타입·기준일·양식·문서번호·제목·작성자·상태 배지
 *   2) 조회 전용. 상태 색은 DOC_STATUS_BADGE
 *   3) Page가 useMemo로 호출한다
 */
export function buildListColumns(
  // 상태코드 → 라벨 — DOC_STATUS 공통코드 맵. 화면이 넘긴다
  statusNm: Record<string, string>,
): GridColumn<ListRow>[] {
  return [
    { field: "docKindNm", header: "타입", width: 80 },
    { field: "baseDt", header: "기준일", width: 100 },
    { field: "tmplNm", header: "양식", width: 140 },
    { field: "docNo", header: "문서번호", width: 130 },
    // 식별 제목 — 언제·무엇을 썼는지. 우측 h2·지면 제목(양식명)과 다르다
    { field: "title", header: "제목", width: 160 },
    { field: "writerDisp", header: "작성자", width: 100 },
    {
      // 결재상태 — 색 배지. 업무 상태가 정하고 사용자가 바꾸지 않는다
      field: "status",
      header: "상태",
      width: 90,
      type: "code",
      editable: false,
      codeMap: statusNm,
      badge: DOC_STATUS_BADGE,
    },
  ];
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 결재 단계 결과코드로 스테퍼 칸 색을 고른다
 *   2) ApprovalLineSteps 가 칸을 그릴 때 쓴다
 *   3) 대기(W) 중 가장 앞 칸만 현재(active), 나머지는 대기. 승인(A)은 완료, 반려(R)은 rejected (빨강)
 */
export function approvalLineToneOf(
  // 단계별 결과코드 — W 대기 · A 승인 · R 반려. 화면이 넘긴 순서 그대로
  results: Array<string | null | undefined>,
  // 지금 칸 인덱스 — 0부터
  index: number,
): ApprovalLineTone {
  const cd = String(results[index] ?? "").toUpperCase();
  if (cd === "R") return "rejected";
  if (cd === "A") return "done";
  const firstWait = results.findIndex((r) => String(r ?? "").toUpperCase() === "W");
  if (index === firstWait) return "active";
  return "pending";
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 문서 결재 단계 행을 첨부화면과 같은 순서형 스테퍼 칸으로 바꾼다
 *   2) DocumentBoxPage 상세 패널이 호출한다
 *   3) 역할·결과 라벨은 화면이 공통코드로 넘겨 준다 — Rule 은 코드를 모른다
 */
export function buildApprovalLineSteps(
  // 문서 상세 approvals — stepNo 오름차순이라고 가정하지 않고 여기서 정렬한다
  steps: DocumentApprovalRow[],
  // 역할코드 → 라벨 (WRITE→작성 등)
  roleLabel: (cd: string) => string,
  // 결과코드 → 라벨 (A→승인 등)
  resultLabel: (cd: string) => string,
  // 처리일시 표시 변환 — 없으면 칸에 시각을 안 넣는다
  formatActDt?: (value: string | null | undefined) => string,
): ApprovalLineStepView[] {
  const ordered = [...steps].sort((a, b) => a.stepNo - b.stepNo);
  const results = ordered.map((s) => s.resultCd);
  return ordered.map((step, index) => {
    const act = formatActDt ? formatActDt(step.actDt) : "";
    const resultNm = resultLabel(step.resultCd);
    const detail = [resultNm, act && act !== "-" ? act : ""].filter(Boolean).join(" · ");
    return {
      key: String(step.idx || `${step.roleCd}-${step.stepNo}`),
      label: roleLabel(step.roleCd),
      tone: approvalLineToneOf(results, index),
      caption: (step.approverNm || step.approverId || "").trim(),
      detail,
      opinion: (step.opinion ?? "").trim(),
    };
  });
}
