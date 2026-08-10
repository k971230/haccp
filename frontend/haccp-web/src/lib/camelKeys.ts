/**
 * camelKeys — API Map 응답 snake_case → camelCase 정규화.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) PG SP Map 키가 doc_no로 올 때(= MyBatis camel 미적용) 그리드 field가 비는 문제를 막는다
 *   2) 이미 camelCase인 키는 그대로 두고 underscore가 있을 때만 변환한다
 *   3) 문서함·결재함·개선조치·감사 목록 API 경계에서만 쓴다
 *
 * PIPELINE[HF121] API 키 정규화
 * PIPELINE[HF82, HF87] 연관 모듈
 */

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 단일 키를 camelCase로 바꾼다
 *   2) underscore가 없으면 원문을 반환한다
 *   3) DOC_NO·doc_no 모두 docNo가 된다
 */
export function toCamelKey(key: string): string {
  if (!key || !key.includes("_")) return key;
  return key
    .toLowerCase()
    .replace(/_([a-z0-9])/g, (_, ch: string) => ch.toUpperCase());
}

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 행 객체의 키를 camelCase로 복사한다
 *   2) listDocuments·workflow list 응답에 적용한다
 *   3) 중첩 객체는 1depth만 변환한다 (목록 행 계약)
 */
export function camelizeRow<T extends Record<string, unknown>>(row: Record<string, unknown>): T {
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(row ?? {})) {
    out[toCamelKey(key)] = value;
  }
  return out as T;
}

/** 행 배열 정규화 */
export function camelizeRows<T extends Record<string, unknown>>(rows: Record<string, unknown>[] | null | undefined): T[] {
  return (rows ?? []).map((row) => camelizeRow<T>(row));
}
