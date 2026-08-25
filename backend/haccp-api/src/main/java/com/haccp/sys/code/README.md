# com.haccp.sys.code — 권한·사용자·코드

FE `pages/sys/code` 6화면과 1:1. URL `/api/v1/sys/code/{scrnCd}`.

| 하위 | 화면 | 표 |
|---|---|---|
| [`commoncode/`](commoncode/README.md) | `common-code-management` | `tbl_code` |
| [`menu/`](menu/README.md) | `menu-management` | `tbl_menu` |
| [`role/`](role/README.md) | `role-management` | `tbl_role` · `tbl_role_screen` |
| [`department/`](department/README.md) | `department-management` | `tbl_dept` |
| [`user/`](user/README.md) | `user-management` | `tbl_user` |
| [`approvalline/`](approvalline/README.md) | `approval-line-management` | `tbl_approval_line` · `_step` |

## 공통

- 회사코드·작업자는 **JWT 에서만** 읽는다. 요청 본문의 `coCd`·`userId` 를 신뢰하지 않는다
- 삭제는 `validate-delete` → `delete` 2단계 (`OPS_DELETE`)
- 비밀번호는 Service 가 BCrypt 로 해시한 뒤에만 SP 로 넘긴다 (`UserService`)
