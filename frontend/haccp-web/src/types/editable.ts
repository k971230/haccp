/**
 * editable — 편집 그리드 행 타입.
 *
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 저장 전 행을 식별하는 _key 와 변경상태 _rowState 를 붙인다
 *   2) useEditableRows 와 그리드 저장 절차가 함께 쓴다
 *   3) _original 은 load 시점 스냅샷이다 — 잠긴 칸이 바뀌었는지 여기서 본다
 *
 * PIPELINE[F33] 공통 모듈
 */

// 설명 — 편집 행 변경 상태 — C(신규)·U(수정)
export type RowState = "C" | "U"; // Created(신규) / Updated(수정)

/** useEditableRows 가 관리하는 행 — 내부 키·변경상태·원본 스냅샷 포함 */
export type EditableRow<T> = T & {
  _key: string;              // 클라이언트 행 식별자(저장 전 신규행 포함)
  _rowState?: RowState;      // C=신규, U=수정, undefined=변경 없음
  /** load 시점 스냅샷 — 저장 전 잠긴 필드 변경 감지 */
  _original?: Partial<T>;
};
