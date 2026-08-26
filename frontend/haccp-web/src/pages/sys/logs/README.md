# pages/sys/logs — 이력·통계

URL `/sys/logs`. 조회 전용 3화면. 셋 다 `LogPageShell` 을 공유한다 (좌 트리 + 우 목록).

| 하위 | 화면 | 표 |
|---|---|---|
| [`loginhistory/`](loginhistory/README.md) | `login-history` | `tbl_login_log` |
| [`screenusage/`](screenusage/README.md) | `screen-usage-statistics` | `tbl_view_log` · `tbl_view_stat_daily` |
| [`auditlog/`](auditlog/README.md) | `audit-log` | `tbl_audit_log` |

## 이 표들을 지우지 않는 이유

셋 다 `scrn_cd` 를 참조한다. 2026-08-25 화면 정리에서 빠진 화면도 `tbl_screen` 을 지우지 않고
`use_yn='N'` 으로만 둔 것은 여기 쌓인 이력이 고아가 되지 않게 하려는 것이다.

감사 로그는 **고쳐 쓰지 않는다.** 코드 표기를 바꾸더라도 이미 쌓인 행은 그대로 둔다.
