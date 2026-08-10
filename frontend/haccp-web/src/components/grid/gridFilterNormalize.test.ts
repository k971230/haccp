// 역할 — Vitest describe·expect·it
import { describe, expect, it } from "vitest";
// 역할 — 필터 문자열 정규화 함수
import { normalizeFilterText } from "./gridFilterNormalize";

describe("normalizeFilterText", () => {
  it("콤마 제거", () => {
    expect(normalizeFilterText("1,234")).toBe("1234");
    expect(normalizeFilterText("1,234,567.8")).toBe("1234567.8");
  });

  it("소문자 변환", () => {
    expect(normalizeFilterText("ABC")).toBe("abc");
    expect(normalizeFilterText("AbC")).toBe("abc");
  });

  it("콤마 + 대소문자 동시", () => {
    expect(normalizeFilterText("Lot-A,1")).toBe("lot-a1");
  });

  it("빈 문자열", () => {
    expect(normalizeFilterText("")).toBe("");
  });
});
