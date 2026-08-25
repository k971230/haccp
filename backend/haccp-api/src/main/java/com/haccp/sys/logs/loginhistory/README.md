# com.haccp.sys.logs.loginhistory — 로그인 이력 (조회)

화면코드 `login-history` · XML `resources/mapper/sys/logs/loginhistory/LoginHistoryMapper.xml` · SP `db_sasshaccp/01_sp.sql`

## 엔드포인트

| Method | URL | Service | SP | 테이블 |
|---|---|---|---|---|
| GET | `/api/v1/sys/logs/login-history/list` | `list` | `sp_login_history_r_000` | `tbl_login_log` `tbl_user` |

조회 전용이다. save·delete 엔드포인트를 만들지 않는다. 기간은 Controller가 `YYYYMMDD`로 정규화한다.

FE: `pages/sys/loginhistory/` · 공용 셸 `components/layout/LogPageShell.tsx`
