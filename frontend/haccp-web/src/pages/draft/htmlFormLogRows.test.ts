/**
 * htmlFormLogRows.test — 기록 표 행 영역 분리·행 추가/삭제.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 행 추가가 지정한 영역 끝에만 붙어야 한다 — 다른 영역 행 수가 변하면 저장 위치가 어긋난다
 *   2) 재조회 때 phaseCd 로 같은 영역에 복원되는지 본다
 *   3) UI 렌더 없이 순수 함수만 본다
 *
 * PIPELINE[HF177] CCP 모니터링 작성 기록행
 */
// 역할 — vitest 러너
import { describe, expect, it } from "vitest";
// 역할 — 검증 대상 순수 함수
import {
  LOG_PHASE,
  appendLogRow,
  appendPassRow,
  logRowsOf,
  patchLogRow,
  patchPassRow,
  removeLogRow,
  type HtmlFormLogRow,
} from "@/components/form/htmlFormPaperShared";
// 역할 — 서버 cells EAV → 지면 맵
import { cellsToMap } from "@/api/draft/ccpMonitoringDraftApi";

/** 기록 행 1건 — 영역과 순번만 지정 */
function row(rowSeq: number, phaseCd: "BEFORE" | "AFTER"): HtmlFormLogRow {
  return {
    rowSeq,
    phaseCd,
    productNm: "",
    checkTime: "",
    judgeCd: "",
    judgeModYn: "N",
    checkerNm: "",
    signYn: "N",
    cells: {},
  };
}

describe("logRowsOf — 영역 분리", () => {
  const rows = [row(1, "BEFORE"), row(2, "AFTER"), row(3, "BEFORE")];

  it("작업 전 행만 순번대로 뽑는다", () => {
    expect(logRowsOf(rows, LOG_PHASE.BEFORE).map((r) => r.rowSeq)).toEqual([1, 3]);
  });

  it("작업 종료 행만 뽑는다", () => {
    expect(logRowsOf(rows, LOG_PHASE.AFTER).map((r) => r.rowSeq)).toEqual([2]);
  });

  it("기준관리 미리보기는 기록행이 없어 빈 배열이다", () => {
    expect(logRowsOf(undefined, LOG_PHASE.BEFORE)).toEqual([]);
  });
});

describe("appendLogRow — 지정 영역 끝에만 붙는다", () => {
  const rows = [row(1, "BEFORE"), row(2, "AFTER")];

  it("작업 전에 붙여도 작업 종료 행 수는 그대로다", () => {
    const next = appendLogRow(rows, LOG_PHASE.BEFORE);
    expect(logRowsOf(next, LOG_PHASE.BEFORE)).toHaveLength(2);
    expect(logRowsOf(next, LOG_PHASE.AFTER)).toHaveLength(1);
  });

  it("작업 종료에 붙여도 작업 전 행 수는 그대로다", () => {
    const next = appendLogRow(rows, LOG_PHASE.AFTER);
    expect(logRowsOf(next, LOG_PHASE.BEFORE)).toHaveLength(1);
    expect(logRowsOf(next, LOG_PHASE.AFTER)).toHaveLength(2);
  });

  it("새 행 순번은 전체 최대값+1 — 영역이 섞여도 겹치지 않는다", () => {
    const next = appendLogRow(rows, LOG_PHASE.BEFORE);
    expect(next[next.length - 1].rowSeq).toBe(3);
  });
});

describe("patchLogRow · removeLogRow", () => {
  const rows = [row(1, "BEFORE"), row(2, "AFTER")];

  it("cells 는 병합한다 — 다른 칸 값이 날아가지 않는다", () => {
    const a = patchLogRow(rows, 1, { cells: { temp: "4" } });
    const b = patchLogRow(a, 1, { cells: { min: "10" } });
    expect(b[0].cells).toEqual({ temp: "4", min: "10" });
  });

  it("다른 영역의 같은 칸은 건드리지 않는다", () => {
    const next = patchLogRow(rows, 1, { productNm: "돈육" });
    expect(next[0].productNm).toBe("돈육");
    expect(next[1].productNm).toBe("");
  });

  it("행 삭제는 그 순번만 뺀다", () => {
    expect(removeLogRow(rows, 1).map((r) => r.rowSeq)).toEqual([2]);
  });
});

describe("cellsToMap — SP EAV 배열을 지면 맵으로", () => {
  it("itemCd → numVal, 숫자가 없으면 txtVal", () => {
    expect(cellsToMap([
      { itemCd: "temp", numVal: 4, txtVal: "" },
      { itemCd: "min", numVal: "", txtVal: "10" },
    ])).toEqual({ temp: "4", min: "10" });
  });
});

describe("통과량 표 — 금속검출 두 번째 표", () => {
  it("행 추가는 끝에 붙고 순번은 최대값+1", () => {
    const next = appendPassRow([
      { rowSeq: 1, productNm: "", passQty: "", detectQty: "", remark: "" },
    ]);
    expect(next).toHaveLength(2);
    expect(next[1].rowSeq).toBe(2);
  });

  it("칸 수정은 그 행만 바꾼다", () => {
    const rows = [
      { rowSeq: 1, productNm: "", passQty: "", detectQty: "", remark: "" },
      { rowSeq: 2, productNm: "", passQty: "", detectQty: "", remark: "" },
    ];
    const next = patchPassRow(rows, 2, { passQty: "100" });
    expect(next[0].passQty).toBe("");
    expect(next[1].passQty).toBe("100");
  });
});
