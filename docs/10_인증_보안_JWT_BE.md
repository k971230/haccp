# haccp-api 인증 · 보안

> FE 정본(파이프라인 표): [`9_인증_보안_JWT_FE.md`](9_인증_보안_JWT_FE.md)  
> 파일 보안: FE [`11`](18_프레임워크_파일_보안_작성규칙.md)

## 핵심 클래스

| 클래스 | 역할 |
|--------|------|
| `JwtFilter` | Bearer · public=`/api/v1/auth/login` only |
| `JwtProvider` | HS512 · `JWT_SECRET` · `JWT_EXPIRE_MINUTES` |
| `WebConfig` | CORS `/api/**` |
| `LoginUserContext` | coCd/userId/sid |
| `AuthService` | login/lock/이력 · **비트랜잭션** |
| `DocumentFileStorage` | path traversal 차단 |

## env

`JWT_SECRET`(64B+) · `JWT_EXPIRE_MINUTES` · `LOGIN_MAX_FAIL_COUNT` · `CORS_ALLOWED_ORIGINS`

## 권한

화면 5종은 FE `can()` + 메뉴 SP. API는 JWT+테넌트 강제. 관리자=`usrgrpCd==ADMIN`.
