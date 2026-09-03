# mapper

도메인별 MyBatis XML. SP 호출은 lower_snake. 경로는 `mapper/{대}/{중}/` —
`namespace` 는 매퍼 인터페이스 FQCN 이다.
경로 정본 [`docs/4_명명과_경로.md`](../../../../../../docs/4_명명과_경로.md).

## 하위 (실물 기준)

- `auth/` · `menu/` · `code/` · `pref/` · `log/` — 셸
- `docs/` — `documents` · `htmlform` · `hwp` · `sch`
- `draft/` — 작성
- `flow/ca/` — 개선조치
- `sys/code/` · `sys/logs/` — 시스템
- `tsk/` — 오늘 할 일

`bas/`·`workflow/` 는 없다.

**패키지를 옮기면 XML `resultType`·`namespace` 도 같이 옮기고 반드시 기동해서 확인한다** —
MyBatis 는 컴파일로 안 잡힌다 (`mvn compile` 통과가 기동 성공을 뜻하지 않는다).

## 관련

- 규칙: `.cursor/rules/08-haccp-backend.mdc`
