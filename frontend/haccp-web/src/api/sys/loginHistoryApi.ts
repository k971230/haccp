/**
 * loginHistoryApi — 로그인 이력 화면 API (/api/v1/sys/login-history).
 *
 * 개발자: 박승우
 * 일자: 2026-08-18
 * 코멘트:
 *   1) 조회 전용이다 — 저장·삭제 계약이 없다
 *   2) 기간은 YYYYMMDD 문자열이며 비워 보내면 서버가 오늘로 채운다
 *   3) 사용자 트리 선택값은 userId로 넘기고, 비우면 전체다
 *
 * PIPELINE[HF92] 로그인 이력 API
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
 * 일자: 2026-08-18
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
