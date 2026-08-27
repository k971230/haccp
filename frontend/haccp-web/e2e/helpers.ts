/**
 * helpers — E2E 공통 로그인·화면 열기.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 로그인 셀렉터·성공 판정을 한곳에 둔다 — 스펙마다 복제하면 셸이 바뀔 때 전부 깨진다
 *   2) 자격증명은 환경변수로만 받는다. 스펙 코드에 비밀번호를 박지 않는다
 *   3) 화면 경로는 basename /haccp/ 아래 SCREEN_PATH 그대로다. /screen/{scrnCd} 는 없다
 *
 * PIPELINE[HF130] E2E
 */
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { expect, test, type Locator, type Page } from "@playwright/test";

/** 관리자 계정 — 대부분의 스펙이 쓴다 */
export function adminCreds(): { user: string; pass: string } {
  const user = (process.env.E2E_USER || process.env.SMOKE_USER || "").trim();
  const pass = (process.env.E2E_PASS || process.env.SMOKE_PASS || "").trim();
  if (!user || !pass) {
    throw new Error("E2E_USER/E2E_PASS 가 없습니다. 비밀번호를 커밋하지 마세요.");
  }
  return { user, pass };
}

/** 조회 전용 계정 — 권한 회귀 케이스만 쓴다. 없으면 그 케이스를 건너뛴다 */
export function readonlyCreds(): { user: string; pass: string } | null {
  const user = (process.env.E2E_RO_USER || "").trim();
  const pass = (process.env.E2E_RO_PASS || "").trim();
  return user && pass ? { user, pass } : null;
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 로그인 화면에서 아이디·비밀번호를 넣고 셸이 뜰 때까지 기다린다
 *   2) 모든 스펙의 beforeEach 가 호출한다
 *   3) URL 로 판정하지 않는다 — basename 때문에 잠시 /login 에 남을 수 있다
 *   4) 로그아웃 직후에도 안전하다 — 로그아웃 버튼이 스스로 /login 으로 보내므로
 *      그 이동이 도는 중에 goto 를 부르면 "interrupted by another navigation" 으로 깨진다.
 *      이미 로그인 화면이면 다시 이동하지 않는다
 */
export async function login(page: Page, user: string, pass: string): Promise<void> {
  const idBox = page.locator("#login-user-id");
  // 로그아웃이 보낸 이동이 아직 도는 중일 수 있다 — 잠깐 기다려 보고 없을 때만 직접 간다
  const already = await idBox
    .waitFor({ state: "visible", timeout: 3_000 })
    .then(() => true)
    .catch(() => false);
  if (!already) {
    await page.goto("login", { waitUntil: "domcontentloaded" });
  }
  await expect(idBox).toBeVisible({ timeout: 30_000 });
  await idBox.fill(user);
  await page.locator("#login-password").fill(pass);
  await page.getByRole("button", { name: "로그인" }).click();
  await expect(page.getByRole("button", { name: "로그아웃" })).toBeVisible({ timeout: 30_000 });
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) SCREEN_PATH 경로로 화면을 연다 — 앞의 슬래시는 빼고 baseURL 에 붙인다
 *   2) 스모크·시나리오 스펙이 화면마다 호출한다
 *   3) 셸이 그 화면을 실제로 마운트했는지까지는 호출측이 본다
 */
export async function openScreen(page: Page, path: string): Promise<void> {
  await page.goto(path.replace(/^\//, ""), { waitUntil: "domcontentloaded" });
}

/** 로그인 사용자의 JWT — API 를 직접 부르는 케이스가 쓴다 */
export async function tokenOf(page: Page): Promise<string> {
  const token = await page.evaluate(() => {
    for (let i = 0; i < localStorage.length; i += 1) {
      const k = localStorage.key(i);
      if (k && k.startsWith("haccp-") && k.includes("token")) {
        return localStorage.getItem(k) ?? "";
      }
    }
    return "";
  });
  return (token || "").replace(/^"|"$/g, "");
}

/**
 * 문서를 전부 비운다 — 흐름 시험을 깨끗한 자리에서 시작하려고 쓴다.
 *
 * 목록에 문서번호 열이 없어 「몇 번째 행이 내 문서인가」를 화면으로는 가릴 수 없다.
 * 그래서 시험 전에 비우고 한 건만 만든다. 로컬 전용이며 tools/ 가 있어야 돈다.
 * 없으면 조용히 건너뛴다 — CI 에서 tools/ 는 git 에 없다.
 */
export function resetDocuments(): void {
  const root = repoRoot();
  const sql = path.join(root, "tools", "reset_test_documents.sql");
  /*
   * 도구가 없으면(= CI) 비우지 못한다. 그 상태로 이어 가면 「내 문서가 첫 행」 전제가 깨져
   * 엉뚱한 문서를 보고 통과하거나 실패한다 — 조용히 넘기지 말고 건너뛴다.
   */
  if (!fs.existsSync(sql) || !hasDbTools()) {
    test.skip(true, "tools/ 가 없어 문서를 비울 수 없다 (로컬 전용)");
  }
  // 문서를 전량 지운다 — 운영 DB 면 여기서 멈춘다
  assertTestDb("문서 전량 삭제");
  runDb(`@${sql}`);
}

/** ESM 이라 __dirname 이 없다 — 실행 기준은 항상 frontend/haccp-web 다 */
function repoRoot(): string {
  return path.resolve(process.cwd(), "../..");
}

/** tools/ 는 git 에 없다(로컬 전용) — CI 에서는 DB 대조를 건너뛴다 */
/**
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) DB 를 직접 볼 수 있는 상태인지 본다 — 도구와 접속정보가 **둘 다** 있어야 한다
 *   2) DB 대조가 필요한 시험이 먼저 부른다. 없으면 그 시험을 건너뛴다
 *   3) tools/q.mjs 는 git 에 있어도 backend/.env 는 없다 —
 *      CI 에서 도구만 보고 「있다」고 판정하면 건너뛰던 시험이 실패로 바뀐다
 */
export function hasDbTools(): boolean {
  const root = repoRoot();
  return (
    fs.existsSync(path.join(root, "tools", "q.mjs"))
    && fs.existsSync(path.join(root, "backend", "haccp-api", ".env"))
  );
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 지금 붙은 DB 이름을 backend/.env 에서 읽는다 — q.mjs 와 같은 출처다
 *   2) 자료를 지우는 헬퍼가 부른다
 *   3) 파일이 없거나 값이 없으면 빈 문자열 — 그 경우 아래에서 막는다
 */
function currentDbName(): string {
  try {
    const env = fs.readFileSync(
      path.join(repoRoot(), "backend", "haccp-api", ".env"),
      "utf-8",
    );
    const m = env.match(/^DB_NAME=(.*)$/m);
    return m ? m[1].trim() : "";
  } catch {
    return "";
  }
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 자료를 지우기 전에 「여기가 시험용 DB 인가」를 본다
 *   2) resetDocuments·purgeCompany 처럼 되돌릴 수 없는 것이 부른다
 *   3) 시험용 DB 는 이름이 _test 로 끝난다. 아니면 시험을 멈춘다
 *
 * 운영 DB 와 시험 DB 가 같으면 E2E 한 번에 운영 문서가 통째로 사라진다.
 * 정말 필요하면 E2E_ALLOW_PROD_WRITES=1 로 열 수 있다 — 손으로 켜야 한다.
 */
function assertTestDb(what: string): void {
  if (process.env.E2E_ALLOW_PROD_WRITES === "1") return;
  const db = currentDbName();
  if (db.endsWith("_test")) return;
  throw new Error(
    `${what} 은(는) 시험용 DB 에서만 한다. 지금 DB 는 "${db || "알 수 없음"}" 이다.\n`
      + "backend/haccp-api/.env 의 DB_NAME 을 *_test 로 두거나,\n"
      + "정말 운영을 만져야 하면 E2E_ALLOW_PROD_WRITES=1 로 켠다.",
  );
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) SQL 한 덩어리를 돌리고 Q.java 와 같은 형식의 표를 돌려준다
 *   2) dbRows·dbOne·seedCompany 가 호출한다. 동기라 스펙 어디서나 그냥 쓴다
 *   3) 예전에는 질의마다 JVM 을 띄웠다 — 원격 DB 상대로 1.9초씩 붙고 가끔 물려
 *      Node 이벤트 루프째 막혔다. Windows 에서는 timeout 이 JVM 을 못 죽여
 *      Playwright 의 시험 타임아웃도 안 먹었다. 그래서 JVM 을 걷어냈다 (0.32초)
 */
function runDb(sql: string): string {
  const root = repoRoot();
  return execFileSync("node", [path.join(root, "tools", "q.mjs"), sql], {
    cwd: root,
    encoding: "utf-8",
    // 물리면 멈추지 말고 실패해야 원인이 보인다. q.mjs 안에도 접속·질의 타임아웃이 있다
    timeout: 60_000,
    maxBuffer: 32 * 1024 * 1024,
  });
}

/**
 * DB 를 직접 읽는다 — 화면이 「저장했습니다」라고 해도 실제로 들어갔는지는 여기서만 확인된다.
 *
 * 화면·API 응답만 믿으면 서버가 삼킨 오류를 못 본다(E2E-001 이 그랬다).
 * 첫 줄이 열 이름, 이후가 값이며 열 구분자는 " | " 다.
 *
 * 도구가 없으면(= CI. tools/ 는 git 미포함) 그 시험을 **건너뛴다**.
 * 빈 값을 돌려주면 검사가 조용히 통과해 버려 더 나쁘다.
 */
export function dbRows(sql: string): string[][] {
  if (!hasDbTools()) {
    test.skip(true, "tools/ 가 없어 DB 대조를 건너뛴다 (로컬 전용)");
  }
  return runDb(sql)
    .split(/\r?\n/)
    .filter((l) => l.trim() && !/^-+$/.test(l.trim()) && !/^\(\d+ rows?\)$/.test(l.trim()))
    .map((l) => l.split(" | ").map((c) => c.trim()));
}

/** 한 칸짜리 조회 — count(*) 처럼 값 하나만 볼 때 */
export function dbOne(sql: string): string {
  const rows = dbRows(sql);
  return rows.length > 1 ? rows[1][0] : "";
}

/**
 * 편집 그리드 셀에 값을 넣는다.
 *
 * MesEditableGrid 는 셀을 한 번 누르면 그 자리에 input/select 를 덮어 씌운다.
 * td 순서를 숫자로 박으면 열이 하나 늘 때마다 스펙이 전부 깨지므로 헤더 글자로 자리를 찾는다.
 */
export async function fillCell(
  // grid: 대상 그리드 — 한 화면에 그리드가 여럿이라 범위를 좁혀 받는다
  grid: Locator,
  // rowIndex: 행 위치. 행추가로 만든 새 행은 보통 0
  rowIndex: number,
  // header: 열 제목 그대로
  header: string,
  // value: 넣을 값. select 는 표시 글자가 아니라 값으로 고른다
  value: string,
): Promise<void> {
  const heads = (await grid.locator("thead th").allInnerTexts()).map((t) => t.trim());
  const col = heads.indexOf(header);
  expect(col, `${header} 열을 찾지 못했다 — 실제 헤더: ${heads.join("/")}`).toBeGreaterThanOrEqual(0);

  const cell = grid.locator("tbody tr").nth(rowIndex).locator("td").nth(col);
  await cell.click();
  const select = cell.locator("select");
  if (await select.count()) {
    await select.selectOption(value);
    return;
  }
  const input = cell.locator("input:not([type=checkbox])");
  await input.waitFor({ state: "visible", timeout: 5_000 });
  await input.fill(value);
  // blur 해야 그리드 버퍼에 값이 확정된다
  await input.press("Tab");
}

/**
 * 저장을 누르고 확인창까지 넘긴다.
 *
 * 이 프로젝트의 저장·삭제·전송은 모두 mesConfirm 을 거친다.
 * 확인을 안 누르면 요청 자체가 안 나가고 화면은 아무 말도 안 한다 — 스펙이 조용히 통과해 버린다.
 * @returns 서버 응답. 상태코드까지 봐야 「저장했습니다」 뒤에 숨은 실패를 잡는다
 */
export async function saveAndConfirm(
  page: Page,
  // urlPart: 기다릴 저장 API 의 일부
  urlPart: string,
  // button: 저장 버튼. 화면에 저장이 여럿이면 좁혀서 넘긴다
  button?: Locator,
): Promise<number> {
  const done = page.waitForResponse(
    (r) => r.url().includes(urlPart) && r.request().method() !== "GET",
    { timeout: 30_000 },
  );
  await (button ?? btn(page, "저장")).click();
  /*
   * 대부분의 저장은 mesConfirm 을 거치지만 전부는 아니다(HTML 양식 복사는 바로 나간다).
   * 확인창이 뜨면 넘기고, 안 뜨면 그냥 기다린다 — 없는 버튼을 기다리다 시험이 통째로 멈추지 않게.
   */
  const ok = btn(page, "확인");
  await ok
    .waitFor({ state: "visible", timeout: 3_000 })
    .then(() => ok.click())
    .catch(() => undefined);
  return (await done).status();
}

/**
 * 행추가를 누르고 새 행의 위치를 돌려준다.
 *
 * 새 행이 맨 위에 붙는지 맨 아래에 붙는지는 화면마다 다르다.
 * 「추가 전 건수」를 세어 두고 늘어난 자리를 찾는 편이 화면 구현에 안 매인다.
 */
export async function addRow(page: Page, grid: Locator): Promise<number> {
  await btn(page, /행\s*추가/).click();
  /*
   * 건수로 판정하지 않는다 — 그리드가 페이지당 10행이라 목록이 꽉 차 있으면 행을 더해도 보이는 수가 그대로다.
   * 빈 칸 세기도 못 쓴다 — 사용여부처럼 기본값이 들어간 칸이 있다.
   * useEditableRows 가 신규행 키에 __new_ 를 붙인다(tr[data-key]). 그걸로 잡는다.
   */
  /*
   * 편집 그리드는 useEditableRows 가 __new_ 키를 붙인다.
   * HTML 양식 원본 화면만 예외다 — 행추가가 「표준 복사」라 키가 pending 하나로 고정돼 있다.
   */
  const fresh = grid
    .locator('tbody tr[data-key^="__new_"], tbody tr[data-key="pending"]')
    .last();
  await fresh.waitFor({ state: "visible", timeout: 10_000 });
  const key = await fresh.getAttribute("data-key");
  const keys = await grid.locator("tbody tr").evaluateAll((trs) =>
    trs.map((tr) => tr.getAttribute("data-key") ?? ""),
  );
  return keys.indexOf(key ?? "");
}

/**
 * 지금 보이는 탭의 버튼.
 *
 * 셸은 닫지 않은 탭을 DOM 에 남겨 둔다. 이름만으로 잡으면 뒤에 숨은 탭의 버튼을 누른다 —
 * 클릭은 성공하고 화면은 아무 반응이 없어 원인을 찾기 어렵다.
 */
export function btn(page: Page, name: string | RegExp): Locator {
  return page.getByRole("button", { name, exact: typeof name === "string" }).filter({ visible: true }).first();
}

/** 지금 보이는 탭의 그리드 — nth 는 보이는 것들 사이의 순번이다 */
export function grids(page: Page): Locator {
  return page.locator("table").filter({ visible: true });
}

/**
 * 작성 6화면 공통 — 문서 한 건을 만들고 지면을 열어 준다.
 *
 * 여섯 화면이 같은 프레임(HtmlFormDraftPage / HwpDraftPage)을 쓴다.
 * 좌측에서 행추가 → 양식 선택 → 저장까지 해야 docIdx 가 생기고 우측 지면이 편집 가능해진다.
 * @returns 좌측 목록에서 그 문서의 행
 */
export async function createDraft(
  page: Page,
  // path: 화면 경로
  path: string,
  // tmplPrefix: 고를 양식코드의 앞부분
  tmplPrefix: string,
): Promise<Locator> {
  await openScreen(page, path);
  await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });

  const list = grids(page).first();
  const before = await list.locator("tbody tr").count();
  await btn(page, /행\s*추가/).click();

  // 양식코드 칸의 셀 버튼이 양식 선택 팝업을 연다 — 손으로 칠 수 없는 칸이다
  const pick = page.getByTitle("양식 선택").filter({ visible: true }).first();
  await pick.scrollIntoViewIfNeeded();
  await pick.click({ force: true });
  const popupRow = page.getByRole("row").filter({ hasText: tmplPrefix }).last();
  await expect(popupRow).toBeVisible({ timeout: 20_000 });
  await popupRow.dblclick();

  // 좌측 저장 — 여기서 docIdx 가 생긴다. 그 전까지 우측 지면은 읽기 전용이다
  const [saveRes] = await Promise.all([
    page.waitForResponse((r) => r.url().includes("/save") && r.request().method() !== "GET", {
      timeout: 30_000,
    }),
    btn(page, "저장").click(),
  ]);

  /*
   * 방금 만든 문서의 idx 를 응답에서 받아 **그 행을** 연다.
   * 자리(nth)로만 잡으면 안 된다 — 목록에 같은 양식의 옛 문서가 쌓인 화면에서는
   * 엉뚱한 행, 그것도 이미 결재까지 끝나 읽기 전용인 문서를 열게 된다.
   * 그러면 지면이 잠겨 시험이 엉뚱한 곳에서 터진다.
   */
  let docIdx = "";
  try {
    const body = (await saveRes.json()) as { data?: unknown };
    const d = body?.data;
    if (typeof d === "number" || typeof d === "string") docIdx = String(d);
    else if (Array.isArray(d) && d.length) docIdx = String(d[d.length - 1]);
  } catch {
    // 응답이 JSON 이 아니면 자리로 되돌아간다
  }

  const byKey = docIdx ? list.locator(`tbody tr[data-key="${docIdx}"]`) : null;
  const row = byKey && (await byKey.count()) > 0
    ? byKey.first()
    : list.locator("tbody tr").nth(before);
  await row.click();
  return row;
}

/**
 * 지면 필수값을 채운다 — 전송이 막히지 않을 만큼만.
 *
 * 기록 표는 줄마다 라디오 그룹이 따로다. 한 그룹만 찍으면 다음 줄에서 다시 막힌다.
 */
export async function fillPaperRequired(page: Page): Promise<void> {
  const groups = [
    ...new Set(
      await page
        .locator('input[type="radio"]:not([disabled])')
        .evaluateAll((els) => els.map((e) => (e as HTMLInputElement).name)),
    ),
  ];
  for (const name of groups) {
    await page.locator(`input[type="radio"][name="${name}"]`).first().check({ force: true });
  }
  const times = page.locator('input[type="time"]:not([disabled])');
  for (let i = 0; i < (await times.count()); i += 1) {
    if (!(await times.nth(i).inputValue())) await times.nth(i).fill("09:30");
  }
  const nums = page.locator('input[type="number"]:not([disabled])');
  for (let i = 0; i < (await nums.count()); i += 1) {
    if (!(await nums.nth(i).inputValue())) await nums.nth(i).fill("1");
  }
}

/**
 * 지금 보이는 탭의 그리드 행.
 *
 * 셸은 닫지 않은 탭을 DOM 에 남긴다. page.getByRole("row") 로 잡으면 뒤에 숨은 탭의 행이 먼저 걸려
 * 「보이지 않는 요소를 누르려다 시험이 통째로 멈추는」 일이 생긴다.
 */
export function visibleRows(page: Page): Locator {
  return page.getByRole("row").filter({ visible: true });
}

/**
 * 문서 idx 로 그 행을 집는다.
 *
 * 목록에 보이는 열은 좌우 폭에 따라 달라져 「양식코드가 보이는가」로 행을 못 찾는다.
 * 탭을 여럿 열어 두면 「첫 그리드」도 못 믿는다.
 * 그리드는 행 tr 에 업무키를 data-key 로 달아 두므로 그게 가장 확실한 손잡이다.
 */
export function rowOfDoc(page: Page, docIdx: string | number): Locator {
  return page.locator(`tr[data-key="${docIdx}"]`).filter({ visible: true }).first();
}

/**
 * 삭제 확인창의 긍정 버튼을 누른다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 확인창은 mes-notice 다이얼로그이고 긍정 버튼 글자가 **「삭제」**다 — 「확인」이 아니다
 *   2) 툴바 「삭제」와 글자가 같아 다이얼로그 안으로 범위를 좁혀야 한다
 *   3) 이 구분을 안 하면 아무것도 안 누르고 시험이 통과한다 (2026-08-26 실제로 그랬다)
 */
export function confirmDeleteBtn(page: Page): Locator {
  return page
    .locator('[role=dialog], .mes-notice')
    .filter({ visible: true })
    .locator("button")
    .filter({ hasText: /^삭제$/ })
    .first();
}

/**
 * 신규 업체 시드(06_company_seed.sql)를 돌린다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 그 파일은 psql 전용 메타명령(\if·\set·\gset)을 머리말에만 쓴다. 본문은 순수 SQL 이다
 *   2) psql 이 없는 개발 PC 에서도 시드를 **실제로 돌려 보려고** 여기서 변수만 바꿔 넣는다
 *   3) 값 치환 규칙은 psql 과 같다 — :'x' 는 작은따옴표 문자열이다. 본문 SQL 은 손대지 않는다
 *
 * 시드 자체를 베끼지 않는다. 파일을 읽어 돌리므로 정본은 계속 06_company_seed.sql 하나다.
 */
export function seedCompany(vars: {
  coCd: string;
  coNm?: string;
  adminId?: string;
  srcCo?: string;
}): void {
  if (!hasDbTools()) {
    test.skip(true, "tools/ 가 없어 업체 개설 시드를 건너뛴다 (로컬 전용)");
  }
  assertTestDb("업체 개설 시드");
  const file = path.join(repoRoot(), "db_sasshaccp", "06_company_seed.sql");
  const raw = fs.readFileSync(file, "utf-8");

  const v: Record<string, string> = {
    co_cd: vars.coCd,
    co_nm: vars.coNm ?? "E2E 신규업체",
    admin_id: vars.adminId ?? `admin${vars.coCd}`,
    // '1234' 의 BCrypt 해시 — 시드 기본값과 같다
    admin_pw: "$2a$10$omCFk.XMhqOp5dAmMQ7Me.Rp9c0f87cCPZS3IRg1avF5PVWRzjw4O",
    src_co: vars.srcCo ?? "0000",
  };

  const body = raw
    .split(/\r?\n/)
    // psql 메타명령 줄을 걷어낸다 — 전부 머리말의 기본값·가드다
    .filter((l) => !/^\s*\\/.test(l))
    // gset 으로 끝나던 가드 질의도 뺀다. 같은 검사는 아래에서 직접 한다
    .filter((l) => !l.includes("\\gset"))
    .join("\n")
    .replace(/:'([a-z_]+)'/g, (_m, name: string) => {
      const val = v[name];
      if (val == null) throw new Error(`시드 변수 ${name} 에 값이 없다`);
      return `'${val.replace(/'/g, "''")}'`;
    });

  if (v.co_cd === v.src_co) throw new Error("원본 회사코드와 같다 — 다른 co_cd 로 돌린다");
  runDb(body);
}

/** 업체 하나를 통째로 지운다 — 시드가 만든 표를 역순으로 비운다 */
export function purgeCompany(coCd: string): void {
  if (!hasDbTools()) return;
  if (coCd === "0000") throw new Error("표준 업체(0000)는 지울 수 없다");
  assertTestDb("업체 통째 삭제");
  for (const t of [
    "tbl_doc_no_rule",
    "tbl_company_template",
    "tbl_approval_line_step",
    "tbl_approval_line",
    "tbl_role_screen",
    "tbl_menu",
    "tbl_user",
    "tbl_dept",
    "tbl_role",
    "tbl_code",
    "tbl_company",
  ]) {
    runDb(`DELETE FROM ${t} WHERE co_cd = '${coCd}'`);
  }
}
