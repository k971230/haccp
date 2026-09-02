/**
 * htmlFormDraftShared.test — 결재 여부 3단계 판정·U/D/전송 잠금·전송 필수값.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) DOC_STATUS → 전송대기/전송/결재완료 묶음이 틀어지면 버튼 잠금이 통째로 어긋난다
 *   2) 전송 필수값은 저장에는 걸리지 않고 전송에만 걸려야 한다
 *   3) HYG·CCP 가 이 함수들을 공유하므로 여기서 한 번만 본다. UI 렌더 없이 순수 함수만 본다
 *
 * PIPELINE[HF172] 양식 작성 공통 규칙
 */
// 역할 — vitest 러너
import { describe, expect, it } from "vitest";
// 역할 — 지면 항목 타입
import type { HtmlFormItem } from "@/api/docs/htmlFormApi";
// 역할 — 검증 대상 순수 함수
import {
  AUTO_DEVIATION_DESC,
  buildDraftListColumns,
  canCancelSendDoc,
  canEditDetail,
  canModifyDoc,
  canSendDoc,
  detailToDraftBuf,
  htmlFormDraftGridRules,
  sendStateOf,
  draftRejectedRowClass,
  validateForTransfer,
  firstInvalidTarget,
} from "./htmlFormDraftShared";

/** 점검 행 1건 — 필요한 칸만 채운다 */
function item(over: Partial<HtmlFormItem>): HtmlFormItem {
  return {
    itemCd: "hp-01",
    sortNo: 1,
    cycleNm: "",
    grpNm: "",
    itemNm: "테스트 항목",
    inputType: "radio",
    unitNm: null,
    yn: "",
    valNm: "",
    ...over,
  };
}

describe("sendStateOf — DOC_STATUS 3단계 묶음", () => {
  it("작성중·반려·임시·저장 전은 전송대기", () => {
    expect(sendStateOf("WRK")).toBe("wait");
    expect(sendStateOf("RJT")).toBe("wait");
    expect(sendStateOf("TMP")).toBe("wait");
    expect(sendStateOf(null)).toBe("wait");
    expect(sendStateOf("")).toBe("wait");
  });

  it("검토요청·검토완료는 전송", () => {
    expect(sendStateOf("REQ")).toBe("sent");
    expect(sendStateOf("REV")).toBe("sent");
  });

  it("승인완료는 결재완료", () => {
    expect(sendStateOf("APV")).toBe("done");
  });
});

describe("draftRejectedRowClass — 반려 행 노란 표시", () => {
  it("RJT 만 클래스를 준다", () => {
    expect(draftRejectedRowClass("RJT")).toBe("mes-row-rejected");
    expect(draftRejectedRowClass("WRK")).toBeUndefined();
    expect(draftRejectedRowClass("REQ")).toBeUndefined();
    expect(draftRejectedRowClass(null)).toBeUndefined();
  });
});

describe("U/D·전송·전송취소 잠금", () => {
  it("전송대기만 수정·삭제할 수 있다", () => {
    expect(canModifyDoc("WRK")).toBe(true);
    expect(canModifyDoc("RJT")).toBe(true);
    expect(canModifyDoc("REQ")).toBe(false);
    expect(canModifyDoc("REV")).toBe(false);
    expect(canModifyDoc("APV")).toBe(false);
  });

  it("저장된 전송대기 문서만 전송할 수 있다", () => {
    expect(canSendDoc(10, "WRK")).toBe(true);
    // 아직 저장 전일 때(= docIdx 없음) 전송 불가
    expect(canSendDoc(null, "WRK")).toBe(false);
    expect(canSendDoc(10, "REQ")).toBe(false);
    expect(canSendDoc(10, "APV")).toBe(false);
  });

  it("오른쪽 상세는 저장된 전송대기 문서만 편집한다", () => {
    // 저장 전 신규 행 — 왼쪽 기본정보를 먼저 저장해야 한다
    expect(canEditDetail(null, null, true)).toBe(false);
    expect(canEditDetail(10, "WRK", true)).toBe(true);
    expect(canEditDetail(10, "RJT", true)).toBe(true);
    expect(canEditDetail(10, "REQ", true)).toBe(false);
    expect(canEditDetail(10, "APV", true)).toBe(false);
    // 권한이 없으면 저장 문서라도 편집 불가
    expect(canEditDetail(10, "WRK", false)).toBe(false);
  });

  it("전송취소는 REQ 만 — 검토완료·결재완료는 열지 않는다", () => {
    expect(canCancelSendDoc(10, "REQ")).toBe(true);
    expect(canCancelSendDoc(10, "REV")).toBe(false);
    expect(canCancelSendDoc(10, "APV")).toBe(false);
    expect(canCancelSendDoc(10, "WRK")).toBe(false);
    expect(canCancelSendDoc(null, "REQ")).toBe(false);
  });
});

describe("validateForTransfer — 전송 직전 필수값", () => {
  const ok = [
    item({ itemCd: "hp-01", inputType: "radio", yn: "Y" }),
    item({ itemCd: "hp-02", sortNo: 2, inputType: "radio-num", yn: "Y", valNm: "4" }),
    item({ itemCd: "hp-03", sortNo: 3, inputType: "text", valNm: "이상 없음" }),
  ];

  it("모든 입력 항목이 차 있으면 통과", () => {
    expect(validateForTransfer("20260824", ok)).toBeNull();
  });

  it("일자가 8자리가 아니면 막는다", () => {
    expect(validateForTransfer("", ok)).toContain("일자");
  });

  it("점검 행이 없으면 막는다", () => {
    expect(validateForTransfer("20260824", [])).toBe("점검 행이 없습니다.");
  });

  it("라디오 판정이 비면 막는다", () => {
    const rows = [item({ itemCd: "hp-01", inputType: "radio", yn: "" })];
    expect(validateForTransfer("20260824", rows)).toContain("테스트 항목");
  });

  it("숫자·문자 값 칸이 비면 막는다", () => {
    const rows = [item({ itemCd: "hp-09", inputType: "radio-num", yn: "Y", valNm: "" })];
    expect(validateForTransfer("20260824", rows)).toContain("테스트 항목");
  });

  /*
   * 문구만으로는 어느 칸인지 못 찾는다 — 항목이 수십 개인 지면에서
   * 사람이 빈칸을 눈으로 뒤지게 된다는 현장 보고가 있었다.
   * 그래서 막은 자리를 같이 돌려준다. 화면은 그 값으로 행을 찾아 스크롤한다.
   */
  it("막은 자리의 항목코드를 같이 준다 — 화면이 그 칸으로 옮긴다", () => {
    const rows = [
      item({ itemCd: "hp-01", inputType: "radio", yn: "Y" }),
      item({ itemCd: "hp-09", sortNo: 2, inputType: "radio-num", yn: "Y", valNm: "" }),
    ];
    const block = firstInvalidTarget("20260824", rows);
    expect(block?.itemCd, "막은 항목을 안 알려주면 화면이 그 칸을 못 찾는다").toBe("hp-09");
    expect(block?.message).toContain("테스트 항목");
  });

  /*
   * HWP 문서형은 본문이 rhwp 파일이라 점검 항목이 원래 없다.
   * 항목형 규칙을 태우면 「점검 행이 없습니다」로 전송이 영영 막힌다 —
   * 운영에서 HWP 문서가 한 건도 전송된 적이 없었다.
   */
  it("문서형 지면(HWP)은 항목이 없어도 막지 않는다", () => {
    expect(validateForTransfer("20260827", [], undefined, false)).toBeNull();
    expect(firstInvalidTarget("20260827", [], undefined, false)).toBeNull();
  });

  it("문서형이어도 일자는 본다", () => {
    expect(validateForTransfer("", [], undefined, false)).toContain("일자");
  });

  it("항목형은 그대로 항목이 없으면 막는다", () => {
    expect(validateForTransfer("20260827", [])).toBe("점검 행이 없습니다.");
  });

  it("막을 것이 없으면 자리도 없다", () => {
    expect(firstInvalidTarget("20260824", ok)).toBeNull();
  });

  it("제목·부제 메타 항목은 필수값 대상이 아니다", () => {
    const rows = [
      item({ itemCd: "hdr-title", itemNm: "일반위생관리 및 공정점검표", inputType: "text", valNm: "" }),
      item({ itemCd: "hp-01", sortNo: 2, inputType: "radio", yn: "Y" }),
    ];
    expect(validateForTransfer("20260824", rows)).toBeNull();
  });
});

describe("detailToDraftBuf — 이탈 시그널 복원", () => {
  it("이탈내용이 있으면 체크를 켠다", () => {
    const buf = detailToDraftBuf(
      {
        header: { docIdx: 1, specialNote: "온도 이탈", improveNote: "", baseDt: "20260901" },
        items: [],
      },
      { tmplCd: "tml_ccp_pkg_001", tmplNm: "포장" },
    );
    expect(buf.deviationYn).toBe(true);
  });

  it("근거가 없으면 꺼 둔다", () => {
    const buf = detailToDraftBuf(
      {
        header: { docIdx: 1, specialNote: "", improveNote: "", baseDt: "20260901" },
        items: [],
        logRows: [],
      },
      { tmplCd: "tml_ccp_pkg_001", tmplNm: "포장" },
    );
    expect(buf.deviationYn).toBe(false);
  });

  it("자동문구는 이탈내용 칸을 비우고 체크는 켠다", () => {
    const buf = detailToDraftBuf(
      {
        header: {
          docIdx: 1,
          specialNote: AUTO_DEVIATION_DESC,
          improveNote: "",
          baseDt: "20260901",
        },
        items: [],
        corrective: {
          deviationDesc: AUTO_DEVIATION_DESC,
          actionDesc: "",
        },
      },
      { tmplCd: "tml_ccp_pkg_001", tmplNm: "포장" },
    );
    expect(buf.specialNote).toBe("");
    expect(buf.deviationYn).toBe(true);
  });
});

describe("htmlFormDraftGridRules — 좌측 셀 편집 잠금", () => {
  const rules = htmlFormDraftGridRules;

  it("일자는 저장 후에도 셀에서 고친다 — 좌측 저장이 커밋한다", () => {
    // alwaysReadonly·newOnly 어디에도 없어야 저장행에서 편집이 열린다
    expect(rules.alwaysReadonly ?? []).not.toContain("baseDtDisp");
    expect(rules.newOnly ?? []).not.toContain("baseDtDisp");
  });

  it("양식코드는 팝업 전용이고 저장 후에는 잠긴다", () => {
    // newOnly 라서 canOpenPopup 이 저장행의 팝업 버튼을 막는다
    expect(rules.newOnly ?? []).toContain("tmplCd");
  });

  it("양식명·작성자·결재 여부는 셀에서 절대 못 고친다", () => {
    for (const field of ["tmplNm", "writerNm", "sendState"]) {
      expect(rules.alwaysReadonly ?? []).toContain(field);
    }
  });

  it("제목은 전송 이후에도 칸을 연다", () => {
    expect(rules.alwaysReadonly ?? []).not.toContain("title");
    expect(rules.editableWhenLocked ?? []).toContain("title");
    const titleCol = buildDraftListColumns(() => {}).find((c) => c.field === "title");
    expect(titleCol?.header).toBe("제목");
    expect(titleCol?.type).toBe("text");
    expect(titleCol?.editable).toBe(true);
    expect(titleCol?.maxLength).toBe(300);
  });

  it("전송·결재완료 행은 잠그되 제목만 예외다", () => {
    const locked = rules.isRowEditLocked;
    expect(locked).toBeTypeOf("function");
    expect(locked?.({ sendState: "wait" })).toBe(false);
    expect(locked?.({ sendState: "sent" })).toBe(true);
    expect(locked?.({ sendState: "done" })).toBe(true);
  });
});

describe("validateForTransfer — 기록 표가 있는 화면(CCP 모니터링)", () => {
  const log = (over: Record<string, unknown> = {}) => ({
    rowSeq: 1,
    phaseCd: "BEFORE" as const,
    productNm: "",
    checkTime: "09:30",
    judgeCd: "P",
    checkerNm: "",
    signYn: "N",
    cells: { temp: "5" },
    ...over,
  });

  /*
   * 기록 표는 작업 전·후를 나눠 그려서 배열 위치로는 화면에서 행을 못 찾는다.
   * 그래서 rowSeq 를 준다 — 지면 tr 의 data-log-seq 와 짝이다.
   */
  it("막은 기록 행의 rowSeq 를 준다 — 배열 위치가 아니다", () => {
    const rows = [
      log({ rowSeq: 7, phaseCd: "AFTER" as const }),
      log({ rowSeq: 3, phaseCd: "BEFORE" as const, checkTime: "" }),
    ];
    const block = firstInvalidTarget("20260825", [], rows);
    expect(block?.logRowSeq, "배열 위치(1)가 아니라 rowSeq(3) 여야 한다").toBe(3);
    expect(block?.message).toContain("시각");
  });

  it("기록 표가 있으면 한계기준·주기·방법 안내문을 필수값으로 보지 않는다", () => {
    // items 는 안내문 블록이다 — 값이 비어 있어도 전송을 막으면 안 된다
    const noticeItems = [
      { itemCd: "limit", itemNm: "가열온도 : 180±5℃", inputType: "TEXT", yn: "", valNm: "" },
    ] as never;
    expect(validateForTransfer("20260825", noticeItems, [log()])).toBeNull();
  });

  it("기록 행의 시각이 비면 몇 번째 행인지 알려준다", () => {
    const msg = validateForTransfer("20260825", [], [log(), log({ rowSeq: 2, checkTime: "" })]);
    expect(msg).toContain("2번째");
    expect(msg).toContain("시각");
  });

  it("기록 행의 판정이 비면 전송을 막는다", () => {
    const msg = validateForTransfer("20260825", [], [log({ judgeCd: "" })]);
    expect(msg).toContain("판정");
  });

  it("포장·가열 기록 행의 온도가 비면 전송을 막는다", () => {
    const msg = validateForTransfer("20260825", [], [log({ cells: {} })]);
    expect(msg).toContain("온도");
  });

  /*
   * 품명은 사람이 더한 행에서만 필수다.
   * 영역 첫 줄(작업 전·작업 종료)은 화면이 품명 자리에 라벨을 대신 그려서
   * 사람이 채울 칸이 아예 없다 — 거기서 막으면 아무도 전송을 못 한다.
   */
  it("영역 첫 줄은 품명이 비어도 막지 않는다 — 라벨 자리라 채울 칸이 없다", () => {
    const rows = [log({ rowSeq: 1, phaseCd: "BEFORE" as const, productNm: "" })];
    expect(validateForTransfer("20260825", [], rows)).toBeNull();
  });

  it("사람이 더한 행은 품명이 비면 막는다", () => {
    const rows = [
      log({ rowSeq: 1, phaseCd: "BEFORE" as const, productNm: "" }),
      log({ rowSeq: 2, phaseCd: "BEFORE" as const, productNm: "" }),
    ];
    const msg = validateForTransfer("20260825", [], rows);
    expect(msg, "둘째 줄부터가 사람이 더한 행이다").toContain("2번째");
    expect(msg).toContain("품명");
  });

  it("영역이 다르면 각자 첫 줄이 라벨이다", () => {
    const rows = [
      log({ rowSeq: 1, phaseCd: "BEFORE" as const, productNm: "" }),
      log({ rowSeq: 5, phaseCd: "AFTER" as const, productNm: "" }),
    ];
    expect(validateForTransfer("20260825", [], rows), "작업 종료 첫 줄도 라벨이다").toBeNull();
  });

  it("금속 통과 첫 줄은 품명이 비면 막는다", () => {
    const pass = [{ rowSeq: 1, productNm: "", passQty: "", detectQty: "", remark: "" }];
    const msg = validateForTransfer("20260825", [], [log()], true, pass);
    expect(msg).toContain("통과 행");
    expect(msg).toContain("품명");
  });

  it("금속 통과 둘째 줄이 전부 비면 건너뛴다", () => {
    const pass = [
      { rowSeq: 1, productNm: "삼겹살", passQty: "", detectQty: "", remark: "" },
      { rowSeq: 2, productNm: "", passQty: "", detectQty: "", remark: "" },
    ];
    expect(validateForTransfer("20260825", [], [log()], true, pass)).toBeNull();
  });

  it("금속은 온도가 비어도 막지 않는다 — 온도 칸이 없다", () => {
    const pass = [
      { rowSeq: 1, productNm: "삼겹살", passQty: "", detectQty: "", remark: "" },
    ];
    expect(validateForTransfer("20260825", [], [log({ cells: {} })], true, pass)).toBeNull();
  });

  it("통과량을 쓴 줄은 품명이 비면 막는다", () => {
    const pass = [
      { rowSeq: 1, productNm: "삼겹살", passQty: "", detectQty: "", remark: "" },
      { rowSeq: 2, productNm: "", passQty: "10", detectQty: "", remark: "" },
    ];
    const msg = validateForTransfer("20260825", [], [log()], true, pass);
    expect(msg).toContain("2번째");
    expect(msg).toContain("품명");
  });
});
