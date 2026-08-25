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
