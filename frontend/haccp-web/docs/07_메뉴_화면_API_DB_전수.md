# HACCP 메뉴·화면·API·DB 전수 스펙

> 정본: `frontend/haccp-web/docs/07_메뉴_화면_API_DB_전수.md`  
> 작성일: 2026-08-10 · 개발자: 박승우  
> 범위: HACCP SaaS만 (MES 제외). CRUD 패턴은 [`06_업무_CRUD.md`](06_업무_CRUD.md).  
> DEMO 테넌트 DB 스냅샷 기준.  
> 인덱스: [`00_문서인덱스_및_통합리뷰.md`](00_문서인덱스_및_통합리뷰.md)  
> FE·BE 통합 상세: [`08_HACCP_FE_BE_통합_상세스펙.md`](08_HACCP_FE_BE_통합_상세스펙.md)  
> 잘된 점·부족한 점: [`09_통합완성도_및_부족분.md`](09_통합완성도_및_부족분.md)

---

## §0 개요·스택 버전·라우팅

**스택 한 줄:** React **18.3.1** · Vite **5.4.8** · MyBatis Spring Boot Starter **3.0.3** · Spring Boot **3.3.4** · Java **17** · PostgreSQL JDBC **42.7.4** · Node **≥20** · DB/스키마 **`sasshaccp`**.

### 0.1 버전 표 (필수)

| 층 | 항목 | 버전 | 출처 |
|----|------|------|------|
| FE | React | **18.3.1** (`^18.3.1`) | frontend/haccp-web/package.json |
| FE | react-dom | 18.3.1 | 동일 |
| FE | react-router-dom | 6.26.2 | 동일 |
| FE | Vite | **5.4.8** | 동일 |
| FE | TypeScript | 5.6.2 | 동일 |
| FE | Zustand | 5.0.0 | 동일 |
| FE | @tanstack/react-query | 5.59.0 | 동일 |
| FE | @tanstack/react-table | 8.20.5 | 동일 |
| FE | @tanstack/react-virtual | 3.14.5 | 동일 |
| FE | axios | 1.7.7 | 동일 |
| FE | Tailwind CSS | 3.4.17 | 동일 |
| FE | lucide-react | 1.21.0 | 동일 |
| FE | @rhwp/editor | 0.8.2 | 동일 |
| FE | Node / npm | ≥20 / ≥10 | engines |
| BE | Java | **17** | backend/haccp-api/pom.xml |
| BE | Spring Boot | **3.3.4** | parent |
| BE | MyBatis Spring Boot Starter | **3.0.3** | pom 명시 |
| BE | PostgreSQL JDBC | 42.7.4 | pom |
| BE | JJWT | 0.12.6 | pom |
| BE | spring-dotenv | 4.0.0 | pom |
| DB | DB / schema | sasshaccp / sasshaccp | 규약 |
| DB | SP 규약 | `sp_tbl_{의미}_{r|c|d|u}_000` | 60-haccp-db |
| 런타임 | FE / BE 포트 | 5174 / 8081 | env |

### 0.2 라우팅·셸

| 경로 | 동작 |
|------|------|
| `/login` | LoginPage — authApi |
| `/` | HomeView → today-tasks |
| `/screen/{scrnCd}` | HaccpShell + SCREEN_REGISTRY |
| deep-link | `/screen/{scrnCd}?docIdx={n}` — documentNav.ts |

- 메뉴: `GET /api/v1/menu/list` → SideMenu → `isImplemented`
- 레지스트리: `src/shell/screenRegistry.tsx` — 키 **75**
- UV/PV: useViewLog → POST `/api/v1/log/view/collect` → ViewStatDailyJob → tbl_view_stat_daily
- HTTP DELETE 금지 — POST validate-delete → delete

---

## §1 메뉴 IA·DB 스키마 스펙

### 1.1 사이드바 IA (migrate 36 정본)

| 순서 | 표시 | menu_cd | 역할 |
|------|------|---------|------|
| 0 | 오늘 할 일 | today-tasks | 최상위 leaf |
| 1 | 문서 작성 | MWRK | DB형 + HWP leaf |
| 2 | 문서 현황·결재 | MAPR | 결재·문서함·법적서류·개선 |
| 3 | 문서 기준관리 | MFRM | 양식·admin·주기·결재선·이력 |
| 4 | 기초정보 관리 | MCOD | 공통코드·마스터 |
| 5 | 시스템 관리 | MSYS | 회사·사용자·권한·로그·UV/PV |

숨긴 대메뉴: MCCP MHYG MPRC MFAC MINV MDOC MBAS MSET MLAW MEDU MTST MCA MAUD.

### 1.2 테이블 스펙 (`01_ddl_auth.sql`)

**tbl_screen** — scrn_cd(UK)·scrn_nm·module_cd·tmpl_cd·sort_no·use_yn  
**tbl_menu** — co_cd·menu_cd(UK with co)·menu_nm·h_menu_cd·scrn_cd·sort_no·use_yn  
**tbl_role_screen** — usrgrp_cd·scrn_cd + read/write/modify/delete/print_yn  

주의: menu_cd ≠ scrn_cd 가능 (예: MFRM `equipment-management` → scrn `equipment-history`).

### 1.3 메뉴 API·init

| 단계 | 구현 |
|------|------|
| API | GET /api/v1/menu/list — MenuController → MenuMapper |
| SP | sp_tbl_menu_r_000 (11_sp_auth.sql) |
| 회사 생성 | sp_tbl_company_init_c_000 — use_yn=Y AND module IN (WRK,APR,FRM,COD,SYS) |

### 1.4 migrate 타임라인

| # | 파일 | 요지 |
|---|------|------|
| 09 | 09_seed_platform.sql | 화면 시드. 범용 점검항목관리 미등록 |
| 17 | 17_migrate_screen_codes.sql | frm* → kebab |
| 26~31 | … | LAW/EDU/TST N, legal-document-upload |
| 35 | 35_migrate_menu_ia_cleanup.sql | IA 정리 |
| **36** | 36_migrate_menu_sidebar_ia.sql | **5대메뉴 정본** |
| **40** | 40_migrate_mfrm_admin_menus.sql | 문서별 FRM admin |
| **45** | 45_migrate_equip_pest_tmpl_admin.sql | 설비/방충 → history |
| **46** | 46_migrate_template_volume_ko.sql | 메뉴 equipment→history |
| **47** | 47_migrate_check_item_admin_crud.sql | template-check-item-management N |
| **47** | 47_migrate_legal_upload_type.sql | 법적서류 유형 SP (번호 충돌 주의) |

---

## §2 DB 레이어 파일·도메인 맵

| 영역 | 파일 | 대표 |
|------|------|------|
| 스키마 | 00_schema.sql | sasshaccp |
| 인증·메뉴 | 01_ddl_auth.sql · 11_sp_auth.sql | user/role/screen/menu/code |
| 로그·UV | 02_ddl_log.sql · 12_sp_log.sql | view_log · view_stat_daily |
| 문서·HWP | 03_ddl_doc.sql · 15_sp_doc.sql | document · hwp_document |
| 마스터 | 04_ddl_master.sql · 16_sp_master.sql | sp_tbl_master_* |
| CCP | 05_ddl_biz_ccp.sql · 14_sp_ccp.sql · 39_sp_spec_screens.sql | cold/metal/form |
| 위생 | 06_ddl_biz_hyg.sql · 19_sp_hygiene.sql | hygiene · health_cert |
| 시설·재고 | 07_ddl_biz_ops.sql · 20_sp_biz_ops.sql | biz_ops |
| 플랫폼 | 13_sp_platform.sql | company_template · check_item · init |
| 워크플로 | 18_sp_workflow.sql | approval_line · schedule_rule |
| 과제 | 22_sp_task_notification.sql | today_task · corrective |
| 시스템 | 21_sp_system.sql | sys CRUD SP |
| 시드 | 09_seed_platform.sql · 10_seed_check_item.sql | |

Two-Tier: DB `lower_snake` / 앱 `camelCase`.

---

## §3 공통 인프라

FE: authApi · menuApi · codeApi · prefApi · viewLogApi · http(3계층)  
UI: MesEditableGrid · GridCrudButtons · MesButton(download=indigo) · DocForm* · DocumentApprovalToolbar · PageCard · usePageCommands  
BE: Auth/Menu/Code/Pref/ViewLog Controllers  
Job: DailyTaskGenerationJob `0 5 0 * * *` · ViewStatDailyJob `0 15 0 * * *` (Asia/Seoul)

---

## §4 활성 메뉴 전수 매트릭스

### 4.1 대메뉴·랜딩

| 부모 | menu_cd | 메뉴명 | scrn_cd | sort | module | tmplCd | FE Page | 컴포넌트 | FE API | BE Controller | API | Mapper | SP | Cmds |
|------|---------|--------|---------|------|--------|--------|---------|----------|--------|---------------|-----|--------|----|------|
| `(root)` | `today-tasks` | 오늘 할 일 | `today-tasks` | 10 | TSK | — | TodayTasksPage | MesEditableGrid·MesButton | taskWorkflowApi·documentApi | TaskController | GET /api/v1/tsk/today-tasks/list | TaskMapper | sp_tbl_today_task_r_000 | search |
| `(root)` | `MWRK` | 문서 작성 | — | 100 | — | — | (폴더) | — | — | — | — | — | — | — |
| `(root)` | `MAPR` | 문서 현황·결재 | — | 200 | — | — | (폴더) | — | — | — | — | — | — | — |
| `(root)` | `MFRM` | 문서 기준관리 | — | 300 | — | — | (폴더) | — | — | — | — | — | — | — |
| `(root)` | `MCOD` | 기초정보 관리 | — | 400 | — | — | (폴더) | — | — | — | — | — | — | — |
| `(root)` | `MSYS` | 시스템 관리 | — | 900 | — | — | (폴더) | — | — | — | — | — | — | — |

### 4.2 문서 작성 (MWRK)

| 부모 | menu_cd | 메뉴명 | scrn_cd | sort | module | tmplCd | FE Page | 컴포넌트 | FE API | BE Controller | API | Mapper | SP | Cmds |
|------|---------|--------|---------|------|--------|--------|---------|----------|--------|---------------|-----|--------|----|------|
| `MWRK` | `daily-hygiene-check` | 일일위생점검표 | `daily-hygiene-check` | 101 | WRK | DAILY_HYG | HygieneCheckPage | DocFormLayout·SearchToolbar·DocPaper·DocCell·DocumentApprovalToolbar·MesEditableGrid | hygieneApi | HygieneController | /api/v1/hyg/daily-hygiene-check/* | HygieneMapper | sp_tbl_hygiene_document_* | add·save·del·search |
| `MWRK` | `health-cert-record` | 건강진단관리기록부 | `health-cert-record` | 102 | WRK | LAW_HEALTH | HealthCertPage | MesEditableGrid·GridCrudButtons·MesButton·Input | healthCertApi | HealthCertController | /api/v1/hyg/health-cert/* | HealthCertMapper | sp_tbl_health_cert_* | add·save·del·search |
| `MWRK` | `visitor-log` | 입출입대장 | `visitor-log` | 103 | WRK | VISITOR_LOG | HwpDocumentEditorPage(hwpLeaf) | MesEditableGrid·DocForm*·DocumentApprovalToolbar·rhwp | documentApi·systemApi | DocumentController·TemplateController | /api/v1/doc/documents/* · /templates/{tmplCd}/form | DocumentMapper | sp_tbl_document_* · hwp_document_c | 인페이지 |
| `MWRK` | `pest-control-check` | 방충방서관리점검표 | `pest-control-check` | 104 | WRK | PEST | HygieneCheckPage | DocFormLayout·SearchToolbar·DocPaper·DocCell·DocumentApprovalToolbar·MesEditableGrid | hygieneApi | HygieneController | /api/v1/hyg/pest-control-check/* | HygieneMapper | sp_tbl_hygiene_document_* | add·save·del·search |
| `MWRK` | `ccp-cold-monitor` | 냉장냉동보관모니터링 | `ccp-cold-monitor` | 105 | WRK | CCP_COLD | ColdMonitorPage | DocFormLayout·SearchToolbar·DocPaper·DocCell·DocumentApprovalToolbar·MesEditableGrid | ccpColdApi | CcpColdController | /api/v1/ccp/cold-monitor/* | CcpColdMapper | sp_tbl_ccp_cold_monitor_* | add·save·del·search |
| `MWRK` | `ccp-heat-monitor` | 가열 CCP 모니터링 일지 | `ccp-heat-monitor` | 106 | WRK | CCP_HEAT | CcpGenericMonitorPage | DocFormLayout·SearchToolbar·DocPaper·DocCell·DocumentApprovalToolbar·MesEditableGrid | ccpGenericApi | CcpGenericController | /api/v1/ccp/generic-monitor/* | CcpGenericMapper | ccp generic SP | add·save·del·search |
| `MWRK` | `ccp-sanitize-monitor` | 멸균 CCP 모니터링 일지 | `ccp-sanitize-monitor` | 107 | WRK | CCP_SANITIZE | CcpGenericMonitorPage | DocFormLayout·SearchToolbar·DocPaper·DocCell·DocumentApprovalToolbar·MesEditableGrid | ccpGenericApi | CcpGenericController | /api/v1/ccp/generic-monitor/* | CcpGenericMapper | ccp generic SP | add·save·del·search |
| `MWRK` | `ccp-filter-monitor` | 여과 CCP 모니터링 일지 | `ccp-filter-monitor` | 108 | WRK | CCP_FILTER | CcpGenericMonitorPage | DocFormLayout·SearchToolbar·DocPaper·DocCell·DocumentApprovalToolbar·MesEditableGrid | ccpGenericApi | CcpGenericController | /api/v1/ccp/generic-monitor/* | CcpGenericMapper | ccp generic SP | add·save·del·search |
| `MWRK` | `ccp-metal-monitor` | 금속검출CCP일지 | `ccp-metal-monitor` | 109 | WRK | CCP_METAL | MetalMonitorPage→CcpFormPage | DocFormLayout·SearchToolbar·DocPaper·DocCell·DocumentApprovalToolbar·MesEditableGrid | ccpFormsApi | CcpFormsController | /api/v1/ccp/metal-monitor/* | CcpFormsMapper | sp_tbl_ccp_form_* | add·save·del·search |
| `MWRK` | `ccp-verification-check` | CCP검증점검표 | `ccp-verification-check` | 110 | WRK | CCP_VERIFY | VerificationCheckPage→CcpFormPage | DocFormLayout·SearchToolbar·DocPaper·DocCell·DocumentApprovalToolbar·MesEditableGrid | ccpFormsApi | CcpFormsController | /api/v1/ccp/verification-check/* | CcpFormsMapper | sp_tbl_ccp_form_* | add·save·del·search |
| `MWRK` | `equipment-history` | 설비이력기록부 | `equipment-history` | 111 | WRK | EQUIP_CARD | EquipmentHistoryPage | MesEditableGrid·GridCrudButtons·PageCard·SearchArea | masterApi·equipmentHistApi | MasterController·EquipmentHistController | /api/v1/bas/equipment/* · /equipment-hist/* · photo | MasterMapper·EquipmentHistMapper | sp_tbl_equipment_hist_* | add·save·del·search |
| `MWRK` | `facility-equipment-check` | 설비및시설점검표 | `facility-equipment-check` | 112 | WRK | FACILITY | BizOpsFormPage | DocFormLayout·SearchToolbar·DocPaper·DocCell·DocumentApprovalToolbar·MesEditableGrid | bizOpsApi | BizOpsController | /api/v1/fac/facility-equipment-check/* | BizOpsMapper | sp_tbl_biz_ops_* | add·save·del·search |
| `MWRK` | `visual-insp-standard` | 육안검사기준 | `visual-insp-standard` | 113 | WRK | VISUAL_INSP | HwpDocumentEditorPage(hwpLeaf) | MesEditableGrid·DocForm*·DocumentApprovalToolbar·rhwp | documentApi·systemApi | DocumentController·TemplateController | /api/v1/doc/documents/* · /templates/{tmplCd}/form | DocumentMapper | sp_tbl_document_* · hwp_document_c | 인페이지 |
| `MWRK` | `receiving-insp-hwp` | 입고검사일지 | `receiving-insp-hwp` | 114 | WRK | RECV_INSP | HwpDocumentEditorPage(hwpLeaf) | MesEditableGrid·DocForm*·DocumentApprovalToolbar·rhwp | documentApi·systemApi | DocumentController·TemplateController | /api/v1/doc/documents/* · /templates/{tmplCd}/form | DocumentMapper | sp_tbl_document_* · hwp_document_c | 인페이지 |
| `MWRK` | `submaterial-recv-hwp` | 부자재입고검수점검표 | `submaterial-recv-hwp` | 115 | WRK | SUBMAT_RECV | HwpDocumentEditorPage(hwpLeaf) | MesEditableGrid·DocForm*·DocumentApprovalToolbar·rhwp | documentApi·systemApi | DocumentController·TemplateController | /api/v1/doc/documents/* · /templates/{tmplCd}/form | DocumentMapper | sp_tbl_document_* · hwp_document_c | 인페이지 |
| `MWRK` | `calib-self-hwp` | 자체검교정기록부 | `calib-self-hwp` | 116 | WRK | CALIB_LOG_TEMP | HwpDocumentEditorPage(hwpLeaf) | MesEditableGrid·DocForm*·DocumentApprovalToolbar·rhwp | documentApi·systemApi | DocumentController·TemplateController | /api/v1/doc/documents/* · /templates/{tmplCd}/form | DocumentMapper | sp_tbl_document_* · hwp_document_c | 인페이지 |
| `MWRK` | `calib-ext-hwp` | 외부검교정기록부 | `calib-ext-hwp` | 117 | WRK | CALIB_EXT | HwpDocumentEditorPage(hwpLeaf) | MesEditableGrid·DocForm*·DocumentApprovalToolbar·rhwp | documentApi·systemApi | DocumentController·TemplateController | /api/v1/doc/documents/* · /templates/{tmplCd}/form | DocumentMapper | sp_tbl_document_* · hwp_document_c | 인페이지 |
| `MWRK` | `shipment-log-hwp` | 제품출고관리일지 | `shipment-log-hwp` | 118 | WRK | SHIPMENT | HwpDocumentEditorPage(hwpLeaf) | MesEditableGrid·DocForm*·DocumentApprovalToolbar·rhwp | documentApi·systemApi | DocumentController·TemplateController | /api/v1/doc/documents/* · /templates/{tmplCd}/form | DocumentMapper | sp_tbl_document_* · hwp_document_c | 인페이지 |
| `MWRK` | `waste-hwp` | 폐기물처리점검표 | `waste-hwp` | 119 | WRK | WASTE | HwpDocumentEditorPage(hwpLeaf) | MesEditableGrid·DocForm*·DocumentApprovalToolbar·rhwp | documentApi·systemApi | DocumentController·TemplateController | /api/v1/doc/documents/* · /templates/{tmplCd}/form | DocumentMapper | sp_tbl_document_* · hwp_document_c | 인페이지 |
| `MWRK` | `inventory-hwp` | 입출고및재고점검표 | `inventory-hwp` | 120 | WRK | INV_CHECK | HwpDocumentEditorPage(hwpLeaf) | MesEditableGrid·DocForm*·DocumentApprovalToolbar·rhwp | documentApi·systemApi | DocumentController·TemplateController | /api/v1/doc/documents/* · /templates/{tmplCd}/form | DocumentMapper | sp_tbl_document_* · hwp_document_c | 인페이지 |
| `MWRK` | `edu-plan-hwp` | 연간교육계획표 | `edu-plan-hwp` | 121 | WRK | EDU_PLAN | HwpDocumentEditorPage(hwpLeaf) | MesEditableGrid·DocForm*·DocumentApprovalToolbar·rhwp | documentApi·systemApi | DocumentController·TemplateController | /api/v1/doc/documents/* · /templates/{tmplCd}/form | DocumentMapper | sp_tbl_document_* · hwp_document_c | 인페이지 |
| `MWRK` | `edu-log-hwp` | 교육및회의결과보고서 | `edu-log-hwp` | 122 | WRK | EDU_LOG | HwpDocumentEditorPage(hwpLeaf) | MesEditableGrid·DocForm*·DocumentApprovalToolbar·rhwp | documentApi·systemApi | DocumentController·TemplateController | /api/v1/doc/documents/* · /templates/{tmplCd}/form | DocumentMapper | sp_tbl_document_* · hwp_document_c | 인페이지 |
| `MWRK` | `bad-product-hwp` | 부적합품발생보고서 | `bad-product-hwp` | 123 | WRK | BAD_PRODUCT | HwpDocumentEditorPage(hwpLeaf) | MesEditableGrid·DocForm*·DocumentApprovalToolbar·rhwp | documentApi·systemApi | DocumentController·TemplateController | /api/v1/doc/documents/* · /templates/{tmplCd}/form | DocumentMapper | sp_tbl_document_* · hwp_document_c | 인페이지 |
| `MWRK` | `claim-hwp` | 클레임및이물혼입보고서 | `claim-hwp` | 124 | WRK | CLAIM | HwpDocumentEditorPage(hwpLeaf) | MesEditableGrid·DocForm*·DocumentApprovalToolbar·rhwp | documentApi·systemApi | DocumentController·TemplateController | /api/v1/doc/documents/* · /templates/{tmplCd}/form | DocumentMapper | sp_tbl_document_* · hwp_document_c | 인페이지 |
| `MWRK` | `recall-hwp` | 회수결과보고서 | `recall-hwp` | 125 | WRK | RECALL | HwpDocumentEditorPage(hwpLeaf) | MesEditableGrid·DocForm*·DocumentApprovalToolbar·rhwp | documentApi·systemApi | DocumentController·TemplateController | /api/v1/doc/documents/* · /templates/{tmplCd}/form | DocumentMapper | sp_tbl_document_* · hwp_document_c | 인페이지 |
| `MWRK` | `eval-hwp` | 실시상황평가표 | `eval-hwp` | 126 | WRK | EVAL | HwpDocumentEditorPage(hwpLeaf) | MesEditableGrid·DocForm*·DocumentApprovalToolbar·rhwp | documentApi·systemApi | DocumentController·TemplateController | /api/v1/doc/documents/* · /templates/{tmplCd}/form | DocumentMapper | sp_tbl_document_* · hwp_document_c | 인페이지 |
| `MWRK` | `verify-ca-hwp` | 검증개선조치보고서 | `verify-ca-hwp` | 127 | WRK | VERIFY_CA | HwpDocumentEditorPage(hwpLeaf) | MesEditableGrid·DocForm*·DocumentApprovalToolbar·rhwp | documentApi·systemApi | DocumentController·TemplateController | /api/v1/doc/documents/* · /templates/{tmplCd}/form | DocumentMapper | sp_tbl_document_* · hwp_document_c | 인페이지 |
| `MWRK` | `handover-hwp` | 업무인수인계서 | `handover-hwp` | 128 | WRK | HANDOVER | HwpDocumentEditorPage(hwpLeaf) | MesEditableGrid·DocForm*·DocumentApprovalToolbar·rhwp | documentApi·systemApi | DocumentController·TemplateController | /api/v1/doc/documents/* · /templates/{tmplCd}/form | DocumentMapper | sp_tbl_document_* · hwp_document_c | 인페이지 |
| `MWRK` | `process-hwp` | 공정관리점검표 | `process-hwp` | 129 | WRK | PROCESS | HwpDocumentEditorPage(hwpLeaf) | MesEditableGrid·DocForm*·DocumentApprovalToolbar·rhwp | documentApi·systemApi | DocumentController·TemplateController | /api/v1/doc/documents/* · /templates/{tmplCd}/form | DocumentMapper | sp_tbl_document_* · hwp_document_c | 인페이지 |
| `MWRK` | `vehicle-hwp` | 차량운행일지 | `vehicle-hwp` | 130 | WRK | VEHICLE_LOG | HwpDocumentEditorPage(hwpLeaf) | MesEditableGrid·DocForm*·DocumentApprovalToolbar·rhwp | documentApi·systemApi | DocumentController·TemplateController | /api/v1/doc/documents/* · /templates/{tmplCd}/form | DocumentMapper | sp_tbl_document_* · hwp_document_c | 인페이지 |
| `MWRK` | `personal-hyg-hwp` | 개인위생관리점검표 | `personal-hyg-hwp` | 131 | WRK | PERSONAL_HYG | HwpDocumentEditorPage(hwpLeaf) | MesEditableGrid·DocForm*·DocumentApprovalToolbar·rhwp | documentApi·systemApi | DocumentController·TemplateController | /api/v1/doc/documents/* · /templates/{tmplCd}/form | DocumentMapper | sp_tbl_document_* · hwp_document_c | 인페이지 |
| `MWRK` | `area-hyg-hwp` | 작업장환경위생점검표 | `area-hyg-hwp` | 132 | WRK | AREA_HYG | HwpDocumentEditorPage(hwpLeaf) | MesEditableGrid·DocForm*·DocumentApprovalToolbar·rhwp | documentApi·systemApi | DocumentController·TemplateController | /api/v1/doc/documents/* · /templates/{tmplCd}/form | DocumentMapper | sp_tbl_document_* · hwp_document_c | 인페이지 |
| `MWRK` | `water-hwp` | 용수관리점검표 | `water-hwp` | 133 | WRK | WATER | HwpDocumentEditorPage(hwpLeaf) | MesEditableGrid·DocForm*·DocumentApprovalToolbar·rhwp | documentApi·systemApi | DocumentController·TemplateController | /api/v1/doc/documents/* · /templates/{tmplCd}/form | DocumentMapper | sp_tbl_document_* · hwp_document_c | 인페이지 |
| `MWRK` | `verify-plan-hwp` | 연간검증계획서 | `verify-plan-hwp` | 134 | WRK | VERIFY_PLAN | HwpDocumentEditorPage(hwpLeaf) | MesEditableGrid·DocForm*·DocumentApprovalToolbar·rhwp | documentApi·systemApi | DocumentController·TemplateController | /api/v1/doc/documents/* · /templates/{tmplCd}/form | DocumentMapper | sp_tbl_document_* · hwp_document_c | 인페이지 |
| `MWRK` | `verify-check-hwp` | 검증점검표 | `verify-check-hwp` | 135 | WRK | VERIFY_CHECK | HwpDocumentEditorPage(hwpLeaf) | MesEditableGrid·DocForm*·DocumentApprovalToolbar·rhwp | documentApi·systemApi | DocumentController·TemplateController | /api/v1/doc/documents/* · /templates/{tmplCd}/form | DocumentMapper | sp_tbl_document_* · hwp_document_c | 인페이지 |
| `MWRK` | `verify-report-hwp` | 검증결과보고서 | `verify-report-hwp` | 136 | WRK | VERIFY_REPORT | HwpDocumentEditorPage(hwpLeaf) | MesEditableGrid·DocForm*·DocumentApprovalToolbar·rhwp | documentApi·systemApi | DocumentController·TemplateController | /api/v1/doc/documents/* · /templates/{tmplCd}/form | DocumentMapper | sp_tbl_document_* · hwp_document_c | 인페이지 |
| `MWRK` | `prod-test-hwp` | 제품검사성적서 | `prod-test-hwp` | 137 | WRK | PROD_TEST | HwpDocumentEditorPage(hwpLeaf) | MesEditableGrid·DocForm*·DocumentApprovalToolbar·rhwp | documentApi·systemApi | DocumentController·TemplateController | /api/v1/doc/documents/* · /templates/{tmplCd}/form | DocumentMapper | sp_tbl_document_* · hwp_document_c | 인페이지 |
| `MWRK` | `surface-test-hwp` | 표면오염도검사성적서 | `surface-test-hwp` | 138 | WRK | SURFACE_TEST | HwpDocumentEditorPage(hwpLeaf) | MesEditableGrid·DocForm*·DocumentApprovalToolbar·rhwp | documentApi·systemApi | DocumentController·TemplateController | /api/v1/doc/documents/* · /templates/{tmplCd}/form | DocumentMapper | sp_tbl_document_* · hwp_document_c | 인페이지 |

### 4.3 문서 현황·결재 (MAPR)

| 부모 | menu_cd | 메뉴명 | scrn_cd | sort | module | tmplCd | FE Page | 컴포넌트 | FE API | BE Controller | API | Mapper | SP | Cmds |
|------|---------|--------|---------|------|--------|--------|---------|----------|--------|---------------|-----|--------|----|------|
| `MAPR` | `approval-inbox` | 결재함 | `approval-inbox` | 210 | APR | — | DocumentBoxPage | MesEditableGrid·DocFormSearchToolbar·DocumentApprovalToolbar | documentApi·taskWorkflowApi | DocumentController | GET …/approval-inbox · PUT …/approval | DocumentMapper | sp_tbl_document_* | search |
| `MAPR` | `document-inbox` | 문서함 | `document-inbox` | 220 | APR | — | DocumentBoxPage | MesEditableGrid·DocFormSearchToolbar·DocumentApprovalToolbar | documentApi·taskWorkflowApi | DocumentController | GET …/documents/list · PUT …/approval | DocumentMapper | sp_tbl_document_* | search·del |
| `MAPR` | `legal-document-upload` | 법적서류 | `legal-document-upload` | 240 | APR | — | LegalDocumentUploadPage | MesEditableGrid·GridCrudButtons·PageCard·MesButton(download) | documentApi·workflowApi | TemplateController·DocumentController·WorkflowController | templates/list · legal-types/save · documents hwp/files | DocumentMapper·WorkflowMapper | legal_type · company_template · document | search(패널CRUD) |
| `MAPR` | `corrective-action-management` | 이탈·개선조치 | `corrective-action-management` | 250 | APR | — | CorrectiveActionManagementPage | MesEditableGrid·DocFormSearchToolbar·MesButton | taskWorkflowApi | TaskController | /api/v1/doc/corrective-actions/* | TaskMapper | sp_tbl_corrective_action_* | add·save·del·search |

### 4.4 문서 기준관리 (MFRM)

| 부모 | menu_cd | 메뉴명 | scrn_cd | sort | module | tmplCd | FE Page | 컴포넌트 | FE API | BE Controller | API | Mapper | SP | Cmds |
|------|---------|--------|---------|------|--------|--------|---------|----------|--------|---------------|-----|--------|----|------|
| `MFRM` | `hwp-template-management` | HWP문서관리 | `hwp-template-management` | 310 | FRM | — | HwpTemplateManagementPage | MesEditableGrid·DocForm*·MesButton | documentApi·workflowApi | TemplateController·WorkflowController | /api/v1/doc/templates/* · company-templates/forms | DocumentMapper·WorkflowMapper | sp_tbl_company_template_* | 인페이지 |
| `MFRM` | `daily-hyg-item-admin` | 일일위생 점검항목관리 | `daily-hyg-item-admin` | 311 | FRM | DAILY_HYG | TemplateCheckItemManagementPage | MesEditableGrid·GridCrudButtons·PageCard·SearchArea | workflowApi | WorkflowController | /api/v1/bas/company-check-items/* | WorkflowMapper | sp_tbl_company_check_item_* | add·save·del·search |
| `MFRM` | `ccp-cold-limit-admin` | 냉장냉동 CCP 기준관리 | `ccp-cold-limit-admin` | 321 | FRM | CCP_COLD | MasterDataPage | MesEditableGrid·GridCrudButtons·MesButton·Input | masterApi | MasterController | GET/PUT/POST /api/v1/bas/ccp-limit/* | MasterMapper | sp_tbl_ccp_limit_* | add·save·del·search |
| `MFRM` | `ccp-heat-limit-admin` | 가열 CCP 기준관리 | `ccp-heat-limit-admin` | 322 | FRM | CCP_HEAT | MasterDataPage | MesEditableGrid·GridCrudButtons·MesButton·Input | masterApi | MasterController | GET/PUT/POST /api/v1/bas/ccp-limit/* | MasterMapper | sp_tbl_ccp_limit_* | add·save·del·search |
| `MFRM` | `ccp-sanitize-limit-admin` | 멸균 CCP 기준관리 | `ccp-sanitize-limit-admin` | 323 | FRM | CCP_SANITIZE | MasterDataPage | MesEditableGrid·GridCrudButtons·MesButton·Input | masterApi | MasterController | GET/PUT/POST /api/v1/bas/ccp-limit/* | MasterMapper | sp_tbl_ccp_limit_* | add·save·del·search |
| `MFRM` | `ccp-filter-limit-admin` | 여과 CCP 기준관리 | `ccp-filter-limit-admin` | 324 | FRM | CCP_FILTER | MasterDataPage | MesEditableGrid·GridCrudButtons·MesButton·Input | masterApi | MasterController | GET/PUT/POST /api/v1/bas/ccp-limit/* | MasterMapper | sp_tbl_ccp_limit_* | add·save·del·search |
| `MFRM` | `ccp-metal-limit-admin` | 금속검출 CCP 기준관리 | `ccp-metal-limit-admin` | 325 | FRM | CCP_METAL | MasterDataPage | MesEditableGrid·GridCrudButtons·MesButton·Input | masterApi | MasterController | GET/PUT/POST /api/v1/bas/ccp-limit/* | MasterMapper | sp_tbl_ccp_limit_* | add·save·del·search |
| `MFRM` | `ccp-verify-standard-admin` | CCP검증 기준·주기관리 | `ccp-verify-standard-admin` | 326 | FRM | CCP_VERIFY | TemplateCheckItemManagementPage | MesEditableGrid·GridCrudButtons·PageCard·SearchArea | workflowApi | WorkflowController | /api/v1/bas/company-check-items/* | WorkflowMapper | sp_tbl_company_check_item_* | add·save·del·search |
| `MFRM` | `ccp-limit-management` | CCP한계기준 관리 | `ccp-limit-management` | 330 | FRM | — | MasterDataPage | MesEditableGrid·GridCrudButtons·MesButton·Input | masterApi | MasterController | GET/PUT/POST /api/v1/bas/ccp-limit/* | MasterMapper | sp_tbl_ccp_limit_* | add·save·del·search |
| `MFRM` | `facility-check-item-admin` | 설비시설점검 항목·주기 | `facility-check-item-admin` | 331 | FRM | FACILITY | TemplateCheckItemManagementPage | MesEditableGrid·GridCrudButtons·PageCard·SearchArea | workflowApi | WorkflowController | /api/v1/bas/company-check-items/* | WorkflowMapper | sp_tbl_company_check_item_* | add·save·del·search |
| `MFRM` | `schedule-cycle-management` | 작성주기 관리 | `schedule-cycle-management` | 340 | FRM | — | ScheduleCycleManagementPage | MesEditableGrid·GridCrudButtons·PageCard·SearchArea | workflowApi | WorkflowController | /api/v1/bas/schedule-rules/* | WorkflowMapper | sp_tbl_schedule_rule_* | add·save·del·search |
| `MFRM` | `approval-line-management` | 결재선 관리 | `approval-line-management` | 350 | FRM | — | ApprovalLineManagementPage | MesEditableGrid·GridCrudButtons·PageCard·SearchArea | workflowApi | WorkflowController | /api/v1/bas/approval-lines/* | WorkflowMapper | sp_tbl_approval_line_* | add·save·del·search |
| `MFRM` | `equipment-management` | 설비 이력 | `equipment-history` | 360 | WRK | EQUIP_CARD | EquipmentHistoryPage | MesEditableGrid·GridCrudButtons·PageCard·SearchArea | masterApi·equipmentHistApi | MasterController·EquipmentHistController | /api/v1/bas/equipment/* · /equipment-hist/* · photo | MasterMapper·EquipmentHistMapper | sp_tbl_equipment_hist_* | add·save·del·search |
| `MFRM` | `pest-device-management` | 방충설비 이력 | `pest-device-history` | 370 | BAS | — | PestDeviceHistoryPage | MesEditableGrid·GridCrudButtons·PageCard·SearchArea | masterApi·pestDeviceHistApi | MasterController·PestDeviceHistController | /api/v1/bas/pest-device/* · /pest-device-hist/* | MasterMapper·PestDeviceHistMapper | pest hist SP | add·save·del·search |

### 4.5 기초정보 (MCOD)

| 부모 | menu_cd | 메뉴명 | scrn_cd | sort | module | tmplCd | FE Page | 컴포넌트 | FE API | BE Controller | API | Mapper | SP | Cmds |
|------|---------|--------|---------|------|--------|--------|---------|----------|--------|---------------|-----|--------|----|------|
| `MCOD` | `common-code-management` | 공통코드 관리 | `common-code-management` | 410 | COD | — | SystemManagementPage | MesEditableGrid·GridCrudButtons·MesButton·Input | systemApi | SystemController | GET/PUT/POST /api/v1/sys/common-code-management/{list,save,validate-delete,delete} | SystemMapper | sp_tbl_* (sys) | add·save·del·search |
| `MCOD` | `partner-management` | 거래처 관리 | `partner-management` | 420 | COD | — | MasterDataPage | MesEditableGrid·GridCrudButtons·MesButton·Input | masterApi | MasterController | GET/PUT/POST /api/v1/bas/partner/* | MasterMapper | sp_tbl_master_* | add·save·del·search |
| `MCOD` | `product-management` | 제품 관리 | `product-management` | 430 | COD | — | MasterDataPage | MesEditableGrid·GridCrudButtons·MesButton·Input | masterApi | MasterController | GET/PUT/POST /api/v1/bas/product/* | MasterMapper | sp_tbl_master_* | add·save·del·search |
| `MCOD` | `material-management` | 원·부재료 관리 | `material-management` | 440 | COD | — | MasterDataPage | MesEditableGrid·GridCrudButtons·MesButton·Input | masterApi | MasterController | GET/PUT/POST /api/v1/bas/material/* | MasterMapper | sp_tbl_master_* | add·save·del·search |
| `MCOD` | `storage-management` | 보관고 관리 | `storage-management` | 450 | COD | — | MasterDataPage | MesEditableGrid·GridCrudButtons·MesButton·Input | masterApi | MasterController | GET/PUT/POST /api/v1/bas/storage/* | MasterMapper | sp_tbl_master_* | add·save·del·search |
| `MCOD` | `measuring-device-management` | 계측기 관리 | `measuring-device-management` | 460 | COD | — | MasterDataPage | MesEditableGrid·GridCrudButtons·MesButton·Input | masterApi | MasterController | GET/PUT/POST /api/v1/bas/measuring-device/* | MasterMapper | sp_tbl_master_* | add·save·del·search |
| `MCOD` | `vehicle-management` | 차량 관리 | `vehicle-management` | 470 | COD | — | MasterDataPage | MesEditableGrid·GridCrudButtons·MesButton·Input | masterApi | MasterController | GET/PUT/POST /api/v1/bas/vehicle/* | MasterMapper | sp_tbl_master_* | add·save·del·search |
| `MCOD` | `work-area-management` | 작업장·구역 관리 | `work-area-management` | 480 | COD | — | MasterDataPage | MesEditableGrid·GridCrudButtons·MesButton·Input | masterApi | MasterController | GET/PUT/POST /api/v1/bas/work-area/* | MasterMapper | sp_tbl_master_* | add·save·del·search |

### 4.6 시스템 (MSYS)

| 부모 | menu_cd | 메뉴명 | scrn_cd | sort | module | tmplCd | FE Page | 컴포넌트 | FE API | BE Controller | API | Mapper | SP | Cmds |
|------|---------|--------|---------|------|--------|--------|---------|----------|--------|---------------|-----|--------|----|------|
| `MSYS` | `company-management` | 회사정보 관리 | `company-management` | 910 | SYS | — | SystemManagementPage | MesEditableGrid·GridCrudButtons·MesButton·Input | systemApi | SystemController | GET/PUT/POST /api/v1/sys/company-management/{list,save,validate-delete,delete} | SystemMapper | sp_tbl_* (sys) | add·save·del·search |
| `MSYS` | `user-management` | 사용자 관리 | `user-management` | 920 | SYS | — | SystemManagementPage | MesEditableGrid·GridCrudButtons·MesButton·Input | systemApi | SystemController | GET/PUT/POST /api/v1/sys/user-management/{list,save,validate-delete,delete} | SystemMapper | sp_tbl_* (sys) | add·save·del·search |
| `MSYS` | `department-management` | 부서 관리 | `department-management` | 930 | SYS | — | SystemManagementPage | MesEditableGrid·GridCrudButtons·MesButton·Input | systemApi | SystemController | GET/PUT/POST /api/v1/sys/department-management/{list,save,validate-delete,delete} | SystemMapper | sp_tbl_* (sys) | add·save·del·search |
| `MSYS` | `role-management` | 권한그룹 관리 | `role-management` | 940 | SYS | — | SystemManagementPage | MesEditableGrid·GridCrudButtons·MesButton·Input | systemApi | SystemController | GET/PUT/POST /api/v1/sys/role-management/{list,save,validate-delete,delete} | SystemMapper | sp_tbl_* (sys) | add·save·del·search |
| `MSYS` | `menu-management` | 메뉴 관리 | `menu-management` | 950 | SYS | — | SystemManagementPage | MesEditableGrid·GridCrudButtons·MesButton·Input | systemApi | SystemController | GET/PUT/POST /api/v1/sys/menu-management/{list,save,validate-delete,delete} | SystemMapper | sp_tbl_* (sys) | add·save·del·search |
| `MSYS` | `login-history` | 로그인 이력 | `login-history` | 970 | SYS | — | SystemManagementPage | MesEditableGrid(readOnly) | systemApi | SystemController | GET /api/v1/sys/login-history/list | SystemMapper | login/audit SP | search |
| `MSYS` | `screen-usage-statistics` | 화면 이용 통계 | `screen-usage-statistics` | 980 | SYS | — | SystemManagementPage | MesEditableGrid(readOnly) | systemApi | SystemController | GET /api/v1/sys/screen-usage-statistics/list | SystemMapper | sp_tbl_view_stat_daily_r_000 | search |
| `MSYS` | `audit-log` | 변경 감사 로그 | `audit-log` | 990 | SYS | — | SystemManagementPage | MesEditableGrid(readOnly) | systemApi | SystemController | GET /api/v1/sys/audit-log/list | SystemMapper | login/audit SP | search |

### 4.7 HWP leaf fixedTmplCd 완전표

공통: HwpDocumentEditorPage · documentApi · TemplateController · PUT …/approval

| scrn_cd | fixedTmplCd | 화면명 |
|---------|-------------|--------|
| `visitor-log` | `VISITOR_LOG` | 입출입대장 |
| `visual-insp-standard` | `VISUAL_INSP` | 육안검사기준 |
| `receiving-insp-hwp` | `RECV_INSP` | 입고검사일지 |
| `submaterial-recv-hwp` | `SUBMAT_RECV` | 부자재입고검수점검표 |
| `calib-self-hwp` | `CALIB_LOG_TEMP` | 자체검교정기록부 |
| `calib-ext-hwp` | `CALIB_EXT` | 외부검교정기록부 |
| `shipment-log-hwp` | `SHIPMENT` | 제품출고관리일지 |
| `waste-hwp` | `WASTE` | 폐기물처리점검표 |
| `inventory-hwp` | `INV_CHECK` | 입출고및재고점검표 |
| `edu-plan-hwp` | `EDU_PLAN` | 연간교육계획표 |
| `edu-log-hwp` | `EDU_LOG` | 교육및회의결과보고서 |
| `bad-product-hwp` | `BAD_PRODUCT` | 부적합품발생보고서 |
| `claim-hwp` | `CLAIM` | 클레임및이물혼입보고서 |
| `recall-hwp` | `RECALL` | 회수결과보고서 |
| `eval-hwp` | `EVAL` | 실시상황평가표 |
| `verify-ca-hwp` | `VERIFY_CA` | 검증개선조치보고서 |
| `handover-hwp` | `HANDOVER` | 업무인수인계서 |
| `process-hwp` | `PROCESS` | 공정관리점검표 |
| `vehicle-hwp` | `VEHICLE_LOG` | 차량운행일지 |
| `personal-hyg-hwp` | `PERSONAL_HYG` | 개인위생관리점검표 |
| `area-hyg-hwp` | `AREA_HYG` | 작업장환경위생점검표 |
| `water-hwp` | `WATER` | 용수관리점검표 |
| `verify-plan-hwp` | `VERIFY_PLAN` | 연간검증계획서 |
| `verify-check-hwp` | `VERIFY_CHECK` | 검증점검표 |
| `verify-report-hwp` | `VERIFY_REPORT` | 검증결과보고서 |
| `prod-test-hwp` | `PROD_TEST` | 제품검사성적서 |
| `surface-test-hwp` | `SURFACE_TEST` | 표면오염도검사성적서 |

### 4.8 레지스트리↔메뉴 갭

| scrn_cd | 상태 |
|---------|------|
| approval-history | FE 구현 O · DEMO 활성 메뉴 X (메뉴관리/migrate 복구 대상) |
| equipment-management / pest-device-management | 화면 use_yn=N · 레지스트리는 History로 리다이렉트 · MFRM 메뉴는 history scrn 가리킴 |

---

## §5 화면 유형별 API·Controller 19

| Domain | Controller | Base |
|--------|------------|------|
| auth | AuthController | /api/v1/auth |
| menu | MenuController | /api/v1/menu |
| code | CodeController | /api/v1/code |
| pref | PrefController | /api/v1/pref/grid |
| log | ViewLogController | /api/v1/log/view |
| bas | MasterController | /api/v1/bas/{masterType} |
| bas | EquipmentHistController | /api/v1/bas/equipment-hist |
| bas | PestDeviceHistController | /api/v1/bas/pest-device-hist |
| workflow | WorkflowController | /api/v1/bas (approval-lines·templates·check-items·schedule·legal-types…) |
| ccp | CcpColdController | /api/v1/ccp/cold-monitor |
| ccp | CcpGenericController | /api/v1/ccp/generic-monitor |
| ccp | CcpFormsController | /api/v1/ccp/{metal-monitor\|verification-check\|…} |
| hyg | HygieneController | /api/v1/hyg/{screenCode} |
| hyg | HealthCertController | /api/v1/hyg/health-cert |
| doc | DocumentController | /api/v1/doc/documents |
| doc | TemplateController | /api/v1/doc/templates |
| tsk | TaskController | /api/v1/tsk/* · corrective-actions · audit-export |
| sys | SystemController | /api/v1/sys/{screenCode} · users/…/sign |
| ops | BizOpsController | /api/v1/fac\|inv\|prc/… (6양식) |

표준: GET list · PUT save · POST validate-delete · POST delete (Body 복합키 배열).

---

## §6 짤림·이관·비활성

### 6.1 tbl_screen.use_yn=N

| scrn_cd | 화면명 | module | tmpl | 대체 |
|---------|--------|--------|------|------|
| `annual-verification-plan` | 연간 검증계획서 | CCP | VERIFY_PLAN | verify-plan-hwp |
| `area-hygiene-check` | 작업장 환경위생 점검표 | HYG | AREA_HYG | area-hyg-hwp |
| `audit-export` | 감사자료 출력 | DOC | — | IA 밖(API 잔존) |
| `calibration-target-management` | 검·교정 대상 점검표 | FAC | CALIB_TARGET | 숨김 |
| `ccp-generic-monitor` | 공통 CCP 모니터링 | CCP | — | 유형별 ccp-*-monitor |
| `ccp-iqf-monitor` | 급속냉동 CCP | CCP | CCP_IQF | 미사용 |
| `ccp-wash-monitor` | 세척 CCP | CCP | CCP_WASH | 미사용 |
| `edu-annual-plan` | 연간 교육·훈련 계획서 | EDU | EDU_PLAN | edu-plan-hwp |
| `edu-training-log` | 교육일지 | EDU | EDU_LOG | edu-log-hwp |
| `equipment-management` | 설비마스터등록 | FRM | — | equipment-history (45/46) |
| `hwp-document-editor` | 문서 작성(한글 양식) | WRK | — | 양식별 hwpLeaf |
| `inventory-check` | 입·출고 및 재고 점검표 | INV | INV_CHECK | inventory-hwp |
| `law-building-ledger` | 건축물대장관리 | LAW | LAW_BUILDING | legal-document-upload |
| `law-business-license` | 영업등록증관리 | LAW | LAW_LICENSE | legal-document-upload |
| `law-completion-cert` | 수료증관리 | LAW | LAW_CERT | legal-document-upload |
| `law-health-cert` | 보건증관리 | LAW | LAW_HEALTH | health-cert-record + legal-document-upload |
| `law-material-ledger` | 원료수불대장관리 | LAW | LAW_MATERIAL | legal-document-upload |
| `law-production-ledger` | 생산대장관리 | LAW | LAW_PRODUCTION | legal-document-upload |
| `law-self-quality-test` | 자가품질검사관리 | LAW | LAW_SELF_TEST | legal-document-upload |
| `personal-hygiene-check` | 개인 위생관리 점검표 | HYG | PERSONAL_HYG | personal-hyg-hwp |
| `pest-device-management` | 방충방서 설비·위치관리 | FRM | — | pest-device-history (45) |
| `process-control-check` | 공정관리 점검표 | PRC | PROCESS | process-hwp |
| `receiving-inspection` | 입고검사 일지 | INV | RECV_INSP | receiving-insp-hwp |
| `smart-diary-type-management` | 스마트일지유형 관리 | SET | — | IA 밖(API 잔존) |
| `template-check-item-management` | 점검항목관리 | FRM | — | 문서별 admin (47) |
| `test-product-report` | 제품검사 성적서 | TST | PROD_TEST | prod-test-hwp |
| `test-surface-report` | 표면오염도 검사 성적서 | TST | SURFACE_TEST | surface-test-hwp |
| `waste-disposal-check` | 폐기물 처리 점검표 | FAC | WASTE | waste-hwp |
| `water-management-check` | 용수관리 점검표 | HYG | WATER | water-hwp |

### 6.2 FE dead / 리다이렉트

- MasterDataPage equipment/pest config → History로 우회되어 dead path
- template-check-item-management: 레지스트리 없음
- ccpMetalApi/ccpVerificationApi: 페이지는 ccpFormsApi 경유
- DocumentBoxPage.approvalMode deprecated

### 6.3 최근 반영

- 법적서류 M-D + download(indigo)
- ViewStatDailyJob UV/PV 일집계
- 범용 점검항목관리 비활성
- 설비/방충 → 이력 M-D

---

## §7 FE 카탈로그

### 7.1 pages

- `src/pages/auth/LoginPage.tsx`
- `src/pages/bas/ApprovalLineManagementPage.tsx`
- `src/pages/bas/EquipmentHistoryPage.tsx`
- `src/pages/bas/HwpTemplateManagementPage.tsx`
- `src/pages/bas/MasterDataPage.tsx`
- `src/pages/bas/PestDeviceHistoryPage.tsx`
- `src/pages/bas/ScheduleCycleManagementPage.tsx`
- `src/pages/bas/TemplateCheckItemManagementPage.tsx`
- `src/pages/ccp/CcpFormPage.tsx`
- `src/pages/ccp/CcpGenericMonitorPage.tsx`
- `src/pages/ccp/ColdMonitorPage.tsx`
- `src/pages/ccp/MetalMonitorPage.tsx`
- `src/pages/ccp/VerificationCheckPage.tsx`
- `src/pages/doc/CorrectiveActionManagementPage.tsx`
- `src/pages/doc/DocumentBoxPage.tsx`
- `src/pages/doc/HwpDocumentEditorPage.tsx`
- `src/pages/doc/LegalDocumentUploadPage.tsx`
- `src/pages/hyg/HealthCertPage.tsx`
- `src/pages/hyg/HygieneCheckPage.tsx`
- `src/pages/ops/BizOpsFormPage.tsx`
- `src/pages/sys/SystemManagementPage.tsx`
- `src/pages/tsk/TodayTasksPage.tsx`

### 7.2 api

- `src/api/authApi.ts`
- `src/api/bizOpsApi.ts`
- `src/api/ccpColdApi.ts`
- `src/api/ccpFormsApi.ts`
- `src/api/ccpGenericApi.ts`
- `src/api/ccpMetalApi.ts`
- `src/api/ccpVerificationApi.ts`
- `src/api/codeApi.ts`
- `src/api/documentApi.ts`
- `src/api/equipmentHistApi.ts`
- `src/api/healthCertApi.ts`
- `src/api/http.ts`
- `src/api/hygieneApi.ts`
- `src/api/masterApi.ts`
- `src/api/menuApi.ts`
- `src/api/pestDeviceHistApi.ts`
- `src/api/prefApi.ts`
- `src/api/systemApi.ts`
- `src/api/taskWorkflowApi.ts`
- `src/api/viewLogApi.ts`
- `src/api/workflowApi.ts`

### 7.3 components

grid: MesEditableGrid · MesDataGrid · GridCrudButtons · GridChrome · useMesTable · gridCsv  
form: DocFormLayout · DocFormSearchToolbar · DocPaper · DocCell · DocFormMeta · DocSummaryPanel · DocRowToolbar · DocDeviationFooter · DocumentApprovalToolbar  
ui/layout: MesButton · Input · PageCard · PageHead · pageClasses  
shell: HaccpShell · SideMenu · screenRegistry · pageCommands · useViewLog · tabRoute

---

## §8 BE Mapper·Job

| Interface | XML |
|-----------|-----|
| com.metis.haccp.auth/AuthMapper | resources/mapper/auth/AuthMapper.xml |
| com.metis.haccp.menu/MenuMapper | resources/mapper/menu/MenuMapper.xml |
| com.metis.haccp.code/CodeMapper | resources/mapper/code/CodeMapper.xml |
| com.metis.haccp.pref/PrefMapper | resources/mapper/pref/PrefMapper.xml |
| com.metis.haccp.log/LogMapper | resources/mapper/log/LogMapper.xml |
| com.metis.haccp.bas/MasterMapper | resources/mapper/bas/MasterMapper.xml |
| com.metis.haccp.bas/EquipmentHistMapper | resources/mapper/bas/EquipmentHistMapper.xml |
| com.metis.haccp.bas/PestDeviceHistMapper | resources/mapper/bas/PestDeviceHistMapper.xml |
| com.metis.haccp.workflow/WorkflowMapper | resources/mapper/workflow/WorkflowMapper.xml |
| com.metis.haccp.ccp/CcpColdMapper | resources/mapper/ccp/CcpColdMapper.xml |
| com.metis.haccp.ccp/CcpGenericMapper | resources/mapper/ccp/CcpGenericMapper.xml |
| com.metis.haccp.ccp/CcpFormsMapper | resources/mapper/ccp/CcpFormsMapper.xml |
| com.metis.haccp.hyg/HygieneMapper | resources/mapper/hyg/HygieneMapper.xml |
| com.metis.haccp.hyg/HealthCertMapper | resources/mapper/hyg/HealthCertMapper.xml |
| com.metis.haccp.doc/DocumentMapper | resources/mapper/doc/DocumentMapper.xml |
| com.metis.haccp.doc/DocCorrectiveMapper | resources/mapper/doc/DocCorrectiveMapper.xml |
| com.metis.haccp.tsk/TaskMapper | resources/mapper/tsk/TaskMapper.xml |
| com.metis.haccp.sys/SystemMapper | resources/mapper/sys/SystemMapper.xml |
| com.metis.haccp.ops/BizOpsMapper | resources/mapper/ops/BizOpsMapper.xml |

비 REST: GlobalExceptionHandler · TemplateImportService(ApplicationRunner) · Actuator

---

## §9 교차검증

- SCREEN_REGISTRY 키 수 = **75**
- DEMO 활성 메뉴 leaf scrn_cd 수 = **72**
- 메뉴 scrn ⊆ 레지스트리: OK
- 갭: approval-history = 레지스트리 O / DEMO 메뉴 X
- React 18.3.1 · MyBatis 3.0.3 · Spring Boot 3.3.4 · Vite 5.4.8 · Java 17 — §0
- 비활성 대체 경로 §6.1 · Controller 19 · Job 2 · Mapper XML 19

### 9.1 레지스트리 키 전체

`today-tasks`, `company-management`, `user-management`, `department-management`, `role-management`, `menu-management`, `login-history`, `screen-usage-statistics`, `audit-log`, `common-code-management`, `product-management`, `material-management`, `partner-management`, `storage-management`, `measuring-device-management`, `vehicle-management`, `work-area-management`, `ccp-limit-management`, `equipment-management`, `pest-device-management`, `approval-line-management`, `hwp-template-management`, `schedule-cycle-management`, `daily-hyg-item-admin`, `ccp-cold-limit-admin`, `ccp-heat-limit-admin`, `ccp-sanitize-limit-admin`, `ccp-filter-limit-admin`, `ccp-metal-limit-admin`, `ccp-verify-standard-admin`, `facility-check-item-admin`, `daily-hygiene-check`, `pest-control-check`, `ccp-cold-monitor`, `ccp-metal-monitor`, `ccp-heat-monitor`, `ccp-sanitize-monitor`, `ccp-filter-monitor`, `ccp-verification-check`, `facility-equipment-check`, `health-cert-record`, `visitor-log`, `equipment-history`, `pest-device-history`, `visual-insp-standard`, `receiving-insp-hwp`, `submaterial-recv-hwp`, `calib-self-hwp`, `calib-ext-hwp`, `shipment-log-hwp`, `waste-hwp`, `inventory-hwp`, `edu-plan-hwp`, `edu-log-hwp`, `bad-product-hwp`, `claim-hwp`, `recall-hwp`, `eval-hwp`, `verify-ca-hwp`, `handover-hwp`, `process-hwp`, `vehicle-hwp`, `personal-hyg-hwp`, `area-hyg-hwp`, `water-hwp`, `verify-plan-hwp`, `verify-check-hwp`, `verify-report-hwp`, `prod-test-hwp`, `surface-test-hwp`, `document-inbox`, `approval-inbox`, `approval-history`, `legal-document-upload`, `corrective-action-management`

---

*코드·DB 변경 없는 스펙 보고 문서. 메뉴 DB 재시드는 별도 작업.*
