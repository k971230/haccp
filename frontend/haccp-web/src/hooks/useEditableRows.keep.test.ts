/**
 * useEditableRows.keep.test — 저장 후 선택 유지 (첫 행 점프 금지).
 *
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) pickKeptRow 가 _key·업무키로 같은 행을 찾고, 없으면 null 인지 고정한다
 *   2) npm test 로 실행 — 마스터-디테일 저장 후 좌측 포커스 회귀 방지
 *   3) 실패하면 저장 뒤 선택이 첫 행으로 떨어진다
 */
import { describe, expect, it } from "vitest";
import { pickKeptRow } from "./useEditableRows";
import type { EditableRow } from "@/types/editable";

type Line = { apprLineCd: string; apprLineNm: string };

function row(cd: string, key?: string): EditableRow<Line> {
  return { apprLineCd: cd, apprLineNm: cd, _key: key ?? cd };
}

describe("pickKeptRow", () => {
  const mapped = [row("DEFAULT"), row("LINE-2"), row("LINE-3")];

  it("업무키로 2번째 행을 유지한다", () => {
    const hit = pickKeptRow(mapped, "apprLineCd", "LINE-2");
    expect(hit?._key).toBe("LINE-2");
  });

  it("신규행 _key(__new_) 대신 저장 후 업무키로 찾는다", () => {
    const hit = pickKeptRow(mapped, "apprLineCd", "LINE-3");
    expect(hit?.apprLineCd).toBe("LINE-3");
  });

  it("키가 없거나 목록에 없으면 첫 행이 아니라 null", () => {
    expect(pickKeptRow(mapped, "apprLineCd", null)).toBeNull();
    expect(pickKeptRow(mapped, "apprLineCd", "")).toBeNull();
    expect(pickKeptRow(mapped, "apprLineCd", "GONE")).toBeNull();
  });
});
