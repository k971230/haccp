/**
 * departmentApi — 부서 관리 화면 API (SCREEN_PATH).
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 회사코드는 보내지 않는다 — 서버가 JWT 테넌트로 범위를 고정한다
 *   2) 조회 결과에는 상위부서명(hDeptNm)이 이미 붙어 있어 화면에서 다시 매핑하지 않는다
 *   3) 삭제는 validate-delete → delete 두 단계 POST다 (HTTP DELETE 금지)
 *
 * PIPELINE[HF92] 부서 관리 API
 */
// 역할 — 일반 CRUD Axios 인스턴스
import { http } from "../http";
// 역할 — SCREEN_PATH 기준 API 베이스
import { apiOf } from "@/shell/tabRoute";
// 역할 — 공통 성공 응답 형식
import type { CommonResponse } from "@/types/common";
// 역할 — MyBatis Map snake_case → 그리드 camelCase 정규화
import { camelizeRows } from "@/lib/camelKeys";
// 역할 — 부서 행·삭제키 타입
import type { SysDeleteKey, SysRow } from "./sysTypes";

/** 화면 기본 경로 — SCREEN_PATH department-management */
const BASE = apiOf("department-management");

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 부서 목록을 조회한다 — 최상위 우선 트리 정렬
 *   2) 부서 관리 진입·조회와 사용자 관리 부서 트리·룩업에서 호출한다
 *   3) 조건에 맞는 부서가 없으면 빈 배열
 */
export async function listDepartments(): Promise<SysRow[]> {
  const { data } = await http.get<CommonResponse<SysRow[]>>(`${BASE}/list`);
  return camelizeRows<SysRow>(data.data as unknown as Record<string, unknown>[]);
}

/** 변경된 부서 행 저장 — 회사코드·작업자는 서버 JWT로만 채운다 */
export async function saveDepartments(rows: SysRow[]): Promise<void> {
  await http.put(`${BASE}/save`, rows);
}

/** 삭제 전 사용자·하위 부서 참조 검증 — 단건도 idx 객체 배열로 전달한다 */
export async function validateDeleteDepartments(keys: SysDeleteKey[]): Promise<void> {
  await http.post(`${BASE}/validate-delete`, keys);
}

/** 검증·확인 완료 부서 삭제 — HTTP DELETE 대신 POST를 사용한다 */
export async function deleteDepartments(keys: SysDeleteKey[]): Promise<void> {
  await http.post(`${BASE}/delete`, keys);
}
