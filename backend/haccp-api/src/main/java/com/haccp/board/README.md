# com.haccp.board

정본: FE `pages/board/README.md`. `TaskController` · `CalendarController` · `DailyTaskGenerationJob`. XML `mapper/board/`.

**맡는 것:** 오늘 할 일·알림·일정 캘린더·일일 과제 생성.
**안 맡는 것:** 비밀번호 변경(`com.haccp.auth`), 예정일 생성 알고리즘(`docs.sch.DocCycleService`).

| URL | 무엇 |
|---|---|
| `/api/v1/board/today-tasks/*` | 오늘 할 일 화면. 최근 문서는 JWT `userId` → `writer_id` |
| `/api/v1/board/notifications/*` | 알림 — 화면이 아니라 셸 공용. 권한은 today-tasks |
| `/api/v1/board/calendar/*` | 일정 캘린더. `mine`은 JWT 담당·부서 |

`TaskService.todayTasks()` 는 목록을 읽기 전에 `sp_tbl_schedule_task_generate_c_000` 을 먼저 부른다.
알림은 `docs/sch/DocumentAlarmScheduler` 한 곳에서만 만든다.

캘린더 저장은 `tbl_workday_override` 후 `DocCycleService.regenerateCompany`.

## 변경

- 2026-09-03 — `com.haccp.tsk` 에서 옮기고 일정 캘린더를 붙였다
- 2026-09-03 — 감사자료 `/api/v1/docs/audit-export/*` 를 지웠다. 화면이 없었다
