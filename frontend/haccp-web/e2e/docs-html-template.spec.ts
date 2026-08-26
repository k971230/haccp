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
  dbOne,
  dbRows,
  fillCell,
  grids,
  login,
  openScreen,
  saveAndConfirm,
} from "./helpers";

/** 화면 · 표준 양식코드 · 복사본 지면 항목이 들어가는 표 */
const SCREENS = [
  { path: "hyg-process-template", std: "html_hyg_prc_000", itemTbl: "tbl_html_hyg_prc_ver_item" },
  { path: "ccp-verify-template", std: "tml_ccp_chk_000", itemTbl: "tbl_tml_ccp_chk_ver_item" },
  { path: "ccp-pkg-template", std: "tml_ccp_pkg_000", itemTbl: "tbl_tml_ccp_pkg_ver_item" },
  { path: "ccp-htg-template", std: "tml_ccp_htg_000", itemTbl: "tbl_tml_ccp_htg_ver_item" },
  { path: "ccp-mtl-template", std: "tml_ccp_mtl_000", itemTbl: "tbl_tml_ccp_mtl_ver_item" },
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
   */
  const codes = dbOne(
    `SELECT string_agg(DISTINCT quote_literal(tmpl_cd), ',') FROM (
       SELECT tmpl_cd FROM tbl_template WHERE tmpl_nm='${NAME}'
       UNION SELECT tmpl_cd FROM tbl_tml_ccp_htg_ver WHERE ver_nm='${NAME}'
       UNION SELECT tmpl_cd FROM tbl_tml_ccp_pkg_ver WHERE ver_nm='${NAME}'
       UNION SELECT tmpl_cd FROM tbl_tml_ccp_mtl_ver WHERE ver_nm='${NAME}'
       UNION SELECT tmpl_cd FROM tbl_tml_ccp_chk_ver WHERE ver_nm='${NAME}'
       UNION SELECT tmpl_cd FROM tbl_html_hyg_prc_ver WHERE ver_nm='${NAME}'
     ) t`,
  );
  if (!codes) return;
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
    dbOne(`DELETE FROM ${t} WHERE tmpl_cd IN (${codes})`);
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
      dbOne(`SELECT count(*) FROM tbl_template WHERE tmpl_cd='${target.std}' AND co_cd='0000'`),
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
});
