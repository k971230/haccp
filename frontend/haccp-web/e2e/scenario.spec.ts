/**
 * scenario — 통합 시나리오 A~E.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 화면 단위 시험이 다 통과해도 이어 붙이면 깨진다 — 층 사이가 실제로 이어지는지 본다
 *   2) 각 시나리오는 「업무 하나를 끝까지」다. 중간 상태가 아니라 마지막 자리를 확인한다
 *   3) 시나리오끼리 서로의 자료를 밟지 않게 문서를 비우고 시작한다
 *
 * PIPELINE[HF130] E2E
 */
import { expect, test, type APIRequestContext, type Page } from "@playwright/test";
import {
  adminCreds,
  btn,
  createDraft,
  dbOne,
  fillPaperRequired,
  grids,
  login,
  openScreen,
  resetDocuments,
  rowOfDoc,
  loginCoCd,
  sqlLit,
  visibleRows,
} from "./helpers";

const API = process.env.E2E_API_BASE_URL || "http://localhost:7070";

async function tokenOf(request: APIRequestContext): Promise<string> {
  const { user, pass } = adminCreds();
  const res = await request.post(`${API}/api/v1/auth/login`, { data: { userId: user, password: pass } });
  const token = ((await res.json())?.data?.token ?? "") as string;
  expect(token, "로그인 실패").not.toBe("");
  return token;
}

/** 작성 → 필수값 → 저장 → 전송. 결재가 필요한 시나리오의 공통 앞부분이다 */
async function draftAndSend(page: Page): Promise<string> {
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
  return dbOne("SELECT idx FROM tbl_document ORDER BY idx DESC LIMIT 1");
}

/** 결재대기에서 그 문서를 열고 결재한다 */
async function actOnApproval(page: Page, action: "승인" | "반려", reason?: string): Promise<void> {
  await openScreen(page, "/flow/appr/sign-ready");
  await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });
  // 목록 열 구성·열린 탭 수에 안 매이게 문서 idx 로 행을 집는다
  await rowOfDoc(page, dbOne("SELECT idx FROM tbl_document ORDER BY idx DESC LIMIT 1")).click();
  await expect(page.getByText("문서 미리보기")).toBeVisible({ timeout: 30_000 });
  if (reason) await page.getByPlaceholder("반려 사유").fill(reason);
  await btn(page, action).click();
  await Promise.all([
    page.waitForResponse(
      (r) => r.url().includes("/docs/documents/approval") && r.request().method() === "PUT",
      { timeout: 30_000 },
    ),
    btn(page, "확인").click().catch(() => undefined),
  ]);
}

test.describe.serial("통합 시나리오", () => {
  test("A. 신규 업체 세팅 — 부서·사용자를 만들면 그 사용자로 로그인된다", async ({ request }) => {
    const DEPT = "E2ESCA";
    const USER = "e2esca";
    dbOne(`DELETE FROM tbl_user WHERE user_id='${USER}'`);
    dbOne(`DELETE FROM tbl_dept WHERE dept_cd='${DEPT}'`);

    const token = await tokenOf(request);
    const dept = await request.put(`${API}/api/v1/sys/code/department-management/save`, {
      headers: { Authorization: `Bearer ${token}` },
      data: [{ deptCd: DEPT, deptNm: "시나리오 부서", useYn: "Y" }],
    });
    expect(dept.status(), await dept.text()).toBe(200);

    const user = await request.put(`${API}/api/v1/sys/code/user-management/save`, {
      headers: { Authorization: `Bearer ${token}` },
      data: [{ userId: USER, userNm: "시나리오 사용자", usrgrpCd: "USER", deptCd: DEPT, useYn: "Y" }],
    });
    expect(user.status(), await user.text()).toBe(200);

    // 만든 사용자로 실제 로그인된다 — 기본 비밀번호가 안 걸리면 여기서 막힌다
    const auth = await request.post(`${API}/api/v1/auth/login`, {
      data: { userId: USER, password: "1234" },
    });
    expect(auth.status(), "새로 만든 사용자로 로그인이 안 된다").toBe(200);

    // 만든 부서가 사용자에게 실제로 붙었다
    expect(dbOne(`SELECT dept_cd FROM tbl_user WHERE user_id='${USER}'`)).toBe(DEPT);

    dbOne(`DELETE FROM tbl_user WHERE user_id='${USER}'`);
    dbOne(`DELETE FROM tbl_dept WHERE dept_cd='${DEPT}'`);
  });

  test("B. 정상 결재 — 작성부터 문서함까지 한 번에 간다", async ({ page }) => {
    resetDocuments();
    const { user, pass } = adminCreds();
    await login(page, user, pass);

    const idx = await draftAndSend(page);
    expect(dbOne(`SELECT status FROM tbl_document WHERE idx=${idx}`)).toBe("REQ");

    await actOnApproval(page, "승인");
    expect(dbOne(`SELECT status FROM tbl_document WHERE idx=${idx}`)).toBe("APV");

    // 승인 시각·승인자가 남아야 감사에 쓸 수 있다
    expect(dbOne(`SELECT COALESCE(approver_id,'') FROM tbl_document WHERE idx=${idx}`)).not.toBe("");
    expect(
      dbOne(`SELECT CASE WHEN approve_dt IS NULL THEN 'N' ELSE 'Y' END FROM tbl_document WHERE idx=${idx}`),
    ).toBe("Y");

    const docNo = dbOne(`SELECT doc_no FROM tbl_document WHERE idx=${idx}`);
    await openScreen(page, "/flow/box/document-inbox");
    await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });
    await expect(
      visibleRows(page).filter({ hasText: docNo }).first(),
      "승인 끝난 문서가 문서함에 없다",
    ).toBeVisible({ timeout: 30_000 });
  });

  test("C. 반려 후 재상신 — 돌아온 문서를 다시 올리면 승인까지 간다", async ({ page }) => {
    resetDocuments();
    const { user, pass } = adminCreds();
    await login(page, user, pass);

    const idx = await draftAndSend(page);
    await actOnApproval(page, "반려", "시나리오 반려");
    expect(dbOne(`SELECT status FROM tbl_document WHERE idx=${idx}`)).toBe("RJT");

    /*
     * 작성 화면으로 돌아온다 — 반려 문서는 다시 고칠 수 있어야 한다.
     * 목록 배지는 3단계(전송대기/전송/결재완료)라 반려도 「전송대기」로 묶여 보인다 —
     * 배지로는 반려를 못 가린다. 상태는 위에서 DB 로 이미 확인했다.
     * 여기서는 「행을 눌러 우측이 실제로 열렸는지」를 본다. 안 열리면 전송이 잠긴 채로 남는다.
     */
    await openScreen(page, "/draft/ccp-monitoring/ccp-htg");
    await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });
    const rejected = grids(page).first().locator("tbody tr").first();
    await expect(rejected).toBeVisible({ timeout: 30_000 });
    await rejected.click();
    await expect(
      page.getByText("왼쪽에서 문서를 고르거나"),
      "행을 눌렀는데 우측이 안 열렸다",
    ).toHaveCount(0, { timeout: 30_000 });
    await expect(btn(page, "전송")).toBeEnabled({ timeout: 30_000 });

    await btn(page, "전송").click();
    await Promise.all([
      page.waitForResponse(
        (r) => r.url().includes("/docs/documents/approval") && r.request().method() === "PUT",
        { timeout: 30_000 },
      ),
      btn(page, "확인").click(),
    ]);
    expect(
      dbOne(`SELECT status FROM tbl_document WHERE idx=${idx}`),
      "반려 문서를 다시 전송했는데 상태가 안 올라갔다",
    ).toBe("REQ");
    /*
     * 재상신하면 앞선 반려 사유는 지워져야 한다.
     * 남아 있으면 결재자가 이번 문서에 대한 지적인 줄 알고 판단한다.
     */
    expect(
      dbOne(`SELECT COALESCE(reject_reason,'') FROM tbl_document WHERE idx=${idx}`),
      "재상신했는데 이전 반려 사유가 남아 있다",
    ).toBe("");

    await actOnApproval(page, "승인");
    expect(dbOne(`SELECT status FROM tbl_document WHERE idx=${idx}`)).toBe("APV");
  });

  test("D. 이탈 발생 — 작성에서 켠 이탈이 개선조치까지 이어진다", async ({ page }) => {
    resetDocuments();
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await createDraft(page, "/draft/hwp-doc/hwp-write", "hwp_sys_");

    const list = grids(page).first();
    const heads = (await list.locator("thead th").allInnerTexts()).map((t) => t.trim());
    const col = heads.indexOf("이탈여부");
    expect(col, "이탈여부 열이 없다").toBeGreaterThanOrEqual(0);
    await list
      .locator("tbody tr")
      .first()
      .locator("td")
      .nth(col)
      .locator('input[type="checkbox"]')
      .check({ force: true });
    await Promise.all([
      page.waitForResponse((r) => r.url().includes("/save") && r.request().method() !== "GET"),
      btn(page, "저장").click(),
    ]);

    const idx = dbOne("SELECT idx FROM tbl_document ORDER BY idx DESC LIMIT 1");
    await expect
      .poll(
        () => Number(dbOne(`SELECT count(*) FROM tbl_corrective_action WHERE src_doc_idx=${idx}`)),
        { timeout: 20_000 },
      )
      .toBe(1);

    // 개선조치 번호가 채번돼야 추적이 된다
    expect(
      dbOne(`SELECT COALESCE(ca_no,'') FROM tbl_corrective_action WHERE src_doc_idx=${idx}`),
      "개선조치 번호가 안 붙었다",
    ).not.toBe("");

    const docNo = dbOne(`SELECT doc_no FROM tbl_document WHERE idx=${idx}`);
    await openScreen(page, "/flow/ca/corrective-action-management");
    await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });
    await expect(
      visibleRows(page).filter({ hasText: docNo }).first(),
      "이탈 문서가 개선조치 목록에 없다",
    ).toBeVisible({ timeout: 30_000 });
  });

  test("E. 주기 변경 — 주기를 바꾸면 예정일이 따라 바뀐다", async ({ page, request }) => {
    const TMPL = "html_ccp_chk_001";
    const token = await tokenOf(request);
    const co = sqlLit(loginCoCd());
    const saved = dbOne(
      `SELECT cycle_cd FROM tbl_schedule_rule WHERE co_cd='${co}' AND tmpl_cd='${TMPL}'`,
    );

    const body = (cycleCd: string, details: unknown[]) => ({
      tmplCd: TMPL,
      baseDt: "20260101",
      cycleCd,
      nonworkRule: "KEEP",
      dueTime: "1800",
      useYn: "Y",
      details,
    });
    const future = () =>
      Number(
        dbOne(`SELECT count(*) FROM tbl_schedule_task
                WHERE co_cd='${co}' AND tmpl_cd='${TMPL}'
                  AND base_dt > to_char(current_date,'YYYYMMDD')`),
      );

    // 매일로 바꾸면 앞으로의 예정일이 깔린다
    let res = await request.put(`${API}/api/v1/docs/sch/schedule-cycle-management/save`, {
      headers: { Authorization: `Bearer ${token}` },
      data: body("D", []),
    });
    expect(res.status(), await res.text()).toBe(200);
    const daily = future();
    expect(daily, "매일로 바꿨는데 예정일이 없다").toBeGreaterThan(0);

    // 매년으로 바꾸면 확 줄어야 한다 — 규칙이 실제로 반영된다는 뜻이다
    res = await request.put(`${API}/api/v1/docs/sch/schedule-cycle-management/save`, {
      headers: { Authorization: `Bearer ${token}` },
      data: body("Y", [{ detailTy: "year-month", val1: 12, val2: 20 }]),
    });
    expect(res.status()).toBe(200);
    expect(future(), "매년으로 바꿨는데 예정일이 줄지 않았다").toBeLessThan(daily);

    // 오늘 할 일 화면이 열리고 요약이 뜬다
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openScreen(page, "/board/today-tasks");
    await expect(page.getByText(/오늘 작성 과제/).first()).toBeVisible({ timeout: 30_000 });

    dbOne(
      `DELETE FROM tbl_schedule_task
        WHERE co_cd='${co}' AND tmpl_cd='${TMPL}'
          AND status IN ('TODO','LATE') AND doc_idx IS NULL`,
    );
    if (saved) {
      dbOne(
        `UPDATE tbl_schedule_rule SET cycle_cd='${sqlLit(saved)}'
          WHERE co_cd='${co}' AND tmpl_cd='${TMPL}'`,
      );
    } else {
      dbOne(`DELETE FROM tbl_schedule_rule_detail WHERE co_cd='${co}' AND tmpl_cd='${TMPL}'`);
      dbOne(`DELETE FROM tbl_schedule_rule WHERE co_cd='${co}' AND tmpl_cd='${TMPL}'`);
    }
  });
});
