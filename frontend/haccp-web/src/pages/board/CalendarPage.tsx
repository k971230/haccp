/**
 * CalendarPage — 회사 전체 일정 월간 캘린더.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 한 달 칸에 회사 과제를 뿌린다. 색은 내 담당·밀림·완료·오늘 할 일·그 외
 *   2) 주말·공휴일 체크 후 저장하면 그 날을 영업일로 바꾼다
 *   3) 담당이면 밀림·오늘 할 일도 열고, 완료는 문서가 있을 때만 조회한다
 *
 * PIPELINE[HF212] 일정 캘린더 화면
 */
// 역할 — 상태·효과·ref
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
// 역할 — 문서·작성 화면 이동
import { useNavigate } from "react-router-dom";
// 역할 — 월 이동·오늘 아이콘
import { CalendarCheck, ChevronLeft, ChevronRight } from "lucide-react";
// 역할 — 권한
import { useAuthStore } from "@/stores/authStore";
// 역할 — 중복 클릭 차단
import { useAsyncAction } from "@/hooks/useAsyncAction";
// 역할 — 2분 폴링 주기
import { DASHBOARD_POLLING_MS } from "@/config/envConfig";
// 역할 — 표준 버튼
import { MesButton } from "@/components/ui/MesButton";
// 역할 — 페이지 루트
import { pageRootClass } from "@/components/layout/pageClasses";
import { PageCard } from "@/components/layout/PageCard";
// 역할 — 확인·토스트·오류
import { mesConfirm, mesToast } from "@/shell/dialog";
import { mesError } from "@/shell/errors";
// 역할 — 캘린더 API
import {
  listCalendar,
  saveCalendarWorkdays,
  type CalendarHoliday,
  type CalendarTask,
} from "@/api/board/calendarApi";
// 역할 — 오늘 할 일과 같은 문서·작성 href
import { todayTaskHref } from "./TodayTasksRule";
// 역할 — 완료 문서는 최근 문서와 같은 조회 경로
import { routeForDocument } from "@/lib/documentNav";
// 역할 — 월 행렬·톤·전환 diff
import {
  SCRN_CD,
  TASK_TONE_CLASS,
  WEEKDAY_LABELS,
  buildMonthCells,
  canOpenCalendarTask,
  canOverride,
  compareCalendarTask,
  isCalendarTaskDone,
  parseYearMonth,
  shiftYearMonth,
  taskTone,
  thisYearMonth,
  todayYmd,
  workdayDiff,
} from "./CalendarRule";

/**
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 월 캘린더를 그리고 영업일 전환을 저장한다
 *   2) 메뉴 일정 캘린더에서 연다
 *   3) 조회 실패는 업무 토스트. 폴링 실패는 조용히 넘긴다
 */
export function CalendarPage() {
  const navigate = useNavigate();
  const loginUserId = useAuthStore((s) => s.user?.userId);
  const canSave = useAuthStore((s) => s.can(SCRN_CD, "write") || s.can(SCRN_CD, "modify"));
  const { run, isBusy } = useAsyncAction();
  const [month, setMonth] = useState(thisYearMonth);
  const [tasks, setTasks] = useState<CalendarTask[]>([]);
  const [holidays, setHolidays] = useState<CalendarHoliday[]>([]);
  const [savedWorkdays, setSavedWorkdays] = useState<Set<string>>(new Set());
  const [workdays, setWorkdays] = useState<Set<string>>(new Set());
  const [nowTick, setNowTick] = useState(() => new Date());
  // 폴링이 dirty 를 덮지 않게 최신 dirty 를 본다
  const dirtyRef = useRef(false);
  const monthRef = useRef(month);
  monthRef.current = month;

  const holidaySet = useMemo(() => new Set(holidays.map((h) => h.ymd)), [holidays]);
  const holidayName = useMemo(() => {
    const m = new Map<string, string>();
    for (const h of holidays) m.set(h.ymd, h.name);
    return m;
  }, [holidays]);
  const { year, month: mo } = parseYearMonth(month);
  const cells = useMemo(() => buildMonthCells(year, mo), [year, mo]);
  const today = todayYmd(nowTick);
  const tasksByDay = useMemo(() => {
    const m = new Map<string, CalendarTask[]>();
    for (const t of tasks) {
      const ymd = String(t.baseDt ?? "").replace(/\D/g, "");
      if (ymd.length !== 8) continue;
      const list = m.get(ymd) ?? [];
      list.push(t);
      m.set(ymd, list);
    }
    for (const [ymd, list] of m) {
      m.set(ymd, [...list].sort((a, b) => compareCalendarTask(a, b, nowTick)));
    }
    return m;
  }, [tasks, nowTick]);
  const dirty = useMemo(() => workdayDiff(savedWorkdays, workdays).length > 0, [savedWorkdays, workdays]);
  dirtyRef.current = dirty;

  const load = useCallback(async (ym: string) => {
    const data = await listCalendar(ym);
    setTasks(data.tasks);
    setHolidays(data.holidays);
    const next = new Set(data.workdays);
    setSavedWorkdays(next);
    setWorkdays(new Set(next));
    setNowTick(new Date());
  }, []);

  useEffect(() => {
    void run(() => load(month), "search", mesError);
  }, [month, load, run]);

  // 2분 무소음 폴링 — 영업일 변경분이 있으면 건너뛴다
  useEffect(() => {
    const id = window.setInterval(() => {
      if (dirtyRef.current) return;
      void load(monthRef.current).catch(() => {
        // 폴링 실패는 다음 주기에 다시 본다
      });
    }, DASHBOARD_POLLING_MS);
    return () => window.clearInterval(id);
  }, [load]);

  const toggleWorkday = (ymd: string, checked: boolean) => {
    setWorkdays((prev) => {
      const next = new Set(prev);
      if (checked) next.add(ymd);
      else next.delete(ymd);
      return next;
    });
  };

  /**
   * 개발자: 박승우
   * 일자: 2026-09-03
   * 코멘트:
   *   1) 오늘 할 일과 같은 담당이면 문서·작성 화면으로 연다
   *   2) 캘린더 과제 알약이 호출한다
   *   3) 완료는 최근 문서와 같이 routeForDocument 조회. 문서 없으면 안 연다
   */
  const openMineTask = (
    // 캘린더 과제 행
    t: CalendarTask,
  ) => {
    // 타인 지정 담당일 때(= 오늘 할 일에도 안 뜸) 열지 않는다
    if (!canOpenCalendarTask(t, loginUserId)) return;
    // 완료일 때(= 조회만) 작성 add=1 로 보내지 않는다
    if (isCalendarTaskDone(t.status)) {
      navigate(routeForDocument({ docIdx: Number(t.docIdx), tmplCd: String(t.tmplCd ?? "") }));
      return;
    }
    const href = todayTaskHref({
      taskType: "TASK",
      tmplCd: t.tmplCd,
      title: t.tmplNm,
      baseDt: t.baseDt,
      docIdx: t.docIdx,
    });
    if (href) navigate(href);
  };

  const handleSave = () => {
    void run(async () => {
      const items = workdayDiff(savedWorkdays, workdays);
      if (items.length === 0) {
        mesToast("변경된 영업일이 없습니다.", "warn");
        return;
      }
      if (!(await mesConfirm("선택한 날을 영업일로 반영하고 예정일을 다시 만들겠습니까?"))) return;
      await saveCalendarWorkdays(items);
      mesToast("영업일을 저장했습니다.", "success");
      await load(month);
    }, "save", mesError);
  };

  return (
    <div
      // 화면 루트 — 세로 flex. 글자 커서·선택은 끈다
      className={`${pageRootClass} cursor-default select-none`}
    >
      <PageCard>
        <div
          // 날짜 · 이전 · 다음 · 오늘 · 범례 · 저장
          className="flex flex-wrap items-center gap-2 border-b border-slate-200 bg-slate-50/70 px-3 py-2"
        >
          <span
            // 현재 조회 월 — 제목 대신 맨 앞
            className="min-w-[7.5rem] text-base font-bold text-slate-800"
          >
            {year}년 {mo}월
          </span>
          <MesButton
            // 이전 달 — 조회 파란 틴트
            variant="search"
            size="sm"
            icon={ChevronLeft}
            onClick={() => setMonth((m) => shiftYearMonth(m, -1))}
          >
            이전
          </MesButton>
          <MesButton
            // 다음 달 — 조회 파란 틴트
            variant="search"
            size="sm"
            icon={ChevronRight}
            onClick={() => setMonth((m) => shiftYearMonth(m, 1))}
          >
            다음
          </MesButton>
          <MesButton
            // 이번 달 — 저장과 다른 초록 틴트
            variant="excel"
            size="sm"
            icon={CalendarCheck}
            onClick={() => setMonth(thisYearMonth())}
          >
            오늘
          </MesButton>
          <div
            // 범례는 오른쪽, 저장이 진짜 끝
            className="ml-auto flex flex-wrap items-center gap-2"
          >
            <span className="inline-flex items-center gap-1 text-xs font-semibold text-slate-700">
              <span className="inline-block h-2.5 w-2.5 rounded-full bg-blue-400" />
              내 담당
            </span>
            <span className="inline-flex items-center gap-1 text-xs font-semibold text-slate-700">
              <span className="inline-block h-2.5 w-2.5 rounded-full bg-rose-400" />
              밀림
            </span>
            <span className="inline-flex items-center gap-1 text-xs font-semibold text-slate-700">
              <span className="inline-block h-2.5 w-2.5 rounded-full bg-emerald-400" />
              완료
            </span>
            <span className="inline-flex items-center gap-1 text-xs font-semibold text-slate-700">
              <span className="inline-block h-2.5 w-2.5 rounded-full bg-amber-400" />
              그 외
            </span>
            <span className="inline-flex items-center gap-1 text-xs font-semibold text-slate-700">
              <span className="inline-block h-2.5 w-2.5 rounded-full bg-violet-400" />
              오늘 할 일
            </span>
            {canSave ? (
              <MesButton
                // 영업일 전환 저장 — 주기설정·그리드 CRUD 와 같은 save 아이콘 버튼
                variant="save"
                size="sm"
                icon="save"
                loading={isBusy("save")}
                disabled={!dirty}
                onClick={handleSave}
              >
                저장
              </MesButton>
            ) : null}
          </div>
        </div>
        <div
          // 요일 머리 + 6주 칸. 글자 커서는 안 간다
          className="grid min-h-0 flex-1 cursor-default select-none grid-cols-7 grid-rows-[auto_repeat(6,minmax(0,1fr))]"
        >
          {WEEKDAY_LABELS.map((label, i) => (
            <div
              // 요일 머리 — 일·토 강조
              key={label}
              className={`border-b border-slate-200 px-2 py-1 text-center text-xs font-bold ${
                i === 0 || i === 6 ? "text-rose-700" : "text-slate-700"
              }`}
            >
              {label}
            </div>
          ))}
          {cells.map((cell) => {
            const dayTasks = tasksByDay.get(cell.ymd) ?? [];
            const holiday = holidayName.get(cell.ymd);
            const off = canOverride(cell, holidaySet);
            const checked = workdays.has(cell.ymd);
            const isToday = cell.inMonth && cell.ymd === today;
            const weekendBg = cell.inMonth && cell.weekend && !checked;
            const holidayBg = cell.inMonth && !!holiday && !cell.weekend && !checked;
            const overflow = dayTasks.length >= 4;
            return (
              <div
                // 하루 칸 — 주말 rose · 오늘 파란 테두리 · 영업일 전환 초록
                key={cell.ymd}
                className={`relative flex min-h-[5.5rem] cursor-default flex-col border-b border-r border-slate-200 p-1 text-xs ${
                  !cell.inMonth ? "bg-slate-100 text-slate-500" : "text-slate-800"
                } ${weekendBg ? "bg-rose-100" : ""} ${holidayBg ? "bg-orange-100" : ""} ${
                  cell.inMonth && checked ? "bg-emerald-50" : ""
                } ${isToday ? "ring-2 ring-inset ring-blue-500" : ""}`}
              >
                <div className="flex items-center justify-between gap-1">
                  <div className="flex items-center gap-1">
                    <span
                      // 일자 — 오늘은 파란 원. 주말·공휴일은 붉게
                      className={`inline-flex h-5 min-w-[1.25rem] items-center justify-center rounded-full px-1 font-bold ${
                        isToday
                          ? "bg-blue-500 text-white"
                          : cell.inMonth && (cell.weekend || holiday)
                            ? "text-rose-700"
                            : "text-slate-800"
                      }`}
                    >
                      {cell.day}
                    </span>
                    {isToday ? (
                      <span
                        // 오늘 배지
                        className="text-[10px] font-bold text-blue-700"
                      >
                        오늘
                      </span>
                    ) : null}
                  </div>
                  {canSave && cell.inMonth && off ? (
                    <label
                      // 영업일 전환 — 주말·공휴일만. 글자를 진하게
                      className="inline-flex cursor-pointer items-center gap-0.5 text-xs font-bold text-slate-900"
                      title="영업일로 전환"
                    >
                      <input
                        // 체크하면 그 날을 영업일로
                        type="checkbox"
                        checked={checked}
                        onChange={(e) => toggleWorkday(cell.ymd, e.target.checked)}
                      />
                      영업일
                    </label>
                  ) : null}
                </div>
                {holiday ? (
                  <div
                    // 공휴일 명칭
                    className="truncate text-xs font-bold text-rose-700"
                    title={holiday}
                  >
                    {holiday}
                  </div>
                ) : null}
                <div
                  // 과제 목록 — 4건 이상이면 스크롤
                  className={`mt-0.5 flex min-h-0 flex-1 flex-col gap-0.5 ${
                    overflow ? "overflow-y-auto" : "overflow-hidden"
                  }`}
                >
                  {dayTasks.map((t, i) => {
                    const tone = taskTone(t, nowTick);
                    // 밀림·오늘 할 일 색이어도 오늘 할 일 담당 규칙이면 연다
                    const canOpen = canOpenCalendarTask(t, loginUserId);
                    const label = String(t.tmplNm ?? t.tmplCd ?? "");
                    return (
                      <div key={`${t.taskIdx}-${t.tmplCd}`}>
                        {overflow && i === 3 ? (
                          <div
                            // 4건부터 접힘 힌트 — 스크롤하면 나머지가 보인다
                            className="px-1 py-0.5 text-xs font-bold text-slate-700"
                          >
                            ... 외 {dayTasks.length - 3}건
                          </div>
                        ) : null}
                        <div
                          // 과제 알약 — 담당 규칙 맞으면 더블클릭으로 문서·작성 화면
                          className={`truncate rounded-full px-1.5 py-0.5 text-xs font-semibold ${TASK_TONE_CLASS[tone]} ${
                            canOpen ? "cursor-pointer" : "cursor-default"
                          }`}
                          title={canOpen ? `${label} (더블클릭하여 열기)` : label}
                          onDoubleClick={() => openMineTask(t)}
                        >
                          {t.tmplNm ?? t.tmplCd}
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            );
          })}
        </div>
      </PageCard>
    </div>
  );
}
