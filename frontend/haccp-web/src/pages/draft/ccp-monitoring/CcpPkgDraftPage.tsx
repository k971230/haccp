/**
 * CcpPkgDraftPage — CCP 포장 모니터링일지 작성.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 공통 HtmlFormDraftPage 에 상수·지면·API 만 넘긴다. HYG·CCP검증과 형제 화면이다
 *   2) 좌측 업무(검색·행 추가·양식 팝업·저장·전송·모두 전송·삭제·전송취소)는 전부 공통이다
 *   3) 오른쪽 지면만 이 양식 구조다 — mode=write 에서 기록행을 제어 입력·행 추가·행 삭제한다
 *
 * PIPELINE[HF178] CCP 포장 작성 화면
 */
// 역할 — CCP 포장 지면 — 양식관리와 같은 HTML
import { CcpPkgPaper } from "@/pages/docs/html/ccppkgtemplate/CcpPkgPaper";
// 역할 — 양식 작성 공통 화면
import { HtmlFormDraftPage } from "../HtmlFormDraftPage";
// 역할 — 이 화면 작성 API
import { ccpPkgDraftApi } from "@/api/draft/ccpMonitoringDraftApi";
// 역할 — 이 화면 상수
import { PAPER_SUBTITLE, PAPER_TITLE, PERSIST_ID, SCRN_CD, SPLIT_KEY } from "./CcpPkgDraftRule";

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 양식 작성 대분류 CCP 모니터링 메뉴에서 연다
 *   2) 검색·목록·팝업·저장·전송·삭제 동작은 전부 공통 화면이 갖는다
 *   3) 형제 화면과 UI 가 갈리지 않도록 여기서 레이아웃을 덧붙이지 않는다
 */
export function CcpPkgDraftPage() {
  return (
    <HtmlFormDraftPage
      // 화면코드 — tbl_screen.scrn_cd. 권한·그리드 pref·API 베이스 기준
      scrnCd={SCRN_CD}
      // 열 너비 저장 키
      persistId={PERSIST_ID}
      // 좌우 분할 비율 저장 키
      splitKey={SPLIT_KEY}
      // 지면 제목 — 양식명이 없을 때만 쓴다
      paperTitle={PAPER_TITLE}
      // 지면 부제
      paperSubtitle={PAPER_SUBTITLE}
      // 우측 지면 — 이 양식 전용 HTML
      PaperComponent={CcpPkgPaper}
      // 작성 API — /api/v1/draft/ccp-monitoring/ccp-pkg
      api={ccpPkgDraftApi}
    />
  );
}
