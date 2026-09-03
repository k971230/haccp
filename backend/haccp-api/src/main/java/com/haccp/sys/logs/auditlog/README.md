# com.haccp.sys.logs.auditlog — 변경 감사 로그 (조회) + 적재기

화면코드 `audit-log` · XML `resources/mapper/sys/logs/auditlog/AuditLogMapper.xml` · SP `db_sasshaccp/01_sp.sql`

## 엔드포인트

| Method | URL | Service | SP | 테이블 |
|---|---|---|---|---|
| GET | `/api/v1/sys/logs/audit-log/list` | `list` | `sp_audit_log_r_000` | `tbl_audit_log` `tbl_user` |
| (적재) | `AuditWriter.record` | `insertAudit` | `sp_tbl_audit_log_c_000` | `tbl_audit_log` |

조회 전용이다. save·delete 엔드포인트를 만들지 않는다. 적재는 `AuditWriter.record(...)`가 `sp_tbl_audit_log_c_000`을 부른다.

## AuditWriter

조회를 뺀 메뉴 쓰기(기준정보·양식·주기·개선조치·작성 저장/삭제·결재)가 같은 규칙으로 이력을 남긴다. 화면코드는 요청 컨텍스트(`X-Haccp-Scrn` · URL 맵). 호출부는 각 Service의 save·delete·결재.

FE: `pages/sys/logs/auditlog/` · 공용 셸 `components/layout/LogPageShell.tsx`
