# backend 단위 테스트

`./mvnw test` 로 도는 JUnit 5 테스트. **DB·기동 없이** 도는 것만 여기 둔다.

DB 를 붙여야 확인되는 것은 프론트의 Playwright E2E 가 맡는다 —
`frontend/haccp-web/e2e/`, 결과는 루트 [`E2E.md`](../../../../../../../E2E.md).

## 무엇을 여기서 보는가

| 기준 | 뜻 |
|---|---|
| **순수 계산** | 날짜 생성기·권한 판정처럼 입출력이 값으로 끝나는 것 |
| **분기가 많은 것** | 화면으로 다 밟기 어려운 경우의 수 (주기 7종, 월말 보정 …) |
| **회귀 고정** | 한 번 터진 규칙을 값으로 못 박아 둔다 |

반대로 **화면·API·SP 가 이어지는지는 여기서 안 본다.** `mvn test` 통과가
기동 성공이나 화면 동작을 뜻하지 않는다 (MyBatis 매퍼 XML 은 컴파일에 안 잡힌다).

## 파일

| 파일 | 맡는 것 |
|---|---|
| `common/auth/ScreenAuthResolverTest` | URL → `scrnCd`·권한 종류 매핑. 화면을 옮기면 여기가 먼저 깨진다 |
| `common/auth/ScreenAuthInterceptorTest` | 권한 없는 호출을 실제로 막는지 (deny 로그 포함) |
| `docs/sch/CycleScheduleGeneratorTest` | 주기 → 예정일 생성. 월말 보정·비영업일 이동·시작일 이전 제외 |
| `draft/DraftSupportSeedTest` | 작성 화면 공통 시드 값 정규화 |
| `draft/hwp/HwpDraftServiceDetailTest` | HWP 작성 상세 조립 |

## 테스트를 더할 때

- 폴더는 **대상 클래스와 같은 패키지**에 둔다 (`com.haccp.{대}.{중}`)
- 이름은 `{대상}Test`
- 한글 메서드명을 쓰지 않는다 — 리포트·CI 로그에서 깨진다. 대신 무엇을 보는지 주석으로 적는다
- DB·스프링 컨텍스트가 필요해지면 그건 E2E 로 보낸다

## 관련

- 규칙: `.cursor/rules/08-backend.mdc`
- 실행: `cd backend/haccp-api ; ./mvnw -q -o test`

## 변경

- 2026-08-25 — README 신설. 단위 테스트와 E2E 의 경계를 적었다
