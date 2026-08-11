/**
 * playwright.config — HACCP FE 최소 E2E (G-21 / STEP 28).
 * JS 설정 — TS 로더 이슈 회피.
 */
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { defineConfig, devices } from "@playwright/test";

function loadE2eEnvFile() {
  const path = resolve(process.cwd(), "e2e/.env");
  if (!existsSync(path)) return;
  for (const line of readFileSync(path, "utf8").split(/\r?\n/)) {
    const t = line.trim();
    if (!t || t.startsWith("#")) continue;
    const i = t.indexOf("=");
    if (i <= 0) continue;
    const key = t.slice(0, i).trim();
    let val = t.slice(i + 1).trim();
    if (
      (val.startsWith('"') && val.endsWith('"')) ||
      (val.startsWith("'") && val.endsWith("'"))
    ) {
      val = val.slice(1, -1);
    }
    if (process.env[key] == null || process.env[key] === "") {
      process.env[key] = val;
    }
  }
}

loadE2eEnvFile();

const rawBaseInput = (process.env.E2E_BASE_URL || "http://localhost:5174").trim();
const rawBase = rawBaseInput.endsWith("/") ? rawBaseInput : `${rawBaseInput}/`;
const insecure = process.env.E2E_INSECURE === "1" || process.env.SMOKE_INSECURE === "1";
const useSystemChrome = process.env.E2E_USE_CHANNEL !== "0";

const config = {
  testDir: "./e2e",
  testMatch: /.*\.spec\.ts/,
  fullyParallel: false,
  workers: 1,
  retries: process.env.CI ? 1 : 0,
  timeout: 120_000,
  expect: { timeout: 20_000 },
  reporter: [["list"], ["html", { open: "never", outputFolder: "playwright-report" }]],
  use: {
    baseURL: rawBase,
    ignoreHTTPSErrors: insecure,
    trace: "on-first-retry",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
    locale: "ko-KR",
  },
  projects: [
    {
      name: "chromium",
      use: useSystemChrome
        ? { ...devices["Desktop Chrome"], channel: "chrome" }
        : { ...devices["Desktop Chrome"] },
    },
  ],
};

if (process.env.E2E_WEB_SERVER === "1") {
  config.webServer = {
    command: "npm run dev -- --host localhost --port 5174",
    url: "http://localhost:5174/login",
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  };
}

export default defineConfig(config);
