# scripts/ — 배포·스모크·기동·CI·감사

운영·Jenkins가 호출하는 셸 스크립트 모음이다.  
**여기 파일을 임의로 지우면** Deploy·Prod smoke·nightly audit·로컬 compose 선행이 깨진다.

일회성 Path 전환용 `ops_path_gateway_cutover.sh` 는 STEP 16–28 종료 후 **제거됨** (재실행 대상 아님).

## 유지 목록

| 그룹 | 파일 | 호출처 | 성공 / 실패 |
|------|------|--------|-------------|
| 배포 | `build_images.sh` | `Jenkinsfile` Build images | 3이미지 로컬 태그 완료 / docker build 실패 |
| 배포 | `deploy_remote.sh` | `Jenkinsfile` Deploy | 원격 pull·up 완료 / SSH·compose 실패 |
| 스모크 | `prod_smoke.sh` | Jenkins Prod smoke · 런북 §15 | 9단계 통과 / 단계별 exit 1 |
| 스모크 | `smoke_env.sh` | `prod_smoke.sh` 가 source | (단독 실행 아님) |
| 기동 | `init_volumes.sh` | compose 선행 · 런북 §9 | 양식 볼륨 시드 / 매니페스트·원본 부재 |
| 기동 | `install_rhwp.sh` | PDF 쓸 때 · 런북 §11 | rhwp 볼륨 설치 / SHA·다운로드 실패 |
| 기동 | `gen_selfsigned.sh` | 로컬·도메인 전 · 런북 §10 | certs 생성 / openssl 실패 |
| CI | `db_migrate_dryrun.sh` | `Jenkinsfile` dry-run | 임시 PG apply-all OK / SQL 오류 |
| CI | `pre-commit-check-secrets.sh` | git hook · README | staged 시크릿 없음 / 실값 검출 |
| 감사 | `audit_version_drift.sh` | `Jenkinsfile.audit` | 문서·코드 버전 일치 / drift |
| 감사 | `audit_ops_delete.sh` | `Jenkinsfile.audit` | OPS_DELETE 위반 없음 / DELETE·짝 누락 |
| 감사 | `audit_file_size_alignment.sh` | `Jenkinsfile.audit` | 파일크기 3키 정합 / 불일치 |
| 감사 | `audit_docs_links.sh` | `Jenkinsfile.audit` | docs 상대링크 존재 / 깨진 링크 |

상세 운영 절차: [`docs/12_배포_런북.md`](../docs/12_배포_런북.md) §13.2 · §15 · §19.

## 시크릿

- `.env.docker` · Credential 평문은 **이 디렉터리에 두지 않는다**
- `prod_smoke.sh` 는 `SMOKE_USER`/`SMOKE_PASS` 를 환경으로만 받는다
