# AGENTS.md — 에이전트 진입점

이 저장소의 규칙 정본은 **`.cursor/rules/`** 다. 도구가 무엇이든 그것을 읽는다.

- Claude Code → [`CLAUDE.md`](CLAUDE.md)
- Cursor → `.cursor/rules/*.mdc` 자동 적용
- 그 밖 → 아래 순서로 읽는다

| # | 파일 | 역할 |
|---|---|---|
| 00 | `.cursor/rules/00-bootstrap.mdc` | 작업 전 읽기 순서 |
| 01 | `.cursor/rules/01-project-core.mdc` | 스택·git·시크릿·명명·URL 규칙 |
| 05 | `.cursor/rules/05-handoff-comments.mdc` | 주석 밀도 |
| 06 | `.cursor/rules/06-operations.mdc` | 삭제·타임아웃·env |
| 10 | `.cursor/rules/10-ide-workflow.mdc` | IDE 별 실행·같이 바꿀 것 |

규칙을 이 파일에 옮겨 적지 않는다. 진입점만 둔다.
복제하면 한쪽만 고쳐져 도구마다 다른 답을 준다.

## 코드를 만지기 전에

| 하려는 일 | 볼 곳 |
|---|---|
| 이 프로젝트가 뭔지 | [`docs/1_시작하기.md`](docs/1_시작하기.md) |
| 코드가 어떤 순서로 도는지 | [`backend/haccp-api/PIPELINE.md`](backend/haccp-api/PIPELINE.md) · [`frontend/haccp-web/PIPELINE.md`](frontend/haccp-web/PIPELINE.md) |
| 화면 하나 만들기 | [`docs/2_화면_추가하기.md`](docs/2_화면_추가하기.md) |
| 지금 있는 화면 | [`docs/3_화면_지도.md`](docs/3_화면_지도.md) |
| 이름·경로 규칙 | [`docs/4_명명과_경로.md`](docs/4_명명과_경로.md) |
| 왜 이렇게 돼 있나 | [`docs/8_결정_이력.md`](docs/8_결정_이력.md) |

## 특히 자주 어긋나는 것

- **한 화면 = 일곱 층.** FE 라우트·레지스트리, BE 패키지·매퍼, `ScreenAuthResolver`,
  DB `tbl_screen`·`tbl_role_screen`·`tbl_menu` 가 같이 움직인다
- **`scrnCd`·`persistId` 는 고정.** 폴더·URL 이 바뀌어도 안 바꾼다
- **MyBatis 는 컴파일로 안 잡힌다.** 패키지를 옮기면 매퍼 XML 도 같이 옮기고
  **반드시 기동해서** 확인한다 (`mvn compile` 통과 ≠ 기동 성공)
- **이모지 금지** · **한국어** · git commit/push 는 사용자가 말할 때만
