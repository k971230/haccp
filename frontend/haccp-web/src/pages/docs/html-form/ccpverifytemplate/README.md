# 중요관리점(CCP) 검증점검표 (`ccp-verify-template`)

- 좌우 50:50 프레임(`HtmlFormTemplatePage`). 지면은 `CcpChkPaper` → `HygPrcPaper` 동일 HTML.
- 검색: 양식코드·양식명. 입력 즉시 목록 필터. 조회는 서버 LIKE.
- 좌측 버튼: 행추가 · 삭제 · 저장. 행추가는 표준(`html_ccp_chk_000`) 복사 pending. 좌 저장이 `copy` INSERT·양식명 `name`.
- 표준(`html_ccp_chk_000`)은 `tbl_check_item` 가상행(12 radio + 6 text). 라디오 전용은 값 칸이 비고, 문자·숫자는 빨간 테두리(공정점검과 같음). 카탈로그 원본은 `html_sys_006`. 양식명·항목 수정·삭제 불가.
- 자사 저장은 `html_ccp_chk_001`부터 채번, 테이블 `tbl_html_ccp_chk_ver`. 문서주기 좌측에 오른다.
- 우측 수정은 저장한 자사 양식만. 작성 화면(`ccp-verification-check`) 연동은 후속.

scrnCd `ccp-verify-template` · API `/api/v1/docs/html-form/ccp-verify-template`

지면: `CcpChkPaper.tsx` (이 폴더, `HygPrcPaper` re-export).
