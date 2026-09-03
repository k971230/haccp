/**
 * docs-html-template — HTML 양식 원본 5화면.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 다섯 화면이 같은 프레임(HtmlFormTemplatePage)을 쓴다 — 한 화면을 깊게 보고 나머지는 뼈대만 본다
 *   2) 행추가는 신규 등록이 아니라 「표준 복사」다. 표준(sys)은 절대 안 바뀌어야 한다
 *   3) 표준 양식은 수정·삭제가 막혀야 한다 — 뚫리면 다른 회사 배포본이 오염된다
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
  dbRows,
  fillCell,
  grids,
  login,
  loginCoCd,
  openScreen,
  saveAndConfirm,
  sqlLit,
} from "./helpers";

/** 화면 · 표준 양식코드 · 복사본 지면 항목이 들어가는 표 */
const SCREENS = [
  { path: "hyg-process-template", std: "html_hyg_prc_000", itemTbl: "tbl_html_hyg_prc_ver_item", verTbl: "tbl_html_hyg_prc_ver" },
  { path: "ccp-verify-template", std: "tml_ccp_chk_000", itemTbl: "tbl_tml_ccp_chk_ver_item", verTbl: "tbl_tml_ccp_chk_ver" },
  { path: "ccp-pkg-template", std: "tml_ccp_pkg_000", itemTbl: "tbl_tml_ccp_pkg_ver_item", verTbl: "tbl_tml_ccp_pkg_ver" },
  { path: "ccp-htg-template", std: "tml_ccp_htg_000", itemTbl: "tbl_tml_ccp_htg_ver_item", verTbl: "tbl_tml_ccp_htg_ver" },
  { path: "ccp-mtl-template", std: "tml_ccp_mtl_000", itemTbl: "tbl_tml_ccp_mtl_ver_item", verTbl: "tbl_tml_ccp_mtl_ver" },
];

const NAME = "E2E 복사양식";

/**
 * 시험이 만든 복사본을 지운다.
 *
 * 양식 하나가 표 여러 곳에 걸쳐 있다 — 회사양식·양식·지면 버전(tbl_*_ver)·버전 항목.
 * 버전 표를 안 지우면 다음 회차가 같은 양식코드를 다시 채번하려다 409 로 막힌다.
 * 표를 손으로 나열하지 않고 tmpl_cd 열을 가진 표를 찾아 지운다 — 양식이 늘어도 안 고친다.
 */
function purge(): void {
  /*
   * 양식 표에서만 찾으면 안 된다 — 앞 회차가 반쯤 지워져 버전 표에만 남아 있을 수 있고,
   * 그러면 다음 회차가 같은 코드를 다시 채번하려다 409 로 막힌다. 버전 표 이름으로도 찾는다.
   *
   * 그리고 지울 코드를 **부분질의로** 넘긴다. 목록을 문자열로 만들어 IN (…) 에 박으면
   * 운영처럼 자사 양식이 쌓인 DB 에서는 명령줄 길이를 넘겨 SQL 이 잘린다 —
   * `syntax error at or near ".."` 로 터진다. 실제로 배포 서버에서 10건이 그렇게 났다.
   */
  const codeSql = `SELECT tmpl_cd FROM tbl_template WHERE tmpl_nm='${NAME}'
       UNION SELECT tmpl_cd FROM tbl_tml_ccp_htg_ver WHERE ver_nm='${NAME}'
       UNION SELECT tmpl_cd FROM tbl_tml_ccp_pkg_ver WHERE ver_nm='${NAME}'
       UNION SELECT tmpl_cd FROM tbl_tml_ccp_mtl_ver WHERE ver_nm='${NAME}'
       UNION SELECT tmpl_cd FROM tbl_tml_ccp_chk_ver WHERE ver_nm='${NAME}'
       UNION SELECT tmpl_cd FROM tbl_html_hyg_prc_ver WHERE ver_nm='${NAME}'`;

  const tables = dbRows(
    `SELECT table_name FROM information_schema.columns
      WHERE table_schema='sasshaccp' AND column_name='tmpl_cd'
        AND table_name LIKE '%_ver_item'
      ORDER BY 1`,
  )
    .slice(1)
    .map((r) => r[0]);
  const verTables = dbRows(
    `SELECT table_name FROM information_schema.columns
      WHERE table_schema='sasshaccp' AND column_name='tmpl_cd'
        AND table_name LIKE '%_ver' ORDER BY 1`,
  )
    .slice(1)
    .map((r) => r[0]);
  for (const t of [...tables, ...verTables, "tbl_company_template", "tbl_template"]) {
    dbOne(`DELETE FROM ${t} WHERE tmpl_cd IN (${codeSql})`);
  }
}

test.describe("HTML 양식 원본 5화면", () => {
  test.afterAll(purge);

  test("다섯 화면 모두 표준 양식을 갖고 열린다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    for (const s of SCREENS) {
      await openScreen(page, `/docs/html-form/${s.path}`);
      await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });
      await expect(
        grids(page).first().locator("tbody tr").filter({ hasText: s.std }).first(),
        `${s.path} 에 표준 양식 ${s.std} 이 없다`,
      ).toBeVisible({ timeout: 20_000 });
    }
  });

  /*
   * 다섯 화면이 같은 프레임이지만 복사 SP 는 화면마다 다르다.
   * CCP 하나만 보고 넘어갔다가 일반위생 복사가 깨진 걸 못 잡은 적이 있다 — 전부 돈다.
   */
  for (const target of SCREENS) {
  test(`${target.path} — 행추가는 표준 복사다. 회사 양식이 생기고 표준은 그대로다`, async ({ page }) => {
    purge();

    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openScreen(page, `/docs/html-form/${target.path}`);
    await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });

    const grid = grids(page).first();
    const at = await addRow(page, grid);
    await fillCell(grid, at, "양식명", NAME);
    // 이 화면의 저장은 신규 등록이 아니라 표준 복사다 — API 도 /copy 다
    expect(await saveAndConfirm(page, `/${target.path}/copy`)).toBe(200);

    const made = dbOne(`SELECT tmpl_cd FROM tbl_template WHERE tmpl_nm='${NAME}' ORDER BY idx DESC LIMIT 1`);
    expect(made, "복사한 양식이 DB 에 없다").not.toBe("");
    // 지면 항목까지 딸려와야 한다 — 껍데기만 복사되면 작성 화면이 빈 종이로 뜬다
    expect(
      Number(dbOne(`SELECT count(*) FROM ${target.itemTbl} WHERE tmpl_cd='${made}'`)),
      "복사했는데 지면 항목이 하나도 안 따라왔다",
    ).toBeGreaterThan(0);
    // 표준은 DB 행이 없다 — 복사가 표준을 실체화해 덮어쓰면 안 된다
    expect(
      dbOne(`SELECT count(*) FROM tbl_template WHERE tmpl_cd='${target.std}' AND co_cd='${sqlLit(loginCoCd())}'`),
      "복사 과정에서 표준이 회사 양식으로 만들어졌다",
    ).toBe("0");
  });
  }

  test("표준 양식은 지울 수 없다", async ({ page }) => {
    const target = SCREENS[3];
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openScreen(page, `/docs/html-form/${target.path}`);
    await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });

    const grid = grids(page).first();
    const stdRow = grid.locator("tbody tr").filter({ hasText: target.std }).first();
    await expect(stdRow).toBeVisible({ timeout: 20_000 });

    // 표준 행에는 선택 체크박스 자체가 없다 — 고를 수 없으니 지울 수도 없다
    await expect(
      stdRow.locator('input[type="checkbox"]'),
      "표준 양식에 삭제용 체크박스가 있다",
    ).toHaveCount(0);
    /*
     * 표준은 DB 행이 아니라 코드에 박힌 기본 지면이다 — 지울 대상이 애초에 없다.
     * 그래도 목록에서는 계속 보여야 한다. 사라지면 복사할 원본이 없어진다.
     */
    await expect(stdRow, "표준 양식이 목록에서 사라졌다").toBeVisible();
    expect(
      dbOne(`SELECT count(*) FROM tbl_template WHERE tmpl_cd='${target.std}'`),
      "표준이 DB 행으로 새로 생겼다 — 복사본이 표준을 덮어쓴 것이다",
    ).toBe("0");
  });

  /*
   * 삭제도 화면마다 SP 가 다르다. 「표준은 못 지운다」만 보면 삭제가 통째로 죽어도 통과한다 —
   * 2026-08-26 에 HWP 양식에서 실제로 그랬다. 복사본이 실제로 지워지는지 전 화면에서 본다.
   */
  for (const target of SCREENS) {
  test(`${target.path} — 복사한 자사 양식은 실제로 지워진다`, async ({ page }) => {
    purge();

    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openScreen(page, `/docs/html-form/${target.path}`);
    await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });

    // 지울 대상을 만든다 — 표준은 못 지우니 복사본으로 본다
    const grid = grids(page).first();
    const at = await addRow(page, grid);
    await fillCell(grid, at, "양식명", NAME);
    expect(await saveAndConfirm(page, `/${target.path}/copy`)).toBe(200);

    const made = dbOne(
      `SELECT tmpl_cd FROM tbl_template WHERE tmpl_nm='${NAME}' ORDER BY idx DESC LIMIT 1`,
    );
    expect(made, "복사본이 안 만들어졌다").not.toBe("");

    await openScreen(page, `/docs/html-form/${target.path}`);
    await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });
    const row = grids(page).first().locator("tbody tr").filter({ hasText: made }).first();
    await expect(row, "복사본이 목록에 없다").toBeVisible({ timeout: 20_000 });
    // 이 화면들은 체크박스가 아니라 「지금 고른 행」을 지운다 (HtmlFormTemplatePage.handleDelete)
    await row.click();

    const [res] = await Promise.all([
      page.waitForResponse((r) => /\/(validate-)?delete/.test(r.url()), { timeout: 30_000 }),
      (async () => {
        await btn(page, "삭제").click();
        const ok = confirmDeleteBtn(page);
        await expect(ok, "삭제 확인창이 안 뜬다").toBeVisible({ timeout: 20_000 });
        await ok.click();
      })(),
    ]);
    expect(res.status(), "삭제 API 가 실패했다").toBeLessThan(400);

    /*
     * 화면이 아니라 DB 로 확인한다. 이 삭제는 **소프트 삭제**다 —
     * 회사 사용양식과 예정 규칙은 지우되 지면 버전은 use_yn='N' 으로 남긴다.
     * 이미 그 양식으로 쓴 문서가 지면을 잃으면 기록의 근거가 사라지기 때문이다.
     */
    await expect
      .poll(
        () => dbOne(`SELECT count(*) FROM tbl_company_template WHERE co_cd='${sqlLit(loginCoCd())}' AND tmpl_cd='${made}'`),
        { timeout: 20_000 },
      )
      .toBe("0");
    expect(
      dbOne(`SELECT count(*) FROM tbl_schedule_rule WHERE co_cd='${sqlLit(loginCoCd())}' AND tmpl_cd='${made}'`),
      "삭제했는데 예정 규칙이 남았다 — 없는 양식의 과제가 계속 생긴다",
    ).toBe("0");
    expect(
      dbOne(`SELECT use_yn FROM ${target.verTbl} WHERE tmpl_cd='${made}' ORDER BY ver_no DESC LIMIT 1`),
      "지면 버전이 사용중으로 남았다 — 목록에 계속 뜬다",
    ).toBe("N");

    // 화면 목록에서도 사라져야 한다
    await openScreen(page, `/docs/html-form/${target.path}`);
    await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });
    await expect(
      grids(page).first().locator("tbody tr").filter({ hasText: made }),
      "지운 양식이 목록에 계속 보인다",
    ).toHaveCount(0);
  });
  }
});
