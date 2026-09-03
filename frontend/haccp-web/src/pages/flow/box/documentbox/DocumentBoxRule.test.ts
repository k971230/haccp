/**
 * DocumentBoxRule.test — 결재 스테퍼 칸 색·정렬 단위 테스트.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 대기 중 가장 앞 칸만 현재로 칠한다 — 뒤 칸을 같이 파랗게 칠하면 진행이 끝난 것처럼 보인다
 *   2) 반려는 rejected(빨강), 승인은 파랑 완료다
 *   3) stepNo 가 뒤섞여 와도 칸 순서는 단계 번호다
 */
import { describe, expect, it } from "vitest";
import type { DocumentApprovalRow } from "@/api/documentApi";
import { toDisplayDateOnly } from "@/lib/docDateTime";
import { approvalLineToneOf, buildApprovalLineSteps } from "./DocumentBoxRule";

describe("approvalLineToneOf — 결재 칸 색", () => {
  it("승인(A)은 완료, 반려(R)는 반려다", () => {
    expect(approvalLineToneOf(["A", "R"], 0)).toBe("done");
    expect(approvalLineToneOf(["A", "R"], 1)).toBe("rejected");
  });

  it("대기(W) 중 가장 앞만 현재, 나머지는 대기다", () => {
    expect(approvalLineToneOf(["A", "W", "W"], 1)).toBe("active");
    expect(approvalLineToneOf(["A", "W", "W"], 2)).toBe("pending");
  });

  it("전부 승인이면 모두 완료다", () => {
    expect(approvalLineToneOf(["A", "A"], 0)).toBe("done");
    expect(approvalLineToneOf(["A", "A"], 1)).toBe("done");
  });
});

describe("buildApprovalLineSteps — 단계 번호 순", () => {
  it("stepNo 가 뒤섞여 있어도 작은 번호가 앞 칸이다", () => {
    const rows: DocumentApprovalRow[] = [
      { idx: 2, stepNo: 2, roleCd: "APPROVE", resultCd: "W", approverNm: "팀장" },
      { idx: 1, stepNo: 1, roleCd: "WRITE", resultCd: "A", approverNm: "작성자" },
    ];
    const steps = buildApprovalLineSteps(rows, (cd) => cd, (cd) => cd);
    expect(steps.map((s) => s.key)).toEqual(["1", "2"]);
    expect(steps[0].tone).toBe("done");
    expect(steps[1].tone).toBe("active");
    expect(steps[0].caption).toBe("작성자");
  });

  it("처리일은 시각 없이 날짜만 붙인다", () => {
    const rows: DocumentApprovalRow[] = [
      {
        idx: 1,
        stepNo: 1,
        roleCd: "APPROVE",
        resultCd: "A",
        approverNm: "시스템관리자",
        actDt: "2026-09-03T16:26:00",
      },
    ];
    const steps = buildApprovalLineSteps(rows, () => "승인", (cd) => (cd === "A" ? "승인" : cd), toDisplayDateOnly);
    expect(steps[0].detail).toBe("승인 · 2026-09-03");
    expect(steps[0].detail).not.toContain("16:26");
  });
});
