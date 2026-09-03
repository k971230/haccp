# com.haccp.draft.html — HTML 작성 2화면 (일반위생·공정점검 / CCP 검증점검)

| 화면 | scrnCd | URL | 자사 양식 |
|---|---|---|---|
| 일반위생·공정점검 작성 | `hyg-process` | `/api/v1/draft/html/hyg-process/*` | `html_hyg_prc_001` 이상 |
| CCP 검증점검표 작성 | `ccp-verify` | `/api/v1/draft/html/ccp-verify/*` | `html_ccp_chk_001` 이상 |

둘 다 **사용여부 Y 인 자사 양식만** 작성 대상이다. 표준 예시(`*_000`)는 가상행이라 목록에서 뺀다.

중분류 슬러그는 `ccp-chk` 다 — `tbl_menu UNIQUE (co_cd, menu_cd)` 때문에 `docs` 아래 `ccp` 와 겹칠 수 없다.
자바 패키지는 `com.haccp.draft.html` — FE SCREEN_PATH `/draft/html` 과 같은 칸이다.

## 파일

| 파일 | 역할 |
|---|---|
| `HtmlDraftControllerBase.java` | 엔드포인트 6개 — 두 화면이 글자까지 같다 |
| `HygProcessDraftController.java` · `CcpVerifyDraftController.java` | URL 과 양식군(Family)만 선언하는 껍데기 |
| `HtmlDraftService.java` | 업무 전부 + `Family` (HYG·CHK) |
| `HtmlDraftMapper.java` · `mapper/draft/html/HtmlDraftMapper.xml` | family 로 SP 를 고른다 |

**2026-09-03 에 합쳤다.** 그 전에는 화면마다 Service·Mapper·Controller 를 따로 뒀는데,
이름을 치환하면 Service 224줄 중 17줄, Controller 146줄 중 15줄, Mapper 161줄 중 20줄만 달랐다 —
그 차이도 주석과 상수 둘(`STD_TMPL_CD`·`USR_TMPL_PREFIX`)뿐이었다.
복제해 두면 한 곳을 고칠 때 다른 하나가 조용히 어긋난다. 실제로 제목(`title`) 인자를 넣을 때
같은 수정을 두 번 해야 했다. 포장·가열의 `CcpLogDraftControllerBase` 가 먼저 쓴 방식을 그대로 따랐다.

## 계열별로 다른 것 — SP 이름뿐이다

| | 일반위생·공정점검 (`hyg`) | CCP 검증점검 (`chk`) |
|---|---|---|
| 양식 버전 | `sp_tbl_html_hyg_prc_ver_r_000` | `sp_tbl_html_ccp_chk_ver_r_000` |
| 목록·상세·저장·삭제·서명 | `sp_tbl_hyg_process_*` | `sp_ccp_verify_*` |
| 표 | `tbl_html_hyg_prc_*` | `tbl_ccp_verify_check` / `_item` |

**목록 SP 만 인자 형태가 다르다** — `sp_tbl_hyg_process_r_000` 은 10개(문서번호·통합작성자 자리에 빈값을 넘긴다),
`sp_ccp_verify_r_000` 은 8개다. 그 차이는 XML `<choose>` 안에만 둔다.
CCP 쪽 `sp_tbl_ccp_form_*` 은 `html_sys_006`·`hwp_sys_003` 전용이라 여기서 부르지 않는다.

## 여기 없는 것

전송(REQUEST)·전송취소(CANCEL)는 이 패키지에 없다. 문서 허브 `PUT /api/v1/docs/documents/approval` 을 그대로 쓴다.
상태 3단계: 전송대기 `WRK`·`RJT` / 전송 `REQ`·`REV` / 결재완료 `APV`.

저장은 전송 전이라 **필수값을 보지 않는다.** 필수값은 전송 직전에 화면이 검사한다
(FE `htmlFormDraftShared.validateForTransfer` 한 곳).

## 새 계열을 더할 때

1. `HtmlDraftService.Family` 에 한 줄 (`key`·`prefix`·`std`)
2. `HtmlDraftMapper.xml` 의 `<choose>` 에 가지 하나
3. 컨트롤러 하나 — URL 과 `family()` 만
