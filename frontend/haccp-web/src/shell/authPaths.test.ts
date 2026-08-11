/**
 * authPaths.test — Vite base 정합 경로 헬퍼 단위 검증 (G-22).
 *
 * 개발자: 박승우
 * 일자: 2026-08-11
 * 코멘트:
 *   1) Path 배포(/haccp/)와 로컬(/)에서 로그인·복귀 경로가 깨지지 않는지 고정한다
 *   2) CI·로컬 npm test 로 실행한다
 *   3) 실패하면 handleUnauthorized 가 잘못된 URL 로 replace 할 위험이 있다
 */
import { describe, expect, it } from "vitest";
import {
  isLoginBrowserPath,
  loginBrowserPath,
  normalizeAppBaseUrl,
  toRouterPath,
} from "@/shell/authPaths";

describe("authPaths — base /", () => {
  it("normalize·login", () => {
    expect(normalizeAppBaseUrl("/")).toBe("/");
    expect(loginBrowserPath("/")).toBe("/login");
    expect(isLoginBrowserPath("/login", "/")).toBe(true);
    expect(isLoginBrowserPath("/", "/")).toBe(false);
  });

  it("toRouterPath 는 base 없을 때 그대로", () => {
    expect(toRouterPath("/ccp-cold-monitor?x=1", "/")).toBe("/ccp-cold-monitor?x=1");
  });
});

describe("authPaths — base /haccp/", () => {
  const base = "/haccp/";

  it("login browser path", () => {
    expect(normalizeAppBaseUrl("/haccp")).toBe("/haccp/");
    expect(loginBrowserPath(base)).toBe("/haccp/login");
    expect(isLoginBrowserPath("/haccp/login", base)).toBe(true);
    expect(isLoginBrowserPath("/login", base)).toBe(false);
    expect(isLoginBrowserPath("/haccp/", base)).toBe(false);
  });

  it("toRouterPath 가 basename 을 벗긴다", () => {
    expect(toRouterPath("/haccp/ccp-cold-monitor", base)).toBe("/ccp-cold-monitor");
    expect(toRouterPath("/haccp/today-tasks?a=1", base)).toBe("/today-tasks?a=1");
    expect(toRouterPath("/haccp", base)).toBe("/");
    expect(toRouterPath("/haccp/", base)).toBe("/");
  });
});
