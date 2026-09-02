/**
 * documentApi — 문서함·결재·첨부 API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-21
 * 코멘트:
 *   1) DB형·HWP형 공통 문서 목록·상세·결재·파일 요청을 /api/v1/docs/documents에 연결한다
 *   2) 파일 업로드·다운로드는 httpFile(120초)을 사용하고, 나머지는 일반 http를 사용한다
 *   3) 삭제는 OPS_DELETE 순서대로 validate-delete와 delete를 분리한다
 *
 * PIPELINE[HF82] API 레이어
 * PIPELINE[HF3] 연관 모듈
 */
// 역할 — 일반 CRUD·파일 전송 Axios
import { http, httpFile } from "./http";
// 역할 — 공통 응답 타입
import type { CommonResponse } from "@/types/common";
// 역할 — SP Map snake_case → camelCase (그리드 field 공백 방지)
import { camelizeRow, camelizeRows } from "@/lib/camelKeys";

/** 문서 목록 행 */
export interface DocumentListRow {
  docIdx: number;
  tmplCd: string;
  tmplNm: string;
  docKind: "HWP" | "HTML";
  docNo: string;
  baseDt: string;
  title?: string | null;
  status: string;
  writerId?: string | null;
  writerNm?: string | null;
  verNo: number;
  fileCnt: number;
  openCaCnt: number;
}

/** 결재 단계 */
export interface DocumentApprovalRow {
  idx: number;
  stepNo: number;
  roleCd: "WRITE" | "REVIEW" | "APPROVE";
  approverId?: string | null;
  approverNm?: string | null;
  resultCd: "W" | "A" | "R";
  opinion?: string | null;
  actDt?: string | null;
}

/** 첨부 파일 — 서버 물리 경로는 API가 주지 않는다 */
export interface DocumentFileRow {
  idx: number;
  docIdx: number;
  fileKind: "HWP_SRC" | "PDF" | "ATTACH" | "PHOTO";
  fileNm: string;
  fileSize?: number | null;
  mimeType?: string | null;
  sortNo: number;
  insId?: string | null;
  insDt?: string | null;
}

/** 문서 상세 */
export interface DocumentDetail {
  header: DocumentListRow & {
    baseDtTo?: string | null;
    apprLineCd?: string | null;
    // 상신 일시 — 결재 첨부 화면의 결재요청일
    writeDt?: string | null;
    reviewerId?: string | null;
    reviewerNm?: string | null;
    reviewDt?: string | null;
    approverId?: string | null;
    approverNm?: string | null;
    approveDt?: string | null;
    rejectReason?: string | null;
    cancelReason?: string | null;
    retentionUntil?: string | null;
    remark?: string | null;
  };
  approvals: DocumentApprovalRow[];
  files: DocumentFileRow[];
  versions: Array<{
    idx: number;
    verNo: number;
    changeReason?: string | null;
    insId?: string | null;
    insDt?: string | null;
  }>;
}

/** HWP 문서 메타 저장 입력 — 본문 HWPX는 별도 파일 API로 전송한다 */
export interface HwpDocumentSaveRequest {
  docIdx?: number;
  tmplCd: string;
  baseDt: string;
  baseDtTo?: string;
  title?: string;
}

/** HWP 문서 메타 저장 결과 — 이후 HWPX 파일 업로드에 쓸 문서 대리키 */
export interface HwpDocumentSaveResult {
  docIdx: number;
}

/** 회사 사용 템플릿 API 행 — 서버 내부 formPath는 응답에 포함하지 않는다 */
export interface DocumentTemplateRow {
  tmplCd: string;
  tmplNm: string;
  docKind: "HWP" | "HTML";
  categoryCd?: string | null;
  mngNo?: string | null;
  formUrl?: string | null;
  formFileNm?: string | null;
  /** 시스템 배포분 Y — Y면 삭제 불가, 회사 전용 N만 삭제 */
  sysYn?: string | null;
}

/**
 * 현재 로그인 회사가 사용할 수 있는 구현 템플릿 목록을 조회한다.
 * formUrl은 같은 API 서버의 인증된 HWP 원본 스트림이며 서버 물리 경로가 아니다.
 */
export async function listDocumentTemplates(): Promise<DocumentTemplateRow[]> {
  const { data } = await http.get<CommonResponse<DocumentTemplateRow[]>>(
    "/api/v1/docs/templates/list"
  );
  return data.data ?? [];
}

/**
 * HWP 템플릿 원본 URL의 바이너리를 읽는다.
 * 템플릿 목록 API가 같은 출처의 formUrl을 제공하면 편집기가 이 함수를 통해 적재한다.
 */
export async function loadHwpTemplateFile(
  // 템플릿 API가 제공한 같은 출처 URL 또는 상대 경로
  formUrl: string
): Promise<ArrayBuffer> {
  const target = new URL(formUrl, window.location.origin);
  // 다른 출처일 때(= 인증 헤더가 외부 서비스로 나갈 수 있음) 요청을 차단한다
  if (target.origin !== window.location.origin) {
    throw new Error("같은 서버에서 제공한 템플릿 원본만 열 수 있습니다.");
  }
  const { data } = await httpFile.get<ArrayBuffer>(
    `${target.pathname}${target.search}`,
    { responseType: "arraybuffer" }
  );
  return data;
}

/**
 * 표준 템플릿 HWP/HWPX 원본을 같은 form_path에 덮어쓴다.
 * 문서 인스턴스가 아니라 양식 파일 자체를 수정할 때 쓴다.
 */
export async function saveHwpTemplateForm(
  // 회사 사용 템플릿 업무키
  tmplCd: string,
  // rhwp export 또는 로컬에서 고른 HWP/HWPX
  file: File
): Promise<void> {
  const form = new FormData();
  form.append("file", file);
  await httpFile.post(`/api/v1/docs/templates/${encodeURIComponent(tmplCd)}/form`, form);
}

/** 통합 문서함 조회 */
export async function listDocuments(
  // 조회 조건 — 빈 값은 전체 조건
  params: {
    fromDt?: string;
    toDt?: string;
    tmplCd?: string;
    status?: string;
    keyword?: string;
    writerId?: string;
  }
): Promise<DocumentListRow[]> {
  const { data } = await http.get<CommonResponse<Record<string, unknown>[]>>(
    "/api/v1/docs/documents/list",
    { params }
  );
  // doc_no → docNo — MesEditableGrid field 바인딩
  return camelizeRows<DocumentListRow & Record<string, unknown>>(data.data);
}

/** 결재함 — 내 차례 대기 문서 */
export async function listApprovalInbox(params: {
  fromDt?: string;
  toDt?: string;
  keyword?: string;
}): Promise<DocumentListRow[]> {
  const { data } = await http.get<CommonResponse<Record<string, unknown>[]>>(
    "/api/v1/docs/documents/approval-inbox",
    { params }
  );
  return camelizeRows<DocumentListRow & Record<string, unknown>>(data.data);
}

/** 결재 이력 — 내가 승인·반려한 문서 */
export async function listApprovalHistory(params: {
  fromDt?: string;
  toDt?: string;
  keyword?: string;
}): Promise<DocumentListRow[]> {
  const { data } = await http.get<CommonResponse<Record<string, unknown>[]>>(
    "/api/v1/docs/documents/approval-history",
    { params }
  );
  return camelizeRows<DocumentListRow & Record<string, unknown>>(data.data);
}

/** 문서 헤더·결재·파일·버전 상세 */
export async function getDocumentDetail(
  // 문서 idx
  docIdx: number
): Promise<DocumentDetail> {
  const { data } = await http.get<CommonResponse<DocumentDetail>>(
    `/api/v1/docs/documents/${docIdx}`
  );
  const detail = data.data;
  if (!detail) return detail;
  // header·결재 행도 snake 키가 섞일 수 있어 동일 정규화
  return {
    ...detail,
    header: camelizeRow(detail.header as unknown as Record<string, unknown>),
    approvals: camelizeRows(detail.approvals as unknown as Record<string, unknown>[]),
    files: camelizeRows(detail.files as unknown as Record<string, unknown>[]),
    versions: camelizeRows(detail.versions as unknown as Record<string, unknown>[]),
  } as unknown as DocumentDetail;
}

/** HWP 문서 헤더 저장 — 신규면 문서번호를 만들고 기존이면 임시·반려 문서를 갱신한다 */
export async function saveHwpDocument(
  // 템플릿 코드·기준일·제목 — 작성자·회사는 JWT로 서버가 강제한다
  body: HwpDocumentSaveRequest
): Promise<HwpDocumentSaveResult> {
  const { data } = await http.put<CommonResponse<HwpDocumentSaveResult>>(
    "/api/v1/docs/documents/hwp/save",
    body
  );
  return data.data;
}

/** 결재 상태 전이 */
export async function processDocumentApproval(
  // REQUEST/REVIEW/APPROVE/REJECT 처리 계약
  body: { docIdx: number; actionCd: string; opinion?: string }
): Promise<void> {
  await http.put("/api/v1/docs/documents/approval", body);
}

/** 파일 업로드 — HWPX·PDF·사진·일반첨부 */
export async function uploadDocumentFile(
  // 연결 문서 idx
  docIdx: number,
  // 파일 분류
  fileKind: DocumentFileRow["fileKind"],
  // 브라우저 파일
  file: File
): Promise<DocumentFileRow> {
  const form = new FormData();
  form.append("fileKind", fileKind);
  form.append("file", file);
  const { data } = await httpFile.post<CommonResponse<DocumentFileRow>>(
    `/api/v1/docs/documents/${docIdx}/files`,
    form
  );
  return data.data;
}

/** 첨부 다운로드 URL — httpFile 인터셉터가 인증 헤더를 처리하도록 API 함수가 아닌 URL만 쓰지 않는다 */
export async function downloadDocumentFile(
  // 파일 idx
  fileIdx: number
): Promise<Blob> {
  const { data } = await httpFile.get(`/api/v1/docs/documents/files/${fileIdx}/download`, {
    responseType: "blob",
  });
  return data as Blob;
}

/** 첨부 삭제 — 결재 진행·완료 문서는 SP가 막는다. HTTP DELETE 금지 → POST */
export async function deleteDocumentFile(
  // 파일 idx
  fileIdx: number
): Promise<void> {
  await http.post(`/api/v1/docs/documents/files/${fileIdx}/delete`);
}

/** 문서 비고 저장 — 결재 첨부 화면. 결재 완료 전까지만 */
export async function saveDocumentRemark(
  // 문서 idx
  docIdx: number,
  // 비고 본문 — 빈 문자열이면 지운다
  remark: string
): Promise<void> {
  await http.put(`/api/v1/docs/documents/${docIdx}/remark`, { remark });
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-02
 * 코멘트:
 *   1) 작성 목록 제목을 저장한다 — tbl_document.title
 *   2) 작성 화면 좌측 저장이 호출한다. 전송·결재완료여도 고친다
 *   3) 결재 첨부 remark 와 다르다
 */
export async function saveDocumentTitle(
  // 문서 idx
  docIdx: number,
  // 제목 — 빈 문자열이면 지운다
  title: string
): Promise<void> {
  await http.put(`/api/v1/docs/documents/${docIdx}/title`, { title });
}

/**
 * 서버 rhwp CLI로 문서 HWP_SRC를 PDF로 변환·보관한다.
 * 변환·저장이 길어질 수 있어 httpFile(VITE_API_TIMEOUT_FILE)만 사용한다.
 */
export async function exportDocumentPdf(
  // PDF로 내보낼 문서 대리키 — HWPX 본문이 먼저 있어야 한다
  docIdx: number
): Promise<DocumentFileRow> {
  const { data } = await httpFile.post<CommonResponse<DocumentFileRow>>(
    `/api/v1/docs/documents/${docIdx}/export-pdf`
  );
  return data.data;
}

/** HWP 문서 삭제 사전 검증 */
export async function validateDeleteDocument(
  // 객체 배열 — 스칼라 배열 금지
  keys: { docIdx: number }[]
): Promise<void> {
  await http.post("/api/v1/docs/documents/validate-delete", keys);
}

/** HWP 문서 삭제 */
export async function deleteDocument(
  // 객체 배열 — validate-delete와 동일
  keys: { docIdx: number }[]
): Promise<void> {
  await http.post("/api/v1/docs/documents/delete", keys);
}

/**
 * 로그인 사용자 서명 이미지 바이너리.
 * rhwp에 insertImage가 없으면 호출부가 클립보드 복사·붙여넣기 안내로 대체한다.
 * ClipboardItem은 image/* MIME이 필요하므로 octet-stream이면 png로 감싼다.
 */
export async function fetchMySignImage(): Promise<Blob> {
  const { data } = await httpFile.get("/api/v1/sys/users/me/sign", {
    // 바이너리 — 오류 JSON도 Blob으로 오므로 http 인터셉터가 text 파싱한다
    responseType: "blob",
  });
  const blob = data as Blob;
  // MIME이 image/*가 아닐 때(= 서버 octet-stream) 클립보드 쓰기용으로 png 타입을 부여
  if (!blob.type || !blob.type.startsWith("image/")) {
    return new Blob([blob], { type: "image/png" });
  }
  return blob;
}
