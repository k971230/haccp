/**
 * htmlFormPaperEdit.test — 지면의 「값 표시」와 「편집 가능」이 다른 축임을 고정한다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 두 축을 한 조건으로 묶으면 잠긴 문서가 빈 예시 지면으로 보인다 — 실제로 그렇게 났다
 *   2) 전송한 문서(작성 화면)와 결재 미리보기가 같은 경로를 탄다
 *   3) 기준관리(template)는 값 표시 대상이 아니다 — 빈 양식을 보여 주는 화면이다
 */
import { describe, expect, it } from "vitest";
import { htmlFormPaperEdit, paperRadioLock } from "./htmlFormPaperShared";

describe("htmlFormPaperEdit — 값 표시와 편집 가능은 다르다", () => {
  it("작성 중이면 값도 보이고 고칠 수도 있다", () => {
    const r = htmlFormPaperEdit("write", false, true);
    expect(r.writeView).toBe(true);
    expect(r.writeEdit).toBe(true);
  });

  it("전송·결재 미리보기(editable=false)여도 저장된 값은 보여야 한다", () => {
    const r = htmlFormPaperEdit("write", true, false);
    expect(r.writeView).toBe(true);
    expect(r.writeEdit).toBe(false);
  });

  it("기준관리는 빈 양식 화면이라 실데이터를 그리지 않는다", () => {
    const r = htmlFormPaperEdit("template", false, true, true);
    expect(r.writeView).toBe(false);
    expect(r.templateEdit).toBe(true);
  });

  it("기준관리에서 표준 양식은 잠긴다", () => {
    expect(htmlFormPaperEdit("template", true, true, true).templateEdit).toBe(false);
  });

  it("잠금 라디오는 disabled 가 아니라 aria-disabled 다", () => {
    expect(paperRadioLock(true)).toEqual({});
    const lock = paperRadioLock(false);
    expect(lock["aria-disabled"]).toBe(true);
    expect(lock.className).toBe("html-form-radio-lock");
    expect("disabled" in lock).toBe(false);
  });
});
