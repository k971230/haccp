/**
 * screen-permission — 권한 밖 화면은 열리지 않는다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 예전에는 주소만 맞으면 화면이 열렸다. API 는 전부 403 이라
 *      사용자는 「화면은 떴는데 아무것도 안 된다」를 겪었고 서버 로그는 deny 로 도배됐다
 *   2) 메뉴는 이미 권한이 반영된 목록이다 — 거기 없으면 열지 않는다
 *   3) 계정을 갈아타면 이전 계정이 열어 둔 탭도 닫혀야 한다
 *
 * PIPELINE[HF130] E2E
 */
import { expect, test } from "@playwright/test";
import { adminCreds, login, openScreen, readonlyCreds } from "./helpers";

/** VIEWER 가 못 읽는 화면 하나 — tbl_role_screen 에서 read_yn='N' 이다 */
const DENIED = "/sys/code/user-management";
/** 누구나 볼 수 있는 화면 */
const ALLOWED = "/draft/ccp-monitoring/ccp-htg";

test.describe("화면 권한", () => {
  test("권한 없는 화면 주소로 들어가면 열리지 않고 오늘 할 일로 돌아온다", async ({ page }) => {
    const ro = readonlyCreds();
    test.skip(!ro, "E2E_RO_USER/E2E_RO_PASS 가 없어 건너뛴다");

    await login(page, ro!.user, ro!.pass);
    await openScreen(page, DENIED);

    // 안내가 뜨고
    await expect(page.getByText(/볼 권한이 없습니다/)).toBeVisible({ timeout: 20_000 });
    // 주소가 오늘 할 일로 바뀐다
    await expect(page).toHaveURL(/today-tasks/, { timeout: 20_000 });
    // 그 화면 탭이 안 생긴다
    await expect(
      page.getByRole("tab", { name: /사용자관리/ }),
      "권한 없는 화면 탭이 생겼다",
    ).toHaveCount(0);
  });

  test("권한 있는 계정에서 열어 둔 탭은 계정을 갈아타면 닫힌다", async ({ page }) => {
    const ro = readonlyCreds();
    test.skip(!ro, "E2E_RO_USER/E2E_RO_PASS 가 없어 건너뛴다");

    // 관리자로 사용자관리를 연다
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openScreen(page, DENIED);
    await expect(page.getByRole("button", { name: "조회" }).first()).toBeVisible({
      timeout: 30_000,
    });

    // 로그아웃하고 조회 전용 계정으로 들어간다
    await page.getByRole("button", { name: "로그아웃" }).click();
    await expect(page).toHaveURL(/login/, { timeout: 20_000 });
    await login(page, ro!.user, ro!.pass);

    // 이전 계정이 열어 둔 탭이 남아 있으면 안 된다
    await expect(
      page.getByRole("tab", { name: /사용자관리/ }),
      "계정을 갈아탔는데 이전 계정의 탭이 남아 있다",
    ).toHaveCount(0, { timeout: 20_000 });
  });

  test("권한 있는 화면은 그대로 열린다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openScreen(page, ALLOWED);
    await expect(page.getByRole("button", { name: "조회" }).first()).toBeVisible({
      timeout: 30_000,
    });
  });
});
