# HACCP FE·BE 통합 상세 스펙

> 정본: `15_HACCP_FE_BE_통합_상세스펙.md`  
> 작성일: 2026-08-21 · 개발자: 박승우  
> **이 파일은 사람이 읽는 이야기**다. 로그인·그리드 CRUD·DocForm·HWP leaf·삭제·배포를 문장과 다이어그램으로 쓴다. 태그 번호 전수는 [`23_PIPELINE.md`](23_PIPELINE.md).  
> 범위: **HACCP만** (`haccp-web` + `haccp-api` + `db_sasshaccp`). MES 제외.  
> 관련: [`00`](1_문서인덱스.md) · [`01`](4_운영규칙_BE.md) · [`04`](10_인증_보안_JWT_BE.md) · [`06`](13_업무_CRUD_BE.md) · [`07`](14_메뉴_화면_API_DB_전수.md) · [`09`](16_통합완성도_및_부족분.md) · 파일 찾는 법 [`10`](17_파일구조_컴포넌트_함수지도.md) · [`11` 파일·보안](18_프레임워크_파일_보안_작성규칙.md) · 경로 [`24`](24_URL_DB_폴더_패키지_정본.md)

---

## 0. 문서 목적·읽는 법

| 절 | 내용 |
|----|------|
| 1 | 스택·포트·환경변수 (버전 필수) |
| 2 | 런타임 아키텍처·요청 파이프라인 |
| 3 | 인증·권한·메뉴 · §3.4 멀티탭 · §3.5 그리드 pref/가상화 |
| 4 | 패키지·디렉터리 지도 (FE/BE/DB) |
| 5 | FE API 함수 ↔ HTTP URL 전수 (§5.7 BizOps G-15) |
| 6 | BE Controller 엔드포인트 전수 |
| 7 | 화면 유형별 통합 계약 (Page→API→Controller→Mapper→SP→Table) |
| 8 | 문서·결재 상태 기계 |
| 9 | 파일 볼륨·rhwp·타임아웃 4중 방어 (서명 UX는 **11 §2.8**) |
| 10 | 배치 Job·UV/PV |
| 11 | 운영 규약 (삭제·테넌트·응답) |
| 12 | 동결·갭·교차검증 |

메뉴 leaf 한 줄 표는 **14**가 정본이다. 폴더·패키지·URL은 **24**와 `SCREEN_PATH`다. 본 문서는 **호출 체인·계약·환경**을 더 깊게 적는다.

---

## 1. 스택·포트·환경

### 1.1 버전 (필수 명시)

| 층 | 항목 | 버전 |
|----|------|------|
| FE | React / react-dom | **18.3.1** |
| FE | Vite | **5.4.8** |
| FE | TypeScript | 5.6.2 |
| FE | react-router-dom | 6.26.2 |
| FE | Zustand | 5.0.0 |
| FE | TanStack Query / Table / Virtual | 5.59.0 / 8.20.5 / 3.14.5 |
| FE | axios | 1.7.7 |
| FE | Tailwind | 3.4.17 |
| FE | @rhwp/editor | 0.8.2 |
| FE | Node | ≥20 |
| BE | Java | **17** |
| BE | Spring Boot | **3.3.4** |
| BE | MyBatis Spring Boot Starter | **3.0.3** |
| BE | PostgreSQL JDBC | 42.7.4 |
| BE | JJWT | 0.12.6 |
| DB | PostgreSQL DB·스키마 | `sasshaccp` / `sasshaccp` |
| DB | SP | `sp_tbl_{의미}_{r\|c\|d\|u}_000` |

### 1.2 포트·베이스 URL

| 프로세스 | 기본 | 비고 |
|----------|------|------|
| haccp-web (Vite) | `http://localhost:4173` | mes-web 5173과 분리 |
| haccp-api | `http://localhost:7070` | 운영 컨테이너 listen 과 동일 |
| FE→BE | `VITE_API_BASE_URL` | 기본 `http://localhost:7070` |

### 1.3 FE env (`frontend/haccp-web/.env.example`)

| 키 | 기본 | 용도 |
|----|------|------|
| VITE_API_BASE_URL | http://localhost:7070 | API 루트 |
| VITE_API_TIMEOUT_DEFAULT | 10000 | http (일반 CRUD) |
| VITE_API_TIMEOUT_BATCH | 60000 | httpBatch |
| VITE_API_TIMEOUT_FILE | 120000 | httpFile (HWP/PDF) |
| VITE_GRID_DEFAULT_PAGE_SIZE | 50 | **예약**(클라 페이징 미사용) — G-23 |
| VITE_GRID_VIRTUAL_THRESHOLD | 100 | 가상화 임계 — Mes*Grid `shouldVirtualize` |
| VITE_SEARCH_DEBOUNCE_MS | 300 | 검색 디바운스 |
| VITE_API_RETRY_COUNT | 2 | GET 재시도 |
| VITE_DASHBOARD_POLLING_MS | 10000 | 폴링 |
| VITE_VIEW_LOG_FLUSH_MS | 30000 | UV/PV 배치 전송 |
| VITE_TOAST_DURATION_MS | 2600 | 토스트 |
| VITE_TOAST_ERROR_DURATION_MS | 5000 | 오류 토스트 |

### 1.4 BE env (`backend/haccp-api/.env.example`)

| 키 | 용도 |
|----|------|
| SERVER_PORT | 7070 |
| DB_* / DB_URL | PG sasshaccp (`currentSchema=sasshaccp&escapeSyntaxCallMode=callIfNoReturn`) |
| HIKARI_* | 커넥션 풀 |
| TX_DEFAULT_TIMEOUT_SECONDS / MYBATIS_STATEMENT_TIMEOUT_SECONDS | 60 |
| JWT_SECRET / JWT_EXPIRE_MINUTES | HS512 ≥64B / 480분 |
| LOGIN_MAX_FAIL_COUNT | 5 |
| APP_TIMEZONE | Asia/Seoul |
| TASK_GENERATION_CRON | 0 5 0 * * * |
| VIEW_STAT_DAILY_CRON | 0 15 0 * * * |
| VIEW_STAT_DAILY_RUN_ON_STARTUP | false (로컬 스모크만 true) |
| CORS_ALLOWED_ORIGINS | http://localhost:4173 |
| APP_FILE_ROOT / APP_FILE_MAX_* | 파일 볼륨 |
| APP_TEMPLATE_* | 표준 HWP 볼륨·매니페스트 |
| APP_RHWP_* | CLI PDF 변환 |

---

## 2. 런타임 아키텍처

```mermaid
flowchart TB
  Browser["Browser Vite:4173"]
  Shell["HaccpShell + SideMenu + Tabs"]
  Reg["SCREEN_REGISTRY"]
  Page["Page Component"]
  Api["src/api/* Axios"]
  Ctrl["@RestController"]
  Svc["@Service"]
  Map["MyBatis Mapper + XML"]
  SP["PostgreSQL sp_tbl_*"]
  Vol["APP_FILE_ROOT volume"]

  Browser --> Shell
  Shell --> Reg
  Reg --> Page
  Page --> Api
  Api -->|"JWT Bearer"| Ctrl
  Ctrl --> Svc
  Ctrl --> Map
  Svc --> Map
  Map --> SP
  Svc --> Vol
```

### 2.1 요청 파이프라인 (상세)

태그 번호 전수는 [`23_PIPELINE.md`](23_PIPELINE.md). 여기는 이야기만.

1. 브라우저 주소 = Vite basename `/haccp/` + 라우터 pathname (예: `/docs/ccp/ccp-cold-monitor`). pathname에 `/haccp`를 다시 넣지 않는다. `/screen/{scrnCd}` 없음.  
2. `tabRoute.parseRoute` → `scrnCd` → `openTab` · `SCREEN_REGISTRY[scrnCd]` keep-alive. 맵에 없으면 셸이 오늘 할 일.  
3. `isImplemented(scrnCd)` — 레지스트리 없으면 메뉴 비활성(숨기지 않음)  
4. Page 마운트 → `PageScrnContext`에 scrnCd → `useAuthStore.can(scrnCd, write|modify|delete|…)`  
5. `usePageCommands` — 셸 상단 조회/신규/저장/삭제 (화면별 등록)  
6. API: `http` / `httpFile` / `httpBatch` + Bearer JWT  
7. BE: `JwtFilter` → Controller → (Service) → Mapper CALL/SELECT SP  
8. 응답: `CommonResponse<T>` `{ success, data, message }` · 예외는 `GlobalExceptionHandler` → 업무 문구  

탭: `ShellTabBar` + `tabStore`. 닫기는 `afterRemove` 한 번. `navigate`는 셸 `onTabClosed`. 활성 탭이 지워지면 오른쪽 → 왼쪽 → `/`. 홈 탭 고정 없음.

### 2.2 FE 레이어

| 경로 | 역할 |
|------|------|
| `src/shell/*` | 셸·메뉴·탭·명령·뷰로그·다이얼로그 |
| `src/pages/*` | 화면 (도메인별) |
| `src/api/*` | REST 클라이언트 |
| `src/components/grid|form|document|layout|ui` | 공용 UI |
| `src/hooks/*` | useEditableRows · useGridAccess · useAsyncAction |
| `src/stores/authStore` | JWT·권한·can() |
| `src/config/envConfig.ts` | env 파싱 (매직넘버 금지) |

### 2.3 BE 레이어

| 패키지 | 역할 |
|--------|------|
| `auth` | 로그인·JWT·잠금 |
| `menu` `code` `pref` `log` | 셸 API (Controller→Mapper 직결 가능) |
| `bas` | 마스터·설비/방충 이력 |
| `workflow` | 결재선·양식·점검항목·주기·법적유형 |
| `docs` `flow` `bas` `sys` `tsk` | 업무. 화면 패키지는 `com.haccp.{대}.{중}` (`docs.ccp`·`docs.hwp`·`sys.code` …). 공유 허브 `docs.document` · `docs.template` |
| `common` | LoginUserContext · BizException · DeleteValidation · response |

DI: `@RequiredArgsConstructor` + `private final`. CUD는 `@Transactional` (로그인 제외).

---

## 3. 인증·권한·메뉴

### 3.1 로그인 흐름

```mermaid
sequenceDiagram
  participant UI as LoginPage
  participant API as AuthController
  participant SP as sp_tbl_user_login_r_000
  participant FE as authStore
  participant Menu as MenuController

  UI->>API: POST /api/v1/auth/login {userId,userPw}
  API->>SP: 검증·회사 판정
  API-->>UI: token + user + screenAuth[]
  UI->>FE: persist JWT
  FE->>Menu: GET /api/v1/menu/list
  Menu-->>FE: 트리 (read_yn 반영)
```

| API | FE | 비고 |
|-----|-----|------|
| POST `/api/v1/auth/login` | `authApi.login` | 공개 (JwtFilter 예외) |
| POST `/api/v1/auth/logout` | `authApi.logout` | 이력 |
| GET `/api/v1/auth/me` | `authApi.me` | 세션 복구 |

- 로그인: **아이디만** (회사는 서버 판정, MES와 다름)  
- JWT 클레임: coCd, coNm, userId, userNm, usrgrpCd, deptCd, deptNm, sid  
- 관리자: `usrgrpCd == "ADMIN"`  
- 연속 실패 → `LOGIN_MAX_FAIL_COUNT` 잠금  

### 3.2 화면 권한 5종

`tbl_role_screen`: read_yn · write_yn · modify_yn · delete_yn · print_yn  

| FE | 의미 |
|----|------|
| `can(scrn, "read")` | 메뉴 노출 (서버에서 이미 필터) |
| write | 행추가 |
| modify | 기존행 편집 |
| delete | 삭제 |
| print | 출력/PDF |

그리드 잠금: `useGridAccess` + Page rules (`*.rules.ts`).

### 3.3 메뉴 로딩

| 단계 | 구현 |
|------|------|
| DB | tbl_menu (co_cd) JOIN 권한 |
| SP | `sp_menu_nav_r_000` |
| API | GET `/api/v1/menu/list` |
| FE | `menuApi` → `SideMenu` |
| 구현 여부 | `isImplemented(scrnCd)` ← SCREEN_REGISTRY |

회사 생성: `sp_tbl_company_init_c_000` — `tbl_screen.use_yn=Y` AND module ∈ {WRK,APR,FRM,COD,SYS}.

IA 대메뉴: today-tasks + MWRK / MAPR / MFRM / MCOD / MSYS (migrate 36).

### 3.4 멀티탭 로그아웃 (G-22 · MES F174)

MES `OPS_AUTH_CROSSTAB`과 동일 패턴. 키 접두만 `haccp-*` (MES `mes-*`와 혼용 금지).

```mermaid
sequenceDiagram
  participant T1 as 탭1
  participant LS as localStorage
  participant T2 as 탭2

  T1->>T1: clearAuthSession
  T1->>LS: setItem haccp-auth-logout-signal
  T1->>T1: authStore.logout · tab reset · RQ clear
  LS-->>T2: storage 이벤트
  T2->>T2: subscribeAuthCrossTab → handleUnauthorized
  T2->>T2: location.replace(loginBrowserPath)
```

| 단계 | 파일 · 심볼 | 비고 |
|------|-------------|------|
| 수동 로그아웃 | `HaccpShell.onLogout` → `logoutApi` → `clearAuthSession` → `nav("/login")` | Router basename 상대 |
| 신호 송신 | `broadcastAuthLogout` | **항상 localStorage** (자동로그인 OFF·sessionStorage여도 신호는 local) |
| 신호 키 | `AUTH_LOGOUT_SIGNAL_KEY=haccp-auth-logout-signal` | `authKeys.ts` |
| 2차 감지 | `AUTH_STORAGE_KEY=haccp-auth` 삭제·토큰 공백 | 신호 유실 대비 |
| 구독 | `main.tsx` → `subscribeAuthCrossTab` | 로그인 화면이면 no-op (`isLoginBrowserPath`) |
| 타 탭 정리 | `handleUnauthorized` | `authPaths.loginBrowserPath` 로 replace — **Vite base `/haccp/` 정합** |
| 복귀 URL | `toRouterPath` 후 `saveReturnUrl` | browser `/haccp/...` → 라우터 `/...` |

**Path 갭(STEP 24 수정):** 하드코딩 `location.replace("/login")`·`pathname === "/login"` 은 Apache Path 배포에서 `/haccp/login` 과 불일치 → 타 탭이 잘못된 origin 경로로 튕기거나 중복 처리됨. `shell/authPaths.ts` 로 통일.

**검증:** `npm test` — `authPaths.test.ts` · `authCrossTab.test.ts`. 수동 2탭: 동일 계정 로그인 → 탭1 로그아웃 → 탭2가 `/haccp/login`(또는 로컬 `/login`)으로 이동·이후 API는 미인증.

판정: [`09` G-22](16_통합완성도_및_부족분.md).

### 3.5 그리드 pref · 가상화 (G-23)

| 항목 | 정본 |
|------|------|
| 가상화 임계 | `VITE_GRID_VIRTUAL_THRESHOLD` → `GRID_VIRTUAL_THRESHOLD` → `shouldVirtualize` (`useGridVirtual`) |
| 기본값 | **100**행 이상이면 TanStack Virtual 활성 (`MesEditableGrid` · `MesDataGrid`) |
| 페이지 크기 env | `VITE_GRID_DEFAULT_PAGE_SIZE` — **클라 페이징 미사용(예약)**. 목록은 전체 조회 + 가상 스크롤 |
| pref 저장 | `persistId` + `PageScrnContext.scrnCd` → `prefApi` (`/api/v1/pref/grid/*`) · JSON v2(hidden/order/sizing) |
| pref 미저장 | `persistId` 없거나 셸 밖(scrnCd 공백) — 세션만 |

**대량 화면 스모크(코드 경로 · STEP 25)**

| 화면 | scrn_cd | persistId | 그리드 | 가상화 | pref |
|------|---------|-----------|--------|--------|------|
| 문서함 | `document-inbox` | `doc-document-inbox` | MesEditableGrid | displayRows≥100 | O (셸 Provider) |
| 변경 감사 로그 | `audit-log` | `log-audit-log` | MesDataGrid (LogPageShell) | 동일 | O |
| 설비 이력 | `equipment-history` | `bas-equipment-history-master` · `-detail` | MesEditableGrid×2 | 동일 | O |

편차(허용): `ROW_ESTIMATE_PX=28` 은 estimateSize 고정(가상화 보정용) — env 미이관. 크리티컬 버그 없음.  
단위: `useGridVirtual.test.ts` · `gridPref.test.ts`. 수동: 행≥100에서 스크롤 부드러움·열 숨김 후 재진입 유지.

판정: [`09` G-23](16_통합완성도_및_부족분.md).

---

## 4. 디렉터리 지도

### 4.1 FE pages

| 폴더 | 화면 |
|------|------|
| pages/auth | LoginPage |
| pages/tsk | TodayTasksPage |
| pages/sys/code | commoncode/ · menu/ · role/ · department/ · user/ · approvalline/ |
| pages/sys/logs | loginhistory/ · auditlog/ · screenusage/ |
| pages/bas/master | MasterDataPage (7종) |
| pages/docs/hwp | 사용양식 · 공용 HWP 에디터 |
| pages/docs/sch | 문서주기 |
| pages/docs/ccp | Cold · Generic · Metal · Verification · CcpFormPage · process-hwp |
| pages/docs/prp | Hygiene · HealthCert · BizOps · 설비/방충 이력 · PRP HWP leaf |
| pages/docs/html | HTML양식 원본 5화면 · hygprocess 작성 |
| pages/docs/logis · admin | 물류·운영 HWP leaf |
| pages/flow/box | DocumentBox · LegalDocumentUpload |
| pages/flow/appr | 결재함·이력은 DocumentBox mode |
| pages/flow/ca | CorrectiveAction |

### 4.2 FE api

authApi · menuApi · codeApi · prefApi · viewLogApi · http  
api/sys/* · masterApi · equipmentHistApi · pestDeviceHistApi · workflowApi  
documentApi · hygieneApi · healthCertApi · ccpColdApi · ccpFormsApi · ccpGenericApi · bizOpsApi · taskWorkflowApi · hwpTemplateApi · docCycleApi

### 4.3 BE java 패키지 ↔ mapper XML

`src/main/java/com/haccp/{대}/{중}` ↔ `resources/mapper/{대}/{중}/*.xml`. 정본 [`24`](24_URL_DB_폴더_패키지_정본.md).

### 4.4 DB

| 번호대 | 내용 |
|--------|------|
| 00~08 | schema · ddl · indexes |
| 09~10 | seed |
| 11~22 | SP |
| 23~47 | migrate (IA·문서·admin·legal·viewstat 관련) |

---

## 5. FE API 함수 ↔ HTTP 전수

### 5.1 셸·공통

| FE 함수 | Method | URL | 클라이언트 |
|---------|--------|-----|------------|
| auth login/logout/me | POST/POST/GET | `/api/v1/auth/*` | http |
| menu list | GET | `/api/v1/menu/list` | http |
| code list | GET | `/api/v1/code/list?mainCd=` | http |
| pref grid list/save | GET/PUT | `/api/v1/pref/grid/{list,save}` | http |
| collectViewLogs | POST | `/api/v1/log/view/collect` | http (실패 무시) |

### 5.2 api/sys (화면 1개 = 파일 1개)

| FE | Method | URL |
|----|--------|-----|
| commonCodeApi | GET/PUT/POST | `/api/v1/sys/code/common-code-management/{groups,details,save,validate-delete,delete}` |
| menuApi | GET/PUT/POST | `/api/v1/sys/code/menu-management/{list,save,validate-delete,delete}` |
| roleApi | GET/PUT/POST | `/api/v1/sys/code/role-management/{list,save,validate-delete,delete}` · screens |
| departmentApi | GET/PUT/POST | `/api/v1/sys/code/department-management/{list,save,validate-delete,delete}` |
| userApi | GET/PUT/POST | `/api/v1/sys/code/user-management/{list,save,validate-delete,delete}` · `/users/{id\|me}/sign` |
| loginHistoryApi | GET | `/api/v1/sys/logs/login-history/list` |
| auditLogApi | GET | `/api/v1/sys/logs/audit-log/list` |
| screenUsageApi | GET | `/api/v1/sys/logs/screen-usage-statistics/list` |

이력 3종은 list만. 서명은 `userApi`가 소유한다. `company-management`는 온보딩 외 미노출.

### 5.3 masterApi · 이력

| FE | URL |
|----|-----|
| list/save/validate/delete Master | `/api/v1/bas/{type}/*` type=product\|material\|partner\|storage\|equipment\|measuring-device\|pest-device\|vehicle\|work-area\|ccp-limit |
| equipment photo | POST `/api/v1/bas/equipment/{idx}/photo` |
| equipmentHist list/save/del | `/api/v1/docs/prp/equipment-history/*` |
| pestDeviceHist list/save/del | `/api/v1/docs/prp/pest-device-history/*` |

### 5.4 workflowApi

| FE | URL |
|----|-----|
| approval-lines CRUD | `/api/v1/sys/code/approval-line-management/{list,save,validate-delete,delete}` |
| company-templates | list/save/validate-delete/delete · create-custom(multipart) |
| saveLegalType | PUT `/api/v1/bas/legal-types/save` |
| company-check-items | list?tmplCd · save · validate-delete · delete |
| company-forms | list · clone · activate · form-items list/save |
| hwp-templates | `/api/v1/docs/hwp/hwp-template-management/{list,save,files,apply-file}` — 사용양식 목록·저장·파일이력·불러오기/초기화 |
| schedule-rules | list/save/validate-delete/delete (구 단일 그리드 API — 화면은 5.9 doc-cycles 사용) |
| template-export-hist | list · get · export · import |
| ~~smart-diary~~ | **폐기** (STEP 20 / G-14) — BE 엔드포인트 제거. DB DROP은 별도 승인 |

### 5.5 documentApi

| FE | URL | 클라이언트 |
|----|-----|------------|
| listDocumentTemplates | GET `/api/v1/docs/templates/list` | http |
| loadHwpTemplateFile(formUrl) | GET formUrl | httpFile blob |
| saveHwpTemplateForm | POST `/api/v1/docs/templates/{tmplCd}/form` | httpFile |
| listDocuments | GET `/api/v1/docs/documents/list` | http |
| listApprovalInbox/History | GET `…/approval-inbox` · `…/approval-history` | http |
| getDocumentDetail | GET `…/documents/{docIdx}` | http |
| saveHwpDocument | PUT `…/documents/hwp/save` | http |
| uploadDocumentFile | POST `…/{docIdx}/files` | httpFile |
| downloadDocumentFile | GET `…/files/{fileIdx}/download` | httpFile |
| exportDocumentPdf | POST `…/{docIdx}/export-pdf` | httpFile |
| processDocumentApproval | PUT `…/documents/approval` | http |
| validate/delete Document | POST validate-delete · delete | http |
| fetchMySignImage | GET `/api/v1/sys/users/me/sign` | httpFile |

### 5.6 작성 도메인 API

| 모듈 | FE | Base |
|------|-----|------|
| hygieneApi | list/detail/save/validate/delete | `/api/v1/docs/prp/{daily-hygiene-check\|pest-control-check}/*` |
| healthCertApi | list/save/del + upload file | `/api/v1/docs/prp/health-cert-record/*` |
| ccpColdApi | list/detail/save/del | `/api/v1/docs/ccp/ccp-cold-monitor/*` |
| ccpFormsApi | list/detail/save/del | `/api/v1/docs/ccp/{ccp-metal-monitor\|ccp-verification-check}/*` |
| ccpGenericApi | templates · get · save · del | `/api/v1/docs/ccp/{ccp-heat-monitor\|ccp-sanitize-monitor\|ccp-filter-monitor}/*` |
| bizOpsApi | list/detail/save/del | `/api/v1/docs/prp/{facility-equipment-check\|calibration-target-management}/*` — HTML 2종만 (§5.7) |
| taskWorkflowApi | today-tasks · notifications · corrective · relations · audit-export(동결) | `/api/v1/tsk/*` · `/api/v1/flow/ca/corrective-action-management/*` |
| api/docs/docCycleApi | forms(좌측 목록) · get · save · validate-delete · delete | `/api/v1/docs/sch/schedule-cycle-management/*` — 저장 시 서버가 예정일 재생성 |

### 5.7 BizOps HTML 2종 (G-15)

`BizOpsController`는 **시설·검교정 2 base × (list/detail/save/validate-delete/delete)** 만 둔다. 폐기·재고·입고·공정 HTML API는 삭제했고, 그 화면은 `documentApi`(+rhwp)만 호출한다.

| screenCode | API base | BE 상태 | FE 작성 UI | tmpl_cd | 비고 |
|------------|----------|---------|------------|---------|------|
| `facility-equipment-check` | `/api/v1/docs/prp/facility-equipment-check` | 사용 | `BizOpsFormPage` 레지스트리 | `html_sys_009` | 메뉴 활성 HTML |
| `calibration-target-management` | `/api/v1/docs/prp/calibration-target-management` | 사용 | `BizOpsFormPage` (메뉴 숨김 · 레지스트리·`/docs/prp/`만) | `html_sys_010` | 문서함 deep-link · 자체/외부 검교정 HWP는 `calib-*-hwp` |

**코드 삭제 (2026-08-19)**

| 구 screenCode | 구 API | 현재 |
|---------------|--------|------|
| `waste-disposal-check` | `/api/v1/fac/waste-disposal-check` | `waste-hwp` / `hwp_sys_015` |
| `inventory-check` | `/api/v1/inv/inventory-check` | `inventory-hwp` / `hwp_sys_016` |
| `receiving-inspection` | `/api/v1/inv/receiving-inspection` | `receiving-insp-hwp` / `hwp_sys_017` |
| `process-control-check` | `/api/v1/prc/process-control-check` | `process-hwp` / `hwp_sys_028` |

메뉴·이관 한 줄 표 교차: [`07` §6.1·§6.4](14_메뉴_화면_API_DB_전수.md). 판정: [`09` G-15](16_통합완성도_및_부족분.md).

---

## 6. BE Controller 엔드포인트 전수

### 6.1 요약 표

| Controller | Base | 메서드 수(대략) |
|------------|------|----------------|
| AuthController | /api/v1/auth | 3 |
| MenuController | /api/v1/menu | 1 |
| CodeController | /api/v1/code | 1 |
| PrefController | /api/v1/pref/grid | 2 |
| ViewLogController | /api/v1/log/view | 1 |
| MasterController | /api/v1/bas | 5 |
| EquipmentHistController | /api/v1/docs/prp/equipment-history | 4 |
| DocCycleController (`docs.sch`) | /api/v1/docs/sch/schedule-cycle-management | 5 |
| HwpTemplateController (`docs.hwp`) | /api/v1/docs/hwp/hwp-template-management | 4 |
| PestDeviceHistController | /api/v1/docs/prp/pest-device-history | 4 |
| WorkflowController | /api/v1/bas | 30+ |
| CcpColdController | /api/v1/docs/ccp/ccp-cold-monitor | 5 |
| CcpGenericController | /api/v1/docs/ccp/{ccp-heat-monitor\|ccp-sanitize-monitor\|ccp-filter-monitor} | 5 |
| CcpFormsController | /api/v1/docs/ccp/{ccp-metal-monitor\|ccp-verification-check} | 5 |
| HygieneController | /api/v1/docs/prp/{daily-hygiene-check\|pest-control-check} | 5 |
| HealthCertController | /api/v1/docs/prp/health-cert-record | 5 |
| DocumentController | /api/v1/docs/documents | 11 |
| TemplateController | /api/v1/docs/templates | 3 |
| TaskController | (full path) | 11 |
| CommonCodeController | /api/v1/sys/code/common-code-management | 4 |
| MenuMgmtController | /api/v1/sys/code/menu-management | 4 |
| RoleMgmtController | /api/v1/sys/code/role-management | 6 |
| DepartmentController | /api/v1/sys/code/department-management | 4 |
| UserController | /api/v1/sys/code/user-management · /users | 8 |
| LoginHistoryController | /api/v1/sys/logs/login-history | 1 |
| AuditLogController | /api/v1/sys/logs/audit-log | 1 |
| ScreenUsageController | /api/v1/sys/logs/screen-usage-statistics | 1 |
| BizOpsController | 2 bases × 5 | 10 |

합계: sys는 화면 1개 = Controller 1개로 분할. 나머지 도메인은 기존 표와 같다.

### 6.2 DocumentController 상세

| Method | Path | 역할 |
|--------|------|------|
| GET | /list | 문서함·작성 목록 |
| GET | /approval-inbox | 내 차례 결재 |
| GET | /approval-history | 결재·변경 이력 |
| GET | /{docIdx} | 상세(헤더·결재·파일·버전) |
| PUT | /hwp/save | HWP 헤더 저장 → docIdx |
| POST | /{docIdx}/files | 첨부 multipart (HWP_SRC/PDF/ATTACH/PHOTO) |
| POST | /{docIdx}/export-pdf | rhwp CLI 변환 |
| GET | /files/{fileIdx}/download | 다운로드 |
| PUT | /approval | REQUEST/REVIEW/APPROVE/REJECT/CANCEL |
| POST | /validate-delete · /delete | OPS_DELETE |

### 6.3 WorkflowController 상세 그룹

- approval-lines · company-templates · **legal-types/save** · company-check-items  
- company-forms / form-items / clone / activate  
- schedule-rules · ~~smart-diary-*~~(STEP 20 폐기) · template-export-hist · audit-export(동결)  

---

## 7. 화면 유형별 통합 계약

### 7.1 유형 분류

| 유형 | FE Page | FE API | BE | 대표 SP/테이블 |
|------|---------|--------|-----|----------------|
| A 시스템 CRUD | CommonCode·Menu·Role·Department·User·ApprovalLine Page | api/sys/{공통코드·메뉴·권한·부서·사용자·결재선}Api | CommonCode·MenuMgmt·RoleMgmt·Department·User·ApprovalLine Controller | sp_{화면명}_* · sp_tbl_approval_line_* |
| B 시스템 이력 | LoginHistory·AuditLog·ScreenUsage Page (LogPageShell) | loginHistoryApi · auditLogApi · screenUsageApi | LoginHistory·AuditLog·ScreenUsage Controller | login_log · view_stat_daily · audit_log |
| C 기초 마스터 | MasterDataPage | masterApi | MasterController | sp_tbl_master_* |
| D CCP 한계 admin | MasterDataPage | masterApi ccp-limit | MasterController | sp_tbl_ccp_limit_* |
| E 설비/방충 이력 M-D | Equipment/Pest HistoryPage | master+hist API | Master+HistController | equipment_hist / pest hist |
| F 주기·점검항목 | Schedule · TemplateCheckItem | docCycleApi · workflowApi | DocCycleController · WorkflowController | 85/96 cycle · 18_sp_workflow |
| G HWP 양식관리 | docs/hwp/HwpTemplateManagementPage | document+hwpTemplateApi | Template+HwpTemplate (삭제는 Workflow 잔류) | company_template · form file |
| H 위생 DB | HygieneCheckPage | hygieneApi | HygieneController | sp_tbl_hygiene_document_* |
| I 냉장 CCP | ColdMonitorPage | ccpColdApi | CcpColdController | sp_tbl_ccp_cold_monitor_* |
| J 금속/검증 CCP | CcpFormPage | ccpFormsApi | CcpFormsController | sp_tbl_ccp_form_* |
| K 가열·멸균·여과 | CcpGenericMonitorPage | ccpGenericApi | CcpGenericController | generic monitor SP |
| L 시설·검교정 HTML | BizOpsFormPage | bizOpsApi | BizOpsController | sp_tbl_biz_ops_* html_sys_009/010 (§5.7) |
| M 건강진단 | HealthCertPage | healthCertApi | HealthCertController | sp_tbl_health_cert_* |
| N HWP leaf | HwpDocumentEditorPage | documentApi | Document+Template | document · hwp_document_c (폐기물·재고·입고·공정 등 구 BizOps 이관 포함) |
| O 문서함/결재 | DocumentBoxPage | documentApi | DocumentController | document list/inbox |
| P 법적서류 M-D | LegalDocumentUploadPage | document+workflow | Template+Document+Workflow | legal_type · templates · documents |
| Q 개선조치 | CorrectiveActionManagementPage | taskWorkflowApi | TaskController | corrective_action |
| R 오늘할일 | TodayTasksPage | taskWorkflowApi | TaskController | today_task |

### 7.2 작성 화면 공통 UI 체인 (DB형)

```
Page
 ├─ DocFormSearchToolbar (기간·문서번호·작성자)
 ├─ DocFormLayout / DocPaper / DocCell*
 ├─ MesEditableGrid (항목 행)
 ├─ DocumentApprovalToolbar (writerActionsOnly: 상신·취소)
 ├─ DocDeviationFooter (이탈·개선)
 └─ usePageCommands(add/save/del/search)
```

권한: PageScrnContext scrn_cd. 결재 검토·승인은 **결재함**만.

### 7.3 HWP leaf 체인

```
화면별 thin Page → HwpDocumentEditorPage
 ├─ 목록 MesEditableGrid (tmpl 고정 필터)
 ├─ rhwp editor (@rhwp/editor)
 ├─ saveHwpDocument → uploadDocumentFile(HWP_SRC)
 ├─ exportDocumentPdf (선택)
 └─ DocumentApprovalToolbar (상신·취소)
```

양식 원본: GET/POST `/api/v1/docs/templates/{tmplCd}/form` (form_path 없으면 400 — 법적유형은 formUrl 생략).

### 7.4 법적서류 M-D 체인

| 패널 | FE | BE |
|------|-----|-----|
| 좌 양식 | saveLegalType · saveHwpTemplateForm · company-templates delete · templates form download | Workflow legal-types · Template form · company-templates |
| 우 문서 | saveHwpDocument · uploadDocumentFile · downloadDocumentFile · document delete | DocumentController |
| 셸 Cmds | search만 (CRUD는 패널 GridCrudButtons) | — |

### 7.5 마스터·이력 삭제 키

| 리소스 | validate/delete Body |
|--------|----------------------|
| master | `[{ idx }]` 또는 타입별 키 |
| equipment-hist / pest-hist | `[{ idx }]` |
| approval-lines | `[{ apprLineCd }]` |
| company-templates | `[{ tmplCd }]` |
| company-check-items | `[{ tmplCd, itemCd }]` |
| schedule-rules | `[{ idx }]` |
| doc-cycles | `[{ tmplCd }]` — 양식당 주기 1건이라 대리키가 아니라 양식코드다 |
| documents / ccp / hyg / bizops | `[{ docIdx }]` |
| health-cert | `[{ idx }]` |
| corrective | `[{ idx }]` |

규칙: **객체 배열** · 스칼라 배열 금지 · FE·BE 양쪽 assertDeletable(더블체크).

---

## 8. 문서·결재 상태 기계

### 8.1 status 코드

| 코드 | 의미 |
|------|------|
| WRK | 작성중 |
| REQ | 검토요청(상신) |
| REV | 검토완료 |
| APV | 승인완료 |
| RJT | 반려 |

### 8.2 approval action (PUT `/documents/approval`)

| action | 결과 상태(요지) | 누가 |
|--------|-----------------|------|
| REQUEST | WRK/RJT → REQ | 작성자 |
| CANCEL | REQ → WRK (서명 후 차단 등 SP 33) | 작성자 |
| REVIEW | REQ → REV | 검토자 |
| APPROVE | → APV | 승인자 |
| REJECT | → RJT | 검토/승인 |

정본 SP: `sp_tbl_document_approval_c_000` (`15_sp_doc.sql` + migrate **33**).

### 8.3 작성 vs 결재 UI

| 화면 | 툴바 |
|------|------|
| 작성 DB/HWP | writerActionsOnly — 상신·취소 |
| approval-inbox | 검토·승인·반려 |
| document-inbox | 상신·취소 + 「작성화면」 deep-link |

Deep-link: `routeOf(scrnCd) + ?docIdx=` — `documentNav.routeForDocument` (`tmplCd`→`scrnCd`). 브라우저에는 basename `/haccp/`가 붙는다. `/screen/` 없음.

---

## 9. 파일 볼륨·rhwp·타임아웃

### 9.1 볼륨 레이아웃 (개념)

```
APP_FILE_ROOT/
  HaccpTemplates/{tmplCd}/{한글파일}.hwp        # 전 회사 공통 표준 양식 (DB에 바이너리 없음)
  CustomTemplates/{coCd}/{tmplCd}/{파일}       # 회사 커스텀 양식
  HaccpLogBooks/{coCd}/{yyyy-MM-dd}/{tmplCd}/  # 작성 문서 첨부·PDF·설비 사진
    {uuid}_{원본명}
```

사용자 서명은 파일이 아니라 `tbl_user.sign_img bytea` — 볼륨에 두지 않는다.

사용양식 업로드는 덮어쓰지 않는다. `CustomTemplates/{coCd}/{tmplCd}/` 안에 `{안전파일명}_{yyyyMMddHHmmss}.{확장자}` 로 버전이 공존하고,
`tbl_company_template_file` 이력의 `current_file_idx`(현재 적용) · `default_file_idx`(초기화 복원 대상)만 바뀐다.

- TemplateImportService(ApplicationRunner): APP_TEMPLATE_IMPORT_ROOT + manifest.tsv  
- formPath는 서버 전용 — API는 formUrl만  

### 9.2 타임아웃 4중 방어 (배치 60s 기준)

1. FE httpBatch/File timeout (env) — 배치 60s · 파일 120s  
2. Nginx `proxy_read_timeout` — 일반 `/api/` **70s**, 파일·PDF 경로 **130s**  
   (`nginx/haccp.conf.template`, 배포 런북 §10.2)  
3. Spring `@Transactional(timeout=60)`  
4. MyBatis `default-statement-timeout: 60`  

파일: FE 120s · rhwp CLI `APP_RHWP_TIMEOUT_SECONDS` 110 · Nginx Grace(파일) 130s.

서명 등록·HWP 클립보드·CCP 행 적용·실패 안내는 **[`11` §2.8](18_프레임워크_파일_보안_작성규칙.md)** (G-24).

### 9.3 MesButton variant (FE)

search(blue) · add(amber) · save(blue) · danger(red) · excel(emerald) · **download(indigo)** · secondary/ghost.

---

## 10. 배치 Job·UV/PV

```mermaid
flowchart LR
  FE["useViewLog buffer"] -->|POST collect| VL["tbl_view_log"]
  Job["ViewStatDailyJob 00:15"] -->|sp_tbl_view_stat_daily_c_000| ST["tbl_view_stat_daily"]
  UI["screen-usage-statistics"] -->|GET sys list| ST
  TaskJob["DailyTaskGenerationJob 00:05"] --> Tasks["today tasks"]
```

| Job | cron | Service |
|-----|------|---------|
| DailyTaskGenerationJob | TASK_GENERATION_CRON | TaskService.generateAllCompanies |
| ViewStatDailyJob | VIEW_STAT_DAILY_CRON | ViewStatService.aggregateYesterdayAndToday |

수집 실패는 업무를 막지 않음 (ViewLogController warn만).

---

## 11. 운영 규약 (HACCP 적용)

| 규약 | 내용 |
|------|------|
| OPS_DELETE | HTTP DELETE 금지 · validate→delete · Body 객체배열 · BE Double Check |
| 테넌트 | co_cd/user_id 요청 본문 금지 — LoginUserContext만 |
| 응답 | CommonResponse · SP CALL 건수 미반환 |
| 에러 | 사용자=업무문구 / 로그=기술상세 |
| 매직넘버 | env / application.yml / envConfig만 |
| 인수인계 주석 | FE=BE 동일 밀도 (05-handoff) |
| 이모지 | 소스·UI·문서 금지 |

---

## 12. 동결·갭·검증

### 12.1 동결 (의도적 미노출)

- ~~스마트일지 유형~~ — **API 폐기 완료** (STEP 20). DB `tbl_smart_diary_*` DROP은 후속 승인  
- 감사추출 UI (TaskController `audit-export` **동결 유지** · `@Deprecated` · FE 미노출) — `audit-log`와 별개  
- 범용 template-check-item-management (use_yn=N)  
- 단독 hwp-document-editor 메뉴  
- LAW/EDU/TST 개별 leaf  
- **법적서류 인페이지 PDF/HWP 미리보기** — **동결(의도)** (STEP 27 / G-25). 다운로드만 · [`11` §2.9](18_프레임워크_파일_보안_작성규칙.md)

### 12.2 알려진 갭

상세·우선순위·백로그는 **[`09_통합완성도_및_부족분.md`](16_통합완성도_및_부족분.md)** 정본.

| ID | 항목 | 상태 |
|----|------|------|
| G-01 | approval-history | FE O · DEMO 메뉴 leaf 없을 수 있음 |
| G-03 | migrate 47 이중 파일 | 적용 순서 주의 |
| G-13 | MasterData equipment/pest · ccpMetal/VerificationApi | **완료** — 2026-08-10 STEP 01 삭제 |
| G-15 | BizOps HTML 2종 | **완료(코드)** — 2026-08-19. 시설·검교정만 API. 폐기·재고·입고·공정 URL 삭제. §5.7 |
| G-22 | 멀티탭 로그아웃 | **완료** — 2026-08-11 STEP 24. §3.4 · `authPaths` Path basename |
| G-23 | 그리드 pref·가상화 | **완료** — 2026-08-11 STEP 25. §3.5 · VIRTUAL_THRESHOLD 정본 |
| G-24 | 서명 UX | **완료(문서)** — 2026-08-11 STEP 26. [`11` §2.8](18_프레임워크_파일_보안_작성규칙.md) |
| G-25 | 법적서류 미리보기 | **동결(의도)** — 2026-08-11 STEP 27. [`11` §2.9](18_프레임워크_파일_보안_작성규칙.md) · 다운로드만 |
| G-21 | Playwright E2E | **완료(최소)** — 2026-08-11 STEP 28. `e2e/cold-request` · main 파이프라인 미포함 · `Jenkinsfile.e2e` |

### 12.3 교차 수치

| 항목 | 수 |
|------|-----|
| SCREEN_REGISTRY | 75 |
| @RestController | 19 |
| FE api 모듈 | 19 |
| Mapper XML | 19 |
| 활성 IA 대메뉴 | 5 + today-tasks |

### 12.4 검증 체크리스트

- [ ] React 18.3.1 · MyBatis 3.0.3 · Boot 3.3.4 · Vite 5.4.8 · Java 17 본문 존재  
- [ ] FE 함수명 ↔ URL §5와 Controller §6 일치  
- [ ] 삭제 Body 복합키 배열  
- [ ] 작성 화면 결재 버튼 = 상신·취소만  
- [ ] 메뉴 leaf 상세 표는 07 참조  

---

## 부록 A. 공통 응답·DTO 스케치

```ts
// CommonResponse<T>
{ success: boolean; data: T; message?: string }

// DocumentListRow (요지)
{ docIdx, tmplCd, tmplNm, docKind: "DB"|"HWP", docNo, baseDt, status, verNo, fileCnt, … }

// DocumentFileRow.fileKind
"HWP_SRC" | "PDF" | "ATTACH" | "PHOTO"

// ViewLogItem
{ scrnCd, enterDt, leaveDt?, refScrnCd? }
```

## 부록 B. 화면코드 레지스트리 75키

`today-tasks`, 시스템 8, 기초 8, 기준·admin·이력, WRK DB/HWP, APR 5 — 전체 나열은 [`07 §9.1`](14_메뉴_화면_API_DB_전수.md) 정본.

## 부록 C. HWP fixedTmplCd (27)

visitor-log→hwp_sys_001 … surface-test-hwp→hwp_sys_019 — 07 §4.7 정본.

---

*본 문서는 HACCP FE+BE+DB 통합 상세 스펙이다. 메뉴 한 줄 매트릭스는 07, CRUD 갭은 06을 본다.*
