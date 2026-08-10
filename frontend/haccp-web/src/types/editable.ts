/**
 * editable.ts — types 공통 editable.
 *
 * 주요 역할:
 *     1. 타입·순수 함수·스타일 헬퍼
 *     2. React/UI 의존 없음
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
