# draft — 양식 작성 대분류

URL `/draft`. 사용 중인 양식을 골라 일자별 작성 문서를 만드는 화면 묶음이다.
HYG·CCP 는 형제 화면이며 업무 규칙·상태·버튼이 같다.

```
draft/
 ├ hyg/    HYG 양식 — hyg-process  (html_hyg_prc_NNN · tbl_hyg_process)
 └ ccp/    CCP 양식 — ccp-verify   (tml_ccp_chk_NNN · tbl_ccp_verify_check)
```

| 화면 | URL 중분류 | 자바 패키지 | 기준 양식관리 |
|---|---|---|---|
| `hyg-process` | `hyg` | `com.haccp.draft.hyg` | `hyg-process-template` |
| `ccp-verify` | `ccp-chk` | `com.haccp.draft.ccp` | `ccp-verify-template` |

중분류 `menu_cd` 는 `tbl_menu UNIQUE (co_cd, menu_cd)` 때문에 전 트리에서 유일해야 한다.
`docs` 아래 `html`·`ccp` 가 이미 있어 이 대분류는 `hyg`·`ccp-chk` 를 쓴다.
자바 패키지는 하이픈을 못 쓰므로 `ccp-chk` → `ccp` 로 둔다.

두 화면은 UI 를 공유하지만(`FE pages/draft/HtmlFormDraftPage`) 테이블·SP 는 각자 것을 쓴다.
