# api/board

게시판 화면 API. 오늘 할 일·알림·일정 캘린더.

**맡는 것:** 오늘 과제·최근 문서·알림·캘린더 월 조회·영업일 저장.
**안 맡는 것:** 로그인·비밀번호(`authApi.ts`). 개선조치 URL은 `/api/v1/flow/ca` — 파일이 여기 있는 이유는 예전 한 파일이었기 때문이다.

| 파일 | URL |
|------|-----|
| `taskWorkflowApi.ts` | `/api/v1/board/today-tasks` · `/api/v1/board/notifications` · `/api/v1/flow/ca/*` |
| `calendarApi.ts` | `/api/v1/board/calendar` |

최근 문서 `listTodayRecentDocs` — 기간 + OFFSET/LIMIT. 작성자 필터는 JWT. 요청에 userId를 넣지 않는다.

## 관련

- FE `pages/board/`
- BE `com.haccp.board`
