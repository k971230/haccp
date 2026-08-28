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
- DB — `db_sasshaccp/01_sp.sql`
- 양식 파일 — 사용양식 관리 `/docs/hwp/hwp-template-management`

## 이탈여부 (목록 칸)

우측이 rhwp 편집기라 HTML 5화면처럼 **지면 하단에 이탈 시그널을 둘 자리가 없다**.
그래서 좌측 목록에 「이탈여부」 체크 칸을 두고 거기서 켠다 — 뜻은 지면 시그널과 같다.

- 켜고 저장하면 개선조치 행이 생기고 **이탈·개선조치 화면(`/flow/ca`)** 목록에 올라온다.
  실제 조치 내용은 거기서 적는다 — 이 화면은 「이탈이 있었다」만 표시한다
- 끄면 개선조치 행을 지운다. 단 **이미 조치를 적어 둔 건은 지우지 않는다**
  (`HwpDraftService.applyDeviation`) — 다른 화면에서 쓴 내용이 사라지면 안 된다
- 전송 이후 행은 `htmlFormDraftGridRules.isRowEditLocked` 가 행 전체를 잠근다

칸 노출은 `HtmlFormDraftPage` 의 `showDeviationColumn` 하나로 켠다.
HTML 5화면은 켜지 않는다 — 지면 시그널과 두 곳에 두면 값이 갈린다.

목록 SP 의 `deviation_yn` 은 완료 여부와 무관하게 개선조치가 붙어 있으면 Y 다
(`db_sasshaccp/01_sp.sql`). 미완료 수(`ng_cnt`)와 다른 축이다.

## 편집기 (`HwpEditorPane`)

### 도구상자는 접지 않는다

이 화면은 사람이 한글 문서를 **직접 고치는** 곳이다. 글꼴·표·정렬을 못 쓰면 일지를 채울 수 없다.
`foldRhwpToolboxes` 는 **미리보기 화면(사용양식관리)에서만** 쓴다 — 거기는 고칠 일이 없다.

### 늦게 온 응답이 화면을 덮지 않게 한다

HWP 는 내려받기와 `loadFile` 이 둘 다 느리다. 목록에서 문서를 빠르게 바꾸면
먼저 시작한 A 가 나중에 끝나 B 위에 A 가 실린다.

두 곳에서 막는다.

| 어디 | 무엇 |
|---|---|
| `HwpEditorPane` | `await` 마다 「이 로드가 아직 내 것인가」를 본다. 아니면 조용히 그만둔다 |
| `HtmlFormDraftPage.handleSelect` | 문서를 바꾸는 **즉시** 첨부를 비우고, 늦게 온 상세는 순번으로 버린다 |

두 번째가 더 중요하다. `docIdx` 는 바로 바뀌는데 첨부는 상세 응답이 와야 바뀌어서,
그 틈에 편집기가 **「새 문서 + 앞 문서 첨부」**를 보고 앞 문서 본문을 열었다.
실제로 843 자리에 844 본문이 실리는 것을 재현했다.

여는 동안에는 상태줄이 「문서를 여는 중입니다…」로 바뀐다 —
앞 문서 이름이 남아 있으면 그것만으로도 다른 파일이 열린 것처럼 보인다.
