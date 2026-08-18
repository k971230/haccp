# com.haccp.sys.auditlog — 변경 감사 로그 (조회) + 적재기

화면코드 `audit-log` · XML `resources/mapper/sys/auditlog/AuditLogMapper.xml` · SP `db_sasshaccp/77_migrate_sp_log_screens_v2.sql`

## 엔드포인트

| Method | URL | Service | SP | 테이블 |
|---|---|---|---|---|
| GET | `/api/v1/sys/audit-log/list` | `list` | `sp_audit_log_r_000` | `tbl_audit_log` `tbl_user` |
| (적재) | `AuditWriter.record` | `insertAudit` | `sp_tbl_audit_log_c_000` | `tbl_audit_log` |

조회 전용이다. save·delete 엔드포인트를 만들지 않는다. 적재는 `AuditWriter.record(...)`가 `sp_tbl_audit_log_c_000`을 부른다.

## AuditWriter

시스템 관리 5화면(공통코드·메뉴·권한그룹·부서·사용자)이 같은 규칙으로 이력을 남긴다. 호출부는 각 Service의 save·delete.

FE: `pages/sys/auditlog/` · 공용 셸 `components/layout/LogPageShell.tsx`
