# draft — 양식 작성 대분류

URL `/draft`. 사용 중인 양식을 골라 일자별 작성 문서를 만드는 화면 묶음이다.
HYG·CCP 는 형제 화면이며 업무 규칙·상태·버튼이 같다.

```
draft/
 ├ html/           HTML 작성 2화면   — URL 중분류 html
 ├ ccpmonitoring/  CCP 모니터링 3화면 — URL 중분류 ccp-monitoring
 ├ hwpdoc/         HWP 작성 1화면    — URL 중분류 hwp-doc
 └ dto/            6화면 공용 DTO — 여기에 컨트롤러를 두지 않는다
```

| 화면(`scrnCd`) | URL 중분류 (`menu_cd`) | 자바 패키지 | 기준 양식관리 |
|---|---|---|---|
| `hyg-process` | `html` | `com.haccp.draft.html` | `hyg-process-template` |
| `ccp-verify` | `html` | `com.haccp.draft.html` | `ccp-verify-template` |
| `ccp-pkg` | `ccp-monitoring` | `com.haccp.draft.ccpmonitoring` | `ccp-pkg-template` |
| `ccp-htg` | `ccp-monitoring` | `com.haccp.draft.ccpmonitoring` | `ccp-htg-template` |
| `ccp-mtl` | `ccp-monitoring` | `com.haccp.draft.ccpmonitoring` | `ccp-mtl-template` |
| `hwp-write` | `hwp-doc` | `com.haccp.draft.hwpdoc` | `hwp-template-management` |

중분류 `menu_cd` 는 `tbl_menu UNIQUE (co_cd, menu_cd)` 때문에 전 트리에서 유일해야 한다.
2026-08-25 에 `docs` 쪽을 `html-form` 으로 개명해 **이 대분류가 `html` 을 가져갔다**.
자바 패키지는 하이픈을 못 쓰므로 `ccp-monitoring` → `ccpmonitoring`, `hwp-doc` → `hwpdoc` 으로 둔다.

두 화면은 UI 를 공유하지만(`FE pages/draft/HtmlFormDraftPage`) 테이블·SP 는 각자 것을 쓴다.
