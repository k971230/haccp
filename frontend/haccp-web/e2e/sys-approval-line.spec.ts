/**
 * sys-approval-line — 결재선관리.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 결재선은 문서 흐름의 상류다 — 여기가 틀리면 전송이 어느 단계에서 멈출지 정해진다
 *   2) 헤더(결재선)와 단계(1~3)가 별개 그리드다. 헤더를 고르면 단계가 열린다
 *   3) 단계는 SP 가 1~2 를 고정으로 깔아 준다 — 사람이 순번을 만들지 않는다
 *
 * PIPELINE[HF130] E2E
 */
import { expect, test } from "@playwright/test";
import {
  addRow,
  adminCreds,
  dbOne,
  fillCell,
  grids,
  login,
  loginCoCd,
  openScreen,
  saveAndConfirm,
  sqlLit,
} from "./helpers";

const PATH = "/sys/code/approval-line-management";
const LINE = "E2ELINE";

const purge = () => {
  dbOne(`DELETE FROM tbl_approval_line_step WHERE appr_line_cd='${LINE}'`);
  dbOne(`DELETE FROM tbl_approval_line WHERE appr_line_cd='${LINE}'`);
};

test.describe.serial("결재선관리", () => {
  test.beforeAll(purge);
  test.afterAll(purge);

  test("결재선 등록 → DB 반영 → 단계가 깔린다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openScreen(page, PATH);
    await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });

    const head = grids(page).first();
    const at = await addRow(page, head);
    await fillCell(head, at, "결재선코드", LINE);
    await fillCell(head, at, "결재선명", "E2E 시험결재선");
    const auditBefore = Number(dbOne("SELECT count(*) FROM tbl_audit_log WHERE tbl_nm='tbl_approval_line' AND scrn_cd='approval-line-management'"));
    expect(await saveAndConfirm(page, "/approval-line-management/save")).toBe(200);

    // 결재선은 누가 결재하는지를 정한다 — 조용히 바뀌면 안 된다 (E2E-003)
    expect(
      Number(dbOne("SELECT count(*) FROM tbl_audit_log WHERE tbl_nm='tbl_approval_line' AND scrn_cd='approval-line-management'")),
      "결재선 변경이 감사로그에 안 남는다",
    ).toBeGreaterThan(auditBefore);

    expect(dbOne(`SELECT appr_line_nm FROM tbl_approval_line WHERE appr_line_cd='${LINE}'`)).toBe(
      "E2E 시험결재선",
    );
    // 단계는 사람이 만들지 않는다 — 등록과 함께 작성·승인 2행이 깔려야 한다
    expect(
      dbOne(`SELECT count(*) FROM tbl_approval_line_step WHERE appr_line_cd='${LINE}'`),
      "결재선을 만들었는데 단계가 안 깔렸다",
    ).toBe("2");
  });

  test("기본 결재선에 검토 단계가 없다", () => {
    const rows = dbOne(
      `SELECT count(*) FROM tbl_approval_line_step
        WHERE co_cd='${sqlLit(loginCoCd())}' AND appr_line_cd='DEFAULT' AND role_cd='REVIEW'`,
    );
    expect(rows, "기본 결재선에 검토 단계가 남아 있다").toBe("0");
  });
});
