# com.haccp.sys.code.menu — 메뉴 관리

화면코드 `menu-management` · XML `resources/mapper/sys/code/menu/MenuMgmtMapper.xml` · SP `db_sasshaccp/73_migrate_sp_menu_mgmt_v2.sql`

## 엔드포인트

| Method | URL | Service | SP | 테이블 |
|---|---|---|---|---|
| GET | `/api/v1/sys/code/menu-management/list` | `list` | `sp_menu_management_r_000` | `tbl_menu` `tbl_screen` |
| PUT | `/api/v1/sys/code/menu-management/save` | `save` | `sp_menu_management_c_000` | `tbl_menu` |
| POST | `/api/v1/sys/code/menu-management/validate-delete` | `validateDelete` | `sp_menu_management_delete_blocker_r_000` | `tbl_menu` `tbl_role_screen` |
| POST | `/api/v1/sys/code/menu-management/delete` | `delete` | `sp_menu_management_d_000` | `tbl_menu` `tbl_role_screen` |

## 사이드바와 분리된 이유

같은 `tbl_menu`를 읽지만 쿼리가 다르다.

| 용도 | SP | 특징 |
|---|---|---|
| 메뉴 관리 화면 | `sp_menu_management_r_000` | 관리자 전체 메뉴, 화면코드·정렬 포함 |
| 사이드바 트리 | `sp_menu_nav_r_000` (`mapper/menu/MenuMapper.xml`) | 로그인 사용자 권한(`tbl_role_screen`) 필터 |

한 SP로 합치지 않는다. 구 `sp_tbl_menu_r_000`·`sp_tbl_menu_admin_r_000`을 이 둘로 대체했다.

## 규칙

- 메뉴 신규 생성은 이 API로 하지 않는다. 메뉴코드·상위·화면코드·정렬은 시드·migrate로만 만든다 (FE도 행추가 잠금)
- 저장은 메뉴명·사용여부만 반영한다
- 삭제는 하위 메뉴 또는 화면권한 참조가 있으면 차단된다
