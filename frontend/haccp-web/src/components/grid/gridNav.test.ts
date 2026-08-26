/**
 * gridNav.test — 행/셀 좌표·입력 가드.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) nextRowIndex 클램프·빈 목록, nextCell 행 넘김·그리드 탈출을 고정한다
 *   2) npm test 로 실행 — 키보드 네비가 어긋나면 이 케이스가 먼저 깨진다
 *   3) 실패하면 방향키 행이동·Tab 셀이동 좌표가 틀린 것이다
 */
// 역할 — Vitest describe·expect·it
import { describe, expect, it } from "vitest";
// 역할 — 그리드 키보드 좌표·입력 가드
import { isTypingTarget, nextCell, nextRowIndex } from "./gridNav";

describe("nextRowIndex", () => {
  it("선택 없음(-1)에서 Down → 0번 행", () => {
    expect(nextRowIndex(5, -1, 1)).toBe(0);
  });
  it("선택 없음(-1)에서 Up → 마지막 행", () => {
    expect(nextRowIndex(5, -1, -1)).toBe(4);
  });
  it("마지막 행에서 Down → 클램프(마지막 유지)", () => {
    expect(nextRowIndex(5, 4, 1)).toBe(4);
  });
  it("첫 행에서 Up → 클램프(0 유지)", () => {
    expect(nextRowIndex(5, 0, -1)).toBe(0);
  });
  it("빈 데이터 → -1", () => {
    expect(nextRowIndex(0, -1, 1)).toBe(-1);
  });
});

describe("nextCell", () => {
  it("일반 이동", () => {
    expect(nextCell(1, 2, 5, 4, 1)).toEqual({ ri: 1, ci: 3 });
  });
  it("열 끝에서 Tab → 다음 행 첫 열", () => {
    expect(nextCell(1, 3, 5, 4, 1)).toEqual({ ri: 2, ci: 0 });
  });
  it("열 처음에서 Shift+Tab → 이전 행 마지막 열", () => {
    expect(nextCell(1, 0, 5, 4, -1)).toEqual({ ri: 0, ci: 3 });
  });
  it("마지막 행 마지막 열 Tab → null(탈출)", () => {
    expect(nextCell(4, 3, 5, 4, 1)).toBeNull();
  });
  it("첫 행 첫 열 Shift+Tab → null(탈출)", () => {
    expect(nextCell(0, 0, 5, 4, -1)).toBeNull();
  });
});

describe("isTypingTarget", () => {
  it("tbody 체크박스는 행이동 허용(false)", () => {
    const table = document.createElement("table");
    table.innerHTML = "<tbody><tr><td><input type=\"checkbox\"></td></tr></tbody>";
    document.body.appendChild(table);
    const input = table.querySelector("input");
    expect(isTypingTarget({ target: input })).toBe(false);
    table.remove();
  });
  it("thead 필터 input은 가로챔(true)", () => {
    const table = document.createElement("table");
    table.innerHTML = "<thead><tr><th><input type=\"text\"></th></tr></thead>";
    document.body.appendChild(table);
    const input = table.querySelector("input");
    expect(isTypingTarget({ target: input })).toBe(true);
    table.remove();
  });
  it("셀·행이 아닌 div는 false", () => {
    const div = document.createElement("div");
    expect(isTypingTarget({ target: div })).toBe(false);
  });
});
