/**
 * draft-all — 작성 6화면.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 여섯 화면이 같은 프레임을 쓴다 — 화면마다 「만들고 저장하고 다시 열어도 남아 있나」를 본다
 *   2) 저장했다는 문구가 아니라 DB 를 본다. 화면만 믿으면 서버가 삼킨 실패를 못 본다
 *   3) 이탈(한계기준 벗어남)은 개선조치 화면으로 넘어가야 한다 — 그 연결까지 여기서 만든다
 *
 * PIPELINE[HF130] E2E
 */
import { expect, test } from "@playwright/test";
import {
  adminCreds,
  btn,
  createDraft,
  dbOne,
  grids,
  login,
  openScreen,
  resetDocuments,
  visibleRows,
} from "./helpers";

const SCREENS = [
  { name: "일반위생·공정점검", path: "/draft/html/hyg-process", tmpl: "html_hyg_prc_" },
  { name: "CCP 검증점검표", path: "/draft/html/ccp-verify", tmpl: "html_ccp_chk_" },
  { name: "CCP 포장공정", path: "/draft/ccp-monitoring/ccp-pkg", tmpl: "html_ccp_pkg_" },
  { name: "CCP 가열공정", path: "/draft/ccp-monitoring/ccp-htg", tmpl: "html_ccp_htg_" },
  { name: "CCP 금속검출", path: "/draft/ccp-monitoring/ccp-mtl", tmpl: "html_ccp_mtl_" },
  { name: "HWP 양식", path: "/draft/hwp-doc/hwp-write", tmpl: "hwp_sys_" },
];

test.describe.serial("작성 6화면", () => {
  test.beforeAll(() => resetDocuments());

  for (const s of SCREENS) {
    test(`${s.name} — 문서를 만들면 DB 에 남는다`, async ({ page }) => {
      const before = Number(dbOne(`SELECT count(*) FROM tbl_document WHERE tmpl_cd LIKE '${s.tmpl}%'`));

      const { user, pass } = adminCreds();
      await login(page, user, pass);
      await createDraft(page, s.path, s.tmpl);

      const after = Number(dbOne(`SELECT count(*) FROM tbl_document WHERE tmpl_cd LIKE '${s.tmpl}%'`));
      expect(after, `${s.name} 저장이 DB 에 안 남았다`).toBe(before + 1);

      // 문서번호는 서버가 채번한다 — 비어 있으면 결재·문서함에서 못 찾는다
      const docNo = dbOne(
        `SELECT doc_no FROM tbl_document WHERE tmpl_cd LIKE '${s.tmpl}%' ORDER BY idx DESC LIMIT 1`,
      );
      expect(docNo, "문서번호가 비었다").not.toBe("");
      // 상태는 작성 직후 전송대기(WRK)여야 한다
      expect(
        dbOne(`SELECT status FROM tbl_document WHERE tmpl_cd LIKE '${s.tmpl}%' ORDER BY idx DESC LIMIT 1`),
      ).toBe("WRK");
    });
  }

  test("지면에 넣은 값은 새로고침해도 남는다", async ({ page }) => {
    /*
     * 작성 목록에는 문서번호 열이 없다 — 몇 번째 행이 내 문서인지 화면으로 못 가린다.
     * 앞 시험들이 만든 문서가 쌓여 있으면 새로고침 뒤 엉뚱한 행을 열게 되므로 비우고 시작한다.
     */
    resetDocuments();
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await createDraft(page, "/draft/ccp-monitoring/ccp-pkg", "html_ccp_pkg_");

    const time = page.locator('input[type="time"]:not([disabled])').first();
    await expect(time).toBeVisible({ timeout: 30_000 });
    await time.fill("08:00");
    await time.fill("14:20");
    await Promise.all([
      page.waitForResponse((r) => r.url().includes("/save") && r.request().method() !== "GET"),
      btn(page, "작성 후 저장").click(),
    ]);

    await expect(btn(page, "전송")).toBeEnabled({ timeout: 30_000 });

    // DB 에 실제로 들어갔는가 — 화면 표시와 별개로 본다
    expect(
      dbOne(`SELECT COALESCE(r.check_time,'') FROM tbl_ccp_pkg_monitor m
              JOIN tbl_ccp_pkg_monitor_row r ON r.monitor_idx = m.idx
             WHERE r.row_seq = 1 ORDER BY m.doc_idx DESC LIMIT 1`),
      "저장했는데 DB 에 시각이 없다",
    ).toBe("14:20");

    await page.reload();
    await visibleRows(page).filter({ hasText: "html_ccp_pkg_" }).first().click();
    await expect(
      page.locator('input[type="time"]').first(),
      "저장한 값이 새로고침 뒤 사라졌다",
    ).toHaveValue("14:20", { timeout: 30_000 });
  });

  test("이탈로 표시하면 개선조치 행이 생기고 개선조치 화면에 뜬다", async ({ page }) => {
    resetDocuments();
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await createDraft(page, "/draft/hwp-doc/hwp-write", "hwp_sys_");

    /*
     * 이탈여부는 tbl_document 의 칸이 아니다 — 켜면 tbl_corrective_action 행이 생긴다.
     * HWP 는 지면 푸터가 없어 좌측 목록의 「이탈여부」 칸으로 켠다.
     */
    const list = grids(page).first();
    const heads = (await list.locator("thead th").allInnerTexts()).map((t) => t.trim());
    const col = heads.indexOf("이탈여부");
    expect(col, `이탈여부 열이 없다 — 실제 헤더: ${heads.join("/")}`).toBeGreaterThanOrEqual(0);

    const cell = list.locator("tbody tr").first().locator("td").nth(col);
    await cell.locator('input[type="checkbox"]').check({ force: true });
    await Promise.all([
      page.waitForResponse((r) => r.url().includes("/save") && r.request().method() !== "GET", {
        timeout: 30_000,
      }),
      btn(page, "저장").click(),
    ]);

    const docIdx = dbOne("SELECT idx FROM tbl_document ORDER BY idx DESC LIMIT 1");
    await expect
      .poll(
        () => Number(dbOne(`SELECT count(*) FROM tbl_corrective_action WHERE src_doc_idx=${docIdx}`)),
        { timeout: 20_000 },
      )
      .toBe(1);

    // 개선조치 화면이 그 문서를 읽어야 한다 — 여기서 끊기면 이탈 처리가 사실상 없는 기능이다
    await openScreen(page, "/flow/ca/corrective-action-management");
    await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });
    // 목록은 양식코드가 아니라 양식명·문서번호로 보여 준다 — 문서번호로 찾는다
    const docNo = dbOne(`SELECT doc_no FROM tbl_document WHERE idx=${docIdx}`);
    await expect(
      visibleRows(page).filter({ hasText: docNo }).first(),
      "이탈로 표시했는데 개선조치 목록에 없다",
    ).toBeVisible({ timeout: 30_000 });
  });
});
