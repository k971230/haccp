/**
 * masterApi — HACCP 기준정보 공통 API (역할 기반 화면 식별자 10종).
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 고정된 10개 기준정보 유형의 목록·저장·삭제 검증·삭제 요청만 담당한다
 *   2) 삭제는 POST validate-delete → 사용자 확인 → POST delete 순서를 화면이 지킨다
 *   3) 회사코드는 요청 본문에 넣지 않는다 — JWT가 로그인 회사 테넌트를 고정한다
 *
 * PIPELINE[HF84] 기준정보 API
 * PIPELINE[HF3, HF85] 연관 모듈
 */
// 역할 — 일반·파일 타임아웃 Axios 인스턴스
import { http, httpFile } from "./http";
// 역할 — 서버 공통 성공 응답 타입
import type { CommonResponse } from "@/types/common";

/** 서버가 허용하는 기준정보 리소스 — 화면 설정의 type과 1:1 대응 */
export type MasterType =
  | "product"
  | "material"
  | "partner"
  | "storage"
  | "equipment"
  | "measuring-device"
  | "pest-device"
  | "vehicle"
  | "work-area"
  | "ccp-limit";

/** 기준정보 행 — 유형별 고정 필드 설정이 키·값을 해석한다 */
export type MasterRow = Record<string, string | number | null | undefined>;

/** 목록 조회 조건 — 미입력 조건은 서버가 전체로 처리한다 */
export interface MasterListParams {
  keyword?: string;
  useYn?: string;
}

/** storage_cd → storageCd — SP to_jsonb 잔여 snake_case도 그리드 계약에 맞춘다 */
function toCamelKey(key: string): string {
  if (!key.includes("_")) return key;
  return key.replace(/_([a-z])/g, (_, ch: string) => ch.toUpperCase());
}

/** 목록 행 키를 camelCase로 정규화한다. 이미 camelCase면 그대로 둔다. */
function normalizeMasterRow(row: MasterRow): MasterRow {
  const next: MasterRow = {};
  for (const [key, value] of Object.entries(row ?? {})) {
    next[toCamelKey(key)] = value;
  }
  return next;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 지정한 기준정보 유형의 목록을 조회한다
 *   2) 화면 최초 진입·조회 버튼·저장 및 삭제 후 재조회에서 호출한다
 *   3) 성공하면 camelCase 행 배열을, data가 비었으면 빈 배열을 반환한다
 */
export async function listMasterRows(
  // 리소스 유형 — product, storage 등 API 경로 조각
  type: MasterType,
  // 검색어·사용여부 — 빈 값은 생략 가능
  params: MasterListParams
): Promise<MasterRow[]> {
  const { data } = await http.get<CommonResponse<MasterRow[]>>(`/api/v1/bas/${type}/list`, { params });
  return (data.data ?? []).map(normalizeMasterRow);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 고정된 유형 설정으로 만든 한 건의 기준정보 행을 저장한다
 *   2) 신규·수정 모두 같은 save API가 행의 키 존재 여부로 구분한다
 *   3) 성공 시 서버가 반환한 최신 행을 돌려주되, 본문이 없으면 입력 행을 유지한다
 */
export async function saveMasterRow(
  // 리소스 유형 — API 경로와 백엔드 마스터 정의를 고정 연결
  type: MasterType,
  // 저장 행 — 화면 설정에서 허용한 필드만 담긴 camelCase 객체
  row: MasterRow
): Promise<MasterRow> {
  const { data } = await http.put<CommonResponse<MasterRow>>(`/api/v1/bas/${type}/save`, [row]);
  return data.data ?? row;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 선택 행이 다른 HACCP 기록에서 참조되는지 먼저 검사한다
 *   2) 삭제 확인창을 열기 직전에 호출해 차단 사유를 즉시 사용자에게 알린다
 *   3) 서버가 차단하면 예외를 던지고 화면은 삭제 요청을 보내지 않는다
 */
export async function validateDeleteMasterRows(
  // 리소스 유형 — API 경로와 삭제 검증 규칙을 고정 연결
  type: MasterType,
  // 업무키 객체 배열 — 단건 삭제여도 [{ productCd: "..." }] 형식을 유지
  keys: MasterRow[]
): Promise<void> {
  await http.post(`/api/v1/bas/${type}/validate-delete`, keys);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 검증·사용자 확인을 모두 통과한 기준정보 키 목록을 삭제한다
 *   2) validate-delete와 같은 객체 배열을 전달해 복합키 확장에도 대비한다
 *   3) 성공 시 반환값 없이 끝나며 화면이 목록을 다시 조회한다
 */
export async function deleteMasterRows(
  // 리소스 유형 — API 경로와 백엔드 삭제 대상을 고정 연결
  type: MasterType,
  // 삭제 업무키 객체 배열 — 스칼라 배열은 허용하지 않는다
  keys: MasterRow[]
): Promise<void> {
  await http.post(`/api/v1/bas/${type}/delete`, keys);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 저장 완료된 설비 행에 사진을 올리고 photoPath를 갱신한다
 *   2) 시설·설비 관리 「사진 업로드」가 httpFile로 호출한다
 *   3) 성공 시 서버가 반환한 photoPath
 */
export async function uploadEquipmentPhoto(
  // 설비 대리키 — 미저장 신규행이면 서버가 거부
  idx: number,
  // 사진 파일
  file: File
): Promise<string> {
  const form = new FormData();
  form.append("file", file);
  const { data } = await httpFile.post<CommonResponse<{ photoPath?: string }>>(
    `/api/v1/bas/equipment/${idx}/photo`,
    form
  );
  return (data.data?.photoPath ?? "").trim();
}
