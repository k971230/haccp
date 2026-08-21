/**
 * tabRoute.test — 계층 경로 ↔ scrnCd 왕복.
 *
 * 개발자: 박승우
 * 일자: 2026-08-21
 * 코멘트:
 *   1) 레지스트리 화면이 모두 SCREEN_PATH 에 있는지, 왕복이 깨지지 않는지 고정한다
 *   2) npm test 로 실행한다
 *   3) 실패하면 메뉴 클릭·새로고침이 다른 화면으로 떨어질 수 있다
 */
import { describe, expect, it } from "vitest";
import { SCREEN_REGISTRY } from "@/shell/screenRegistry";
import { SCREEN_PATH, parseRoute, routeOf } from "@/shell/tabRoute";

describe("tabRoute — 계층 경로", () => {
  it("레지스트리 키마다 SCREEN_PATH 가 있고 왕복한다", () => {
    for (const scrnCd of Object.keys(SCREEN_REGISTRY)) {
      expect(SCREEN_PATH[scrnCd], scrnCd).toBeDefined();
      expect(parseRoute(routeOf(scrnCd))).toBe(scrnCd);
    }
  });

  it("맵 키는 레지스트리에만 있다", () => {
    for (const scrnCd of Object.keys(SCREEN_PATH)) {
      expect(SCREEN_REGISTRY[scrnCd], scrnCd).toBeDefined();
    }
  });

  it("사용자 예시 경로가 맞다", () => {
    expect(routeOf("today-tasks")).toBe("/today-tasks");
    expect(routeOf("schedule-cycle-management")).toBe("/docs/sch/schedule-cycle-management");
    expect(routeOf("hwp-template-management")).toBe("/docs/hwp/hwp-template-management");
    expect(routeOf("hyg-process-template")).toBe("/docs/html/hyg-process-template");
    expect(routeOf("hygiene-process-check")).toBe("/docs/prp/hygiene-process-check");
    expect(routeOf("calibration-target-management")).toBe("/docs/prp/calibration-target-management");
    expect(routeOf("common-code-management")).toBe("/sys/code/common-code-management");
    expect(routeOf("menu-management")).toBe("/sys/code/menu-management");
    expect(routeOf("role-management")).toBe("/sys/code/role-management");
    expect(routeOf("user-management")).toBe("/sys/code/user-management");
    expect(routeOf("department-management")).toBe("/sys/code/department-management");
    expect(routeOf("approval-line-management")).toBe("/sys/code/approval-line-management");
    expect(routeOf("login-history")).toBe("/sys/logs/login-history");
    expect(routeOf("screen-usage-statistics")).toBe("/sys/logs/screen-usage-statistics");
    expect(routeOf("audit-log")).toBe("/sys/logs/audit-log");
  });

  it("끝 슬래시·쿼리는 화면코드 판정에 영향을 주지 않는다", () => {
    expect(parseRoute("/sys/logs/audit-log/")).toBe("audit-log");
    expect(routeOf("document-inbox", { docIdx: 12 })).toBe("/flow/box/document-inbox?docIdx=12");
  });

  it("옛 /screen 과 위조 접두는 열지 않는다", () => {
    expect(parseRoute("/screen/login-history")).toBeNull();
    expect(parseRoute("/sch/schedule-cycle-management")).toBeNull();
    expect(parseRoute("/sys/log/audit-log")).toBeNull();
    expect(parseRoute("/docs/hwp/audit-log")).toBeNull();
    expect(parseRoute("/sys/logs/hyg-process-template")).toBeNull();
    expect(parseRoute("/")).toBeNull();
  });

  it("경로에 basename /haccp/ 가 섞이지 않는다", () => {
    for (const p of Object.values(SCREEN_PATH)) {
      expect(p).not.toContain("/haccp/");
    }
  });

  it("빈 코드는 홈, 없는 코드는 오늘 할 일", () => {
    expect(routeOf("")).toBe("/");
    expect(routeOf("not-a-screen")).toBe("/today-tasks");
  });
});
