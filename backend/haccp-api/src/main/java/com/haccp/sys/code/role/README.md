# com.haccp.sys.code.role — 권한그룹 관리

화면코드 `role-management` · XML `resources/mapper/sys/code/role/RoleMgmtMapper.xml` · SP `db_sasshaccp/01_sp.sql`

## 엔드포인트

| Method | URL | Service | SP | 테이블 |
|---|---|---|---|---|
| GET | `/api/v1/sys/code/role-management/list` | `list` | `sp_role_management_r_000` | `tbl_role` |
| PUT | `/api/v1/sys/code/role-management/save` | `save` | `sp_role_management_c_000` | `tbl_role` |
| POST | `/api/v1/sys/code/role-management/validate-delete` | `validateDelete` | `sp_role_management_delete_blocker_r_000` | `tbl_role` `tbl_user` |
| POST | `/api/v1/sys/code/role-management/delete` | `delete` | `sp_role_management_d_000` | `tbl_role` `tbl_user` `tbl_role_screen` |
| GET | `/api/v1/sys/code/role-management/screens?usrgrpCd` | `listScreens` | `sp_role_management_screen_r_000` | `tbl_screen` `tbl_role_screen` |
| PUT | `/api/v1/sys/code/role-management/screens` | `saveScreens` | `sp_role_management_screen_c_000` | `tbl_role_screen` |

## 규칙

- 그룹 저장과 화면권한 저장은 별개 트랜잭션이다. 저장되지 않은 신규 그룹에는 권한을 붙일 수 없다
- `saveScreens`는 화면 단위 upsert 루프이며 전체가 한 `@Transactional`이다
- 삭제는 소속 사용자가 있으면 차단된다. 화면권한 행은 삭제 SP가 함께 정리한다

## 영향 범위 (주의)

`sp_role_management_screen_r_000`은 로그인 인증 경로(`mapper/auth/AuthMapper.xml` → `AuthService`)가 함께 쓴다. 로그인 직후 화면·버튼 권한 판정이 이 SP 결과에 달려 있으므로, 컬럼을 바꾸면 **로그인 후 권한 회귀**를 반드시 확인한다. 구 `sp_tbl_role_screen_r_000`을 이 SP로 대체했다.
