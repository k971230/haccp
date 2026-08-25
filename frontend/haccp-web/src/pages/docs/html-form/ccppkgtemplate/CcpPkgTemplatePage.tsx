/**
 * CcpPkgTemplatePage — 중요관리점(CCP-1B) 모니터링일지 양식관리.
 *
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) 공통 HtmlFormTemplatePage에 포장일지 상수와 CcpPkgPaper만 넘긴다
 *   2) 저장본은 tml_ccp_pkg_001부터 채번되어 문서주기 좌측에 오른다
 *   3) 표준·pending은 지면 수정 불가. 작성 화면은 후속
 *
 * PIPELINE[HF132] CCP-1B 포장일지 양식 화면
 */
import { CcpPkgPaper } from "./CcpPkgPaper";
import { HtmlFormTemplatePage } from "../HtmlFormTemplatePage";
import {
  PAPER_SUBTITLE,
  PAPER_TITLE,
  PERSIST_ID,
  SCRN_CD,
  SPLIT_KEY,
  STD_TMPL_CD,
  nextCcpPkgTmplCd,
} from "./CcpPkgTemplateRule";

/**
 * 개발자: 박승우
 * 일자: 2026-08-20
 * 코멘트:
 *   1) HTML양식 원본 하위 CCP-1B 포장일지 메뉴에서 연다
 *   2) 공정점검·검증점검과 같은 좌우 분할·저장 흐름이다
 *   3) scrnCd는 폴더를 옮겨도 바꾸지 않는다
 */
export default function CcpPkgTemplatePage() {
  return (
    <HtmlFormTemplatePage
      // 화면코드 — tbl_screen.scrn_cd. 권한·그리드 pref
      scrnCd={SCRN_CD}
      // 열 너비 저장 키
      persistId={PERSIST_ID}
      // 좌우 분할 비율 저장 키
      splitKey={SPLIT_KEY}
      // 예시 양식코드 — tml_ccp_pkg_000. 목록 SP 가족 분기
      stdTmplCd={STD_TMPL_CD}
      // 지면 제목
      paperTitle={PAPER_TITLE}
      // 지면 부제 — 기본 주기 매일
      paperSubtitle={PAPER_SUBTITLE}
      // pending 양식코드 제안 — tml_ccp_pkg_001…
      nextTmplCd={nextCcpPkgTmplCd}
      // 우측 지면 — 포장 모니터링일지 레이아웃
      PaperComponent={CcpPkgPaper}
    />
  );
}
