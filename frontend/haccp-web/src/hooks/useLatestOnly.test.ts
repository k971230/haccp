/**
 * useLatestOnly.test — 늦게 온 응답이 최신 선택을 덮지 않는지.
 *
 * 개발자: 박승우
 * 일자: 2026-09-04
 * 코멘트:
 *   1) 알맹이 makeLatestOnly 를 직접 부른다. 훅은 이걸 ref 에 담는 한 겹일 뿐이다
 *   2) 응답이 역순으로 와도 마지막에 시작한 적재만 참이어야 한다
 *   3) 가드를 빼면 「A 를 보다 B 를 눌렀는데 우측은 A」가 된다
 */
import { describe, expect, it } from "vitest";
import { makeLatestOnly } from "./useLatestOnly";

describe("makeLatestOnly", () => {
  it("한 번만 시작했으면 최신이다", () => {
    const begin = makeLatestOnly();
    expect(begin()()).toBe(true);
  });

  it("나중 적재가 이긴다 — 먼저 시작한 것은 낡았다", () => {
    const begin = makeLatestOnly();
    const first = begin();
    const second = begin();
    expect(first()).toBe(false);
    expect(second()).toBe(true);
  });

  it("응답이 역순으로 와도 판정이 같다", () => {
    // A 를 열고 B 를 눌렀는데 A 의 응답이 늦게 온 경우
    const begin = makeLatestOnly();
    const a = begin();
    const b = begin();
    expect(b()).toBe(true);
    // 여기서 true 면 우측이 A 로 되돌아간다 — 오승인·오저장의 자리다
    expect(a()).toBe(false);
  });

  it("몇 번을 물어도 답이 같다", () => {
    const begin = makeLatestOnly();
    const only = begin();
    expect(only()).toBe(true);
    expect(only()).toBe(true);
  });

  it("화면마다 번호가 따로다", () => {
    const one = makeLatestOnly();
    const two = makeLatestOnly();
    const a = one();
    two();
    two();
    // 다른 화면에서 적재가 돌아도 내 판정은 안 흔들린다
    expect(a()).toBe(true);
  });
});
