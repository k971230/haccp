/**
 * workflowApi — 결재선·사용양식/점검항목·작성주기 관리 API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 역할 기반 관리·내보내기이력·스마트일지매핑 고정 REST 경로만 제공하며 임의 리소스명을 받지 않는다
 *   2) 회사코드는 요청 본문에 넣지 않고 로그인 JWT의 테넌트 범위를 서버가 고정한다
 *   3) 삭제는 결재선·작성주기는 validate-delete→delete, 스마트일지매핑은 POST delete 단건을 사용한다
 *
 * PIPELINE[HF86] 워크플로 관리 API
 * PIPELINE[HF3, HF87, HF88, HF89] 연관 모듈
 */
// 역할 — 일반 CRUD Axios
import { http } from "./http";
// 역할 — 파일 업로드(긴 타임아웃) Axios
import { httpFile } from "./http";
// 역할 — 서버 공통 응답
import type { CommonResponse } from "@/types/common";

export interface ApprovalStep {
  stepNo: number;
  roleCd: "WRITE" | "REVIEW" | "APPROVE";
  approverId?: string | null;
  deptCd?: string | null;
  posCd?: string | null;
}

export interface ApprovalLine {
  apprLineCd: string;
  apprLineNm: string;
  useYn: "Y" | "N";
  steps: ApprovalStep[];
}

export interface CompanyTemplate {
  tmplCd: string;
  tmplNm: string;
  // 문서 유형 — DB: HTML 일지, HWP: rhwp 문서
  docKind?: "DB" | "HWP" | string;
  apprLineCd?: string | null;
  cycleCd?: string | null;
  retentionMonth?: number | null;
  // 사용여부 — DB Y/N, 화면 use-yn(y/n)
  useYn: "Y" | "N" | "y" | "n" | string;
  // 시스템유무 — sys/usr (레거시 Y/N)
  sysYn?: "Y" | "N" | "sys" | "usr" | string | null;
  // 기본 양식 사용여부 — Y이면 공통 양식, N이면 coFormIdx 자사 복제본
  baseUseYn?: "Y" | "N";
  // 활성 자사 양식 대리키 — 기본 양식 사용일 때 null
  coFormIdx?: number | null;
}

export interface TemplateExportHist {
  idx: number;
  packNm: string;
  docKind: string;
  remk?: string | null;
  insId?: string | null;
  insDt?: string | null;
  payload?: Record<string, unknown> | null;
  fileRef?: string | null;
}

export interface CompanyCheckItem {
  tmplCd: string;
  itemCd: string;
  grpNm?: string | null;
  itemNm: string;
  itemNmOvr?: string | null;
  sortNo?: number | null;
  useYn: "Y" | "N";
}

export interface CompanyForm {
  idx: number;
  srcTmplCd: string;
  formNm: string;
  docKind: string;
  scrnCd?: string | null;
  formPath?: string | null;
  verNo: number;
  formTitle?: string | null;
  limitRmk?: string | null;
  cycleRmk?: string | null;
  methodRmk?: string | null;
  improvementRmk?: string | null;
  useYn: "Y" | "N";
  activeYn: "Y" | "N";
}

export interface CompanyFormItem {
  idx?: number;
  coFormIdx: number;
  itemCd: string;
  grpCd?: string | null;
  grpNm?: string | null;
  itemNm: string;
  inputType: string;
  unitNm?: string | null;
  methodNm?: string | null;
  cycleNm?: string | null;
  sortNo: number;
  useYn: "Y" | "N";
}

export interface ScheduleRule {
  idx?: number;
  tmplCd: string;
  tmplNm?: string;
  // 주기 — D일 W주 M월 Y연
  cycleCd: "D" | "W" | "M" | "Y" | string;
  weekDays?: string | null;
  monthDay?: number | null;
  monthNo?: number | null;
  // 기준일 yyyyMMdd
  baseDt?: string | null;
  // 마감시각 HHMM
  dueTime?: string | null;
  // 담당부서·담당자명 — 텍스트
  deptCd?: string | null;
  userId?: string | null;
  userNm?: string | null;
  useYn: "Y" | "N" | "y" | "n" | string;
  insId?: string | null;
  insDt?: string | null;
  updId?: string | null;
  updDt?: string | null;
}

export async function listApprovalLines(): Promise<ApprovalLine[]> {
  const { data } = await http.get<CommonResponse<ApprovalLine[]>>("/api/v1/bas/approval-lines/list");
  return data.data ?? [];
}

export async function saveApprovalLine(row: ApprovalLine): Promise<void> {
  await http.put("/api/v1/bas/approval-lines/save", row);
}

export async function validateDeleteApprovalLines(keys: { apprLineCd: string }[]): Promise<void> {
  await http.post("/api/v1/bas/approval-lines/validate-delete", keys);
}

export async function deleteApprovalLines(keys: { apprLineCd: string }[]): Promise<void> {
  await http.post("/api/v1/bas/approval-lines/delete", keys);
}

export async function listCompanyTemplates(): Promise<CompanyTemplate[]> {
  const { data } = await http.get<CommonResponse<CompanyTemplate[]>>("/api/v1/bas/company-templates/list");
  return data.data ?? [];
}

export async function saveCompanyTemplate(row: CompanyTemplate): Promise<void> {
  await http.put("/api/v1/bas/company-templates/save", row);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) 법적서류 업로드 유형(회사 전용 신규 또는 기존 LAW 명칭)을 저장한다
 *   2) legal-document-upload 좌측 그리드 저장이 호출한다
 *   3) 성공 시 void — 화면이 목록을 재조회한다
 */
export async function saveLegalType(row: {
  // 유형 코드 — 신규일 때만 입력, 저장 후 잠금
  tmplCd: string;
  // 표시 명칭
  tmplNm: string;
}): Promise<void> {
  await http.put("/api/v1/bas/legal-types/save", row);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) 회사 사용양식(sys_yn=N) 삭제 키만 먼저 검사한다
 *   2) 사용양식관리 삭제 확인창 직전에 호출한다
 *   3) 차단이면 예외 — 화면은 delete를 보내지 않는다
 */
export async function validateDeleteCompanyTemplates(
  // 삭제 키 객체 배열 — 단건도 [{ tmplCd }]
  keys: { tmplCd: string }[],
): Promise<void> {
  await http.post("/api/v1/bas/company-templates/validate-delete", keys);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) 검증·확인을 통과한 회사 사용양식을 삭제한다
 *   2) validate-delete와 같은 [{ tmplCd }] 배열을 전달한다
 *   3) 성공 시 void — 화면이 목록을 재조회한다
 */
export async function deleteCompanyTemplates(
  keys: { tmplCd: string }[],
): Promise<void> {
  await http.post("/api/v1/bas/company-templates/delete", keys);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) 자사 HWP를 템플릿 볼륨에 올리고 sys_yn=N 회사 양식으로 등록한다
 *   2) 사용양식관리 신규 업로드가 httpFile로 호출한다
 *   3) 성공 시 tmplCd·formFileNm — 파일명은 업로드 원본(번호 접두 제거)을 서버가 유지한다
 */
export async function createCompanyTemplateCustom(params: {
  tmplCd: string;
  tmplNm?: string;
  file: File;
}): Promise<{ tmplCd: string; formPath?: string; formFileNm?: string; sysYn?: string }> {
  const form = new FormData();
  form.append("tmplCd", params.tmplCd);
  if (params.tmplNm) form.append("tmplNm", params.tmplNm);
  form.append("file", params.file);
  // 파일 업로드 — httpFile(긴 타임아웃)
  const { data } = await httpFile.post<CommonResponse<{
    tmplCd: string;
    formPath?: string;
    formFileNm?: string;
    sysYn?: string;
  }>>("/api/v1/bas/company-templates/create-custom", form);
  return data.data ?? { tmplCd: params.tmplCd };
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) 고정 양식(tmplCd)의 회사 점검항목 목록을 조회한다
 *   2) 문서별 admin·점검항목 화면 진입·재조회에서 호출한다
 *   3) tmplCd가 비면 요청을 보내지 않고 업무 문구로 막는다(필수 쿼리 누락 500 방지)
 */
export async function listCompanyCheckItems(
  // 양식 코드 — tmpl_prp-hygiene-daily / tmpl_prp-facility-check / tmpl_ccp-verify-check 등
  tmplCd: string,
): Promise<CompanyCheckItem[]> {
  // 공백·미전달일 때(= 선택 전) 서버 MissingServletRequestParameterException 방지
  const code = String(tmplCd ?? "").trim();
  if (!code) throw new Error("양식 코드를 선택하세요.");
  const { data } = await http.get<CommonResponse<CompanyCheckItem[]>>(
    "/api/v1/bas/company-check-items/list",
    { params: { tmplCd: code } },
  );
  return data.data ?? [];
}

export async function saveCompanyCheckItem(row: CompanyCheckItem): Promise<void> {
  await http.put("/api/v1/bas/company-check-items/save", row);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) 회사 전용(CUST*) 점검항목 삭제 키만 먼저 검사한다
 *   2) 문서별 admin 삭제 확인창 직전에 호출한다
 *   3) 차단이면 예외 — 화면은 delete를 보내지 않는다
 */
export async function validateDeleteCompanyCheckItems(
  // 삭제 키 객체 배열 — 단건도 [{ tmplCd, itemCd }]
  keys: { tmplCd: string; itemCd: string }[],
): Promise<void> {
  await http.post("/api/v1/bas/company-check-items/validate-delete", keys);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) 검증·확인을 통과한 회사 전용 점검항목을 삭제한다
 *   2) validate-delete와 같은 [{ tmplCd, itemCd }] 배열을 전달한다
 *   3) 표준 항목은 서버가 차단한다
 */
export async function deleteCompanyCheckItems(
  keys: { tmplCd: string; itemCd: string }[],
): Promise<void> {
  await http.post("/api/v1/bas/company-check-items/delete", keys);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) 기준 양식에서 파생된 자사 양식 목록을 조회한다
 *   2) 사용양식·복제 UI에서 tmplCd별로 호출한다
 *   3) tmplCd가 비면 요청을 보내지 않는다
 */
export async function listCompanyForms(
  // 기준 양식 코드
  tmplCd: string,
): Promise<CompanyForm[]> {
  const code = String(tmplCd ?? "").trim();
  if (!code) throw new Error("양식 코드를 선택하세요.");
  const { data } = await http.get<CommonResponse<CompanyForm[]>>(
    "/api/v1/bas/company-forms/list",
    { params: { tmplCd: code } },
  );
  return data.data ?? [];
}

export async function listCompanyFormItems(coFormIdx: number): Promise<CompanyFormItem[]> {
  const { data } = await http.get<CommonResponse<CompanyFormItem[]>>("/api/v1/bas/company-form-items/list", { params: { coFormIdx } });
  return data.data ?? [];
}

export async function cloneCompanyForm(row: { tmplCd: string; formNm?: string }): Promise<void> {
  await http.put("/api/v1/bas/company-forms/clone", row);
}

export async function saveCompanyFormItem(row: CompanyFormItem): Promise<void> {
  await http.put("/api/v1/bas/company-form-items/save", row);
}

export async function activateCompanyForm(row: { tmplCd: string; coFormIdx?: number | null }): Promise<void> {
  await http.put("/api/v1/bas/company-forms/activate", row);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 양식 설정 내보내기 이력 목록을 조회한다
 *   2) 불러오기 팝업이 docKind로 좁힐 때 호출한다
 *   3) payload 본문은 목록 응답에 포함되지 않는다
 */
export async function listTemplateExportHist(params?: { docKind?: string }): Promise<TemplateExportHist[]> {
  const { data } = await http.get<CommonResponse<TemplateExportHist[]>>(
    "/api/v1/bas/template-export-hist/list",
    { params },
  );
  return data.data ?? [];
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 내보내기 이력 단건과 payload를 조회한다
 *   2) 불러오기 직전 확인이 필요할 때 호출한다
 *   3) 없는 idx는 서버 업무 예외로 전달된다
 */
export async function getTemplateExportHist(idx: number): Promise<TemplateExportHist> {
  const { data } = await http.get<CommonResponse<TemplateExportHist>>(`/api/v1/bas/template-export-hist/${idx}`);
  return data.data as TemplateExportHist;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 현재 회사 양식·점검항목 오버라이드를 이력 패키지로 내보낸다
 *   2) DB/HWP 설정 화면 내보내기 버튼이 호출한다
 *   3) 생성된 이력 idx를 반환한다
 */
export async function exportTemplateHist(body: {
  packNm: string;
  docKind: string;
  remk?: string;
}): Promise<number> {
  const { data } = await http.put<CommonResponse<number>>("/api/v1/bas/template-export-hist/export", body);
  return data.data ?? 0;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 서버 표준 또는 이력으로 오버라이드를 All-or-Nothing 복원한다
 *   2) 불러오기 팝업에서 SERVER 또는 histIdx 선택 후 호출한다
 *   3) docKind는 SERVER 복원 범위를 좁힐 때 선택 전달한다
 */
export async function importTemplateHist(body: {
  histIdx?: number;
  source?: "SERVER";
  docKind?: string;
}): Promise<void> {
  await http.put("/api/v1/bas/template-export-hist/import", body);
}

export async function listScheduleRules(): Promise<ScheduleRule[]> {
  const { data } = await http.get<CommonResponse<ScheduleRule[]>>("/api/v1/bas/schedule-rules/list");
  return data.data ?? [];
}

export async function saveScheduleRule(row: ScheduleRule): Promise<void> {
  await http.put("/api/v1/bas/schedule-rules/save", row);
}

export async function validateDeleteScheduleRules(keys: { idx: number }[]): Promise<void> {
  await http.post("/api/v1/bas/schedule-rules/validate-delete", keys);
}

export async function deleteScheduleRules(keys: { idx: number }[]): Promise<void> {
  await http.post("/api/v1/bas/schedule-rules/delete", keys);
}
