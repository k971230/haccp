/**
 * CcpPkgDraftRule — CCP 포장 모니터링일지 작성 상수.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 공통 화면 HtmlFormDraftPage 에 넘길 값만 둔다. 업무 판정·컬럼·필수값은 htmlFormDraftShared 공용이다
 *   2) 기준 양식은 ccp-pkg-template 의 자사 양식(html_ccp_pkg_001 이상)이다
 *   3) persist·scrnCd 값을 폴더 이동 후에도 바꾸지 않는다
 *
 * PIPELINE[HF178] CCP 포장 작성 규칙
 */
// 역할 — 계열 예시 양식코드 (이 화면 고유값)
import { HTML_CCP_PKG_000 } from "@/api/docs/htmlFormApi";

/** 화면코드 — tbl_screen.scrn_cd. 폴더를 옮겨도 바꾸지 않는다 */
export const SCRN_CD = "ccp-pkg" as const;

/** 그리드 열 너비·정렬 저장 키. 값을 바꾸면 사용자 설정이 초기화된다 */
export const PERSIST_ID = "ccp-pkg-draft-list" as const;

/** 좌우 분할 비율 저장 키 — 50 은 기본 반반 */
export const SPLIT_KEY = "haccp-split-ccp-pkg-draft-50" as const;

/** 기준 양식 예시코드 — 작성 대상은 이 계열의 자사 양식이다 */
export const STD_TMPL_CD = HTML_CCP_PKG_000;

/** 자사 양식 접두 — html_ccp_pkg_001 이상 */
export const USR_TMPL_PREFIX = "html_ccp_pkg_" as const;

/** 지면 제목 기본값 — 양식명이 없을 때만 쓴다 */
export const PAPER_TITLE = "중요관리점(CCP-1B) 모니터링일지";

/** 지면 부제 */
export const PAPER_SUBTITLE = "(작업 전·작업 종료)";
