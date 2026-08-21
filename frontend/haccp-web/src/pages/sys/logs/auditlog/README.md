# 변경 감사 로그 (`audit-log`)

정본 파이프라인 요약은 상위 [`pages/sys/README.md`](../../README.md) 6장.

## 파일

| 파일 | 책임 |
|---|---|
| `AuditLogPage.tsx` | `LogPageShell`에 Rule만 꽂는 얇은 진입점. `key={scrnCd}` |
| `AuditLogRule.ts` | `scrnCd` · `persistId` · 컬럼 · `fetchRows`(리프 서버 필터, 폴더 FE 필터) |

공용 셸은 [`LogPageShell`](../../../components/layout/LogPageShell.tsx)다. 조회 전용이라 행추가·저장·삭제를 붙이지 않는다.

`scrnCd = audit-log` · `persistId = log-audit-log` — 값 변경 금지.

## API · SP · 테이블

| 동작 | API (`api/sys/auditLogApi.ts`) | SP | 테이블 |
|---|---|---|---|
| 조회 | `listAuditLog` | `sp_audit_log_r_000` | `tbl_audit_log` `tbl_user` |
| 좌측 메뉴 트리 | `menuApi.listAdminMenus` | `sp_menu_management_r_000` | `tbl_menu` `tbl_screen` |
| 적재 (화면 아님) | `AuditWriter.record` | `sp_tbl_audit_log_c_000` | `tbl_audit_log` |

행위 라벨은 공통코드 `audit-result`. 대상 표시명·트리 필터는 `audit-target`. 시스템 관리 5화면 저장·삭제가 `record(...)`를 부른다.
