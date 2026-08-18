# com.haccp.sys.screenusage — 화면 이용 통계 (조회)

화면코드 `screen-usage-statistics` · XML `resources/mapper/sys/screenusage/ScreenUsageMapper.xml` · SP `db_sasshaccp/77_migrate_sp_log_screens_v2.sql`

## 엔드포인트

| Method | URL | Service | SP | 테이블 |
|---|---|---|---|---|
| GET | `/api/v1/sys/screen-usage-statistics/list` | `list` | `sp_screen_usage_statistics_r_000` | `tbl_view_stat_daily` `tbl_menu` `tbl_screen` |

조회 전용이다. save·delete 엔드포인트를 만들지 않는다. 기간은 Controller가 `YYYYMMDD`로 정규화한다.

FE: `pages/sys/screenusage/` · 공용 셸 `components/layout/LogPageShell.tsx`
