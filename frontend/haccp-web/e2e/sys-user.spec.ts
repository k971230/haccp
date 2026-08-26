/**
 * sys-user — 사용자관리 CRUD·비밀번호·제약.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 권한그룹·부서는 셀 버튼으로 여는 팝업이다 — 손으로 못 치는 칸이라 팝업까지 같이 본다
 *   2) 비밀번호가 평문으로 들어가면 안 된다. DB 를 직접 열어 BCrypt 인지 본다
 *   3) 사용자 ID 는 전역 UNIQUE 다 — 같은 ID 를 다시 만들면 막혀야 한다
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

const PATH = "/sys/code/user-management";
const ID = "e2euser";

const purge = () => dbOne(`DELETE FROM tbl_user WHERE user_id='${ID}'`);

/**
 * 셀 버튼으로 팝업을 열고 첫 행을 고른다 — 권한그룹·부서가 같은 구조다.
 *
 * 반드시 그 행 안에서 찾는다. 화면 전체에서 title 로 찾으면 좌측 메뉴의 「권한그룹관리」가 먼저 잡혀
 * 엉뚱한 화면이 열린다.
 */
async function pickFromPopup(
  page: import("@playwright/test").Page,
  row: import("@playwright/test").Locator,
  title: string,
): Promise<void> {
  await row.getByTitle(title).first().click({ force: true });
  // 코드 선택 모달은 한 번 누르면 고르고 닫힌다(CodeLookupModal.onRowClick)
  const modal = page.getByRole("dialog");
  const popupRow = modal.locator("tbody tr").first();
  await expect(popupRow).toBeVisible({ timeout: 20_000 });
  await popupRow.click();
  await expect(modal).toHaveCount(0, { timeout: 10_000 });
}

// 두 시험이 같은 사용자 하나를 이어서 쓴다 — 병렬로 돌면 서로를 밟는다
test.describe.serial("사용자관리", () => {
  test.beforeAll(purge);
  test.afterAll(purge);

  test("사용자 등록 → 비밀번호는 해시로 들어간다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openScreen(page, PATH);
    await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });

    const grid = grids(page).last();
    const at = await addRow(page, grid);
    await fillCell(grid, at, "사용자 ID", ID);
    await fillCell(grid, at, "사용자명", "E2E 시험사용자");
    const newRow = grid.locator("tbody tr").nth(at);
    await pickFromPopup(page, newRow, "권한그룹");
    await pickFromPopup(page, newRow, "부서");
    expect(await saveAndConfirm(page, "/user-management/save")).toBe(200);

    expect(dbOne(`SELECT user_nm FROM tbl_user WHERE user_id='${ID}'`)).toBe("E2E 시험사용자");
    // 평문이면 여기서 잡힌다 — BCrypt 는 $2a$/$2b$ 로 시작하고 60자다
    const pw = dbOne(`SELECT COALESCE(user_pw,'') FROM tbl_user WHERE user_id='${ID}'`);
    expect(pw.startsWith("$2"), `비밀번호가 해시가 아니다: ${pw.slice(0, 12)}`).toBe(true);
  });

  test("같은 사용자 ID 를 또 만들면 막는다", async ({ page }) => {
    expect(dbOne(`SELECT count(*) FROM tbl_user WHERE user_id='${ID}'`), "앞 시험 사용자가 없다").toBe("1");

    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openScreen(page, PATH);
    await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });

    const grid = grids(page).last();
    const at = await addRow(page, grid);
    await fillCell(grid, at, "사용자 ID", ID);
    await fillCell(grid, at, "사용자명", "중복 시도");
    const newRow = grid.locator("tbody tr").nth(at);
    await pickFromPopup(page, newRow, "권한그룹");
    await pickFromPopup(page, newRow, "부서");

    await btn(page, "저장").click();
    await page.waitForTimeout(2_000);
    const ok = btn(page, "확인");
    if (await ok.count()) await ok.click();
    await page.waitForTimeout(3_000);
    expect(dbOne(`SELECT count(*) FROM tbl_user WHERE user_id='${ID}'`), "중복 ID 가 들어갔다").toBe("1");
  });
});
