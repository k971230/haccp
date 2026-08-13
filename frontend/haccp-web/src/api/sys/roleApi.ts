/**
 * roleApi — 권한그룹 관리 화면 API (/api/v1/sys/role-management).
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 좌측 권한그룹 마스터와 우측 화면권한 매트릭스를 한 파일에서 다룬다
 *   2) 회사코드는 보내지 않는다 — 서버가 JWT 테넌트로 범위를 고정한다
 *   3) 삭제는 validate-delete → delete 두 단계 POST다 (HTTP DELETE 금지)
 *
 * PIPELINE[HF92] 권한그룹 관리 API
 */
// 역할 — 일반 CRUD Axios 인스턴스
import { http } from "../http";
// 역할 — 공통 성공 응답 형식
import type { CommonResponse } from "@/types/common";
// 역할 — MyBatis Map snake_case → 그리드 camelCase 정규화
import { camelizeRows } from "@/lib/camelKeys";
// 역할 — 권한그룹 행·화면권한 행·삭제키 타입
import type { RoleScreenRow, SysDeleteKey, SysRow } from "./sysTypes";

/** 화면 기본 경로 — Controller @RequestMapping과 1:1 */
const BASE = "/api/v1/sys/role-management";

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 권한그룹 목록을 조회한다
 *   2) 권한 관리 진입·조회와 사용자 관리 권한그룹 룩업에서 호출한다
 *   3) 조건에 맞는 그룹이 없으면 빈 배열
 */
export async function listRoles(): Promise<SysRow[]> {
  const { data } = await http.get<CommonResponse<SysRow[]>>(`${BASE}/list`);
  return camelizeRows<SysRow>(data.data as unknown as Record<string, unknown>[]);
}

/** 변경된 권한그룹 행 저장 — 회사코드·작업자는 서버 JWT로만 채운다 */
export async function saveRoles(rows: SysRow[]): Promise<void> {
  await http.put(`${BASE}/save`, rows);
}

/** 삭제 전 사용자 참조 검증 — 단건도 idx 객체 배열로 전달한다 */
export async function validateDeleteRoles(keys: SysDeleteKey[]): Promise<void> {
  await http.post(`${BASE}/validate-delete`, keys);
}

/** 검증·확인 완료 권한그룹 삭제 — 화면권한 설정도 함께 정리된다 */
export async function deleteRoles(keys: SysDeleteKey[]): Promise<void> {
  await http.post(`${BASE}/delete`, keys);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 권한그룹별 화면 권한 목록을 조회한다
 *   2) 좌측에서 그룹을 고를 때 우측 트리가 호출한다
 *   3) 아직 설정하지 않은 화면도 전부 N으로 내려온다
 */
export async function listRoleScreens(
  // 조회할 권한그룹코드 — 필수
  usrgrpCd: string,
): Promise<RoleScreenRow[]> {
  const { data } = await http.get<CommonResponse<RoleScreenRow[]>>(`${BASE}/screens`, {
    params: { usrgrpCd },
  });
  return camelizeRows<RoleScreenRow>(data.data as unknown as Record<string, unknown>[]);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 화면 조회권한(readYn) 변경을 저장한다
 *   2) 권한 트리 체크 후 저장 버튼에서 호출한다
 *   3) 조회권한이 Y면 등록·수정·삭제·출력도 함께 Y가 된다
 */
export async function saveRoleScreens(
  // 대상 권한그룹코드 — 필수
  usrgrpCd: string,
  // 변경된 화면 권한 행 — 체크 상태만 보낸다
  rows: Array<{ scrnCd: string; readYn: string }>,
): Promise<void> {
  await http.put(`${BASE}/screens`, { usrgrpCd, rows });
}
