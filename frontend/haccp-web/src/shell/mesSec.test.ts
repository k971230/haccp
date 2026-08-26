/**
 * mesSec.test — 패널 활성 조상 탐색.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 헤더 직계 부모만 패널이다. 바깥 래퍼는 고르지 않는다
 *   2) npm test 로 실행 — 트리·그리드 클릭 초록이 어긋나면 이 케이스가 먼저 깨진다
 *   3) 실패하면 중첩 분할에서 안쪽 헤더가 같이 칠해지거나 단패널이 안 잡힌 것이다
 */
// 역할 — Vitest describe·expect·it
import { describe, expect, it } from "vitest";
// 역할 — 클릭 지점 → 헤더 패널
import { closestSecPanel } from "./mesSec";

function el(html: string): HTMLElement {
  const wrap = document.createElement("div");
  wrap.innerHTML = html.trim();
  return wrap.firstElementChild as HTMLElement;
}

describe("closestSecPanel", () => {
  it("트리 헤더 클릭 → 그 부모 패널", () => {
    const panel = el(`<div class="card"><div class="mes-grid-head"><b>메뉴 트리</b></div><button>전체</button></div>`);
    const head = panel.querySelector("b")!;
    expect(closestSecPanel(head)).toBe(panel);
  });

  it("그리드 셀 클릭 → 헤더를 직계 자식으로 둔 패널", () => {
    const panel = el(
      `<div class="card"><div class="mes-grid-head"><b>로그인 이력</b></div><table><td class="cell">x</td></table></div>`,
    );
    const cell = panel.querySelector(".cell")!;
    expect(closestSecPanel(cell)).toBe(panel);
  });

  it("중첩 분할 — 안쪽 패널만 반환 (바깥 칸은 건너뜀)", () => {
    const outer = el(`
      <div class="outer">
        <div class="inner">
          <div class="mes-grid-head"><b>사용자 코드</b></div>
          <span class="cell">행</span>
        </div>
      </div>
    `);
    const cell = outer.querySelector(".cell")!;
    expect(closestSecPanel(cell)?.className).toBe("inner");
  });

  it("검색·사이드바처럼 헤더 없음 → null", () => {
    const bar = el(`<div class="search"><input /></div>`);
    expect(closestSecPanel(bar.querySelector("input"))).toBeNull();
  });
});
