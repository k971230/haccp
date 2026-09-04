# common/auth — 화면 권한 인터셉터

JWT 다음 단계다. **로그인했는지**는 `JwtFilter` 가, **그 화면을 만질 권한이 있는지**는 여기가 본다.

| 파일 | 역할 |
|---|---|
| `ScreenAuthInterceptor.java` | `/api/**` 전 요청을 가로채 권한행과 대조한다. `WebConfig` 가 등록 |
| `ScreenAuthResolver.java` | 요청 경로 → 화면코드·권한 칸. FE `SCREEN_PATH` 와 같은 칸을 쓴다 |
| `ScreenAuthMatch.java` | 판정 결과 — 화면코드 + 권한 칸 |
| `ScreenAuthAction.java` | 권한 칸 — READ·WRITE·MODIFY·SAVE·DELETE·PRINT. SAVE 는 `write_yn` 또는 `modify_yn` |

## 왜 필요한가

화면에서 버튼을 숨기는 것만으로는 막히지 않는다. API 를 직접 부르면 그대로 통한다.
읽기 전용 계정이 `POST /delete` 를 불러도 **403** 이어야 한다.

## 화면을 추가·이동할 때

`ScreenAuthResolver` 의 경로 맵을 FE `SCREEN_PATH` 와 **같이** 고친다.
맵에 없으면 인터셉터는 통과시키고 로그만 남긴다 — 조용히 뚫린다.

## 예외 (경로가 화면과 1:1 이 아닌 것)

- `/api/v1/docs/documents/**` — 문서 허브. 삭제·HWP 저장은 `HWP_HUB_SCREENS`, 나머지는 `DOC_HUB_SCREENS`
- `/api/v1/board/notifications/**` — 알림은 셸 공용이라 전용 화면코드가 없다. `today-tasks` 권한 칸으로 판정한다 (`ScreenAuthResolver.java`)
- `/auth/**` · 셸 공용 · `/sys/users/me` — 화이트리스트
- `/api/v1/docs/templates/list` · GET `/{tmplCd}/form` — **공용 조회**. 업로드 POST 만 `hwp-template-management`
- GET `/api/v1/sys/users/{userId}/sign` — 지면 도장. 업로드·삭제는 `user-management`
- GET `user-management/list` · `approval-line-management/list` — 문서주기 콤보. 저장·삭제는 그 화면

## 여러 화면이 쓰는 조회는 화면에 묶지 않는다

콤보를 채우는 목록 같은 것은 **부르는 화면이 여럿**이라 특정 화면 권한에 묶으면
「내가 볼 권한을 가진 화면인데 남의 화면 권한 때문에 403」이 난다.

실제로 났다 — `/api/v1/docs/templates/list` 가 `hwp-template-management` 에 묶여 있어서,
그 화면이 `read_yn='N'` 인 조회 전용(VIEWER)이 **이탈·개선조치 화면에서** 양식 콤보가 비었다.
그 화면은 VIEWER 도 읽기 권한이 있는데도 그랬다. 부르는 곳은 둘이다 —
`draft/hwp-doc/HwpEditorPane` 과 `flow/ca/CorrectiveActionManagementPage`.

**목록·GET 원본·GET 서명·사용자/결재선 목록** 은 연다. 업로드·삭제는 화면 권한을 본다.
회사 범위는 어차피 JWT 로 SP 가 가른다.

새 조회를 더할 때 **부르는 화면이 둘 이상이면** 화면에 묶지 말고 여기를 본다.

## 변경 (2026-09-01)

HWP 작성 팀원(사용자관리·사용양식관리 없음)이 양식 원본·서명·사용자 목록에서 403 이 나던 것을 고쳤다.
GET `/{tmplCd}/form` · GET `/{userId}/sign` · 사용자/결재선 목록 GET 을 공용 조회로 열었다.

## 변경 (2026-08-28)

`/api/v1/docs/templates/list` 를 화이트리스트로 옮겼다. 위 문단이 까닭이다.

## 변경 (2026-08-25)

화면 28개 정리에 맞춰 경로 맵과 허브 화면 집합에서 사라진 화면을 걷어냈다.
기준정보(`/bas/{type}`) 분기도 화면이 없어져 제거했다.
