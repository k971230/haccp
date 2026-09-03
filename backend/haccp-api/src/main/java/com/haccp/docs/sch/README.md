# sch — 문서주기관리 (`schedule-cycle-management`)

화면 1개 = 패키지 1개. 파이프라인 표는 FE `pages/docs/README.md` 2장 · 이 패키지 상위 `com.haccp.docs/README.md`.

XML `resources/mapper/docs/sch/DocCycleMapper.xml` · SP `db_sasshaccp/01_sp.sql`

## 엔드포인트

| Method | URL | Service | SP | 테이블 |
|---|---|---|---|---|
| GET | `/api/v1/docs/sch/schedule-cycle-management/forms` | `forms` | `sp_schedule_cycle_management_form_r_000` | `tbl_company_template` `tbl_template` `tbl_schedule_rule` `tbl_approval_line` — HTML 은 사용 중인 지면 버전이 있는 것만 |
| GET | `/api/v1/docs/sch/schedule-cycle-management/get` | `cycle` | `sp_schedule_cycle_management_r_000` | `tbl_schedule_rule` `tbl_schedule_rule_detail` `tbl_company_template` `tbl_approval_line` |
| PUT | `/api/v1/docs/sch/schedule-cycle-management/save` | `save` | `sp_schedule_cycle_management_c_000` · `sp_tbl_schedule_task_regen_c_000` | `tbl_schedule_rule` `tbl_schedule_rule_detail` `tbl_schedule_task` `tbl_company_template` |
| POST | `/api/v1/docs/sch/schedule-cycle-management/validate-delete` | `validateDelete` | SP 없음 — `sp_schedule_cycle_management_r_000`으로 존재 확인 | `tbl_schedule_rule` |
| POST | `/api/v1/docs/sch/schedule-cycle-management/delete` | `delete` | `sp_schedule_cycle_management_d_000` | `tbl_schedule_rule` |
| (배치) | `DocumentAlarmScheduler` | `sendAlarms` | `sp_tbl_notification_task_c_000` | `tbl_schedule_task` |

| 파일 | 역할 |
|------|------|
| `DocCycleController` | `/api/v1/docs/sch/schedule-cycle-management/{forms,get,save,validate-delete,delete}` |
| `DocCycleService` | 주기 업서트 + 저장 직후 예정일 재생성. 삭제는 Double Check(Java 존재 확인) |
| `DocCycleMapper` | 위 SP |
| `CycleScheduleGenerator` | 규칙 → 예정일 순수 계산. 검증 `src/test/.../docs/sch/CycleScheduleGeneratorTest` |
| `KoreanHolidayDates` | holidays-kr JSON → 날짜 Set. 공휴일 규칙은 직접 계산하지 않는다 |
| `DocumentAlarmScheduler` | 마감 임박 알림 — `app.schedule.alarm-cron` |

일일 배치: `board/DailyTaskGenerationJob` → `DocCycleService.regenerateAllCompanies()` → `TaskService.generateAllCompanies()`.

비영업일은 토·일 + classpath `holidays/holidays-kr.json`([hyunbinseo/holidays-kr](https://github.com/hyunbinseo/holidays-kr) `basic.json`, npm `5.2027.1`).
월력요항이 새 연도에 실리면 JSON만 덮어쓴다. 절차는 `src/main/resources/holidays/README.md`. JSON에 없는 연도는 주말만 본다.

## 알림은 여기 한 곳에서만 만든다

`DocumentAlarmScheduler`(10분) → `DocCycleService.sendTaskAlarms()` → `sp_tbl_notification_task_c_000`.
**과제당 정확히 한 번**이다 — 적재 직후 `alarm_send_yn='Y'` 로 잠근다.

예전에는 일일 배치(`sp_tbl_schedule_task_generate_c_000`)도 같이 넣었다. 셋이 겹쳐 표가 끝없이 불었다 —
지연분이 날마다 다시 들어갔고, `NOT EXISTS` 가드가 **같은 INSERT 가 방금 넣은 행을 못 봐서** 한 문장이 여러 행을 넣었고,
그 SP 를 **화면 조회**(`tsk/TaskService.todayTasks`)도 불러 사람이 화면을 열 때마다 알림이 생겼다.
그쪽 INSERT 는 걷어냈다. **여기 말고 다른 데서 `tbl_notification` 에 넣지 않는다.**

| 설정 | 뜻 |
|---|---|
| `app.schedule.alarm-cron` | 점검 주기. 기본 10분 — **발송 주기가 아니라 `alarm_dt` 를 맞추는 눈금**이다 |
| `app.schedule.alarm-before-minutes` | 마감 몇 분 전. 기본 60 |
| `app.schedule.dormant-days` | 이 날수만큼 로그인이 없는 회사는 **적재를 건너뛴다**. 기본 30, 0 이하면 안 거른다 |

**휴면이어도 `alarm_send_yn` 은 닫는다.** 안 그러면 그 회사가 한 달 뒤 다시 들어왔을 때 지나간 마감이 한꺼번에 터진다.

`INSERT` 에 `ON CONFLICT DO NOTHING` 이 붙어 있다. **없으면 `ux_tbl_notification_dedup` 에 걸리는 순간
그 실행의 모든 회사 알림이 같이 롤백된다** — 한 문장이라 그렇다. 시험에서 실제로 그렇게 났다.

기본 설정으로는 겹칠 길이 좁다(`alarm_send_yn` 이 과제당 한 번을 이미 막고, `content` 에 `due_dt`·`due_time` 이 들어간다).
**`alarm-before-minutes` 를 하루 넘게 키우면 그 길이 열린다** — 「이미 알린 미래 과제」가 생기고,
그 상태에서 주기를 고쳐 저장하면 그 행이 지워졌다 다시 `'N'` 으로 깔린다.
설정 하나 바꿨다고 전 회사 알림이 멎으면 안 되니 붙여 둔다.
목록 `useYn` 검색은 `db_sasshaccp/01_sp.sql`. 비정기(E)·좌측 숨김은 `db_sasshaccp/01_sp.sql`. 결재선은 `db_sasshaccp/01_sp.sql`(사용양식 `appr_line_cd`). Jenkins migrate 안 함.
