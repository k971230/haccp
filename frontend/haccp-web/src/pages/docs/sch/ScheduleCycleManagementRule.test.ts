/**
 * ScheduleCycleManagementRule.test — 문서주기 저장 필수값.
 *
 * 개발자: 박승우
 * 일자: 2026-08-29
 * 코멘트:
 *   1) DB 가 NULL 을 받는 칸(결재선·담당자)을 화면이 막는지 본다 —
 *      비면 저장은 되는데 일지가 아무 결재함에도 안 가고 누구의 할 일에도 안 뜬다
 *   2) 결재선은 「고른 결재선에 승인 결재자가 있는가」까지 본다.
 *      결재선관리는 두 걸음으로 만들어서 결재자 없는 결재선이 목록에 있는 게 정상이다
 *   3) 순서가 곧 사람이 채우는 순서다 — 앞 칸이 비면 뒤 칸은 안 본다
 */
import { describe, expect, it } from "vitest";
import { emptyForm, formToDetails, validateCycleSave, type CycleForm } from "./ScheduleCycleManagementRule";

/** 승인 결재자가 제대로 든 결재선 */
const okSteps = [
  { roleCd: "WRITE", approverId: "usr01" },
  { roleCd: "APPROVE", approverId: "mgr01" },
];

/** 다 채운 폼 — 시험마다 한 칸씩 비운다 */
function filled(over: Partial<CycleForm> = {}): CycleForm {
  return { ...emptyForm(), apprLineCd: "DEFAULT", userId: "usr01", ...over };
}

describe("문서주기 저장 필수값", () => {
  it("다 채우면 통과한다", () => {
    expect(validateCycleSave(filled(), okSteps)).toBeNull();
  });

  it("관리 시작일이 비면 막는다", () => {
    expect(validateCycleSave(filled({ baseDt: "" }), okSteps)).toContain("관리 시작일");
  });

  it("결재선이 비면 막는다", () => {
    const msg = validateCycleSave(filled({ apprLineCd: "" }), okSteps);
    expect(msg, "비면 올린 일지가 아무 결재함에도 안 간다").toContain("결재선");
  });

  it("담당자가 비면 막는다", () => {
    const msg = validateCycleSave(filled({ userId: "" }), okSteps);
    expect(msg, "비면 그 과제가 누구의 오늘 할 일에도 안 뜬다").toContain("담당자");
  });

  /*
   * 결재선을 골랐어도 그 결재선에 승인 결재자가 없으면 결재가 안 간다.
   * 결재선관리에서는 그 상태로 저장되는 게 정상이라(두 걸음) 쓰는 자리인 여기서 막는다.
   */
  it("승인 결재자가 없는 결재선을 고르면 막는다", () => {
    const msg = validateCycleSave(filled(), [{ roleCd: "WRITE", approverId: "usr01" }]);
    expect(msg).toContain("승인 결재자");
  });

  it("결재선 단계를 아예 못 받아도 막는다", () => {
    expect(validateCycleSave(filled(), undefined)).toContain("승인 결재자");
  });

  it("매주인데 요일을 안 고르면 막는다", () => {
    expect(validateCycleSave(filled({ cycleCd: "W", weekDays: [] }), okSteps)).toContain("요일");
  });

  it("매월인데 실행일도 말일도 없으면 막는다", () => {
    const form = filled({ cycleCd: "M", monthDays: [], monthEnd: false });
    expect(validateCycleSave(form, okSteps)).toContain("실행일");
  });

  it("매월이어도 말일을 고르면 통과한다", () => {
    const form = filled({ cycleCd: "M", monthDays: [], monthEnd: true });
    expect(validateCycleSave(form, okSteps)).toBeNull();
  });

  it("분기 말일이면 실행일 sentinel은 0이다", () => {
    const rows = formToDetails(filled({
      cycleCd: "Q",
      periodMonth: 2,
      periodDay: 31,
      monthEnd: true,
    }));
    expect(rows).toEqual([{ detailTy: "quarter-month", val1: 2, val2: 0 }]);
  });
});
