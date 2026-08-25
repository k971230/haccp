# HACCP 인증 · 권한 · 보안 (JWT)

> 정본: `9_인증_보안_JWT_FE.md`  
> 작성일: 2026-08-10 · 개발자: 박승우  
> BE 대칭: [`10_인증_보안_JWT_BE.md`](10_인증_보안_JWT_BE.md)  
> 파일 path traversal·볼륨: [`11`](18_프레임워크_파일_보안_작성규칙.md) §2~3

MES와 차이: **아이디만 로그인**(회사 콤보 없음) · 권한 **5종 Y/N** · JWT **단일 TTL** · storage `haccp-*`.

---

## 1. 규칙 요약

| 항목 | 값 |
|------|-----|
| 토큰 | JWS **HS512** (`JwtProvider`) |
| TTL | `JWT_EXPIRE_MINUTES` 기본 **480** (현장 별도 TTL 없음) |
| Secret | 64바이트 이상 — 짧으면 기동 실패 |
| 공개 API | **`POST /api/v1/auth/login`만** (`JwtFilter.isPublic`) |
| CORS | `CORS_ALLOWED_ORIGINS` (로컬 `http://localhost:4173`) · credentials false |
| 잠금 | `LOGIN_MAX_FAIL_COUNT` 기본 5 · 0 이하면 잠금 OFF |
| 관리자 | `usrgrpCd === "ADMIN"` (아이디 하드코딩 아님) |

클레임: `coCd` `coNm` `userId` `userNm` `usrgrpCd` `deptCd` `deptNm` `sid`

---

## 2. 로그인 파이프라인 (파일)

| 단계 | 내용 | 파일 |
|------|------|------|
| 1 | Hydration · 토큰 유효 | `authStore` · `AppRoutes` Protected · `authSession.isTokenValid` |
| 2 | 아이디 저장 prefs | `LoginPage` · `loginPrefs` |
| 3 | Submit | `LoginPage.onSubmit` |
| 4 | POST login | `authApi.login` |
| 5 | 자격·잠금·이력 | `AuthController` · `AuthService` · `AuthMapper.xml` |
| 6 | JWT 발급 | `JwtProvider.createToken` |
| 7 | persist 격리 | `authStore` · `haccp-auth` |
| 8 | Protected | `AppRoutes` |
| 9 | Bearer | `api/http.ts` 인터셉터 |
| 10 | 로그아웃 | `clearAuthSession` · `authApi.logout` |
| 10b | 멀티탭 | `authCrossTab` · `haccp-auth-logout-signal` · **`authPaths`(base `/haccp/`)** — G-22 |

**중요:** `AuthService.login`에 `@Transactional` 없음 — 실패 이력이 롤백되면 안 됨.

---

## 3. 화면 권한 5종

| perm | 의미 | UI |
|------|------|-----|
| `read` | 조회 | 메뉴·진입 |
| `write` | 등록 | 신규 |
| `modify` | 수정 | 저장·편집 |
| `delete` | 삭제 | 삭제 버튼 |
| `print` | 출력 | CSV/PDF 등 |

FE: `useAuthStore.getState().can(scrnCd, perm)` — 값이 `"Y"`일 때만.  
BE: 업무 API는 JWT 필수. 화면 권한은 FE 게이트 + `ScreenAuthInterceptor`(tbl_role_screen). 메뉴는 SP가 role과 결합.

---

## 4. 테넌트 격리

- Service/Mapper는 항상 `LoginUserContext.coCd()`  
- 요청 JSON에 `coCd`/`userId`를 **받지 않음** (위조 방지)  
- 파일 경로 첫 세그먼트 = `coCd` (`DocumentFileStorage`)

---

## 5. FE 세션·리다이렉트

| 심볼 | 역할 |
|------|------|
| `clearAuthSession` | 토큰·스토어 정리 + 크로스탭 신호 |
| `handleUnauthorized` | 401·타 탭 로그아웃 → 로그인 (`loginBrowserPath`) |
| `saveReturnUrl` / `resolvePostLoginPath` | 복귀 |
| `isSafeReturnPath` | open redirect 방지 (`/` 시작, `//` 금지) |
| `loginBrowserPath` / `isLoginBrowserPath` / `toRouterPath` | Vite base 정합 (`authPaths.ts`) |

키: `AUTH_STORAGE_KEY=haccp-auth` · `AUTH_LOGOUT_SIGNAL_KEY=haccp-auth-logout-signal`

### 5.1 멀티탭 로그아웃 (G-22 · MES F174)

| MES 규약 | HACCP |
|----------|-------|
| `clearAuthSession` → `broadcastAuthLogout` | 동일 |
| 신호 키 `mes-auth-logout-signal` (localStorage) | `haccp-auth-logout-signal` |
| 타 탭 `storage` → `handleUnauthorized` | 동일 (`main.tsx` 구독) |
| 자동로그인 OFF(sessionStorage)여도 신호는 local | 동일 |

수동 스모크: 탭 2개 로그인 → 탭1 로그아웃 → 탭2가 로그인 화면으로 이동. Path 운영 URL은 `…/haccp/login`.  
단위: `src/shell/authPaths.test.ts` · `authCrossTab.test.ts`. 상세 시퀀스: [`08` §3.4](15_HACCP_FE_BE_통합_상세스펙.md).

---

## 6. 로그인 이력·시스템 화면

- 테이블: `tbl_login_log` (`02_ddl_log.sql`) — result S/F/L
- 조회: `LoginHistoryController` `GET /api/v1/sys/login-history/list`
- FE: `pages/sys/loginhistory/LoginHistoryPage` + `LoginHistoryRule` (`LogPageShell`)

---

## 7. 운영 체크리스트

- [ ] `JWT_SECRET` 64B+ · `JWT_EXPIRE_MINUTES`  
- [ ] `LOGIN_MAX_FAIL_COUNT`  
- [ ] `CORS_ALLOWED_ORIGINS`에 실제 FE origin  
- [ ] 운영 HTTPS·시크릿은 배포 런북 (`20_배포_런북.md`)  
- [ ] 로그아웃 시 타 탭도 끊기는지  

---

## 8. 보안 범위 (이 문서 vs 11)

| 주제 | 문서 |
|------|------|
| JWT·권한·잠금·CORS·세션 | **본 문서(04)** |
| 업로드 path traversal · 파일명 sanitize · 템플릿 경로 | **11** |
| 서명 등록·클립보드·실패 시 (G-24) | **[`11` §2.8](18_프레임워크_파일_보안_작성규칙.md)** |
| XSS(sanitize) · 에러 메시지 누출 차단 | **11** · `lib/sanitize` · `SqlUserMessage` |

---

*인증·권한 정본.*
