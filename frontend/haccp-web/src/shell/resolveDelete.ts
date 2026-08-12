/**
 * resolveDelete — 선택행 우선 삭제 대상 해석.
 *
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) selectedKeys를 넘긴 화면(= 선택열 있음)은 체크된 행만 삭제한다
 *   2) 체크 없이 activeKey(행추가 포커스)로 삭제하지 않는다 — 미체크 일괄 삭제 방지
 *   3) selectedKeys 미전달 화면만 activeKey 단건을 쓴다
 *
 * PIPELINE[HF97] 삭제 대상 해석
 * PIPELINE[HF90, F41] 연관 모듈
 */
// 역할 — 편집 행 타입
import type { EditableRow } from "@/types/editable";

/**
 * 개발자: 박승우
 * 일자: 2026-08-12
 * 코멘트:
 *   1) 삭제 버튼이 누른 시점에 실제 대상 행 목록을 결정한다
 *   2) selectedKeys가 배열로 전달되면(= selectable) 체크 행만 반환한다
 *   3) selectedKeys 미전달일 때만 activeKey 단건 — 없으면 빈 배열
 */
export function resolveRowsForDelete<T>(
  // 현재 그리드 전체 행
  rows: EditableRow<T>[],
  // 포커스 행 _key — selectedKeys 미사용 화면 전용
  activeKey: string | null,
  // 시그니처 호환 — 첫 행 폴백·활성 강제 없음
  _setActiveKey: (key: string | null) => void,
  // 체크된 _key 목록 — 전달 시(배열) 체크만 인정, undefined면 activeKey 폴백
  selectedKeys?: string[] | null,
): EditableRow<T>[] {
  // selectable 그리드 — 호출부가 selKeys state(배열)를 넘김. 빈 배열도 "체크 없음"
  if (selectedKeys !== undefined && selectedKeys !== null) {
    const sel = selectedKeys.filter(Boolean);
    if (sel.length === 0) return [];
    const set = new Set(sel);
    return rows.filter((row) => set.has(row._key));
  }
  // 선택열 없는 화면 — 활성 행 단건
  if (!activeKey) return [];
  const one = rows.find((row) => row._key === activeKey);
  return one ? [one] : [];
}
