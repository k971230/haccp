/**
 * resolveDelete — 선택행 우선 삭제 대상 해석.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 체크 다중선택이 있으면 그 행을, 없으면 활성 행을 삭제 대상으로 삼는다
 *   2) ProcessPage ADR-026과 같은 순서를 HACCP 관리 그리드에 적용한다
 *   3) 대상이 없으면 빈 배열을 반환해 호출부가 업무 안내를 한다
 *
 * PIPELINE[HF97] 삭제 대상 해석
 * PIPELINE[HF90, F41] 연관 모듈
 */
// 역할 — 편집 행 타입
import type { EditableRow } from "@/types/editable";

/**
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 삭제 버튼이 누른 시점에 실제 대상 행 목록을 결정한다
 *   2) selectedKeys가 비어 있을 때(= 체크 없음) activeKey 단건으로 폴백한다
 *   3) 활성 키도 없으면 빈 배열을 반환한다
 */
export function resolveRowsForDelete<T>(
  // 현재 그리드 전체 행
  rows: EditableRow<T>[],
  // 포커스 행 _key
  activeKey: string | null,
  // 활성 키가 없을 때 첫 후보로 맞출 setter
  setActiveKey: (key: string | null) => void,
  // 체크된 _key 목록 — 다중 삭제 우선
  selectedKeys?: string[] | null,
): EditableRow<T>[] {
  const sel = (selectedKeys ?? []).filter(Boolean);
  if (sel.length > 0) {
    const set = new Set(sel);
    const found = rows.filter((row) => set.has(row._key));
    if (found.length > 0) return found;
  }
  if (!activeKey) return [];
  const one = rows.find((row) => row._key === activeKey);
  if (one) return [one];
  const fallback = rows[0] ?? null;
  if (fallback) setActiveKey(fallback._key);
  return fallback ? [fallback] : [];
}
