/**
 * docStatus — 문서·과제·개선조치 상태 배지 색 정본.
 *
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 그리드 badge·상세 배지가 같은 색을 쓰게 한곳에 모은다
 *   2) 라벨은 tbl_code(DOC_STATUS·CA_STATUS) 또는 TASK_STATUS_NM 이 정한다. 여기서는 색만 둔다
 *   3) 오늘 할 일·결재첨부·문서함·HWP 오늘할일 팝업이 가져다 쓴다
 *
 * PIPELINE[HF88] 오늘 할 일 화면
 */

/** 그리드·상세 배지 톤 — GridColumn.badge 와 같다 */
export type StatusBadgeTone = "blue" | "amber" | "green" | "gray" | "red" | "purple" | "dash";

/**
 * 문서상태 배지 색 — WRK/REQ/REV/APV/RJT.
 * 라벨은 DOC_STATUS 공통코드(작성중·검토요청 등)가 정한다.
 */
export const DOC_STATUS_BADGE: Record<string, StatusBadgeTone> = {
  // 작성중 — 아직 손댈 수 있다
  WRK: "red",
  // 구 임시저장 — 작성중과 같이 본다
  TMP: "red",
  // 승인요청 — 결재가 돌고 있다
  REQ: "blue",
  // 검토완료 — 다음이 승인이다
  REV: "amber",
  // 승인완료 — 확정된 기록
  APV: "green",
  // 반려 — 작성중(빨강)과 겹치지 않게 둔다
  RJT: "purple",
};

/**
 * 일정 과제 상태 문구 — tbl_schedule_task.status. 공통코드 도메인이 없어 여기가 정본이다.
 * HWP 오늘할일 팝업·오늘 할 일 그리드가 같이 쓴다.
 */
export const TASK_STATUS_NM: Record<string, string> = {
  TODO: "예정",
  ING: "진행",
  LATE: "지연",
  APV: "승인완료",
};

/** 일정 과제 상태 배지 색 — TODO/ING/LATE/APV */
export const TASK_STATUS_BADGE: Record<string, StatusBadgeTone> = {
  TODO: "gray",
  ING: "blue",
  LATE: "red",
  APV: "green",
  /*
   * 그 날짜로 쓴 문서가 있으면 오늘 할 일에 문서상태가 그대로 온다.
   * 색이 없으면 배지가 회색으로 뭉개져 「썼는지 안 썼는지」가 안 보인다.
   */
  WRK: "blue",
  REQ: "amber",
  REV: "amber",
  RJT: "red",
};

/**
 * 개선조치 상태 배지 색 — OPEN/ING/DONE.
 * 라벨은 CA_STATUS 공통코드(미조치·조치중·완료)가 정한다.
 */
export const CA_STATUS_BADGE: Record<string, StatusBadgeTone> = {
  // 미조치 — 점선 주황. 아직 손이 안 갔다
  OPEN: "dash",
  // 조치중
  ING: "blue",
  // 완료
  DONE: "green",
};

/**
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 문서 상태 코드의 배지 색을 고른다 — 모르는 코드는 회색
 *   2) 결재첨부 우측 상세 배지가 호출한다. 그리드는 DOC_STATUS_BADGE 를 그대로 넘긴다
 *   3) 색 의미: 빨강 작성중 · 파랑 진행 · 노랑 중간단계 · 초록 완료 · 보라 반려
 */
export function docStatusBadgeClass(
  // 문서 상태 WRK/REQ/REV/APV/RJT
  status?: string | null,
): string {
  const tone = DOC_STATUS_BADGE[status ?? "WRK"] ?? "gray";
  // 그리드 배지와 같은 색 계열 — .mes-* 가 아닌 곳이라 토큰 클래스로 맞춘다
  const byTone: Record<string, string> = {
    gray: "bg-slate-100 text-slate-700 border-slate-200",
    blue: "bg-blue-50 text-blue-700 border-blue-200",
    amber: "bg-amber-50 text-amber-700 border-amber-200",
    green: "bg-emerald-50 text-emerald-700 border-emerald-200",
    red: "bg-red-50 text-red-700 border-red-200",
    purple: "bg-violet-50 text-violet-700 border-violet-200",
  };
  return byTone[tone] ?? byTone.gray;
}
