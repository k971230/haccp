/**
 * HwpDraftRule — HWP 양식 작성 상수.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 공통 화면 HtmlFormDraftPage 에 넘길 값만 둔다. 업무 판정·컬럼·필수값은 htmlFormDraftShared 공용이다
 *   2) 작성 대상은 사용양식 관리에서 사용여부 예로 둔 HWP 양식 전체다 — 계열 접두가 따로 없다
 *   3) persist·scrnCd 값을 폴더 이동 후에도 바꾸지 않는다
 *
 * PIPELINE[HF182] HWP 작성 규칙
 */

/** 화면코드 — tbl_screen.scrn_cd. 폴더를 옮겨도 바꾸지 않는다 */
export const SCRN_CD = "hwp-write" as const;

/** 그리드 열 너비·정렬 저장 키. 값을 바꾸면 사용자 설정이 초기화된다 */
export const PERSIST_ID = "hwp-draft-list" as const;

/** 좌우 분할 비율 저장 키 — 50 은 기본 반반 */
export const SPLIT_KEY = "haccp-split-hwp-draft-50" as const;

/** 지면 제목 기본값 — 양식명이 없을 때만 쓴다 */
export const PAPER_TITLE = "HWP 문서";

/** 지면 부제 */
export const PAPER_SUBTITLE = "(한글 문서 작성)";

/** 본문 파일 종류 — 문서 첨부 중 한글 원본을 가리킨다 */
export const HWP_SRC_KIND = "HWP_SRC" as const;
