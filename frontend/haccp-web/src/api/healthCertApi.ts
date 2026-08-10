/**
 * healthCertApi — 건강진단관리기록부 API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 목록·저장·삭제 검증·삭제·첨부 업로드 요청만 담당한다
 *   2) 삭제는 POST validate-delete → 사용자 확인 → POST delete 순서를 화면이 지킨다
 *   3) 회사코드는 요청 본문에 넣지 않는다 — JWT가 로그인 회사 테넌트를 고정한다
 *
 * PIPELINE[HF124] 건강진단 API
 * PIPELINE[HF3, HF125] 연관 모듈
 */
// 역할 — 일반 CRUD 타임아웃 Axios 인스턴스
import { http, httpFile } from "./http";
// 역할 — 서버 공통 성공 응답 타입
import type { CommonResponse } from "@/types/common";

/** 건강진단 행 — 그리드 필드와 1:1 camelCase */
export type HealthCertRow = Record<string, string | number | null | undefined>;

/** 목록 조회 조건 — 미입력 조건은 서버가 전체로 처리한다 */
export interface HealthCertListParams {
  personNm?: string;
  useYn?: string;
}

/** person_nm → personNm — SP to_jsonb 잔여 snake_case도 그리드 계약에 맞춘다 */
function toCamelKey(key: string): string {
  if (!key.includes("_")) return key;
  return key.replace(/_([a-z])/g, (_, ch: string) => ch.toUpperCase());
}

/** 목록 행 키를 camelCase로 정규화한다. 이미 camelCase면 그대로 둔다. */
function normalizeRow(row: HealthCertRow): HealthCertRow {
  const next: HealthCertRow = {};
  for (const [key, value] of Object.entries(row ?? {})) {
    next[toCamelKey(key)] = value;
  }
  return next;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 건강진단 목록을 성명·사용여부로 조회한다
 *   2) 화면 최초 진입·조회 버튼·저장·삭제·첨부 후 재조회에서 호출한다
 *   3) 성공하면 camelCase 행 배열을, data가 비었으면 빈 배열을 반환한다
 */
export async function listHealthCertRows(
  // 성명·사용여부 — 빈 값은 생략 가능
  params: HealthCertListParams
): Promise<HealthCertRow[]> {
  const { data } = await http.get<CommonResponse<HealthCertRow[]>>("/api/v1/hyg/health-cert/list", {
    params,
  });
  return (data.data ?? []).map(normalizeRow);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 변경된 건강진단 행 배열을 일괄 저장한다
 *   2) 신규·수정 모두 같은 save API가 행의 idx 존재 여부로 구분한다
 *   3) 성공 시 반환값 없이 끝나며 화면이 목록을 다시 조회한다
 */
export async function saveHealthCertRows(
  // 저장 행 배열 — personNm·examDt 등 camelCase
  rows: HealthCertRow[]
): Promise<void> {
  await http.put("/api/v1/hyg/health-cert/save", rows);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 선택 행 삭제 가능 여부만 검사한다
 *   2) 삭제 확인창을 열기 직전에 호출한다
 *   3) 서버가 차단하면 예외를 던지고 화면은 삭제 요청을 보내지 않는다
 */
export async function validateDeleteHealthCertRows(
  // 업무키 객체 배열 — 단건 삭제여도 [{ idx }]
  keys: Array<{ idx: number }>
): Promise<void> {
  await http.post("/api/v1/hyg/health-cert/validate-delete", keys);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 검증·사용자 확인을 모두 통과한 건강진단 키 목록을 삭제한다
 *   2) validate-delete와 같은 객체 배열을 전달한다
 *   3) 성공 시 반환값 없이 끝나며 화면이 목록을 다시 조회한다
 */
export async function deleteHealthCertRows(
  // 삭제 업무키 객체 배열 — 스칼라 배열은 허용하지 않는다
  keys: Array<{ idx: number }>
): Promise<void> {
  await http.post("/api/v1/hyg/health-cert/delete", keys);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 저장된 건강진단 행에 첨부 파일을 업로드한다
 *   2) 그리드 활성 행의 첨부 버튼에서 호출한다
 *   3) multipart는 httpFile 타임아웃을 쓰고 fileNm·filePath를 반환한다
 */
export async function uploadHealthCertFile(
  // 첨부 대상 대리키
  idx: number,
  // 선택한 파일
  file: File
): Promise<{ idx: number; filePath: string; fileNm: string }> {
  const form = new FormData();
  // 첨부 파일 — 서버 MultipartFile name=file
  form.append("file", file);
  const { data } = await httpFile.post<
    CommonResponse<{ idx: number; filePath: string; fileNm: string }>
  >(`/api/v1/hyg/health-cert/${idx}/file`, form);
  return data.data ?? { idx, filePath: "", fileNm: file.name };
}
