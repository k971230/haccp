# com.haccp.tsk

정본: FE `pages/tsk/README.md`. `TaskController` · `DailyTaskGenerationJob`. XML `mapper/tsk/`.

맡는 URL

| URL | 무엇 |
|---|---|
| `/api/v1/tsk/today-tasks/*` | 오늘 할 일 화면 |
| `/api/v1/tsk/notifications/*` | 알림 — 화면이 아니라 셸 공용 |

## 조회가 쓰기를 한다 — 알아 두고 만져야 한다

`TaskService.todayTasks()` 는 목록을 읽기 전에 `sp_tbl_schedule_task_generate_c_000` 을 먼저 부른다.
**화면을 열 때마다 과제 생성·지연 판정이 돈다.** 배치(`DailyTaskGenerationJob`, 00:05)가 실패한 날에도
화면이 과제를 메워 주라고 그렇게 뒀다.

그래서 그 SP 에 무엇을 넣느냐가 중요하다. **알림은 넣지 않는다** —
넣던 시절에는 사람이 「오늘 할 일」을 열 때마다 알림이 생겼다.
알림은 `docs/sch/DocumentAlarmScheduler` 한 곳에서만 만든다 (`docs/sch/README.md`).

`/api/v1/tsk/notifications/*` 는 살아 있지만 **부르는 화면이 아직 없다.** 알림함 화면은 미구현이다.

## 변경

- 2026-09-03 — 감사자료 `/api/v1/docs/audit-export/*` 를 지웠다. 화면이 없었다
- 2026-08-28 — 일일 배치 SP 에서 알림 INSERT 를 걷어냈다.
  지연분이 날마다 다시 쌓였고, 한 문장이 중복 행을 넣었고, 화면 조회가 그걸 유발했다
- 2026-08-26 — 개선조치관리 화면 API 를 `flow/ca` 로 내보냈다.
  URL 이 `/flow/ca/...` 인데 여기 있어서 패키지 규칙이 깨져 있었다
