# public/manual

화면별 사용자 매뉴얼 HTML. 빌드가 `dist/manual/` 로 그대로 복사한다.

파일명 = `scrnCd.html` (`today-tasks.html`, `ccp-htg.html`).
주소는 `/haccp/manual/{scrnCd}.html`. 화면 경로(`/draft/ccp-monitoring/ccp-htg`)와 다른 축이다.

## 맡는 것

- 풋터 도움말이 새 탭으로 여는 정적 문서
- 스크린샷은 HTML 안에 들어 있다. 외부 이미지 폴더 없음

## 맡지 않는 것

- `scrnCd` 탭·메뉴·권한·라우트. `tbl_screen` 에 올리지 않는다
- API·SP·백엔드
- `src/pages/` 화면 소스

원본 초안은 저장소 밖 로컬 폴더에 있다 — clone 한 사람에게는 없다. 여기 파일이 배포본이다.

## 역할별 순서

화면별 누르는 순서는 각 `{scrnCd}.html` 이다. 여기는 **누가 무엇을 먼저**만 적는다.

| 누가 | 순서 |
|---|---|
| 관리자 (처음 한 번) | 부서 → 사용자 → 권한 → 결재선 → 양식 → 주기 |
| 팀원 (매일) | 오늘 할 일 → 작성 → 전송 |
| 팀장 | 결재대기 → 승인 → 문서함 |
