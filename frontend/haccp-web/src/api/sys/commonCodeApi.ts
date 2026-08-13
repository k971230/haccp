/**
 * commonCodeApi — 공통코드 관리 화면 API (/api/v1/sys/common-code-management).
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 회사코드는 보내지 않는다 — 서버가 JWT 테넌트로 범위를 고정한다
 *   2) Map 조회 결과는 camelizeRows로 snake_case를 그리드 field에 맞춘다
 *   3) 삭제는 validate-delete → delete 두 단계 POST다 (HTTP DELETE 금지)
 *
 * PIPELINE[HF92] 공통코드 API
 */
// 역할 — 일반 CRUD Axios 인스턴스
import { http } from "../http";
// 역할 — 공통 성공 응답 형식
import type { CommonResponse } from "@/types/common";
// 역할 — MyBatis Map snake_case → 그리드 camelCase 정규화
import { camelizeRows } from "@/lib/camelKeys";
// 역할 — 공통코드 행·삭제키 타입
import type { CodeManageRow, SysDeleteKey } from "./sysTypes";

/** 화면 기본 경로 — Controller @RequestMapping과 1:1 */
const BASE = "/api/v1/sys/common-code-management";

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 대분류(좌측 그리드) 목록을 조회한다
 *   2) 화면 진입·조회 버튼에서 호출한다
 *   3) 조건에 맞는 대분류가 없으면 빈 배열
 */
export async function listCodeGroups(
  // 대분류코드 부분검색어 — 생략하면 전체
  mainCd = "",
  // 대분류명 부분검색어 — 생략하면 전체
  codeNm = "",
): Promise<CodeManageRow[]> {
  const { data } = await http.get<CommonResponse<CodeManageRow[]>>(`${BASE}/groups`, {
    params: { mainCd, codeNm },
  });
  return camelizeRows<CodeManageRow>(data.data as unknown as Record<string, unknown>[]);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 선택 대분류의 세부코드 목록을 조회한다
 *   2) 대분류 행을 고를 때 시스템·사용자 그리드가 각각 호출한다
 *   3) 대분류가 비면 서버가 업무 오류로 응답한다
 */
export async function listCodeDetails(
  // 좌측에서 고른 대분류코드 — 필수
  mainCd: string,
  // 시스템/사용자 구분 Y|N|sys|usr — 빈 문자열이면 둘 다
  sysYn: string,
): Promise<CodeManageRow[]> {
  const { data } = await http.get<CommonResponse<CodeManageRow[]>>(`${BASE}/details`, {
    params: { mainCd, sysYn },
  });
  return camelizeRows<CodeManageRow>(data.data as unknown as Record<string, unknown>[]);
}

/** 변경된 세부코드 행 저장 — 회사코드·작업자는 서버 JWT로만 채운다 */
export async function saveCommonCodes(rows: CodeManageRow[]): Promise<void> {
  await http.put(`${BASE}/save`, rows);
}

/** 삭제 전 참조 검증 — 단건도 idx 객체 배열로 전달한다 */
export async function validateDeleteCommonCodes(keys: SysDeleteKey[]): Promise<void> {
  await http.post(`${BASE}/validate-delete`, keys);
}

/** 검증·확인 완료 행 삭제 — HTTP DELETE 대신 POST를 사용한다 */
export async function deleteCommonCodes(keys: SysDeleteKey[]): Promise<void> {
  await http.post(`${BASE}/delete`, keys);
}
