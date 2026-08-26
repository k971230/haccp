# 중요관리점(CCP-2B) 모니터링일지 (`ccp-htg-template`)

HTML양식 원본 하위. 좌우 50:50 프레임. 지면은 `CcpHtgPaper` 전용 HTML.

- 검색: 양식코드·양식명. 입력 즉시 목록 필터. 조회는 서버 LIKE.
- 좌측 버튼: 행추가 · 삭제 · 저장. 행추가는 표준(`tml_ccp_htg_000`) 복사 pending. 좌 저장이 `copy` INSERT·양식명 `name`.
- 표준(`tml_ccp_htg_000`)은 `tbl_check_item` 가상행(한계기준 2 · 주기 · 방법 · 개선조치). 양식명·항목 수정·삭제 불가.
- 자사 저장은 `tml_ccp_htg_001`부터 채번, 테이블 `tbl_tml_ccp_htg_ver`. 문서주기 좌측에 오른다.
- 우측 수정은 저장한 자사 양식만. 한계기준 항목명·값과 기록 표 열 제목(가열온도·가열시간)을 같이 고친다. 작성 화면은 후속. 기존 `ccp-heat-monitor` 와 섞지 않는다. 미리보기 기록은 작업 전·빈행·작업 종료·빈행 4행, 칸은 비움. 판정은 적합/부적합 반 가름. 작성 `mode=write` 에서 중간 행 추가.

scrnCd `ccp-htg-template` · API `/api/v1/docs/html-form/ccp-htg-template`

지면: `CcpHtgPaper.tsx` (이 폴더).
