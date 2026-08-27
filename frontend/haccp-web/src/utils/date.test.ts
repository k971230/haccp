/**
 * date.test — 화면 날짜 표시가 「Invalid Date」를 흘리지 않는지 본다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-27
 * 코멘트:
 *   1) 저장형 YYYYMMDD 8자리는 dayjs 가 못 읽는다 — 그 자리를 못 박는다
 *   2) 조회 그리드 date 열이 전부 이 함수를 탄다
 *   3) 읽을 수 없는 값은 원본을 보여 준다. 「Invalid Date」는 사용자에게 뜻이 없다
 */
import { describe, expect, it } from "vitest";
import { fmtDate, fmtDateTime, fmtDateTimeMinute } from "./date";

describe("fmtDate — 조회 그리드 date 열", () => {
  it("저장형 YYYYMMDD 를 읽는다 — 양식 선택 팝업이 전 행 Invalid Date 였다", () => {
    expect(fmtDate("20260827")).toBe("2026-08-27");
  });

  it("이미 구분자가 있으면 그대로 둔다", () => {
    expect(fmtDate("2026-08-27")).toBe("2026-08-27");
  });

  it("빈 값은 빈 문자열이다", () => {
    expect(fmtDate("")).toBe("");
    expect(fmtDate(null)).toBe("");
  });

  it("읽을 수 없는 값은 원본을 보여 준다 — Invalid Date 를 흘리지 않는다", () => {
    expect(fmtDate("없음")).toBe("없음");
    expect(fmtDateTime("없음")).toBe("없음");
    expect(fmtDateTimeMinute("없음")).toBe("없음");
  });

  it("일시는 시각까지 살린다", () => {
    expect(fmtDateTimeMinute("2026-08-27T18:30:00")).toBe("2026-08-27 18:30");
  });
});
