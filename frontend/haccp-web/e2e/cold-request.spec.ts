/**
 * cold-request.spec - G-21 Playwright minimal loop (STEP 28).
 *
 * Developer: Park Seungwoo
 * Date: 2026-08-11
 * Comment:
 *   1) Base: login -> cold monitor -> document list (works with SMOKE read-only)
 *   2) Extended: when write enabled, new -> save -> request approval
 *   3) Secrets via E2E_USER or SMOKE_USER env only; baseURL needs trailing slash
 *
 * PIPELINE[HF130] E2E smoke
 */
import { expect, test, type Page } from "@playwright/test";

function requireCreds(): { user: string; pass: string } {
  const user = (process.env.E2E_USER || process.env.SMOKE_USER || "").trim();
  const pass = (process.env.E2E_PASS || process.env.SMOKE_PASS || "").trim();
  if (!user || !pass) {
    throw new Error(
      "Missing E2E_USER/E2E_PASS (or SMOKE_USER/SMOKE_PASS). Do not commit secrets.",
    );
  }
  return { user, pass };
}

async function login(page: Page, user: string, pass: string): Promise<void> {
  await page.goto("login", { waitUntil: "domcontentloaded" });
  await expect(page.locator("#login-user-id")).toBeVisible({ timeout: 30_000 });
  await page.locator("#login-user-id").fill(user);
  await page.locator("#login-password").fill(pass);
  await page.getByRole("button", { name: "로그인" }).click();
  // 셸 푸터·로그아웃이 보이면 성공 — Path(/haccp/)에서 URL이 잠시 /login에 남을 수 있어 URL만으로 판정하지 않는다
  await expect(page.getByRole("button", { name: "로그아웃" })).toBeVisible({
    timeout: 30_000,
  });
}

async function openColdMonitor(page: Page): Promise<void> {
  await page.goto("screen/ccp-cold-monitor", { waitUntil: "domcontentloaded" });
  await expect(page.getByText("문서 목록").first()).toBeVisible({ timeout: 30_000 });
  await expect(page.getByRole("button", { name: "조회" })).toBeVisible();
}

test.describe("G-21 minimal loop", () => {
  test("login -> cold monitor -> list", async ({ page }) => {
    const { user, pass } = requireCreds();
    await login(page, user, pass);
    await openColdMonitor(page);
    // keep-alive 탭에 hidden table 이 남을 수 있음 — 활성 화면의 신규/조회만 본다
    await expect(page.getByRole("button", { name: "신규" })).toBeVisible({ timeout: 20_000 });
    await expect(page.getByRole("button", { name: "조회" })).toBeEnabled({ timeout: 20_000 });
  });

  test("cold new-save-request (write account)", async ({ page }) => {
    const { user, pass } = requireCreds();
    await login(page, user, pass);
    await openColdMonitor(page);

    const addBtn = page.getByRole("button", { name: "신규" });
    await expect(addBtn).toBeVisible({ timeout: 15_000 });

    if (!(await addBtn.isEnabled())) {
      test.skip(
        true,
        "No write permission on cold monitor - set E2E_USER to a writer account for request flow",
      );
      return;
    }

    await addBtn.click();

    const noStorage = page.getByText("선택 CCP에 연결된 냉장·냉동 보관고가 없습니다");
    if (await noStorage.isVisible().catch(() => false)) {
      throw new Error("Cold storage/CCP master missing - cannot create document");
    }

    await expect(page.getByText("모니터링 기록")).toBeVisible({ timeout: 20_000 });

    // 점검시간 표만 대상 — 상단 메타 doc-table 과 구분한다
    const monitorTable = page.locator("table.doc-table").filter({ hasText: "점검시간" });
    const timeInput = monitorTable.locator('input[type="time"]').first();
    await expect(timeInput).toBeVisible({ timeout: 20_000 });
    await timeInput.fill("09:00");

    const tempInput = monitorTable.locator('input[type="number"]').first();
    if (await tempInput.count()) {
      await tempInput.fill("5");
    }

    await page.getByRole("button", { name: "저장" }).first().click();
    await expect(page.getByRole("button", { name: "상신" })).toBeVisible({ timeout: 30_000 });
    await page.getByRole("button", { name: "상신" }).click();

    const dialog = page.getByRole("dialog");
    await expect(dialog).toBeVisible({ timeout: 15_000 });
    await expect(dialog).toContainText("상신");
    await dialog.getByRole("button", { name: "확인" }).click();

    await expect(
      page.getByText(/상신했습니다|상태:\s*상신/).or(page.getByRole("button", { name: "취소" })),
    ).toBeVisible({ timeout: 30_000 });
  });
});
