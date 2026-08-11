# docs/ — 루트 문서·양식 원본

파트별 설계·API 정본은 여기가 아니다.

| 위치 | 역할 |
|------|------|
| [`frontend/haccp-web/docs/`](../frontend/haccp-web/docs/) | FE 정본 |
| [`backend/haccp-api/docs/`](../backend/haccp-api/docs/) | BE 정본 |
| [`12_배포_런북.md`](12_배포_런북.md) | 배포·Jenkins·스모크 (git 추적) |
| [`13_후속_STEP_16이후.md`](13_후속_STEP_16이후.md) | STEP 16–28 이력 (git 추적) |
| `templates/*.hwp` | 표준 양식 원본 — **로컬 전용**(gitignore). `scripts/init_volumes.sh` 시드 |

## 정리 규칙

- 구 MES용 md·migration-plan·ui-stabilization·PDF 추출물·고아 HWP 는 두지 않는다
- `templates/` 에는 `manifest.tsv` 의 `source_name`(required=Y)만 둔다
- LAW_* 양식은 매니페스트 optional(N) — 없으면 시드 생략

## 시드

```bash
bash scripts/init_volumes.sh
# 또는
HACCP_TEMPLATE_SRC=/path/to/hwp bash scripts/init_volumes.sh
```
