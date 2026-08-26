# api/docs — 문서 기준관리 API

`/docs` 대분류 화면이 쓰는 API. 베이스는 `apiOf(scrnCd)` 가 `SCREEN_PATH` 로 조립한다.

| 파일 | 화면 | API 베이스 |
|---|---|---|
| `docCycleApi.ts` | `schedule-cycle-management` | `/api/v1/docs/sch/schedule-cycle-management` |
| `hwpTemplateApi.ts` | `hwp-template-management` | `/api/v1/docs/hwp/hwp-template-management` |
| `htmlFormApi.ts` | HTML 양식 원본 5화면 | `/api/v1/docs/html-form/{scrnCd}` |

## htmlFormApi 가 더 갖는 것

지면 입력유형(`input_type`) 판정이 여기 있다. 화면마다 if-else 를 두지 않는다.

- `normalizeHtmlInputTy` — 들어온 값을 공통코드 `HTML_INPUT_TY` 와 같은 UPPER_SNAKE 로
- `htmlFormInputLayout` — 유형 하나로 라디오·숫자·문자·값칸을 정한다
- `HTML_INPUT_TY_LEGACY` — 구형 `YN·OX·JUDGE·NUM2` 방어. DB 는 2026-08-25 에 올렸지만
  외부에서 옛 값이 들어올 수 있어 읽기 쪽은 남겨 둔다

## 변경 (2026-08-25)

- `/docs/html` → `/docs/html-form` (중분류 `html` 을 양식 작성이 가져갔다)
- 입력유형을 UPPER_SNAKE 로 (`radio` → `RADIO`). 데이터·BE 와 같이 옮겼다
- 삭제된 작성 화면(`hygiene-process-check`) 전용 함수 5개 제거
