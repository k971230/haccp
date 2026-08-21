# approvalline — 결재선 관리 (`approval-line-management`)

화면 1개 = 패키지 1개. 파이프라인 표는 FE `pages/sys/README.md`.

XML `resources/mapper/sys/approvalline/ApprovalLineMapper.xml` · SP `db_sasshaccp/18_sp_workflow.sql` · `97_migrate_approval_line_sys.sql`

URL은 폴더를 옮겨도 `/api/v1/bas/approval-lines/*` 를 유지한다.

## 엔드포인트

| Method | URL | Service | SP | 테이블 |
|---|---|---|---|---|
| GET | `/api/v1/bas/approval-lines/list` | `list` | `sp_tbl_approval_line_r_000` | `tbl_approval_line` `tbl_approval_line_step` |
| PUT | `/api/v1/bas/approval-lines/save` | `save` | `sp_tbl_approval_line_c_000` | 위 |
| POST | `/api/v1/bas/approval-lines/validate-delete` | `validateDelete` | `sp_tbl_approval_line_delete_blocker_r_000` | 위 + 참조 |
| POST | `/api/v1/bas/approval-lines/delete` | `delete` | `sp_tbl_approval_line_d_000` | 위 |

왼쪽 삭제 버튼이 validate-delete → delete 를 탄다. 검토(REVIEW) 기본 `use_yn=N`. 상신은 사용(Y) 단계만 스냅샷한다.
