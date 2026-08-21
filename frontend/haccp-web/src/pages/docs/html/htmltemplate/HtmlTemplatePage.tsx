/**
 * HtmlTemplatePage — 일반위생·공정점검 양식관리.
 *
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 공통 HtmlFormTemplatePage에 공정점검 상수와 HygPrcPaper 를 넘긴다
 *   2) 저장본은 html_hyg_prc_001부터 채번되어 문서주기 좌측에 오른다
 *   3) 표준·pending은 지면 수정 불가
 *
 * PIPELINE[HF130] HTML양식 원본 화면
 */
import { HygPrcPaper } from "./HygPrcPaper";
import { HtmlFormTemplatePage } from "../HtmlFormTemplatePage";
import {
  PAPER_SUBTITLE,
  PAPER_TITLE,
  PERSIST_ID,
  SCRN_CD,
  SPLIT_KEY,
  STD_TMPL_CD,
  nextHtmlHygTmplCd,
} from "./HtmlTemplateRule";

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) HTML양식 원본 하위 공정점검 메뉴에서 연다
 *   2) 공통 지면·그리드는 HtmlFormTemplatePage
 *   3) scrnCd는 폴더를 옮겨도 바꾸지 않는다
 */
export default function HtmlTemplatePage() {
  return (
    <HtmlFormTemplatePage
      // 화면코드 — tbl_screen.scrn_cd. 권한·그리드 pref
      scrnCd={SCRN_CD}
      // 열 너비 저장 키
      persistId={PERSIST_ID}
      // 좌우 분할 비율 저장 키
      splitKey={SPLIT_KEY}
      // 예시 양식코드 — html_hyg_prc_000. 목록 SP 가족 분기
      stdTmplCd={STD_TMPL_CD}
      // 지면 제목
      paperTitle={PAPER_TITLE}
      // 지면 부제 — 매일 작성
      paperSubtitle={PAPER_SUBTITLE}
      // pending 양식코드 제안 — html_hyg_prc_001…
      nextTmplCd={nextHtmlHygTmplCd}
      // 우측 지면 — 공정점검표 HTML. 검증점검과 공유하지 않는다
      PaperComponent={HygPrcPaper}
    />
  );
}
