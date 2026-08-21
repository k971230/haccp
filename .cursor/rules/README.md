# .cursor/rules — HACCP 에이전트 규칙 (`00`~`09`)

이 저장소는 **HACCP만** 다룬다. 번호는 연속이다.

| # | 파일 | 적용 | 역할 |
|---|------|------|------|
| 00 | `00-bootstrap.mdc` | always | 작업 전 읽기 순서 |
| 01 | `01-project-core.mdc` | always | 스택·git·시크릿·이모지 |
| 02 | `02-frontend-ui.mdc` | haccp-web UI | Tailwind·레이아웃 |
| 03 | `03-branching.mdc` | always | 브랜치·커밋·PR |
| 04 | `04-deploy.mdc` | compose·nginx·scripts | 배포·포트 |
| 05 | `05-handoff-comments.mdc` | always | FE=BE 인수인계 주석 |
| 06 | `06-operations.mdc` | always | 삭제·타임아웃·env |
| 07 | `07-haccp-db.mdc` | db_sasshaccp | PG·SP |
| 08 | `08-haccp-backend.mdc` | haccp-api | BE 컨벤션 |
| 09 | `09-haccp-frontend.mdc` | haccp-web | FE 컨벤션 |

문서 본문: 루트 `docs/1_`~`23_`. PIPELINE 색인 `docs/23_PIPELINE.md`.
