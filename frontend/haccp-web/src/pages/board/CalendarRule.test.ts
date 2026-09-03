/**
 * CalendarRule.test — 월 행렬·전환 diff·톤·정렬.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 6주 42칸·일요 시작이 깨지면 달력이 밀린다
 *   2) diff 가 빠지면 저장이 전체 덮어쓰거나 무변화가 된다
 *   3) 톤·정렬이 바뀌면 색·순서가 어긋난다 — vitest 로 돌린다
 */
import { describe, expect, it } from "vitest";
import {
  buildMonthCells,
  canOpenCalendarTask,
  canOverride,
  compareCalendarTask,
  formatYearMonth,
  parseYearMonth,
  shiftYearMonth,
  taskTone,
  workdayDiff,
} from "./CalendarRule";

describe("CalendarRule", () => {
  it("2026-09 은 화요일 시작·42칸", () => {
    const cells = buildMonthCells(2026, 9);
    expect(cells).toHaveLength(42);
    expect(cells[0].ymd).toBe("20260830");
    expect(cells[0].inMonth).toBe(false);
    expect(cells[2].ymd).toBe("20260901");
    expect(cells[2].inMonth).toBe(true);
    expect(cells[2].weekend).toBe(false);
    const sat = cells.find((c) => c.ymd === "20260905");
    expect(sat?.weekend).toBe(true);
  });

  it("월 이동이 해를 넘긴다", () => {
    expect(shiftYearMonth("202601", -1)).toBe("202512");
    expect(shiftYearMonth("202512", 1)).toBe("202601");
    expect(parseYearMonth("202609")).toEqual({ year: 2026, month: 9 });
    expect(formatYearMonth(2026, 9)).toBe("202609");
  });

  it("전환 diff 는 추가 Y·해제 N", () => {
    const saved = new Set(["20260905"]);
    const current = new Set(["20260906"]);
    expect(workdayDiff(saved, current)).toEqual([
      { ymd: "20260905", workYn: "N" },
      { ymd: "20260906", workYn: "Y" },
    ]);
  });

  it("공휴일은 주말이 아니어도 전환 대상", () => {
    const cells = buildMonthCells(2026, 3);
    const day = cells.find((c) => c.ymd === "20260302");
    expect(day).toBeDefined();
    expect(canOverride(day!, new Set(["20260302"]))).toBe(true);
  });

  it("톤은 완료·밀림·내 담당·오늘 할 일·그 외 순", () => {
    const now = new Date(2026, 8, 3, 12, 0, 0);
    expect(taskTone({ status: "APV", mine: true }, now)).toBe("done");
    expect(taskTone({ status: "LATE", mine: true }, now)).toBe("overdue");
    expect(taskTone({ status: "TODO", dueDt: "20260902", dueTime: "0900", mine: true }, now)).toBe("overdue");
    expect(taskTone({ status: "TODO", dueDt: "20260903", dueTime: "1800", mine: true }, now)).toBe("mine");
    expect(taskTone({ status: "TODO", dueDt: "20260903", dueTime: "1800", baseDt: "20260903", mine: false }, now)).toBe("today");
    expect(taskTone({ status: "TODO", dueDt: "20260905", dueTime: "1800", baseDt: "20260905", mine: false }, now)).toBe("other");
  });

  it("셀 정렬은 내 담당 밀림 → 내 담당 → 타인 밀림 → 나머지", () => {
    const now = new Date(2026, 8, 3, 12, 0, 0);
    const mineOk = { status: "TODO", dueDt: "20260903", dueTime: "1800", mine: true, taskIdx: 3 };
    const mineLate = { status: "TODO", dueDt: "20260901", dueTime: "0900", mine: true, taskIdx: 5 };
    const overdueOther = { status: "TODO", dueDt: "20260901", dueTime: "1000", mine: false, taskIdx: 1 };
    const other = { status: "TODO", dueDt: "20260905", dueTime: "1200", mine: false, taskIdx: 2 };
    const done = { status: "APV", dueDt: "20260902", dueTime: "1000", mine: false, taskIdx: 4 };
    const sorted = [other, done, overdueOther, mineOk, mineLate].sort((a, b) => compareCalendarTask(a, b, now));
    // 내밀림(5) → 내담당(3) → 타인밀림(1) → 나머지(due 빠른 완료 4, 그다음 타인 2)
    expect(sorted.map((t) => t.taskIdx)).toEqual([5, 3, 1, 4, 2]);
  });

  it("더블클릭은 담당 없음·본인·mine — 밀림·오늘 할 일 색이어도 연다", () => {
    expect(canOpenCalendarTask({ status: "TODO", userId: null, mine: false }, "me")).toBe(true);
    expect(canOpenCalendarTask({ status: "LATE", userId: "me", mine: true }, "me")).toBe(true);
    expect(canOpenCalendarTask({ status: "TODO", userId: "me", mine: true }, "me")).toBe(true);
    expect(canOpenCalendarTask({ status: "TODO", userId: "other", mine: false }, "me")).toBe(false);
    expect(canOpenCalendarTask({ status: "TODO", userId: "other", mine: true }, "me")).toBe(true);
    expect(canOpenCalendarTask({ status: "APV", userId: null, mine: false, docIdx: 10 }, "me")).toBe(true);
    expect(canOpenCalendarTask({ status: "APV", userId: "me", mine: true, docIdx: 10 }, "me")).toBe(true);
    expect(canOpenCalendarTask({ status: "APV", userId: "me", mine: true }, "me")).toBe(false);
    expect(canOpenCalendarTask({ status: "APV", userId: "other", mine: false, docIdx: 10 }, "me")).toBe(false);
  });
});
