/**
 * hwpOpenMode.test — 저장된 문서에 빈 양식 원본을 열지 않는지.
 *
 * 개발자: 박승우
 * 일자: 2026-09-01
 * 코멘트:
 *   1) docIdx 있는데 첨부가 없으면 wait — 원본 금지
 *   2) 신규(docIdx 없음)만 template
 *   3) HWP_SRC 가 있으면 source
 *
 * PIPELINE[HF186] HWP 열기 판정
 */
import { describe, expect, it } from "vitest";
import { canUploadBody, hwpOpenMode, nextOpenedRef } from "./hwpOpenMode";

describe("hwpOpenMode", () => {
  it("저장된 문서인데 첨부가 없으면 기다린다", () => {
    expect(hwpOpenMode(12, false)).toBe("wait");
  });

  it("신규 행은 양식 원본을 연다", () => {
    expect(hwpOpenMode(null, false)).toBe("template");
    expect(hwpOpenMode(0, false)).toBe("template");
  });

  it("본문 첨부가 있으면 작성본을 연다", () => {
    expect(hwpOpenMode(12, true)).toBe("source");
    expect(hwpOpenMode(null, true)).toBe("source");
  });
});

describe("canUploadBody — 저장 가드", () => {
  it("본문 대기 중이면 올리지 않는다 — 편집기 내용이 앞 문서 것이다", () => {
    expect(canUploadBody({ mode: "wait", docIdx: 7 }, 7)).toBe(false);
    expect(canUploadBody({ mode: "wait", docIdx: null }, 7)).toBe(false);
  });

  it("신규 첫 저장은 통과한다 — template 은 idx 를 안 본다", () => {
    // 신규 행은 docIdx=null 로 열리고 저장은 서버가 발급한 새 idx 로 온다.
    // 여기서 막으면 모든 HWP 문서의 첫 저장에서 본문이 안 올라간다
    expect(canUploadBody({ mode: "template", docIdx: null }, 42)).toBe(true);
  });

  it("기존 문서는 idx 가 같을 때만 올린다", () => {
    expect(canUploadBody({ mode: "source", docIdx: 7 }, 7)).toBe(true);
    expect(canUploadBody({ mode: "source", docIdx: 7 }, 8)).toBe(false);
  });
});

describe("nextOpenedRef — 같은 문서 재로드는 잠그지 않는다", () => {
  it("본문을 저장하면 첨부 idx 가 바뀌어 같은 문서를 다시 읽는다 — 그때 잠그면 연달아 저장이 막힌다", () => {
    const cur = { mode: "source", docIdx: 7 } as const;
    expect(nextOpenedRef(cur, "wait", 7)).toBe(cur);
  });

  it("다른 문서로 넘어가는 wait 는 잠근다 — 이게 원래 막으려던 것이다", () => {
    expect(nextOpenedRef({ mode: "source", docIdx: 7 }, "wait", 8))
      .toEqual({ mode: "wait", docIdx: 8 });
  });

  it("template 을 들고 있었으면 같은 idx 여도 잠근다 — 아직 이 문서를 읽은 적이 없다", () => {
    expect(nextOpenedRef({ mode: "template", docIdx: null }, "wait", null))
      .toEqual({ mode: "wait", docIdx: null });
  });

  it("성공 통지는 그대로 받는다", () => {
    expect(nextOpenedRef({ mode: "wait", docIdx: 7 }, "source", 7))
      .toEqual({ mode: "source", docIdx: 7 });
  });
});
