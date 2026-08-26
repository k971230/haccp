/**
 * sys-logs — 로그인이력·화면통계·감사로그.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 세 화면 다 조회 전용이다 — 등록·수정·삭제 버튼이 있으면 그게 결함이다
 *   2) 앞 단계에서 한 CRUD 가 여기 남아 있어야 한다. 안 남으면 감사 기능이 죽은 것이다
 *   3) 로그인 실패도 남아야 한다 — 성공만 남기면 침입 시도를 못 본다
 *
 * PIPELINE[HF130] E2E
 */
import { expect, test } from "@playwright/test";
import { adminCreds, dbOne, login, openScreen } from "./helpers";

test.describe("이력·통계 3화면", () => {
  test("세 화면 모두 조회 전용이다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    for (const scrn of ["login-history", "screen-usage-statistics", "audit-log"]) {
      await openScreen(page, `/sys/logs/${scrn}`);
      await expect(page.getByRole("button", { name: "조회" }).first()).toBeVisible({
        timeout: 30_000,
      });
      for (const forbidden of ["행추가", "저장", "삭제"]) {
        await expect(
          page.getByRole("button", { name: forbidden, exact: true }).filter({ visible: true }),
          `${scrn} 에 ${forbidden} 버튼이 있다 — 이력은 고칠 수 없어야 한다`,
        ).toHaveCount(0);
      }
    }
  });

  test("로그인하면 로그인이력에 남는다", async ({ page }) => {
    const before = Number(dbOne("SELECT count(*) FROM tbl_login_log"));
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openScreen(page, "/sys/logs/login-history");
    await expect(page.getByRole("button", { name: "조회" }).first()).toBeVisible({ timeout: 30_000 });
    expect(Number(dbOne("SELECT count(*) FROM tbl_login_log"))).toBeGreaterThan(before);
  });

  test("비밀번호를 틀려도 이력에 남는다", async ({ page, request }) => {
    const before = dbOne(
      "SELECT count(*) FROM tbl_login_log WHERE result_cd <> 'SUCCESS'",
    );
    const apiBase = process.env.E2E_API_BASE_URL || "http://localhost:7070";
    const res = await request.post(`${apiBase}/api/v1/auth/login`, {
      data: { userId: adminCreds().user, password: "틀린비밀번호" },
    });
    expect(res.status(), "틀린 비밀번호가 통과했다").not.toBe(200);
    // 실패도 흔적이 남아야 한다
    expect(
      Number(dbOne("SELECT count(*) FROM tbl_login_log WHERE result_cd <> 'SUCCESS'")),
      "로그인 실패가 이력에 안 남는다",
    ).toBeGreaterThan(Number(before));
    void page;
  });

  test("화면을 열면 화면통계에 쌓인다", async ({ page }) => {
    const before = Number(dbOne("SELECT count(*) FROM tbl_view_log"));
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openScreen(page, "/sys/code/department-management");
    await expect(page.getByRole("button", { name: "조회" }).first()).toBeVisible({ timeout: 30_000 });
    // 화면 이동 시점에 모아 보낸다 — 다른 화면으로 옮겨야 적재된다
    await openScreen(page, "/sys/logs/screen-usage-statistics");
    await expect(page.getByRole("button", { name: "조회" }).first()).toBeVisible({ timeout: 30_000 });
    await expect
      .poll(() => Number(dbOne("SELECT count(*) FROM tbl_view_log")), { timeout: 20_000 })
      .toBeGreaterThan(before);
  });

  test("기준정보를 고치면 감사로그에 남는다", async ({ page }) => {
    const before = Number(dbOne("SELECT count(*) FROM tbl_audit_log WHERE tbl_nm='tbl_dept'"));
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openScreen(page, "/sys/logs/audit-log");
    await expect(page.getByRole("button", { name: "조회" }).first()).toBeVisible({ timeout: 30_000 });
    // 앞 시험(부서관리)이 이미 남겼다 — 0 이면 감사 자체가 안 돌고 있다
    expect(before, "부서 변경이 감사로그에 하나도 없다").toBeGreaterThan(0);
  });
});
