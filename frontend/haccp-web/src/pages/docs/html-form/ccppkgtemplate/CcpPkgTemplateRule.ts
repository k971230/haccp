/**
 * CcpPkgTemplateRule — 중요관리점(CCP-1B) 모니터링일지 양식관리 상수.
 *
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 공통 화면 HtmlFormTemplatePage에 넘길 값만 둔다
 *   2) 예시 html_ccp_pkg_000. 저장본은 html_ccp_pkg_001부터 SP가 채번한다
 *   3) persist·scrnCd 값을 폴더 이동 후에도 바꾸지 않는다
 *
 * PIPELINE[HF132] CCP-1B 포장일지 양식 규칙
 */
import { HTML_CCP_PKG_000 } from "@/api/docs/htmlFormApi";
import { nextUsrTmplCd } from "../htmlFormTemplateShared";

/** 화면코드 — tbl_screen.scrn_cd */
export const SCRN_CD = "ccp-pkg-template" as const;

/** 그리드 열 설정 저장 키 — v2 는 사용여부 추가 후 기본 순서. 계정별 pref 는 이 키로 갈린다 */
export const PERSIST_ID = "ccp-pkg-template-list-v2" as const;

/** 좌우 분할 비율 저장 키 — -50 은 기본 반반. 옛 28% 키와 분리 */
export const SPLIT_KEY = "haccp-split-ccp-pkg-template-50" as const;

/** 화면 예시 양식코드 — 시드 항목은 html_ccp_pkg_000 */
export const STD_TMPL_CD = HTML_CCP_PKG_000;

/** 자사 양식 접두 */
export const USR_TMPL_PREFIX = "html_ccp_pkg_" as const;

export const PAPER_TITLE = "중요관리점(CCP-1B) 모니터링일지 [포장공정]";
export const PAPER_SUBTITLE = "(매일 작성)";

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 다음 자사 양식코드를 제안한다 — html_ccp_pkg_001 …
 *   2) 행추가 pending 표시용. 최종 번호는 SP가 전역 MAX로 확정
 *   3) 000은 건너뛰고 빈 목록이면 001
 */
export function nextCcpPkgTmplCd(
  // 현재 그리드 행 — 저장된 자사 + 아직 저장 안 한 draft
  rows: Array<{ tmplCd?: string | null }>,
): string {
  return nextUsrTmplCd(USR_TMPL_PREFIX, rows);
}
