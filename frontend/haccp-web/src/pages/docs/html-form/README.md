# pages/docs/html

화면 1개 = 폴더 1개.

| 폴더 | scrnCd | 역할 |
|---|---|---|
| htmltemplate | hyg-process-template | 일반위생·공정점검 양식관리(`html_hyg_prc_NNN`) |
| ccpverifytemplate | ccp-verify-template | 중요관리점(CCP) 검증점검표 양식관리(`html_ccp_chk_NNN`) |
| ccppkgtemplate | ccp-pkg-template | 중요관리점(CCP-1B) 모니터링일지 양식관리(`html_ccp_pkg_NNN`) |
| ccphtgtemplate | ccp-htg-template | 중요관리점(CCP-2B) 모니터링일지 양식관리(`html_ccp_htg_NNN`) |
| ccpmtltemplate | ccp-mtl-template | 중요관리점(CCP-3P) 모니터링일지 양식관리(`html_ccp_mtl_NNN`) |
| hygprocess | hygiene-process-check | 공정점검표 작성 |

공통 프레임은 `HtmlFormTemplatePage`(좌우 50:50) · `htmlFormTemplateShared.ts`.
좌측 사용여부는 공통코드 `use-yn`(사용/미사용). 표준 `*_000`은 항상 미사용·잠금. 신규는 기본 사용, 수정 가능. 값은 `tbl_company_template.use_yn`이라 문서주기 좌측과 같다.
지면 HTML 은 점검표 `HygPrcPaper`(검증점검은 `CcpChkPaper` re-export) · 일지 `CcpPkgPaper` · `CcpHtgPaper` · `CcpMtlPaper`.
표준은 수정 불가, 자사 양식은 행추가로만 만든다.
