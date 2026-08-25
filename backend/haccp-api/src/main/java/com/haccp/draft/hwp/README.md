# `com.haccp.draft.hwp` — HWP 양식 작성

경로 `/api/v1/draft/hwp-doc/hwp-write` — FE `SCREEN_PATH` 와 같은 칸.

## 파일

| 파일 | 책임 |
|---|---|
| `HwpDraftController` | 경로·요청 검증. 계약은 HTML 작성 5화면과 같고 `tasks` 하나만 더 있다 |
| `HwpDraftService` | 이 화면 고유 조회 3개. 저장·상세·삭제는 문서 허브에 위임 |
| `HwpDraftMapper` (+ `mapper/draft/hwp/HwpDraftMapper.xml`) | 조회 SP 바인딩 |

## 문서 허브에 위임하는 이유

저장·상세·삭제를 여기서 다시 구현하지 않는다. `DocumentService` 의
`saveHwpDocument` · `detail` · `validateDelete` · `delete` 를 그대로 부른다.

기존 HWP 편집 화면(`/docs/**/*-hwp` 20여 개)이 같은 메서드를 쓴다.
두 화면이 **같은 경로를 타야** 한쪽에서 만든 문서를 다른 쪽에서 열었을 때 결과가 어긋나지 않는다.
새 저장 SP·새 삭제 SP 를 만들면 그 순간 두 화면이 갈라진다.

## 이 화면 고유 조회 3개

| 메서드 | SP | 왜 따로 두는가 |
|---|---|---|
| `forms()` | `sp_tbl_document_template_r_000` 을 감싸 `doc_kind='hwp'` 만 | 사용양식 관리와 같은 목록이라 SP 를 새로 만들지 않는다 |
| `list(...)` | `sp_draft_hwp_r_000` | 작성 화면 6조건 검색 계약 — 문서함 SP 는 양식명·작성자명 부분검색이 없다 |
| `tasks(baseDt)` | `sp_draft_hwp_task_r_000` | 오늘 할일 SP 는 `tmpl_cd` 를 안 주고 개선조치(CA)까지 섞어 준다 |

## 삭제 (OPS_DELETE)

HTTP `DELETE` 를 쓰지 않는다. `POST validate-delete` → `POST delete` 두 단계다.
두 단계 모두 `DocumentService` 가 같은 검사를 한다 (Double Check).
`doc_kind <> 'hwp'` 문서는 SP 가 거부한다 — 이 화면으로 HTML 문서를 지울 수 없다.

## 본문 파일

이 서비스를 거치지 않는다. 문서 파일 업로드 API
`POST /api/v1/docs/documents/{docIdx}/files` (`fileKind=HWP_SRC`) 가 받는다.

경로·파일명 규칙은 `DocumentFileStorage` 가 정한다 —
`{coCd}/{tmplCd}/{YYYY-MM-DD}/{YYYY-MM-DD}_{원본명}_{연번}.{확장자}`.

## 전송·전송취소

여기 없다. 문서 허브 `POST /api/v1/docs/documents/approval`
(`processDocumentApproval(REQUEST | CANCEL)`) 공용이다.

## 연관

- DTO — `com.haccp.draft.dto` (5화면 공용). 이 패키지에 DTO 를 다시 만들지 않는다
- 공용 유틸 — `com.haccp.draft.DraftSupport`
- DB — `db_sasshaccp/01_sp.sql`
