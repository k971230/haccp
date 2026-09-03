# mapper/board

MyBatis XML — 게시판(오늘 할 일·일정 캘린더). SP `sp_tbl_*` · `sp_calendar_*` 호출.

**맡는 것:** SP 인자 바인딩만. SQL 본문은 `db_sasshaccp/01_sp.sql`.
**안 맡는 것:** `mine` 판정(Service JWT), 공휴일(Java `KoreanHolidayDates`).

| XML | SP |
|-----|-----|
| `TaskMapper.xml` | `sp_tbl_today_task_r_000` · `sp_tbl_today_task_doc_r_000`(p_user_id) · 알림·과제생성 |
| `CalendarMapper.xml` | `sp_calendar_r_000`(doc_idx) · `sp_calendar_workday_r_000` · `sp_calendar_workday_u_000` |

## 관련

- Java `com.haccp.board`
- 정본: `.cursor/rules/08-haccp-backend.mdc`
