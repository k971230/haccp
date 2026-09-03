# holidays — 한국 공휴일 날짜 JSON

문서주기 비영업일 판정용. 규칙을 이 저장소에서 계산하지 않는다.

| 파일 | 역할 |
|------|------|
| `holidays-kr.json` | [hyunbinseo/holidays-kr](https://github.com/hyunbinseo/holidays-kr) `basic.json` 복사본. npm `5.2027.1` (2018~2027) |

맡지 않는 것: 음력·대체공휴일 계산, 런타임 HTTP, 공휴일 관리 화면.

## 교체

월력요항이 holidays-kr `basic.json`에 실리면 파일을 덮어쓴다. Java는 연도를 하드코딩하지 않는다.

```sh
curl -fsSL -o backend/haccp-api/src/main/resources/holidays/holidays-kr.json https://holidays.hyunbin.page/basic.json
```

동등본: https://github.com/hyunbinseo/holidays-kr/blob/main/public/basic.json

npm `@hyunbinseo/holidays-kr` 버전이 `5.2028.x`처럼 오르거나 JSON에 `"2028"` 키가 생기면 교체 시점이다. 이 README의 버전 문자열도 같이 고친다.

JSON에 없는 연도는 생성기가 주말만 본다.
