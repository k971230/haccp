# company

테넌트 통째 삭제. **화면이 없다.** 회사관리 메뉴는 레지스트리에서 빠져 있다.

플랫폼 회사 `0000` 의 `ADMIN`·`HACCP_MASTER` 만 다른 회사를 지운다.
`0000` 과 로그인한 회사는 거절한다. 화면 권한 맵이 없어 `ScreenAuthResolver` 화이트리스트로 열고, 권한은 서비스가 본다.

```
POST /api/v1/sys/company/validate-delete
POST /api/v1/sys/company/delete
Body: [{ "coCd": "0099" }]
```

SP: `sp_tbl_company_exists_r_000` · `sp_tbl_company_purge_d_000`
E2E `purgeCompany` 는 HTTP 가 아니라 시험 DB 에서 SP 를 직접 부른다 (`assertTestDb` 유지).
없는 회사는 SP 가 조용히 끝낸다. validate-delete 는 없음을 거절한다.

## 관련
- 정본: `.cursor/rules/08-haccp-backend.mdc` · `.cursor/rules/06-operations.mdc`
