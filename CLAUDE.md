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
  실제로 네 번 났다 ([`docs/4_명명과_경로.md`](docs/4_명명과_경로.md) 10절).
  **문자 입력칸의 `maxLength` 는 DDL 폭과 같은 수다** — 그리드(`MesEditableGrid`)와
  작성 지면(`HtmlFormCellInput`) 둘 다. `bash scripts/audit_grid_maxlength.sh` 가 대조하는데
  **짝을 적어 둔 칸만 본다** — 새 문자칸을 만들면 `scripts/_grid_maxlength_diff.py` 에 한 줄 더한다
- **MyBatis 는 컴파일로 안 잡힌다.** 패키지를 옮기면 매퍼 XML `resultType` 도 같이 옮기고
  **반드시 기동해서** 확인한다 (`mvn compile` 통과가 기동 성공을 뜻하지 않는다)
- **이모지 금지** · **한국어** · git commit/push 는 사용자가 말할 때만

## 폴더마다 README — 할 말이 있을 때만

**폴더 이름으로 알 수 있는 것은 적지 않는다.** `dto/` 가 "요청·응답 DTO" 라는 README 는
읽는 사람에게 아무것도 주지 않고, 고칠 곳만 한 군데 늘린다.
2026-09-09 에 그런 스텁 31본을 지웠다.

README 를 두는 자리는 그 폴더에 **폴더 이름 밖의 사실**이 있을 때다 —
연결된 API·SP·표, 무엇을 맡고 무엇을 **안** 맡는지, 남들이 자주 틀리는 것.
예: `com/haccp/pref/README.md` 는 "조회는 Controller → Mapper 직행, 저장만 `@Transactional`"
을 적는다. 이건 폴더 이름으로 못 안다.

`INDEX.md` 의 「README 없는 폴더」 절은 **위반 목록이 아니라 현황**이다.

## 검증

```sh
# 프론트
cd frontend/haccp-web
npx tsc --noEmit ; npx eslint src e2e ; npx vitest run ; npm run build
npm run preview &            # 4173 에 dist/ 를 띄운다 — 이걸 빼면 E2E 가 전부 접속 실패한다
npx playwright test          # E2E — 화면·API·SP·DB 를 한 줄로 꿴다

# 백엔드
cd backend/haccp-api ; ./mvnw -q -o test

# DB — 7본. 스키마가 있으면 00_ddl·02_seed 를 건너뛴다
PGHOST=... PGUSER=... PGPASSWORD=*** bash db_sasshaccp/apply-all.sh
```

**E2E 는 `npm run build` 한 결과를 본다.** `e2e/.env` 의 `E2E_BASE_URL` 이
`http://localhost:4173/haccp/` — `vite preview` 가 서빙하는 `dist/` 다.
**프론트 소스를 고쳤으면 반드시 다시 빌드하고 E2E 를 돌린다.**
빌드를 건너뛰면 고치기 전 화면을 시험하게 되고, 통과해도 뜻이 없다.
`playwright.config.mjs` 의 `webServer` 는 `E2E_WEB_SERVER=1` 일 때만 붙는다 —
**기본 경로에서는 Playwright 가 서버를 안 띄운다.** `npm run preview` 가 선행이다.
(`E2E_WEB_SERVER=1` 은 dev 서버를 5174 에 띄우는데 `baseURL` 은 여전히 4173 이라
`E2E_BASE_URL` 을 같이 주지 않으면 성립하지 않는다. 고치기 전까지는 preview 쪽을 쓴다.)

## 코드를 만지기 전에

하려는 일로 찾는 표는 [`README.md`](README.md) 「어디를 보나」가 정본이다.
