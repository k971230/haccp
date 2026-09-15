/**
 * flow-health-cert — 보건증관리 화면.
 *
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) 가림 없이 저장하면 행이 생기면 안 된다. 화면 토스트만 보고 통과시키지 않는다
 *   2) 올린 PDF 는 디스크에서 %PDF 로 시작하면 안 된다 — 봉투가 씌워졌는지 DB 가 아니라 실물로 본다
 *   3) afterAll 은 삭제 API 로 이력과 HrDocs 파일을 같이 지운다. DB 만 지우면 UUID.pdf 가 남는다
 *
 * PIPELINE[HF130] E2E
 */
import fs from "node:fs";
import path from "node:path";
import { expect, request, test, type APIRequestContext, type Page } from "@playwright/test";
import {
  adminCreds,
  btn,
  dbOne,
  dbRows,
  grids,
  hasDbTools,
  login,
  loginCoCd,
  loginUserId,
  openScreen,
  saveAndConfirm,
  sqlLit,
} from "./helpers";

const PATH = "/flow/box/health-cert-management";
const API = process.env.E2E_API_BASE_URL || "http://localhost:7070";
const FILE_NM = "e2e-health-cert.pdf";
const OTHER_NM = "e2e-health-cert-other.pdf";
const MIN_PDF = Buffer.from("%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n");

let prevYn = "";
let seededEmp = false;
let seededMgr = false;

/** 백엔드 작업 디렉터리 기준 APP_FILE_ROOT. 상대 경로면 haccp-api 아래로 푼다 */
function fileRoot(): string {
  const envPath = path.resolve(process.cwd(), "../../backend/haccp-api/.env");
  let raw = "./data/haccp-files";
  try {
    const m = fs.readFileSync(envPath, "utf-8").match(/^APP_FILE_ROOT=(.*)$/m);
    if (m) raw = m[1].trim();
  } catch {
    /* 기본값 */
  }
  if (path.isAbsolute(raw)) return raw;
  return path.resolve(process.cwd(), "../../backend/haccp-api", raw);
}

function seedActor(): void {
  const co = sqlLit(loginCoCd());
  const uid = sqlLit(loginUserId());
  prevYn = dbOne(
    `SELECT health_cert_manage_yn FROM tbl_emp_detail WHERE co_cd='${co}' AND user_id='${uid}'`,
  );
  if (!prevYn) {
    dbOne(
      `INSERT INTO tbl_emp_detail (co_cd, user_id, health_cert_manage_yn, ins_id, ins_dt)
       VALUES ('${co}', '${uid}', 'Y', 'e2e', now())`,
    );
    seededEmp = true;
  } else if (prevYn !== "Y") {
    dbOne(
      `UPDATE tbl_emp_detail SET health_cert_manage_yn='Y', upd_id='e2e', upd_dt=now()
        WHERE co_cd='${co}' AND user_id='${uid}'`,
    );
  }
  const mgr = dbOne(
    `SELECT 1 FROM tbl_health_cert_mgr WHERE co_cd='${co}' AND user_id='${uid}'`,
  );
  if (!mgr) {
    dbOne(
      `INSERT INTO tbl_health_cert_mgr (co_cd, user_id, ins_id, ins_dt)
       VALUES ('${co}', '${uid}', 'e2e', now())`,
    );
    seededMgr = true;
  }
}

function restoreActor(): void {
  const co = sqlLit(loginCoCd());
  const uid = sqlLit(loginUserId());
  if (seededEmp) {
    dbOne(`DELETE FROM tbl_emp_detail WHERE co_cd='${co}' AND user_id='${uid}'`);
  } else if (prevYn && prevYn !== "Y") {
    dbOne(
      `UPDATE tbl_emp_detail SET health_cert_manage_yn='${sqlLit(prevYn)}', upd_id='e2e', upd_dt=now()
        WHERE co_cd='${co}' AND user_id='${uid}'`,
    );
  }
  if (seededMgr) {
    dbOne(`DELETE FROM tbl_health_cert_mgr WHERE co_cd='${co}' AND user_id='${uid}' AND ins_id='e2e'`);
  }
}

function histIdxs(fileNm: string): number[] {
  const rows = dbRows(
    `SELECT idx FROM tbl_health_cert_hist
      WHERE co_cd='${sqlLit(loginCoCd())}' AND file_nm='${sqlLit(fileNm)}'`,
  );
  return rows.slice(1).map((r) => Number(r[0])).filter((n) => n > 0);
}

function histCell(fileNm: string, col: string): string {
  const rows = dbRows(
    `SELECT idx, file_path, wrapped_dek, key_version
       FROM tbl_health_cert_hist
      WHERE co_cd='${sqlLit(loginCoCd())}' AND file_nm='${sqlLit(fileNm)}'
      ORDER BY idx DESC LIMIT 1`,
  );
  if (rows.length < 2) return "";
  const i = rows[0].indexOf(col);
  return i >= 0 ? rows[1][i] ?? "" : "";
}

/**
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) 삭제는 validate-delete → delete. 디스크는 커밋 뒤에 지워진다
 *   2) 담당자가 아니면 400 이라 beforeAll 에서 mgr 행을 심는다
 *   3) 타 회사 심은 행은 API 가 못 지우므로 SQL 로만 걷어낸다
 */
async function purgeUploaded(api: APIRequestContext): Promise<void> {
  if (!hasDbTools()) return;
  const pathRows = dbRows(
    `SELECT file_path FROM tbl_health_cert_hist
      WHERE (co_cd='${sqlLit(loginCoCd())}' AND file_nm='${sqlLit(FILE_NM)}')
         OR file_nm='${sqlLit(OTHER_NM)}'`,
  );
  const diskPaths = pathRows.slice(1).map((r) => r[0]).filter(Boolean);
  try {
    const { user, pass } = adminCreds();
    const loginRes = await api.post(`${API}/api/v1/auth/login`, {
      data: { userId: user, password: pass },
    });
    const token = ((await loginRes.json())?.data?.token ?? "") as string;
    const idxs = histIdxs(FILE_NM);
    if (token && idxs.length) {
      const keys = idxs.map((idx) => ({ idx }));
      await api.post(`${API}/api/v1/flow/box/health-cert-management/hist/validate-delete`, {
        headers: { Authorization: `Bearer ${token}` },
        data: keys,
      });
      await api.post(`${API}/api/v1/flow/box/health-cert-management/hist/delete`, {
        headers: { Authorization: `Bearer ${token}` },
        data: keys,
      });
    }
  } catch {
    /* API 가 죽어도 아래 unlink·SQL 로 걷는다 */
  }
  const root = fileRoot();
  for (const rel of diskPaths) {
    try {
      fs.unlinkSync(path.join(root, rel));
    } catch {
      /* 이미 없음 */
    }
  }
  dbOne(`DELETE FROM tbl_health_cert_hist WHERE file_nm='${sqlLit(OTHER_NM)}'`);
  dbOne(
    `DELETE FROM tbl_health_cert_hist
      WHERE co_cd='${sqlLit(loginCoCd())}' AND file_nm='${sqlLit(FILE_NM)}'`,
  );
}

async function openHealthCert(page: Page): Promise<void> {
  await openScreen(page, PATH);
  await expect(page.getByText("식품위생법 제40조")).toBeVisible({ timeout: 30_000 });
}

async function selectSelf(page: Page): Promise<void> {
  const uid = loginUserId();
  const nm = dbOne(`SELECT user_nm FROM tbl_user WHERE user_id='${sqlLit(uid)}'`);
  const row = grids(page).first().locator("tbody tr").filter({ hasText: nm || uid }).first();
  await expect(row, "로그인 사용자가 대상 사원 목록에 없다").toBeVisible({ timeout: 20_000 });
  await row.click();
  await expect(page.getByText("주민번호 뒷자리를 가린 뒤 올렸습니다")).toBeVisible({ timeout: 10_000 });
}

function ymdDash(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

test.describe("보건증관리", () => {
  test.beforeAll(() => {
    if (!hasDbTools()) return;
    seedActor();
  });

  test.afterAll(async () => {
    const api = await request.newContext();
    try {
      await purgeUploaded(api);
    } finally {
      await api.dispose();
    }
    if (hasDbTools()) restoreActor();
  });

  test("화면이 열리고 가림 안내가 보인다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openHealthCert(page);
    await expect(page.getByText("뒷자리가 보이게 올리지 마세요")).toBeVisible();
  });

  test("가림 체크 없이 저장하면 이력이 안 생긴다", async ({ page }) => {
    const before = Number(
      dbOne(
        `SELECT count(*) FROM tbl_health_cert_hist
          WHERE co_cd='${sqlLit(loginCoCd())}' AND file_nm='${sqlLit(FILE_NM)}'`,
      ) || "0",
    );
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openHealthCert(page);
    await selectSelf(page);

    const today = new Date();
    const exp = new Date(today);
    exp.setFullYear(exp.getFullYear() + 1);
    await page.locator('input[type="date"]').nth(0).fill(ymdDash(today));
    await page.locator('input[type="date"]').nth(1).fill(ymdDash(exp));
    await page.locator('input[type="file"]').first().setInputFiles({
      name: FILE_NM,
      mimeType: "application/pdf",
      buffer: MIN_PDF,
    });
    await btn(page, "저장").click();
    await expect(page.getByText("주민번호 뒷자리를 가린 사본만")).toBeVisible({ timeout: 10_000 });

    const after = Number(
      dbOne(
        `SELECT count(*) FROM tbl_health_cert_hist
          WHERE co_cd='${sqlLit(loginCoCd())}' AND file_nm='${sqlLit(FILE_NM)}'`,
      ) || "0",
    );
    expect(after, "가림 없이 저장했는데 이력이 생겼다").toBe(before);
  });

  test("가린 PDF 를 올리면 봉투가 씌워지고 경로에 원본명이 없다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);
    await openHealthCert(page);
    await selectSelf(page);

    const today = new Date();
    const exp = new Date(today);
    exp.setFullYear(exp.getFullYear() + 1);
    await page.locator('input[type="date"]').nth(0).fill(ymdDash(today));
    await page.locator('input[type="date"]').nth(1).fill(ymdDash(exp));
    await page.locator('input[type="file"]').first().setInputFiles({
      name: FILE_NM,
      mimeType: "application/pdf",
      buffer: MIN_PDF,
    });
    await page.getByRole("checkbox", { name: "주민번호 뒷자리를 가린 뒤 올렸습니다" }).check();
    expect(await saveAndConfirm(page, "/hist/upload")).toBe(200);

    await expect
      .poll(
        () =>
          dbOne(
            `SELECT count(*) FROM tbl_health_cert_hist
              WHERE co_cd='${sqlLit(loginCoCd())}' AND file_nm='${sqlLit(FILE_NM)}'`,
          ),
        { timeout: 20_000 },
      )
      .toBe("1");

    const filePath = histCell(FILE_NM, "file_path");
    const dek = histCell(FILE_NM, "wrapped_dek");
    const ver = histCell(FILE_NM, "key_version");
    expect(dek, "wrapped_dek 가 비었다").not.toBe("");
    expect(Number(ver), "key_version 이 1 미만이다").toBeGreaterThanOrEqual(1);
    expect(filePath, "file_path 가 비었다").not.toBe("");
    expect(filePath.includes(FILE_NM), "디스크 경로에 원본 파일명이 실렸다").toBe(false);
    expect(/[0-9a-f-]{36}\.pdf$/i.test(filePath.split(/[/\\]/).pop() ?? ""), "파일명이 UUID.pdf 가 아니다").toBe(true);

    const abs = path.join(fileRoot(), filePath);
    expect(fs.existsSync(abs), `실물이 없다: ${abs}`).toBe(true);
    const head = fs.readFileSync(abs).subarray(0, 4).toString("utf8");
    expect(head, "디스크가 평문 PDF 다 — 봉투가 안 씌워졌다").not.toBe("%PDF");
  });

  test("이력 목록 JSON 에 filePath·wrappedDek 이 없다", async ({ request: api }) => {
    const { user, pass } = adminCreds();
    const loginRes = await api.post(`${API}/api/v1/auth/login`, {
      data: { userId: user, password: pass },
    });
    const token = ((await loginRes.json())?.data?.token ?? "") as string;
    const res = await api.get(`${API}/api/v1/flow/box/health-cert-management/hist/list`, {
      headers: { Authorization: `Bearer ${token}` },
      params: { userId: loginUserId() },
    });
    expect(res.status()).toBe(200);
    const body = JSON.stringify(await res.json());
    expect(body.includes("filePath") || body.includes("file_path"), "목록에 파일 경로가 실렸다").toBe(false);
    expect(body.includes("wrappedDek") || body.includes("wrapped_dek"), "목록에 DEK 가 실렸다").toBe(false);
  });

  test("타 회사 이력은 목록에 안 나온다", async ({ request: api }) => {
    const otherCo = dbOne(
      `SELECT co_cd FROM tbl_company WHERE co_cd <> '${sqlLit(loginCoCd())}' ORDER BY co_cd LIMIT 1`,
    );
    test.skip(!otherCo, "타 회사가 없어 테넌트 격리 시험을 건너뛴다");
    const otherUser = dbOne(
      `SELECT user_id FROM tbl_user WHERE co_cd='${sqlLit(otherCo)}' ORDER BY user_id LIMIT 1`,
    );
    test.skip(!otherUser, "타 회사 사용자가 없다");
    dbOne(
      `INSERT INTO tbl_health_cert_hist
         (co_cd, user_id, reg_dt, expire_dt, file_nm, file_path, file_ext, file_size, ins_id, ins_dt)
       VALUES ('${sqlLit(otherCo)}', '${sqlLit(otherUser)}', '20260101', '20270101',
               '${sqlLit(OTHER_NM)}', 'HrDocs/e2e-other/no-file.pdf', 'pdf', 1, 'e2e', now())`,
    );
    const planted = dbOne(
      `SELECT idx FROM tbl_health_cert_hist WHERE file_nm='${sqlLit(OTHER_NM)}' ORDER BY idx DESC LIMIT 1`,
    );

    const { user, pass } = adminCreds();
    const loginRes = await api.post(`${API}/api/v1/auth/login`, {
      data: { userId: user, password: pass },
    });
    const token = ((await loginRes.json())?.data?.token ?? "") as string;
    const res = await api.get(`${API}/api/v1/flow/box/health-cert-management/hist/list`, {
      headers: { Authorization: `Bearer ${token}` },
      params: { userId: loginUserId() },
    });
    expect(res.status()).toBe(200);
    const json = await res.json() as { data?: { idx?: number; fileNm?: string }[] };
    const rows = json.data ?? [];
    expect(rows.some((r) => Number(r.idx) === Number(planted)), "타 회사 이력이 목록에 실렸다").toBe(false);
    expect(rows.some((r) => r.fileNm === OTHER_NM), "타 회사 파일명이 목록에 실렸다").toBe(false);
  });
});
