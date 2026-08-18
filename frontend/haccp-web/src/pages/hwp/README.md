# hwp 파이프라인 (FE + BE + DB)

메뉴바에서 열리는 `hwp` 도메인 2화면 정본.
로컬 UI `http://localhost:4173` · API `http://localhost:7070`
관련: `docs/7_에이전트_가이드_FE.md` · `docs/3_운영규칙_FE.md` · `docs/8_에이전트_가이드_BE.md` · `docs/4_운영규칙_BE.md`

라우트 규칙: `routeOf(scrnCd)` → `/screen/{scrnCd}` (`shell/tabRoute.ts`)

골드 구조는 [`pages/sys/README.md`](../sys/README.md)와 같다. 이 파일은 hwp만 적는다.

---

## 0. 구조 규약

손대는 메뉴는 그 작업에서 sys와 같이 분할한다. 미리 전 메뉴를 나누지 않는다.

### 0-1. 폴더 = 메뉴 1개

```
pages/hwp/
 ├ hwptemplate/ HwpTemplateManagementPage.tsx · HwpTemplateManagementRule.ts · README.md
 ├ doccycle/    ScheduleCycleManagementPage.tsx · ScheduleCycleManagementRule.ts · README.md
 ├ formType.ts       구분 라벨·자사양식 판정 정본 (두 화면 공유)
 ├ FormTypeBadge.tsx 헤더 구분 배지 (두 화면 공유)
 └ README.md         (이 파일)
```

### 0-2. Page / Rule 책임 분리

| 파일 | 담는 것 | 담지 않는 것 |
|---|---|---|
| `*Rule.ts` | `SCRN_CD` · `PERSIST_ID` · `SPLIT_KEY` · 컬럼 팩터리 · 잠금 규칙 · 주기 상수·날짜 변환 | JSX · `useState` · API 호출 |
| `*Page.tsx` | 렌더 · 상태 · API 호출 · 이벤트 핸들러 | 컬럼 하드코딩 · 잠금 규칙 하드코딩 |

### 0-3. API도 도메인별로 나눈다

| 파일 (`src/api/hwp/`) | 대상 |
|---|---|
| `hwpTemplateApi.ts` | 사용양식 관리. 삭제는 `api/workflowApi.ts`의 company-templates (법적서류와 URL 공유) |
| `docCycleApi.ts` | 문서주기관리 |

파일 원본 I/O는 공용 `api/documentApi.ts` (`loadHwpTemplateFile` · `saveHwpTemplateForm`).

### 0-4. 그리드 pref 키

**`scrnCd`·`persistId`는 폴더를 옮겨도 값을 바꾸지 않는다.**

| 화면 | scrnCd | persistId · split |
|---|---|---|
| 사용양식 관리 | `hwp-template-management` | `hwp-template-management-list` · `haccp-split-hwp-template` |
| 문서주기관리 | `schedule-cycle-management` | `doc-cycle-forms` · `haccp-split-doc-cycle` |

### 0-5. 백엔드 구조 (`com.haccp.hwp`)

```
java/com/haccp/hwp/
 ├ hwptemplate/ HwpTemplateController · Service · Mapper
 └ doccycle/    DocCycleController · Service · Mapper
                CycleScheduleGenerator · DocumentAlarmScheduler
```

XML은 `resources/mapper/hwp/{같은 폴더명}/*.xml` (`mapper/hwp/README.md`).

삭제는 사용양식만 예외 — `/api/v1/bas/company-templates/*` 를 Workflow가 담당. 법적서류 메뉴 분할 때 이전한다.

### 0-6. CUD 공통 파이프라인

```
조회:  GET  /api/v1/hwp/{resource}/list|forms|get
저장:  PUT  /api/v1/hwp/{resource}/save
삭제:  POST /api/v1/hwp/{resource}/validate-delete → POST .../delete
```

- HTTP DELETE 금지, 삭제 키는 단건이어도 `[{ tmplCd }]` 배열
- `validate-delete`·`delete` 양쪽에서 같은 `assertDeletable` (Double Check)
- 회사코드·작업자는 `LoginUserContext`(JWT)에서만

Jenkins는 `db_sasshaccp/*.sql` migrate를 안 돌린다. 목록 SP 시그니처가 바뀐 파일은 DBeaver/수동 적용.

---

## 1. 사용양식 관리 (`hwp-template-management`)

### 1-1. 화면

좌 목록(크기 조절) · 우 미리보기. 목록 헤더는 신규·저장·삭제, 파일 버튼(업로드·내보내기·불러오기·초기화)은 미리보기 헤더.
구분(시스템/자사)은 badge 표시 전용. 신규는 항상 자사양식. 시스템양식은 카탈로그 예제 전부(html 전용 화면 양식 포함)가 조회된다.

### 1-2. 파일

| 구분 | 경로 |
|---|---|
| FE | `pages/hwp/hwptemplate/HwpTemplateManagementPage.tsx` · `HwpTemplateManagementRule.ts` |
| API | `api/hwp/hwpTemplateApi.ts` · 삭제는 `api/workflowApi.ts` · 파일 I/O `api/documentApi.ts` |
| BE | `com/haccp/hwp/hwptemplate/{HwpTemplateController,HwpTemplateService,HwpTemplateMapper}.java` |
| XML | `resources/mapper/hwp/hwptemplate/HwpTemplateMapper.xml` |
| DB | `db_sasshaccp/84_migrate_form_master_type.sql` · `87_migrate_hwp_template_list_all.sql` |

### 1-3. 버튼 → 끝단

| 버튼·이벤트 | FE 핸들러 | API | Service | SP | 테이블 |
|---|---|---|---|---|---|
| 조회 | `loadList` → `listHwpTemplates` | `GET /api/v1/hwp/hwp-templates/list` | `list` | `sp_hwp_template_management_r_000` | `tbl_company_template` `tbl_template` |
| 신규 | `handleAdd` | 없음(로컬 draft) | | | |
| 저장 | `handleSave` → `saveHwpTemplate` | `PUT .../save` | `save` | `sp_hwp_template_management_c_000` | `tbl_company_template` `tbl_template` |
| 삭제 | `handleDelete` → `validateDeleteCompanyTemplates` → `deleteCompanyTemplates` | `POST /api/v1/bas/company-templates/validate-delete` → `POST .../delete` | Workflow `validateDelete`·`delete` | `sp_tbl_company_template_delete_blocker_r_000` → `sp_tbl_company_template_d_000` | `tbl_company_template` |
| 업로드 | `handleUploadFile` → `saveHwpTemplateForm` | `POST /api/v1/doc/templates/{tmplCd}/form` | `doc.TemplateService.saveForm` | `sp_hwp_template_management_file_c_000` | `tbl_company_template_file` |
| 내보내기 | `handleExportFile` | `GET /api/v1/doc/templates/{tmplCd}/form` | 파일 볼륨 읽기 | | `HaccpTemplates` / `CustomTemplates` |
| 불러오기 | `openHistModal` → `applyHwpTemplateFile` | `GET .../files` · `POST .../apply-file` | `listFiles` · `applyFile` | `sp_hwp_template_management_file_r_000` · `sp_hwp_template_management_current_u_000` | `tbl_company_template_file` |
| 초기화 | `handleReset` → `applyHwpTemplateFile(default)` | `POST .../apply-file` | `applyFile` | `sp_hwp_template_management_current_u_000` | `tbl_company_template` |

시스템양식은 삭제 불가(FE·Service·SP 3중 차단). 파일 기능은 구분과 무관.

---

## 2. 문서주기관리 (`schedule-cycle-management`)

### 2-1. 화면

좌 사용양식 목록(조회 전용, 50:50) · 우 주기 단일 폼(업서트). 양식 1개 = 주기 0..1건.
검색: 양식코드 · 양식명 · 사용여부(기본 Y, 빈값=전체). 열: 양식코드 · 양식명 · 구분 · 사용여부.
반복설정은 주기 콤보에 따라 영역만 교체. 매월 날짜 칩은 파랑, 「말일 실행」은 노랑.

### 2-2. 파일

| 구분 | 경로 |
|---|---|
| FE | `pages/hwp/doccycle/ScheduleCycleManagementPage.tsx` · `ScheduleCycleManagementRule.ts` |
| API | `api/hwp/docCycleApi.ts` |
| BE | `com/haccp/hwp/doccycle/{DocCycleController,DocCycleService,DocCycleMapper,CycleScheduleGenerator,DocumentAlarmScheduler}.java` |
| XML | `resources/mapper/hwp/doccycle/DocCycleMapper.xml` |
| DB | `db_sasshaccp/85_migrate_doc_cycle.sql` · `86_migrate_doc_cycle_form_use_yn.sql` |

### 2-3. 버튼 → 끝단

| 버튼·이벤트 | FE 핸들러 | API | Service | SP | 테이블 |
|---|---|---|---|---|---|
| 조회 | `loadForms` → `listDocCycleForms` | `GET /api/v1/hwp/doc-cycles/forms` | `forms` | `sp_schedule_cycle_management_form_r_000` | `tbl_company_template` `tbl_template` `tbl_schedule_rule` |
| 행 선택 | `handleSelect` → `getDocCycle` | `GET .../get` | `cycle` | `sp_schedule_cycle_management_r_000` | `tbl_schedule_rule` `tbl_schedule_rule_detail` |
| 저장 | `handleSave` → `saveDocCycle` | `PUT .../save` | `save` (+ 예정일 재생성) | `sp_schedule_cycle_management_c_000` · `sp_tbl_schedule_task_regen_c_000` | `tbl_schedule_rule` `tbl_schedule_task` |
| 삭제 | `handleDelete` → `validateDeleteDocCycles` → `deleteDocCycles` | `POST .../validate-delete` → `POST .../delete` | `validateDelete`·`delete` | 검증은 `sp_schedule_cycle_management_r_000` 존재 확인 · 삭제는 `sp_schedule_cycle_management_d_000` | `tbl_schedule_rule` |
| 담당자 | `openModal("CodeLookup")` | `listUsers` | | | `tbl_user` `tbl_dept` |

담당자를 고르면 소속 부서가 기본값으로 들어온다. 담당부서는 읽기 전용.
주기 없는 양식 기본값: 당일 · 매일 · 그대로 · 18:00 · 담당 빈값 · 사용 Y.

---

## 3. 신규 메뉴 추가 절차

`pages/sys/README.md` §7과 같다. 폴더는 `pages/hwp/{메뉴}/`, 패키지는 `com.haccp.hwp.{메뉴}`, XML은 `mapper/hwp/{메뉴}/`.
이 문서의 표와 화면 README를 함께 갱신한다.

검증: `./mvnw -q -DskipTests compile` · `npx tsc --noEmit`.
