/**
 * hwpOpenMode.test — 저장된 문서에 빈 양식 원본을 열지 않는지.
 *
 * 개발자: 박승우
 * 일자: 2026-09-01
 * 코멘트:
 *   1) docIdx 있는데 첨부가 없으면 wait — 원본 금지
 *   2) 신규(docIdx 없음)만 template
 *   3) HWP_SRC 가 있으면 source
 *
 * PIPELINE[HF186] HWP 열기 판정
 */
import { describe, expect, it } from "vitest";
import { hwpOpenMode } from "./hwpOpenMode";

describe("hwpOpenMode", () => {
  it("저장된 문서인데 첨부가 없으면 기다린다", () => {
    expect(hwpOpenMode(12, false)).toBe("wait");
  });

  it("신규 행은 양식 원본을 연다", () => {
    expect(hwpOpenMode(null, false)).toBe("template");
    expect(hwpOpenMode(0, false)).toBe("template");
  });

  it("본문 첨부가 있으면 작성본을 연다", () => {
    expect(hwpOpenMode(12, true)).toBe("source");
    expect(hwpOpenMode(null, true)).toBe("source");
  });
});
