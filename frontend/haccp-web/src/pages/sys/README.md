# sys 파이프라인 (FE + BE)

메뉴바에서 열리는 `sys` 도메인 8화면 정본.  
로컬 UI: `http://localhost:4173` · API: `http://localhost:7070`  
관련: `docs/7_에이전트_가이드_FE.md` · `docs/3_운영규칙_FE.md` · `docs/8_에이전트_가이드_BE.md` · `docs/4_운영규칙_BE.md`

라우트 규칙: `routeOf(scrnCd)` → `/screen/{scrnCd}` (`shell/tabRoute.ts`)

---

## 0. 공통 파일 · SP · 팝업 · pref

### 0-1. FE 파일 목록

| 구분 | 경로 (`frontend/haccp-web/src/`) |
|---|---|
| 페이지 | `pages/sys/CommonCodeManagementPage.tsx` |
| | `pages/sys/MenuManagementPage.tsx` |
| | `pages/sys/RoleManagementPage.tsx` |
| | `pages/sys/DepartmentManagementPage.tsx` |
| | `pages/sys/SystemManagementPage.tsx` (user-management) |
| | `pages/sys/LogManagementPage.tsx` (login/audit/통계 3화면) |
| 팝업 | `pages/sys/CodeLookupDialog.tsx` · `pages/sys/UserSignDialog.tsx` |
| rules | `pages/sys/SystemManagementPage.rules.ts` |
| API | `api/systemApi.ts` · (메뉴 보조) `api/menuApi.ts` |
| 셸 | `shell/screenRegistry.tsx` · `shell/HaccpShell.tsx` · `shell/resolveDelete.ts` · `shell/errors.ts` |
| 그리드 | `components/grid/MesDataGrid.tsx` · `MesEditableGrid.tsx` · `useMesTable.ts` · `types/grid.ts` |
| 레이아웃 | `components/layout/ResizableSplit.tsx` · `TreePanelSearch.tsx` · `PageCard.tsx` |
| 유틸 | `lib/treeFilter.ts` · `lib/yn.ts` · `styles/global.css` |

### 0-2. BE 파일 목록

| 구분 | 경로 (`backend/haccp-api/src/main/`) |
|---|---|
| Controller | `java/com/metis/haccp/sys/SystemController.java` (`@RequestMapping("/api/v1/sys")`) |
| Service | `java/com/metis/haccp/sys/SystemService.java` |
| Mapper 인터페이스 | `java/com/metis/haccp/sys/SystemMapper.java` |
| Mapper XML | `resources/mapper/sys/SystemMapper.xml` |
| 삭제 공통 | `java/com/metis/haccp/common/validation/DeleteValidation.java` · `DeleteBlocker.java` |
| 서명 파일 | `java/com/metis/haccp/doc/DocumentFileStorage.java` (서명 저장/읽기 재사용) |
| 관련 DTO | `java/com/metis/haccp/auth/dto/UserLoginRow.java` (로그인·서명 경로 연관) |
| 패키지 README | `java/com/metis/haccp/sys/README.md` · `resources/mapper/sys/README.md` |

### 0-3. DB 파일

| 구분 | 경로 (`db_sasshaccp/`) |
|---|---|
| DDL | `01_ddl_auth.sql` · `02_ddl_log.sql` |
| SP | `11_sp_auth.sql` · `12_sp_log.sql` · `13_sp_platform.sql` · `21_sp_system.sql` |
| migrate | `53`~`61` (부록 B) |

### 0-4. CUD 공통 파이프라인

```
저장:  PUT  /api/v1/sys/{screenCode}/save
       → SystemController.save
       → SystemService.save
       → SystemMapper.save
       → CALL sp_tbl_system_c_000(co_cd, type, payload jsonb, user_id)
       → 유형별 sp_tbl_*_c_000

삭제검증: POST /api/v1/sys/{screenCode}/validate-delete
       → SystemService.validateDelete → assertDeletable
       → SystemMapper.selectDeleteBlocker
       → sp_tbl_system_delete_blocker_r_000
       → DeleteValidation.throwIfBlocked

삭제:  POST /api/v1/sys/{screenCode}/delete
       → SystemService.delete → assertDeletable(2차) → SystemMapper.delete 루프
       → CALL sp_tbl_system_d_000 → 유형별 sp_tbl_*_d_000
```

조회 list는 Controller가 **Service 미경유**로 `systemMapper.selectRows` 직접 호출.

허용 `screenCode` (`ALLOWED_TYPES`):  
`user-management` · `department-management` · `role-management` · `menu-management` · `common-code-management` · `login-history` · `screen-usage-statistics` · `audit-log`  
이력 3종은 save / validate-delete / delete 불가 (`requireManageType`).

### 0-5. SystemMapper.xml statement id 요약

| id | 호출 |
|---|---|
| `selectRows` | type별 `sp_tbl_user_r_000` / `sp_tbl_dept_r_000` / `sp_tbl_role_r_000` / `sp_tbl_menu_admin_r_000` / `sp_tbl_code_r_000` / `sp_tbl_login_log_r_000` / `sp_tbl_view_stat_daily_r_000` / `sp_tbl_audit_log_r_000` |
| `save` | `CALL sp_tbl_system_c_000` |
| `selectDeleteBlocker` | `sp_tbl_system_delete_blocker_r_000` |
| `delete` | `CALL sp_tbl_system_d_000` |
| `selectSignPath` | SQL `SELECT sign_path FROM tbl_user` |
| `updateSignPath` | SQL `UPDATE tbl_user SET sign_path=...` |
| `selectRoleScreens` | `sp_tbl_role_screen_r_000` |
| `upsertRoleScreen` | `CALL sp_tbl_role_screen_c_000` |
| `selectCodeGroups` | `sp_tbl_code_group_r_000` |
| `selectCodeDetails` | `sp_tbl_code_detail_r_000` |
| `selectMenusAdmin` | `sp_tbl_menu_admin_r_000` |

### 0-6. systemApi.ts export

| Export | Method | URL |
|---|---|---|
| `listSystemRows(screenCode, params)` | GET | `/api/v1/sys/{screenCode}/list` |
| `saveSystemRows(screenCode, rows)` | PUT | `/api/v1/sys/{screenCode}/save` |
| `validateDeleteSystemRows(screenCode, keys)` | POST | `/api/v1/sys/{screenCode}/validate-delete` |
| `deleteSystemRows(screenCode, keys)` | POST | `/api/v1/sys/{screenCode}/delete` |
| `listCodeGroups` | GET | `/api/v1/sys/common-code-management/groups` |
| `listCodeDetails(mainCd, sysYn)` | GET | `/api/v1/sys/common-code-management/details` |
| `listAdminMenus` | GET | `/api/v1/sys/role-management/menus` |
| `listRoleScreens(usrgrpCd)` | GET | `/api/v1/sys/role-management/screens` |
| `saveRoleScreens(usrgrpCd, rows)` | PUT | `/api/v1/sys/role-management/screens` |
| `fetchUserSignBlob(userId)` | GET httpFile | `/api/v1/sys/users/{userId}/sign` |
| `uploadUserSign(userId, file)` | POST httpFile | `/api/v1/sys/users/{userId}/sign` |
| `deleteUserSign(userId)` | POST | `/api/v1/sys/users/{userId}/sign/delete` |
| `fetchMySignPath` / `uploadMySign` | GET/POST | `/api/v1/sys/users/me/sign-path` · `.../me/sign` (CCP·HWP용, sys 화면 외) |

### 0-7. 공통 팝업

#### CodeLookupDialog

- 파일: `pages/sys/CodeLookupDialog.tsx`
- Props: `open` · `title` · `scrnCd` · `options[{value,label}]` · `value?` · `allowEmpty?` · `onSelect` · `onClose`
- API: 없음 (부모 options 클라이언트 필터)
- UX: 보라 `mes-modal-grid-head` · max-w-lg · 바디 280 · 코드/코드명 검색 · 툴바(결과 내 검색) · `persistId="code-lookup-dialog"` · `scrnCd`+pref
- 호출: `SystemManagementPage`(권한그룹·부서) · `DepartmentManagementPage`(상위부서, `allowEmpty`)

#### UserSignDialog

- 파일: `pages/sys/UserSignDialog.tsx`
- Props: `open` · `userId` · `signPath?` · `onClose` · `onUploaded`
- API: `fetchUserSignBlob` · `uploadUserSign` · `deleteUserSign`
- UX: 동일 모달 셸 · JPG/PNG · max 10MB · 푸터 좌:교체/업로드·삭제 / 우:닫기 · 신규행(미저장 userId)은 토스트로 차단

### 0-8. SystemManagementPage.rules.ts

| screenCode | 규칙 |
|---|---|
| `user-management` | `newOnly: ["userId"]` |
| `department-management` | `newOnly: ["deptCd"]` |
| `role-management` | `newOnly: ["usrgrpCd"]` |
| `menu-management` | `alwaysReadonly: ["grpANm","grpBNm","grpCNm","menuCd","hMenuCd","scrnCd","sortNo"]` (행추가 없음) |
| `common-code-management` | `newOnly: ["mainCd","subCd"]` (페이지에서 GROUP/SYS/USR 추가 잠금) |

### 0-9. 삭제 운영 규약 ([OPS_DELETE])

- HTTP DELETE 금지 · `POST validate-delete` → `mesConfirm` → `POST delete`
- Body: 복합키 객체 배열 `[{ idx, ... }]`
- BE: validate·delete **양쪽** `assertDeletable` Double Check
- FE: `mesError(e)`만 호출 (`mesToast(mesError(e))` 이중 토스트 금지)

---

## 1. 공통코드 관리

### 1-0. 식별 · 파일 · 테이블

| 항목 | 값 |
|---|---|
| URL | http://localhost:4173/screen/common-code-management |
| scrnCd | `common-code-management` |
| Registry | `"common-code-management": CommonCodeManagementPage` |
| FE | `pages/sys/CommonCodeManagementPage.tsx` · rules · `systemApi.ts` · `MesEditableGrid` / `MesDataGrid` |
| BE | `SystemController.codeGroups` · `codeDetails` · `save` · `validateDelete` · `delete` |
| | `SystemService.listCodeGroups` · `listCodeDetails` · `save` · `validateDelete` · `delete` |
| | Mapper: `selectCodeGroups` · `selectCodeDetails` · `save` · `selectDeleteBlocker` · `delete` |
| 테이블 | `tbl_code` PK `idx` · UNIQUE `(co_cd, main_cd, sub_cd)` · 대분류 `sub_cd='*'` · `sys_yn` |

### 1-1. 조회

| 단계 | 내용 |
|---|---|
| 버튼 | 상단 「조회」 / 셸 search → `runSearch` |
| FE | `listCodeGroups()` → 대분류 그리드 · 선택 후 `listCodeDetails(mainCd, "Y"|"N")` |
| API | `GET /api/v1/sys/common-code-management/groups` · `.../details?mainCd&sysYn` |
| Controller | `codeGroups()` · `codeDetails(mainCd, sysYn)` |
| Service | `listCodeGroups()` · `listCodeDetails(mainCd, sysYn)` |
| Mapper XML | `selectCodeGroups` → `sp_tbl_code_group_r_000` · `selectCodeDetails` → `sp_tbl_code_detail_r_000` (`21_sp_system.sql`) |
| 테이블 | `tbl_code` |

대분류·시스템 세부는 **조회 전용**. CRUD는 사용자 세부만.

### 1-2. 행추가

| 단계 | 내용 |
|---|---|
| 버튼 | 사용자 세부 「행추가」 → `handleAddUsr` |
| FE | `useMesTable` 신규행 · `mainCd`는 선택 대분류 고정 · `newOnly: mainCd, subCd` |
| BE/SP | 없음 (로컬 행 상태만) |

### 1-3. 저장

| 단계 | 내용 |
|---|---|
| 버튼 | 「저장」 → `handleSaveUsr` |
| FE | `saveSystemRows("common-code-management", rows)` |
| API | `PUT /api/v1/sys/common-code-management/save` |
| Controller | `save(screenCode, rows)` |
| Service | `save` → 행 루프 `mapper.save` |
| Mapper | `save` → `sp_tbl_system_c_000` → `sp_tbl_code_c_000` (`11_sp_auth.sql`) |
| 테이블 | `tbl_code` INSERT/UPDATE |

### 1-4. 삭제

| 단계 | 내용 |
|---|---|
| 버튼 | 「삭제」 → `handleDeleteUsr` |
| FE | `validateDeleteSystemRows` → `mesConfirm` → `deleteSystemRows` |
| API | `POST .../validate-delete` · `POST .../delete` body `[{idx,...}]` |
| Service | `assertDeletable` ×2 → `delete` |
| Mapper | `selectDeleteBlocker` · `delete` → `sp_tbl_system_d_000` → `sp_tbl_code_d_000` |

### 1-5. 그리드 · pref

| 그리드 | persistId | scrnCd | 비고 |
|---|---|---|---|
| 대분류 | `code-mgmt-group` | `common-code-management` | 조회 전용 |
| 시스템 세부 | `code-mgmt-sys` | 동일 | 조회 전용 |
| 사용자 세부 | `code-mgmt-usr` | 동일 | CUD |

---

## 2. 메뉴 관리

### 2-0. 식별 · 파일 · 테이블

| 항목 | 값 |
|---|---|
| URL | http://localhost:4173/screen/menu-management |
| scrnCd | `menu-management` |
| Registry | `"menu-management": MenuManagementPage` |
| FE | `MenuManagementPage.tsx` · `ResizableSplit` · `TreePanelSearch` · `lib/treeFilter.ts` |
| BE | Controller `list`/`save`/`validateDelete`/`delete` · Service `save`/`validateDelete`/`delete` |
| | Mapper `selectRows`(menu) · `save` · `selectDeleteBlocker` · `delete` |
| 테이블 | `tbl_menu` PK `idx` · UNIQUE `(co_cd, menu_cd)` · `h_menu_cd` · `scrn_cd` · `sort_no` |

### 2-1. 조회

| 단계 | 내용 |
|---|---|
| 버튼 | 「조회」 → `runSearch` · 좌 트리 필터(메뉴코드/명/사용여부)는 FE |
| FE | `listSystemRows("menu-management", { keyword: "" })` |
| API | `GET /api/v1/sys/menu-management/list` |
| Controller | `list` → `systemMapper.selectRows` (Service 미경유) |
| Mapper | `selectRows` type=`menu-management` → `sp_tbl_menu_admin_r_000` (`21_sp_system.sql`) |
| 테이블 | `tbl_menu` |
| UX | 좌 트리 `TREE_ALL` + `hMenuCd` · 우 그리드 |

### 2-2. 행추가

없음. `usePageCommands.add: undefined` · rules `alwaysReadonly`로 코드/계층 잠금. 메뉴명·사용여부만 수정.

### 2-3. 저장

| 단계 | 내용 |
|---|---|
| 버튼 | 「저장」 → `handleSave` |
| FE | `saveSystemRows("menu-management", rows)` |
| API | `PUT /api/v1/sys/menu-management/save` |
| Service | `save` → `sp_tbl_system_c_000` → `sp_tbl_menu_c_000` |
| 비고 | `use_yn=N` 시 자손 전파 (`sp_tbl_menu_c_000`) · sort 재인코딩은 migrate/SP `sp_tbl_menu_sort_encode_u_000` |

### 2-4. 삭제

| 단계 | 내용 |
|---|---|
| 버튼 | 「삭제」 → `handleDelete` |
| FE | validate → confirm → delete |
| API | `POST .../menu-management/validate-delete` · `.../delete` |
| SP | blocker `sp_tbl_system_delete_blocker_r_000` · `sp_tbl_system_d_000` → menu DELETE |

### 2-5. 그리드 · pref

- `persistId`: `menu-mgmt-master` · `scrnCd=menu-management`

---

## 3. 권한그룹 관리

### 3-0. 식별 · 파일 · 테이블

| 항목 | 값 |
|---|---|
| URL | http://localhost:4173/screen/role-management |
| scrnCd | `role-management` |
| Registry | `"role-management": RoleManagementPage` |
| FE | `RoleManagementPage.tsx` · 좌 메뉴권한 트리 · 우 권한그룹 그리드 |
| BE | list/save/delete + `roleScreens` · `saveRoleScreens` · `roleMenus` |
| | Service `listRoleScreens` · `saveRoleScreens` · `listMenusAdmin` |
| | Mapper `selectRoleScreens` · `upsertRoleScreen` · `selectMenusAdmin` · `selectRows`/`save`/`delete` |
| 테이블 | `tbl_role` PK `idx` · UNIQUE `(co_cd, usrgrp_cd)` (**`tbl_usrgrp` 아님**) |
| | `tbl_role_screen` UNIQUE `(co_cd, usrgrp_cd, scrn_cd)` · `read_yn`…`print_yn` |
| | `tbl_screen` · `tbl_menu` (트리) |

### 3-1. 조회

| 단계 | 내용 |
|---|---|
| 버튼 | 「조회」 → `runSearch` |
| FE | `listSystemRows("role-management")` · `listAdminMenus()` · 선택 그룹 시 `listRoleScreens(usrgrpCd)` |
| API | `GET .../role-management/list` · `GET .../role-management/menus` · `GET .../role-management/screens?usrgrpCd` |
| Controller | `list` · `roleMenus` → `listMenusAdmin` · `roleScreens` → `listRoleScreens` |
| Mapper | `selectRows` → `sp_tbl_role_r_000` · `selectMenusAdmin` → `sp_tbl_menu_admin_r_000` · `selectRoleScreens` → `sp_tbl_role_screen_r_000` |
| 테이블 | `tbl_role` · `tbl_menu` · `tbl_screen` + `tbl_role_screen` |

### 3-2. 행추가

| 단계 | 내용 |
|---|---|
| 버튼 | 「행추가」 → `handleAdd` |
| FE | `newOnly: ["usrgrpCd"]` · 로컬 신규행 |
| BE/SP | 없음 |

### 3-3. 저장 (마스터)

| 단계 | 내용 |
|---|---|
| 버튼 | 「저장」 → `handleSaveRole` |
| FE | `saveSystemRows("role-management", rows)` |
| API | `PUT /api/v1/sys/role-management/save` |
| SP | `sp_tbl_system_c_000` → `sp_tbl_role_c_000` → `tbl_role` |

### 3-4. 권한 저장 (트리)

| 단계 | 내용 |
|---|---|
| 버튼 | 「권한 저장」 → `handleSaveTree` |
| FE | `saveRoleScreens(usrgrpCd, rows)` — `readYn`만 전송 |
| API | `PUT /api/v1/sys/role-management/screens` body `{ usrgrpCd, rows }` |
| Controller | `saveRoleScreens` |
| Service | `saveRoleScreens` — readYn=Y이면 read/write/modify/delete/print **전부 Y**, N이면 전부 N · `@Transactional(timeout=60)` |
| Mapper | `upsertRoleScreen` → `CALL sp_tbl_role_screen_c_000` |
| 테이블 | `tbl_role_screen` UPSERT |

### 3-5. 삭제

| 단계 | 내용 |
|---|---|
| 버튼 | 「삭제」 → `handleDelete` |
| FE | validate → confirm → delete |
| SP | blocker(사용자 참조 등) · `sp_tbl_system_d_000` → role DELETE |

### 3-6. 그리드 · pref

- `persistId`: `role-mgmt-master` · `scrnCd=role-management`

---

## 4. 부서 관리

### 4-0. 식별 · 파일 · 테이블

| 항목 | 값 |
|---|---|
| URL | http://localhost:4173/screen/department-management |
| scrnCd | `department-management` |
| Registry | `"department-management": DepartmentManagementPage` |
| FE | `DepartmentManagementPage.tsx` · `CodeLookupDialog`(상위부서) |
| BE | Controller list/save/validateDelete/delete · Service 동일 · Mapper selectRows/save/blocker/delete |
| 테이블 | `tbl_dept` PK `idx` · UNIQUE `(co_cd, dept_cd)` · `h_dept_cd` · 조회 시 self JOIN `h_dept_nm` (migrate 61) |

### 4-1. 조회

| 단계 | 내용 |
|---|---|
| 버튼 | 「조회」 → `runSearch` |
| FE | `listSystemRows("department-management", …)` |
| API | `GET /api/v1/sys/department-management/list` |
| Mapper | `selectRows` → `sp_tbl_dept_r_000` (`11_sp_auth.sql`, `h_dept_nm` 포함) |
| 테이블 | `tbl_dept` |

### 4-2. 행추가

| 단계 | 내용 |
|---|---|
| 버튼 | 「행추가」 → `handleAdd` |
| FE | `newOnly: ["deptCd"]` |
| BE/SP | 없음 |

### 4-3. 저장

| 단계 | 내용 |
|---|---|
| 버튼 | 「저장」 → `handleSave` |
| FE | `saveSystemRows("department-management", rows)` |
| API | `PUT .../department-management/save` |
| SP | `sp_tbl_system_c_000` → `sp_tbl_dept_c_000` → `tbl_dept` |

### 4-4. 삭제

| 단계 | 내용 |
|---|---|
| 버튼 | 「삭제」 → `handleDelete` |
| FE | validate → confirm → delete |
| SP | `sp_tbl_system_delete_blocker_r_000` — 직접 사용자·하위트리 사용자·직속 하위 부서 차단 (migrate 60) |
| | `sp_tbl_system_d_000` → `sp_tbl_dept_d_000` |

### 4-5. 상위부서 룩업

| 단계 | 내용 |
|---|---|
| UI | `hDeptNm` 룩업 박스 · `hDeptCd` `defaultHidden` |
| FE | `CodeLookupDialog` · `allowEmpty` · options=로드된 부서 목록 (추가 API 없음) |
| 선택 | `onSelect` → `hDeptCd`/`hDeptNm` 셀 반영 |

### 4-6. 그리드 · pref

- `persistId`: `dept-mgmt-master-v2` · `scrnCd=department-management`

---

## 5. 사용자 관리

### 5-0. 식별 · 파일 · 테이블

| 항목 | 값 |
|---|---|
| URL | http://localhost:4173/screen/user-management |
| scrnCd | `user-management` |
| Registry | `"user-management": () => <SystemManagementPage screenCode="user-management" />` |
| FE | `SystemManagementPage.tsx` · `CodeLookupDialog` · `UserSignDialog` · rules |
| BE | list/save/delete + 서명 엔드포인트 전부 |
| | Service `save`(BCrypt) · `loadSign` · `uploadSign` · `deleteSign` · `mySignPath` |
| | Mapper `selectRows` · `save` · `delete` · `selectSignPath` · `updateSignPath` |
| 테이블 | `tbl_user` PK `idx` · UNIQUE `user_id` · `(co_cd, emp_cd)` · `usrgrp_cd` · `dept_cd` · `sign_path` |
| JOIN 조회 | `sp_tbl_user_r_000` → `tbl_role`(usrgrpNm) · `tbl_dept`(deptNm) |

### 5-1. 조회

| 단계 | 내용 |
|---|---|
| 버튼 | 「조회」 → `runSearch` → `load` |
| FE | `listSystemRows("user-management", …)` · 룩업용으로 role/dept list도 로드 |
| API | `GET /api/v1/sys/user-management/list` (+ role/dept list) |
| Mapper | `selectRows` → `sp_tbl_user_r_000` |
| 테이블 | `tbl_user` · `tbl_role` · `tbl_dept` |

### 5-2. 행추가

| 단계 | 내용 |
|---|---|
| 버튼 | 「행추가」 → `handleAdd` |
| FE | `newOnly: ["userId"]` · `deptCd` required |
| BE/SP | 없음 · 서명 등록은 저장 후만 가능 |

### 5-3. 저장

| 단계 | 내용 |
|---|---|
| 버튼 | 「저장」 → `handleSave` |
| FE | `saveSystemRows("user-management", rows)` |
| API | `PUT /api/v1/sys/user-management/save` |
| Service | 신규만 `userPw` BCrypt(빈 값이면 기본 `"1234"`) · JWT `coCd`/`userId`만 SP 전달 |
| SP | `sp_tbl_system_c_000` → `sp_tbl_user_c_000` → `tbl_user` |

### 5-4. 삭제

| 단계 | 내용 |
|---|---|
| 버튼 | 「삭제」 → `handleDelete` |
| FE | validate → confirm → delete |
| SP | blocker · `sp_tbl_system_d_000` → `sp_tbl_user_d_000` (pref·noti 등 연쇄) |

### 5-5. 권한그룹 · 부서 룩업

| 단계 | 내용 |
|---|---|
| UI | `usrgrpNm` / `deptNm` 룩업 박스 · `usrgrpCd`/`deptCd` `defaultHidden` |
| FE | `CodeLookupDialog` · options=`listSystemRows("role-management"|"department-management")` |
| persistId | 사용자 그리드 `sys-user-management-v2` |

### 5-6. 서명

| 단계 | 내용 |
|---|---|
| UI | 서명 열 → `UserSignDialog` |
| 조회 | `GET /api/v1/sys/users/{userId}/sign` → `SystemController.userSign` → `SystemService.loadSign` → `selectSignPath` + `DocumentFileStorage.read` |
| 업로드 | `POST .../users/{userId}/sign` multipart → `uploadSign` → 파일 저장 + `updateSignPath` · PNG/JPG ≤10MB |
| 삭제 | `POST .../users/{userId}/sign/delete` → `deleteSign` → `updateSignPath("")` + 파일 삭제 |
| 내 서명 | `GET/POST .../users/me/sign` · `GET .../me/sign-path` (타 화면용) |

### 5-7. 그리드 · pref

- `persistId`: `sys-user-management-v2` · `scrnCd=user-management`

---

## 6. 로그인 이력

### 6-0. 식별 · 파일 · 테이블

| 항목 | 값 |
|---|---|
| URL | http://localhost:4173/screen/login-history |
| scrnCd | `login-history` |
| Registry | `"login-history": () => <LogManagementPage screenCode="login-history" />` |
| FE | `LogManagementPage.tsx` · `MesDataGrid` · 좌 사용자 트리 |
| BE | Controller `list`만 · Mapper `selectRows` |
| 테이블 | `tbl_login_log` PK `idx` · `co_cd` · `user_id` · `sid` · `login_dt` · `result_cd` · JOIN `tbl_user` |

### 6-1. 조회

| 단계 | 내용 |
|---|---|
| 버튼 | 「조회」 → `runSearch` → `load` |
| FE | `listSystemRows("login-history", { keyword, fromDt, toDt })` · 트리용 `listSystemRows("user-management")` |
| API | `GET /api/v1/sys/login-history/list` · `GET .../user-management/list` |
| Mapper | `selectRows` → `sp_tbl_login_log_r_000` (`12_sp_log.sql`) |
| UX | 기간 기본 30일 · 읽기 전용 · add/save/delete 없음 |

### 6-2. 그리드 · pref

- `persistId`: `log-login-history` · `scrnCd=login-history`

---

## 7. 감사 로그

### 7-0. 식별 · 파일 · 테이블

| 항목 | 값 |
|---|---|
| URL | http://localhost:4173/screen/audit-log |
| scrnCd | `audit-log` |
| Registry | `"audit-log": () => <LogManagementPage screenCode="audit-log" />` |
| FE | `LogManagementPage.tsx` · 좌 메뉴 계층 트리 |
| BE | Controller `list` · Mapper `selectRows` |
| 테이블 | `tbl_audit_log` · JOIN `tbl_user` · `tbl_code`(audit-target) |

### 7-1. 조회

| 단계 | 내용 |
|---|---|
| 버튼 | 「조회」 → `runSearch` |
| FE | `listSystemRows("audit-log", { keyword, fromDt, toDt })` · 트리 `listAdminMenus()` |
| API | `GET /api/v1/sys/audit-log/list` · `GET .../role-management/menus` |
| Mapper | `selectRows` → `sp_tbl_audit_log_r_000` (`12_sp_log.sql`) |
| UX | 기간 30일 · 읽기 전용 |

### 7-2. 그리드 · pref

- `persistId`: `log-audit-log` · `scrnCd=audit-log`

---

## 8. 화면 이용 통계

### 8-0. 식별 · 파일 · 테이블

| 항목 | 값 |
|---|---|
| URL | http://localhost:4173/screen/screen-usage-statistics |
| scrnCd | `screen-usage-statistics` |
| Registry | `"screen-usage-statistics": () => <LogManagementPage screenCode="screen-usage-statistics" />` |
| FE | `LogManagementPage.tsx` · 좌 메뉴 계층 트리 |
| BE | Controller `list` · Mapper `selectRows` |
| 테이블 | `tbl_view_stat_daily` UNIQUE `(co_cd, stat_dt, scrn_cd)` · `pv_cnt`/`uv_cnt`/`sess_cnt`/`ip_cnt` · JOIN `tbl_screen`/`tbl_menu` |
| 원천 | `tbl_view_log` (배치 집계 `sp_tbl_view_stat_daily_c_000` — 화면 list 외) |

### 8-1. 조회

| 단계 | 내용 |
|---|---|
| 버튼 | 「조회」 → `runSearch` |
| FE | `listSystemRows("screen-usage-statistics", { keyword, fromDt, toDt })` · 트리 `listAdminMenus()` |
| API | `GET /api/v1/sys/screen-usage-statistics/list` · `GET .../role-management/menus` |
| Mapper | `selectRows` → `sp_tbl_view_stat_daily_r_000` (`12_sp_log.sql`) |
| UX | 기간 30일 · 읽기 전용 |

### 8-2. 그리드 · pref

- `persistId`: `log-screen-usage-statistics` · `scrnCd=screen-usage-statistics`

---

## 부록 A. SystemController 엔드포인트 전체

베이스 `/api/v1/sys`

| HTTP | Path | Controller | Service/Mapper |
|---|---|---|---|
| GET | `/{screenCode}/list` | `list` | `systemMapper.selectRows` (직접) |
| PUT | `/{screenCode}/save` | `save` | `systemService.save` |
| POST | `/{screenCode}/validate-delete` | `validateDelete` | `systemService.validateDelete` |
| POST | `/{screenCode}/delete` | `delete` | `systemService.delete` |
| GET | `/users/me/sign` | `mySign` | `loadMySign` |
| GET | `/users/{userId}/sign` | `userSign` | `loadSign` |
| GET | `/users/me/sign-path` | `mySignPath` | `mySignPath` |
| POST | `/users/me/sign` | `uploadMySign` | `uploadSign(me)` |
| POST | `/users/{userId}/sign` | `uploadUserSign` | `uploadSign` |
| POST | `/users/{userId}/sign/delete` | `deleteUserSign` | `deleteSign` |
| GET | `/role-management/screens` | `roleScreens` | `listRoleScreens` |
| PUT | `/role-management/screens` | `saveRoleScreens` | `saveRoleScreens` |
| GET | `/role-management/menus` | `roleMenus` | `listMenusAdmin` |
| GET | `/common-code-management/groups` | `codeGroups` | `listCodeGroups` |
| GET | `/common-code-management/details` | `codeDetails` | `listCodeDetails` |

## 부록 B. migrate 53~61

| File | 역할 |
|---|---|
| `53_migrate_menu_sort_encode_cleanup.sql` | 미사용 메뉴 삭제 + `sort_no` 대·중·소 인코딩 SP |
| `54_migrate_sys_menu_ia.sql` | company-management 숨김 · user/dept를 `menu-sys-auth`로 이동 |
| `55_migrate_user_drop_pos_cd.sql` | `tbl_user.pos_cd` 제거 · 사용자 SP 시그니처 동기화 |
| `56_migrate_sys_auth_menu_order.sql` | menu-sys-auth leaf 순서(공통코드→메뉴→권한→부서→사용자) |
| `57_migrate_system_delete_blocker_cast.sql` | delete_blocker varchar 캐스트 · 메뉴 use_yn=N 자손 전파 |
| `58_migrate_log_mgmt.sql` | login/audit 코드 · ip_cnt · 통계/감사 조회 SP 정비 |
| `59_migrate_system_d_found.sql` | `sp_tbl_system_d_000` FOUND 오판 삭제 실패 수정 |
| `60_migrate_dept_delete_user_tree.sql` | 부서 삭제 차단(사용자·하위트리) 강화 |
| `61_migrate_dept_h_dept_nm.sql` | `sp_tbl_dept_r_000`에 `h_dept_nm` self JOIN |

## 부록 C. screenRegistry 매핑

파일: `frontend/haccp-web/src/shell/screenRegistry.tsx`

| scrnCd | 컴포넌트 |
|---|---|
| `common-code-management` | `CommonCodeManagementPage` |
| `menu-management` | `MenuManagementPage` |
| `role-management` | `RoleManagementPage` |
| `department-management` | `DepartmentManagementPage` |
| `user-management` | `<SystemManagementPage screenCode="user-management" />` |
| `login-history` | `<LogManagementPage screenCode="login-history" />` |
| `audit-log` | `<LogManagementPage screenCode="audit-log" />` |
| `screen-usage-statistics` | `<LogManagementPage screenCode="screen-usage-statistics" />` |

키 = `tbl_screen.scrn_cd` = URL path segment.

## 부록 D. 테이블 PK 요약

| Table | PK | UNIQUE / 핵심 |
|---|---|---|
| `tbl_code` | `idx` | `(co_cd, main_cd, sub_cd)` · `sys_yn` · `sub_cd='*'`=그룹 |
| `tbl_menu` | `idx` | `(co_cd, menu_cd)` · `h_menu_cd` · `scrn_cd` · `sort_no` |
| `tbl_role` | `idx` | `(co_cd, usrgrp_cd)` · `usrgrp_nm` |
| `tbl_dept` | `idx` | `(co_cd, dept_cd)` · `h_dept_cd` |
| `tbl_user` | `idx` | `user_id` · `(co_cd, emp_cd)` · `sign_path` |
| `tbl_role_screen` | `idx` | `(co_cd, usrgrp_cd, scrn_cd)` |
| `tbl_screen` | `idx` | `scrn_cd` |
| `tbl_login_log` | `idx` | `login_dt` · `result_cd` |
| `tbl_view_stat_daily` | `idx` | `(co_cd, stat_dt, scrn_cd)` |
| `tbl_audit_log` | `idx` | `tbl_nm` · `action_cd` · `ins_dt` |

## 부록 E. persistId 전체

| 화면/그리드 | persistId |
|---|---|
| 공통코드 대분류/시스템/사용자 | `code-mgmt-group` / `code-mgmt-sys` / `code-mgmt-usr` |
| 메뉴 | `menu-mgmt-master` |
| 권한그룹 | `role-mgmt-master` |
| 부서 | `dept-mgmt-master-v2` |
| 사용자 | `sys-user-management-v2` |
| 로그인/감사/통계 | `log-login-history` / `log-audit-log` / `log-screen-usage-statistics` |
| CodeLookupDialog | `code-lookup-dialog` |
