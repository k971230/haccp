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
- **MyBatis 는 컴파일로 안 잡힌다.** 패키지를 옮기면 매퍼 XML `resultType` 도 같이 옮기고
  **반드시 기동해서** 확인한다 (`mvn compile` 통과가 기동 성공을 뜻하지 않는다)
- **이모지 금지** · **한국어** · git commit/push 는 사용자가 말할 때만

## 폴더마다 README

폴더를 새로 만들면 `README.md` 를 같이 만든다. 그 폴더가 **무엇을 맡고 무엇을 안 맡는지**,
연결된 API·SP·표, 그리고 최근 변경을 적는다. 상위 README 가 하위를 가리킨다.

## 검증

```sh
# 프론트
cd frontend/haccp-web ; npx tsc --noEmit ; npx eslint src ; npx vitest run ; npm run build
# 백엔드
cd backend/haccp-api ; ./mvnw -q -o test
# DB — 빈 DB 에 5본을 순서대로
psql -f db_sasshaccp/00_ddl.sql ; psql -f db_sasshaccp/01_sp.sql ; psql -f db_sasshaccp/02_seed.sql
psql -v co_cd=0000 -f db_sasshaccp/03_code_seed.sql ; psql -v co_cd=0000 -f db_sasshaccp/05_form_seed.sql
```
