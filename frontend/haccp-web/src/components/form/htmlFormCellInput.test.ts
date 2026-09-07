/**
 * htmlFormCellInput.test — 지면 입력칸 값 허용 규칙 검증.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 숫자칸에 한글·기호가 들어가면 값이 조용히 사라진다 — 그 경로를 값으로 막는다
 *   2) 규칙이 흔들리면 이 테스트가 먼저 실패한다
 *   3) 실행: npx vitest run src/components/form/htmlFormCellInput.test.ts
 */
// 역할 — 검증 대상
import { CELL_KIND, cellValueAccepted, clampCellValue } from "./htmlFormPaperShared";
// 역할 — 단정
import { describe, expect, it } from "vitest";

describe("cellValueAccepted", () => {
  it("숫자칸은 숫자·소수점·부호만 받는다", () => {
    expect(cellValueAccepted(CELL_KIND.NUM, "180")).toBe(true);
    expect(cellValueAccepted(CELL_KIND.NUM, "18.5")).toBe(true);
    expect(cellValueAccepted(CELL_KIND.NUM, "-0.1")).toBe(true);
    // 지우는 중간 상태 — 막으면 값을 못 지운다
    expect(cellValueAccepted(CELL_KIND.NUM, "")).toBe(true);
    expect(cellValueAccepted(CELL_KIND.NUM, "-")).toBe(true);
    expect(cellValueAccepted(CELL_KIND.NUM, ".")).toBe(true);
  });

  it("숫자칸에 한글 IME 글자가 들어오면 막는다", () => {
    // 화면에서 실제로 나온 값 — type=number 였을 때 값이 빈 문자열로 사라졌다
    expect(cellValueAccepted(CELL_KIND.NUM, "0.2ㅇ")).toBe(false);
    expect(cellValueAccepted(CELL_KIND.NUM, "1231ㅇ")).toBe(false);
    expect(cellValueAccepted(CELL_KIND.NUM, "ㄹㄹ")).toBe(false);
    // 소수점 두 개·부호 두 개도 숫자가 아니다
    expect(cellValueAccepted(CELL_KIND.NUM, "1.2.3")).toBe(false);
    expect(cellValueAccepted(CELL_KIND.NUM, "--1")).toBe(false);
  });

  it("숫자칸이 아니면 무엇이든 받는다", () => {
    expect(cellValueAccepted(CELL_KIND.TEXT, "고등어살 500g")).toBe(true);
    expect(cellValueAccepted(CELL_KIND.TIME, "09:30")).toBe(true);
    expect(cellValueAccepted(CELL_KIND.DURATION, "00:18:30")).toBe(true);
  });
});

describe("clampCellValue — 지면 문자칸 상한", () => {
  it("상한이 없으면 그대로 둔다", () => {
    expect(clampCellValue("한참 긴 품명", undefined)).toBe("한참 긴 품명");
  });

  it("상한 이하면 그대로 둔다", () => {
    expect(clampCellValue("돼지고기", 100)).toBe("돼지고기");
  });

  it("넘치면 자른다 — 붙여넣기가 maxLength 속성을 지나쳐 온다", () => {
    // 자르지 않으면 저장에서 22001 이 그대로 사용자에게 뜬다
    expect(clampCellValue("가".repeat(150), 100)).toHaveLength(100);
  });

  it("딱 맞으면 안 건드린다", () => {
    const v = "나".repeat(100);
    expect(clampCellValue(v, 100)).toBe(v);
  });
});
