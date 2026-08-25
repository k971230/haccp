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
import { expect, type Page } from "@playwright/test";

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
 */
export async function login(page: Page, user: string, pass: string): Promise<void> {
  await page.goto("login", { waitUntil: "domcontentloaded" });
  await expect(page.locator("#login-user-id")).toBeVisible({ timeout: 30_000 });
  await page.locator("#login-user-id").fill(user);
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
