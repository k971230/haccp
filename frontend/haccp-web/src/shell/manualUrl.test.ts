/**
 * manualUrl.test — 매뉴얼 정적 주소 화이트리스트.
 *
 * 개발자: 박승우
 * 일자: 2026-08-29
 * 코멘트:
 *   1) 빈 값·없는 화면은 null, 있는 화면은 BASE_URL + scrnCd.html 인지 고정한다
 *   2) npm test 로 실행한다
 *   3) 실패하면 풋터가 없는 HTML 을 새 탭으로 연다
 */
import { describe, expect, it } from "vitest";
import { manualUrlOf } from "@/shell/manualUrl";

describe("manualUrlOf", () => {
  it("빈 값은 전부 null 이다", () => {
    expect(manualUrlOf(undefined)).toBeNull();
    expect(manualUrlOf(null)).toBeNull();
    expect(manualUrlOf("")).toBeNull();
  });

  it("맵에 없는 코드는 null 이다", () => {
    expect(manualUrlOf("not-a-screen")).toBeNull();
  });

  it("정본 화면은 소문자 파일명으로 연다", () => {
    expect(manualUrlOf("ccp-htg")).toBe(`${import.meta.env.BASE_URL}manual/ccp-htg.html`);
    expect(manualUrlOf("CCP-HTG")).toBe(`${import.meta.env.BASE_URL}manual/ccp-htg.html`);
    expect(manualUrlOf("today-tasks")).toBe(`${import.meta.env.BASE_URL}manual/today-tasks.html`);
  });
});
