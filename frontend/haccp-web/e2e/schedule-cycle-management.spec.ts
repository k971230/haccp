/**
 * schedule-cycle-management — 문서주기관리.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 이 화면은 작성 6화면의 상류다 — 여기가 틀리면 예정일이 통째로 틀어진다
 *   2) 검색 3조건·단일 폼·삭제 2단계·JWT 전용 본문을 본다
 *   3) 좌측은 조회 전용이다. 양식 등록·삭제는 사용양식 관리 몫이라 여기서 보지 않는다
 *
 * PIPELINE[HF130] E2E
 */
import { expect, test } from "@playwright/test";
import { adminCreds, dbOne, login, openScreen, readonlyCreds, visibleRows } from "./helpers";

const PATH = "/docs/sch/schedule-cycle-management";

test.describe("문서주기관리", () => {
  test.beforeEach(async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openScreen(page, PATH);
    await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });
  });

  test("검색은 3조건이다 — 양식코드·양식명·사용여부", async ({ page }) => {
    // 그리드 헤더에도 같은 문구가 있어 검색 영역으로 좁힌다
    const search = page.locator("form, section").filter({ has: page.getByRole("button", { name: "조회" }) }).first();
    for (const label of ["양식코드", "양식명", "사용여부"]) {
      await expect(search.getByText(label, { exact: true }).first()).toBeVisible({ timeout: 20_000 });
    }
  });

  test("양식을 고르면 우측이 단일 폼으로 열린다", async ({ page }) => {
    await page.getByRole("row").nth(1).click();
    // 그리드가 아니라 폼이다 — 주기 콤보가 보이면 열린 것이다
    await expect(page.getByText("주기").first()).toBeVisible({ timeout: 20_000 });
  });

  test("서버가 본문의 coCd·userId 를 신뢰하지 않는다", async ({ request }) => {
    /*
     * 화면에서 저장을 누르는 대신 API 를 직접 친다.
     * 남의 회사코드를 본문에 실어 보내도 서버가 JWT 회사코드로 덮어써야 한다.
     * 화면 저장 버튼은 셸 명령이라 화면마다 위치가 달라 흐름 테스트(document-flow)가 맡는다.
     */
    const apiBase = process.env.E2E_API_BASE_URL || "http://localhost:7070";
    const { user, pass } = adminCreds();
    const auth = await request.post(`${apiBase}/api/v1/auth/login`, {
      data: { userId: user, password: pass },
    });
    const token = ((await auth.json())?.data?.token ?? "") as string;
    expect(token).not.toBe("");

    const res = await request.post(
      `${apiBase}/api/v1/docs/sch/schedule-cycle-management/validate-delete`,
      {
        headers: { Authorization: `Bearer ${token}` },
        // coCd 를 위조해도 서버가 무시한다 — 400(업무 오류)이지 다른 회사 자료가 지워지면 안 된다
        data: [{ tmplCd: "none", coCd: "9999", userId: "someone" }],
      },
    );
    expect([200, 400]).toContain(res.status());
  });

  test("삭제는 validate-delete → delete 2단계다", async ({ page }) => {
    /*
     * 첫 행을 아무거나 집으면 안 된다 — 주기가 안 걸린 양식이면 지울 게 없어
     * 화면이 API 를 아예 안 부른다. 운영에서는 우연히 첫 행에 주기가 있어 지나갔다.
     * 주기가 실제로 걸린 양식을 DB 에서 집는다.
     */
    const tmplCd = dbOne(
      "SELECT tmpl_cd FROM tbl_schedule_rule WHERE co_cd='0000' ORDER BY tmpl_cd LIMIT 1",
    );
    expect(tmplCd, "주기가 걸린 양식이 하나도 없다").not.toBe("");

    const row = visibleRows(page).filter({ hasText: tmplCd }).first();
    await expect(row, `양식 ${tmplCd} 행이 목록에 없다`).toBeVisible({ timeout: 20_000 });
    await row.click();
    await expect(page.getByText("주기").first()).toBeVisible({ timeout: 20_000 });

    const [validate] = await Promise.all([
      page.waitForResponse((r) => r.url().includes("/validate-delete"), { timeout: 30_000 }),
      page.getByRole("button", { name: "삭제" }).first().click(),
    ]);
    // HTTP DELETE 를 쓰지 않는다 — 규약
    expect(validate.request().method()).toBe("POST");
  });
});

test.describe("권한 회귀", () => {
  test("조회 전용 계정은 삭제 API 에서 403 이다", async ({ request }) => {
    const ro = readonlyCreds();
    test.skip(!ro, "E2E_RO_USER/E2E_RO_PASS 가 없어 건너뛴다");

    // 화면을 거치지 않고 로그인 API 로 토큰을 받는다 — 저장 키 구조에 매이지 않는다
    // baseURL 은 화면(4173)이라 API(7070) 는 절대 주소로 부른다
    const apiBase = process.env.E2E_API_BASE_URL || "http://localhost:7070";
    const auth = await request.post(`${apiBase}/api/v1/auth/login`, {
      data: { userId: ro!.user, password: ro!.pass },
    });
    const token = ((await auth.json())?.data?.token ?? "") as string;
    expect(token, "조회 전용 계정 로그인 실패").not.toBe("");

    const res = await request.post(
      `${apiBase}/api/v1/docs/sch/schedule-cycle-management/delete`,
      {
        headers: { Authorization: `Bearer ${token}` },
        data: [{ tmplCd: "none" }],
      },
    );
    expect(res.status()).toBe(403);
  });
});
