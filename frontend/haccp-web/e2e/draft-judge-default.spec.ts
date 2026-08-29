/**
 * draft-judge-default — 작성 5화면의 판정 기본값과 「모두 적합」.
 *
 * 개발자: 박승우
 * 일자: 2026-08-27
 * 코멘트:
 *   1) 현장 기록은 대부분이 적합이다. 빈 값으로 두면 행마다 라디오를 한 번 더 눌러야 한다 —
 *      새 문서는 **적합으로 깔고** 부적합만 눌러 고치게 한다
 *   2) **금속검출만 다르다.** 거기는 서버가 감도 5칸으로 판정을 계산한다
 *      (`sp_tbl_ccp_metal_monitor_c_000` — 5칸이 기준과 같아야 적합).
 *      화면이 미리 적합으로 칠하면 저장하는 순간 뒤집혀 「보이는 값」과 「저장되는 값」이 달라지고,
 *      감도 확인을 안 한 행이 적합으로 남는다. HACCP 에서 하면 안 되는 일이다
 *   3) 화면 문구가 아니라 **라디오의 checked 상태**로 판정한다.
 *      버튼이 눌렸는지만 보면 값이 안 바뀌어도 통과한다
 *
 * PIPELINE[HF130] E2E
 */
import { expect, test, type Page } from "@playwright/test";
import { adminCreds, createDraft, login } from "./helpers";

/** 판정을 화면이 적합으로 깔아 주는 네 화면 */
const SEEDED = [
  { name: "일반위생·공정점검", path: "/draft/html/hyg-process", tmpl: "html_hyg_prc_" },
  { name: "CCP 검증점검표", path: "/draft/html/ccp-verify", tmpl: "tml_ccp_chk_" },
  { name: "CCP 포장공정", path: "/draft/ccp-monitoring/ccp-pkg", tmpl: "tml_ccp_pkg_" },
  { name: "CCP 가열공정", path: "/draft/ccp-monitoring/ccp-htg", tmpl: "tml_ccp_htg_" },
] as const;

/** 서버가 판정을 계산하는 화면 — 화면이 미리 칠하면 안 된다 */
const AUTO_JUDGED = {
  name: "CCP 금속검출",
  path: "/draft/ccp-monitoring/ccp-mtl",
  tmpl: "tml_ccp_mtl_",
} as const;

const ALL = [...SEEDED, AUTO_JUDGED];

/**
 * 판정 라디오를 짝으로 읽는다.
 * 지면마다 마크업이 달라 자리로 못 박으면 안 된다 — 한 행에 라디오가 둘(적합·부적합)이고
 * 그 둘이 같은 name 을 쓴다는 규칙만 쓴다.
 * 금속검출의 검출 O/X 라디오(`mtl-ox-…`)는 판정이 아니라 측정값이라 뺀다.
 */
async function judgePairs(
  page: Page,
): Promise<{ name: string; pass: boolean; fail: boolean; on: boolean }[]> {
  return page.evaluate(() => {
    const byName = new Map<string, HTMLInputElement[]>();
    for (const el of Array.from(document.querySelectorAll<HTMLInputElement>("input[type=radio]"))) {
      // 셸이 mount 한 채 숨긴 앞 탭은 뺀다
      const r = el.getBoundingClientRect();
      if (r.width === 0 && r.height === 0) continue;
      if (!/(^|-)pf-|^yn-/.test(el.name)) continue;
      const list = byName.get(el.name) ?? [];
      list.push(el);
      byName.set(el.name, list);
    }
    return Array.from(byName.entries())
      .filter(([, list]) => list.length === 2)
      .map(([name, list]) => ({
        name,
        pass: list[0].checked,
        fail: list[1].checked,
        // 저장 전 지면은 읽기 전용이다 — 그때 누르면 아무 일도 안 난다
        on: !list[0].disabled && !list[1].disabled,
      }));
  });
}

/**
 * 지면이 다 그려지고 **편집 가능해질 때까지** 기다린 뒤 판정 짝을 준다.
 * 좌측 저장 직후 잠깐은 읽기 전용이라, 그때 라디오를 누르면 아무 일도 안 난다 —
 * 그걸 안 기다려서 시험이 엉뚱하게 터졌다.
 */
async function settledPairs(page: Page, where: string) {
  /*
   * 「모두 적합」 버튼은 작성 행(writeRows)이 들어왔을 때만 그려진다 —
   * 그전까지 지면은 **미리보기 행**을 그리고, 그 라디오는 눌러도 아무 일이 없다.
   * 버튼이 보일 때까지 기다리는 게 「이제 진짜 작성 지면이다」의 신호다.
   */
  await expect(page.getByRole("button", { name: "모두 적합" }).first()).toBeVisible({
    timeout: 30_000,
  });
  await expect
    .poll(async () => (await judgePairs(page)).filter((p) => p.on).length, { timeout: 30_000 })
    .toBeGreaterThan(0);
  /*
   * 미리보기 행 → 작성 행으로 갈아타는 사이에 읽으면 사라질 행을 잡는다.
   * 두 번 읽어 같을 때까지 기다린다 — 그래야 「다 그려졌다」다.
   */
  let prev = "";
  await expect
    .poll(async () => {
      const now = (await judgePairs(page)).map((p) => p.name).join("|");
      const same = now !== "" && now === prev;
      prev = now;
      return same;
    }, { timeout: 30_000, intervals: [300] })
    .toBe(true);

  const pairs = await judgePairs(page);
  expect(pairs.length, `${where} — 판정 라디오를 못 찾는다`).toBeGreaterThan(0);
  return pairs;
}

async function openDraft(page: Page, path: string, tmpl: string): Promise<void> {
  const { user, pass } = adminCreds();
  await login(page, user, pass);
  await createDraft(page, path, tmpl);
}

test.describe("작성 5화면 — 판정 기본값", () => {
  for (const s of SEEDED) {
    test(`${s.name} — 새 문서는 판정이 전부 적합으로 깔린다`, async ({ page }) => {
      await openDraft(page, s.path, s.tmpl);
      const pairs = await settledPairs(page, s.name);

      const unset = pairs.filter((p) => !p.pass && !p.fail);
      expect(
        unset.length,
        `${s.name} — 판정이 안 깔린 행이 ${unset.length}개 있다 (전체 ${pairs.length})`,
      ).toBe(0);
      expect(pairs.every((p) => p.pass), `${s.name} — 적합이 아닌 행이 있다`).toBe(true);
    });
  }

  /*
   * 금속검출도 이제 다른 넷과 같다.
   *
   * 예전에는 여기만 판정을 안 깔았다 — 서버가 감도 5칸으로 계산해서(O,O,X,O,O 라야 적합)
   * 화면이 미리 칠하면 저장할 때 뒤집혔기 때문이다.
   * 그 자동 판정을 걷어냈다. 판정은 다섯 화면 모두 사람이 정한 값이 그대로 저장된다.
   */
  test(`${AUTO_JUDGED.name} — 새 문서는 판정이 전부 적합으로 깔린다`, async ({ page }) => {
    await openDraft(page, AUTO_JUDGED.path, AUTO_JUDGED.tmpl);
    const pairs = await settledPairs(page, AUTO_JUDGED.name);

    const unset = pairs.filter((p) => !p.pass && !p.fail);
    expect(
      unset.length,
      `판정이 안 깔린 행이 ${unset.length}개 있다 (전체 ${pairs.length})`,
    ).toBe(0);
    expect(pairs.every((p) => p.pass), "적합이 아닌 행이 있다").toBe(true);
  });
});

test.describe("작성 5화면 — 모두 적합", () => {
  for (const s of ALL) {
    test(`${s.name} — 부적합으로 바꿔도 「모두 적합」이 되돌린다`, async ({ page }) => {
      await openDraft(page, s.path, s.tmpl);
      const before = await settledPairs(page, s.name);

      /*
       * 첫 행을 부적합으로 바꾼다 — 같은 name 의 두 번째 라디오.
       * evaluate 안에서 el.click() 을 하면 React 가 안 받는 화면이 있다.
       * Playwright 로 진짜 클릭한다.
       */
      /*
       * **누를 수 있는 행**을 고른다. 지면이 읽기 전용일 때가 있다 —
       * 목록이 쌓이면 createDraft 가 새로 만든 행 대신 이미 전송된 옛 문서를
       * 열기도 한다. 그러면 라디오가 disabled 라 아무리 눌러도 안 바뀐다.
       */
      const editable = before.find((p) => p.on);
      expect(editable, `${s.name} — 고칠 수 있는 판정 행이 없다 (지면이 읽기 전용이다)`).toBeTruthy();
      const target = editable!.name;
      // check() 는 상태가 안 바뀌면 그 자리에서 실패한다 — 제어 컴포넌트는 한 박자 늦다.
      // 누르기만 하고 결과는 아래에서 기다린다
      /*
       * :visible — 셸이 mount 한 채 숨긴 앞 탭에도 같은 name 의 라디오가 있다.
       * 그리고 지면이 미리보기 행 → 작성 행으로 갈아타는 사이에 누르면 먹지 않는다.
       * 먹을 때까지 몇 번 다시 누른다 — 결과는 아래에서 못 박으므로 숨기는 게 아니다.
       */
      const fail = page.locator(`input[type=radio][name="${target}"]:visible`).nth(1);
      let flipped = false;
      for (let i = 0; i < 3 && !flipped; i += 1) {
        // force 를 쓰지 않는다 — 지면은 저장 직후 잠깐 읽기 전용이라
        // 그때 억지로 누르면 아무 일도 안 나고 시험만 헛돈다.
        // Playwright 가 「눌러도 되는 상태」가 될 때까지 기다리게 둔다
        await fail.click({ timeout: 30_000 });
        await page.waitForTimeout(700);
        flipped = (await judgePairs(page)).find((p) => p.name === target)?.fail === true;
      }
      expect(flipped, `${s.name} — 부적합으로 안 바뀐다`).toBe(true);

      await page.getByRole("button", { name: "모두 적합" }).first().click();

      await expect
        .poll(async () => (await judgePairs(page)).filter((p) => p.pass).length, { timeout: 15_000 })
        .toBe(before.length);
      expect(
        (await judgePairs(page)).some((p) => p.fail),
        `${s.name} — 「모두 적합」 뒤에도 부적합이 남는다`,
      ).toBe(false);
    });
  }
});
