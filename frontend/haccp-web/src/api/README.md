# api

Axios HTTP 클라이언트·도메인 API 함수.

손대는 메뉴의 화면 전용 API는 `api/{대}/` 로 나눈다. 공용 파일 I/O(`documentApi`)는 그대로 둔다. 경로 `docs/24`.

## docs

| 파일 | 대상 |
|------|------|
| `docs/hwpTemplateApi.ts` | 사용양식관리 `/api/v1/docs/hwp/hwp-template-management/*` — 삭제 포함 전부 화면 자기 경로 |
| `docs/docCycleApi.ts` | 문서주기관리 `/api/v1/docs/sch/schedule-cycle-management`. 저장 1회로 규칙 업서트 + 예정일 재생성까지 끝난다 |
| `docs/htmlFormApi.ts` | HTML양식 원본 5화면 `/api/v1/docs/html-form/{scrnCd}` · 공정점검 작성 `/api/v1/docs/html-form/hyg-process-template` |

## 기타

| 파일 | 대상 |
|------|------|
| `board/taskWorkflowApi.ts` | 오늘 할 일 `/api/v1/board/today-tasks` · 알림 `/api/v1/board/notifications` · 이탈개선조치 `/api/v1/flow/ca/*` |
| `board/calendarApi.ts` | 일정 캘린더 `/api/v1/board/calendar` |
| `sys/approvalLineApi.ts` | 결재선 `/api/v1/sys/code/approval-line-management/*` |
| `documentApi.ts` | 문서함·결재·HWP 원본 `/api/v1/docs/documents` · `/api/v1/docs/templates` |

## 관련

- 정본: `.cursor/rules/09-haccp-frontend.mdc` · `.cursor/rules/09-haccp-frontend.mdc`
