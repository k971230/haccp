/**
 * grid.codeSelect.test — 그리드 내부 콤보 빈 option 규칙.
 *
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) useYn·Y/N·required 콤보는 빈칸 없이 사용/미사용만 둔다
 *   2) npm test 로 실행 — MesEditableGrid select 공통 판정
 *   3) 실패하면 그리드 콤보에 공백 option 이 다시 생긴다
 */
import { describe, expect, it } from "vitest";
import { codeSelectHasEmptyOption } from "./grid";

describe("codeSelectHasEmptyOption", () => {
  const yn = [
    { value: "Y", label: "사용" },
    { value: "N", label: "미사용" },
  ];

  it("useYn 은 required 가 아니어도 빈칸 없음", () => {
    expect(codeSelectHasEmptyOption({ field: "useYn", codeOptions: yn })).toBe(false);
  });

  it("옵션이 Y/N뿐이면 필드명과 무관하게 빈칸 없음", () => {
    expect(codeSelectHasEmptyOption({ field: "flagYn", codeOptions: yn })).toBe(false);
  });

  it("required 콤보는 빈칸 없음", () => {
    expect(codeSelectHasEmptyOption({
      field: "roleCd",
      required: true,
      codeOptions: [{ value: "A", label: "A" }, { value: "B", label: "B" }],
    })).toBe(false);
  });

  it("일반 코드 콤보는 빈칸 허용", () => {
    expect(codeSelectHasEmptyOption({
      field: "deptCd",
      codeOptions: [{ value: "D1", label: "생산" }, { value: "D2", label: "품질" }],
    })).toBe(true);
  });
});
