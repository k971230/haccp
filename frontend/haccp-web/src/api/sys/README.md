# api/sys — 시스템 9화면 API

`/sys` 대분류. 베이스는 `apiOf(scrnCd)` 가 `SCREEN_PATH` 로 조립한다 — 화면코드와 1:1 이다.

| 파일 | 화면 |
|---|---|
| `commonCodeApi.ts` | `common-code-management` |
| `menuApi.ts` | `menu-management` |
| `roleApi.ts` | `role-management` |
| `departmentApi.ts` | `department-management` |
| `userApi.ts` | `user-management` |
| `approvalLineApi.ts` | `approval-line-management` |
| `loginHistoryApi.ts` | `login-history` |
| `screenUsageApi.ts` | `screen-usage-statistics` |
| `auditLogApi.ts` | `audit-log` |
| `sysTypes.ts` | 위 9개가 공유하는 행·요청 타입 |

## 규칙

- 삭제는 `validate-delete` → `mesConfirm` → `delete` 2단계. HTTP DELETE 를 쓰지 않는다
- `coCd`·`userId` 를 본문에 담지 않는다 — 서버가 JWT 에서 강제한다
- 목록 응답의 snake 키는 `camelizeRows` 가 맞춘다 (그리드 field 바인딩)
