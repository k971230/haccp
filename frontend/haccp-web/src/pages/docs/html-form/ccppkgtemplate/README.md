# 중요관리점(CCP-1B) 모니터링일지 (`ccp-pkg-template`)

HTML양식 원본 하위. 좌우 50:50 프레임. 지면은 `CcpPkgPaper` 전용 HTML.

- 검색: 양식코드·양식명. 입력 즉시 목록 필터. 조회는 서버 LIKE.
- 좌측 버튼: 행추가 · 삭제 · 저장. 행추가는 표준(`html_ccp_pkg_000`) 복사 pending. 좌 저장이 `copy` INSERT·양식명 `name`.
- 표준(`html_ccp_pkg_000`)은 `tbl_check_item` 가상행(한계기준 2 · 주기 · 방법 · 개선조치). 양식명·항목 수정·삭제 불가.
- 자사 저장은 `html_ccp_pkg_001`부터 채번, 테이블 `tbl_html_ccp_pkg_ver`. 문서주기 좌측에 오른다.
- 우측 수정은 저장한 자사 양식만. 한계기준 항목명·값(cycleNm·itemNm)을 같이 고친다. 작성 화면은 후속. 미리보기 기록은 작업 전·빈행·작업 종료·빈행 4행, 측정시각·온도는 빈칸. 판정은 적합/부적합 반 가름. 작성 `mode=write` 에서 중간 행 추가.

scrnCd `ccp-pkg-template` · API `/api/v1/docs/html-form/ccp-pkg-template`

지면: `CcpPkgPaper.tsx` (이 폴더).
