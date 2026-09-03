/**
 * TodayTasksRule.test — 오늘 할 일 상태 라벨·배지 맵 단위 테스트.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) TASK 와 CA 가 같은 ING 코드를 쓴다. 라벨이 바뀌면 그리드가 코드를 그대로 찍는다
 *   2) CA 문구는 공통코드 맵을 그대로 따른다 — 시드 미조치/조치중/완료
 *   3) 문서 배지 키 WRK 가 빠지면 작성중 칸이 회색이 아니게 된다
 */
import { describe, expect, it } from "vitest";
import { DOC_STATUS_BADGE } from "@/lib/docStatus";
import {
  DOC_PAGE_SIZE,
  KPI_DEFS,
  RECENT_DOC_DAYS,
  TASK_GRID_STATUS_BADGE,
  TASK_TYPE_NM,
  buildDocColumns,
  buildTaskColumns,
  compareTodayTask,
  filterTodayTasks,
  formatHeaderUpdatedAt,
  isCaTask,
  isDoneWriteTask,
  isIncompleteTodayTask,
  isOpenCaTask,
  isOpenWriteTask,
  isOverdueDueDt,
  isOverdueTodayTask,
  pageCount,
  pageOffset,
  recentDocRange,
  sessionRoleLabel,
  sessionWho,
  taskStatusLabel,
  todayTaskHref,
} from "./TodayTasksRule";

const CA_NM: Record<string, string> = {
  OPEN: "미조치",
  ING: "조치중",
  DONE: "완료",
};

describe("isCaTask", () => {
  it("CA 만 개선조치로 본다", () => {
    expect(isCaTask("CA")).toBe(true);
    expect(isCaTask("ca")).toBe(true);
    expect(isCaTask("TASK")).toBe(false);
    expect(isCaTask(undefined)).toBe(false);
  });
});

describe("isOpenWriteTask · isDoneWriteTask", () => {
  it("미완료 작성과제만 오늘 작성 과제다", () => {
    expect(isOpenWriteTask("TASK", "TODO")).toBe(true);
    expect(isOpenWriteTask("TASK", "ING")).toBe(true);
    expect(isOpenWriteTask("TASK", "LATE")).toBe(true);
    expect(isOpenWriteTask("TASK", "APV")).toBe(false);
    expect(isOpenWriteTask("CA", "OPEN")).toBe(false);
  });

  it("승인완료 작성과제만 오늘 완료한 과제다", () => {
    expect(isDoneWriteTask("TASK", "APV")).toBe(true);
    expect(isDoneWriteTask("TASK", "TODO")).toBe(false);
    expect(isDoneWriteTask("CA", "DONE")).toBe(false);
  });
});

describe("개선조치 미완료 · 기한경과 정렬", () => {
  it("조치내용이 있으면 미완료가 아니다", () => {
    expect(isOpenCaTask("CA", "OPEN", "")).toBe(true);
    expect(isOpenCaTask("CA", "OPEN", "  ")).toBe(true);
    expect(isOpenCaTask("CA", "OPEN", "세척 재실시")).toBe(false);
    expect(isOpenCaTask("CA", "DONE", "")).toBe(false);
    expect(isIncompleteTodayTask({ taskType: "CA", status: "OPEN", content: "세척 재실시" })).toBe(false);
    expect(isIncompleteTodayTask({ taskType: "TASK", status: "TODO" })).toBe(true);
    expect(isIncompleteTodayTask({ taskType: "TASK", status: "APV" })).toBe(false);
  });

  it("전날 마감이 기한경과이고 맨 앞이다", () => {
    expect(isOverdueDueDt("20260825", "20260826")).toBe(true);
    expect(isOverdueDueDt("20260826", "20260826")).toBe(false);
    expect(isOverdueDueDt("", "20260826")).toBe(false);
    expect(isOverdueTodayTask({ taskType: "TASK", status: "LATE", dueDt: "20260826" }, "20260826")).toBe(true);
    const overdue = { dueDt: "20260825", dueTime: "1800", taskIdx: 2, status: "LATE", taskType: "TASK" };
    const today = { dueDt: "20260826", dueTime: "0900", taskIdx: 1, status: "TODO", taskType: "TASK" };
    expect(compareTodayTask(overdue, today, "20260826")).toBeLessThan(0);
  });

  it("미완료만 보기면 APV·조치내용 있는 CA 를 뺀다", () => {
    const rows = [
      { taskType: "TASK", status: "TODO", title: "작성" },
      { taskType: "TASK", status: "APV", title: "완료" },
      { taskType: "CA", status: "OPEN", content: "", title: "미조치" },
      { taskType: "CA", status: "OPEN", content: "조치함", title: "내용있음" },
    ];
    expect(filterTodayTasks(rows, "ALL", true).map((r) => r.title)).toEqual(["작성", "미조치"]);
    expect(filterTodayTasks(rows, "ALL", false).map((r) => r.title)).toEqual([
      "작성", "완료", "미조치", "내용있음",
    ]);
  });

  it("문서가 없으면 예정이든 지연이든 행추가 쿼리다", () => {
    // 지연도 아직 안 쓴 과제다 — 목록만 열면 양식·일자를 손으로 다시 골라야 한다
    const late = todayTaskHref({
      taskType: "TASK",
      status: "LATE",
      tmplCd: "tml_ccp_chk_001",
      baseDt: "20260826",
      title: "맞춤",
    });
    const lateQ = new URLSearchParams(late.slice(late.indexOf("?") + 1));
    expect(late.startsWith("/draft/html/ccp-verify?")).toBe(true);
    expect(lateQ.get("add")).toBe("1");
    expect(lateQ.get("baseDt")).toBe("20260826");
    const todo = todayTaskHref({
      taskType: "TASK",
      status: "TODO",
      tmplCd: "tml_ccp_chk_001",
      baseDt: "20260826",
      title: "맞춤",
    });
    const todoQ = new URLSearchParams(todo.slice(todo.indexOf("?") + 1));
    expect(todo.startsWith("/draft/html/ccp-verify?")).toBe(true);
    expect(todoQ.get("add")).toBe("1");
    expect(todoQ.get("tmplCd")).toBe("tml_ccp_chk_001");
    expect(todoQ.get("baseDt")).toBe("20260826");
    expect(todoQ.get("tmplNm")).toBe("맞춤");
    expect(todayTaskHref({
      taskType: "TASK",
      status: "APV",
      tmplCd: "tml_ccp_chk_001",
      docIdx: 99,
    })).toBe("/draft/html/ccp-verify?docIdx=99");
    expect(todayTaskHref({ taskType: "CA" })).toBe("/flow/ca/corrective-action-management");
    // HWP 도 문서가 없으면 행추가다 — 양식코드는 content 로 와도 읽는다
    expect(todayTaskHref({
      taskType: "TASK",
      content: "hwp_sys_002",
    })).toBe("/draft/hwp-doc/hwp-write?add=1&tmplCd=hwp_sys_002");
    // 양식코드가 없으면 갈 곳을 못 찾는다 — 빈 문자열이면 화면이 이동을 생략한다
    expect(todayTaskHref({ taskType: "TASK" })).toBe("");
  });
});

describe("taskStatusLabel — TASK/CA 맵 선택", () => {
  it("과제 APV 는 승인완료", () => {
    expect(taskStatusLabel("TASK", "APV", CA_NM)).toBe("승인완료");
  });

  it("과제 ING 는 진행 — CA ING(조치중) 와 섞지 않는다", () => {
    expect(taskStatusLabel("TASK", "ING", CA_NM)).toBe("진행");
    expect(taskStatusLabel("CA", "ING", CA_NM)).toBe("조치중");
  });

  it("개선조치 OPEN 은 공통코드 미조치", () => {
    expect(taskStatusLabel("CA", "OPEN", CA_NM)).toBe("미조치");
  });

  it("맵에 없으면 원본 코드를 남긴다", () => {
    expect(taskStatusLabel("TASK", "ZZZ", CA_NM)).toBe("ZZZ");
    expect(taskStatusLabel("CA", "ZZZ", CA_NM)).toBe("ZZZ");
  });
});

describe("배지 키", () => {
  it("문서 WRK 는 빨강 — 작성중 칸", () => {
    expect(DOC_STATUS_BADGE.WRK).toBe("red");
    expect(DOC_STATUS_BADGE.REQ).toBe("blue");
    expect(DOC_STATUS_BADGE.RJT).toBe("purple");
  });

  it("오늘 할 일 한글 라벨로도 색을 고른다", () => {
    expect(TASK_GRID_STATUS_BADGE["예정"]).toBe("gray");
    expect(TASK_GRID_STATUS_BADGE["승인완료"]).toBe("green");
    expect(TASK_GRID_STATUS_BADGE["미조치"]).toBe("dash");
    expect(TASK_TYPE_NM.TASK).toBe("작성과제");
    expect(TASK_TYPE_NM.CA).toBe("개선조치");
  });
});

describe("KPI_DEFS", () => {
  it("다섯 장 라벨이다", () => {
    expect(KPI_DEFS.map((kpi) => kpi.label)).toEqual([
      "오늘 작성 과제",
      "과제 완료",
      "미결재",
      "이탈·개선조치",
      "최근 문서",
    ]);
  });
});

describe("컬럼 팩터리", () => {
  it("오늘 할 일 상태 칸은 statusNm 배지", () => {
    const statusCol = buildTaskColumns().find((col) => col.field === "statusNm");
    expect(statusCol?.header).toBe("상태");
    expect(statusCol?.badge).toBe(TASK_GRID_STATUS_BADGE);
  });

  it("업무 칸은 더블클릭 이동이라 버튼이 없다", () => {
    const titleCol = buildTaskColumns().find((col) => col.field === "title");
    expect(titleCol?.cellButton).toBeUndefined();
  });

  it("최근 문서 상태는 DOC_STATUS 맵+배지", () => {
    const cols = buildDocColumns({ WRK: "작성중" });
    expect(cols.map((c) => c.field)).toEqual(["status", "tmplNm", "title", "docNo", "baseDt"]);
    const statusCol = cols.find((col) => col.field === "status");
    expect(statusCol?.type).toBe("code");
    expect(statusCol?.codeMap).toEqual({ WRK: "작성중" });
    expect(statusCol?.badge).toBe(DOC_STATUS_BADGE);
  });
});

describe("recentDocRange", () => {
  it("오늘을 포함해 7일이다", () => {
    expect(RECENT_DOC_DAYS).toBe(7);
    expect(recentDocRange("20260825")).toEqual({ fromDt: "20260819", toDt: "20260825" });
  });

  it("월·연 경계를 넘는다", () => {
    expect(recentDocRange("20260801")).toEqual({ fromDt: "20260726", toDt: "20260801" });
    expect(recentDocRange("20260101")).toEqual({ fromDt: "20251226", toDt: "20260101" });
  });
});

describe("pageOffset · pageCount", () => {
  it("1페이지 OFFSET 은 0, 2페이지는 20이다", () => {
    expect(DOC_PAGE_SIZE).toBe(20);
    expect(pageOffset(1, 20)).toBe(0);
    expect(pageOffset(2, 20)).toBe(20);
  });

  it("총건수 0 이면 1페이지로 본다", () => {
    expect(pageCount(0, 20)).toBe(1);
    expect(pageCount(20, 20)).toBe(1);
    expect(pageCount(21, 20)).toBe(2);
  });
});

describe("sessionWho · sessionRoleLabel", () => {
  it("이름(아이디)로 붙인다", () => {
    expect(sessionWho("소민", "write")).toBe("소민(write)");
  });

  it("ADMIN 만 관리자 배지", () => {
    expect(sessionRoleLabel("ADMIN")).toBe("관리자");
    expect(sessionRoleLabel("admin")).toBe("관리자");
    expect(sessionRoleLabel("USER")).toBe("사용자");
    expect(sessionRoleLabel(null)).toBe("사용자");
  });
});

describe("formatHeaderUpdatedAt", () => {
  it("헤더 시각은 점 구분 YYYY.MM.DD HH:mm", () => {
    expect(formatHeaderUpdatedAt(new Date(2026, 7, 25, 18, 5, 0))).toBe("2026.08.25 18:05");
  });
});
