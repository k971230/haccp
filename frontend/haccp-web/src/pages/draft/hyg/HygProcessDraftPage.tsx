/**
 * HygProcessDraftPage — HYG 위생공정 양식 작성.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 공통 HtmlFormDraftPage 에 HYG 상수·지면·API 만 넘긴다. CCP(ccp-verify)와 형제 화면이다
 *   2) 양식관리 hyg-process-template 에서 사용여부 예로 둔 자사 양식만 작성한다
 *   3) scrnCd 는 폴더를 옮겨도 바꾸지 않는다
 *
 * PIPELINE[HF173] 위생공정 작성 화면
 */
// 역할 — 공정점검 지면 — 양식관리와 같은 HTML
import { HygPrcPaper } from "@/pages/docs/html/htmltemplate/HygPrcPaper";
// 역할 — 양식 작성 공통 화면
import { HtmlFormDraftPage } from "../HtmlFormDraftPage";
// 역할 — HYG 작성 API 묶음
import { hygProcessDraftApi } from "@/api/draft/hygProcessDraftApi";
// 역할 — 이 화면 상수
import { PAPER_SUBTITLE, PAPER_TITLE, PERSIST_ID, SCRN_CD, SPLIT_KEY } from "./HygProcessDraftRule";

/**
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 양식 작성 대분류 HYG 양식 메뉴에서 연다
 *   2) 검색·목록·팝업·저장·전송·삭제 동작은 전부 공통 화면이 갖는다
 *   3) CCP 와 UI 가 갈리지 않도록 여기서 레이아웃을 덧붙이지 않는다
 */
export function HygProcessDraftPage() {
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
      // 지면 부제 — 매일 작성
      paperSubtitle={PAPER_SUBTITLE}
      // 우측 지면 — 공정점검표 HTML
      PaperComponent={HygPrcPaper}
      // 작성 API — /api/v1/draft/hyg/hyg-process
      api={hygProcessDraftApi}
    />
  );
}
