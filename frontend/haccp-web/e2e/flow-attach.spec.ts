/**
 * flow-attach — 결재 첨부 화면의 전송·전송취소.
 *
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 이 화면에도 전송(상신)이 있다 — 작성 화면을 다시 열지 않고 여기서 올릴 수 있어야 한다
 *   2) 전송 뒤에는 첨부·내용이 잠긴다. 잠기지 않으면 결재자가 본 것과 기록이 달라진다
 *   3) 상태 전이는 화면 문구가 아니라 DB DOC_STATUS 로 확인한다
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

const API = process.env.E2E_API_BASE_URL || "http://localhost:7070";

/** 방금 만든 문서의 대리키 */
function lastDocIdx(): string {
  return dbOne("SELECT idx FROM tbl_document ORDER BY idx DESC LIMIT 1");
}

test.describe.serial("결재 첨부 — 전송", () => {
  test.beforeAll(() => resetDocuments());

  test("전송대기 문서를 이 화면에서 전송하면 승인요청이 된다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);

    // 작성 화면에서 문서를 하나 만들고 지면 필수값을 채운다
    await createDraft(page, "/draft/ccp-monitoring/ccp-htg", "tml_ccp_htg_");
    await fillPaperRequired(page);
    await btn(page, "저장").click();

    const docIdx = lastDocIdx();
    expect(docIdx, "문서가 안 만들어졌다").not.toBe("");
    expect(
      dbOne(`SELECT status FROM tbl_document WHERE idx=${docIdx}`),
      "새 문서가 전송대기(WRK)가 아니다",
    ).toBe("WRK");

    // 결재 첨부 화면에서 전송한다
    await openScreen(page, "/flow/appr/attach");
    await rowOfDoc(page, docIdx).click();

    await Promise.all([
      page.waitForResponse(
        (r) => r.url().includes("/docs/documents/approval") && r.request().method() === "PUT",
        { timeout: 30_000 },
      ),
      (async () => {
        await btn(page, "전송").click();
        const ok = btn(page, "확인");
        await expect(ok, "전송 확인창이 안 뜬다").toBeVisible({ timeout: 20_000 });
        await ok.click();
      })(),
    ]);

    // 화면 문구가 아니라 DB 로 본다
    await expect
      .poll(() => dbOne(`SELECT status FROM tbl_document WHERE idx=${docIdx}`), { timeout: 20_000 })
      .toBe("REQ");
  });

  test("전송한 문서는 이 화면에서 다시 전송되지 않는다", async ({ page, request }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    const docIdx = lastDocIdx();
    expect(dbOne(`SELECT status FROM tbl_document WHERE idx=${docIdx}`)).toBe("REQ");

    // 화면을 우회해 한 번 더 REQUEST 를 쳐도 서버가 막아야 한다
    const res0 = await request.post(`${API}/api/v1/auth/login`, {
      data: { userId: user, password: pass },
    });
    const token = ((await res0.json())?.data?.token ?? "") as string;
    const again = await request.put(`${API}/api/v1/docs/documents/approval`, {
      headers: { Authorization: `Bearer ${token}` },
      data: { docIdx: Number(docIdx), actionCd: "REQUEST" },
    });
    expect(again.status(), "이미 전송한 문서를 또 전송할 수 있다").not.toBe(200);
    // 막을 때는 업무 오류(400)여야 한다 — 500 이면 막은 게 아니라 터진 것이다
    expect(again.status()).toBeLessThan(500);
    expect(dbOne(`SELECT status FROM tbl_document WHERE idx=${docIdx}`)).toBe("REQ");
  });

  test("전송취소하면 전송대기로 돌아간다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    const docIdx = lastDocIdx();

    await openScreen(page, "/flow/appr/attach");
    await rowOfDoc(page, docIdx).click();

    await Promise.all([
      page.waitForResponse(
        (r) => r.url().includes("/docs/documents/approval") && r.request().method() === "PUT",
        { timeout: 30_000 },
      ),
      (async () => {
        await btn(page, "전송취소").click();
        const ok = btn(page, "확인");
        await expect(ok, "전송취소 확인창이 안 뜬다").toBeVisible({ timeout: 20_000 });
        await ok.click();
      })(),
    ]);

    await expect
      .poll(() => dbOne(`SELECT status FROM tbl_document WHERE idx=${docIdx}`), { timeout: 20_000 })
      .toBe("WRK");
  });
});
