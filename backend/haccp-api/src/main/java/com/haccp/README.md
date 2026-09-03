# haccp

HACCP API 루트 패키지. 화면은 `com.haccp.{대}.{중}`.
경로 정본 [`docs/4_명명과_경로.md`](../../../../../../../docs/4_명명과_경로.md).

## 하위 (실물 기준)

- `auth/` · `menu/` · `code/` · `pref/` · `log/` · `common/` — 셸
- `docs/` — 문서 (`ccp` 는 `draft/ccpmonitoring`, 여기는 `documents` · `templates` · `htmlform` · `hwp` · `sch`)
- `draft/` — 작성 (`ccpmonitoring` · `html` · `hwpdoc`)
- `flow/ca/` — 개선조치
- `sys/code/` · `sys/logs/` — 시스템
- `tsk/` — 오늘 할 일

공유 허브는 `docs.documents` · `docs.templates` · `docs.htmlform` 이다 — 화면 경로와 별개.
`bas/`·`workflow/` 는 없다.

## 관련

- 규칙: `.cursor/rules/08-haccp-backend.mdc`
- 흐름: [`../../../../../PIPELINE.md`](../../../../../PIPELINE.md)
