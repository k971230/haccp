# scripts

HACCP 운영·검증 스크립트. 정본 절차는 [`docs/20_배포_런북.md`](../docs/20_배포_런북.md).

## 배포·기동

| 스크립트 | 역할 |
|----------|------|
| `init_volumes.sh` | 파일·템플릿·rhwp 볼륨 시드 |
| `build_images.sh` | api·web·nginx 이미지 빌드 |
| `deploy_remote.sh` | 원격 rsync·compose up |
| `install_rhwp.sh` | rhwp CLI 주입 |
| `gen_selfsigned.sh` | 로컬 TLS 인증서 |

## 스모크·DB

| 스크립트 | 역할 |
|----------|------|
| `prod_smoke.sh` | 배포 후 HTTP 스모크 |
| `smoke_env.sh` | 스모크 공통 env |
| `db_migrate_dryrun.sh` | SQL 문법 dry-run |

## 감사·훅

| 스크립트 | 역할 |
|----------|------|
| `audit_docs_links.sh` | 루트 `docs/` 상대 링크 |
| `audit_file_size_alignment.sh` | 파일 한도 FE/BE 정합 |
| `audit_ops_delete.sh` | validate-delete 계약 |
| `audit_version_drift.sh` | 버전 드리프트 |
| `pre-commit-check-secrets.sh` | 시크릿 커밋 차단 |

## 관련

- 배포 규칙: `.cursor/rules/30-haccp-deploy.mdc`
