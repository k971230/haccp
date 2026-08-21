# 권한그룹 관리 (`role-management`)

정본 파이프라인 요약은 상위 [`pages/sys/README.md`](../../README.md) 3장.

## 파일

| 파일 | 책임 |
|---|---|
| `RoleManagementPage.tsx` | 렌더·상태·API 호출. 좌 권한 트리(체크박스) + 우 권한그룹 CRUD 그리드 |
| `RoleManagementRule.ts` | `SCRN_CD` · `PERSIST_ID` · 컬럼 팩터리 · `ROLE_RULES` · `newRoleRow` · `matchRole` · `buildRoleTree` · `collectLeafScrn` |

## 화면 규칙

- 좌측 트리는 **저장된 권한그룹을 선택했을 때만** 활성화된다. 신규 행(`_rowState === "C"`, = 아직 DB에 없는 행)은 화면권한을 붙일 대상이 없다
- 트리 리프 = 화면(`scrn_cd`), 체크 = 조회권한(`read_yn`). 폴더 체크는 하위 리프 전체 토글
- 권한그룹 코드(`usrgrpCd`)는 신규 행에서만 입력 가능
- 그룹 저장과 권한 저장은 **별개 버튼**이다. 그룹을 저장하지 않은 채 권한만 저장할 수 없다

## API · SP · 테이블

| 동작 | API (`api/sys/roleApi.ts`) | SP | 테이블 |
|---|---|---|---|
| 그룹 조회 | `listRoles` | `sp_role_management_r_000` | `tbl_role` |
| 화면권한 조회 | `listRoleScreens(usrgrpCd)` | `sp_role_management_screen_r_000` | `tbl_screen` `tbl_role_screen` |
| 그룹 저장 | `saveRoles` | `sp_role_management_c_000` | `tbl_role` |
| 화면권한 저장 | `saveRoleScreens` | `sp_role_management_screen_c_000` | `tbl_role_screen` |
| 삭제 검증 | `validateDeleteRoles` | `sp_role_management_delete_blocker_r_000` | `tbl_role` `tbl_user` |
| 삭제 | `deleteRoles` | `sp_role_management_d_000` | `tbl_role` `tbl_user` `tbl_role_screen` |

트리 원본은 `api/sys/menuApi.listAdminMenus`다.

## 로그인 권한과의 관계

로그인 직후 버튼·화면 권한 판정도 `sp_role_management_screen_r_000`을 쓴다(`mapper/auth/AuthMapper.xml`). 이 SP의 컬럼을 바꾸면 **로그인 경로가 함께 깨진다**. 변경 시 로그인 후 권한 회귀를 반드시 확인한다.

## pref 키

`scrnCd = role-management` · `persistId = role-mgmt-master` — 값 변경 금지.
