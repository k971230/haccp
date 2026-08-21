/**
 * hwpTemplateApi — 사용양식관리 API (SCREEN_PATH, 삭제는 company-templates).
 *
 * 개발자: 박승우
 * 일자: 2026-08-21
 * 코멘트:
 *   1) 목록·저장·파일이력·불러오기/초기화만 이 파일이 담당한다
 *   2) 회사코드·작업자는 요청에 넣지 않고 서버 JWT 테넌트로 고정된다
 *   3) 삭제는 법적서류 화면도 같은 URL을 쓰므로 경로를 바꾸지 않는다 — 그 메뉴 분할 때 이전
 *
 * PIPELINE[HF123] 사용양식관리 API
 */
// 역할 — 일반 CRUD Axios (10s)
import { http } from "../http";
// 역할 — SCREEN_PATH 기준 API 베이스
import { apiOf } from "@/shell/tabRoute";
// 역할 — 서버 공통 응답 형식
import type { CommonResponse } from "@/types/common";

/** 화면 기본 경로 — SCREEN_PATH /docs/hwp/hwp-template-management */
const BASE = apiOf("hwp-template-management");

/** 사용양식관리 목록 1행 — 구분·현재 파일·버튼 활성 판정 값을 서버가 함께 내린다 */
export interface HwpTemplateRow {
  tmplCd: string;
  tmplNm: string;
  // 구분 — sys: 시스템 제공, usr: 자사양식. 표시 전용이며 저장·수정 대상이 아니다
  sysYn: "sys" | "usr" | string;
  docKind?: string | null;
  categoryCd?: string | null;
  mngNo?: string | null;
  // 현재 적용 파일 상대경로 — 서버 내부 값. 화면은 파일명만 쓴다
  formPath?: string | null;
  // 현재 적용 파일명 — 없으면 파일 미등록
  formFileNm?: string | null;
  useYn: "Y" | "N" | string;
  // 기본 제공 파일 idx — 없으면 초기화 불가
  defaultFileIdx?: number | null;
  // 현재 적용 파일 idx
  currentFileIdx?: number | null;
  // 살아있는 파일 이력 건수 — 불러오기 활성 판정
  fileHistCnt?: number | null;
}

/** 양식 파일 이력 1행 — 불러오기 목록 */
export interface HwpTemplateFile {
  idx: number;
  fileSeq: number;
  fileNm: string;
  fileSize?: number | null;
  // 출처 — sys: 기본 제공본, usr: 회사 업로드본
  srcTy: "sys" | "usr" | string;
  // 현재 적용 문구 — SP CASE. 적용 중이면 '현재적용', 아니면 빈 문자열
  currentYn: string;
  // 기본 제공 여부 — SP CASE. 그리드 양식구분은 src-ty 를 쓰고 이 값은 초기화 판정용
  defaultYn: string;
  insId?: string | null;
  insDt?: string | null;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) 사용양식관리 목록(hwp 양식·미사용 포함)을 조회한다
 *   2) 화면 진입·조회·저장/삭제/파일작업 후 재조회에서 호출한다
 *   3) 검색어가 비면 전체 목록 — 구분·현재 파일명·이력건수까지 한 번에 받는다
 */
export async function listHwpTemplates(params?: {
  // 양식코드 검색어 — 공백이면 전체
  tmplCd?: string;
  // 양식명 검색어 — 공백이면 전체
  tmplNm?: string;
}): Promise<HwpTemplateRow[]> {
  const { data } = await http.get<CommonResponse<HwpTemplateRow[]>>(
    `${BASE}/list`,
    { params: { tmplCd: params?.tmplCd ?? "", tmplNm: params?.tmplNm ?? "" } },
  );
  return data.data ?? [];
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) 사용양식 1건(양식코드·양식명·사용유무)을 저장한다
 *   2) 사용양식관리 저장 버튼이 신규·수정 구분 없이 호출한다
 *   3) 구분(sysYn)은 보내지 않는다 — 신규는 서버가 자사양식으로 강제한다
 */
export async function saveHwpTemplate(row: {
  tmplCd: string;
  tmplNm: string;
  useYn: string;
}): Promise<void> {
  await http.put(`${BASE}/save`, row);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) 선택 양식의 파일 이력을 조회한다
 *   2) 「불러오기」 팝업을 열 때 호출한다
 *   3) 최근 업로드가 먼저 오고 삭제된 이력은 제외된다
 */
export async function listHwpTemplateFiles(tmplCd: string): Promise<HwpTemplateFile[]> {
  const { data } = await http.get<CommonResponse<HwpTemplateFile[]>>(
    `${BASE}/files`,
    { params: { tmplCd } },
  );
  return data.data ?? [];
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) 과거 이력 파일을 현재 적용본으로 바꾸거나(불러오기) 기본 제공본으로 되돌린다(초기화)
 *   2) 「불러오기」 선택 확정·「초기화」 버튼이 호출한다
 *   3) fileIdx 를 넘기지 않으면(= 초기화) 서버가 기본 제공본을 쓴다
 */
export async function applyHwpTemplateFile(body: {
  tmplCd: string;
  // 적용할 이력 idx — 생략하면 초기화
  fileIdx?: number | null;
}): Promise<void> {
  await http.post(`${BASE}/apply-file`, body);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) 회사 사용양식 삭제 키만 먼저 검사한다
 *   2) 사용양식관리 삭제 확인창 직전에 호출한다
 *   3) URL은 법적서류와 공유하는 company-templates 경로를 유지한다
 */
export async function validateDeleteCompanyTemplates(
  // 삭제 키 객체 배열 — 단건도 [{ tmplCd }]
  keys: { tmplCd: string }[],
): Promise<void> {
  await http.post("/api/v1/bas/company-templates/validate-delete", keys);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-14
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
