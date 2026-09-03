# pages/board

게시판 대분류. 오늘 할 일·일정 캘린더. URL `/board/{scrnCd}`.

**맡는 것:** 오늘 과제 KPI·최근 문서(본인 작성)·월간 캘린더·영업일 전환.
**안 맡는 것:** 개선조치 화면(`pages/flow/ca/corrective/`), 문서 작성·결재.

| scrnCd | Page | Rule | API | Controller | persistId |
|--------|------|------|-----|------------|-----------|
| `today-tasks` | `TodayTasksPage.tsx` | `TodayTasksRule.ts` | `api/board/taskWorkflowApi.ts` | `TaskController` `/api/v1/board/today-tasks` | `tsk-today-tasks` · `tsk-today-recent-docs` |
| `calendar` | `CalendarPage.tsx` | `CalendarRule.ts` | `api/board/calendarApi.ts` | `CalendarController` `/api/v1/board/calendar` | 없음 |

`scrnCd`·`persistId`는 폴더를 옮겨도 바꾸지 않는다.

홈 `/` → HomeView가 `routeOf("today-tasks")` → `/board/today-tasks`.

알림 `GET /api/v1/board/notifications/*` 는 오늘 할 일 화면 권한. 알림함 화면은 없다.

## 일정 캘린더

회사 전체 과제. pill 색: 내 담당(파랑)·밀림(빨강)·완료(초록)·오늘 할 일(보라)·그 외(호박). 글자는 검정.

더블클릭(`canOpenCalendarTask`):

- 담당 없음 · 본인 · 서버 `mine`(부서)이면 연다 — 밀림·오늘 할 일 색 포함
- 완료(APV)는 `docIdx > 0`일 때만 `routeForDocument` 조회. 문서 없으면 작성 화면으로 안 보낸다
- 타인 지정 담당은 안 연다

저장은 주기설정과 같은 `MesButton variant="save" icon="save"`. 주말·공휴일 체크 후 `tbl_workday_override` 에 넣고 예정일을 다시 만든다.

오늘 할 일·캘린더는 `VITE_DASHBOARD_POLLING_MS`(기본 2분)마다 무소음 재조회한다. 영업일 변경분이 있으면 그 회차는 건너뛴다.

## 최근 문서

로그인 사용자가 쓴 문서만(`writer_id`). 더블클릭은 `routeForDocument` — 캘린더 완료 조회와 같다.

## 관련

- BE `com.haccp.board` · XML `mapper/board/`
- 비밀번호 변경: 푸터 → `PasswordChangeModal` · `POST /api/v1/auth/change-password`
- 정본: `.cursor/rules/09-haccp-frontend.mdc`

## 변경

- 2026-09-03 — `pages/tsk` 에서 옮기고 일정 캘린더·비밀번호 변경을 붙였다
