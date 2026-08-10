# HACCP 표준 HWP 템플릿 배포

이진 HWP는 Git에 넣지 않는다. **메타·매핑만** 이 폴더와 classpath `src/main/resources/templates/`에 둔다.

## 저장 구조 (볼륨)

```text
{APP_FILE_ROOT}/
  _template/                 # 표준 원본 — 한글 파일명 (매니페스트 target)
  _template/{coCd}/          # 자사 업로드 원본 — 동일 공간, 테넌트 하위
  {coCd}/{yyyy}/{MM}/        # 문서 인스턴스 (별도 DocumentFileStorage)
```

DB에는 `form_path` 문자열만 저장한다. 나중에 MinIO/S3로 옮길 때는 `TemplateFileStorage` 구현만 교체하면 된다.

## 매니페스트 (하드코딩 금지)

정본: [`manifest.tsv`](manifest.tsv)  
(런타임: `classpath:templates/manifest.tsv` 또는 `APP_TEMPLATE_MANIFEST`)

| 열 | 의미 |
|---|---|
| tmpl_cd | 표준 템플릿 코드 |
| source_name | `docs/` 또는 import-root의 **실존** 파일명 (임의 작명 금지) |
| target_name | `_template` 저장명 — 번호 접두 제거 한글명 |
| required | Y=필수(누락 시 기동 실패), N=선택(LAW 등 skip) |

양식 추가 시 **TSV 한 줄만** 추가하고 docs에 파일을 두면 된다. Java `TEMPLATE_CODES` 배열은 쓰지 않는다.

## 환경변수

| env | 기본 | 용도 |
|---|---|---|
| `APP_FILE_ROOT` | `./data/haccp-files` | 볼륨 루트 |
| `APP_TEMPLATE_DIRECTORY` | `_template` | 템플릿 하위 디렉터리명 |
| `APP_TEMPLATE_MANIFEST` | `templates/manifest.tsv` | 매니페스트 경로 |
| `APP_TEMPLATE_IMPORT_ROOT` | (비움) | 기동 시 복사할 원본 루트(예: `../../docs`) |
| `APP_TEMPLATE_IMPORT_OVERWRITE` | `false` | true면 기존 파일 교체 |

로컬 예:

```text
APP_TEMPLATE_IMPORT_ROOT=D:/SassHaccp/docs
APP_TEMPLATE_IMPORT_OVERWRITE=true
```

## 운영 절차

1. `docs/`에 한글 원본 배치 (번호 접두 포함 가능)
2. `manifest.tsv`에 tmpl_cd ↔ source_name 매핑
3. migrate `46_migrate_template_volume_ko.sql`로 DB `form_path` 갱신
4. API 기동 시 Import가 target_name으로 볼륨 복사 (또는 수동 복사)
5. 자사 신규: 사용양식관리에서 기준 양식 선택 → 한글 HWP 업로드 → `_template/{coCd}/`

`GET /api/v1/doc/templates/{tmplCd}/form` 400은 대부분 볼륨에 해당 `form_path` 파일이 없을 때다.
