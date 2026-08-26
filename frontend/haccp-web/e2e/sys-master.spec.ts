/**
 * sys-master — 부서·권한그룹·메뉴 기준정보 CRUD 와 제약.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 공통코드와 같은 편집 그리드라 같은 헬퍼(addRow·fillCell·saveAndConfirm)를 쓴다
 *   2) 저장 성공 여부는 화면 문구가 아니라 DB 로 판정한다
 *   3) 메뉴는 코드·화면코드가 잠겨 있어 신규 등록이 없다 — 수정만 본다
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
  openScreen,
  saveAndConfirm,
} from "./helpers";

const DEPT = "E2EDEPT";
const ROLE = "E2EROLE";

test.describe("부서관리", () => {
  const purge = () => dbOne(`DELETE FROM tbl_dept WHERE dept_cd='${DEPT}'`);
  test.beforeAll(purge);
  test.afterAll(purge);

  test("부서 등록 → DB 반영 → 수정", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openScreen(page, "/sys/code/department-management");
    await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });

    const grid = grids(page).last();
    const at = await addRow(page, grid);
    await fillCell(grid, at, "부서코드", DEPT);
    await fillCell(grid, at, "부서명", "E2E 시험부서");
    expect(await saveAndConfirm(page, "/department-management/save")).toBe(200);
    expect(dbOne(`SELECT dept_nm FROM tbl_dept WHERE dept_cd='${DEPT}'`)).toBe("E2E 시험부서");
    // 회사코드는 JWT 가 정한다 — 화면이 못 정한다
    expect(dbOne(`SELECT co_cd FROM tbl_dept WHERE dept_cd='${DEPT}'`)).toBe("0000");
  });

  test("부서명을 비우면 저장이 안 나간다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openScreen(page, "/sys/code/department-management");
    await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });
    const grid = grids(page).last();
    const at = await addRow(page, grid);
    await fillCell(grid, at, "부서코드", "E2ENONM");
    await btn(page, "저장").click();
    await expect(page.getByText(/입력하세요|필수/).first()).toBeVisible({ timeout: 10_000 });
    expect(dbOne("SELECT count(*) FROM tbl_dept WHERE dept_cd='E2ENONM'")).toBe("0");
  });
});

test.describe("권한그룹관리", () => {
  const purge = () => dbOne(`DELETE FROM tbl_role WHERE usrgrp_cd='${ROLE}'`);
  test.beforeAll(purge);
  test.afterAll(purge);

  test("권한그룹 등록 → DB 반영", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openScreen(page, "/sys/code/role-management");
    await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });

    const grid = grids(page).first();
    const at = await addRow(page, grid);
    await fillCell(grid, at, "그룹코드", ROLE);
    await fillCell(grid, at, "그룹명", "E2E 시험그룹");
    expect(await saveAndConfirm(page, "/role-management/save")).toBe(200);
    expect(dbOne(`SELECT usrgrp_nm FROM tbl_role WHERE usrgrp_cd='${ROLE}'`)).toBe("E2E 시험그룹");
  });
});

test.describe("메뉴관리", () => {
  test("메뉴명을 고치면 DB 에 남는다", async ({ page }) => {
    const before = dbOne("SELECT menu_nm FROM tbl_menu WHERE menu_cd='today-tasks' AND co_cd='0000'");
    expect(before, "today-tasks 메뉴가 없다").not.toBe("");

    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openScreen(page, "/sys/code/menu-management");
    await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });

    const grid = grids(page).last();
    const rowIdx = await grid
      .locator("tbody tr")
      .evaluateAll((trs) => trs.findIndex((tr) => (tr.textContent || "").includes("today-tasks")));
    expect(rowIdx, "today-tasks 행을 목록에서 못 찾았다").toBeGreaterThanOrEqual(0);

    await fillCell(grid, rowIdx, "메뉴명", "E2E 수정메뉴");
    expect(await saveAndConfirm(page, "/menu-management/save")).toBe(200);
    expect(dbOne("SELECT menu_nm FROM tbl_menu WHERE menu_cd='today-tasks' AND co_cd='0000'")).toBe(
      "E2E 수정메뉴",
    );

    // 원래 이름으로 되돌린다 — 다음 시험·사람이 쓰는 화면이다
    dbOne(`UPDATE tbl_menu SET menu_nm='${before}' WHERE menu_cd='today-tasks' AND co_cd='0000'`);
  });
});
