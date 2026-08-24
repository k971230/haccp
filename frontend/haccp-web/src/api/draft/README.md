# api/draft

`pages/draft/**` 양식 작성 화면 전용 API.

| 파일 | 화면 | 베이스 |
|---|---|---|
| `htmlFormDraftTypes.ts` | 공통 | 행·요청 타입 + `HtmlFormDraftApi` 계약 (HYG·CCP 공유) |
| `hygProcessDraftApi.ts` | `hyg-process` | `apiOf("hyg-process")` = `/api/v1/draft/hyg/hyg-process` |
| `ccpVerifyDraftApi.ts` | `ccp-verify` | `apiOf("ccp-verify")` = `/api/v1/draft/ccp-chk/ccp-verify` |

두 파일은 같은 6개 함수(`listForms`·`list`·`detail`·`save`·`validateDelete`·`remove`)를 구현하고
`HtmlFormDraftApi` 묶음으로 export 한다. 공통 화면은 이 묶음만 보고 어느 쪽인지 모른다.

전송·전송취소는 여기 없다 — 문서 허브 `api/documentApi.processDocumentApproval` 을 쓴다.
