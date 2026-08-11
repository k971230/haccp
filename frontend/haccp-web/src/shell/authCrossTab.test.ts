/**
 * authCrossTab.test — 멀티탭 로그아웃 storage 신호 (G-22 / F174).
 *
 * 개발자: 박승우
 * 일자: 2026-08-11
 * 코멘트:
 *   1) 로그아웃 신호 키·세션 키 삭제 시 onForeignLogout 이 호출되는지 검증한다
 *   2) npm test 로 실행 — 브라우저 2탭 수동 스모크의 자동 대응분이다
 *   3) 실패하면 타 탭이 로그인 화면에 안 내려가는 사고와 같다
 */
import { afterEach, describe, expect, it, vi } from "vitest";
import { AUTH_LOGOUT_SIGNAL_KEY, AUTH_STORAGE_KEY } from "@/shell/authKeys";
import { subscribeAuthCrossTab } from "@/shell/authCrossTab";

describe("subscribeAuthCrossTab", () => {
  afterEach(() => {
    localStorage.clear();
  });

  it("로그아웃 신호 키 변경 시 콜백", () => {
    const onForeign = vi.fn();
    const unsub = subscribeAuthCrossTab(onForeign);
    window.dispatchEvent(
      new StorageEvent("storage", {
        key: AUTH_LOGOUT_SIGNAL_KEY,
        newValue: String(Date.now()),
        storageArea: localStorage,
      })
    );
    expect(onForeign).toHaveBeenCalledTimes(1);
    unsub();
  });

  it("haccp-auth 키 삭제 시 콜백 (2차 감지)", () => {
    const onForeign = vi.fn();
    const unsub = subscribeAuthCrossTab(onForeign);
    window.dispatchEvent(
      new StorageEvent("storage", {
        key: AUTH_STORAGE_KEY,
        newValue: null,
        storageArea: localStorage,
      })
    );
    expect(onForeign).toHaveBeenCalledTimes(1);
    unsub();
  });

  it("토큰 빈 persist JSON 이면 콜백", () => {
    const onForeign = vi.fn();
    const unsub = subscribeAuthCrossTab(onForeign);
    window.dispatchEvent(
      new StorageEvent("storage", {
        key: AUTH_STORAGE_KEY,
        newValue: JSON.stringify({ state: { token: null } }),
        storageArea: localStorage,
      })
    );
    expect(onForeign).toHaveBeenCalledTimes(1);
    unsub();
  });

  it("무관한 키는 무시", () => {
    const onForeign = vi.fn();
    const unsub = subscribeAuthCrossTab(onForeign);
    window.dispatchEvent(
      new StorageEvent("storage", {
        key: "haccp-login-prefs",
        newValue: "{}",
        storageArea: localStorage,
      })
    );
    expect(onForeign).not.toHaveBeenCalled();
    unsub();
  });
});
