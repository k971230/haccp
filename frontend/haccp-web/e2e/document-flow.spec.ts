/**
 * document-flow — 작성부터 결재·보관까지 한 바퀴.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 2026-08-25 정리에서 실제로 났던 두 회귀를 고정한다
 *      (가) 저장한 지면 값이 전송 뒤 사라지던 것 — writeEdit 와 writeView 를 묶어 둔 탓
 *      (나) 결재 미리보기가 빈 예시 지면으로 뜨던 것 — 같은 원인
 *   2) 화면 하나가 아니라 흐름을 본다 — 층이 갈라져 있어 단위 테스트로는 안 잡힌다
 *   3) 순서가 곧 업무다. 앞 단계가 실패하면 뒤는 볼 필요가 없어 한 test 로 묶었다
 *
 * PIPELINE[HF130] E2E
 */
import { expect, test } from "@playwright/test";
import {
  adminCreds,
  btn,
  dbOne,
  login,
  openScreen,
  resetDocuments,
  rowOfDoc,
  visibleRows,
} from "./helpers";


test.describe("문서 흐름 — 작성 → 전송 → 승인 → 보관", () => {
  // 흐름은 문서 한 건을 끝까지 쫓는다 — 앞선 시험이 남긴 문서가 있으면 행을 못 가린다
  test.beforeAll(() => resetDocuments());

  test("CCP 가열일지 한 바퀴", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);

    // --- 1. 작성 ---------------------------------------------------------
    await openScreen(page, "/draft/ccp-monitoring/ccp-htg");
    await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });

    /*
     * 목록에는 문서번호 열이 없고 신규 행은 맨 끝에 붙는다.
     * 시험을 돌릴수록 문서가 쌓이므로 「추가 전 건수」로 내 행 자리를 잡는다.
     */
    const rowsOf = () => visibleRows(page).filter({ hasText: "tml_ccp_htg_" });
    const before = await rowsOf().count();
    await page.getByRole("button", { name: "행추가" }).click();
    // 양식 선택 팝업 — 양식코드 셀 버튼이 연다.
    // 셀 버튼은 행 위에 떠 있어 가려질 수 있다. 셀을 먼저 활성화하고 강제 클릭한다
    const pickBtn = page.getByTitle("양식 선택").first();
    await pickBtn.scrollIntoViewIfNeeded();
    await pickBtn.click({ force: true });
    // 팝업 목록에서 양식을 고른다 — 그리드 행은 더블클릭으로 확정된다
    const pick = visibleRows(page).filter({ hasText: "tml_ccp_htg_" }).last();
    await expect(pick).toBeVisible({ timeout: 20_000 });
    await pick.dblclick();
    // 고르면 좌측 양식코드 칸이 「미선택」에서 실제 코드로 바뀐다
    await expect(
      visibleRows(page).filter({ hasText: "tml_ccp_htg_" }).first(),
    ).toBeVisible({ timeout: 20_000 });

    /*
     * 좌측 저장 — 일자 + 양식코드로 문서를 만든다.
     * 저장이 끝나야 docIdx 가 생기고 우측 지면이 열린다 (그 전에는 readonly 다).
     * 좌측 툴바의 「저장」이다. 우측 「작성 후 저장」과 이름이 달라 exact 로 가른다.
     */
    await Promise.all([
      page.waitForResponse((r) => r.url().includes("/draft/") && r.url().includes("/save"), {
        timeout: 30_000,
      }),
      page.getByRole("button", { name: "저장", exact: true }).first().click(),
    ]);

    // --- 2. 지면 값 입력·저장 → 재조회해도 남아 있어야 한다 (회귀 고정) ------
    /*
     * 저장이 끝나면 좌측 행을 다시 눌러야 우측이 그 문서로 열린다.
     * 시험을 돌릴수록 목록에 문서가 쌓이므로 문서번호(가장 큰 일련)로 내 문서를 특정한다.
     */
    const myRow = rowsOf().nth(before);
    await myRow.click();
    const timeCell = page.locator('input[type="time"]:not([disabled])').first();
    await expect(timeCell).toBeVisible({ timeout: 30_000 });
    // 값이 이미 09:30 이면 dirty 가 안 생겨 저장이 안 눌린다 — 다른 값으로 한 번 밀었다가 되돌린다
    await timeCell.fill("08:00");
    await timeCell.fill("09:30");
    await Promise.all([
      page.waitForResponse((r) => r.url().includes("/draft/") && r.url().includes("/save"), {
        timeout: 30_000,
      }),
      page.getByRole("button", { name: "작성 후 저장" }).click(),
    ]);
    /*
     * 새로고침해도 저장값이 살아 있어야 한다 (회귀 고정).
     * 목록에 이전 시험 문서가 쌓이므로 방금 만든 문서번호로 행을 특정한다.
     */
    // 저장 응답이 와도 좌측 목록 재조회가 남아 있다 — 끝나기를 기다린 뒤 새로고침한다
    await expect(page.getByRole("button", { name: "전송", exact: true })).toBeEnabled({
      timeout: 30_000,
    });
    await page.reload();
    await expect(myRow).toBeVisible({ timeout: 30_000 });
    await myRow.click();
    await expect(page.locator('input[type="time"]').first()).toHaveValue("09:30", {
      timeout: 30_000,
    });

    // --- 3. 전송 필수값 — 판정을 비우면 막혀야 한다 (음성 검증) --------------
    await page.getByRole("button", { name: "전송", exact: true }).click();
    // 필수값 안내는 토스트라 버튼이 없다 — 떴다 사라지는 것만 확인한다
    await expect(page.getByText(/판정을 선택하세요/)).toBeVisible({ timeout: 20_000 });

    /*
     * 필수값을 채운다.
     * 기록 표는 「작업 전·작업 종료」 두 줄이라 라디오 그룹이 줄마다 따로 있다.
     * 그룹 하나만 찍으면 나머지 줄에서 다시 막힌다.
     */
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
    const emptyTimes = page.locator('input[type="time"]:not([disabled])');
    for (let i = 0; i < (await emptyTimes.count()); i += 1) {
      if (!(await emptyTimes.nth(i).inputValue())) await emptyTimes.nth(i).fill("09:30");
    }
    await Promise.all([
      page.waitForResponse((r) => r.url().includes("/draft/") && r.url().includes("/save")),
      page.getByRole("button", { name: "작성 후 저장" }).click(),
    ]);

    // --- 4. 전송 ---------------------------------------------------------
    await page.getByRole("button", { name: "전송", exact: true }).click();
    // 전송·승인·반려는 모두 문서 허브 한 곳(PUT /docs/documents/approval)으로 간다
    await Promise.all([
      page.waitForResponse(
        (r) => r.url().includes("/docs/documents/approval") && r.request().method() === "PUT",
        { timeout: 30_000 },
      ),
      page.getByRole("button", { name: "확인", exact: true }).click(),
    ]);

    // --- 4. 결재 첨부 — 내 문서로 보이고 상태가 승인요청이다 --------------
    await openScreen(page, "/flow/appr/attach");
    // 결재상태 열은 우측 미리보기에 밀려 가로로 잘린다 — 셀 가시성이 아니라 행 내용으로 본다
    await expect(
      visibleRows(page).filter({ hasText: "tml_ccp_htg_" }).first(),
    ).toContainText("승인요청", { timeout: 30_000 });

    // --- 5. 결재 대기 — 미리보기에 값이 보여야 한다 (회귀 고정) --------------
    await openScreen(page, "/flow/appr/sign-ready");
    // 목록 열 구성·열린 탭 수에 안 매이게 문서 idx 로 행을 집는다
    const docIdx = dbOne("SELECT idx FROM tbl_document ORDER BY idx DESC LIMIT 1");
    await rowOfDoc(page, docIdx).click();
    await expect(page.getByText("문서 미리보기")).toBeVisible({ timeout: 30_000 });
    // 빈 예시 지면이면 09:30 이 없다 — 저장값이 그려졌는지로 판정한다
    await expect(page.locator('input[type="time"][value="09:30"]').first()).toBeVisible({
      timeout: 30_000,
    });

    // --- 6. 승인 ---------------------------------------------------------
    await page.getByRole("button", { name: "승인" }).click();
    await Promise.all([
      page.waitForResponse(
        (r) => r.url().includes("/docs/documents/approval") && r.request().method() === "PUT",
        { timeout: 30_000 },
      ),
      page.getByRole("button", { name: "확인", exact: true }).click(),
    ]);

    // --- 7. 문서함 — 승인 완료만 보이고 조회 전용이다 ---------------------
    await openScreen(page, "/flow/box/document-inbox");
    // 셸이 닫은 탭을 DOM 에 남겨 둔다 — 보이는 것만 골라야 한다
    await expect(page.getByText("문서 목록").filter({ visible: true }).first())
      .toBeVisible({ timeout: 30_000 });
    await expect(btn(page, "신규")).toHaveCount(0);
    await expect(btn(page, "삭제")).toHaveCount(0);
  });
});
