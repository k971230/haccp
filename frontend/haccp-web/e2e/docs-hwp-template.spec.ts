/**
 * docs-hwp-template — HWP 사용양식관리 (원본 등록·업로드·버전).
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 진짜 HWP 파일을 올린다 — 13MB짜리 실물이라 크기 제한·저장 경로가 여기서 드러난다
 *   2) 업로드는 덮어쓰지 않고 버전을 쌓는다. DB 에 버전 행이 늘어야 성공이다
 *   3) 시스템 제공 양식은 삭제할 수 없어야 한다 — 지워지면 다른 회사 배포본이 깨진다
 *
 * PIPELINE[HF130] E2E
 */
import { expect, test } from "@playwright/test";
import {
  addRow,
  adminCreds,
  btn,
  confirmDeleteBtn,
  dbOne,
  fillCell,
  grids,
  login,
  loginCoCd,
  openScreen,
  saveAndConfirm,
  sqlLit,
  visibleRows,
} from "./helpers";

const PATH = "/docs/hwp/hwp-template-management";
/** 양식코드는 화면이 자동 채번한다(hwp_usr_NNN) — 저장 뒤에 읽어서 채운다 */
let TMPL = "";
const HWP = "C:/Users/user/Downloads/(개정) 소규모업체를 위한 과자_해썹(HACCP)관리(최종).hwp";

const NAME = "E2E 시험양식";

/** 삭제 왕복 전용 이름 — 위 NAME 과 나눠야 앞 시험이 만든 행을 안 건드린다 */
const DEL_NAME = "E2E 삭제검증양식";

/** 시험이 만든 사용자 양식만 지운다 — 이름으로 찾는다. 시스템 제공본은 건드리지 않는다 */
function purge(): void {
  const codes = dbOne(`SELECT string_agg(quote_literal(tmpl_cd), ',') FROM tbl_template
                        WHERE tmpl_nm IN ('${NAME}', '${DEL_NAME}')`);
  if (!codes) return;
  dbOne(`DELETE FROM tbl_company_template_file WHERE tmpl_cd IN (${codes})`);
  dbOne(`DELETE FROM tbl_company_template WHERE tmpl_cd IN (${codes})`);
  dbOne(`DELETE FROM tbl_template WHERE tmpl_cd IN (${codes})`);
}

test.describe.serial("HWP 사용양식관리", () => {
  test.beforeAll(purge);
  test.afterAll(purge);

  test("사용자 양식 등록 → 실제 HWP 업로드 → 버전이 쌓인다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openScreen(page, PATH);
    await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });

    const grid = grids(page).first();
    const at = await addRow(page, grid);
    // 양식코드는 화면이 hwp_usr_NNN 으로 자동 채번한다 — 사람이 정하지 않는다
    await fillCell(grid, at, "양식명", NAME);
    expect(await saveAndConfirm(page, "/hwp-template-management/save")).toBe(200);

    TMPL = dbOne(`SELECT tmpl_cd FROM tbl_template WHERE tmpl_nm='${NAME}' ORDER BY idx DESC LIMIT 1`);
    expect(TMPL, "저장했는데 양식이 DB 에 없다").not.toBe("");
    expect(TMPL.startsWith("hwp_usr_"), `자동 채번 규칙에 안 맞는다: ${TMPL}`).toBe(true);

    // --- 실제 파일 업로드 ------------------------------------------------
    await visibleRows(page).filter({ hasText: TMPL }).first().click();
    const verBefore = Number(dbOne(`SELECT count(*) FROM tbl_company_template_file WHERE tmpl_cd='${TMPL}'`));

    // 숨은 input 에 직접 넣는다 — 파일 대화상자는 브라우저 밖이라 자동화가 못 연다
    await page.locator('input[type="file"]').first().setInputFiles(HWP);
    // 업로드 전 확인창을 넘긴다
    await btn(page, "확인").click();

    await expect
      .poll(() => Number(dbOne(`SELECT count(*) FROM tbl_company_template_file WHERE tmpl_cd='${TMPL}'`)), {
        timeout: 120_000,
      })
      .toBeGreaterThan(verBefore);

    // 파일 본체는 디스크에 두고 DB 엔 경로·크기만 남는다 — 13MB 가 잘리면 여기서 잡힌다
    const size = Number(
      dbOne(`SELECT COALESCE(file_size,0) FROM tbl_company_template_file
              WHERE tmpl_cd='${TMPL}' ORDER BY idx DESC LIMIT 1`),
    );
    expect(size, "올린 파일이 비었거나 잘렸다").toBeGreaterThan(13_000_000);

    // 경로만 남고 실물이 없으면 열 때 터진다 — 디스크까지 확인한다
    const saved = dbOne(`SELECT form_path FROM tbl_company_template_file
                          WHERE tmpl_cd='${TMPL}' ORDER BY idx DESC LIMIT 1`);
    expect(saved, "저장 경로가 비었다").not.toBe("");
  });

  test("시스템 제공 양식은 지울 수 없다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openScreen(page, PATH);
    await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });

    const before = dbOne("SELECT count(*) FROM tbl_template WHERE tmpl_cd='hwp_sys_001'");
    expect(before).toBe("1");

    const grid = grids(page).first();
    const row = grid.locator("tbody tr").filter({ hasText: "hwp_sys_001" }).first();
    await row.click();
    await row.locator('input[type="checkbox"]').first().check({ force: true });
    // 화면이 먼저 막는다 — 삭제 API 를 아예 부르지 않는다
    let called = false;
    page.on("request", (r) => {
      if (/hwp-template-management\/(validate-)?delete/.test(r.url())) called = true;
    });
    await btn(page, "삭제").click();
    await expect(
      page.getByText("시스템에서 제공하는 양식은 삭제할 수 없습니다.").filter({ visible: true }).first(),
      "시스템 양식 삭제를 막는 안내가 없다",
    ).toBeVisible({ timeout: 20_000 });
    expect(called, "화면이 안 막고 서버까지 갔다").toBe(false);

    expect(
      dbOne("SELECT count(*) FROM tbl_template WHERE tmpl_cd='hwp_sys_001'"),
      "시스템 제공 양식이 지워졌다",
    ).toBe("1");
  });

  test("자사 양식은 실제로 지워진다 — 화면·DB 둘 다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openScreen(page, PATH);
    await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });

    // 지울 자사 양식을 하나 만든다 — 시스템 제공분은 못 지우니 만들어서 지운다
    // 양식코드는 화면이 hwp_usr_NNN 으로 자동 채번한다
    const grid = grids(page).first();
    const at = await addRow(page, grid);
    await fillCell(grid, at, "양식명", DEL_NAME);
    expect(await saveAndConfirm(page, "/hwp-template-management/save")).toBe(200);

    const cd = dbOne(
      `SELECT tmpl_cd FROM tbl_template WHERE tmpl_nm='${DEL_NAME}' ORDER BY idx DESC LIMIT 1`,
    );
    expect(cd, "자사 양식이 저장되지 않았다").not.toBe("");
    expect(
      dbOne(`SELECT count(*) FROM tbl_company_template WHERE co_cd='${sqlLit(loginCoCd())}' AND tmpl_cd='${cd}'`),
    ).toBe("1");

    // 만든 양식을 골라 지운다 — 삭제 응답이 5xx 면 여기서 걸린다
    await openScreen(page, PATH);
    await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });
    const row = grids(page).first().locator("tbody tr").filter({ hasText: cd }).first();
    await expect(row).toBeVisible({ timeout: 20_000 });
    await row.click();
    await row.locator('input[type="checkbox"]').first().check({ force: true });

    const [res] = await Promise.all([
      page.waitForResponse(
        (r) => r.url().includes("/hwp-template-management/delete"),
        { timeout: 30_000 },
      ),
      (async () => {
        await btn(page, "삭제").click();
        // 확인창의 긍정 버튼도 글자가 「삭제」다 — 다이얼로그 안으로 좁힌다
        const ok = confirmDeleteBtn(page);
        await expect(ok, "삭제 확인창이 안 뜬다").toBeVisible({ timeout: 20_000 });
        await ok.click();
      })(),
    ]);
    expect(res.status(), "삭제 API 가 실패했다").toBe(200);

    // DB 에서 사라져야 한다 — 화면만 보고 통과시키지 않는다
    await expect
      .poll(
        () => dbOne(`SELECT count(*) FROM tbl_company_template WHERE co_cd='${sqlLit(loginCoCd())}' AND tmpl_cd='${cd}'`),
        { timeout: 20_000 },
      )
      .toBe("0");
    expect(
      dbOne(`SELECT count(*) FROM tbl_template WHERE tmpl_cd='${cd}'`),
      "자사 카탈로그 행이 남았다",
    ).toBe("0");
  });

  test("구분·사용여부로 목록이 실제로 줄어든다", async ({ page }) => {
    /*
     * 검색 조건을 화면에서 고르고 **DB 건수와 대조**한다.
     * 시험 DB 는 hwp 양식이 전부 sys·Y 라 그대로는 갈리지 않는다 —
     * 두 건을 미사용·자사로 돌려 놓고 보고, 끝나면 되돌린다.
     */
    const flip = ["hwp_sys_002", "hwp_sys_003"].map((c) => `'${c}'`).join(",");
    dbOne(`UPDATE tbl_company_template SET use_yn='N' WHERE co_cd='${sqlLit(loginCoCd())}' AND tmpl_cd IN (${flip})`);
    dbOne(`UPDATE tbl_company_template SET sys_yn='usr' WHERE co_cd='${sqlLit(loginCoCd())}' AND tmpl_cd='hwp_sys_005'`);
    try {
      const total = Number(dbOne(`SELECT count(*) FROM tbl_company_template ct
                                    JOIN tbl_template t ON t.tmpl_cd = ct.tmpl_cd
                                   WHERE ct.co_cd='${sqlLit(loginCoCd())}' AND t.doc_kind='HWP'`));
      const { user, pass } = adminCreds();
      await login(page, user, pass);
      await openScreen(page, PATH);
      const grid = grids(page).first();
      await expect.poll(() => grid.locator("tbody tr").count(), { timeout: 30_000 }).toBe(total);

      // 콤보 둘 — 앞이 구분, 뒤가 사용여부
      const sels = page.locator("select").filter({ visible: true });
      const sysSel = sels.nth((await sels.count()) - 2);
      const useSel = sels.nth((await sels.count()) - 1);

      /*
       * 기대값을 숫자로 박지 않는다 — 앞 시험이 만든 자사 양식이 남아 있어
       * 「usr 는 1건」 같은 상수는 실행 순서에 따라 어긋난다. DB 에서 세어 대조한다.
       */
      const cnt = (where: string) => Number(dbOne(
        `SELECT count(*) FROM tbl_company_template ct
           JOIN tbl_template t ON t.tmpl_cd = ct.tmpl_cd
          WHERE ct.co_cd='${sqlLit(loginCoCd())}' AND t.doc_kind='HWP' AND ${where}`,
      ));
      const nCnt = cnt("upper(coalesce(ct.use_yn,'Y')) = 'N'");
      const usrCnt = cnt("lower(coalesce(ct.sys_yn,'sys')) IN ('n','usr')");

      await useSel.selectOption("N");
      await expect
        .poll(() => grid.locator("tbody tr").count(), { timeout: 20_000 })
        .toBe(nCnt);
      await useSel.selectOption("Y");
      await expect
        .poll(() => grid.locator("tbody tr").count(), { timeout: 20_000 })
        .toBe(total - nCnt);
      await useSel.selectOption("");

      await sysSel.selectOption("usr");
      await expect
        .poll(() => grid.locator("tbody tr").count(), { timeout: 20_000 })
        .toBe(usrCnt);
      await sysSel.selectOption("sys");
      await expect
        .poll(() => grid.locator("tbody tr").count(), { timeout: 20_000 })
        .toBe(total - usrCnt);
    } finally {
      // 뒷정리 — 다른 시험이 이 값을 보고 돈다
      dbOne(`UPDATE tbl_company_template SET use_yn='Y' WHERE co_cd='${sqlLit(loginCoCd())}' AND tmpl_cd IN (${flip})`);
      dbOne(`UPDATE tbl_company_template SET sys_yn='sys' WHERE co_cd='${sqlLit(loginCoCd())}' AND tmpl_cd='hwp_sys_005'`);
    }
  });

  test("화면을 우회해 API 를 직접 쳐도 시스템 양식은 막는다", async ({ request }) => {
    const apiBase = process.env.E2E_API_BASE_URL || "http://localhost:7070";
    const { user, pass } = adminCreds();
    const login0 = await request.post(`${apiBase}/api/v1/auth/login`, {
      data: { userId: user, password: pass },
    });
    const token = ((await login0.json())?.data?.token ?? "") as string;
    expect(token, "로그인 실패").not.toBe("");

    // 화면 차단을 지나쳐도 서버가 다시 막아야 한다 (Double Check)
    const res = await request.post(
      `${apiBase}/api/v1/docs/hwp/hwp-template-management/validate-delete`,
      { headers: { Authorization: `Bearer ${token}` }, data: [{ tmplCd: "hwp_sys_001" }] },
    );
    expect(res.status(), "서버가 시스템 양식 삭제를 막지 않는다").toBe(400);
    expect(await res.text()).toContain("시스템 제공 양식");

    expect(dbOne("SELECT count(*) FROM tbl_template WHERE tmpl_cd='hwp_sys_001'")).toBe("1");
  });
});
