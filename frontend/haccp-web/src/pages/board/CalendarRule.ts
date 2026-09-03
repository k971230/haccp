/**
 * CalendarRule — 일정 캘린더 순수 함수·상수.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) Page는 렌더·API만 하고 월 행렬·전환 diff는 여기 둔다
 *   2) 요일은 일~토. 앞뒤 빈 칸은 전월·익월 날짜다
 *   3) 체크 변경분만 저장 본문으로 만든다
 *
 * PIPELINE[HF211] 일정 캘린더 규칙
 */

/** 화면코드 — tbl_screen.scrn_cd. 폴더를 옮겨도 바꾸지 않는다 */
export const SCRN_CD = "calendar" as const;

/** 요일 머리 — 일요일 시작 */
export const WEEKDAY_LABELS = ["일", "월", "화", "수", "목", "금", "토"] as const;

/** 캘린더 한 칸 */
export interface CalendarCell {
  /** YYYYMMDD */
  ymd: string;
  /** 1~31 */
  day: number;
  /** 이번 달이면 true */
  inMonth: boolean;
  /** 토·일이면 true */
  weekend: boolean;
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 해당 월의 일~토 6주 칸을 만든다
 *   2) 캘린더 렌더가 호출한다
 *   3) 앞뒤 칸은 전월·익월. year/month 가 깨지면 빈 배열
 */
export function buildMonthCells(
  // 연 — 예: 2026
  year: number,
  // 월 — 1~12
  month: number,
): CalendarCell[] {
  if (!Number.isInteger(year) || !Number.isInteger(month) || month < 1 || month > 12) return [];
  const first = new Date(Date.UTC(year, month - 1, 1));
  const startDow = first.getUTCDay();
  const start = new Date(first);
  start.setUTCDate(1 - startDow);
  const cells: CalendarCell[] = [];
  for (let i = 0; i < 42; i++) {
    const d = new Date(start);
    d.setUTCDate(start.getUTCDate() + i);
    const y = d.getUTCFullYear();
    const m = d.getUTCMonth() + 1;
    const day = d.getUTCDate();
    const dow = d.getUTCDay();
    cells.push({
      ymd: `${String(y).padStart(4, "0")}${String(m).padStart(2, "0")}${String(day).padStart(2, "0")}`,
      day,
      inMonth: y === year && m === month,
      weekend: dow === 0 || dow === 6,
    });
  }
  return cells;
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) YYYYMM 을 연·월로 나눈다
 *   2) 월 이동·조회 파라미터에 쓴다
 *   3) 6자리가 아니면 오늘 월
 */
export function parseYearMonth(
  // YYYYMM
  month: string,
): { year: number; month: number } {
  const digits = (month ?? "").replace(/\D/g, "");
  if (digits.length === 6) {
    const year = Number(digits.slice(0, 4));
    const mo = Number(digits.slice(4, 6));
    if (year >= 2000 && mo >= 1 && mo <= 12) return { year, month: mo };
  }
  const now = new Date();
  return { year: now.getFullYear(), month: now.getMonth() + 1 };
}

/** 연·월 → YYYYMM */
export function formatYearMonth(year: number, month: number): string {
  return `${String(year).padStart(4, "0")}${String(month).padStart(2, "0")}`;
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 한 달을 앞뒤로 옮긴다
 *   2) 이전·다음 버튼이 호출한다
 *   3) 1월 이전이면 전년 12월
 */
export function shiftYearMonth(
  // YYYYMM
  month: string,
  // -1 이전 / +1 다음
  delta: number,
): string {
  const { year, month: mo } = parseYearMonth(month);
  const d = new Date(Date.UTC(year, mo - 1 + delta, 1));
  return formatYearMonth(d.getUTCFullYear(), d.getUTCMonth() + 1);
}

/** 오늘 YYYYMM */
export function thisYearMonth(): string {
  const now = new Date();
  return formatYearMonth(now.getFullYear(), now.getMonth() + 1);
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 서버 저장분과 화면 체크분을 비교해 변경만 뽑는다
 *   2) 저장 버튼이 호출한다
 *   3) 추가된 날은 Y, 빠진 날은 N
 */
export function workdayDiff(
  // 조회 시점 전환 집합
  saved: Set<string>,
  // 화면 체크 집합
  current: Set<string>,
): Array<{ ymd: string; workYn: "Y" | "N" }> {
  const out: Array<{ ymd: string; workYn: "Y" | "N" }> = [];
  for (const ymd of current) {
    if (!saved.has(ymd)) out.push({ ymd, workYn: "Y" });
  }
  for (const ymd of saved) {
    if (!current.has(ymd)) out.push({ ymd, workYn: "N" });
  }
  return out.sort((a, b) => a.ymd.localeCompare(b.ymd));
}

/** 주말 또는 공휴일이면 전환 체크박스를 그린다 */
export function canOverride(
  // 칸
  cell: CalendarCell,
  // 공휴일 ymd 집합
  holidays: Set<string>,
): boolean {
  return cell.weekend || holidays.has(cell.ymd);
}

/** 과제 표시 톤 — 완료·밀림·내 담당·오늘 할 일·그 외 */
export type CalendarTaskTone = "done" | "overdue" | "mine" | "today" | "other";

/** 톤별 pill 클래스 — 연한 틴트 + 진한 테두리 + 검정 글씨 */
export const TASK_TONE_CLASS: Record<CalendarTaskTone, string> = {
  mine: "border border-blue-500 bg-blue-300 text-slate-900",
  overdue: "border border-rose-500 bg-rose-300 text-slate-900",
  done: "border border-emerald-500 bg-emerald-300 text-slate-900",
  today: "border border-violet-500 bg-violet-300 text-slate-900",
  other: "border border-amber-500 bg-amber-300 text-slate-900",
};

/** 톤 판정에 쓰는 최소 필드 */
export type CalendarTaskToneInput = {
  status?: string | null;
  dueDt?: string | null;
  dueTime?: string | null;
  baseDt?: string | null;
  mine?: boolean | null;
  taskIdx?: number | null;
  /** 이미 쓴 문서 idx — 완료 조회에 쓴다 */
  docIdx?: number | null;
  /** 과제 담당자 — 비면 오늘 할 일에 전원 */
  userId?: string | null;
};

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 과제가 완료인지 본다 — 승인완료 APV
 *   2) 톤·정렬이 호출한다
 *   3) 문서 상태가 붙어도 APV 만 완료로 본다
 */
export function isCalendarTaskDone(
  // 과제·문서 상태
  status: unknown,
): boolean {
  return String(status ?? "").toUpperCase() === "APV";
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 마감일시가 지금보다 앞인지 본다
 *   2) due_time 이 없으면 그날 23:59 로 본다
 *   3) 형식이 깨지면 밀림이 아니다
 */
export function isCalendarTaskOverdue(
  // 마감일 YYYYMMDD
  dueDt: unknown,
  // 마감시각 HHMM — 비면 2359
  dueTime: unknown,
  // 기준 시각
  now: Date,
): boolean {
  const dt = String(dueDt ?? "").replace(/\D/g, "");
  if (dt.length !== 8) return false;
  let hhmm = String(dueTime ?? "").replace(/\D/g, "");
  if (hhmm.length === 0) hhmm = "2359";
  if (hhmm.length === 3) hhmm = `0${hhmm}`;
  if (hhmm.length !== 4) return false;
  const y = Number(dt.slice(0, 4));
  const m = Number(dt.slice(4, 6));
  const d = Number(dt.slice(6, 8));
  const hh = Number(hhmm.slice(0, 2));
  const mm = Number(hhmm.slice(2, 4));
  if (![y, m, d, hh, mm].every(Number.isFinite)) return false;
  const due = new Date(y, m - 1, d, hh, mm, 0, 0);
  return due.getTime() < now.getTime();
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 완료 → 밀림 → 내 담당 → 오늘 할 일 → 그 외 순으로 톤을 고른다
 *   2) 캘린더 pill 색이 호출한다
 *   3) 담당이 없고 기준일이 오늘이면 오늘 할 일. LATE 는 시각과 무관하게 밀림
 */
export function taskTone(
  // 과제 행
  task: CalendarTaskToneInput,
  // 기준 시각 — 밀림·오늘 판정
  now: Date = new Date(),
): CalendarTaskTone {
  if (isCalendarTaskDone(task.status)) return "done";
  const late = String(task.status ?? "").toUpperCase() === "LATE"
    || isCalendarTaskOverdue(task.dueDt, task.dueTime, now);
  if (late) return "overdue";
  if (task.mine) return "mine";
  const base = String(task.baseDt ?? "").replace(/\D/g, "");
  if (base.length === 8 && base === todayYmd(now)) return "today";
  return "other";
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 더블클릭으로 열 수 있는지 본다 — 오늘 할 일 SP 담당 규칙과 맞춘다
 *   2) 캘린더 pill 커서·더블클릭이 호출한다
 *   3) 완료(APV)는 문서가 있을 때만 조회. 담당 없음·본인·mine 이면 밀림·오늘 할 일도 연다
 */
export function canOpenCalendarTask(
  // 과제 행
  task: CalendarTaskToneInput,
  // 로그인 아이디 — 담당자 비교
  loginUserId?: string | null,
): boolean {
  const assign = String(task.userId ?? "").trim();
  const me = String(loginUserId ?? "").trim();
  // 담당 없음 · 본인 · 서버 mine(부서)
  const mine = !assign || (!!me && assign === me) || !!task.mine;
  if (!mine) return false;
  // 완료일 때(= 조회만) 문서가 없으면 작성 화면으로 보내지 않는다
  if (isCalendarTaskDone(task.status)) return Number(task.docIdx ?? 0) > 0;
  return true;
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 셀 안 정렬 — 내 담당 밀림 → 내 담당 → 타인 밀림 → 나머지
 *   2) 같은 칸 과제 목록이 호출한다
 *   3) 동순위는 마감시각·taskIdx. 완료도 나머지로 본다
 */
export function compareCalendarTask(
  // 왼쪽
  a: CalendarTaskToneInput,
  // 오른쪽
  b: CalendarTaskToneInput,
  // 기준 시각
  now: Date = new Date(),
): number {
  const rank = (t: CalendarTaskToneInput): number => {
    const tone = taskTone(t, now);
    const mine = !!t.mine;
    // 내 담당인데 밀린 것 — 맨 앞
    if (mine && tone === "overdue") return 0;
    // 내 담당(당일·아직 마감 전)
    if (mine) return 1;
    // 타인 밀림
    if (tone === "overdue") return 2;
    return 3;
  };
  const ra = rank(a);
  const rb = rank(b);
  if (ra !== rb) return ra - rb;
  const byDue = String(a.dueDt ?? "").localeCompare(String(b.dueDt ?? ""));
  if (byDue !== 0) return byDue;
  const byTime = String(a.dueTime ?? "").localeCompare(String(b.dueTime ?? ""));
  if (byTime !== 0) return byTime;
  return Number(a.taskIdx ?? 0) - Number(b.taskIdx ?? 0);
}

/** 오늘 YYYYMMDD */
export function todayYmd(
  // 기준 시각
  now: Date = new Date(),
): string {
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, "0");
  const d = String(now.getDate()).padStart(2, "0");
  return `${y}${m}${d}`;
}
