# approvalline — 결재선 관리 (`approval-line-management`)

화면 1개 = 패키지 1개. 파이프라인 표는 FE `pages/sys/README.md`.

XML `resources/mapper/sys/code/approvalline/ApprovalLineMapper.xml` · SP `db_sasshaccp/01_sp.sql`

URL은 `/api/v1/sys/code/approval-line-management/*` 이다.

## 엔드포인트

| Method | URL | Service | SP | 테이블 |
|---|---|---|---|---|
| GET | `/api/v1/sys/code/approval-line-management/list` | `list` | `sp_tbl_approval_line_r_000` | `tbl_approval_line` `tbl_approval_line_step` |
| PUT | `/api/v1/sys/code/approval-line-management/save` | `save` | `sp_tbl_approval_line_c_000` | 위 |
| POST | `/api/v1/sys/code/approval-line-management/validate-delete` | `validateDelete` | `sp_tbl_approval_line_delete_blocker_r_000` | 위 + 참조 |
| POST | `/api/v1/sys/code/approval-line-management/delete` | `delete` | `sp_tbl_approval_line_d_000` | 위 |

왼쪽 삭제 버튼이 validate-delete → delete 를 탄다. 단계는 작성·승인 2단. 상신은 사용(Y) 단계만 스냅샷한다.
