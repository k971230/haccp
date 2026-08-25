# ccp — CCP 검증점검 양식 작성

화면 1개 = 패키지 1개. FE `pages/draft/ccp/`. HYG(`draft.hyg`)와 형제 화면이다.

URL `/api/v1/draft/ccp-chk/ccp-verify/*`
XML `mapper/draft/ccp/CcpVerifyDraftMapper.xml`
scrnCd `ccp-verify` · 양식 `tml_ccp_chk_001` 이상(사용여부 Y 자사 양식만)

중분류 슬러그는 `ccp-chk` 다 — `tbl_menu UNIQUE (co_cd, menu_cd)` 때문에 `docs` 아래 `ccp` 와 겹칠 수 없다.
자바 패키지는 하이픈을 못 쓰므로 `com.haccp.draft.ccp` 로 둔다(`docs.ccp` 와는 다른 네임스페이스다).

## 데이터

CCP 기존 테이블 `tbl_ccp_verify_check` / `tbl_ccp_verify_item` 을 그대로 쓴다. HYG 테이블을 복제하지 않는다.
지면이 요구하는 칸(`ver_no`·승인자·확인·서명·하단 4열, 항목 `cycle_nm`·`input_type`·`unit_nm`)만 123에서 ALTER 로 더했다.

작성 SP 는 이 화면 전용 `sp_ccp_verify_r_000/r_001/c_000/d_000` + `sp_ccp_verify_sign_u_000` 이다.
기존 `sp_tbl_ccp_form_*` 은 `html_sys_006`·`hwp_sys_003` 전용이라 건드리지 않는다.

전송(REQUEST)·전송취소(CANCEL)는 여기 없다. 문서 허브 `PUT /api/v1/docs/documents/approval` 을 그대로 쓴다.
상태 3단계: 전송대기 `WRK`·`RJT` / 전송 `REQ`·`REV` / 결재완료 `APV`.
