# docs/html — HTML 양식

| 폴더 | 화면 |
|---|---|
| htmltemplate | 일반위생·공정점검 양식관리 (`tbl_html_hyg_prc_ver`) |
| html/ccpverifytemplate | 중요관리점(CCP) 검증점검표 양식관리 (`tbl_html_ccp_chk_ver`) |
| html/ccppkgtemplate | 중요관리점(CCP-1B) 모니터링일지 양식관리 (`tbl_html_ccp_pkg_ver`) |
| html/ccphtgtemplate | 중요관리점(CCP-2B) 모니터링일지 양식관리 (`tbl_html_ccp_htg_ver`) |
| html/ccpmtltemplate | 중요관리점(CCP-3P) 모니터링일지 양식관리 (`tbl_html_ccp_mtl_ver`) |
| hygprocess | 일반위생관리 및 공정점검표 작성 |

기준관리 API는 `/api/v1/docs/html-form/{scrnCd}` (hyg-process-template · ccp-verify-template · ccp-pkg-template · ccp-htg-template · ccp-mtl-template). 목록·복사는 `p_tmpl_cd`로 가족을 가른다.
