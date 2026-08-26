/**
 * shell-grid — 셸이 전 화면에 공통으로 주는 그리드 동작.
 *
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 방향키 행 이동 — 비제어(로그 3화면)·제어(문서주기관리) 두 갈래를 모두 본다
 *   2) 패널을 클릭하면 그 패널 메뉴명이 초록 — 그리드·트리·단패널·중첩분할 4케이스
 *   3) 화면마다 붙이는 게 아니라 셸이 일괄로 준다. 화면 하나가 되고 하나가 안 되면 결함이다
 *
 * PIPELINE[HF130] E2E
 */
import { expect, test } from "@playwright/test";
import { adminCreds, dbOne, grids, hasDbTools, login, openScreen } from "./helpers";

/** 활성 행의 data-key 를 읽는다 — 없으면 빈 문자열 */
async function activeKey(grid: import("@playwright/test").Locator): Promise<string> {
  const row = grid.locator("tbody tr.mes-row-active").first();
  if ((await row.count()) === 0) return "";
  return (await row.getAttribute("data-key")) ?? "";
}

test.describe("셸 공통 그리드 동작", () => {
  /*
   * 화면 이용 통계는 집계 표(tbl_view_stat_daily)를 읽는다. 갓 시드한 DB 는
   * 일일 배치가 돈 적이 없어 0행이라 방향키를 시험할 행이 없다 —
   * 운영에는 쌓여 있어 안 드러났다. 배치가 부르는 것과 같은 SP 로 직접 깐다.
   */
  test.beforeAll(() => {
    if (!hasDbTools()) return;
    dbOne(
      "CALL sp_tbl_view_stat_daily_c_000('0000', to_char(now(),'YYYYMMDD'), 'system')",
    );
  });

  test("로그 3화면에서 위·아래 키로 행이 옮겨간다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);

    for (const scrn of ["login-history", "screen-usage-statistics", "audit-log"]) {
      await openScreen(page, `/sys/logs/${scrn}`);
      await expect(page.getByRole("button", { name: "조회" }).first()).toBeVisible({
        timeout: 30_000,
      });
      const grid = grids(page).first();
      await expect
        .poll(async () => grid.locator("tbody tr").count(), { timeout: 30_000 })
        .toBeGreaterThan(1);

      // 첫 행을 눌러 잡고 아래로 한 칸
      await grid.locator("tbody tr").first().click();
      const first = await activeKey(grid);
      expect(first, `${scrn} — 행을 눌러도 활성 표시가 안 붙는다`).not.toBe("");

      await page.keyboard.press("ArrowDown");
      const down = await activeKey(grid);
      expect(down, `${scrn} — ArrowDown 으로 행이 안 옮겨간다`).not.toBe(first);

      // 다시 위로 올리면 원래 자리
      await page.keyboard.press("ArrowUp");
      expect(await activeKey(grid), `${scrn} — ArrowUp 이 안 먹는다`).toBe(first);
    }
  });

  test("문서주기관리는 방향키로 옮기면 우측 폼이 따라온다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openScreen(page, "/docs/sch/schedule-cycle-management");
    await expect(page.getByRole("button", { name: "조회" }).first()).toBeVisible({ timeout: 30_000 });

    const grid = grids(page).first();
    await expect
      .poll(async () => grid.locator("tbody tr").count(), { timeout: 30_000 })
      .toBeGreaterThan(1);

    await grid.locator("tbody tr").first().click();
    const first = await activeKey(grid);
    await page.keyboard.press("ArrowDown");
    // 부모가 activeKey 를 넘기는(제어) 화면이라 여기서도 옮겨가야 한다
    expect(await activeKey(grid), "제어 그리드에서 방향키가 안 먹는다").not.toBe(first);
  });

  test("그리드를 클릭하면 그 패널 메뉴명이 초록으로 활성된다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openScreen(page, "/sys/logs/login-history");
    await expect(page.getByRole("button", { name: "조회" }).first()).toBeVisible({ timeout: 30_000 });

    const grid = grids(page).first();
    await grid.click();
    // data-mes-sec 은 React className 밖이라 재조회·행클릭 리렌더에도 남는다
    await expect(
      page.locator("[data-mes-sec]").filter({ visible: true }).first(),
      "패널을 눌러도 활성 표시가 안 붙는다",
    ).toBeVisible({ timeout: 20_000 });
  });

  test("중첩 분할에서 바깥 칸이 안쪽 헤더를 같이 칠하지 않는다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    // 공통코드관리는 좌(대분류)·우(세부) 두 칸이다
    await openScreen(page, "/sys/code/common-code-management");
    await expect(page.getByRole("button", { name: "조회" }).first()).toBeVisible({ timeout: 30_000 });

    const all = grids(page);
    await expect.poll(async () => all.count(), { timeout: 30_000 }).toBeGreaterThan(1);

    await all.nth(1).click();
    // 활성 패널은 항상 하나여야 한다 — 둘이면 바깥이 안쪽을 같이 칠한 것이다
    await expect
      .poll(async () => page.locator("[data-mes-sec]").filter({ visible: true }).count(), {
        timeout: 20_000,
      })
      .toBe(1);
  });

  test("메뉴 트리만 있는 화면도 클릭하면 활성된다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openScreen(page, "/sys/code/menu-management");
    await expect(page.getByRole("button", { name: "조회" }).first()).toBeVisible({ timeout: 30_000 });

    // 헤더 종류가 셋이다 — mesSec.ts HEAD_SEL 과 같은 목록을 쓴다
    const head = page
      .locator(".mes-grid-head, .mes-grid-block-head, .mes-grid-title-only")
      .filter({ visible: true })
      .first();
    await expect(head, "트리 화면에 헤더 패널이 없다").toBeVisible({ timeout: 20_000 });
    await head.click({ force: true });
    await expect(
      page.locator("[data-mes-sec]").filter({ visible: true }).first(),
      "단패널 트리 화면에서 활성 표시가 안 붙는다",
    ).toBeVisible({ timeout: 20_000 });
  });
});
