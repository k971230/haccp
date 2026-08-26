/**
 * approvalAttachRule.test — 결재 첨부 잠금·개수 판정 단위 테스트.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 첨부 잠금과 비고 잠금의 기준이 다르다 — 이 차이가 깨지면 여기서 잡힌다
 *   2) 사용자 첨부 개수는 본문(HWP_SRC)·완료본(PDF)을 빼고 센다
 *   3) 서버 SP 가 같은 기준으로 다시 막는다. 여기는 화면 판정만 본다
 */
import { describe, expect, it } from "vitest";
import {
  ATTACH_MAX,
  canCancelSend,
  canEditAttach,
  canEditRemark,
  canSend,
  countUserFiles,
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

  it("전송(REQ·REV)·결재완료(APV)는 잠긴다", () => {
    expect(canEditAttach("REQ")).toBe(false);
    expect(canEditAttach("REV")).toBe(false);
    expect(canEditAttach("APV")).toBe(false);
  });
});

describe("canEditRemark — 비고는 결재완료 직전까지", () => {
  it("전송 중에도 비고는 열려 있다 — 첨부와 다른 기준이다", () => {
    expect(canEditRemark("REQ")).toBe(true);
    expect(canEditRemark("REV")).toBe(true);
  });

  it("결재완료(APV)만 잠근다", () => {
    expect(canEditRemark("APV")).toBe(false);
  });
});

describe("countUserFiles — 사용자 첨부만 센다", () => {
  it("본문·완료본은 상한에서 뺀다", () => {
    const files = [
      { fileKind: "HWP_SRC" },
      { fileKind: "PDF" },
      { fileKind: "ATTACH" },
      { fileKind: "PHOTO" },
    ];
    expect(countUserFiles(files)).toBe(2);
  });

  it("첨부가 없으면 0", () => {
    expect(countUserFiles([])).toBe(0);
  });

  it("상한만큼 채우면 ATTACH_MAX 와 같아진다", () => {
    const files = Array.from({ length: ATTACH_MAX }, () => ({ fileKind: "ATTACH" }));
    expect(countUserFiles(files)).toBe(ATTACH_MAX);
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
    expect(canSend("REV")).toBe(false);
    expect(canSend("APV")).toBe(false);
  });

  it("전송취소는 검토요청(REQ)에서만 — 검토가 시작되면 서버가 막는다", () => {
    expect(canCancelSend("REQ")).toBe(true);
    expect(canCancelSend("REV")).toBe(false);
    expect(canCancelSend("WRK")).toBe(false);
    expect(canCancelSend("APV")).toBe(false);
  });

  it("전송과 전송취소는 같은 상태에서 동시에 되지 않는다", () => {
    for (const st of ["WRK", "RJT", "REQ", "REV", "APV"]) {
      expect(canSend(st) && canCancelSend(st)).toBe(false);
    }
  });
});
