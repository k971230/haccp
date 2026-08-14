# hwp

도메인 `hwp` — 사용양식·문서주기. Controller·Service·Mapper.

손대는 메뉴는 `com.haccp.hwp.{메뉴}` 로 분할한다. 골드: `com.haccp.sys` · `08-haccp-backend.mdc`.

## 패키지

### 사용양식 (`hwptemplate/`)

`HwpTemplateController` · Service · Mapper — `/api/v1/hwp/hwp-templates/{list,save,files,apply-file}`.  
삭제는 법적서류도 `/api/v1/bas/company-templates/*` 를 쓰므로 Workflow에 잔류. 그 메뉴를 손볼 때 이전한다.

### 문서주기 (`doccycle/`)

| 파일 | 역할 |
|------|------|
| `DocCycleController` | `/api/v1/hwp/doc-cycles/{forms,get,save,validate-delete,delete}` |
| `DocCycleService` | 주기 업서트 + 저장 직후 예정일 재생성. 삭제는 Double Check |
| `DocCycleMapper` (+ `mapper/hwp/doccycle/`) | `sp_schedule_cycle_management_*` · regen · 알림 |
| `CycleScheduleGenerator` | 규칙 → 예정일 순수 계산. 검증 `src/test/.../hwp/doccycle/CycleScheduleGeneratorTest` |
| `DocumentAlarmScheduler` | 마감 임박 알림 — `app.schedule.alarm-cron` |

일일 배치: `tsk/DailyTaskGenerationJob` → `DocCycleService.regenerateAllCompanies()` → `TaskService.generateAllCompanies()`.

## 관련

- 정본: `docs/8_에이전트_가이드_BE.md` · `.cursor/rules/08-haccp-backend.mdc`
