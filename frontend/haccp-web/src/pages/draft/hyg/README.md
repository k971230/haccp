# HYG 위생공정 양식 작성 (`hyg-process`)

양식관리 `hyg-process-template` 에서 **사용여부 = 예**로 둔 자사 양식(`html_hyg_prc_001` 이상)만 작성한다.

화면·업무 규칙은 전부 공통 `../HtmlFormDraftPage` + `../htmlFormDraftShared` 에 있다.
이 폴더에는 이 화면 고유값만 둔다 — CCP(`../ccp`)와 UI 가 갈리지 않게 레이아웃을 덧붙이지 않는다.

| 파일 | 역할 |
|---|---|
| `HygProcessDraftPage.tsx` | 공통 화면에 상수·지면·API 를 넘기는 래퍼 |
| `HygProcessDraftRule.ts` | `SCRN_CD` · `PERSIST_ID` · `SPLIT_KEY` · 양식 접두 · 지면 제목/부제 |

- 지면: `docs/html/htmltemplate/HygPrcPaper` — 양식관리와 같은 HTML
- 데이터: `tbl_hyg_process` / `_item` · SP `sp_tbl_hyg_process_*`
- API: `api/draft/hygProcessDraftApi.ts` → `/api/v1/draft/hyg/hyg-process`

scrnCd `hyg-process` · DB `121_migrate_hyg_process_draft.sql` · `122_migrate_hyg_process_draft_search.sql`
