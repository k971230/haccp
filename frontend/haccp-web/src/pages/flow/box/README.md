# pages/flow/box — 문서함

URL `/flow/box`. 결재까지 끝난 문서를 모아 보는 보관함이다.

| 하위 | 화면 |
|---|---|
| [`documentbox/`](documentbox/README.md) | `document-inbox` — 결재 완료 문서 조회 전용 |

`DocumentBoxPage` 하나가 `mode` 로 세 화면을 그린다 — 문서함(`inbox`)·결재 대기(`approval`)·결재 완료(`history`).
결재 2화면의 업무 규칙은 [`../appr/README.md`](../appr/README.md) 가 정본이다.

목록 API: inbox `GET /list?status=APV` · 대기 `GET /sign-ready` · 완료 `GET /sign-ok`.
검색 칸은 세 화면 모두 `keyword`(문서번호)·`writerId`(작성자)로 나눈다.
