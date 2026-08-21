# tsk 파이프라인 (FE + BE + DB)

오늘 할 일. **평탄.** 화면 1개.

| scrnCd | Page | API | Controller | persistId |
|--------|------|-----|------------|-----------|
| `today-tasks` | `TodayTasksPage.tsx` | `api/taskWorkflowApi.ts` | `TaskController` `/api/v1/tsk/...` | `tsk-today-tasks` · `tsk-today-recent-docs` |

경로 예: `GET /api/v1/tsk/today-tasks/list` · 알림 `.../notifications/list`. 과제 생성은 `DailyTaskGenerationJob`.

라우트: `/today-tasks`. 홈 `/` → HomeView가 여기로 보낸다. 탭 첫 칸 고정 아님.

개선조치 화면은 [`pages/docs/corrective/`](../docs/corrective/README.md) (`taskWorkflowApi` 공유 가능).
