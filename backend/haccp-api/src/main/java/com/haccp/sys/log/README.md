# com.haccp.sys.log — 로그 3화면 (조회) + 감사 적재기

XML `resources/mapper/sys/log/*.xml` · SP `db_sasshaccp/77_migrate_sp_log_screens_v2.sql`

## 구성

| 화면코드 | 클래스 | URL | SP | 테이블 |
|---|---|---|---|---|
| `login-history` | `LoginHistoryController` · `Service` · `Mapper` | `GET /api/v1/sys/login-history/list` | `sp_login_history_r_000` | `tbl_login_log` `tbl_user` |
| `audit-log` | `AuditLogController` · `Service` · `Mapper` | `GET /api/v1/sys/audit-log/list` | `sp_audit_log_r_000` | `tbl_audit_log` `tbl_user` |
| `screen-usage-statistics` | `ScreenUsageController` · `Service` · `Mapper` | `GET /api/v1/sys/screen-usage-statistics/list` | `sp_screen_usage_statistics_r_000` | `tbl_view_stat_daily` `tbl_menu` `tbl_screen` |

구 `sp_tbl_login_log_r_000` · `sp_tbl_audit_log_r_000` · `sp_tbl_view_stat_daily_r_000`을 위 3개로 대체했다.

## AuditWriter — 변경 감사 적재기

`AuditWriter.record(tblNm, tgtIdx, actionCd, after)` 하나로 시스템 관리 5화면이 이력을 남긴다. 적재 SP는 테이블 단위라 이름이 `sp_tbl_audit_log_c_000`이다.

| 호출부 | tbl_nm | 행위 |
|---|---|---|
| `commoncode.CommonCodeService` | `tbl_code` | 저장 I·U / 삭제 D |
| `menu.MenuMgmtService` | `tbl_menu` | 저장 I·U / 삭제 D |
| `role.RoleMgmtService` | `tbl_role` · `tbl_role_screen` | 그룹 저장 I·U / 삭제 D / 화면권한 저장 U |
| `department.DepartmentService` | `tbl_dept` | 저장 I·U / 삭제 D |
| `user.UserService` | `tbl_user` | 저장 I·U / 삭제 D / 서명 업로드·삭제 U |
| `doc.DocumentService` | `tbl_document` · `tbl_document_file` | 자체 `insertAudit` 사용 (기존 경로 유지) |

- 회사코드·행위자는 JWT, IP는 `RequestContextHolder`로 현재 요청에서 뽑는다 — Controller 시그니처를 바꾸지 않는다
- 원 업무와 같은 트랜잭션이라 저장이 롤백되면 이력도 사라진다. "실패한 변경"이 남지 않는다
- `before_json`은 남기지 않는다. 저장 SP가 UPSERT라 직전 값을 다시 읽어야 하고 그 비용을 지지 않기로 했다
- `after_json`은 화면 payload 그대로다. `_key`·`_rowState` 같은 그리드 전용 필드는 버리고 `userPw` 계열은 `***`로 가린다
- 대상 테이블은 `audit-target` 공통코드(`sub_cd`=테이블명, `ref1`=화면코드)에 등록돼야 화면에 표시명과 트리 필터가 붙는다. 신규 대상 추가 시 `db_sasshaccp/09_seed_platform.sql`과 업체 복제를 함께 갱신한다 (`82_migrate_audit_target_sys.sql` 참고)

## 규칙

- **화면 3개는 조회 전용이다.** save·delete 엔드포인트를 만들지 않는다 (적재는 각 업무 도메인이 AuditWriter로 한다)
- 기간 파라미터는 Controller가 `YYYYMMDD` 8자리로 정규화(`SysPayload.normalizeDate`)한 뒤 Service에 넘긴다. FE는 `YYYY-MM-DD`로 보내도 되고, 빈 값이면 오늘로 채운다. SP는 8자리만 받는다
- 파라미터는 시작일·종료일 + 화면별 키(`userId` 또는 `scrnCd`) + 결과코드. 폴더 노드 필터는 FE가 처리하므로 서버에 하위 목록을 넘기지 않는다
- 적재 SP(`sp_tbl_login_log_c_000` · `sp_tbl_view_log_c_000` · `sp_tbl_view_stat_daily_c_000`)는 각 발생 지점(인증·화면 진입)이 호출한다. 조회 SP와 혼동하지 않는다. 감사 적재 `sp_tbl_audit_log_c_000`만 이 패키지의 `AuditWriter`를 거친다
- 화면 이용 통계 3지표는 집계 SP가 만든다. PV = 진입 건수, UV = `distinct user_id`, IP = `distinct ip_addr`. `ip_cnt`는 컬럼을 뒤늦게 추가해 과거분이 전부 0이었고 `db_sasshaccp/79_migrate_view_stat_backfill.sql`로 전 일자를 재집계해 해소했다
- 감사 로그의 대상 구분(`audit-target`) 조인도 회사코드 격리다. `tbl_code`를 `c.co_cd = p_co_cd`로 조인하므로 업체별 표준코드 복제가 선행돼야 한다

## FE 대응

세 화면은 `pages/sys/log/LogPageShell.tsx` 하나를 공유하고 화면별 차이는 `*Rule.ts`가 갖는다 (`frontend/haccp-web/src/pages/sys/log/README.md`).
