/**
 * approvalAttachRule.test — 결재 첨부 잠금·개수·원본/첨부 분류 단위 테스트.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 첨부 잠금과 비고 잠금의 기준이 다르다 — 이 차이가 깨지면 여기서 잡힌다
 *   2) 사용자 첨부 개수·목록은 본문(HWP_SRC)·완료본(PDF)을 빼고 센다
 *   3) 진행 스테퍼는 작성·전송·결재 3칸이다. 검토 칸은 없다
 */
import { describe, expect, it } from "vitest";
import {
  ATTACH_MAX,
  attachStepperCaption,
  attachStepperOf,
  attachStepperToneClass,
  canCancelSend,
  canEditAttach,
  canEditRemark,
  canSend,
  countUserFiles,
  fileKindBadgeOf,
  splitFiles,
} from "./ApprovalAttachRule";

describe("canEditAttach — 첨부는 전송대기에서만", () => {
  it("전송대기(WRK)·반려(RJT)는 고칠 수 있다", () => {
    expect(canEditAttach("WRK")).toBe(true);
    expect(canEditAttach("RJT")).toBe(true);
  });

  it("저장 전(없음)·구 TMP 는 전송대기로 본다", () => {
    expect(canEditAttach(null)).toBe(true);
    expect(canEditAttach("TMP")).toBe(true);
  });

  it("전송(REQ)·결재완료(APV)는 잠긴다", () => {
    expect(canEditAttach("REQ")).toBe(false);
    expect(canEditAttach("APV")).toBe(false);
  });
});

describe("canEditRemark — 비고는 결재완료 직전까지", () => {
  it("전송 중에도 비고는 열려 있다 — 첨부와 다른 기준이다", () => {
    expect(canEditRemark("REQ")).toBe(true);
  });

  it("결재완료(APV)만 잠근다", () => {
    expect(canEditRemark("APV")).toBe(false);
  });
});

describe("countUserFiles / splitFiles — 사용자 첨부만 센다", () => {
  const files = [
    { idx: 1, fileKind: "HWP_SRC" },
    { idx: 2, fileKind: "HWP_SRC" },
    { idx: 3, fileKind: "PDF" },
    { idx: 4, fileKind: "ATTACH" },
    { idx: 5, fileKind: "PHOTO" },
  ];

  it("본문·완료본은 상한에서 뺀다", () => {
    expect(countUserFiles(files)).toBe(2);
  });

  it("첨부가 없으면 0", () => {
    expect(countUserFiles([])).toBe(0);
  });

  it("상한만큼 채우면 ATTACH_MAX 와 같아진다", () => {
    const filled = Array.from({ length: ATTACH_MAX }, () => ({ fileKind: "ATTACH" }));
    expect(countUserFiles(filled)).toBe(ATTACH_MAX);
  });

  it("원본은 최신 HWP_SRC 1건 + PDF, 첨부는 ATTACH·PHOTO", () => {
    const { originals, attachments } = splitFiles(files);
    expect(originals.map((f) => f.idx)).toEqual([2, 3]);
    expect(attachments.map((f) => f.idx)).toEqual([4, 5]);
    expect(countUserFiles(files)).toBe(attachments.length);
  });
});

describe("fileKindBadgeOf — 카드 뱃지", () => {
  it("HWP 본문은 HWP", () => {
    expect(fileKindBadgeOf("HWP_SRC", "a.hwpx").label).toBe("HWP");
  });

  it("완료본은 PDF", () => {
    expect(fileKindBadgeOf("PDF", "a.pdf").label).toBe("PDF");
  });
});

describe("attachStepperOf — 작성·전송·결재", () => {
  it("미전송은 작성만 활성", () => {
    const { steps, hint } = attachStepperOf("WRK");
    expect(steps.map((s) => s.label)).toEqual(["작성", "전송", "결재"]);
    expect(steps.map((s) => s.tone)).toEqual(["active", "pending", "pending"]);
    expect(hint).toContain("전송하지");
  });

  it("전송 중이면 결재 칸이 노랑 대기", () => {
    expect(attachStepperOf("REQ").steps.map((s) => s.tone)).toEqual(["done", "done", "active"]);
    expect(attachStepperToneClass("done").dot).toContain("blue");
    expect(attachStepperToneClass("active").dot).toContain("amber");
    expect(attachStepperToneClass("rejected").dot).toContain("red");
  });

  it("완료면 세 칸 모두 채운다", () => {
    expect(attachStepperOf("APV").steps.map((s) => s.tone)).toEqual(["done", "done", "done"]);
  });

  it("반려면 결재 칸이 반려", () => {
    expect(attachStepperOf("RJT").steps.map((s) => s.tone)).toEqual(["done", "done", "rejected"]);
  });
});

describe("attachStepperCaption — 날짜 대신 완료·결재자", () => {
  it("작성·전송이 끝나면 완료", () => {
    const { steps } = attachStepperOf("REQ");
    expect(attachStepperCaption(steps[0])).toBe("완료");
    expect(attachStepperCaption(steps[1])).toBe("완료");
    expect(attachStepperCaption(steps[2], "김결재")).toBe("");
  });

  it("결재가 끝나면 결재자명만", () => {
    const { steps } = attachStepperOf("APV");
    expect(attachStepperCaption(steps[2], "김결재")).toBe("김결재");
  });

  it("반려면 결재 칸에 반려", () => {
    const { steps } = attachStepperOf("RJT");
    expect(attachStepperCaption(steps[1])).toBe("완료");
    expect(attachStepperCaption(steps[2], "김결재")).toBe("반려");
  });
});

describe("canSend / canCancelSend — 전송 가능 상태", () => {
  it("전송대기(WRK·RJT)만 전송할 수 있다", () => {
    expect(canSend("WRK")).toBe(true);
    expect(canSend("RJT")).toBe(true);
    expect(canSend(null)).toBe(true);
  });

  it("이미 전송했거나 결재된 문서는 전송할 수 없다", () => {
    expect(canSend("REQ")).toBe(false);
    expect(canSend("APV")).toBe(false);
  });

  it("전송취소는 승인요청(REQ)에서만", () => {
    expect(canCancelSend("REQ")).toBe(true);
    expect(canCancelSend("WRK")).toBe(false);
    expect(canCancelSend("APV")).toBe(false);
  });

  it("전송과 전송취소는 같은 상태에서 동시에 되지 않는다", () => {
    for (const st of ["WRK", "RJT", "REQ", "APV"]) {
      expect(canSend(st) && canCancelSend(st)).toBe(false);
    }
  });
});
