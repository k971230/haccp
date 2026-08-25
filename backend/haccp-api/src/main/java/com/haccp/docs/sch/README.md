# sch — 문서주기관리 (`schedule-cycle-management`)

화면 1개 = 패키지 1개. 파이프라인 표는 FE `pages/docs/README.md` 2장 · 이 패키지 상위 `com.haccp.docs/README.md`.

XML `resources/mapper/docs/sch/DocCycleMapper.xml` · SP `db_sasshaccp/01_sp.sql`

## 엔드포인트

| Method | URL | Service | SP | 테이블 |
|---|---|---|---|---|
| GET | `/api/v1/docs/sch/schedule-cycle-management/forms` | `forms` | `sp_schedule_cycle_management_form_r_000` | `tbl_company_template` `tbl_template` `tbl_schedule_rule` `tbl_approval_line` |
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
| `DocumentAlarmScheduler` | 마감 임박 알림 — `app.schedule.alarm-cron` |

일일 배치: `tsk/DailyTaskGenerationJob` → `DocCycleService.regenerateAllCompanies()` → `TaskService.generateAllCompanies()`.
목록 `useYn` 검색은 `db_sasshaccp/01_sp.sql`. 비정기(E)·좌측 숨김은 `db_sasshaccp/01_sp.sql`. 결재선은 `db_sasshaccp/01_sp.sql`(사용양식 `appr_line_cd`). Jenkins migrate 안 함.
