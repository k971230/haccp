# 화면 이용 통계 (`screen-usage-statistics`)

정본 파이프라인 요약은 상위 [`pages/sys/README.md`](../../README.md) 6장.

## 파일

| 파일 | 책임 |
|---|---|
| `ScreenUsageStatisticsPage.tsx` | `LogPageShell`에 Rule만 꽂는 얇은 진입점. `key={scrnCd}` |
| `ScreenUsageStatisticsRule.ts` | `scrnCd` · `persistId` · 컬럼 · `fetchRows`(리프 서버 필터, 폴더 FE 필터) |

공용 셸은 [`LogPageShell`](../../../components/layout/LogPageShell.tsx)다. 조회 전용이라 행추가·저장·삭제를 붙이지 않는다.

`scrnCd = screen-usage-statistics` · `persistId = log-screen-usage-statistics` — 값 변경 금지.

## API · SP · 테이블

| 동작 | API (`api/sys/screenUsageApi.ts`) | SP | 테이블 |
|---|---|---|---|
| 조회 | `listScreenUsage` | `sp_screen_usage_statistics_r_000` | `tbl_view_stat_daily` `tbl_menu` `tbl_screen` |
| 좌측 메뉴 트리 | `menuApi.listAdminMenus` | `sp_menu_management_r_000` | `tbl_menu` `tbl_screen` |

집계 배치 전이면 당일 값이 비어 있을 수 있다.
