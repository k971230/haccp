/**
 * grid-features — 커스텀 그리드의 있는 기능 전부.
 *
 * 개발자: 박승우
 * 일자: 2026-08-27
 * 코멘트:
 *   1) 그리드는 스물여덟 화면이 같이 쓴다 — 여기가 무르면 전 화면이 같이 무른다.
 *      셸이 일괄로 주므로 대표 화면 둘에서 기능별로 본다
 *   2) 셸은 **먼저 열린 탭을 mount 한 채 숨긴다** (오늘 할 일이 늘 남아 있다).
 *      page 전체에서 .first() 를 잡으면 안 보이는 탭의 그리드를 집는다 —
 *      반드시 :visible 로 거른 뒤 그 안에서 찾는다
 *   3) 그리드는 **가상 스크롤**이다. 총 550건이어도 DOM 에는 스물 몇 행뿐이다 —
 *      「보이는 행 전부」로 목록을 판정하면 안 된다
 *   4) 열 설정은 **아이디별**이다 (tbl_grid_pref: co_cd+user_id+scrn_cd+grid_id).
 *      DB 를 직접 읽어 저장 여부와 사용자 분리를 확인한다
 *
 * PIPELINE[HF130] E2E
 */
import { readFileSync } from "node:fs";
import { expect, test, type Locator, type Page } from "@playwright/test";
import { adminCreds, dbOne, dbRows, hasDbTools, login, openScreen } from "./helpers";

/** 조회 그리드 대표 — 행이 늘 있고 편집이 없다 */
const DATA_SCREEN = "/sys/logs/login-history";
const DATA_SCRN_CD = "login-history";
const DATA_GRID_ID = "log-login-history";

/** 편집 그리드 대표 — 홑 그리드라 셀 편집을 보기 쉽다 */
const EDIT_SCREEN = "/sys/code/department-management";
const EDIT_SCRN_CD = "department-management";
const EDIT_GRID_ID = "dept-mgmt-master-v2";

/** 한 화면에 그리드가 셋인 화면 — 저장 칸이 서로 갈리는지 볼 때 쓴다 */
const MULTI_SCREEN = "/sys/code/common-code-management";
const MULTI_SCRN_CD = "common-code-management";
const MULTI_GRID_ID = "code-mgmt-group";

/**
 * 지금 보이는 그리드 감싸개들.
 * 숨은 탭이 mount 된 채 남으므로 :visible 로 거르지 않으면 엉뚱한 그리드를 집는다.
 */
function wraps(page: Page): Locator {
  return page.locator(".mes-grid-wrap:visible");
}

/** 활성 행의 data-key — 없으면 빈 문자열 */
async function activeKey(wrap: Locator): Promise<string> {
  const row = wrap.locator("tbody tr.mes-row-active").first();
  if ((await row.count()) === 0) return "";
  return (await row.getAttribute("data-key")) ?? "";
}

/**
 * 포커스 셀의 열 번호 — 없으면 -1.
 * td 에는 data-field 가 없어서(편집 입력칸에만 붙는다) 자리로 센다.
 */
async function focusCol(wrap: Locator): Promise<number> {
  return wrap.evaluate((el) => {
    const td = el.querySelector("tbody td.mes-cell-focus");
    if (!td) return -1;
    return Array.from(td.parentElement?.children ?? []).indexOf(td);
  });
}

/**
 * 편집 가능한 셀 — mes-cell-editable 은 td 안쪽 div 에 붙는다.
 * **이 자리는 흔들린다** — 셀 하나가 편집으로 열리면 그 td 는 이 목록에서 빠져
 * `.first()` 가 옆 칸을 가리키게 된다. 값을 견주는 시험에는 쓰지 않는다
 * (그렇게 써서 Delete 시험이 헛통과했다). 자리를 고정할 때는 cellAt 을 쓴다.
 */
function editableCells(wrap: Locator): Locator {
  return wrap.locator("tbody td:has(div.mes-cell-editable)");
}

/** 행 번호(0부터)와 열 이름으로 셀을 고정해 잡는다 */
async function cellAt(wrap: Locator, rowIndex: number, header: string): Promise<Locator> {
  const at = await colIndexOf(wrap, header);
  return wrap.locator("tbody tr").nth(rowIndex).locator("td").nth(at - 1);
}

/**
 * 열 표시/숨김 메뉴.
 * mes-grid-wrap 의 overflow 에 잘리지 않게 body 로 portal 된다 (ADR-034).
 * Tailwind 클래스(z-[200])로 찾으면 클래스가 바뀔 때 같이 깨지므로 내용으로 찾는다.
 */
function colMenu(page: Page): Locator {
  // #root 를 빼지 않으면 앱 전체가 걸린다 — 그 안에도 체크박스가 있다
  return page
    .locator("body > div:not(#root)")
    .filter({ has: page.locator("label input[type=checkbox]") })
    .last();
}

/** 보이는 열 헤더 문구 목록 */
async function headers(wrap: Locator): Promise<string[]> {
  return wrap.locator("thead tr").first().locator("th").allInnerTexts();
}

/** 그려진 행의 n번째 칸 값들 — 가상 스크롤이라 「보이는 만큼」이다 */
async function renderedCol(wrap: Locator, nth = 2): Promise<string[]> {
  return wrap.locator(`tbody tr td:nth-child(${nth})`).allInnerTexts();
}

/**
 * 이름으로 열을 찾는다 — 1-based td 자리(nth-child 용)를 준다.
 * 자리를 숫자로 박으면 안 된다. 번호 열(rownum)에는 `.mes-th-inner` 가 없어서
 * 헤더 목록과 셀 목록의 번호가 서로 하나씩 밀린다 —
 * 그래서 「로그아웃 일시로 정렬하고 로그인 일시를 읽는」 일이 실제로 벌어졌다.
 */
async function colIndexOf(wrap: Locator, header: string): Promise<number> {
  const idx = await wrap.evaluate((el, name) => {
    const ths = Array.from(el.querySelectorAll("thead tr:first-child th"));
    return ths.findIndex((t) => (t.textContent ?? "").trim() === name);
  }, header);
  expect(idx, `${header} 열이 없다`).toBeGreaterThanOrEqual(0);
  return idx + 1;
}

/**
 * 그 열의 필터 입력칸.
 * 필터 행은 th 수는 같은데 번호 열 th 에는 입력이 없다 —
 * 입력만 세면 번호가 하나 밀린다. th 자리로 맞춘다.
 */
function filterBox(wrap: Locator, colIndex1Based: number): Locator {
  return wrap
    .locator("thead tr")
    .last()
    .locator("th")
    .nth(colIndex1Based - 1)
    .locator("input");
}

/** 이름으로 찾은 열의 정렬 손잡이 */
function sortHandle(wrap: Locator, header: string): Locator {
  return wrap
    .locator("thead tr")
    .first()
    .locator("th")
    .filter({ hasText: new RegExp(`^${header}$`) })
    .locator(".mes-th-inner");
}

/**
 * 푸터가 말하는 지금 보이는 건수.
 * 거르면 「총 550건 · 표시 3건」이 된다 — 총 건수는 안 줄어드니 표시 쪽을 읽어야 한다.
 */
async function shownCount(wrap: Locator): Promise<number> {
  const text = await wrap.getByText(/총\s*[0-9,]+\s*건/).first().innerText();
  const shown = /표시\s*([0-9,]+)\s*건/.exec(text);
  if (shown) return Number(shown[1].replace(/,/g, ""));
  const total = /총\s*([0-9,]+)\s*건/.exec(text);
  expect(total, `푸터에서 건수를 못 읽는다: ${text}`).not.toBeNull();
  return Number(total![1].replace(/,/g, ""));
}

/** 푸터가 말하는 전체 건수 — 거르기 전 원본 크기 */
async function totalCount(wrap: Locator): Promise<number> {
  const text = await wrap.getByText(/총\s*[0-9,]+\s*건/).first().innerText();
  const m = /총\s*([0-9,]+)\s*건/.exec(text);
  expect(m, `푸터에서 총 건수를 못 읽는다: ${text}`).not.toBeNull();
  return Number(m![1].replace(/,/g, ""));
}

/** 그리드가 행을 채울 때까지 기다린다 */
async function waitRows(wrap: Locator, atLeast = 2): Promise<void> {
  await expect
    .poll(async () => wrap.locator("tbody tr").count(), { timeout: 30_000 })
    .toBeGreaterThanOrEqual(atLeast);
}

/**
 * pref 는 **SQL 에서 뽑는다.**
 * pref_json 을 통째로 가져오면 dbRows 의 " | " 분해에 걸려 JSON 이 잘린다.
 */
function prefValue(expr: string, scrnCd: string, gridId: string, userId = "admin"): string {
  return dbOne(
    `SELECT COALESCE((${expr})::text,'') FROM tbl_grid_pref
      WHERE co_cd='0000' AND user_id='${userId}'
        AND scrn_cd='${scrnCd}' AND grid_id='${gridId}'`,
  );
}

/** pref 행이 있는가 — 저장 여부만 볼 때 */
function hasPref(scrnCd: string, gridId: string, userId = "admin"): boolean {
  return (
    dbOne(
      `SELECT count(*) FROM tbl_grid_pref
        WHERE co_cd='0000' AND user_id='${userId}'
          AND scrn_cd='${scrnCd}' AND grid_id='${gridId}'`,
    ) !== "0"
  );
}

/**
 * 열 설정을 싹 지운다.
 * 남겨 두면 앞 시험이 숨긴 열이 다음 시험까지 따라와,
 * 「로그아웃 일시 열이 없다」 같은 엉뚱한 실패가 난다.
 */
function wipePrefs(): void {
  if (!hasDbTools()) return;
  dbOne("DELETE FROM tbl_grid_pref");
}

test.beforeEach(wipePrefs);
test.afterAll(wipePrefs);

/** 조회 화면을 열고 그 화면의 그리드를 준다 */
async function openData(page: Page): Promise<Locator> {
  const { user, pass } = adminCreds();
  await login(page, user, pass);
  await openScreen(page, DATA_SCREEN);
  // 오늘 할 일 탭이 숨은 채 남아 있다 — 보이는 것 중 마지막이 방금 연 화면이다
  const wrap = wraps(page).last();
  await waitRows(wrap);
  return wrap;
}

/** 편집 화면을 열고 그 그리드를 준다 */
async function openEdit(page: Page): Promise<Locator> {
  const { user, pass } = adminCreds();
  await login(page, user, pass);
  await openScreen(page, EDIT_SCREEN);
  const wrap = wraps(page).last();
  await waitRows(wrap);
  return wrap;
}

/** 그리드 셋짜리 화면을 열고 첫 그리드를 준다 */
async function openMulti(page: Page): Promise<Locator> {
  const { user, pass } = adminCreds();
  await login(page, user, pass);
  await openScreen(page, MULTI_SCREEN);
  // 공통코드는 좌 대분류 · 우상 시스템 · 우하 사용자 셋이다. 좌 대분류가 첫 번째다
  const wrap = wraps(page).first();
  await waitRows(wrap);
  return wrap;
}

// ==========================================================================
//  1. 조회 그리드 — 정렬·필터·검색·열·틀고정·CSV·가상스크롤
// ==========================================================================

test.describe("커스텀 그리드 — 조회", () => {
  test("헤더를 누르면 정렬되고, 다시 누르면 방향이 뒤집힌다", async ({ page }) => {
    const wrap = await openData(page);

    // 누른 열과 읽는 열이 반드시 같아야 한다 — 이름으로 맞춘다
    const COL = "로그인 일시";
    const at = await colIndexOf(wrap, COL);
    await sortHandle(wrap, COL).click();
    await expect(wrap.locator("thead .mes-th-sort").first()).toBeVisible();

    /*
     * 가상 스크롤이라 목록 전체를 못 본다 — 그려진 만큼이 정렬돼 있는지로 본다.
     * 첫 클릭이 오름차순이라고 단정하지 않는다. 열마다 기본 방향이 다르다.
     */
    const isAsc = (v: string[]) => JSON.stringify([...v].sort()) === JSON.stringify(v);
    const isDesc = (v: string[]) => JSON.stringify([...v].sort().reverse()) === JSON.stringify(v);

    const one = await renderedCol(wrap, at);
    expect(one.length, "정렬 뒤 그려진 행이 없다").toBeGreaterThan(1);
    expect(isAsc(one) || isDesc(one), `한 번 눌렀는데 정렬이 안 됐다: ${one.join(",")}`).toBe(true);

    await sortHandle(wrap, COL).click();
    const two = await renderedCol(wrap, at);
    expect(isAsc(two) || isDesc(two), `두 번째도 정렬 상태여야 한다: ${two.join(",")}`).toBe(true);
    // 값이 전부 같으면 뒤집혀도 같아 보이므로 그건 넘어간다
    if (new Set(one).size > 1) {
      expect(isAsc(one), "두 번 눌러도 같은 방향이다").not.toBe(isAsc(two));
    }
  });

  test("Shift 를 누르고 헤더를 누르면 다중 정렬로 순번이 붙는다", async ({ page }) => {
    const wrap = await openData(page);

    const ths = wrap.locator("thead tr").first().locator("th .mes-th-inner");
    await ths.nth(1).click();
    await ths.nth(2).click({ modifiers: ["Shift"] });

    // 두 열이 동시에 정렬 표시를 갖는다
    await expect
      .poll(async () => wrap.locator("thead .mes-th-sort").count(), { timeout: 10_000 })
      .toBeGreaterThanOrEqual(2);
    // 순번(1·2)이 보여야 몇 번째 기준인지 안다
    await expect(wrap.locator("thead .mes-th-sort").first()).toContainText(/[12]/);
  });

  test("Shift 없이 다른 헤더를 누르면 정렬 기준이 하나로 바뀐다", async ({ page }) => {
    const wrap = await openData(page);

    const ths = wrap.locator("thead tr").first().locator("th .mes-th-inner");
    await ths.nth(1).click();
    await ths.nth(2).click({ modifiers: ["Shift"] });
    await expect
      .poll(async () => wrap.locator("thead .mes-th-sort").count(), { timeout: 10_000 })
      .toBeGreaterThanOrEqual(2);

    // Shift 없이 누르면 누적이 아니라 교체다 — 아니면 기준이 무한히 쌓인다
    await ths.nth(3).click();
    await expect
      .poll(async () => wrap.locator("thead .mes-th-sort").count(), { timeout: 10_000 })
      .toBe(1);
  });

  test("필터 행을 열고 값을 넣으면 걸러지고, 지우면 되돌아온다", async ({ page }) => {
    const wrap = await openData(page);
    const before = await shownCount(wrap);

    await wrap.getByTitle("컬럼별 필터").click();
    await expect(wrap.locator("thead input[placeholder='…']").first()).toBeVisible();

    /*
     * 날짜 열로 거르면 안 된다 — 화면은 "2026-08-27 09:31" 로 꾸며 보여주지만
     * 거르기는 원본 값과 맞춰 보므로 아무것도 안 걸린다.
     * 꾸미지 않는 글자 열(사용자 ID)로 건다.
     */
    const at = await colIndexOf(wrap, "사용자 ID");
    const sample = (await wrap.locator(`tbody tr td:nth-child(${at})`).first().innerText()).trim();
    expect(sample, "거를 표본 값이 비어 있다").not.toBe("");
    await filterBox(wrap, at).fill(sample);

    await expect.poll(() => shownCount(wrap), { timeout: 15_000 }).toBeLessThan(before);
    expect(await shownCount(wrap), "필터를 걸었는데 남는 행이 없다").toBeGreaterThan(0);
    // 총 건수는 안 줄어야 한다 — 거르기는 원본을 깎는 게 아니다
    expect(await totalCount(wrap), "거르면서 총 건수까지 깎았다").toBeGreaterThanOrEqual(before);

    // 지우면 원래대로 — 필터가 목록을 영구히 깎으면 안 된다
    await filterBox(wrap, at).fill("");
    await expect.poll(() => shownCount(wrap), { timeout: 15_000 }).toBe(before);
  });

  test("결과 내 검색은 전 열을 훑고, 지우면 되돌아온다", async ({ page }) => {
    const wrap = await openData(page);
    const before = await shownCount(wrap);

    const box = wrap.getByPlaceholder("결과 내 검색…");
    await box.fill("찾을리없는값zzz");
    await expect.poll(() => shownCount(wrap), { timeout: 15_000 }).toBe(0);
    await expect(wrap.locator("tbody tr")).toHaveCount(0);

    await box.fill("");
    await expect.poll(() => shownCount(wrap), { timeout: 15_000 }).toBe(before);
  });

  test("열 메뉴에서 끄면 그 열이 사라지고 다시 켜면 돌아온다", async ({ page }) => {
    const wrap = await openData(page);
    const before = await headers(wrap);

    await wrap.getByTitle("열 표시/숨김").click();
    const menu = colMenu(page);
    await expect(menu).toBeVisible();

    const box = menu.locator("label input[type=checkbox]").nth(1);
    const label = (await menu.locator("label").nth(1).innerText()).trim();
    await box.uncheck();

    await expect
      .poll(async () => (await headers(wrap)).length, { timeout: 10_000 })
      .toBe(before.length - 1);
    expect((await headers(wrap)).join("|"), `${label} 열이 안 사라졌다`).not.toContain(label);

    await box.check();
    await expect
      .poll(async () => (await headers(wrap)).length, { timeout: 10_000 })
      .toBe(before.length);
  });

  test("열 초기화는 숨김·너비를 되돌리고 DB 에도 남는다", async ({ page }) => {
    /*
     * 숨긴 열은 메뉴 체크로도 되살아난다. 초기화가 진짜로 필요한 자리는
     * **너비와 순서**다 — 되돌릴 다른 길이 없다. 그래서 너비까지 흔들어 놓고 본다.
     * DB 까지 보는 까닭은 화면만 되돌아가고 저장된 pref 가 옛 값이면
     * 다음에 들어왔을 때 도로 망가진 표를 보기 때문이다.
     */
    const wrap = await openData(page);
    const before = await headers(wrap);

    // 1) 열 하나를 끄고 너비를 좁힌다
    await wrap.getByTitle("열 표시/숨김").click();
    const menu = colMenu(page);
    await menu.locator("label input[type=checkbox]").nth(1).uncheck();
    await expect
      .poll(async () => (await headers(wrap)).length, { timeout: 10_000 })
      .toBe(before.length - 1);

    // 2) 저장될 때까지 기다린다 (persistLayout 은 500ms debounce)
    await expect
      .poll(() => dbOne("SELECT count(*) FROM tbl_grid_pref WHERE grid_id = 'log-login-history'"), {
        timeout: 10_000,
      })
      .not.toBe("0");

    // 3) 초기화 — 메뉴는 체크를 껐다고 닫히지 않는다. 여기서 또 누르면 도로 닫힌다
    await expect(menu).toBeVisible();
    await menu.getByRole("button", { name: "열 초기화" }).click();
    await expect(menu, "초기화하면 메뉴가 닫힌다").toBeHidden();

    // 4) 화면이 돌아왔나
    await expect
      .poll(async () => (await headers(wrap)).length, { timeout: 10_000 })
      .toBe(before.length);
    expect(await headers(wrap), "열 문구까지 그대로여야 한다").toEqual(before);

    // 5) 저장된 pref 에도 숨김이 남지 않았나 — 다시 들어와도 그대로여야 한다
    await expect
      .poll(
        () =>
          dbOne(
            "SELECT pref_json FROM tbl_grid_pref WHERE grid_id = 'log-login-history' LIMIT 1",
          ),
        { timeout: 10_000 },
      )
      .toContain('"hidden":{}');
  });

  test("틀 고정을 누르면 그 열이 왼쪽에 붙고, 다시 누르면 풀린다", async ({ page }) => {
    const wrap = await openData(page);

    const th = wrap.locator("thead tr").first().locator("th").nth(2);
    await th.hover();
    await th.getByTitle("왼쪽 틀 고정").click();

    await expect(th).toHaveClass(/mes-col-pinned/);
    await expect(th).toHaveCSS("position", "sticky");

    await th.hover();
    await th.getByTitle("틀 고정 해제").click();
    await expect(th).not.toHaveClass(/mes-col-pinned/);
  });

  test("CSV 는 지금 보이는 열만, 거른 행만 담는다", async ({ page }) => {
    /*
     * 파일이 떨어지는 것만 보면 뜻이 없다. 숨긴 열이 CSV 에 따라 나가면
     * 화면에서 감춘 값이 파일로 새어 나가고, 거르기 전 전부가 나가면
     * 「보고 있는 것을 내려받았다」가 거짓이 된다.
     */
    const wrap = await openData(page);
    const total = await totalCount(wrap);

    // 1) 행을 실제로 줄인다 — 로그아웃 일시는 대부분 비어 있어 「2026」이면 확 준다.
    //    사용자 ID 같은 값으로 거르면 전 행이 그대로 남아 시험이 뜻을 잃는다
    await wrap.getByTitle("컬럼별 필터").click();
    const outAt = await colIndexOf(wrap, "로그아웃 일시");
    await filterBox(wrap, outAt).fill("2026");
    await expect.poll(() => shownCount(wrap), { timeout: 15_000 }).toBeLessThan(total);
    const shown = await shownCount(wrap);
    expect(shown, "걸렀더니 남는 행이 없다").toBeGreaterThan(0);

    // 2) 열 하나를 끈다 — 거르기에 쓴 열은 남겨 둔다
    await wrap.getByTitle("열 표시/숨김").click();
    const menu = colMenu(page);
    const last = menu.locator("label").last();
    const hidden = (await last.innerText()).trim();
    await last.locator("input[type=checkbox]").uncheck();
    await page.keyboard.press("Escape");
    await expect
      .poll(async () => (await headers(wrap)).join("|"), { timeout: 10_000 })
      .not.toContain(hidden);

    const wait = page.waitForEvent("download", { timeout: 30_000 });
    await wrap.getByTitle("CSV보내기").click();
    const file = await wait;
    expect(file.suggestedFilename(), "CSV 확장자가 아니다").toMatch(/\.csv$/i);

    const path = await file.path();
    const raw = readFileSync(path, "utf8");
    const lines = raw.replace(/^\uFEFF/, "").split(/\r?\n/).filter((l) => l.trim() !== "");

    // 엑셀이 한글을 깨지 않게 BOM 을 붙인다
    expect(raw.charCodeAt(0), "BOM 이 없어 엑셀에서 한글이 깨진다").toBe(0xfeff);
    expect(lines[0], `숨긴 열 「${hidden}」이 CSV 에 따라 나갔다`).not.toContain(hidden);
    expect(lines.length - 1, `화면은 ${shown}건인데 CSV 는 ${lines.length - 1}건이다`).toBe(shown);
  });

  test("저장된 열 순서대로 그린다", async ({ page }) => {
    /*
     * 헤더 끌어놓기는 HTML5 DnD 라 시험 도구로 안정적으로 못 흉내 낸다.
     * 정작 중요한 건 손짓이 아니라 **결과** — 저장된 순서가 그대로 실리는가다.
     * 그래서 pref 를 직접 깔고 화면이 그대로 그리는지 본다.
     */
    test.skip(!hasDbTools(), "DB 도구가 없으면 pref 를 깔 수 없다");

    // 먼저 기본 순서를 본다
    const wrap = await openData(page);
    const before = await headers(wrap);
    expect(before.length, "열이 모자란다").toBeGreaterThan(3);

    // 뒤 두 열을 맞바꾼 순서를 깐다 — 필드명은 화면이 저장하는 것과 같아야 한다
    // pref 행이 있어야 순서를 심을 수 있다 — 열 하나를 꺼서 한 번 저장시킨다.
    // 숨김은 아래 UPDATE 에서 같이 푼다 (다시 켜면 저장이 늦어 순서 심기와 엉킨다)
    await wrap.getByTitle("열 표시/숨김").click();
    const menu = colMenu(page);
    await menu.locator("label input[type=checkbox]").last().uncheck();
    await expect.poll(() => hasPref(DATA_SCRN_CD, DATA_GRID_ID), { timeout: 20_000 }).toBe(true);
    await page.keyboard.press("Escape");

    dbOne(
      `UPDATE tbl_grid_pref
          SET pref_json = jsonb_set(
                jsonb_set(pref_json::jsonb, '{hidden}', '{}'::jsonb),
                '{order}',
                (SELECT jsonb_agg(x ORDER BY n DESC)
                   FROM jsonb_array_elements(pref_json::jsonb->'order') WITH ORDINALITY AS t(x, n)))::text
        WHERE co_cd='0000' AND user_id='admin'
          AND scrn_cd='${DATA_SCRN_CD}' AND grid_id='${DATA_GRID_ID}'`,
    );

    await page.reload();
    const back = wraps(page).last();
    await waitRows(back);

    const after = await headers(back);
    expect([...after].sort(), "순서를 바꿨더니 열이 사라지거나 늘었다").toEqual([...before].sort());
    expect(after.join("|"), "저장된 열 순서를 안 따른다").not.toBe(before.join("|"));
  });

  test("가상 스크롤 — 총 건수보다 훨씬 적은 행만 그린다", async ({ page }) => {
    const wrap = await openData(page);

    const total = await totalCount(wrap);
    const drawn = await wrap.locator("tbody tr").count();

    expect(total, "총 건수가 너무 적어 가상 스크롤을 볼 수 없다").toBeGreaterThan(100);
    expect(drawn, `${total}건을 통째로 그린다 — 큰 목록에서 화면이 멎는다`).toBeLessThan(total / 2);
  });

  test("스크롤을 내리면 다른 행이 그려진다", async ({ page }) => {
    const wrap = await openData(page);
    const before = await renderedCol(wrap);

    await wrap
      .locator(".mes-grid-scroll")
      .first()
      .evaluate((el) => {
        el.scrollTop = el.scrollHeight / 2;
      });

    await expect
      .poll(async () => (await renderedCol(wrap)).join("|"), { timeout: 15_000 })
      .not.toBe(before.join("|"));
  });
});

// ==========================================================================
//  2. 아이디별 저장 — tbl_grid_pref
// ==========================================================================

test.describe("커스텀 그리드 — 아이디별 열 저장", () => {
  test.skip(() => !hasDbTools(), "DB 도구가 없으면 저장 여부를 확인할 수 없다");

  test("열을 숨기면 그 사용자 행으로 DB 에 남는다", async ({ page }) => {
    expect(hasPref(DATA_SCRN_CD, DATA_GRID_ID), "시작 전 pref 가 남아 있다").toBe(false);

    const wrap = await openData(page);
    await wrap.getByTitle("열 표시/숨김").click();
    const menu = colMenu(page);
    await menu.locator("label input[type=checkbox]").nth(1).uncheck();

    // 500ms debounce 뒤 저장한다
    await expect.poll(() => hasPref(DATA_SCRN_CD, DATA_GRID_ID), { timeout: 20_000 }).toBe(true);

    expect(
      prefValue("pref_json::jsonb->>'v'", DATA_SCRN_CD, DATA_GRID_ID),
      "pref 버전이 2가 아니다",
    ).toBe("2");
    expect(
      Number(
        prefValue(
          "(SELECT count(*) FROM jsonb_each(pref_json::jsonb->'hidden') WHERE value = 'true'::jsonb)",
          DATA_SCRN_CD,
          DATA_GRID_ID,
        ),
      ),
      "숨김이 pref 에 안 담겼다",
    ).toBeGreaterThan(0);
    expect(
      Number(prefValue("jsonb_array_length(pref_json::jsonb->'order')", DATA_SCRN_CD, DATA_GRID_ID)),
      "열 순서가 pref 에 안 담겼다",
    ).toBeGreaterThan(0);
  });

  test("숨긴 열은 새로고침해도 숨은 채로 열린다", async ({ page }) => {
    const wrap = await openData(page);
    const before = (await headers(wrap)).length;

    await wrap.getByTitle("열 표시/숨김").click();
    const menu = colMenu(page);
    const label = (await menu.locator("label").nth(1).innerText()).trim();
    await menu.locator("label input[type=checkbox]").nth(1).uncheck();
    await expect.poll(() => hasPref(DATA_SCRN_CD, DATA_GRID_ID), { timeout: 20_000 }).toBe(true);

    await page.reload();
    const back = wraps(page).last();
    await waitRows(back);

    expect((await headers(back)).length, "새로고침하면 숨긴 열이 되돌아온다").toBe(before - 1);
    expect((await headers(back)).join("|"), `${label} 이 다시 보인다`).not.toContain(label);
  });

  test("열 너비를 끌면 그 값이 pref 에 남는다", async ({ page }) => {
    const wrap = await openData(page);

    const th = wrap.locator("thead tr").first().locator("th").nth(1);
    const box = await th.boundingBox();
    expect(box, "헤더 좌표를 못 읽는다").not.toBeNull();

    // 헤더 오른쪽 끝의 리사이즈 손잡이를 오른쪽으로 끈다
    await page.mouse.move(box!.x + box!.width - 2, box!.y + box!.height / 2);
    await page.mouse.down();
    await page.mouse.move(box!.x + box!.width + 80, box!.y + box!.height / 2, { steps: 10 });
    await page.mouse.up();

    await expect.poll(() => hasPref(DATA_SCRN_CD, DATA_GRID_ID), { timeout: 20_000 }).toBe(true);

    expect(
      Number(
        prefValue(
          `(SELECT count(*) FROM jsonb_object_keys(pref_json::jsonb->'sizing'))`,
          DATA_SCRN_CD,
          DATA_GRID_ID,
        ),
      ),
      "너비가 pref 에 안 담겼다",
    ).toBeGreaterThan(0);
    // 50 미만은 parseGridPref 가 버린다 — 살아남을 값이어야 한다
    expect(
      Number(
        prefValue(
          `(SELECT min(value::numeric) FROM jsonb_each_text(pref_json::jsonb->'sizing'))`,
          DATA_SCRN_CD,
          DATA_GRID_ID,
        ),
      ),
      "너비가 50 미만으로 저장돼 다음에 버려진다",
    ).toBeGreaterThanOrEqual(50);
  });

  test("편집 그리드도 열 설정을 저장한다", async ({ page }) => {
    // 조회 그리드만 되고 편집 그리드가 안 되면 절반만 사는 기능이다
    const wrap = await openEdit(page);

    await wrap.getByTitle("열 표시/숨김").click();
    const menu = colMenu(page);
    await menu.locator("label input[type=checkbox]").nth(1).uncheck();

    await expect.poll(() => hasPref(EDIT_SCRN_CD, EDIT_GRID_ID), { timeout: 20_000 }).toBe(true);
    expect(
      prefValue("pref_json::jsonb->>'v'", EDIT_SCRN_CD, EDIT_GRID_ID),
      "pref 버전이 2가 아니다",
    ).toBe("2");
  });

  test("같은 화면의 그리드끼리도 저장 칸이 따로다", async ({ page }) => {
    const wrap = await openMulti(page);

    await wrap.getByTitle("열 표시/숨김").click();
    const menu = colMenu(page);
    await menu.locator("label input[type=checkbox]").nth(1).uncheck();

    await expect.poll(() => hasPref(MULTI_SCRN_CD, MULTI_GRID_ID), { timeout: 20_000 }).toBe(true);

    // 좌 대분류만 건드렸다 — 우측 둘에는 값이 생기면 안 된다
    expect(hasPref(MULTI_SCRN_CD, "code-mgmt-sys"), "안 건드린 그리드에 값이 생겼다").toBe(false);
    expect(hasPref(MULTI_SCRN_CD, "code-mgmt-usr"), "안 건드린 그리드에 값이 생겼다").toBe(false);
  });

  test("열 설정은 아이디별이다 — 다른 사용자 행을 건드리지 않는다", async ({ page }) => {
    const OTHER = '{"v":2,"hidden":{},"order":[],"sizing":{}}';
    dbOne(
      `INSERT INTO tbl_grid_pref (co_cd, user_id, scrn_cd, grid_id, pref_json, ins_id)
       VALUES ('0000','e2e_other','${DATA_SCRN_CD}','${DATA_GRID_ID}','${OTHER}','e2e')`,
    );

    const wrap = await openData(page);
    await wrap.getByTitle("열 표시/숨김").click();
    const menu = colMenu(page);
    await menu.locator("label input[type=checkbox]").nth(1).uncheck();
    await expect.poll(() => hasPref(DATA_SCRN_CD, DATA_GRID_ID), { timeout: 20_000 }).toBe(true);

    // 남의 행은 그대로여야 한다 — 숨긴 열이 하나도 없어야 원본 그대로다
    expect(
      prefValue(
        `(SELECT count(*) FROM jsonb_each(pref_json::jsonb->'hidden'))`,
        DATA_SCRN_CD,
        DATA_GRID_ID,
        "e2e_other",
      ),
      "다른 사용자의 열 설정을 덮어썼다",
    ).toBe("0");

    // 두 행이 따로 서 있어야 한다
    const rows = dbRows(
      `SELECT user_id FROM tbl_grid_pref
        WHERE co_cd='0000' AND scrn_cd='${DATA_SCRN_CD}' AND grid_id='${DATA_GRID_ID}'
        ORDER BY user_id`,
    );
    // dbRows 는 첫 줄이 열 이름이다 — 자료는 그 다음부터다
    expect(rows.length - 1, "아이디별로 안 나뉜다").toBe(2);
  });

  test("정렬은 저장하지 않는다 — 다음에 열면 원래 순서다", async ({ page }) => {
    /*
     * 표 주석이 「숨김·순서·너비만 저장. 정렬·필터는 세션 보관」이라고 못 박았다.
     * 정렬까지 저장하면 어제 걸어 둔 정렬 때문에 오늘 조회가 이상해 보인다.
     */
    const wrap = await openData(page);
    await wrap.locator("thead tr").first().locator("th .mes-th-inner").nth(1).click();
    await expect(wrap.locator("thead .mes-th-sort").first()).toBeVisible();

    // 정렬만 걸면 저장할 것이 없으므로 pref 행 자체가 안 생겨야 한다
    await page.waitForTimeout(3_000);
    expect(hasPref(DATA_SCRN_CD, DATA_GRID_ID), "정렬을 DB 에 저장한다").toBe(false);
  });
});

// ==========================================================================
//  3. 편집 그리드 — 키보드와 값 변경
// ==========================================================================

test.describe("커스텀 그리드 — 편집", () => {
  test("행을 누르면 활성되고 방향키로 옮겨간다", async ({ page }) => {
    const wrap = await openEdit(page);
    // 셀을 누르면 곧바로 편집이 열린다 — Escape 로 닫고 시작한다
    await wrap.locator("tbody tr").first().click();
    await page.keyboard.press("Escape");

    const first = await activeKey(wrap);
    expect(first, "행을 눌러도 활성 표시가 안 붙는다").not.toBe("");

    await page.keyboard.press("ArrowDown");
    expect(await activeKey(wrap), "ArrowDown 이 안 먹는다").not.toBe(first);

    await page.keyboard.press("ArrowUp");
    expect(await activeKey(wrap), "ArrowUp 이 안 먹는다").toBe(first);
  });

  test("끝 행에서 더 눌러도 순환하지 않고 멈춘다", async ({ page }) => {
    const wrap = await openEdit(page);
    await wrap.locator("tbody tr").first().click();
    await page.keyboard.press("Escape");

    for (let i = 0; i < 30; i += 1) await page.keyboard.press("ArrowDown");
    const bottom = await activeKey(wrap);
    await page.keyboard.press("ArrowDown");
    expect(await activeKey(wrap), "끝에서 첫 행으로 돌아갔다").toBe(bottom);

    for (let i = 0; i < 40; i += 1) await page.keyboard.press("ArrowUp");
    const top = await activeKey(wrap);
    await page.keyboard.press("ArrowUp");
    expect(await activeKey(wrap), "처음에서 끝 행으로 돌아갔다").toBe(top);
    expect(top, "위로 끝까지 갔는데 아래 끝과 같다").not.toBe(bottom);
  });

  test("Tab 은 옆 칸으로, Shift+Tab 은 되돌아간다", async ({ page }) => {
    const wrap = await openEdit(page);

    await editableCells(wrap).first().click();
    await page.keyboard.press("Escape");
    const start = await focusCol(wrap);
    expect(start, "셀을 눌러도 포커스 표시가 안 붙는다").toBeGreaterThanOrEqual(0);

    await page.keyboard.press("Tab");
    await page.keyboard.press("Escape");
    const next = await focusCol(wrap);
    expect(next, "Tab 으로 옆 칸에 안 간다").not.toBe(start);

    await page.keyboard.press("Shift+Tab");
    await page.keyboard.press("Escape");
    expect(await focusCol(wrap), "Shift+Tab 이 안 돌아온다").toBe(start);
  });

  test("마지막 칸에서 Tab 을 누르면 그리드 밖으로 나간다", async ({ page }) => {
    /*
     * Tab 은 「이동에 성공했을 때만」 preventDefault 한다.
     * 늘 가로채면 키보드만으로는 그리드를 영영 빠져나갈 수 없다 —
     * 마우스 없이 쓰는 사람에게는 화면이 잠긴 것과 같다.
     */
    const wrap = await openEdit(page);
    await editableCells(wrap).first().click();
    await page.keyboard.press("Escape");

    // 끝 칸까지 충분히 민다 — 마지막 행 마지막 열을 지나면 밖으로 나가야 한다
    for (let i = 0; i < 200; i += 1) {
      await page.keyboard.press("Tab");
      const inside = await page.evaluate(
        () => !!document.activeElement?.closest(".mes-grid-wrap"),
      );
      if (!inside) return;
    }
    throw new Error("Tab 을 200번 눌러도 그리드를 못 빠져나간다 — 키보드가 갇힌다");
  });

  test("편집 없는 그리드에서도 Tab 이 끝에서 밖으로 나간다", async ({ page }) => {
    /*
     * 공통코드 좌 대분류는 editable={false} — Tab 이 편집을 열지 않고 칸만 옮긴다.
     * 편집이 열리는 그리드는 편집칸의 Tab 경로로도 빠져나가서
     * 「이동 실패면 preventDefault 안 함」 가지가 가려진다. 여기서 그 가지를 본다.
     */
    const wrap = await openMulti(page);
    await wrap.locator("tbody tr").first().locator("td").nth(1).click();

    for (let i = 0; i < 200; i += 1) {
      await page.keyboard.press("Tab");
      const inside = await page.evaluate(
        () => !!document.activeElement?.closest(".mes-grid-wrap"),
      );
      if (!inside) return;
    }
    throw new Error("Tab 을 200번 눌러도 그리드를 못 빠져나간다 — 키보드가 갇힌다");
  });

  test("F2 와 Enter 로 편집이 열리고 Escape 로 닫힌다", async ({ page }) => {
    const wrap = await openEdit(page);
    await editableCells(wrap).first().click();
    await page.keyboard.press("Escape");

    await page.keyboard.press("F2");
    await expect(wrap.locator("input.mes-egrid-input").first()).toBeVisible({ timeout: 10_000 });

    await page.keyboard.press("Escape");
    await expect(wrap.locator("input.mes-egrid-input")).toHaveCount(0);

    await page.keyboard.press("Enter");
    await expect(wrap.locator("input.mes-egrid-input").first()).toBeVisible({ timeout: 10_000 });
    await page.keyboard.press("Escape");
  });

  test("Escape 로 닫아도 키보드가 계속 먹는다", async ({ page }) => {
    /*
     * 2026-08-27 에 고쳤다. 그전에는 Escape 가 포커스를 body 로 흘려보내
     * 방향키·F2·Delete 가 전부 죽었다 — 다시 마우스로 눌러야 살아났다.
     * 키보드로 기록을 치는 현장에서는 이게 손을 멈추게 한다.
     */
    const wrap = await openEdit(page);

    await editableCells(wrap).first().click();
    await expect(wrap.locator("input.mes-egrid-input").first()).toBeVisible({ timeout: 10_000 });
    await page.keyboard.press("Escape");

    // 포커스가 그리드 안에 남아야 한다
    expect(
      await page.evaluate(() => !!document.activeElement?.closest(".mes-grid-wrap")),
      "Escape 뒤 포커스가 그리드 밖으로 빠졌다",
    ).toBe(true);
    // 셀 선택도 남아야 한다 — 어디를 고치던 중이었는지 잃으면 안 된다
    expect(await focusCol(wrap), "Escape 뒤 셀 선택이 사라졌다").toBeGreaterThanOrEqual(0);

    // 그리고 실제로 키가 먹어야 한다
    const before = await activeKey(wrap);
    await page.keyboard.press("ArrowDown");
    expect(await activeKey(wrap), "Escape 뒤 방향키가 죽었다").not.toBe(before);

    await page.keyboard.press("F2");
    await expect(wrap.locator("input.mes-egrid-input").first()).toBeVisible({ timeout: 10_000 });
  });

  test("Escape 는 편집을 닫을 뿐, 친 값을 되돌리지는 않는다", async ({ page }) => {
    /*
     * 엑셀과 다르다. 이 그리드는 타이핑이 곧바로 행 버퍼에 들어가고
     * Escape 는 편집칸만 닫는다 — 친 값은 남고 행은 「변경」으로 표시된다.
     * DB 에 들어가는 시점은 어디까지나 「저장」이다.
     * 여기서는 그 실제 동작을 못 박는다. 바뀌면 이 시험이 먼저 안다.
     */
    const wrap = await openEdit(page);
    const cell = await cellAt(wrap, 0, "부서명");
    const before = (await cell.innerText()).trim();

    await cell.click();
    const input = wrap.locator("input.mes-egrid-input").first();
    await expect(input).toBeVisible({ timeout: 10_000 });
    await input.fill("친값남는다");
    await page.keyboard.press("Escape");

    expect((await cell.innerText()).trim(), "친 값이 사라졌다").toBe("친값남는다");
    expect(before, "견줄 원래 값이 비어 있다").not.toBe("");
    // 아직 DB 에 간 것은 아니다 — 「변경」 표시가 붙고 저장에서 결정된다
    await expect(wrap.locator("tbody tr.mes-row-dirty").first()).toBeVisible({ timeout: 10_000 });
  });

  test("Delete 로 셀 값을 비우면 행이 변경 표시된다", async ({ page }) => {
    const wrap = await openEdit(page);

    // 자리를 고정해 잡는다 — 편집이 열리면 「편집 가능한 셀」 목록에서 그 칸이 빠져
    // .first() 가 옆 칸을 가리키고, 시험이 헛통과한다
    const cell = await cellAt(wrap, 0, "부서명");
    const before = (await cell.innerText()).trim();
    expect(before, "비울 값이 이미 비어 있다").not.toBe("");

    await cell.click();
    await page.keyboard.press("Escape");
    await page.keyboard.press("Delete");

    await expect
      .poll(async () => (await cell.innerText()).trim(), { timeout: 10_000 })
      .not.toBe(before);
    // 바뀐 행에 표시가 안 붙으면 저장 대상에서 빠진다
    await expect(wrap.locator("tbody tr.mes-row-dirty").first()).toBeVisible({ timeout: 10_000 });
  });

  test("Backspace 도 Delete 와 같이 셀을 비운다", async ({ page }) => {
    const wrap = await openEdit(page);

    const cell = await cellAt(wrap, 0, "부서명");
    const before = (await cell.innerText()).trim();
    expect(before, "비울 값이 이미 비어 있다").not.toBe("");

    await cell.click();
    await page.keyboard.press("Escape");
    await page.keyboard.press("Backspace");

    await expect
      .poll(async () => (await cell.innerText()).trim(), { timeout: 10_000 })
      .not.toBe(before);
  });

  test("편집 중에는 방향키가 행을 옮기지 않는다", async ({ page }) => {
    const wrap = await openEdit(page);

    await editableCells(wrap).first().click();
    await page.keyboard.press("Escape");
    await page.keyboard.press("F2");
    await expect(wrap.locator("input.mes-egrid-input").first()).toBeVisible({ timeout: 10_000 });

    const key = await activeKey(wrap);
    await page.keyboard.press("ArrowDown");
    // 편집 중 ArrowDown 은 입력칸 커서를 움직일 뿐 행은 그대로여야 한다
    expect(await activeKey(wrap), "편집 중인데 행이 옮겨갔다").toBe(key);
    await page.keyboard.press("Escape");
  });

  test("검색칸에 타이핑하는 동안 방향키가 그리드를 건드리지 않는다", async ({ page }) => {
    const wrap = await openEdit(page);
    await wrap.locator("tbody tr").first().click();
    await page.keyboard.press("Escape");
    const key = await activeKey(wrap);

    const box = wrap.getByPlaceholder("결과 내 검색…");
    await box.click();
    // 한 방향으로만 민다 — 아래·위를 같이 누르면 서로 상쇄돼 시험이 헛통과한다
    await page.keyboard.press("ArrowDown");
    await page.keyboard.press("ArrowDown");

    expect(await activeKey(wrap), "검색칸에서 방향키가 그리드로 샌다").toBe(key);

    // 글자도 그대로 들어가야 한다 — 가로채면 검색을 못 친다
    await box.fill("");
    await box.type("abc");
    await expect(box).toHaveValue("abc");
  });
});

// ==========================================================================
//  4. 단축키가 브라우저 것을 뺏지 않는가
// ==========================================================================

/*
 * 그리드가 가로채는 키는 화살표·Tab·Enter·F2·Delete·Backspace 뿐이고
 * Ctrl·Meta 조합은 코드에 하나도 없다. 새로고침(Ctrl+R)·저장(Ctrl+S)·
 * 검색(Ctrl+F)·인쇄(Ctrl+P)·주소창(Ctrl+L)·복사·붙여넣기를 뺏을 수 없는 구조다.
 * 여기서는 그 구조가 유지되는지 실제 이벤트로 확인한다.
 */
const BROWSER_COMBOS: ReadonlyArray<readonly [string, string]> = [
  ["r", "새로고침"],
  ["s", "저장"],
  ["f", "브라우저 검색"],
  ["p", "인쇄"],
  ["l", "주소창"],
  ["c", "복사"],
  ["v", "붙여넣기"],
  ["a", "전체선택"],
  ["t", "새 탭"],
  ["w", "탭 닫기"],
];

/** 이 조합을 누가 preventDefault 하는가 — 하면 브라우저 기능이 죽는다 */
async function isIntercepted(page: Page, key: string): Promise<boolean> {
  return page.evaluate((k: string) => {
    let prevented = false;
    const probe = (e: KeyboardEvent) => {
      if (e.defaultPrevented) prevented = true;
    };
    document.addEventListener("keydown", probe);
    const ev = new KeyboardEvent("keydown", {
      key: k,
      ctrlKey: true,
      bubbles: true,
      cancelable: true,
    });
    (document.activeElement ?? document.body).dispatchEvent(ev);
    document.removeEventListener("keydown", probe);
    return prevented;
  }, key);
}

test.describe("커스텀 그리드 — 단축키 예의", () => {
  test("조회 그리드는 Ctrl 조합을 하나도 가로채지 않는다", async ({ page }) => {
    const wrap = await openData(page);
    await wrap.locator("tbody tr").first().click();

    for (const [key, what] of BROWSER_COMBOS) {
      expect(
        await isIntercepted(page, key),
        `Ctrl+${key.toUpperCase()} (${what}) 를 가로챈다`,
      ).toBe(false);
    }
  });

  test("편집 그리드도 Ctrl 조합을 가로채지 않는다", async ({ page }) => {
    const wrap = await openEdit(page);
    await wrap.locator("tbody tr").first().click();
    await page.keyboard.press("Escape");

    for (const [key, what] of BROWSER_COMBOS) {
      expect(
        await isIntercepted(page, key),
        `편집 그리드가 Ctrl+${key.toUpperCase()} (${what}) 를 가로챈다`,
      ).toBe(false);
    }
  });

  test("Backspace 는 입력칸 안에서 글자만 지운다", async ({ page }) => {
    // 늘 가로채면 검색칸에서 글자를 못 지운다
    const wrap = await openData(page);
    await wrap.locator("tbody tr").first().click();

    const box = wrap.getByPlaceholder("결과 내 검색…");
    await box.click();
    await box.fill("abc");
    await page.keyboard.press("Backspace");

    await expect(box).toHaveValue("ab");
  });

  test("조회 그리드는 Tab 을 가두지 않는다", async ({ page }) => {
    // Tab 을 늘 가로채면 키보드만으로 화면을 못 빠져나간다
    const wrap = await openData(page);
    await wrap.locator("tbody tr").first().click();

    await page.keyboard.press("Tab");
    const inside = await page.evaluate(
      () => !!document.activeElement?.closest(".mes-grid-wrap tbody"),
    );
    expect(inside, "조회 그리드가 Tab 을 가둔다").toBe(false);
  });

  test("조회 그리드에서 F2·Delete 는 아무 일도 하지 않는다", async ({ page }) => {
    const wrap = await openData(page);
    const first = await renderedCol(wrap);
    await wrap.locator("tbody tr").first().click();

    await page.keyboard.press("F2");
    await expect(wrap.locator("input.mes-egrid-input")).toHaveCount(0);

    await page.keyboard.press("Delete");
    expect(await renderedCol(wrap), "조회 그리드인데 값이 바뀐다").toEqual(first);
  });
});
