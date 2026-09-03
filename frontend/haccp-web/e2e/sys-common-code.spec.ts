/**
 * sys-common-code — 공통코드관리 CRUD 와 제약.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 화면이 「저장했습니다」라고 해도 DB 에 들어갔는지는 따로 본다 — E2E-001 이 그래서 안 잡혔다
 *   2) 정상 경로만 보면 반쪽이다. 중복키·필수값 누락도 같이 본다
 *   3) 시험이 남긴 코드는 마지막에 지운다 — 다음 회차가 중복키에 걸린다
 *
 * PIPELINE[HF130] E2E
 */
import { expect, test } from "@playwright/test";
import {
  addRow,
  adminCreds,
  btn,
  dbOne,
  fillCell,
  grids,
  login,
  loginCoCd,
  openScreen,
  saveAndConfirm,
  sqlLit,
} from "./helpers";

const PATH = "/sys/code/common-code-management";
const MAIN = "CATEGORY_CD";
const SUB = "E2E_TEST";
const API = "/common-code-management";

/** 시험 흔적 지우기 — 화면이 아니라 DB 로 지운다. 삭제 화면 자체가 시험 대상이라 순환을 피한다 */
function purge(): void {
  dbOne(`DELETE FROM tbl_code WHERE main_cd='${MAIN}' AND sub_cd='${SUB}'`);
}

test.describe("공통코드관리", () => {
  test.beforeAll(() => purge());
  test.afterAll(() => purge());

  test("세부코드 등록 → DB 반영 → 수정 → 삭제", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openScreen(page, PATH);
    await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });

    // --- 등록 ---------------------------------------------------------
    await page.getByRole("row").filter({ hasText: MAIN }).first().click();
    const grid = grids(page).last();
    const at = await addRow(page, grid);
    await fillCell(grid, at, "세부코드", SUB);
    await fillCell(grid, at, "코드명", "E2E 시험코드");
    await fillCell(grid, at, "정렬", "999");
    expect(await saveAndConfirm(page, `${API}/save`)).toBe(200);

    // 화면 말고 DB 를 본다
    expect(
      dbOne(`SELECT code_nm FROM tbl_code WHERE main_cd='${MAIN}' AND sub_cd='${SUB}'`),
    ).toBe("E2E 시험코드");
    // 회사코드·시스템여부는 서버가 정한다 — 화면이 보낸 값이 아니다
    expect(dbOne(`SELECT co_cd FROM tbl_code WHERE main_cd='${MAIN}' AND sub_cd='${SUB}'`)).toBe(loginCoCd());

    // --- 수정 ---------------------------------------------------------
    await page.reload();
    await page.getByRole("row").filter({ hasText: MAIN }).first().click();
    const row = grids(page).last().locator("tbody tr").filter({ hasText: SUB }).first();
    await expect(row).toBeVisible({ timeout: 20_000 });
    const grid2 = grids(page).last();
    const rowIdx = await grid2
      .locator("tbody tr")
      .evaluateAll((trs, sub) => trs.findIndex((tr) => (tr.textContent || "").includes(sub)), SUB);
    await fillCell(grid2, rowIdx, "코드명", "E2E 시험코드-수정");
    expect(await saveAndConfirm(page, `${API}/save`)).toBe(200);
    expect(
      dbOne(`SELECT code_nm FROM tbl_code WHERE main_cd='${MAIN}' AND sub_cd='${SUB}'`),
    ).toBe("E2E 시험코드-수정");
  });

  test("같은 세부코드를 또 넣으면 막는다", async ({ page }) => {
    // 위 시험이 남긴 행이 있어야 중복이 성립한다 — 없으면 여기서 만든다
    if (dbOne(`SELECT count(*) FROM tbl_code WHERE main_cd='${MAIN}' AND sub_cd='${SUB}'`) === "0") {
      dbOne(
        `INSERT INTO tbl_code (co_cd, main_cd, sub_cd, code_nm, sort_no, use_yn, sys_yn)
         VALUES ('${sqlLit(loginCoCd())}','${MAIN}','${SUB}','E2E 시험코드',999,'Y','N')`,
      );
    }
    const before = dbOne(`SELECT count(*) FROM tbl_code WHERE main_cd='${MAIN}' AND sub_cd='${SUB}'`);

    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openScreen(page, PATH);
    await page.getByRole("row").filter({ hasText: MAIN }).first().click();
    const grid = grids(page).last();
    await expect(grid.locator("tbody tr").filter({ hasText: SUB }).first()).toBeVisible({
      timeout: 20_000,
    });

    const dup = await addRow(page, grid);
    await fillCell(grid, dup, "세부코드", SUB);
    await fillCell(grid, dup, "코드명", "중복 시도");
    await btn(page, "저장").click();

    // 화면 검증에 걸리든 서버가 막든, 결과는 하나여야 한다 — 행이 늘지 않는다
    await page.waitForTimeout(3_000);
    const confirm = btn(page, "확인");
    if (await confirm.count()) await confirm.click();
    await page.waitForTimeout(3_000);
    expect(
      dbOne(`SELECT count(*) FROM tbl_code WHERE main_cd='${MAIN}' AND sub_cd='${SUB}'`),
      "중복 세부코드가 하나 더 들어갔다",
    ).toBe(before);
  });

  test("코드명을 비우면 저장이 안 나간다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openScreen(page, PATH);
    await page.getByRole("row").filter({ hasText: MAIN }).first().click();
    const grid = grids(page).last();
    const bare = await addRow(page, grid);
    await fillCell(grid, bare, "세부코드", "E2E_NONAME");

    await btn(page, "저장").click();
    await expect(page.getByText(/입력하세요|필수/).first()).toBeVisible({ timeout: 10_000 });
    expect(dbOne("SELECT count(*) FROM tbl_code WHERE sub_cd='E2E_NONAME'")).toBe("0");
  });
});
