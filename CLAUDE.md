# CLAUDE.md — HACCP 저장소 작업 규칙

Claude Code 진입점이다. **규칙 본문은 여기 두지 않는다** — 정본은 `.cursor/rules/` 다.
여기에 옮겨 적으면 한쪽만 고쳐져 도구마다 다른 답이 나온다.

## 무엇부터 읽는가

`.cursor/rules/00-bootstrap.mdc` 가 읽기 순서를 정한다. 요약하면:

| # | 파일 | 언제 |
|---|---|---|
| 00 | `00-bootstrap.mdc` | 항상 — 작업 전 읽기 순서 |
| 01 | `01-project-core.mdc` | 항상 — 스택·git·시크릿·명명·URL 규칙 |
| 05 | `05-handoff-comments.mdc` | 코드를 쓸 때 — FE·BE 동일 밀도 주석 |
| 06 | `06-operations.mdc` | 삭제·타임아웃·전역 env |
| 10 | `10-ide-workflow.mdc` | 항상 — IDE 별 실행·같이 바꿀 것 |
| 02·09 | 프론트 UI · 프론트 컨벤션 | `frontend/haccp-web/**` 을 만질 때 |
| 07·08 | DB · 백엔드 | `db_sasshaccp/**` · `backend/**` 을 만질 때 |
| 03·04 | 브랜치 · 배포 | 그 작업일 때 |

## 이 저장소에서 특히 자주 어긋나는 것

- **한 화면 = 여러 층.** FE 라우트·레지스트리, BE 패키지·매퍼, `ScreenAuthResolver`,
  DB `tbl_screen`·`tbl_role_screen`·`tbl_menu` 가 같이 움직인다. `10-ide-workflow` 표 참조
- **`scrnCd`·`persistId` 는 고정.** 폴더·URL 이 바뀌어도 안 바꾼다
- **공통코드 `sub_cd` 는 저장값과 같은 표기.** 코드만 올리고 데이터를 안 올리면 콤보가 빈다
- **저장형과 표시형이 다르다.** 날짜는 DB `varchar(8)` `20260827` · 화면 `2026-08-27`.
  컬럼 폭을 화면이 보낼 값보다 좁게 잡으면 `22001` 로 저장이 막힌다 —
  실제로 네 번 났다 ([`docs/4_명명과_경로.md`](docs/4_명명과_경로.md) 10절)
- **MyBatis 는 컴파일로 안 잡힌다.** 패키지를 옮기면 매퍼 XML `resultType` 도 같이 옮기고
  **반드시 기동해서** 확인한다 (`mvn compile` 통과가 기동 성공을 뜻하지 않는다)
- **이모지 금지** · **한국어** · git commit/push 는 사용자가 말할 때만

## 폴더마다 README

폴더를 새로 만들면 `README.md` 를 같이 만든다. 그 폴더가 **무엇을 맡고 무엇을 안 맡는지**,
연결된 API·SP·표, 그리고 최근 변경을 적는다. 상위 README 가 하위를 가리킨다.

## 검증

```sh
# 프론트
cd frontend/haccp-web
npx tsc --noEmit ; npx eslint src e2e ; npx vitest run ; npm run build
npx playwright test          # E2E — 화면·API·SP·DB 를 한 줄로 꿴다

# 백엔드
cd backend/haccp-api ; ./mvnw -q -o test

# DB — 빈 DB 에 6본을 순서대로 (재실행 안전)
PGHOST=... PGUSER=... PGPASSWORD=*** bash db_sasshaccp/apply-all.sh
```

**E2E 는 `npm run build` 한 결과를 본다.** `e2e/.env` 의 `E2E_BASE_URL` 이
`http://localhost:4173/haccp/` — `vite preview` 가 서빙하는 `dist/` 다.
**프론트 소스를 고쳤으면 반드시 다시 빌드하고 E2E 를 돌린다.**
빌드를 건너뛰면 고치기 전 화면을 시험하게 되고, 통과해도 뜻이 없다.
(`E2E_WEB_SERVER=1` 을 주면 대신 dev 서버를 띄운다.)

## 코드를 만지기 전에

| 하려는 일 | 볼 곳 |
|---|---|
| 이 프로젝트가 뭔지·업무 흐름 | [`docs/1_시작하기.md`](docs/1_시작하기.md) |
| 코드가 어떤 순서로 도는지 | [`backend/haccp-api/PIPELINE.md`](backend/haccp-api/PIPELINE.md) · [`frontend/haccp-web/PIPELINE.md`](frontend/haccp-web/PIPELINE.md) |
| 화면 하나 만들기 | [`docs/2_화면_추가하기.md`](docs/2_화면_추가하기.md) |
| 지금 있는 화면 | [`docs/3_화면_지도.md`](docs/3_화면_지도.md) — 생성기 |
| 이 표를 고치면 어느 SP 가 걸리나 | [`docs/9_SP_색인.md`](docs/9_SP_색인.md) — 생성기 |
| `PIPELINE[HF130]` 이 무슨 파일인가 | [`docs/5_PIPELINE_색인.md`](docs/5_PIPELINE_색인.md) — 생성기 |
| 이름·경로 규칙 | [`docs/4_명명과_경로.md`](docs/4_명명과_경로.md) |
| 왜 이렇게 돼 있나 | [`docs/8_결정_이력.md`](docs/8_결정_이력.md) |
