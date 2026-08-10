/**
 * viewLogApi — 화면 조회 로그(UV/PV) 수집 API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) /api/v1/log/view/collect 로 진입·이탈 이벤트를 배치 전송한다
 *   2) 어느 기록 화면을 실제로 쓰는지 파악해 메뉴·교육 우선순위를 정하는 데 쓴다
 *   3) 실패해도 예외를 던지지 않는다 — 통계 수집이 업무를 막아서는 안 된다
 *
 * PIPELINE[HF19] API 레이어
 */
// 역할 — 일반 타임아웃 Axios 인스턴스
import { http } from "./http";
// 역할 — 공통 응답 타입
import type { CommonResponse } from "@/types/common";

/** 화면 조회 이벤트 1건 — 백엔드 ViewLogItem과 동일 구조 */
export interface ViewLogItem {
  /** 조회한 화면코드 */
  scrnCd: string;
  /** 진입 일시 — "YYYY-MM-DDTHH:mm:ss" (초까지, 밀리초·타임존 없음) */
  enterDt: string;
  /** 이탈 일시 — 아직 머무는 중이면 생략한다 */
  leaveDt?: string;
  /** 직전 화면코드 — 첫 진입이면 생략한다 */
  refScrnCd?: string;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 모아둔 화면 조회 이벤트를 한 번에 서버로 보낸다
 *   2) 탭을 닫거나 다른 탭으로 옮길 때, 그리고 창을 떠날 때 호출한다
 *   3) 성공·실패 모두 조용히 끝난다 — 호출부는 결과를 확인하지 않는다
 */
export async function collectViewLogs(
  // 이벤트 목록 — 빈 배열이면 호출 자체를 생략한다
  items: ViewLogItem[]
): Promise<void> {
  if (items.length === 0) return;
  try {
    await http.post<CommonResponse<null>>("/api/v1/log/view/collect", items);
  } catch {
    // 네트워크 단절·토큰 만료 — 통계 유실은 감수한다
  }
}
