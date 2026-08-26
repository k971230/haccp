/**
 * today-tasks — 오늘 할 일 랜딩 화면.
 *
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) KPI 5장·미완료 체크·기한경과 빨강·더블클릭 이동을 화면에서 확인한다
 *   2) 단위 테스트(TodayTasksRule.test.ts)는 규칙만 본다 — 화면에서 실제로 도는지는 여기가 본다
 *   3) 클릭은 선택만이고 이동은 더블클릭이다. 이 구분이 깨지면 오조작이 난다
 *
 * PIPELINE[HF130] E2E
 */
import { expect, test } from "@playwright/test";
import { adminCreds, btn, dbOne, grids, login, openScreen, visibleRows } from "./helpers";

/**
 * 오늘 할 일 화면을 열고 **그리드가 채워질 때까지** 기다린다.
 *
 * KPI 문구는 조회 전에도 떠 있다. 그것만 기다리면 0행을 보고 지나간다.
 */
async function openTodayTasks(page: import("@playwright/test").Page): Promise<void> {
  await openScreen(page, "/today-tasks");
  await expect(page.getByText("오늘 작성 과제").filter({ visible: true }).first()).toBeVisible({
    timeout: 30_000,
  });
  await expect
    .poll(async () => grids(page).first().locator("tbody tr").count(), { timeout: 30_000 })
    .toBeGreaterThan(0);
}

test.describe("오늘 할 일", () => {
  test("KPI 가 5장이고 카드 문구가 규칙과 같다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openTodayTasks(page);

    // 4장에서 5장으로 늘었다 — 「과제 완료」가 새로 붙었다
    for (const label of ["오늘 작성 과제", "과제 완료", "미결재", "이탈·개선조치", "최근 문서"]) {
      await expect(
        page.getByText(label, { exact: true }).filter({ visible: true }).first(),
        `KPI 카드 「${label}」가 없다`,
      ).toBeVisible({ timeout: 20_000 });
    }
  });

  test("「미완료 과제만 보기」를 끄면 승인완료가 함께 보인다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openTodayTasks(page);

    const only = page.getByLabel("미완료 과제만 보기").or(
      page.locator('label:has-text("미완료 과제만 보기") input[type="checkbox"]'),
    ).first();
    // 기본값은 체크 — 승인완료·조치완료를 숨긴다
    await expect(only, "「미완료 과제만 보기」가 기본 체크가 아니다").toBeChecked();

    const grid = grids(page).first();
    const closed = await grid.locator("tbody tr").count();
    await only.uncheck();
    // 체크를 풀면 줄어들 수는 없다
    await expect
      .poll(async () => grid.locator("tbody tr").count(), { timeout: 20_000 })
      .toBeGreaterThanOrEqual(closed);
  });

  test("기한이 지난 행은 빨간 배경으로 맨 위에 온다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openTodayTasks(page);

    const grid = grids(page).first();
    const overdue = grid.locator("tbody tr.mes-row-overdue");
    const n = await overdue.count();
    if (n === 0) {
      // 지연 과제가 없는 날은 검사할 게 없다 — 빨간 행이 하나도 없다는 것만 확인한다
      expect(n).toBe(0);
      return;
    }
    // 빨간 행이 있으면 반드시 맨 위 n 줄이어야 한다
    const rows = grid.locator("tbody tr");
    for (let i = 0; i < n; i++) {
      await expect(rows.nth(i), `${i + 1}번째 행이 기한경과가 아니다 — 정렬이 깨졌다`).toHaveClass(
        /mes-row-overdue/,
      );
    }
  });

  test("한 번 클릭은 선택만이다 — 화면이 바뀌지 않는다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openTodayTasks(page);

    const grid = grids(page).first();
    const before = page.url();
    await grid.locator("tbody tr").first().click();
    // 선택은 됐는데 주소는 그대로여야 한다
    await expect(grid.locator("tbody tr.mes-row-active")).toHaveCount(1);
    expect(page.url(), "한 번 클릭으로 화면이 이동했다 — 오조작이 난다").toBe(before);
  });

  test("아직 안 쓴 과제를 더블클릭하면 작성 화면에 행이 하나 붙는다", async ({ page }) => {
    /*
     * 「예정」 글자로 고르지 않는다 — 같은 과제가 마감 시각을 넘기면 「지연」이 된다.
     * 가르는 기준은 상태가 아니라 문서 유무다. 문서가 없는 작성과제를 DB 에서 집는다.
     */
    // 그리드에는 양식코드가 안 보인다 — 업무명으로 행을 집고 이동한 주소로 양식코드를 확인한다
    const picked = dbOne(
      "SELECT title||'|'||tmpl_cd FROM sp_tbl_today_task_r_000('0000','admin',to_char(now(),'YYYYMMDD'))"
      + " WHERE task_type <> 'CA' AND doc_idx IS NULL AND tmpl_cd IS NOT NULL LIMIT 1",
    );
    expect(picked, "아직 안 쓴 작성과제가 하나도 없다 — 주기 설정을 봐야 한다").not.toBe("");
    const [title, tmplCd] = picked.split("|");

    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openTodayTasks(page);

    const grid = grids(page).first();
    const row = visibleRows(page).filter({ hasText: title }).first();
    await expect(row, `업무 ${title} 행이 목록에 없다`).toBeVisible({ timeout: 20_000 });
    await row.dblclick();

    // 작성 화면으로 갔고 add 쿼리는 한 번 쓰고 지워진다
    await expect
      .poll(() => page.url(), { timeout: 30_000 })
      .toMatch(/\/draft\/(html|ccp-monitoring|hwp-doc)\//);
    // 그 과제의 양식으로 갔는지까지 본다
    await expect.poll(() => page.url(), { timeout: 20_000 }).toContain(tmplCd);
    // add 쿼리는 한 번 쓰고 지운다 — 새로고침으로 행이 또 생기지 않게
    await expect.poll(() => page.url(), { timeout: 20_000 }).not.toContain("add=1");
    void grid;
  });

  test("최근 문서도 클릭은 선택, 더블클릭만 문서로 간다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openTodayTasks(page);

    // 최근 문서는 두 번째 그리드다
    const docs = grids(page).nth(1);
    await expect
      .poll(async () => docs.locator("tbody tr").count(), { timeout: 30_000 })
      .toBeGreaterThan(0);

    const before = page.url();
    await docs.locator("tbody tr").first().click();
    expect(page.url(), "최근 문서도 한 번 클릭으로 이동하면 안 된다").toBe(before);

    await docs.locator("tbody tr").first().dblclick();
    await expect.poll(() => page.url(), { timeout: 30_000 }).not.toBe(before);
  });

  test("과제 건수가 DB 와 맞는다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openTodayTasks(page);

    // SP 가 돌려주는 오늘 할 일 전체 — 화면 기본은 미완료만이라 이보다 많을 수 없다
    const all = Number(
      dbOne("SELECT count(*) FROM sp_tbl_today_task_r_000('0000', 'admin', to_char(now(),'YYYYMMDD'))"),
    );
    expect(all, "SP 가 오늘 할 일을 한 건도 안 돌려준다").toBeGreaterThan(0);
    const shown = await grids(page).first().locator("tbody tr").count();
    // 화면 기본은 미완료만이라 SP 전체보다 많을 수 없다. 0 이면 조회가 안 붙은 것이다
    expect(shown, "화면이 한 행도 안 그린다").toBeGreaterThan(0);
    expect(shown, `화면 ${shown}행 > SP ${all}행 — 없는 행을 그리고 있다`).toBeLessThanOrEqual(all);
  });

  test("조회 전용 화면이라 저장·삭제 버튼이 없다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openTodayTasks(page);
    for (const forbidden of ["행추가", "저장", "삭제"]) {
      await expect(
        btn(page, forbidden),
        `오늘 할 일에 ${forbidden} 버튼이 있다 — 여기서 과제를 고칠 수 없어야 한다`,
      ).toHaveCount(0);
    }
  });
});
