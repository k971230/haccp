/**
 * pageClasses.ts — layout UI 컴포넌트.
 *
 * 주요 역할:
 *     1. Page에서 조합해 사용하는 presentational/behavior 컴ponent
 *     2. layout 영역 재사용 UI
 *
 * 설계 기준:
 *     - API 호출 없음(Page/훅 위임).
 *     - Props: [Name]Props 명명.
 *
 * PIPELINE[HF93] UI 컴포넌트 — mes-web pageClasses와 동일 계약
 */

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 업무 화면 루트 — 세로 flex·gap
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 설명 — 업무 화면 루트 — 세로 flex·gap
export const pageRootClass = "flex h-full min-h-0 flex-col gap-4";

/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 그리드 블록 — flex-1 세로 채움
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
// 설명 — 그리드 블록 — flex-1 세로 채움
export const gridBlockClass = "flex min-h-0 flex-1 flex-col";

/** 그리드 패널 헤더 — treePanelHeadClass와 같은 h-9. wrap 금지로 화면 전환 시 흔들림 방지 */
export const gridHeadClass =
  "mes-grid-head flex h-9 shrink-0 items-center justify-between gap-2 overflow-hidden border-b border-slate-200 bg-slate-50/70 px-3 [&_b]:truncate";

/** 그리드 패널 (분할 화면 — border 포함) */
export const gridPanelClass =
  "flex min-h-0 min-w-0 flex-1 flex-col overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm";

/** 좌우 분할 패널 — gridPanelClass + h-full + p-2. 문서주기·사용양식·HTML양식 원본 */
export const splitPanelClass =
  "flex min-h-0 h-full flex-1 flex-col overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm p-2";

/** 3분할 우측 메인 컬럼 */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) 그리드 블록 — flex-1 세로 채움
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export const panelMainClass = "flex min-h-0 flex-1 flex-col";

/** 검색 조건 행 — 필드(좌) + 조회(우) */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) searchFieldsClass — 인프라 export
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export const searchFieldsClass =
  "flex w-full flex-wrap items-end gap-x-3 gap-y-2";

/** 검색 조건 필드 묶음 */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) searchFieldsInnerClass — 인프라 export 함수/상수
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export const searchFieldsInnerClass =
  "flex min-w-0 flex-1 flex-wrap items-end gap-x-3 gap-y-2";

/** 검색 카드 조회 버튼 — 우측 정렬 */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) searchActionsClass — 인프라 export 함수/상수
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export const searchActionsClass =
  "ml-auto flex shrink-0 items-end self-end pb-0.5";

/** 단일 그리드 공통 툴바 */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) pageToolbarClass — 인프라 export 함수/상수
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export const pageToolbarClass =
  "flex shrink-0 flex-wrap items-center justify-end gap-1.5 rounded-xl border border-slate-200 bg-white px-3 py-2 shadow-sm";

/** 그리드 제목만 (PageToolbar 사용 시) */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) gridTitleOnlyClass — 인프라 export 함수/상수
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export const gridTitleOnlyClass = "mes-grid-title-only";

/** 그리드 패널 하단 안내 */
/**
 * 개발자: 박승우
 * 일자: 2026-07-10
 * 코멘트:
 *   1) gridFootnoteClass — 인프라 export 함수/상수
 *   2) 모듈 import·화면/훅에서 호출될 때
 *   3) 성공 시 정상 반환, 실패 시 예외·가드 메시지
 */
export const gridFootnoteClass =
  "shrink-0 rounded-xl border border-blue-100 bg-blue-50/60 px-3 py-2.5 text-xs leading-relaxed text-blue-800";
