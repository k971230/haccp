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
  canCancelSendDoc,
  canEditDetail,
  canModifyDoc,
  canSendDoc,
  htmlFormDraftGridRules,
  sendStateOf,
  validateForTransfer,
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

  it("제목·부제 메타 항목은 필수값 대상이 아니다", () => {
    const rows = [
      item({ itemCd: "hdr-title", itemNm: "일반위생관리 및 공정점검표", inputType: "text", valNm: "" }),
      item({ itemCd: "hp-01", sortNo: 2, inputType: "radio", yn: "Y" }),
    ];
    expect(validateForTransfer("20260824", rows)).toBeNull();
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

  it("전송·결재완료 행은 통째로 잠근다", () => {
    const locked = rules.isRowEditLocked;
    expect(locked).toBeTypeOf("function");
    expect(locked?.({ sendState: "wait" })).toBe(false);
    expect(locked?.({ sendState: "sent" })).toBe(true);
    expect(locked?.({ sendState: "done" })).toBe(true);
  });
});
