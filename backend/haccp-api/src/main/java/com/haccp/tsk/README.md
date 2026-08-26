# com.haccp.tsk

정본: FE `pages/tsk/README.md`. `TaskController` · `DailyTaskGenerationJob`. XML `mapper/tsk/`.

맡는 URL

| URL | 무엇 |
|---|---|
| `/api/v1/tsk/today-tasks/*` | 오늘 할 일 화면 |
| `/api/v1/tsk/notifications/*` | 알림 — 화면이 아니라 셸 공용 |
| `/api/v1/docs/documents/{docIdx}/relations` | 문서 관계 — FE 가 아직 안 부른다 |
| `/api/v1/docs/audit-export/*` | 감사자료 — G-14 동결. `@Deprecated(forRemoval=false)` 로 남긴다 |

## 변경

- 2026-08-26 — 개선조치관리 화면 API 를 `flow/ca` 로 내보냈다.
  URL 이 `/flow/ca/...` 인데 여기 있어서 패키지 규칙이 깨져 있었다
