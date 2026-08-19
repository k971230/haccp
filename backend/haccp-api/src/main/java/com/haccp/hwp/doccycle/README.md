# doccycle — 문서주기관리 (`schedule-cycle-management`)

화면 1개 = 패키지 1개. 파이프라인 표는 FE `pages/hwp/README.md` 2장 · 이 패키지 상위 `com.haccp.hwp/README.md`.

XML `resources/mapper/hwp/doccycle/DocCycleMapper.xml` · SP `db_sasshaccp/85_migrate_doc_cycle.sql` · `86_migrate_doc_cycle_form_use_yn.sql` · `96_migrate_cycle_e_irregular.sql`

## 엔드포인트

| Method | URL | Service | SP | 테이블 |
|---|---|---|---|---|
| GET | `/api/v1/hwp/doc-cycles/forms` | `forms` | `sp_schedule_cycle_management_form_r_000` | `tbl_company_template` `tbl_template` `tbl_schedule_rule` |
| GET | `/api/v1/hwp/doc-cycles/get` | `cycle` | `sp_schedule_cycle_management_r_000` | `tbl_schedule_rule` `tbl_schedule_rule_detail` |
| PUT | `/api/v1/hwp/doc-cycles/save` | `save` | `sp_schedule_cycle_management_c_000` · `sp_tbl_schedule_task_regen_c_000` | `tbl_schedule_rule` `tbl_schedule_rule_detail` `tbl_schedule_task` |
| POST | `/api/v1/hwp/doc-cycles/validate-delete` | `validateDelete` | SP 없음 — `sp_schedule_cycle_management_r_000`으로 존재 확인 | `tbl_schedule_rule` |
| POST | `/api/v1/hwp/doc-cycles/delete` | `delete` | `sp_schedule_cycle_management_d_000` | `tbl_schedule_rule` |
| (배치) | `DocumentAlarmScheduler` | `sendAlarms` | `sp_tbl_notification_task_c_000` | `tbl_schedule_task` |

| 파일 | 역할 |
|------|------|
| `DocCycleController` | `/api/v1/hwp/doc-cycles/{forms,get,save,validate-delete,delete}` |
| `DocCycleService` | 주기 업서트 + 저장 직후 예정일 재생성. 삭제는 Double Check(Java 존재 확인) |
| `DocCycleMapper` | 위 SP |
| `CycleScheduleGenerator` | 규칙 → 예정일 순수 계산. 검증 `src/test/.../hwp/doccycle/CycleScheduleGeneratorTest` |
| `DocumentAlarmScheduler` | 마감 임박 알림 — `app.schedule.alarm-cron` |

일일 배치: `tsk/DailyTaskGenerationJob` → `DocCycleService.regenerateAllCompanies()` → `TaskService.generateAllCompanies()`.
목록 `useYn` 검색은 `86_migrate_doc_cycle_form_use_yn.sql`. 비정기(E)·좌측 숨김은 `96_migrate_cycle_e_irregular.sql`. Jenkins migrate 안 함.
