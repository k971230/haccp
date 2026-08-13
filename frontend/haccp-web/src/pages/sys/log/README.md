# 로그 3화면 (`login-history` · `audit-log` · `screen-usage-statistics`)

정본 파이프라인 요약은 상위 [`pages/sys/README.md`](../README.md) 6장.

## 구조

```
LogPageShell.tsx                 공용 셸 — 기간 검색 · 좌측 트리 · 그리드 뼈대
LoginHistoryPage.tsx             <LogPageShell key rule={LOGIN_HISTORY_RULE} />
LoginHistoryRule.ts
AuditLogPage.tsx                 <LogPageShell key rule={AUDIT_LOG_RULE} />
AuditLogRule.ts
ScreenUsageStatisticsPage.tsx    <LogPageShell key rule={SCREEN_USAGE_RULE} />
ScreenUsageStatisticsRule.ts
```

`*Page.tsx`는 Rule을 셸에 꽂는 얇은 래퍼다. 화면별 로직을 Page에 넣지 않는다.

## LogRule 계약

| 필드 | 의미 |
|---|---|
| `scrnCd` · `persistId` | 그리드 pref 키. 값 변경 금지 |
| `title` · `treeTitle` | 페이지·좌측 패널 제목 |
| `treeKind` | `"user"`(사용자 평면) 또는 `"menu"`(관리자 메뉴 계층) |
| `rangeDays` | 기간 기본값(30일). 하드코딩 금지, Rule에서만 준다 |
| `codeGroup` | 결과 콤보용 공통코드 대분류. 없으면 `undefined` |
| `buildColumns(...)` | `GridColumn[]` 팩터리 |
| `fetchRows(params)` | 조회 + 후처리(FE 필터·날짜 포맷)까지 담당 |

## 상태 격리 (중요)

`LogPageShell`은 상태 없는 순수 셸이 아니라 **인스턴스별 상태를 갖는 컴포넌트**다. `HaccpShell`이 탭을 `hidden`으로 동시 마운트하므로 세 화면이 공존한다.

- 각 Page가 `key={RULE.scrnCd}`를 주어 렌더한다 — 탭 전환·재마운트 시 기간·트리 선택·행이 섞이지 않게 한다
- 모듈 레벨 `let`·싱글턴 캐시 금지. 캐시가 필요하면 컴포넌트 상태나 React Query로 둔다

## 화면별 계약

| 화면 | 트리 | 코드 대분류 | API (`api/sys/logApi.ts`) | SP |
|---|---|---|---|---|
| 로그인 이력 | 사용자 평면 (`userApi.listUsers`) | `login-result` | `listLoginHistory` | `sp_login_history_r_000` |
| 변경 감사 로그 | 메뉴 계층 (`menuApi.listAdminMenus`) | `audit-result` | `listAuditLog` | `sp_audit_log_r_000` |
| 화면 이용 통계 | 메뉴 계층 | 없음 | `listScreenUsage` | `sp_screen_usage_statistics_r_000` |

리프 노드는 서버 조건(`userId`·`scrnCd`)으로 좁히고, 폴더 노드는 기간 전건 조회 후 Rule의 `fetchRows`가 하위 키 집합으로 FE 필터한다. 셸이 내보내는 트리 유틸(`buildMenuTree`·`collectScrnCds`·`collectAuditKeys`·`findHierNode`)을 Rule이 재사용한다.

## 감사 로그에 무엇이 쌓이나

`tbl_audit_log`는 화면이 아니라 **각 업무 저장·삭제가 남긴다**. 대상은 문서함·문서 파일과 시스템 관리 5화면(공통코드·메뉴·권한그룹+화면권한·부서·사용자)이다. 다른 업무 화면은 아직 대상이 아니라 조회해도 행이 없다.

- 대상 목록은 `audit-target` 공통코드(`sub_cd`=테이블명, `ref1`=화면코드)가 정한다. 좌측 트리 필터도 이 `ref1`로 맞춘다
- 적재부는 백엔드 `com.haccp.sys.log.AuditWriter` — 새 화면을 대상에 넣으려면 서비스에서 `record(...)`를 부르고 공통코드에 대상 1건을 추가한다
- 비밀번호는 `***`로 가려 저장되므로 그리드에 평문이 뜨지 않는다

## 공통 제약

세 화면 모두 **조회 전용**이다. 행추가·저장·삭제 버튼을 붙이지 않는다.
