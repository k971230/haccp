# com.haccp.sys.department — 부서 관리

화면코드 `department-management` · XML `resources/mapper/sys/department/DepartmentMapper.xml` · SP `db_sasshaccp/75_migrate_sp_dept_mgmt_v2.sql`

## 엔드포인트

| Method | URL | Service | SP | 테이블 |
|---|---|---|---|---|
| GET | `/api/v1/sys/department-management/list` | `list` | `sp_department_management_r_000` | `tbl_dept` |
| PUT | `/api/v1/sys/department-management/save` | `save` | `sp_department_management_c_000` | `tbl_dept` |
| POST | `/api/v1/sys/department-management/validate-delete` | `validateDelete` | `sp_department_management_delete_blocker_r_000` | `tbl_dept` `tbl_user` |
| POST | `/api/v1/sys/department-management/delete` | `delete` | `sp_department_management_d_000` | `tbl_dept` `tbl_user` |

## 규칙

- 조회 SP가 상위부서명(`hdept_nm`)까지 내려준다. FE가 별도 조회로 이름을 붙이지 않는다
- 상위부서 코드가 빈 값이면 최상위 부서다
- 삭제는 하위 부서 또는 소속 사용자가 있으면 차단된다
- 부서 트리는 FE에서 조립한다. 서버는 평면 목록만 준다
