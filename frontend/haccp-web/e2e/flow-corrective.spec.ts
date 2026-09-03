/**
 * flow-corrective — 개선조치관리 화면.
 *
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 2026-08-26 에 API 를 com.haccp.tsk 에서 com.haccp.flow.ca 로 옮겼다 — 옮긴 자리가 도는지 본다
 *   2) 조회·수정은 화면과 DB 를 함께 대조한다. UI 초록만으로 통과시키지 않는다
 *   3) 삭제는 validate-delete → delete 두 단계다. 빈 키·완료 건은 막혀야 한다
 *
 * PIPELINE[HF130] E2E
 */
import { expect, test } from "@playwright/test";
import {
  adminCreds,
  btn,
  dbOne,
  fillCell,
  grids,
  login,
  loginCoCd,
  openScreen,
  saveAndConfirm,
  sqlLit,
} from "./helpers";

const PATH = "/flow/ca/corrective-action-management";
const API = process.env.E2E_API_BASE_URL || "http://localhost:7070";

/** 이 시험이 깔아 두는 개선조치 번호 — 다른 자료와 섞이지 않게 고유하게 둔다 */
const CA_NO = "E2E-CA-0001";

/**
 * 개선조치 한 건을 깔고 그 대리키를 돌려준다.
 *
 * 화면 시험이 앞 spec 의 결과를 기다리지 않게 하려는 것이다.
 * 이탈 → 개선조치 생성 경로는 draft-all.spec 이 따로 본다.
 */
function seedCorrectiveAction(): string {
  const co = sqlLit(loginCoCd());
  dbOne(`DELETE FROM tbl_corrective_action WHERE co_cd='${co}' AND ca_no='${CA_NO}'`);
  dbOne(`INSERT INTO tbl_corrective_action
           (co_cd, ca_no, occur_dt, deviation_desc, status, ins_id, ins_dt)
         VALUES ('${co}', '${CA_NO}', to_char(now(),'YYYYMMDD'),
                 'E2E 이탈 내용', 'OPEN', 'system', now())`);
  return dbOne(`SELECT idx FROM tbl_corrective_action WHERE co_cd='${co}' AND ca_no='${CA_NO}'`);
}

/** 깔아 둔 자료를 걷어낸다 */
function purgeCorrectiveAction(): void {
  dbOne(`DELETE FROM tbl_corrective_action WHERE co_cd='${sqlLit(loginCoCd())}' AND ca_no='${CA_NO}'`);
}

/** 화면을 열고 첫 조회가 끝날 때까지 기다린다 */
async function openCa(page: import("@playwright/test").Page): Promise<void> {
  await openScreen(page, PATH);
  await expect(page.getByRole("button", { name: "조회" }).first()).toBeVisible({ timeout: 30_000 });
}

test.describe("개선조치관리", () => {
  test.afterAll(purgeCorrectiveAction);

  test("목록이 열리고 건수가 DB 와 맞는다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openCa(page);

    const inDb = Number(dbOne(`SELECT count(*) FROM tbl_corrective_action WHERE co_cd='${sqlLit(loginCoCd())}'`));
    const shown = await grids(page).first().locator("tbody tr").count();
    // 화면은 기간 조건이 걸려 있어 DB 전체보다 많을 수 없다
    expect(shown, `화면 ${shown}행 > DB ${inDb}행 — 없는 행을 그리고 있다`).toBeLessThanOrEqual(inDb);
  });

  test("조치내용을 고치면 DB 에 남는다", async ({ page }) => {
    /*
     * 앞 spec 이 만든 개선조치를 기다리지 않는다 — 실행 순서에 매이면 건너뛰고,
     * 건너뛰는 시험은 검증이 아니다. 이 시험이 보려는 것은 「화면이 읽고 고치는가」다.
     * 개선조치가 이탈에서 어떻게 태어나는지는 draft-all.spec 이 본다.
     */
    const idx = seedCorrectiveAction();

    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openCa(page);

    const grid = grids(page).first();
    const row = grid.locator("tbody tr").filter({ hasText: CA_NO }).first();
    await expect(row, "깔아 둔 개선조치가 목록에 없다").toBeVisible({ timeout: 20_000 });
    await row.click();

    const memo = `E2E 조치 ${Date.now().toString().slice(-6)}`;
    const at = Number(await row.getAttribute("data-row-index")) || 0;
    await fillCell(grid, at, "조치내용", memo);
    expect(await saveAndConfirm(page, "/corrective-action-management/save")).toBe(200);

    // 화면이 아니라 DB 에서 확인한다
    await expect
      .poll(
        () => dbOne(`SELECT action_desc FROM tbl_corrective_action WHERE co_cd='${sqlLit(loginCoCd())}' AND idx=${idx}`),
        { timeout: 20_000 },
      )
      .toContain(memo.slice(0, 8));
  });

  test("조치일을 달력으로 고르면 DB 에 8자리로 들어간다", async ({ page }) => {
    /*
     * `tbl_corrective_action.action_dt` 는 varchar(8) YYYYMMDD 다.
     * 화면의 `<input type="date">` 는 `2026-08-27` 10자를 준다 —
     * 그대로 보내면 DB 가 22001(문자열 잘림)로 막아 조치일을 아예 못 적었다.
     * 되돌리는 자리는 MesEditableGrid 한 곳이다. 여기가 그 계약을 붙잡는다.
     */
    const idx = seedCorrectiveAction();

    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openCa(page);

    const grid = grids(page).first();
    const row = grid.locator("tbody tr").filter({ hasText: CA_NO }).first();
    await expect(row, "깔아 둔 개선조치가 목록에 없다").toBeVisible({ timeout: 20_000 });
    await row.click();

    const at = Number(await row.getAttribute("data-row-index")) || 0;
    // 달력이 주는 표기 그대로 넣는다 — 화면이 저장형으로 되돌려야 한다
    await fillCell(grid, at, "조치일", "2026-08-27");
    expect(await saveAndConfirm(page, "/corrective-action-management/save")).toBe(200);

    // 8자리인지까지 본다. 10자가 들어가면 길이가 다르다
    await expect
      .poll(
        () => dbOne(`SELECT action_dt FROM tbl_corrective_action WHERE co_cd='${sqlLit(loginCoCd())}' AND idx=${idx}`),
        { timeout: 20_000 },
      )
      .toBe("20260827");
  });

  test("빈 키로 삭제를 부르면 막는다", async ({ request }) => {
    const { user, pass } = adminCreds();
    const res0 = await request.post(`${API}/api/v1/auth/login`, {
      data: { userId: user, password: pass },
    });
    const token = ((await res0.json())?.data?.token ?? "") as string;
    expect(token, "로그인 실패").not.toBe("");

    for (const path of ["validate-delete", "delete"]) {
      const res = await request.post(`${API}${"/api/v1" + PATH}/${path}`, {
        headers: { Authorization: `Bearer ${token}` },
        data: [],
      });
      // 400 이어야 한다 — 500 이면 막은 게 아니라 터진 것이다
      expect(res.status(), `${path} 가 빈 키를 400 으로 막지 않는다`).toBe(400);
      expect(await res.text()).toContain("삭제할 개선조치를 선택하세요");
    }
  });

  test("옮긴 URL 이 정본이다 — 옛 경로는 404 다", async ({ request }) => {
    const { user, pass } = adminCreds();
    const res0 = await request.post(`${API}/api/v1/auth/login`, {
      data: { userId: user, password: pass },
    });
    const token = ((await res0.json())?.data?.token ?? "") as string;

    const now = await request.get(`${API}/api/v1${PATH}/list`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(now.status(), "옮긴 경로가 안 돈다").toBe(200);

    // 화면 API 를 패키지 이름으로 여는 길은 없어야 한다
    const old = await request.get(`${API}/api/v1/tsk/corrective-action-management/list`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(old.status(), "없는 경로가 404 가 아니다").toBe(404);
  });

  test("이 화면에는 행추가가 없다 — 개선조치는 이탈에서 생긴다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openCa(page);
    await expect(
      btn(page, "행추가"),
      "개선조치를 손으로 만들 수 있으면 이탈 없이 조치가 생긴다",
    ).toHaveCount(0);
  });
});
