/**
 * gridPref.test — 그리드 열 설정 파싱·직렬화 단위 테스트.
 *
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 저장한 열 폭·순서·숨김이 그대로 되살아나는지 본다
 *   2) 저장 형식을 고칠 때 함께 돌린다 — 형식이 바뀌면 사용자 설정이 날아간다
 *   3) DB·기동 없이 순수 함수만 검사한다
 */
// 역할 — Vitest describe·expect·it
import { describe, expect, it } from "vitest";
// 역할 — 그리드 pref 파싱·직렬화
import { parseGridPref, serializeGridPref } from "./gridPref";

describe("parseGridPref", () => {
  it("빈 문자열·null → 빈 객체", () => {
    expect(parseGridPref("")).toEqual({ hidden: {}, order: [], sizing: {} });
    expect(parseGridPref(null)).toEqual({ hidden: {}, order: [], sizing: {} });
    expect(parseGridPref(undefined)).toEqual({ hidden: {}, order: [], sizing: {} });
  });

  it("v1 또는 v 없음 → hidden만", () => {
    expect(parseGridPref(JSON.stringify({ hidden: { A: true } }))).toEqual({
      hidden: { A: true },
      order: [],
      sizing: {},
    });
    expect(parseGridPref(JSON.stringify({ v: 1, hidden: { B: true }, order: ["B"] }))).toEqual({
      hidden: { B: true },
      order: [],
      sizing: {},
    });
  });

  it("v2 → hidden + order + sizing", () => {
    const raw = JSON.stringify({
      v: 2,
      hidden: { X: true },
      order: ["A", "B"],
      sizing: { A: 140, B: 40 },
    });
    expect(parseGridPref(raw)).toEqual({
      hidden: { X: true },
      order: ["A", "B"],
      sizing: { A: 140 }, // 50 미만 제외
    });
  });

  it("손상 JSON → 빈 객체", () => {
    expect(parseGridPref("{not json")).toEqual({ hidden: {}, order: [], sizing: {} });
  });
});

describe("serializeGridPref", () => {
  it("v:2 로 직렬화", () => {
    const s = serializeGridPref({
      hidden: { A: true },
      order: ["A", "B"],
      sizing: { A: 120 },
    });
    expect(JSON.parse(s)).toEqual({
      v: 2,
      hidden: { A: true },
      order: ["A", "B"],
      sizing: { A: 120 },
    });
  });
});
