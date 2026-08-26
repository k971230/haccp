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
  RECENT_DOC_DAYS,
  TASK_GRID_STATUS_BADGE,
  TASK_TYPE_NM,
  buildDocColumns,
  buildTaskColumns,
  formatHeaderUpdatedAt,
  isCaTask,
  pageCount,
  pageOffset,
  recentDocRange,
  sessionRoleLabel,
  sessionWho,
  taskStatusLabel,
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

describe("taskStatusLabel — TASK/CA 맵 선택", () => {
  it("과제 TODO 는 예정", () => {
    expect(taskStatusLabel("TASK", "TODO", CA_NM)).toBe("예정");
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
  it("문서 WRK 는 회색 — 작성중 칸", () => {
    expect(DOC_STATUS_BADGE.WRK).toBe("gray");
    expect(DOC_STATUS_BADGE.REQ).toBe("blue");
  });

  it("오늘 할 일 한글 라벨로도 색을 고른다", () => {
    expect(TASK_GRID_STATUS_BADGE["예정"]).toBe("gray");
    expect(TASK_GRID_STATUS_BADGE["미조치"]).toBe("dash");
    expect(TASK_TYPE_NM.TASK).toBe("작성과제");
    expect(TASK_TYPE_NM.CA).toBe("개선조치");
  });
});

describe("컬럼 팩터리", () => {
  it("오늘 할 일 상태 칸은 statusNm 배지", () => {
    const statusCol = buildTaskColumns().find((col) => col.field === "statusNm");
    expect(statusCol?.header).toBe("상태");
    expect(statusCol?.badge).toBe(TASK_GRID_STATUS_BADGE);
  });

  it("최근 문서 상태는 DOC_STATUS 맵+배지", () => {
    const statusCol = buildDocColumns({ WRK: "작성중" }).find((col) => col.field === "status");
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
