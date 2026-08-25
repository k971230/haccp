# sys 파이프라인 (FE + BE + DB)

메뉴바에서 열리는 `sys` 도메인 9화면 정본.
로컬 UI `http://localhost:4173` · API `http://localhost:7070`
관련: `docs/7_에이전트_가이드_FE.md` · `docs/3_운영규칙_FE.md` · `docs/8_에이전트_가이드_BE.md` · `docs/4_운영규칙_BE.md`

라우트 규칙: `routeOf(scrnCd)` → `tabRoute.SCREEN_PATH` 계층 경로 (`shell/tabRoute.ts`). `/screen/{scrnCd}` 없음.
경로 정본: `docs/24_URL_DB_폴더_패키지_정본.md`.

---

## 0. 구조 규약 (신규 메뉴·**손대는 메뉴** 동일하게 강제)

아직 평탄한 화면은 **그 메뉴를 손대는 작업에서** 아래 구조로 분할한다. 미리 전 메뉴를 나누지 않는다. 골드: 이 파일(`pages/sys/`).

### 0-1. 폴더 = 메뉴 1개

```
pages/sys/
 ├ code/
 │   ├ commoncode/   CommonCodePage.tsx · CommonCodeRule.ts · README.md
 │   ├ menu/         MenuManagementPage.tsx · MenuManagementRule.ts · README.md
 │   ├ role/         RoleManagementPage.tsx · RoleManagementRule.ts · README.md
 │   ├ department/   DepartmentManagementPage.tsx · DepartmentManagementRule.ts · README.md
 │   ├ user/         UserManagementPage.tsx · UserManagementRule.ts · README.md
 │   └ approvalline/ ApprovalLineManagementPage.tsx · ApprovalLineManagementRule.ts · README.md
 ├ logs/
 │   ├ loginhistory/ LoginHistoryPage.tsx · LoginHistoryRule.ts · README.md
 │   ├ auditlog/     AuditLogPage.tsx · AuditLogRule.ts · README.md
 │   └ screenusage/  ScreenUsageStatisticsPage.tsx · ScreenUsageStatisticsRule.ts · README.md
 └ README.md   (이 파일)
```

### 0-2. Page / Rule 책임 분리

| 파일 | 담는 것 | 담지 않는 것 |
|---|---|---|
| `*Rule.ts` | `SCRN_CD` · `PERSIST_ID` · `GridColumn` 정의 · 신규행 초기값 · 필수항목 · `ScreenGridRules`(newOnly/alwaysReadonly) · FE 필터·정렬·트리 산출 순수 함수 | JSX · `useState` · API 호출 |
| `*Page.tsx` | 렌더 · 상태 · API 호출 · 이벤트 핸들러 | 컬럼 하드코딩 · 잠금 규칙 하드코딩 |

컬럼이 권한·공통코드에 따라 달라지면 Rule이 `buildXxxColumns(editable, ynOpts, ynLabels)` 같은 **팩터리 함수**를 내보내고 Page가 `useMemo`로 호출한다.

### 0-3. 공통 모달은 화면 밖에 둔다

룩업·서명 팝업은 `pages/sys`가 아니라 `components/common/modal/`에 있고 `stores/modalStore.ts`가 열림 상태를 갖는다.
화면은 팝업 JSX를 갖지 않고 `openModal("CodeLookup" | "UserSign", props)`만 호출한다. 상세는 `components/common/modal/README.md`.

### 0-4. API도 도메인별로 나눈다

| 파일 (`src/api/sys/`) | 대상 |
|---|---|
| `sysTypes.ts` | `SysRow` · `SysDeleteKey` · `CodeManageRow` · `AdminMenuRow` · `RoleScreenRow` |
| `commonCodeApi.ts` | 공통코드 관리 |
| `menuApi.ts` | 메뉴 관리 (사이드바용 `api/menuApi.ts`와 다름) |
| `roleApi.ts` | 권한그룹 + 화면권한 |
| `departmentApi.ts` | 부서 관리 |
| `userApi.ts` | 사용자 관리 + 서명(내 서명 포함) |
| `approvalLineApi.ts` | 결재선 관리 (URL `/api/v1/sys/code/approval-line-management`) |
| `loginHistoryApi.ts` | 로그인 이력 |
| `auditLogApi.ts` | 변경 감사 로그 |
| `screenUsageApi.ts` | 화면 이용 통계 |

### 0-5. 그리드 pref 키

그리드 설정은 `scrn_cd` + `persistId` 조합으로 `tbl_grid_pref`에 저장된다(커스텀 그리드 `useMesTable`).
**`scrnCd`·`persistId`는 폴더를 옮겨도 값을 바꾸지 않는다.** 바꾸면 사용자가 저장한 열 너비·숨김이 전부 초기화된다.

| 화면 | scrnCd | persistId |
|---|---|---|
| 공통코드 관리 | `common-code-management` | `code-mgmt-group` · `code-mgmt-sys` · `code-mgmt-usr` |
| 메뉴 관리 | `menu-management` | `menu-mgmt-master` |
| 권한그룹 관리 | `role-management` | `role-mgmt-master` |
| 부서 관리 | `department-management` | `dept-mgmt-master-v2` |
| 사용자 관리 | `user-management` | `sys-user-management-v2` |
| 결재선 관리 | `approval-line-management` | `bas-approval-line-header` · `bas-approval-line-steps-v2` |
| 로그인 이력 | `login-history` | `log-login-history` |
| 변경 감사 로그 | `audit-log` | `log-audit-log` |
| 화면 이용 통계 | `screen-usage-statistics` | `log-screen-usage-statistics` |
| (공통) 코드 룩업 모달 | 호출 화면 scrnCd | `code-lookup-dialog` |

### 0-6. 백엔드 구조 (`com.haccp.sys`)

```
java/com/haccp/sys/
 ├ SysPayload.java   Map payload·삭제키 정규화 공용 유틸
 ├ code/
 │   ├ commoncode/ CommonCodeController · Service · Mapper
 │   ├ menu/       MenuMgmtController · Service · Mapper
 │   ├ role/       RoleMgmtController · Service · Mapper
 │   ├ department/ DepartmentController · Service · Mapper
 │   ├ user/       UserController · Service · Mapper (서명 포함)
 │   └ approvalline/ ApprovalLineController · Service · Mapper
 └ logs/
     ├ loginhistory/ LoginHistory* (C/S/M, 조회 전용)
     ├ auditlog/     AuditLog* · AuditWriter (조회 + 적재)
     └ screenusage/  ScreenUsage* (C/S/M, 조회 전용)
resources/mapper/sys/code/{commoncode,menu,role,department,user,approvalline}/*.xml
resources/mapper/sys/logs/{loginhistory,auditlog,screenusage}/*.xml
```

- 패키지 루트는 `com.haccp` (구 MES 접두 패키지에서 전면 이동 완료)
- Mapper XML은 **SP 호출 전용**이다. 네이티브 SELECT/INSERT/UPDATE/DELETE 금지 (`resources/mapper/sys/README.md`)
- SP 이름은 화면명 기준 `sp_{화면명}_{r|c|d|u}_{nnn}` (lower_snake, `07-haccp-db.mdc`). 테이블 단위 `sp_tbl_*`와 병존하며 sys 화면은 화면명 규약만 쓴다

### 0-7. CUD 공통 파이프라인

```
조회:  GET  /api/v1/sys/code|{logs}/{scrnCd}/list        → Controller → Service → Mapper → SELECT * FROM sp_{화면명}_r_000(...)
저장:  PUT  /api/v1/sys/code|{logs}/{scrnCd}/save        → Controller → Service(@Transactional) → 행 수만큼 CALL sp_{화면명}_c_000(...)
삭제:  POST /api/v1/sys/code|{logs}/{scrnCd}/validate-delete → assertDeletable → sp_{화면명}_delete_blocker_r_000
       POST /api/v1/sys/code|{logs}/{scrnCd}/delete          → assertDeletable(재검사) → CALL sp_{화면명}_d_000(...)
```

- HTTP DELETE 금지, 삭제 키는 단건이어도 `[{ idx }]` 배열 (`06-operations.mdc` OPS_DELETE)
- `validate-delete`·`delete` 양쪽에서 같은 `assertDeletable`을 도는 Double Check
- 참조 차단은 `DeleteValidation.throwIfBlocked` → 400 → FE `mesError(e)` 토스트
- 회사코드·작업자는 요청 본문이 아니라 `LoginUserContext`(JWT)에서만 읽는다

### 0-8. FE 화면 공통 흐름

`useAsyncAction`(중복 클릭 차단) + `usePageCommands`(셸 상단·단축키) + `MesEditableGrid`/`MesDataGrid` + `useEditableRows`(변경행 추적) + `useGridAccess`(잠금) + `resolveRowsForDelete`(체크행 우선) + `guardSaveWithKey`(저장 가드).
React Query는 공통코드 조회(`useCommonCodes`)에만 쓰고 화면 목록 조회에는 쓰지 않는다.

---

## 1. 공통코드 관리 (`common-code-management`)

### 1-1. 화면

좌 대분류(조회 전용) · 우상 시스템 코드(조회 전용) · 우하 사용자 코드(CRUD) 3그리드.
헤더 대분류코드·대분류명·사용여부는 전건 조회 후 FE 필터(`matchGroup`).

### 1-2. 파일

| 구분 | 경로 |
|---|---|
| FE | `pages/sys/code/commoncode/CommonCodePage.tsx` · `CommonCodeRule.ts` |
| API | `api/sys/commonCodeApi.ts` |
| BE | `com/haccp/sys/code/commoncode/{CommonCodeController,CommonCodeService,CommonCodeMapper}.java` |
| XML | `resources/mapper/sys/code/commoncode/CommonCodeMapper.xml` |
| DB | `db_sasshaccp/02_seed.sql` |

### 1-3. 버튼 → 끝단

| 버튼·이벤트 | FE 핸들러 | API | Service | SP | 테이블 |
|---|---|---|---|---|---|
| 조회(대분류) | `runSearch` → `listCodeGroups` | `GET /api/v1/sys/code/common-code-management/groups` | `listGroups` | `sp_common_code_management_r_000` | `tbl_code` |
| 대분류 행 선택 | `loadDetails` → `listCodeDetails` ×2 | `GET .../details?mainCd&sysYn` | `listDetails` | `sp_common_code_management_r_001` | `tbl_code` |
| 행추가 | `handleAddUsr` → `newUsrRow(mainCd)` | 없음(로컬) | | | |
| 저장 | `handleSaveUsr` → `saveCommonCodes` | `PUT .../save` | `save` | `sp_common_code_management_c_000` | `tbl_code` |
| 삭제 | `handleDeleteUsr` → `validateDeleteCommonCodes` → `deleteCommonCodes` | `POST .../validate-delete` → `POST .../delete` | `validateDelete`·`delete` | `sp_common_code_management_delete_blocker_r_000` → `sp_common_code_management_d_000` | `tbl_code` |

시스템 코드(`sys_yn='Y'`)는 삭제·수정 불가이며 SP가 다시 막는다.
전역 콤보(`useCommonCodes` → `api/codeApi.getCodes`)도 같은 `sp_common_code_management_r_001`을 쓴다.

---

## 2. 메뉴 관리 (`menu-management`)

### 2-1. 화면

좌 메뉴 트리(「전체」=전건, 노드 선택 시 직속 하위만) · 우 편집 그리드.
대·중·소 표시열은 트리에서 산출(`enrichMenuLevels`)하며 저장 payload에서 제외한다. **행추가 불가.**

### 2-2. 파일

| 구분 | 경로 |
|---|---|
| FE | `pages/sys/code/menu/MenuManagementPage.tsx` · `MenuManagementRule.ts` |
| API | `api/sys/menuApi.ts` |
| BE | `com/haccp/sys/code/menu/{MenuMgmtController,MenuMgmtService,MenuMgmtMapper}.java` |
| XML | `resources/mapper/sys/code/menu/MenuMgmtMapper.xml` |
| DB | `db_sasshaccp/02_seed.sql` |

### 2-3. 버튼 → 끝단

| 버튼·이벤트 | FE 핸들러 | API | Service | SP | 테이블 |
|---|---|---|---|---|---|
| 조회 | `runSearch` → `listAdminMenus` | `GET /api/v1/sys/code/menu-management/list` | `list` | `sp_menu_management_r_000` | `tbl_menu` `tbl_screen` |
| 저장 | `handleSave` → `saveMenus` | `PUT .../save` | `save` | `sp_menu_management_c_000` | `tbl_menu` |
| 삭제 | `handleDelete` → `validateDeleteMenus` → `deleteMenus` | `POST .../validate-delete` → `POST .../delete` | `validateDelete`·`delete` | `sp_menu_management_delete_blocker_r_000` → `sp_menu_management_d_000` | `tbl_menu` `tbl_role_screen` |

사이드바 트리는 **다른 SP**다: `api/menuApi.ts` → `MenuController` → `mapper/menu/MenuMapper.xml` → `sp_menu_nav_r_000`(권한 필터 포함).

---

## 3. 권한그룹 관리 (`role-management`)

### 3-1. 화면

좌 메뉴 권한 트리(리프=화면, 체크=조회권한) · 우 권한그룹 CRUD 그리드.
좌측은 저장된 권한그룹을 선택했을 때만 활성화된다(신규 행 `_rowState==="C"`이면 잠금).

### 3-2. 파일

| 구분 | 경로 |
|---|---|
| FE | `pages/sys/code/role/RoleManagementPage.tsx` · `RoleManagementRule.ts` |
| API | `api/sys/roleApi.ts` + 트리 원본 `api/sys/menuApi.ts` |
| BE | `com/haccp/sys/code/role/{RoleMgmtController,RoleMgmtService,RoleMgmtMapper}.java` |
| XML | `resources/mapper/sys/code/role/RoleMgmtMapper.xml` |
| DB | `db_sasshaccp/01_sp.sql` |

### 3-3. 버튼 → 끝단

| 버튼·이벤트 | FE 핸들러 | API | Service | SP | 테이블 |
|---|---|---|---|---|---|
| 조회 | `runSearch` → `listRoles` | `GET /api/v1/sys/code/role-management/list` | `list` | `sp_role_management_r_000` | `tbl_role` |
| 그룹 선택 | `loadTreeAuth` → `listAdminMenus` + `listRoleScreens` | `GET .../screens?usrgrpCd` | `listScreens` | `sp_role_management_screen_r_000` | `tbl_screen` `tbl_role_screen` |
| 행추가 | `handleAdd` → `newRoleRow()` | 없음(로컬) | | | |
| 저장(그룹) | `handleSaveRole` → `saveRoles` | `PUT .../save` | `save` | `sp_role_management_c_000` | `tbl_role` |
| 권한저장(트리) | `handleSaveTree` → `saveRoleScreens` | `PUT .../screens` | `saveScreens` | `sp_role_management_screen_c_000` | `tbl_role_screen` |
| 삭제 | `handleDelete` → `validateDeleteRoles` → `deleteRoles` | `POST .../validate-delete` → `POST .../delete` | `validateDelete`·`delete` | `sp_role_management_delete_blocker_r_000` → `sp_role_management_d_000` | `tbl_role` `tbl_user` `tbl_role_screen` |

로그인 후 버튼 권한 판정도 같은 SP를 쓴다: `AuthService` → `mapper/auth/AuthMapper.xml` → `sp_role_management_screen_r_000`.

---

## 4. 부서 관리 (`department-management`)

### 4-1. 화면

좌 부서 트리 · 우 CRUD 그리드. 상위부서는 **코드 룩업 모달**로 고르며 `(없음)` 선택 시 최상위가 된다.

### 4-2. 파일

| 구분 | 경로 |
|---|---|
| FE | `pages/sys/code/department/DepartmentManagementPage.tsx` · `DepartmentManagementRule.ts` |
| 모달 | `components/common/modal/CodeLookupModal.tsx` (`openModal("CodeLookup")`) |
| API | `api/sys/departmentApi.ts` |
| BE | `com/haccp/sys/code/department/{DepartmentController,DepartmentService,DepartmentMapper}.java` |
| XML | `resources/mapper/sys/code/department/DepartmentMapper.xml` |
| DB | `db_sasshaccp/01_sp.sql` |

### 4-3. 버튼 → 끝단

| 버튼·이벤트 | FE 핸들러 | API | Service | SP | 테이블 |
|---|---|---|---|---|---|
| 조회 | `runSearch` → `listDepartments` | `GET /api/v1/sys/code/department-management/list` | `list` | `sp_department_management_r_000` | `tbl_dept`(self JOIN) |
| 상위부서 룩업 | `openHDeptLookup` → `openModal("CodeLookup")` | 없음(FE 목록 재사용) | | | |
| 행추가 | `handleAdd` → `newDeptRow(treeSel)` | 없음(로컬) | | | |
| 저장 | `handleSave` → `saveDepartments` | `PUT .../save` | `save` | `sp_department_management_c_000` | `tbl_dept` |
| 삭제 | `handleDelete` → `validateDeleteDepartments` → `deleteDepartments` | `POST .../validate-delete` → `POST .../delete` | `validateDelete`·`delete` | `sp_department_management_delete_blocker_r_000` → `sp_department_management_d_000` | `tbl_dept` `tbl_user` |

---

## 5. 사용자 관리 (`user-management`)

### 5-1. 화면

단일 CRUD 그리드. 권한그룹·부서는 룩업 모달, 서명은 서명 모달로 처리한다.
`usrgrpCd`·`deptCd`는 기본 숨김이고 `usrgrpNm`·`deptNm` 표시열에 룩업 버튼이 붙는다.

### 5-2. 파일

| 구분 | 경로 |
|---|---|
| FE | `pages/sys/code/user/UserManagementPage.tsx` · `UserManagementRule.ts` |
| 모달 | `components/common/modal/CodeLookupModal.tsx` · `UserSignModal.tsx` |
| API | `api/sys/userApi.ts` + 룩업 후보 `roleApi.listRoles` · `departmentApi.listDepartments` |
| BE | `com/haccp/sys/code/user/{UserController,UserService,UserMapper}.java` |
| XML | `resources/mapper/sys/code/user/UserMapper.xml` |
| DB | `db_sasshaccp/01_sp.sql` |

### 5-3. 버튼 → 끝단

| 버튼·이벤트 | FE 핸들러 | API | Service | SP | 테이블 |
|---|---|---|---|---|---|
| 조회 | `runSearch` → `listUsers` | `GET /api/v1/sys/code/user-management/list` | `list` | `sp_user_management_r_000` | `tbl_user` `tbl_dept` `tbl_role` |
| 행추가 | `handleAdd` → `newUserRow()` | 없음(로컬) | | | |
| 저장 | `handleSave` → `saveUsers` | `PUT .../save` | `save` | `sp_user_management_c_000` | `tbl_user` |
| 삭제 | `handleDelete` → `validateDeleteUsers` → `deleteUsers` | `POST .../validate-delete` → `POST .../delete` | `validateDelete`·`delete` | `sp_user_management_delete_blocker_r_000` → `sp_user_management_d_000` | `tbl_user` `tbl_grid_pref` `tbl_user_noti_pref` |
| 서명 열기 | `openSign` → `openModal("UserSign")` → `fetchUserSignBlob` | `GET /api/v1/sys/users/{userId}/sign` | `loadSign` | `sp_user_management_sign_r_000` | `tbl_user` |
| 서명 업로드 | `UserSignModal.handleFile` → `uploadUserSign` | `POST /api/v1/sys/users/{userId}/sign` (multipart) | `uploadSign` | `sp_user_management_sign_u_000` | `tbl_user.sign_img` |
| 서명 삭제 | `UserSignModal.handleDelete` → `deleteUserSign` | `POST /api/v1/sys/users/{userId}/sign/delete` | `deleteSign` | `sp_user_management_sign_u_000` | `tbl_user.sign_img` |

서명 실물은 `tbl_user.sign_img bytea`에 직접 담기고 파일 저장소를 쓰지 않는다. 목록은 `sign_yn`(= `sign_img IS NOT NULL`)만 받아 서명 보유 여부를 표시하며 바이너리를 싣지 않는다.
등록 여부만 확인하는 자리(CCP 행 서명·서명 삭제 전 검사)는 `GET /users/me/sign-info` → `sp_user_management_sign_info_r_000`로 보유여부·파일명만 받는다. 이미지는 미리보기 버튼을 눌렀을 때만 내려온다.
내 서명(`/users/me/sign`)은 냉장 일지·HWP 문서작성이 쓰며 API는 `api/sys/userApi.ts`가 소유한다. 구 `/users/me/sign-path`는 bytea 전환과 함께 폐기했다.
비밀번호는 값이 있을 때만 BCrypt로 다시 해싱되고, 이 화면은 `userPw`·`empCd`·`posCd`·`lockYn`을 payload에서 제거한다.

---

## 6. 결재선 관리 (`approval-line-management`)

### 6-1. 화면

좌 결재선 헤더(행추가·저장·삭제, 기본 32%) · 우 고정 3단계(작성·검토·승인, 저장만). 검토 기본은 사용안함.
단계 열은 순서 · 역할 · 부서 · 결재자 · 사용. 결재자 셀 버튼은 문서주기 담당자와 같은 `CodeLookup`이며 고르면 소속 부서가 채워진다. 직위코드 없음.
URL은 `/sys/code/approval-line-management` — 메뉴 중분류 `code`. `/screen/{scrnCd}` 없음.

### 6-2. 파일

| 구분 | 경로 |
|---|---|
| FE | `pages/sys/code/approvalline/ApprovalLineManagementPage.tsx` · `ApprovalLineManagementRule.ts` |
| 모달 | `components/common/modal/CodeLookupModal.tsx` (`openModal("CodeLookup")`) |
| API | `api/sys/approvalLineApi.ts` + 룩업 후보 `userApi.listUsers` |
| BE | `com/haccp/sys/code/approvalline/{ApprovalLineController,ApprovalLineService,ApprovalLineMapper}.java` |
| XML | `resources/mapper/sys/code/approvalline/ApprovalLineMapper.xml` |
| DB | `db_sasshaccp/01_sp.sql` |

### 6-3. 버튼 → 끝단

| 버튼·이벤트 | FE 핸들러 | API | Service | SP | 테이블 |
|---|---|---|---|---|---|
| 조회 | `load` → `listApprovalLines` | `GET /api/v1/sys/code/approval-line-management/list` | `list` | `sp_tbl_approval_line_r_000` | `tbl_approval_line` `tbl_approval_line_step` |
| 행추가 | `handleAdd` → `emptyLine()` | 없음(로컬, 우측에 3단계) | | | |
| 결재자 룩업 | `openApproverLookup` → `openModal("CodeLookup")` | 없음(FE 사용자 목록 재사용) | | | |
| 저장 | `handleSave` → `saveApprovalLine` | `PUT .../save` | `save` | `sp_tbl_approval_line_c_000` | 위 |
| 삭제 | `handleDelete` → `validateDeleteApprovalLines` → `deleteApprovalLines` | `POST .../validate-delete` → `POST .../delete` | `validateDelete`·`delete` | `sp_tbl_approval_line_delete_blocker_r_000` → `sp_tbl_approval_line_d_000` | 위 |

---

## 7. 로그 3화면 (`login-history` · `audit-log` · `screen-usage-statistics`)

### 7-1. 구조

세 화면 모두 **조회 전용**이며 `components/layout/LogPageShell.tsx` 하나를 공유한다. 화면 폴더는 `pages/sys/logs/` 아래 `loginhistory/` · `auditlog/` · `screenusage/` 다.

```
loginhistory/LoginHistoryPage           →  <LogPageShell key rule={LOGIN_HISTORY_RULE} />
auditlog/AuditLogPage               →  <LogPageShell key rule={AUDIT_LOG_RULE} />
screenusage/ScreenUsageStatisticsPage  →  <LogPageShell key rule={SCREEN_USAGE_RULE} />
```

- 셸은 기간 검색·좌측 트리·그리드라는 **뼈대**만 갖는다. 컬럼·조회 API·후처리는 전부 Rule이 준다
- 셸은 인스턴스 상태를 갖는 컴포넌트라 각 Page가 `key={rule.scrnCd}`로 렌더한다. `HaccpShell`이 탭을 `hidden`으로 동시 마운트해도 기간·트리·행이 섞이지 않는다
- 모듈 레벨 `let`·싱글턴 캐시 금지

### 7-2. 화면별 계약

| 화면 | 트리 | 코드 대분류 | API | SP | 테이블 |
|---|---|---|---|---|---|
| 로그인 이력 | 사용자 평면(`listUsers`) | `login-result` | `GET /api/v1/sys/logs/login-history/list` | `sp_login_history_r_000` | `tbl_login_log` `tbl_user` |
| 변경 감사 로그 | 메뉴 계층(`listAdminMenus`) | `audit-result` | `GET /api/v1/sys/logs/audit-log/list` | `sp_audit_log_r_000` | `tbl_audit_log` `tbl_user` |
| 화면 이용 통계 | 메뉴 계층 | 없음 | `GET /api/v1/sys/logs/screen-usage-statistics/list` | `sp_screen_usage_statistics_r_000` | `tbl_view_stat_daily` `tbl_menu` `tbl_screen` |

리프 노드는 서버 조건으로, 폴더 노드는 기간 전건 조회 후 Rule의 `fetchRows`가 하위 키로 FE 필터한다.

### 7-3. 감사 이력은 누가 쌓나

`tbl_audit_log`는 화면이 아니라 저장·삭제를 수행한 서비스가 남긴다. 적재기는 `com.haccp.sys.logs.auditlog.AuditWriter` 하나이며 SP는 `sp_tbl_audit_log_c_000`이다.

| 대상 테이블 | 남기는 곳 | 행위 |
|---|---|---|
| `tbl_code` `tbl_menu` `tbl_role` `tbl_role_screen` `tbl_dept` `tbl_user` | 시스템 관리 5화면 Service의 `save`·`delete` | I·U·D (사용자 서명 업로드·삭제는 U) |
| `tbl_document` `tbl_document_file` | `docs.document.DocumentService` | I·U·D·APV·RJT |

- 대상 테이블은 `audit-target` 공통코드(`sub_cd`=테이블명, `ref1`=화면코드)에 있어야 표시명·트리 필터가 붙는다
- `after_json`은 화면 payload 그대로이고 `_key`·`_rowState`는 버려지며 `userPw`는 `***`로 가려진다. `before_json`은 남기지 않는다
- 원 업무 트랜잭션 안에서 기록하므로 저장이 실패하면 이력도 남지 않는다

---

## 8. 신규 메뉴 추가 절차 (요약)

1. DB: `db_sasshaccp/`에 `sp_tbl_{화면}_r_000`·`_c_000`·`_delete_blocker_r_000`·`_d_000` migrate 작성 (DROP은 회귀 통과 후 별도 파일)
2. BE: `com.haccp.{대}.{중}` 아래 Controller·Service·Mapper + `resources/mapper/{대}/{중}/*.xml`(SP 호출 전용)
3. FE: `api/{대}/` → `pages/{대}/{중}/{화면}Page.tsx` + `{화면}Rule.ts`. 경로 `docs/24`
4. 팝업이 필요하면 `components/common/modal/`에 추가하고 `modalTypes.ModalPropsMap`·`GlobalModal` 분기를 늘린다
5. `shell/screenRegistry.tsx`에 화면코드 엔트리 등록, `tbl_menu`·`tbl_screen` 시드 추가
6. 폴더 README 작성 + 이 문서의 표 갱신. 변경 추적이 필요한 화면이면 Service에 `AuditWriter.record(...)`를 넣고 `audit-target` 공통코드에 대상 1건을 추가한다
7. 검증: `./mvnw -q -DskipTests compile` · `npx tsc --noEmit` · 조회/행추가/저장/삭제(참조 차단) 스모크
