# pages/sys/code — 권한·사용자·코드

URL `/sys/code`. 시스템 기준정보 6화면.

| 하위 | 화면 | 표 |
|---|---|---|
| [`commoncode/`](commoncode/README.md) | `common-code-management` | `tbl_code` |
| [`menu/`](menu/README.md) | `menu-management` | `tbl_menu` |
| [`role/`](role/README.md) | `role-management` | `tbl_role` · `tbl_role_screen` |
| [`department/`](department/README.md) | `department-management` | `tbl_dept` |
| [`user/`](user/README.md) | `user-management` | `tbl_user` |
| [`approvalline/`](approvalline/README.md) | `approval-line-management` | `tbl_approval_line` · `_step` |

## 공통

- 6화면 모두 `MesEditableGrid` 단일 그리드 + `guardSaveWithKey` 저장 가드
- 삭제는 `validate-delete` → `delete` 2단계
- 그리드 하단에 **총건수**가 나온다. 숫자열 자동 합계는 없다 —
  집계는 컬럼이 `aggregationFn` 을 명시할 때만이다
  (정렬코드·순번까지 더해져 「정렬 합 173,762」가 찍히던 것을 2026-08-25 에 껐다)
