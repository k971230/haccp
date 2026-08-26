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
  dbOne,
  fillCell,
  grids,
  login,
  openScreen,
  saveAndConfirm,
  visibleRows,
} from "./helpers";

const PATH = "/docs/hwp/hwp-template-management";
/** 양식코드는 화면이 자동 채번한다(hwp_usr_NNN) — 저장 뒤에 읽어서 채운다 */
let TMPL = "";
const HWP = "C:/Users/user/Downloads/(개정) 소규모업체를 위한 과자_해썹(HACCP)관리(최종).hwp";

const NAME = "E2E 시험양식";

/** 시험이 만든 사용자 양식만 지운다 — 이름으로 찾는다. 시스템 제공본은 건드리지 않는다 */
function purge(): void {
  const codes = dbOne(`SELECT string_agg(quote_literal(tmpl_cd), ',') FROM tbl_template
                        WHERE tmpl_nm='${NAME}'`);
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
    await btn(page, "삭제").click();
    await page.waitForTimeout(2_000);
    const ok = btn(page, "확인");
    if (await ok.count()) await ok.click();
    await page.waitForTimeout(3_000);

    expect(
      dbOne("SELECT count(*) FROM tbl_template WHERE tmpl_cd='hwp_sys_001'"),
      "시스템 제공 양식이 지워졌다",
    ).toBe("1");
  });
});
