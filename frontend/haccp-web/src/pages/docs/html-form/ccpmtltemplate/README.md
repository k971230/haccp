# 중요관리점(CCP-3P) 모니터링일지 (`ccp-mtl-template`)

HTML양식 원본 하위. 좌우 50:50 프레임. 지면은 `CcpMtlPaper` 전용 HTML.

- 검색: 양식코드·양식명. 입력 즉시 목록 필터. 조회는 서버 LIKE.
- 좌측 버튼: 행추가 · 삭제 · 저장. 행추가는 표준(`html_ccp_mtl_000`) 복사 pending. 좌 저장이 `copy` INSERT·양식명 `name`.
- 표준(`html_ccp_mtl_000`)은 `tbl_check_item` 가상행(한계기준 1 · 주기 4줄 · 방법 · 감도열 5 · 개선조치). 양식명·항목 수정·삭제 불가.
- 자사 저장은 `html_ccp_mtl_001`부터 채번, 테이블 `tbl_html_ccp_mtl_ver`. 문서주기 좌측에 오른다.
- 우측 수정은 저장한 자사 양식만. 한계기준(금속이물)·주기·방법·감도열을 고친다. 작성 화면은 후속. 기존 `ccp-metal-monitor` 와 섞지 않는다. 미리보기 감도는 작업 전·빈행·작업 후·빈행 4행. 감도열 헤더는 통과시간과 같은 높이(2행 병합). 판정만 적합/부적합 2행. 해당 없음은 수정 때 감도열 헤더 안. 작성 `mode=write` 에서 중간 행 추가. 감도표-통과량표 사이 한 칸(`hdr-gap-cap`)에 통과량 제목 `금속검출기 제품 통과`. 통과량 표 caption 은 없다.

scrnCd `ccp-mtl-template` · API `/api/v1/docs/html-form/ccp-mtl-template`

지면: `CcpMtlPaper.tsx` (이 폴더).
