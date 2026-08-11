/**
 * useGridVirtual.test — 가상화 임계 판정 (G-23).
 *
 * 개발자: 박승우
 * 일자: 2026-08-11
 * 코멘트:
 *   1) VITE_GRID_VIRTUAL_THRESHOLD(기본 100) 경계에서 on/off 가 맞는지 고정한다
 *   2) npm test 로 실행 — 대량 화면 스모크의 자동 대응분이다
 *   3) 실패하면 100행 전후 스크롤·DOM 마운트 전략이 어긋난 것이다
 */
import { describe, expect, it } from "vitest";
import { shouldVirtualize, VIRTUAL_THRESHOLD } from "./useGridVirtual";

describe("shouldVirtualize / VIRTUAL_THRESHOLD", () => {
  it("env 기본 임계는 양의 정수", () => {
    expect(VIRTUAL_THRESHOLD).toBeGreaterThan(0);
    // .env.example 기본 100 — 테스트 환경도 동일 fallback
    expect(VIRTUAL_THRESHOLD).toBe(100);
  });

  it("임계 미만은 비활성", () => {
    expect(shouldVirtualize(0)).toBe(false);
    expect(shouldVirtualize(VIRTUAL_THRESHOLD - 1)).toBe(false);
  });

  it("임계 이상은 활성", () => {
    expect(shouldVirtualize(VIRTUAL_THRESHOLD)).toBe(true);
    expect(shouldVirtualize(VIRTUAL_THRESHOLD + 50)).toBe(true);
  });

  it("enabled=false 이면 행 수와 무관하게 비활성", () => {
    expect(shouldVirtualize(500, VIRTUAL_THRESHOLD, false)).toBe(false);
  });

  it("커스텀 임계", () => {
    expect(shouldVirtualize(10, 10)).toBe(true);
    expect(shouldVirtualize(9, 10)).toBe(false);
  });
});
