# doccycle — 문서주기관리 (`schedule-cycle-management`)

화면 1개 = 패키지 1개. 파이프라인 표는 FE `pages/hwp/README.md` 2장 · 이 패키지 상위 `com.haccp.hwp/README.md`.

| 파일 | 역할 |
|------|------|
| `DocCycleController` | `/api/v1/hwp/doc-cycles/{forms,get,save,validate-delete,delete}` |
| `DocCycleService` | 주기 업서트 + 저장 직후 예정일 재생성. 삭제는 Double Check |
| `DocCycleMapper` (+ `mapper/hwp/doccycle/`) | `sp_schedule_cycle_management_*` · regen · 알림 |
| `CycleScheduleGenerator` | 규칙 → 예정일 순수 계산. 검증 `src/test/.../hwp/doccycle/CycleScheduleGeneratorTest` |
| `DocumentAlarmScheduler` | 마감 임박 알림 — `app.schedule.alarm-cron` |

일일 배치: `tsk/DailyTaskGenerationJob` → `DocCycleService.regenerateAllCompanies()` → `TaskService.generateAllCompanies()`.

목록 `useYn` 검색은 `86_migrate_doc_cycle_form_use_yn.sql`. Jenkins migrate 안 함.
