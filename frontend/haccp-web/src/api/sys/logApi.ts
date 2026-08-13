/**
 * logApi — 로그 3화면(로그인 이력·감사 이력·화면 이용 통계) 조회 API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 세 화면 모두 조회 전용이다 — 저장·삭제 계약이 없다
 *   2) 기간은 YYYYMMDD 문자열이며 비워 보내면 서버가 오늘로 채운다
 *   3) 화면별로 필터 이름이 달라 각각 별도 함수로 둔다 (keyword 하나로 뭉치지 않는다)
 *
 * PIPELINE[HF92] 로그 화면 API
 */
// 역할 — 일반 CRUD Axios 인스턴스
import { http } from "../http";
// 역할 — 공통 성공 응답 형식
import type { CommonResponse } from "@/types/common";
// 역할 — MyBatis Map snake_case → 그리드 camelCase 정규화
import { camelizeRows } from "@/lib/camelKeys";
// 역할 — 이력 행 타입
import type { SysRow } from "./sysTypes";

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 기간 내 로그인 이력을 최신순으로 조회한다
 *   2) 화면 진입·조회와 좌측 사용자 트리 선택 시 호출한다
 *   3) 해당 기간에 이력이 없으면 빈 배열
 */
export async function listLoginHistory(params: {
  // 조회 시작일 YYYYMMDD
  fromDt: string;
  // 조회 종료일 YYYYMMDD
  toDt: string;
  // 좌측 트리에서 고른 아이디 — 생략하면 전체
  userId?: string;
  // 결과 필터 S|F|L — 생략하면 전체
  resultCd?: string;
}): Promise<SysRow[]> {
  const { data } = await http.get<CommonResponse<SysRow[]>>("/api/v1/sys/login-history/list", {
    params,
  });
  return camelizeRows<SysRow>(data.data as unknown as Record<string, unknown>[]);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 기간 내 변경 감사 이력을 최신순으로 조회한다
 *   2) 화면 진입·조회와 좌측 메뉴 트리 선택 시 호출한다
 *   3) 해당 기간에 이력이 없으면 빈 배열
 */
export async function listAuditLog(params: {
  // 조회 시작일 YYYYMMDD
  fromDt: string;
  // 조회 종료일 YYYYMMDD
  toDt: string;
  // 좌측 메뉴 트리 선택값(테이블명·화면코드·메뉴명) — 생략하면 전체
  menuKey?: string;
  // 행위자 아이디 검색어 — 생략하면 전체
  userId?: string;
  // 행위 필터 — 생략하면 전체
  actionCd?: string;
}): Promise<SysRow[]> {
  const { data } = await http.get<CommonResponse<SysRow[]>>("/api/v1/sys/audit-log/list", {
    params,
  });
  return camelizeRows<SysRow>(data.data as unknown as Record<string, unknown>[]);
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 기간 내 화면별 PV/UV/세션/IP 집계를 조회한다
 *   2) 화면 진입·조회와 좌측 메뉴 트리 선택 시 호출한다
 *   3) 집계 배치 전이면 당일 값은 나오지 않는다
 */
export async function listScreenUsage(params: {
  // 집계 시작일 YYYYMMDD
  fromDt: string;
  // 집계 종료일 YYYYMMDD
  toDt: string;
  // 좌측 메뉴 트리에서 고른 화면코드 — 생략하면 전체
  scrnCd?: string;
}): Promise<SysRow[]> {
  const { data } = await http.get<CommonResponse<SysRow[]>>(
    "/api/v1/sys/screen-usage-statistics/list",
    { params },
  );
  return camelizeRows<SysRow>(data.data as unknown as Record<string, unknown>[]);
}
