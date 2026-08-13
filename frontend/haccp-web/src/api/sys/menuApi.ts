/**
 * menuApi (sys) — 메뉴 관리 화면 API (/api/v1/sys/menu-management).
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 사이드바 메뉴 트리 API(`@/api/menuApi`)와 다른 계약이다 — 이쪽은 권한 필터 없는 관리자 전체 목록이다
 *   2) 권한 관리·감사 이력·화면 이용 통계의 좌측 트리도 이 목록을 쓴다
 *   3) 삭제는 validate-delete → delete 두 단계 POST다 (HTTP DELETE 금지)
 *
 * PIPELINE[HF92] 메뉴 관리 API
 */
// 역할 — 일반 CRUD Axios 인스턴스
import { http } from "../http";
// 역할 — 공통 성공 응답 형식
import type { CommonResponse } from "@/types/common";
// 역할 — MyBatis Map snake_case → 그리드 camelCase 정규화
import { camelizeRows } from "@/lib/camelKeys";
// 역할 — 메뉴 행·삭제키 타입
import type { AdminMenuRow, SysDeleteKey, SysRow } from "./sysTypes";

/** 화면 기본 경로 — Controller @RequestMapping과 1:1 */
const BASE = "/api/v1/sys/menu-management";

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 관리용 메뉴 전체 목록을 조회한다
 *   2) 메뉴 관리 진입·조회와 권한·로그 화면의 좌측 트리에서 호출한다
 *   3) 트리 조립에 전체 집합이 필요하므로 기본은 검색어 없이 부른다
 */
export async function listAdminMenus(): Promise<AdminMenuRow[]> {
  const { data } = await http.get<CommonResponse<AdminMenuRow[]>>(`${BASE}/list`);
  return camelizeRows<AdminMenuRow>(data.data as unknown as Record<string, unknown>[]);
}

/** 변경된 메뉴 행 저장 — 사용여부를 N으로 내리면 하위 메뉴도 함께 N이 된다 */
export async function saveMenus(rows: SysRow[]): Promise<void> {
  await http.put(`${BASE}/save`, rows);
}

/** 삭제 전 하위 메뉴 참조 검증 — 단건도 idx 객체 배열로 전달한다 */
export async function validateDeleteMenus(keys: SysDeleteKey[]): Promise<void> {
  await http.post(`${BASE}/validate-delete`, keys);
}

/** 검증·확인 완료 메뉴 삭제 — HTTP DELETE 대신 POST를 사용한다 */
export async function deleteMenus(keys: SysDeleteKey[]): Promise<void> {
  await http.post(`${BASE}/delete`, keys);
}
