/**
 * screenUsageApi — 화면 이용 통계 API (SCREEN_PATH).
 *
 * 개발자: 박승우
 * 일자: 2026-08-18
 * 코멘트:
 *   1) 조회 전용이다 — 저장·삭제 계약이 없다
 *   2) 기간은 YYYYMMDD 문자열이며 비워 보내면 서버가 오늘로 채운다
 *   3) 메뉴 트리 선택값은 scrnCd로 넘기고, 비우면 전체다
 *
 * PIPELINE[HF92] 화면 이용 통계 API
 */
// 역할 — 일반 CRUD Axios 인스턴스
import { http } from "../http";
// 역할 — SCREEN_PATH 기준 API 베이스
import { apiOf } from "@/shell/tabRoute";
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
    apiOf("screen-usage-statistics", "list"),
    { params },
  );
  return camelizeRows<SysRow>(data.data as unknown as Record<string, unknown>[]);
}
