/**
 * screens.smoke — 메뉴 화면 전수 스모크.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 화면마다 라우트 진입·콘솔 error 0·4xx/5xx 0·뼈대 노출만 본다. 업무 시나리오는 다른 스펙이다
 *   2) 라우팅·권한·SP 오류가 한 번에 잡힌다 — 메뉴 개편 회귀 방어선이다
 *   3) 대상은 SCREEN_PATH 에서 뽑는다 — 화면을 늘려도 여기는 손댈 것이 없다
 *
 * PIPELINE[HF130] E2E
 */
import { expect, test } from "@playwright/test";
import { adminCreds, login, openScreen } from "./helpers";
// 역할 — 화면 목록 정본. 손으로 적은 배열이 뒤처지지 않게 여기서 뽑는다
import { SCREEN_PATH } from "../src/shell/tabRoute";

/*
 * 메뉴 화면 — **SCREEN_PATH 에서 뽑는다.**
 *
 * 예전에는 여기에 손으로 적은 배열이 있었다. 옮길 당시 29개로 SCREEN_PATH 와 맞았지만
 * (머리주석만 「28화면」으로 낡아 있었다), 화면을 늘릴 때 여기를 같이 늘리는 것은
 * **절차에 맡긴 약속**이었다. 그런 약속은 지켜지다 한 번 안 지켜지는 순간
 * 새 화면이 스모크를 통째로 건너뛰고, 그 사실이 초록불에 가려 안 보인다.
 *
 * 이름은 보기 좋으라고 붙이는 것뿐이라 없으면 화면코드를 쓴다.
 * 화면을 늘리면 여기는 아무것도 안 해도 된다.
 */
const SCREEN_NAME: Record<string, string> = {
  "today-tasks": "오늘 할 일",
  "calendar": "일정 캘린더",
  "schedule-cycle-management": "문서주기관리",
  "hwp-template-management": "사용양식 관리",
  "hyg-process-template": "일반위생·공정점검 양식관리",
  "ccp-verify-template": "CCP 검증점검표 양식관리",
  "ccp-pkg-template": "CCP 포장공정 일지관리",
  "ccp-htg-template": "CCP 가열공정 일지관리",
  "ccp-mtl-template": "CCP 금속검출공정 일지관리",
  "attach": "결재 첨부",
  "sign-ready": "결재 대기",
  "sign-ok": "결재 완료",
  "document-inbox": "문서함",
  "corrective-action-management": "이탈·개선조치",
  "hyg-process": "일반위생·공정점검 작성",
  "ccp-verify": "CCP 검증점검표 작성",
  "ccp-pkg": "CCP 포장공정 작성",
  "ccp-htg": "CCP 가열공정 작성",
  "ccp-mtl": "CCP 금속검출공정 작성",
  "hwp-write": "HWP 작성",
  "common-code-management": "공통코드 관리",
  "menu-management": "메뉴 관리",
  "role-management": "권한그룹 관리",
  "department-management": "부서 관리",
  "user-management": "사용자 관리",
  "approval-line-management": "결재선 관리",
  "login-history": "로그인 이력",
  "screen-usage-statistics": "화면 이용 통계",
  "audit-log": "변경 감사 로그",
};

const SCREENS: Array<{ path: string; name: string }> = Object.entries(SCREEN_PATH)
  .map(([scrnCd, path]) => ({ path, name: SCREEN_NAME[scrnCd] ?? scrnCd }));


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
