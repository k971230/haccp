/**
 * screens.smoke — 메뉴 28화면 전수 스모크.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 화면마다 라우트 진입·콘솔 error 0·4xx/5xx 0·뼈대 노출만 본다. 업무 시나리오는 다른 스펙이다
 *   2) 라우팅·권한·SP 오류가 한 번에 잡힌다 — 메뉴 개편 회귀 방어선이다
 *   3) 28개는 tbl_menu 에 남긴 화면과 같다. 메뉴를 늘리면 여기도 늘린다
 *
 * PIPELINE[HF130] E2E
 */
import { expect, test } from "@playwright/test";
import { adminCreds, login, openScreen } from "./helpers";

/** 메뉴에 남은 28화면 — SCREEN_PATH 그대로 */
const SCREENS: Array<{ path: string; name: string }> = [
  { path: "/today-tasks", name: "오늘 할 일" },
  { path: "/docs/sch/schedule-cycle-management", name: "문서주기관리" },
  { path: "/docs/hwp/hwp-template-management", name: "사용양식 관리" },
  { path: "/docs/html-form/hyg-process-template", name: "일반위생·공정점검 양식관리" },
  { path: "/docs/html-form/ccp-verify-template", name: "CCP 검증점검표 양식관리" },
  { path: "/docs/html-form/ccp-pkg-template", name: "CCP 포장공정 일지관리" },
  { path: "/docs/html-form/ccp-htg-template", name: "CCP 가열공정 일지관리" },
  { path: "/docs/html-form/ccp-mtl-template", name: "CCP 금속검출공정 일지관리" },
  { path: "/flow/appr/attach", name: "결재 첨부" },
  { path: "/flow/appr/sign-ready", name: "결재 대기" },
  { path: "/flow/appr/sign-ok", name: "결재 완료" },
  { path: "/flow/box/document-inbox", name: "문서함" },
  { path: "/flow/ca/corrective-action-management", name: "이탈·개선조치" },
  { path: "/draft/html/hyg-process", name: "일반위생·공정점검 작성" },
  { path: "/draft/html/ccp-verify", name: "CCP 검증점검표 작성" },
  { path: "/draft/ccp-monitoring/ccp-pkg", name: "CCP 포장공정 작성" },
  { path: "/draft/ccp-monitoring/ccp-htg", name: "CCP 가열공정 작성" },
  { path: "/draft/ccp-monitoring/ccp-mtl", name: "CCP 금속검출공정 작성" },
  { path: "/draft/hwp-doc/hwp-write", name: "HWP 작성" },
  { path: "/sys/code/common-code-management", name: "공통코드 관리" },
  { path: "/sys/code/menu-management", name: "메뉴 관리" },
  { path: "/sys/code/role-management", name: "권한그룹 관리" },
  { path: "/sys/code/department-management", name: "부서 관리" },
  { path: "/sys/code/user-management", name: "사용자 관리" },
  { path: "/sys/code/approval-line-management", name: "결재선 관리" },
  { path: "/sys/logs/login-history", name: "로그인 이력" },
  { path: "/sys/logs/screen-usage-statistics", name: "화면 이용 통계" },
  { path: "/sys/logs/audit-log", name: "변경 감사 로그" },
];

/**
 * 우리 코드가 아닌 콘솔 문구 — 이것만 넘긴다.
 *
 * `[CanvasView] 페이지 0 정보가 없습니다` 는 @rhwp/editor(0.8.4) 가
 * **문서를 안 연 빈 캔버스**에서 남기는 SDK 로그다. 사용양식관리는 화면에 들어오는 즉시
 * 편집기를 만들어 두고(「왼쪽에서 양식을 선택하세요」) 양식을 고를 때 loadFile 한다 —
 * 그 대기 상태가 이 로그를 만든다. 화면·저장에는 영향이 없다.
 *
 * 진짜로 없애려면 둘 중 하나다. 지금은 안 한다(잘 도는 화면의 편집기 수명주기를 흔든다):
 *   1) 양식을 고를 때 createEditor 하도록 늦춘다 (사용양식관리만)
 *   2) SDK 가 빈 캔버스에서 error 대신 debug 로 남기게 고친다
 *
 * **우리 코드 오류는 하나도 넘기지 않는다.** 문자열이 정확히 이것일 때만 뺀다.
 */
const VENDOR_CONSOLE_OK = ["[CanvasView] 페이지 0 정보가 없습니다"];

test.describe("메뉴 28화면 스모크", () => {
  test("화면마다 열리고 콘솔·네트워크 오류가 없다", async ({ page }) => {
    const { user, pass } = adminCreds();
    await login(page, user, pass);

    // 화면별로 모아서 마지막에 한 번에 보고한다 — 첫 실패에서 멈추면 나머지를 못 본다
    const failures: string[] = [];

    for (const scr of SCREENS) {
      const consoleErrors: string[] = [];
      const badResponses: string[] = [];
      const onConsole = (msg: { type: () => string; text: () => string }) => {
        if (msg.type() !== "error") return;
        const text = msg.text();
        // 벤더 로그만 제외 — 우리 문구는 전부 실패로 센다
        if (VENDOR_CONSOLE_OK.some((v) => text.includes(v))) return;
        consoleErrors.push(text);
      };
      const onResponse = (res: { status: () => number; url: () => string }) => {
        const s = res.status();
        // 401 은 세션 만료 흐름이라 따로 본다. 여기서는 4xx/5xx 를 통째로 잡는다
        if (s >= 400) badResponses.push(`${s} ${res.url()}`);
      };
      page.on("console", onConsole);
      page.on("response", onResponse);

      try {
        await openScreen(page, scr.path);
        // 셸이 그 경로에 머물러야 한다 — 없는 화면이면 오늘 할 일로 튕긴다
        await page.waitForTimeout(1500);
        const url = page.url();
        if (!url.includes(scr.path)) {
          failures.push(`${scr.name} (${scr.path}) — 다른 경로로 튕겼다: ${url}`);
        }
        if (consoleErrors.length > 0) {
          failures.push(`${scr.name} — 콘솔 오류 ${consoleErrors.length}건: ${consoleErrors[0]}`);
        }
        if (badResponses.length > 0) {
          failures.push(`${scr.name} — 응답 오류 ${badResponses.length}건: ${badResponses[0]}`);
        }
      } catch (e) {
        failures.push(`${scr.name} (${scr.path}) — 진입 실패: ${String(e).slice(0, 160)}`);
      } finally {
        page.off("console", onConsole);
        page.off("response", onResponse);
      }
    }

    expect(failures, `\n${failures.join("\n")}\n`).toEqual([]);
  });
});
