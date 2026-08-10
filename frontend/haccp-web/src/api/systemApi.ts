/**
 * systemApi — HACCP 시스템 관리·이력 화면 조회 API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) 9개 시스템 화면이 같은 안전한 목록 조회 계약을 사용하도록 HTTP 세부사항을 한 곳에 둔다
 *   2) 회사코드는 호출부에서 전달하지 않으며 서버가 JWT의 로그인 테넌트로 범위를 고정한다
 *   3) Map 조회 키는 camelizeRows로 snake_case→camelCase 정규화해 그리드 field와 맞춘다
 *
 * PIPELINE[HF92] 시스템 관리 API
 * PIPELINE[HF3, HB93, HF121] 연관 모듈
 */
// 역할 — 일반·파일 Axios 인스턴스
import { http, httpFile } from "./http";
// 역할 — 공통 성공 응답 형식
import type { CommonResponse } from "@/types/common";
// 역할 — MyBatis Map snake_case → 그리드 camelCase 정규화
import { camelizeRows } from "@/lib/camelKeys";

/** 역할 기반 시스템 관리 화면코드 — DB tbl_screen 값과 1:1 */
export type SystemScreenCode =
  | "company-management"
  | "user-management"
  | "department-management"
  | "role-management"
  | "menu-management"
  | "common-code-management"
  | "login-history"
  | "screen-usage-statistics"
  | "audit-log";

/** 화면 유형마다 컬럼이 다른 조회 결과의 공통 행 */
export type SystemRow = Record<string, string | number | boolean | null>;

/** 이력·통계 기간과 일반 관리 검색어 */
export interface SystemListParams {
  keyword: string;
  fromDt?: string;
  toDt?: string;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) 지정한 시스템 화면의 현재 테넌트 목록을 조회한다
 *   2) 최초 진입과 사용자가 검색어를 적용해 조회할 때 호출한다
 *   3) 성공 시 camelCase 행 배열을 반환하고, Map 키가 co_nm 등이면 coNm으로 맞춘다
 */
export async function listSystemRows(
  // 화면 식별자 — 서버 허용 목록과 동일한 역할 기반 kebab-case 값
  screenCode: SystemScreenCode,
  // 화면별 부분검색어 — 빈 문자열이면 필터 없이 조회
  params: SystemListParams
): Promise<SystemRow[]> {
  const { data } = await http.get<CommonResponse<SystemRow[]>>(`/api/v1/sys/${screenCode}/list`, {
    params,
  });
  // SystemMapper resultType=map — MyBatis camel 미적용 시 snake_case 잔여를 그리드 field에 맞춤
  return camelizeRows<SystemRow>(data.data as unknown as Record<string, unknown>[]);
}

/** 시스템 설정 저장 — 회사코드·감사 주체는 서버 JWT로만 채운다 */
export async function saveSystemRows(screenCode: SystemScreenCode, rows: SystemRow[]): Promise<void> {
  await http.put(`/api/v1/sys/${screenCode}/save`, rows);
}

/** 삭제 전 참조 검증 — 단건도 idx 객체 배열로 전달한다 */
export async function validateDeleteSystemRows(screenCode: SystemScreenCode, keys: Array<{ idx: number }>): Promise<void> {
  await http.post(`/api/v1/sys/${screenCode}/validate-delete`, keys);
}

/** 검증·확인 완료 행 삭제 — HTTP DELETE 대신 POST를 사용한다 */
export async function deleteSystemRows(screenCode: SystemScreenCode, keys: Array<{ idx: number }>): Promise<void> {
  await http.post(`/api/v1/sys/${screenCode}/delete`, keys);
}

/**
 * 지정 사용자 서명 이미지 업로드 — 사용자 관리·본인 등록.
 * multipart는 httpFile 타임아웃을 쓴다.
 */
export async function uploadUserSign(
  // 대상 사용자 ID — 본인이면 me와 동일 효과
  userId: string,
  // 서명 이미지 파일
  file: File
): Promise<string> {
  const form = new FormData();
  // 서명 이미지 파일 — 서버 MultipartFile name=file
  form.append("file", file);
  const { data } = await httpFile.post<CommonResponse<{ signPath: string }>>(
    `/api/v1/sys/users/${encodeURIComponent(userId)}/sign`,
    form
  );
  return data.data?.signPath ?? "";
}

/**
 * 로그인 사용자 서명 상대경로 조회 — 냉장 일지 행 서명 적용용.
 * 미등록이면 빈 문자열.
 */
export async function fetchMySignPath(): Promise<string> {
  const { data } = await http.get<CommonResponse<{ signPath?: string }>>(
    "/api/v1/sys/users/me/sign-path"
  );
  return (data.data?.signPath ?? "").trim();
}

/**
 * 로그인 사용자 서명 이미지 업로드 — 문서작성 「서명 복사」 미등록 시 즉시 등록.
 * multipart는 httpFile 타임아웃을 쓴다.
 */
export async function uploadMySign(
  // 서명 이미지 파일 — png/jpg 등
  file: File
): Promise<string> {
  const form = new FormData();
  // 서명 이미지 파일 — 서버 MultipartFile name=file
  form.append("file", file);
  const { data } = await httpFile.post<CommonResponse<{ signPath: string }>>(
    "/api/v1/sys/users/me/sign",
    form
  );
  return data.data?.signPath ?? "";
}
