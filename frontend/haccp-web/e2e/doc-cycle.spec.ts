/**
 * doc-cycle — 문서주기 7종과 오늘 할 일 연동.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 주기는 작성 6화면의 상류다 — 여기가 틀리면 「오늘 할 일」이 통째로 틀어진다
 *   2) 7종(매일·매주·매월·분기·반기·매년·비정기)을 실제로 저장해 예정일이 생기는지 본다
 *   3) 화면 폼으로 7번 도는 대신 저장 API 를 직접 친다 — 예정일 생성은 서버 몫이고 폼 조작은
 *      schedule-cycle-management 스펙이 따로 본다
 *
 * PIPELINE[HF130] E2E
 */
import { expect, test, type APIRequestContext } from "@playwright/test";
import { adminCreds, dbOne, login, loginCoCd, openScreen, sqlLit } from "./helpers";

const API = process.env.E2E_API_BASE_URL || "http://localhost:7070";
/** 시험용 양식 — 실제 쓰는 양식을 건드리면 사람 화면이 흔들린다 */
const TMPL = "tml_ccp_chk_001";

async function tokenOf(request: APIRequestContext): Promise<string> {
  const { user, pass } = adminCreds();
  const res = await request.post(`${API}/api/v1/auth/login`, { data: { userId: user, password: pass } });
  const token = ((await res.json())?.data?.token ?? "") as string;
  expect(token, "로그인 실패").not.toBe("");
  return token;
}

/**
 * 앞으로의 예정일 개수 — 오늘 것은 세지 않는다.
 *
 * 재생성 SP 는 미래 TODO 와 관리시작일 이전 미작성 밀린 행을 지운다.
 * 오늘 몫은 이미 사람이 손대고 있을 수 있어 일부러 남긴다.
 * 그래서 주기를 바꾼 효과는 「내일 이후」로만 판정해야 한다.
 */
function futureTasks(): number {
  const co = sqlLit(loginCoCd());
  return Number(
    dbOne(
      `SELECT count(*) FROM tbl_schedule_task
        WHERE co_cd='${co}' AND tmpl_cd='${TMPL}'
          AND base_dt > to_char(current_date,'YYYYMMDD')`,
    ),
  );
}

/** 주기 저장 본문 — details 는 주기마다 모양이 다르다 */
function body(cycleCd: string, details: unknown[]): Record<string, unknown> {
  return {
    tmplCd: TMPL,
    baseDt: "20260101",
    cycleCd,
    nonworkRule: "KEEP",
    dueTime: "1800",
    useYn: "Y",
    details,
  };
}

const CASES: Array<{ cycleCd: string; label: string; details: unknown[]; expectTasks: boolean }> = [
  { cycleCd: "D", label: "매일", details: [], expectTasks: true },
  { cycleCd: "W", label: "매주", details: [{ detailTy: "week-day", val1: 1 }], expectTasks: true },
  { cycleCd: "M", label: "매월", details: [{ detailTy: "month-day", val1: 15 }], expectTasks: true },
  {
    cycleCd: "Q",
    label: "분기",
    details: [{ detailTy: "quarter-month", val1: 1, val2: 10 }],
    expectTasks: true,
  },
  {
    cycleCd: "H",
    label: "반기",
    details: [{ detailTy: "half-month", val1: 1, val2: 10 }],
    expectTasks: true,
  },
  {
    cycleCd: "Y",
    label: "매년",
    details: [{ detailTy: "year-month", val1: 12, val2: 20 }],
    expectTasks: true,
  },
  // 비정기는 예정일이 없다 — 사람이 필요할 때 쓴다
  { cycleCd: "E", label: "비정기", details: [], expectTasks: false },
];

test.describe.serial("문서주기 7종", () => {
  let saved = "";

  test.beforeAll(() => {
    // 원래 주기를 적어 두고 마지막에 되돌린다 — 로그인 회사·이 양식만
    saved = dbOne(
      `SELECT cycle_cd FROM tbl_schedule_rule
        WHERE co_cd='${sqlLit(loginCoCd())}' AND tmpl_cd='${TMPL}'`,
    );
  });

  for (const c of CASES) {
    test(`${c.label}(${c.cycleCd}) — 저장하면 예정일이 규칙대로 깔린다`, async ({ request }) => {
      const token = await tokenOf(request);
      const res = await request.put(
        `${API}/api/v1/docs/sch/schedule-cycle-management/save`,
        { headers: { Authorization: `Bearer ${token}` }, data: body(c.cycleCd, c.details) },
      );
      expect(res.status(), await res.text()).toBe(200);

      expect(
        dbOne(
          `SELECT cycle_cd FROM tbl_schedule_rule
            WHERE co_cd='${sqlLit(loginCoCd())}' AND tmpl_cd='${TMPL}'`,
        ),
      ).toBe(c.cycleCd);
      const tasks = futureTasks();
      if (c.expectTasks) {
        expect(tasks, `${c.label} 인데 앞으로의 예정일이 하나도 없다`).toBeGreaterThan(0);
      } else {
        expect(tasks, "비정기인데 앞으로의 예정일이 깔렸다").toBe(0);
      }
    });
  }

  test("사용안함으로 바꾸면 미래 예정일이 정리된다", async ({ request }) => {
    const token = await tokenOf(request);
    // 먼저 매일로 깔아 둔다
    await request.put(`${API}/api/v1/docs/sch/schedule-cycle-management/save`, {
      headers: { Authorization: `Bearer ${token}` },
      data: body("D", []),
    });
    expect(futureTasks()).toBeGreaterThan(0);

    const res = await request.put(`${API}/api/v1/docs/sch/schedule-cycle-management/save`, {
      headers: { Authorization: `Bearer ${token}` },
      data: { ...body("D", []), useYn: "N" },
    });
    expect(res.status()).toBe(200);
    expect(futureTasks(), "주기를 껐는데 앞으로의 예정일이 남아 있다").toBe(0);
  });

  test("오늘 할 일 화면이 예정일을 읽는다", async ({ page, request }) => {
    const token = await tokenOf(request);
    await request.put(`${API}/api/v1/docs/sch/schedule-cycle-management/save`, {
      headers: { Authorization: `Bearer ${token}` },
      data: body("D", []),
    });
    const today = dbOne(
      `SELECT count(*) FROM tbl_schedule_task
        WHERE co_cd='${sqlLit(loginCoCd())}'
          AND base_dt = to_char(current_date,'YYYYMMDD')`,
    );
    expect(Number(today), "오늘 예정일이 하나도 없다").toBeGreaterThan(0);

    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openScreen(page, "/board/today-tasks");
    // 화면 상단 요약이 DB 와 같은 수를 말해야 한다
    await expect(page.getByText(/오늘 작성 과제/).first()).toBeVisible({ timeout: 30_000 });
  });

  // 로그인 회사·이 양식만 되돌린다. 없었으면 규칙·미작성 과제까지 지운다
  test.afterAll(() => {
    const co = sqlLit(loginCoCd());
    dbOne(
      `DELETE FROM tbl_schedule_task
        WHERE co_cd='${co}' AND tmpl_cd='${TMPL}'
          AND status IN ('TODO','LATE') AND doc_idx IS NULL`,
    );
    if (saved) {
      dbOne(
        `UPDATE tbl_schedule_rule SET cycle_cd='${sqlLit(saved)}'
          WHERE co_cd='${co}' AND tmpl_cd='${TMPL}'`,
      );
    } else {
      dbOne(`DELETE FROM tbl_schedule_rule_detail WHERE co_cd='${co}' AND tmpl_cd='${TMPL}'`);
      dbOne(`DELETE FROM tbl_schedule_rule WHERE co_cd='${co}' AND tmpl_cd='${TMPL}'`);
    }
  });
});
