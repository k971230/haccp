# config

Spring 설정 — 요청이 컨트롤러에 닿기 전과 응답이 나간 뒤에 도는 것들.

| 파일 | 맡는 것 |
|---|---|
| `JwtProvider` | 토큰 발급·검증. 서명키·만료는 `.env` 에서 읽는다 |
| `JwtFilter` | 요청 헤더의 토큰을 풀어 `LoginUserContext` 에 담는다 |
| `SecurityHeadersFilter` | 전 응답에 `X-Content-Type-Options: nosniff` · `Referrer-Policy: same-origin` |
| `WebConfig` | CORS · 인터셉터 등록 (`ScreenAuthInterceptor`) |

**안 맡는 것** — 화면별 권한 판정은 `common/auth/ScreenAuthResolver` 다.
비밀번호 비교·잠금은 `auth/AuthService` 다.

## 왜 헤더를 한 곳에서 거는가

파일 바이너리를 되돌려 주는 컨트롤러가 넷이다 —
문서첨부(`docs/documents`) · 양식(`docs/templates`) · 서명(`sys/code/user`) · 감사PDF(`tsk`).
네 군데에 따로 붙이면 다섯 번째가 생겼을 때 빠진다.

2026-08-27 에 서명 업로드가 **올린 쪽이 준 `Content-Type` 을 그대로 저장**했다가
`inline` 으로 돌려주던 것을 고쳤다. 그 경로는 `UserService` 에서 MIME 을 확장자로 못 박아
막았고, 이 필터는 나머지 셋까지 덮는 겹이다. 배경은 `배포후_개선점.md` J 절.

## 관련
- 테스트: `common/auth/ScreenAuthResolverTest` · `auth/AuthServiceGuardTest`
- 정본: [`docs/7_보안과_파일.md`](../../../../../../../../../docs/7_보안과_파일.md)
