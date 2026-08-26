# auth 파이프라인 (FE + BE)

로그인만. **평탄.** 공개 라우트 `/login` (브라우저 Path `/haccp/login`).

| 파일 | 역할 |
|------|------|
| `LoginPage.tsx` | 아이디·비밀번호. 회사 콤보 없음. JWT는 `authStore` |
| `api/authApi.ts` | `POST /api/v1/auth/login` |
| BE `AuthController` · `AuthService` · `AuthMapper.xml` | `sp_tbl_user_login_r_000`. `@Transactional` 금지(실패 이력) |

셸 세션: `shell/authSession.ts` · `authCrossTab.ts` · `authPaths.ts`. 이야기 [`docs/9`](../../../../../docs/7_보안과_파일.md) · [`docs/10`](../../../../../docs/7_보안과_파일.md).
