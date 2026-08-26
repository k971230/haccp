# htmltemplate — HTML 양식 원본

화면 1개 = 패키지 1개. FE `pages/docs/html/htmltemplate/`.

URL `/api/v1/docs/html-form/hyg-process-template/*`
XML `mapper/docs/html/htmltemplate/HtmlTemplateMapper.xml`
scrnCd `hyg-process-template`

예시 `html_hyg_prc_000`(시드 `html_sys_001`, 잠금). 자사 저장은 `html_hyg_prc_001`부터 채번하고 `tbl_html_hyg_prc_ver`에 둔다. 삭제는 `use_yn=N` + 주기 행 정리.
좌 저장이 copy(INSERT)·name(양식명·회사 사용여부)을 호출한다. 표준 `*_000` 사용여부는 항상 N. 적용 라디오는 쓰지 않는다. CCP 검증점검은 `ccp-verify-template` / `tbl_tml_ccp_chk_ver`. 포장일지는 `ccp-pkg-template` / `tbl_tml_ccp_pkg_ver`. 가열일지는 `ccp-htg-template` / `tbl_tml_ccp_htg_ver`. 금속검출일지는 `ccp-mtl-template` / `tbl_tml_ccp_mtl_ver`.
