# HWP 양식 작성 (`hwp-write`)

사용양식 관리 `hwp-template-management` 에서 **사용여부 = 예**로 둔 HWP 양식만 작성한다.

좌측 업무(검색·체크박스·행 추가·양식 팝업·저장·전송·모두 전송·삭제·전송취소·결재 여부)는
전부 공통 `../HtmlFormDraftPage` + `../htmlFormDraftShared` 다.
HYG·CCP검증·CCP모니터링과 **같은 화면**이며, 이 폴더는 우측을 rhwp 로 바꾸는 일만 한다.

## 파일

| 파일 | 책임 |
|---|---|
| `HwpDraftPage.tsx` | 공통 화면에 주입점 3개를 넘긴다 — 오늘 할일 팝업 · 본문 업로드 · 우측 렌더 |
| `HwpEditorPane.tsx` | rhwp 편집기 생성과 문서 열기. **여는 일은 반드시 useEffect** |
| `HwpDraftRule.ts` | `SCRN_CD` · `PERSIST_ID` · `SPLIT_KEY` · 지면 문구 · 본문 파일 종류 |

## 다른 작성 화면과 다른 점

| | HTML 작성 5화면 | HWP 작성 |
|---|---|---|
| 우측 | `PaperComponent` (지면) | `renderDetail` → rhwp 편집기 |
| 본문 저장 | 저장 API 한 번 | 저장 API + 첨부 업로드(`afterSave`) |
| 행 추가 | 바로 양식 선택 팝업 | 오늘 할일 팝업 → 취소하면 양식 선택 팝업 |
| 지면 항목·기록 표 | 있음 | 없음 (`items`·`logRows` 항상 빈 배열) |

## 본문 파일

본문은 문서 첨부 `file_kind = HWP_SRC` 로 오간다.

- **열기** — 첨부 중 가장 나중 `HWP_SRC` 를 내려받아 편집기에 싣는다. 없으면 양식 원본을 연다
- **저장** — 좌측·우측 저장이 끝나면 `afterSave` 가 `exportHwpx()` 결과를 올린다
- **파일명** — `{YYYY-MM-DD}_{양식명}_{연번}.hwpx` (연번은 서버가 다시 매긴다)

첨부 식별자는 서버가 주는 이름 `idx` 를 그대로 쓴다. `fileIdx` 로 바꿔 부르지 않는다.

## 문서를 여는 규칙

`HwpEditorPane` 의 `useEffect` 안에서만 연다. **렌더 중에 부르면 안 된다** —
실패할 때마다 다시 렌더되어 같은 요청이 끝없이 나간다 (2026-08-25 문서 열기 폭주의 원인).

대상 표식(`문서idx:양식코드:첨부idx`)을 요청 **전에** 남긴다. 실패해도 같은 대상을 다시 부르지 않고,
저장으로 첨부가 바뀌면 표식이 달라져 다시 연다.

## pref 키

`persistId = hwp-draft-list` · 분할 `haccp-split-hwp-draft-50` — 값 변경 금지.

## 연관

- 서버 — `com.haccp.draft.hwp` (저장·상세·삭제는 문서 허브 `DocumentService` 위임)
- DB — `db_sasshaccp/125_migrate_hwp_draft.sql`
- 양식 파일 — 사용양식 관리 `/docs/hwp/hwp-template-management`
