/**
 * company-provisioning — 신규 업체 개설과 회사 격리.
 *
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 06_company_seed.sql 을 실제로 돌려 「로그인해서 문서를 쓸 수 있는 상태」까지 되는지 본다
 *   2) 메뉴·화면권한·양식이 표준 업체(0000)와 같은 수로 깔려야 한다 — 하나라도 빠지면 화면이 안 열린다
 *   3) 만든 업체 계정으로 0000 자료가 보이면 안 된다. 그게 보이면 남의 회사 기록이 새는 것이다
 *
 * PIPELINE[HF130] E2E
 */
import { expect, test } from "@playwright/test";
import { dbOne, login, openScreen, purgeCompany, seedCompany } from "./helpers";

/** 시험 전용 업체코드 — 0000·0001 과 겹치지 않게 둔다 */
const CO = "9099";
const ADMIN = `admin${CO}`;
const API = process.env.E2E_API_BASE_URL || "http://localhost:7070";

test.describe.serial("신규 업체 개설", () => {
  test.beforeAll(() => purgeCompany(CO));
  test.afterAll(() => purgeCompany(CO));

  test("시드를 돌리면 표준 업체와 같은 수의 메뉴·화면권한이 깔린다", async () => {
    seedCompany({ coCd: CO, coNm: "E2E 신규업체", adminId: ADMIN });

    // 손으로 적은 기대치를 두지 않는다 — 표준 업체(0000)와 같은지만 본다.
    // 화면이 하나 늘면 두 곳이 같이 늘어야 하고, 한쪽만 늘면 여기서 걸린다
    for (const tbl of ["tbl_menu", "tbl_role_screen"]) {
      const std = dbOne(`SELECT count(*) FROM ${tbl} WHERE co_cd='0000'`);
      const made = dbOne(`SELECT count(*) FROM ${tbl} WHERE co_cd='${CO}'`);
      expect(made, `${tbl} 이 표준 업체와 다르다 (표준 ${std} / 신규 ${made})`).toBe(std);
      expect(Number(made), `${tbl} 이 비었다`).toBeGreaterThan(0);
    }
  });

  test("관리자·부서·결재선·양식이 함께 깔린다", async () => {
    expect(dbOne(`SELECT count(*) FROM tbl_company WHERE co_cd='${CO}'`), "업체가 없다").toBe("1");
    expect(
      dbOne(`SELECT count(*) FROM tbl_user WHERE co_cd='${CO}' AND user_id='${ADMIN}'`),
      "관리자 계정이 없다 — 로그인할 사람이 없다",
    ).toBe("1");
    expect(
      Number(dbOne(`SELECT count(*) FROM tbl_dept WHERE co_cd='${CO}'`)),
      "부서가 없다",
    ).toBeGreaterThan(0);
    expect(
      Number(dbOne(`SELECT count(*) FROM tbl_approval_line_step WHERE co_cd='${CO}'`)),
      "결재선 단계가 없다 — 전송한 문서가 갈 곳이 없다",
    ).toBeGreaterThan(0);
    expect(
      Number(dbOne(`SELECT count(*) FROM tbl_company_template WHERE co_cd='${CO}'`)),
      "사용양식이 없다 — 쓸 양식이 하나도 없다",
    ).toBeGreaterThan(0);
    expect(
      Number(dbOne(`SELECT count(*) FROM tbl_doc_no_rule WHERE co_cd='${CO}'`)),
      "문서번호 규칙이 없다 — 문서를 만들면 번호가 안 붙는다",
    ).toBeGreaterThan(0);

    // 비밀번호는 평문이면 안 된다
    const pw = dbOne(`SELECT user_pw FROM tbl_user WHERE co_cd='${CO}' AND user_id='${ADMIN}'`);
    expect(pw, "초기 비밀번호가 해시가 아니다").toMatch(/^\$2[aby]\$/);
  });

  test("다시 돌려도 안전하다 — 값이 두 배가 되지 않는다", async () => {
    const before = dbOne(`SELECT count(*) FROM tbl_menu WHERE co_cd='${CO}'`);
    seedCompany({ coCd: CO, coNm: "E2E 신규업체", adminId: ADMIN });
    expect(
      dbOne(`SELECT count(*) FROM tbl_menu WHERE co_cd='${CO}'`),
      "재실행에 메뉴가 늘었다 — 시드가 재실행 안전하지 않다",
    ).toBe(before);
  });

  test("만든 계정으로 로그인해 화면이 열린다", async ({ page }) => {
    await login(page, ADMIN, "1234");
    await openScreen(page, "/board/today-tasks");
    await expect(
      page.getByText("오늘 작성 과제").filter({ visible: true }).first(),
      "새 업체 계정으로 랜딩 화면이 안 열린다",
    ).toBeVisible({ timeout: 30_000 });

    // 사용양식관리도 열려야 한다 — 양식이 안 깔렸으면 여기서 빈 목록이 뜬다
    await openScreen(page, "/docs/hwp/hwp-template-management");
    await expect(page.getByRole("button", { name: "조회" })).toBeVisible({ timeout: 30_000 });
  });

  test("새 업체 계정에는 0000 자료가 보이지 않는다", async ({ request }) => {
    const res0 = await request.post(`${API}/api/v1/auth/login`, {
      data: { userId: ADMIN, password: "1234" },
    });
    expect(res0.status(), "새 업체 관리자로 로그인이 안 된다").toBe(200);
    const body = await res0.json();
    const token = (body?.data?.token ?? "") as string;
    expect(body?.data?.user?.coCd, "JWT 회사코드가 새 업체가 아니다").toBe(CO);

    // 0000 이 만든 문서가 하나라도 새 업체 목록에 섞이면 안 된다
    const docs = await request.get(`${API}/api/v1/docs/documents/list`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(docs.status()).toBe(200);
    const rows = ((await docs.json())?.data ?? []) as { coCd?: string }[];
    const leaked = rows.filter((r) => r.coCd && r.coCd !== CO);
    expect(leaked.length, `남의 회사 문서가 ${leaked.length}건 보인다`).toBe(0);

    // 새 업체는 아직 문서를 쓴 적이 없다
    expect(
      dbOne(`SELECT count(*) FROM tbl_document WHERE co_cd='${CO}'`),
      "새 업체에 문서가 이미 있다",
    ).toBe("0");
  });

  test("본문에 0000 을 실어도 새 업체 자료만 만진다", async ({ request }) => {
    const res0 = await request.post(`${API}/api/v1/auth/login`, {
      data: { userId: ADMIN, password: "1234" },
    });
    const token = ((await res0.json())?.data?.token ?? "") as string;

    // 회사코드는 JWT 에서만 읽어야 한다 — 본문 값을 믿으면 남의 회사에 부서가 생긴다
    const save = await request.put(`${API}/api/v1/sys/code/department-management/save`, {
      headers: { Authorization: `Bearer ${token}` },
      data: [{ coCd: "0000", deptCd: "E2ECO", deptNm: "회사코드 위조 시도", useYn: "Y" }],
    });
    expect(save.status(), "저장이 실패했다 — 위조 검사 이전 문제다").toBe(200);

    expect(
      dbOne("SELECT count(*) FROM tbl_dept WHERE co_cd='0000' AND dept_cd='E2ECO'"),
      "본문 회사코드를 믿고 0000 에 부서를 만들었다",
    ).toBe("0");
    expect(
      dbOne(`SELECT count(*) FROM tbl_dept WHERE co_cd='${CO}' AND dept_cd='E2ECO'`),
      "JWT 회사에 부서가 안 생겼다",
    ).toBe("1");
  });
});
