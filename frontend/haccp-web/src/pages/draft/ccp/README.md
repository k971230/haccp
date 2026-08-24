# CCP 검증점검 양식 작성 (`ccp-verify`)

양식관리 `ccp-verify-template` 에서 **사용여부 = 예**로 둔 자사 양식(`tml_ccp_chk_001` 이상)만 작성한다.

화면·업무 규칙은 전부 공통 `../HtmlFormDraftPage` + `../htmlFormDraftShared` 에 있다.
HYG(`../hyg`)와 형제 화면이며 검색·그리드·팝업·버튼·상태 규칙이 같다.

| 파일 | 역할 |
|---|---|
| `CcpVerifyDraftPage.tsx` | 공통 화면에 상수·지면·API 를 넘기는 래퍼 |
| `CcpVerifyDraftRule.ts` | `SCRN_CD` · `PERSIST_ID` · `SPLIT_KEY` · 양식 접두 · 지면 제목/부제 |

- 지면: `docs/html/ccpverifytemplate/CcpChkPaper` (= `HygPrcPaper` re-export) — 표 HTML 이 HYG 와 같다
- 데이터: **CCP 기존 테이블** `tbl_ccp_verify_check` / `tbl_ccp_verify_item` · SP `sp_ccp_verify_*`
  HYG 테이블을 복제하지 않는다. 지면이 요구하는 칸만 123에서 ALTER 로 더했다
- API: `api/draft/ccpVerifyDraftApi.ts` → `/api/v1/draft/ccp-chk/ccp-verify`

URL 중분류는 `ccp-chk` 다 — `docs` 아래 `ccp` 와 `menu_cd` 가 겹칠 수 없다.

scrnCd `ccp-verify` · DB `123_migrate_ccp_verify_draft.sql`
