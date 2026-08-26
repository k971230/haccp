# HTML양식 원본 (`hyg-process-template`)

일반위생관리 및 공정점검표 기준관리. 사용양식 관리와 같이 검색 헤더 + 왼쪽 양식 그리드 + 오른쪽 지면.

- 검색: 양식코드·양식명. 입력 즉시 목록 필터. 조회는 서버 LIKE.
- 좌측 버튼: 행추가 · 삭제 · 저장. 행추가는 표준(`html_hyg_prc_000`) 복사 pending. 좌 저장이 `copy` INSERT·양식명·사용여부 `name`.
- 좌우 50:50 프레임(`HtmlFormTemplatePage`). 지면은 `HygPrcPaper`. 검증점검 `CcpChkPaper` 도 이 파일을 쓴다.
- 표준(`html_hyg_prc_000`)은 수정·삭제 불가. 사용여부는 항상 미사용. 자사는 행추가로만 만들고 기본 사용.
- 자사 저장은 `html_hyg_prc_001`부터 채번, 테이블 `tbl_html_hyg_prc_ver`. 문서주기 좌측에 오른다.
- 우측 수정은 저장한 자사 양식만. 제목·부제·항목 PUT은 좌 저장과 분리. 입력유형 열은 표 안에 두고 삭제도 같은 행에 둔다.

scrnCd `hyg-process-template` · API `/api/v1/docs/html-form/hyg-process-template`

지면: `HygPrcPaper.tsx` (이 폴더). 작성 화면 `hygprocess` 가 같은 파일을 쓴다.
