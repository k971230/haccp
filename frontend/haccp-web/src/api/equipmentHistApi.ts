/**
 * equipmentHistApi — 설비 이력(M-D 하단) API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 설비별 이력 목록·저장·삭제 검증·삭제 요청만 담당한다
 *   2) 삭제는 POST validate-delete → 사용자 확인 → POST delete 순서를 화면이 지킨다
 *   3) 회사코드는 요청 본문에 넣지 않는다 — JWT가 로그인 회사 테넌트를 고정한다
 *
 * PIPELINE[HF124] 설비이력 API
 * PIPELINE[HF3, HF125] 연관 모듈
 */
// 역할 — 일반 CRUD 타임아웃 Axios 인스턴스
import { http } from "./http";
// 역할 — 서버 공통 성공 응답 타입
import type { CommonResponse } from "@/types/common";

/** 설비 이력 행 — 그리드·저장 SP camelCase 계약 */
export interface EquipmentHistRow {
  idx?: number | null;
  equipIdx?: number | null;
  histDt?: string | null;
  faultRmk?: string | null;
  actionRmk?: string | null;
  docIdx?: number | null;
  remark?: string | null;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 선택한 설비의 이력 목록을 조회한다
 *   2) 설비이력 화면에서 상단 설비 선택·저장·삭제 후 재조회에서 호출한다
 *   3) 성공하면 행 배열을, data가 비었으면 빈 배열을 반환한다
 */
export async function listEquipmentHist(
  // 상위 설비 대리키
  equipIdx: number
): Promise<EquipmentHistRow[]> {
  const { data } = await http.get<CommonResponse<EquipmentHistRow[]>>(
    "/api/v1/docs/prp/equipment-history/list",
    { params: { equipIdx } },
  );
  return data.data ?? [];
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 이력 행 배열을 한 번에 저장한다
 *   2) 신규·수정 모두 같은 save API가 행의 idx 존재 여부로 구분한다
 *   3) 성공 시 반환값 없이 끝나며 화면이 목록을 다시 조회한다
 */
export async function saveEquipmentHist(
  // 저장 행 배열 — UI 단건이어도 배열
  rows: EquipmentHistRow[]
): Promise<void> {
  await http.put("/api/v1/docs/prp/equipment-history/save", rows);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 선택 이력의 삭제 키만 먼저 검사한다
 *   2) 삭제 확인창을 열기 직전에 호출한다
 *   3) 서버가 차단하면 예외를 던지고 화면은 삭제 요청을 보내지 않는다
 */
export async function validateDeleteEquipmentHist(
  // 삭제 키 객체 배열 — 단건도 [{ idx }]
  keys: { idx: number }[]
): Promise<void> {
  await http.post("/api/v1/docs/prp/equipment-history/validate-delete", keys);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-07
 * 코멘트:
 *   1) 검증·사용자 확인을 모두 통과한 이력 키 목록을 삭제한다
 *   2) validate-delete와 같은 객체 배열을 전달한다
 *   3) 성공 시 반환값 없이 끝나며 화면이 목록을 다시 조회한다
 */
export async function deleteEquipmentHist(
  // 삭제 키 객체 배열 — 스칼라 배열은 허용하지 않는다
  keys: { idx: number }[]
): Promise<void> {
  await http.post("/api/v1/docs/prp/equipment-history/delete", keys);
}
