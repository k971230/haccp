/**
 * ApprovalAttachRule — 결재 첨부 화면 상수·컬럼·잠금 판정.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 화면코드·pref 키·목록 컬럼·첨부 상한·원본/첨부 분류·진행 스테퍼만 둔다
 *   2) ApprovalAttachPage 가 가져다 쓴다
 *   3) JSX·API 없음 — 09-haccp-frontend 규칙
 *
 * 원본(HWP_SRC·PDF)은 다운로드만. 사용자 첨부(ATTACH·PHOTO)만 추가·삭제·개수에 넣는다.
 * 결재는 전송(REQUEST) → 결재(APPROVE) 2단. 검토 단계는 없다.
 *
 * PIPELINE[HF185] 결재 첨부 화면
 */
// 역할 — 그리드 컬럼 정의
import type { GridColumn } from "@/types/grid";
// 역할 — 문서 목록 행
import type { DocumentListRow } from "@/api/documentApi";
// 역할 — 문서상태 배지 색·코드 상수 (오늘 할 일과 공유)
import { DOC_STATUS, DOC_STATUS_BADGE, docStatusBadgeClass } from "@/lib/docStatus";
// 역할 — 스테퍼 칸 색 — 문서함 결재선과 같다
import { stepperToneClass, type StepperTone } from "@/components/document/stepperTone";
// 역할 — 원본/첨부 분류·뱃지 — 문서함과 같은 카드
import {
  USER_FILE_KINDS,
  fileKindBadgeOf,
  splitFiles,
  type FileKindBadge,
} from "@/components/document/DocFileList";

export { DOC_STATUS_BADGE, docStatusBadgeClass, fileKindBadgeOf, splitFiles, USER_FILE_KINDS };
export type { FileKindBadge };

/** 좌측 목록 행 — 상태 라벨을 더한 문서 목록 행 */
export type AttachListRow = DocumentListRow & {
  _key: string;
  statusNm?: string;
};

/** 화면코드 — tbl_screen.scrn_cd. 권한·API 베이스 기준 */
export const SCRN_CD = "attach" as const;

/** 목록 그리드 열 너비·정렬 저장 키 */
export const PERSIST_ID = "appr-attach-list" as const;

/** 첨부 파일 목록 저장 키 */
export const FILE_PERSIST_ID = "appr-attach-files" as const;

/** 좌우 분할 비율 저장 키 — 50 은 기본 반반 */
export const SPLIT_KEY = "haccp-split-attach-50" as const;

/** 사용자 첨부 상한 — 문서 1건당 5개.
 * HWP_SRC(본문)·PDF(완료본)는 시스템이 만드는 파일이라 세지 않는다.
 */
export const ATTACH_MAX = 5;

/** 첨부 상한 초과 안내 — 프론트·서버 문구를 맞춘다 */
export const ATTACH_MAX_MSG = `첨부파일은 최대 ${ATTACH_MAX}개까지 등록할 수 있습니다.`;

/** 진행 스테퍼 한 칸 — 작성·전송·결재 */
export type AttachStepperKey = "write" | "draft" | "approve";

/** 스테퍼 칸 상태 — 완료·현재·대기·반려. 색 정본은 stepperTone */
export type AttachStepperTone = StepperTone;

/** 스테퍼 한 칸 */
export type AttachStepperStep = {
  key: AttachStepperKey;
  label: string;
  tone: AttachStepperTone;
};

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 사용자 첨부(일반첨부·사진)만 센다
 *   2) 업로드 직전 상한 검사와 목록 카운트 표시가 호출한다
 *   3) 본문 HWPX·PDF 는 시스템 파일이라 제외한다
 */
export function countUserFiles(
  // 문서 파일 전체
  files: { fileKind: string }[]
): number {
  return files.filter((f) => (USER_FILE_KINDS as readonly string[]).includes(f.fileKind)).length;
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 문서 상태로 작성·전송·결재 3칸 스테퍼를 만든다
 *   2) 결재첨부 우측 진행상태가 호출한다
 *   3) 검토 칸은 없다. 미전송이면 작성만 활성 + 안내 문구
 */
export function attachStepperOf(
  // 문서 상태 WRK/REQ/APV/RJT
  status?: string | null,
): { steps: AttachStepperStep[]; hint: string | null } {
  const st = status === DOC_STATUS.TMP || !status ? DOC_STATUS.WRK : status;
  if (st === DOC_STATUS.APV) {
    return {
      steps: [
        { key: "write", label: "작성", tone: "done" },
        { key: "draft", label: "전송", tone: "done" },
        { key: "approve", label: "결재", tone: "done" },
      ],
      hint: null,
    };
  }
  if (st === DOC_STATUS.REQ) {
    return {
      steps: [
        { key: "write", label: "작성", tone: "done" },
        { key: "draft", label: "전송", tone: "done" },
        { key: "approve", label: "결재", tone: "active" },
      ],
      hint: null,
    };
  }
  if (st === DOC_STATUS.RJT) {
    return {
      steps: [
        { key: "write", label: "작성", tone: "done" },
        { key: "draft", label: "전송", tone: "done" },
        { key: "approve", label: "결재", tone: "rejected" },
      ],
      hint: null,
    };
  }
  return {
    steps: [
      { key: "write", label: "작성", tone: "active" },
      { key: "draft", label: "전송", tone: "pending" },
      { key: "approve", label: "결재", tone: "pending" },
    ],
    hint: "아직 전송하지 않은 문서입니다.",
  };
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 스테퍼 칸 아래 짧은 글자를 고른다 — 날짜·작성자는 두지 않는다
 *   2) 결재첨부 진행상태 칸이 호출한다
 *   3) 작성·전송은 끝나면 「완료」, 결재가 끝나면 결재자명, 반려면 「반려」
 */
export function attachStepperCaption(
  // 스테퍼 한 칸
  step: AttachStepperStep,
  // 결재자 표시명 — 결재 완료 칸에만 쓴다
  approverNm?: string | null,
): string {
  if (step.tone === "rejected") return "반려";
  if (step.key === "approve") {
    return step.tone === "done" ? (approverNm ?? "").trim() : "";
  }
  if (step.tone === "done") return "완료";
  return "";
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 스테퍼 칸 색 — 완료 파랑 · 대기(현재) 노랑 · 반려 빨강 · 아직 아님 회색
 *   2) 결재첨부 진행상태 점이 호출한다
 *   3) 전송된 문서의 결재 칸은 노랑이다. 파랑으로 칠하면 끝난 것처럼 보인다
 */
export const attachStepperToneClass = stepperToneClass;

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 첨부를 더하거나 지울 수 있는 상태인지 본다
 *   2) 업로드·삭제 버튼 활성 판정이 호출한다
 *   3) 전송(REQ)·결재완료(APV)는 기록 잠금이다 — 전송취소 후 고쳐야 한다
 */
export function canEditAttach(
  // 문서 상태 WRK/REQ/APV/RJT
  status?: string | null
): boolean {
  const st = status === DOC_STATUS.TMP || !status ? DOC_STATUS.WRK : status;
  return st === DOC_STATUS.WRK || st === DOC_STATUS.RJT;
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 비고를 고칠 수 있는 상태인지 본다
 *   2) 비고 입력·저장 버튼 활성 판정이 호출한다
 *   3) 첨부와 달리 결재 완료(APV) 직전까지 열어 둔다 — 기록 본문이 아니라 메모다
 */
export function canEditRemark(
  // 문서 상태 WRK/REQ/APV/RJT
  status?: string | null
): boolean {
  const st = status === DOC_STATUS.TMP || !status ? DOC_STATUS.WRK : status;
  return st !== DOC_STATUS.APV;
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 전송(상신)할 수 있는 상태인지 본다
 *   2) 전송 버튼 활성 판정이 호출한다
 *   3) 전송대기(작성중·반려)만 전송할 수 있다. 서버 SP 가 같은 기준으로 다시 막는다
 */
export function canSend(
  // 문서 상태 WRK/REQ/APV/RJT
  status?: string | null
): boolean {
  const st = status === DOC_STATUS.TMP || !status ? DOC_STATUS.WRK : status;
  return st === DOC_STATUS.WRK || st === DOC_STATUS.RJT;
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 전송취소(상신취소)할 수 있는 상태인지 본다
 *   2) 전송취소 버튼 활성 판정이 호출한다
 *   3) 승인요청(REQ)만 가능하다. 승인이 들어가면 SP 가 막는다
 */
export function canCancelSend(
  // 문서 상태 WRK/REQ/APV/RJT
  status?: string | null
): boolean {
  return status === DOC_STATUS.REQ;
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 좌측 목록 컬럼 — 기준일·문서번호·양식명·상태 배지·첨부 수
 *   2) 화면 마운트 때 한 번 만든다
 *   3) 라벨 칸(statusNm)은 화면이 공통코드로 채워 넣는다. 첨부 수는 사용자 첨부만
 */
export function buildAttachListColumns(
  // 상태코드 → 라벨 — DOC_STATUS 공통코드 맵. 화면이 넘긴다
  statusNm: Record<string, string>,
): GridColumn<AttachListRow>[] {
  return [
    { field: "baseDt", header: "기준일", width: 100 },
    { field: "docNo", header: "문서번호", width: 140 },
    { field: "tmplNm", header: "양식", width: 160 },
    // 식별 제목 — 언제·무엇을 썼는지. 우측 h2 는 양식명이다
    { field: "title", header: "제목", width: 160 },
    {
      // 결재상태 — 색 배지. 업무 상태가 정하고 사용자가 바꾸지 않는다
      field: "status",
      header: "결재상태",
      width: 96,
      type: "code",
      editable: false,
      codeMap: statusNm,
      badge: DOC_STATUS_BADGE,
    },
    { field: "fileCnt", header: "첨부", width: 60, align: "right" },
  ];
}
