/**
 * calendarApi — 일정 캘린더 API.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 월 조회·영업일 전환 저장만 감싼다
 *   2) 회사·사용자는 JWT에서 결정되므로 요청에 넣지 않는다
 *   3) 저장 본문은 변경분 [{ ymd, workYn }]
 *
 * PIPELINE[HF210] 일정 캘린더 API
 */
// 역할 — 일반 Axios
import { http } from "@/api/http";
// 역할 — 공통 응답
import type { CommonResponse } from "@/types/common";

/** 캘린더 과제 1건 — 회사 전체. mine 은 내 담당 */
export interface CalendarTask {
  taskIdx?: number;
  tmplCd?: string;
  tmplNm?: string;
  baseDt?: string;
  dueDt?: string;
  dueTime?: string;
  status?: string;
  userId?: string;
  deptCd?: string;
  mine?: boolean;
  /** 이미 쓴 문서 idx — 없으면 0·undefined. 더블클릭 이동에 쓴다 */
  docIdx?: number;
}

/** 공휴일 1건 — ymd YYYYMMDD */
export interface CalendarHoliday {
  ymd: string;
  name: string;
}

/** 월 조회 응답 */
export interface CalendarMonthPayload {
  month: string;
  tasks: CalendarTask[];
  holidays: CalendarHoliday[];
  workdays: string[];
}

/** 영업일 전환 변경 1건 */
export interface WorkdaySaveItem {
  ymd: string;
  workYn: "Y" | "N";
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 한 달치 과제·공휴일·전환을 조회한다
 *   2) 캘린더 진입·월 이동에서 호출한다
 *   3) month 는 YYYYMM. 비면 서버가 이번 달
 */
export async function listCalendar(
  // 조회 월 YYYYMM
  month: string,
): Promise<CalendarMonthPayload> {
  const { data } = await http.get<CommonResponse<CalendarMonthPayload>>("/api/v1/board/calendar/list", {
    params: { month },
  });
  const payload = data.data ?? { month, tasks: [], holidays: [], workdays: [] };
  return {
    month: payload.month ?? month,
    tasks: payload.tasks ?? [],
    holidays: payload.holidays ?? [],
    workdays: payload.workdays ?? [],
  };
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 영업일 전환 변경분을 저장한다
 *   2) 저장 버튼에서 호출한다
 *   3) 성공 시 본문 없음
 */
export function saveCalendarWorkdays(
  // 변경분 — ymd YYYYMMDD, workYn Y/N
  items: WorkdaySaveItem[],
) {
  return http.put<CommonResponse<null>>("/api/v1/board/calendar/save", items);
}
