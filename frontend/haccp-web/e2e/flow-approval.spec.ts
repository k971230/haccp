/**
 * flow-approval — 결재 3화면·문서함·이탈개선조치.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 승인 한 건과 반려 한 건을 끝까지 돌린다 — 반려는 되돌아오는 길이라 더 잘 깨진다
 *   2) 상태 전이는 화면 문구가 아니라 tbl_document.status 로 판정한다
 *   3) 문서함은 조회 전용이다 — 승인 끝난 기록을 고칠 수 있으면 그게 결함이다
 *
 * PIPELINE[HF130] E2E
 */
import { expect, test } from "@playwright/test";
import {
  adminCreds,
  btn,
  createDraft,
  dbOne,
  fillPaperRequired,
  login,
  openScreen,
  resetDocuments,
  rowOfDoc,
} from "./helpers";

/** 작성 → 필수값 → 전송까지. 결재 시험의 공통 전제다 */
async function sendOne(page: import("@playwright/test").Page): Promise<string> {
  await createDraft(page, "/draft/ccp-monitoring/ccp-htg", "html_ccp_htg_");
  await fillPaperRequired(page);
  await Promise.all([
    page.waitForResponse((r) => r.url().includes("/save") && r.request().method() !== "GET"),
    btn(page, "작성 후 저장").click(),
  ]);
  await expect(btn(page, "전송")).toBeEnabled({ timeout: 30_000 });
  await btn(page, "전송").click();
  await Promise.all([
    page.waitForResponse(
      (r) => r.url().includes("/docs/documents/approval") && r.request().method() === "PUT",
      { timeout: 30_000 },
    ),
    btn(page, "확인").click(),
  ]);
  const idx = dbOne("SELECT idx FROM tbl_document ORDER BY idx DESC LIMIT 1");
  expect(dbOne(`SELECT status FROM tbl_document WHERE idx=${idx}`), "전송했는데 상태가 안 바뀌었다").toBe("REQ");
  return idx;
}

test.describe.serial("결재 흐름", () => {
  test("승인 — 결재대기에서 승인하면 결재완료로 간다", async ({ page }) => {
    resetDocuments();
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    const idx = await sendOne(page);

    await openScreen(page, "/flow/appr/sign-ready");
    await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });
    // 목록 열 구성·열린 탭 수에 안 매이게 문서 idx 로 행을 집는다
  await rowOfDoc(page, dbOne("SELECT idx FROM tbl_document ORDER BY idx DESC LIMIT 1")).click();
    await expect(page.getByText("문서 미리보기")).toBeVisible({ timeout: 30_000 });
    // 미리보기에 저장값이 그려져야 한다 — 빈 예시 지면이면 결재자가 아무것도 못 보고 승인한다
    await expect(
      page.locator('input[type="time"][value="09:30"]').first(),
      "결재 미리보기가 빈 지면으로 뜬다",
    ).toBeVisible({ timeout: 30_000 });

    await btn(page, "승인").click();
    await Promise.all([
      page.waitForResponse(
        (r) => r.url().includes("/docs/documents/approval") && r.request().method() === "PUT",
        { timeout: 30_000 },
      ),
      btn(page, "확인").click(),
    ]);
    expect(dbOne(`SELECT status FROM tbl_document WHERE idx=${idx}`)).toBe("APV");

    // 결재완료 화면과 문서함에 뜬다
    for (const path of ["/flow/appr/sign-ok", "/flow/box/document-inbox"]) {
      await openScreen(page, path);
      await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });
      await expect(
        rowOfDoc(page, idx),
        `${path} 에 승인 완료 문서가 없다`,
      ).toBeVisible({ timeout: 30_000 });
    }
  });

  test("문서함은 조회 전용이다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openScreen(page, "/flow/box/document-inbox");
    await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });
    for (const forbidden of ["행추가", "저장", "삭제", "신규"]) {
      await expect(
        page.getByRole("button", { name: forbidden, exact: true }).filter({ visible: true }),
        `문서함에 ${forbidden} 버튼이 있다 — 승인 끝난 기록은 고칠 수 없어야 한다`,
      ).toHaveCount(0);
    }
  });

  test("반려 — 사유 없이 반려하면 막고, 사유를 적으면 작성자에게 돌아간다", async ({ page }) => {
    resetDocuments();
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    const idx = await sendOne(page);

    await openScreen(page, "/flow/appr/sign-ready");
    await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });
    // 목록 열 구성·열린 탭 수에 안 매이게 문서 idx 로 행을 집는다
  await rowOfDoc(page, dbOne("SELECT idx FROM tbl_document ORDER BY idx DESC LIMIT 1")).click();
    await expect(page.getByText("문서 미리보기")).toBeVisible({ timeout: 30_000 });

    // 사유는 결재 툴바 안 입력칸이다 — 비운 채 반려하면 막혀야 한다
    await btn(page, "반려").click();
    await page.waitForTimeout(2_000);
    const ok = btn(page, "확인");
    if (await ok.count()) await ok.click().catch(() => undefined);
    await page.waitForTimeout(2_000);
    expect(
      dbOne(`SELECT status FROM tbl_document WHERE idx=${idx}`),
      "사유 없이 반려가 통과했다",
    ).toBe("REQ");

    // 사유를 적고 다시 반려
    await page.getByPlaceholder("반려 사유").fill("E2E 반려 사유");
    await btn(page, "반려").click();
    await Promise.all([
      page.waitForResponse(
        (r) => r.url().includes("/docs/documents/approval") && r.request().method() === "PUT",
        { timeout: 30_000 },
      ),
      btn(page, "확인").click(),
    ]);
    expect(dbOne(`SELECT status FROM tbl_document WHERE idx=${idx}`)).toBe("RJT");
    expect(
      dbOne(`SELECT COALESCE(reject_reason,'') FROM tbl_document WHERE idx=${idx}`),
      "반려 사유가 안 남았다",
    ).toBe("E2E 반려 사유");
  });
});
