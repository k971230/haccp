# HTML 양식 작성 (`hyg-process` · `ccp-verify`)

URL `/draft/html`. 양식관리에서 **사용여부 = 예**로 둔 자사 HTML 양식을 일자별로 작성한다.
상위 [`../README.md`](../README.md) 에 작성 화면 전체 구성이 있다.

| 화면코드 | 기준 양식관리 | 자사 양식 접두 | 지면 |
|---|---|---|---|
| `hyg-process` | `hyg-process-template` | `html_hyg_prc_` | `docs/html-form/htmltemplate/HygPrcPaper` |
| `ccp-verify` | `ccp-verify-template` | `html_ccp_chk_` | `docs/html-form/ccpverifytemplate/CcpChkPaper` |

| 파일 | 역할 |
|---|---|
| `HygProcessDraftPage.tsx` · `HygProcessDraftRule.ts` | HYG 래퍼 — 상수·지면·API 만 |
| `CcpVerifyDraftPage.tsx` · `CcpVerifyDraftRule.ts` | CCP 검증 래퍼 — 같은 모양 |

두 화면은 **형제**다. 화면·업무 규칙은 전부 공통 `../HtmlFormDraftPage` + `../htmlFormDraftShared`
에 있고, 여기에는 화면 고유값(`SCRN_CD`·`PERSIST_ID`·`SPLIT_KEY`·양식 접두·지면 제목)만 둔다.
래퍼에 레이아웃을 덧붙이면 두 화면 UI 가 갈리므로 금지한다.

## 중분류 슬러그 (2026-08-25 정리)

`draft` 아래 중분류가 `hyg`·`ccp-chk` 두 개였는데 **`html` 하나로 합쳤다**.
`menu_cd` 는 `tbl_menu UNIQUE (co_cd, menu_cd)` 때문에 전 트리에서 유일해야 해서,
docs 쪽이 쓰던 `html` 을 `html-form` 으로 개명하고 이 자리를 비웠다
(`db_sasshaccp/02_seed.sql`).

`scrnCd`·`persistId` 는 그대로다 — 폴더·URL 이 바뀌어도 그 값은 안 바꾼다(`09-haccp-frontend`).
사용자가 저장해 둔 그리드 열 너비가 보존된다.

## 데이터

| 화면 | 테이블 | SP | API |
|---|---|---|---|
| `hyg-process` | `tbl_hyg_process` `_item` | `sp_tbl_hyg_process_*` | `api/draft/hygProcessDraftApi.ts` → `/api/v1/draft/html/hyg-process` |
| `ccp-verify` | `tbl_ccp_verify_check` `tbl_ccp_verify_item` | `sp_tbl_ccp_verify_*` | `api/draft/ccpVerifyDraftApi.ts` → `/api/v1/draft/html/ccp-verify` |

BE 패키지는 둘 다 `com.haccp.draft.html` 이다 — URL 칸과 같다.
