# scripts/

HACCP 운영·검증 스크립트. 정본 절차는 [`DEPLOY.md`](../DEPLOY.md).

**여기 파일을 임의로 지우면** Deploy·Prod smoke·nightly audit·로컬 compose 선행이 깨진다.  
일회성 Path 전환용 `ops_path_gateway_cutover.sh` 는 제거됨 (재실행 대상 아님).

## 배포·기동

| 스크립트 | 역할 | 호출처 |
|----------|------|--------|
| `init_volumes.sh` | 파일·템플릿 볼륨 시드 (rhwp 는 `install_rhwp.sh`) | compose 선행 · `DEPLOY.md` §1 의 1-4 |
| `build_images.sh` | api·web·nginx 이미지 빌드 | `Jenkinsfile` |
| `deploy_remote.sh` | 원격 rsync·compose up | `Jenkinsfile` |
| `install_rhwp.sh` | rhwp CLI 주입 — Windows `tools/rhwp` · Docker 볼륨 `haccp-rhwp` | 로컬 HWP PDF · `DEPLOY.md` §1 의 1-4 |
| `gen_selfsigned.sh` | 로컬 TLS 인증서 | `환경구축.md` §10 |

## 스모크·DB

| 스크립트 | 역할 |
|----------|------|
| `prod_smoke.sh` | 배포 후 HTTP 스모크 (`SMOKE_USER`/`SMOKE_PASS`는 env만) |
| `smoke_env.sh` | 스모크 공통 env (`prod_smoke`가 source) |
| `db_migrate_dryrun.sh` | (수동) SQL 문법 dry-run — Jenkins CI에서 제거됨 |
| `archive_hwp_logbooks.sh` | HaccpLogBooks 를 `_legacy/날짜` 로 이동 (즉시 삭제 금지). `SRC`·`DEST` env |

## 감사·훅

| 스크립트 | 역할 |
|----------|------|
| `audit_docs_links.sh` | 루트 `docs/` 상대 링크 |
| `audit_file_size_alignment.sh` | 파일 한도 FE/BE 정합 |
| `audit_ops_delete.sh` | validate-delete 계약 |
| `audit_version_drift.sh` | 버전 드리프트 |
| `pre-commit-check-secrets.sh` | 시크릿 커밋 차단 |

## 관련

- 배포 규칙: `.cursor/rules/04-deploy.mdc`
- 시크릿·`.env.docker` 평문은 이 디렉터리에 두지 않는다
