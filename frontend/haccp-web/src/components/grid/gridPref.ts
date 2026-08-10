/** 그리드 열 pref v2 — DB 저장: hidden + order + sizing.
 * PIPELINE[F163]
 * 연동: useMesTable(F75) 로드/저장 · GridChrome(F83) 열 메뉴
 */

// 설명 — DB 저장 pref JSON 스키마(v2)
export interface GridPrefV2 {
  v: 2;
  hidden: Record<string, boolean>;
  order: string[];
  sizing: Record<string, number>;
}

// 설명 — parseGridPref 반환 — 파싱된 hidden·order·sizing
export interface GridPrefParsed {
  hidden: Record<string, boolean>;
  order: string[];
  sizing: Record<string, number>;
}

// 설명 — 빈 pref 기본값
const empty = (): GridPrefParsed => ({ hidden: {}, order: [], sizing: {} });

/** v1은 hidden만, v2는 hidden+order+sizing. 실패 시 빈 객체. */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) DB pref JSON 문자열 파싱 — v1/v2 호환·손상 시 빈 객체
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 설명 — DB pref JSON 문자열 파싱 — v1/v2 호환·손상 시 빈 객체
export function parseGridPref(raw: string | null | undefined): GridPrefParsed {
  if (!raw?.trim()) return empty();
  try {
    const p = JSON.parse(raw) as { v?: number; hidden?: Record<string, boolean>; order?: string[]; sizing?: Record<string, number> };
    if (!p || typeof p !== "object") return empty();
    const hidden = p.hidden && typeof p.hidden === "object" ? { ...p.hidden } : {};
    if (p.v === 2) {
      return {
        hidden,
        order: Array.isArray(p.order) ? p.order.filter((x) => typeof x === "string") : [],
        sizing: p.sizing && typeof p.sizing === "object"
          ? Object.fromEntries(Object.entries(p.sizing).filter(([, w]) => typeof w === "number" && w >= 50))
          : {},
      };
    }
    return { hidden, order: [], sizing: {} };
  } catch {
    return empty();
  }
}

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) pref 객체를 v:2 JSON 문자열로 직렬화
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 설명 — pref 객체를 v:2 JSON 문자열로 직렬화
export function serializeGridPref(pref: Omit<GridPrefV2, "v">): string {
  const payload: GridPrefV2 = {
    v: 2,
    hidden: pref.hidden,
    order: pref.order,
    sizing: pref.sizing,
  };
  return JSON.stringify(payload);
}
