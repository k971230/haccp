# 로그인 이력 (`login-history`)

정본 파이프라인 요약은 상위 [`pages/sys/README.md`](../README.md) 6장.

## 파일

| 파일 | 책임 |
|---|---|
| `LoginHistoryPage.tsx` | `LogPageShell`에 Rule만 꽂는 얇은 진입점. `key={scrnCd}` |
| `LoginHistoryRule.ts` | `scrnCd` · `persistId` · 컬럼 · `fetchRows` |

공용 셸은 [`LogPageShell`](../../../components/layout/LogPageShell.tsx)다. 조회 전용이라 행추가·저장·삭제를 붙이지 않는다.

`scrnCd = login-history` · `persistId = log-login-history` — 값 변경 금지.

## API · SP · 테이블

| 동작 | API (`api/sys/loginHistoryApi.ts`) | SP | 테이블 |
|---|---|---|---|
| 조회 | `listLoginHistory` | `sp_login_history_r_000` | `tbl_login_log` `tbl_user` |
| 좌측 사용자 트리 | `userApi.listUsers` | `sp_user_management_r_000` | `tbl_user` `tbl_dept` `tbl_role` |

결과 라벨은 공통코드 `login-result`. 「전체」가 아니면 `userId`로 서버 필터한다.
