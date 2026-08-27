/**
 * htmlFormJudgeDefault.test — 판정 기본값과 「모두 적합」.
 *
 * 개발자: 박승우
 * 일자: 2026-08-27
 * 코멘트:
 *   1) 현장 기록은 대부분이 적합이다. 빈 값으로 두면 행마다 라디오를 한 번 더 눌러야 한다 —
 *      적합으로 깔고 **부적합만 눌러 고치게** 한다
 *   2) 대신 「적합을 깔아도 되는 자리」를 못 박는다. 판정 칸이 없는 항목이나
 *      표 머리글까지 적합으로 칠하면 저장 자료가 더러워진다
 *   3) 순수 함수만 돌린다 — 화면·서버 없이
 */
import { describe, expect, it } from "vitest";
import {
  allItemsPass,
  allLogRowsPass,
  appendLogRow,
  fillBlankItemJudges,
  fillBlankLogJudges,
  ITEM_YN,
  JUDGE,
  LOG_PHASE,
  type HtmlFormLogRow,
} from "./htmlFormPaperShared";
import type { HtmlFormItem } from "@/api/docs/htmlFormApi";

/** 판정만 다른 기록 행 */
function row(rowSeq: number, judgeCd: string): HtmlFormLogRow {
  return {
    rowSeq,
    phaseCd: LOG_PHASE.BEFORE,
    productNm: "",
    checkTime: "",
    judgeCd,
    checkerNm: "",
    signYn: "N",
    cells: {},
  };
}

/** 입력유형만 다른 점검 항목 */
function item(itemCd: string, inputType: string, yn: string | null = ""): HtmlFormItem {
  return { itemCd, sortNo: 1, cycleNm: "", grpNm: "", itemNm: "항목", inputType, yn };
}

describe("새 기록 행은 적합으로 시작한다", () => {
  it("행을 붙이면 판정이 적합이다", () => {
    const [added] = appendLogRow([], LOG_PHASE.BEFORE);
    expect(added.judgeCd).toBe(JUDGE.PASS);
  });

  it("순번은 그대로 이어 붙는다 — 판정만 바뀐 것이지 다른 규칙은 안 건드렸다", () => {
    const rows = appendLogRow([row(1, JUDGE.FAIL), row(2, JUDGE.PASS)], LOG_PHASE.BEFORE);
    expect(rows).toHaveLength(3);
    expect(rows[2].rowSeq).toBe(3);
    expect(rows[0].judgeCd, "이미 있던 행의 판정을 건드렸다").toBe(JUDGE.FAIL);
  });
});

describe("모두 적합 — 기록 행", () => {
  it("빈 판정도 부적합도 전부 적합이 된다", () => {
    const out = allLogRowsPass([row(1, ""), row(2, JUDGE.FAIL), row(3, JUDGE.PASS)]);
    expect(out.map((r) => r.judgeCd)).toEqual([JUDGE.PASS, JUDGE.PASS, JUDGE.PASS]);
  });

  it("판정 말고는 아무것도 안 바꾼다", () => {
    const before = row(7, JUDGE.FAIL);
    before.productNm = "삼겹살";
    before.checkTime = "1030";
    const [after] = allLogRowsPass([before]);
    expect(after.rowSeq).toBe(7);
    expect(after.productNm).toBe("삼겹살");
    expect(after.checkTime).toBe("1030");
  });

  it("사람이 정한 판정이라고 표시한다 — 금속검출은 이게 있어야 서버 자동판정을 누른다", () => {
    // judge_mod_yn='Y' 가 없으면 sp_tbl_ccp_metal_monitor_c_000 이 감도 5칸으로
    // 다시 계산해 부적합으로 덮는다. 화면에서 누른 적합이 저장에서 사라진다
    const [after] = allLogRowsPass([row(1, JUDGE.FAIL)]);
    expect(after.judgeCd).toBe(JUDGE.PASS);
    expect(after.judgeModYn).toBe("Y");
  });

  it("이미 적합이고 수동 표시까지 있으면 같은 객체를 그대로 둔다 — 헛되이 다시 그리지 않는다", () => {
    const same = { ...row(1, JUDGE.PASS), judgeModYn: "Y" };
    expect(allLogRowsPass([same])[0]).toBe(same);
  });
});

describe("모두 적합 — 점검 항목", () => {
  it("라디오 항목만 적합(예)이 된다", () => {
    const out = allItemsPass([item("a", "radio", ""), item("b", "radio", ITEM_YN.FAIL)]);
    expect(out.map((i) => i.yn)).toEqual([ITEM_YN.PASS, ITEM_YN.PASS]);
  });

  it("판정 칸이 없는 항목은 안 건드린다", () => {
    // 숫자·문자 전용 항목에 yn 을 채우면 저장 자료가 더러워진다
    const out = allItemsPass([item("num", "num", null), item("txt", "text", null)]);
    expect(out.map((i) => i.yn)).toEqual([null, null]);
  });

  it("표 머리글 행은 안 건드린다", () => {
    // 머리글은 점검 항목이 아니다 — 적합으로 칠할 자리가 아니다
    const hdr = item("hdr-title", "radio", "");
    expect(allItemsPass([hdr])[0]).toBe(hdr);
  });

  it("라디오와 값칸이 같이 있는 유형도 적합이 된다", () => {
    const out = allItemsPass([item("rn", "radio-num", ""), item("rt", "radio-text", "")]);
    expect(out.map((i) => i.yn)).toEqual([ITEM_YN.PASS, ITEM_YN.PASS]);
  });
});

describe("지면을 열 때 — 빈 판정만 채운다", () => {
  it("빈 기록행은 적합이 되고 부적합은 그대로다", () => {
    // 저장해 둔 부적합을 적합으로 덮으면 사람이 남긴 판정을 지우는 셈이다
    const out = fillBlankLogJudges([row(1, ""), row(2, JUDGE.FAIL), row(3, JUDGE.PASS)]);
    expect(out.map((r) => r.judgeCd)).toEqual([JUDGE.PASS, JUDGE.FAIL, JUDGE.PASS]);
  });

  it("빈 항목만 적합(예)이 되고 아니오는 그대로다", () => {
    const out = fillBlankItemJudges([
      item("a", "radio", ""),
      item("b", "radio", ITEM_YN.FAIL),
      item("c", "radio", ITEM_YN.PASS),
    ]);
    expect(out.map((i) => i.yn)).toEqual([ITEM_YN.PASS, ITEM_YN.FAIL, ITEM_YN.PASS]);
  });

  it("판정 칸이 없는 항목과 표 머리글은 안 건드린다", () => {
    const out = fillBlankItemJudges([item("num", "num", null), item("hdr-title", "radio", "")]);
    expect(out.map((i) => i.yn)).toEqual([null, ""]);
  });

  it("채우는 것이지 수동 판정으로 표시하지는 않는다", () => {
    // judgeModYn 은 「사람이 정했다」는 뜻이다. 화면이 깔아 준 기본값에 붙이면
    // 금속검출에서 서버 자동판정을 엉뚱하게 눌러 버린다
    const [after] = fillBlankLogJudges([row(1, "")]);
    expect(after.judgeModYn).not.toBe("Y");
  });
});
