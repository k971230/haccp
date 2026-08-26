# common/auth — 화면 권한 인터셉터

JWT 다음 단계다. **로그인했는지**는 `JwtFilter` 가, **그 화면을 만질 권한이 있는지**는 여기가 본다.

| 파일 | 역할 |
|---|---|
| `ScreenAuthInterceptor.java` | `/api/**` 전 요청을 가로채 권한행과 대조한다. `WebConfig` 가 등록 |
| `ScreenAuthResolver.java` | 요청 경로 → 화면코드·권한 칸. FE `SCREEN_PATH` 와 같은 칸을 쓴다 |
| `ScreenAuthMatch.java` | 판정 결과 — 화면코드 + 권한 칸 |
| `ScreenAuthAction.java` | 권한 칸 — READ·SAVE·DELETE·PRINT |

## 왜 필요한가

화면에서 버튼을 숨기는 것만으로는 막히지 않는다. API 를 직접 부르면 그대로 통한다.
읽기 전용 계정이 `POST /delete` 를 불러도 **403** 이어야 한다.

## 화면을 추가·이동할 때

`ScreenAuthResolver` 의 경로 맵을 FE `SCREEN_PATH` 와 **같이** 고친다.
맵에 없으면 인터셉터는 통과시키고 로그만 남긴다 — 조용히 뚫린다.

## 예외 (경로가 화면과 1:1 이 아닌 것)

- `/api/v1/docs/documents/**` — 문서 허브. 삭제·HWP 저장은 `HWP_HUB_SCREENS`, 나머지는 `DOC_HUB_SCREENS`
- `/auth/**` · 셸 공용 · `/sys/users/me` — 화이트리스트

## 변경 (2026-08-25)

화면 28개 정리에 맞춰 경로 맵과 허브 화면 집합에서 사라진 화면을 걷어냈다.
기준정보(`/bas/{type}`) 분기도 화면이 없어져 제거했다.
