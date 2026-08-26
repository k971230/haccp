# com.haccp.sys.logs — 이력·통계

조회 전용 3화면. 쓰기 API 가 없다 — 이력은 다른 경로가 쌓는다.

| 하위 | 화면 | 쌓는 쪽 |
|---|---|---|
| [`loginhistory/`](loginhistory/README.md) | `login-history` | `AuthService` 로그인 성공·실패·잠금 |
| [`screenusage/`](screenusage/README.md) | `screen-usage-statistics` | `ViewLogController` + 일 집계 배치 |
| [`auditlog/`](auditlog/README.md) | `audit-log` | 각 Service 의 `audit(...)` 호출 |

## 감사 로그는 고쳐 쓰지 않는다

`tbl_audit_log` 는 append-only 로 다룬다. 코드 표기·표 이름이 바뀌어도 이미 쌓인 행은 그대로 둔다.
그래서 화면 정리에서 빠진 화면도 `tbl_screen` 을 지우지 않고 `use_yn='N'` 으로만 둔다.
