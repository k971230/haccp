# .cursor/rules — HACCP 에이전트 규칙 정본

이 저장소는 **HACCP만** 다룬다. MES(`mes-web`/`mes-api`) 규칙은 두지 않는다.

| 파일 | 적용 | 역할 |
|------|------|------|
| `00-bootstrap.mdc` | always | 작업 전 읽기 순서 |
| `01-project-core.mdc` | always | 스택·git·시크릿·이모지 |
| `21-frontend-ui.mdc` | haccp-web UI | Tailwind·레이아웃 |
| `30-branching.mdc` | always | 브랜치·커밋·PR |
| `30-haccp-deploy.mdc` | compose·nginx·scripts | 배포·포트 |
| `40-handoff-comments.mdc` | always | FE=BE 인수인계 주석 |
| `50-operations.mdc` | always | 삭제·타임아웃·env |
| `60-haccp-db.mdc` | db_sasshaccp | PG·SP |
| `61-haccp-backend.mdc` | haccp-api | BE 컨벤션 |
| `62-haccp-frontend.mdc` | haccp-web | FE 컨벤션 |

문서 본문: 루트 `docs/1_`~`n_`.
