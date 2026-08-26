# tsk 파이프라인 (FE + BE + DB)

오늘 할 일. 화면 1개. Page + Rule.

| scrnCd | Page | Rule | API | Controller | persistId |
|--------|------|------|-----|------------|-----------|
| `today-tasks` | `TodayTasksPage.tsx` | `TodayTasksRule.ts` | `api/taskWorkflowApi.ts` | `TaskController` `/api/v1/tsk/...` | `tsk-today-tasks` · `tsk-today-recent-docs` |

경로 예: `GET /api/v1/tsk/today-tasks/list` · 알림 `.../notifications/list`. 과제 생성은 `DailyTaskGenerationJob`.

라우트: `/today-tasks`. 홈 `/` → HomeView가 여기로 보낸다. 탭 첫 칸 고정 아님.

개선조치 화면은 [`pages/flow/ca/corrective/`](../flow/ca/corrective/README.md) (`taskWorkflowApi` 공유 가능).

목록: 기본 「미완료 과제만 보기」(조치내용 없는 CA · APV 아닌 작성과제). 기한경과(`due_dt` < 오늘)는 빨간 행으로 맨 위. 더블클릭: 예정은 작성 화면 행추가(양식코드·일자 그대로), 그 외는 기존 문서·개선조치 조회.
