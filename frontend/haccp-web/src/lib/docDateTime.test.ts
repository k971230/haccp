/**
 * docDateTime.test — 저장형(YYYYMMDD) ↔ 화면형(YYYY-MM-DD) 변환.
 *
 * 개발자: 박승우
 * 일자: 2026-08-28
 * 코멘트:
 *   1) 자리 수만 맞고 달력에 없는 날을 걸러내는지 본다 — 그게 실제로 터진 자리다
 *   2) 그리드 date 셀·지면 일자·문서함 기준일이 모두 이 함수를 탄다
 *   3) 되돌리기(fromInputDate)까지 왕복으로 확인한다
 */
import { describe, expect, it } from "vitest";
import { fromInputDate, toInputDate, toDisplayDate } from "./docDateTime";

describe("toInputDate — 저장형을 달력 입력값으로", () => {
  it("정상 날짜를 바꾼다", () => {
    expect(toInputDate("20260828")).toBe("2026-08-28");
    expect(toInputDate("2026-08-28")).toBe("2026-08-28");
  });

  /*
   * 8자리이기만 하면 통과시켰더니 `2024-00-82` 가 만들어졌다.
   * 브라우저가 <input type=date> 에서 그 값을 거부하고 콘솔에 경고를 쌓았다.
   */
  it("자리 수는 맞고 달력엔 없는 날을 막는다", () => {
    expect(toInputDate("20240082"), "00월 82일이 통과하면 안 된다").toBe("");
    expect(toInputDate("20261301"), "13월").toBe("");
    expect(toInputDate("20260800"), "0일").toBe("");
    expect(toInputDate("20260230"), "2월 30일").toBe("");
  });

  it("윤년은 살린다", () => {
    expect(toInputDate("20240229"), "2024는 윤년이다").toBe("2024-02-29");
    expect(toInputDate("20260229"), "2026은 윤년이 아니다").toBe("");
  });

  it("자리 수가 안 맞으면 빈 문자열", () => {
    expect(toInputDate("2026")).toBe("");
    expect(toInputDate("")).toBe("");
    expect(toInputDate(null)).toBe("");
  });
});

describe("fromInputDate — 달력 입력값을 저장형으로", () => {
  it("구분자를 뗀다", () => {
    expect(fromInputDate("2026-08-28")).toBe("20260828");
  });

  it("왕복해도 같다", () => {
    expect(fromInputDate(toInputDate("20260828"))).toBe("20260828");
  });
});

describe("toDisplayDate — 화면 표시", () => {
  it("읽을 수 없으면 대시 한 글자", () => {
    expect(toDisplayDate("20240082")).toBe("-");
    expect(toDisplayDate("")).toBe("-");
  });
});
