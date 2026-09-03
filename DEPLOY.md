# 배포 체크리스트

> 개발자: 박승우 · 일자: 2026-08-26
> 장애 대응·스테이지 상세는 [`운영.md`](운영.md)

**Jenkins 는 Build Now 하나만 누르면 된다.** 그 전에 아래 셋을 확인한다.

---

## 1. 누르기 전 (한 번만)

| # | 확인 | 어디서 |
|---|---|---|
| 1-1 | Credentials 4개가 등록돼 있는가 | Jenkins > Credentials |
| 1-2 | Job `haccp-deploy` 가 `Jenkinsfile` 을 가리키는가 | Job > Pipeline > Script Path |
| 1-3 | 배포 서버에 `.env.docker` 가 있고 권한이 `0600` 인가 | `/home/ubuntu/haccp/` |
| 1-4 | external 볼륨 3개가 있는가 — `haccp-files`·`haccp-templates`·`haccp-rhwp` | 서버 `docker volume ls` |

1-4 가 없으면 `compose up` 이 `volume not found` 로 즉시 멈춘다 (`docker-compose.prod.yml` 의 `external: true`).
Jenkins 가 만들어 주지 않는다 — 서버에서 한 번 돌린다. 둘 다 멱등이다.

```sh
bash scripts/init_volumes.sh    # haccp-files · haccp-templates
bash scripts/install_rhwp.sh    # Docker 볼륨 haccp-rhwp. Windows 로컬은 tools/rhwp 도 같이
```

| Credential ID | 종류 | 쓰는 곳 |
|---|---|---|
| `haccp-deploy-host` | Secret text | `user@host` 또는 `host` |
| `haccp-deploy-ssh-key` | SSH Username + Key | 배포 서버 접속 |
| `haccp-registry-cred` | Username + Password | `ghcr.io` push |
| `haccp-smoke-user` | Username + Password | 배포 후 스모크 로그인 |

---

## 2. DB — 파이프라인이 안 건드린다

스키마 정본은 `db_sasshaccp/` **7본**이고, 배포 담당이 **따로** 돌린다.
Jenkins 는 DB 를 안 건드린다. SP 를 바꿨으면 `01_sp.sql` 을 운영에 따로 적용한다
(`CREATE OR REPLACE` 라 재실행된다). 이미 깔린 운영·시험은 2026-09-03 에 맞췄다.

```sh
PGHOST=호스트 PGUSER=계정 PGPASSWORD=*** bash db_sasshaccp/apply-all.sh
```

**빈 DB 전용이다.** `00_ddl.sql` 은 `CREATE SCHEMA`·`CREATE TABLE` 에 `IF NOT EXISTS` 가 없고
`02_seed.sql` 은 `ON CONFLICT` 가 없다 — 다시 부르면 `42P06 duplicate schema` 로 죽는다.
(`01_sp.sql` 만 `CREATE OR REPLACE` 라 재실행된다.)

새 업체를 여는 경우 — `apply-all.sh` 를 다시 부르지 않고 업체분 4본만 돌린다:

```sh
cd db_sasshaccp
P="psql -v ON_ERROR_STOP=1"
$P -v co_cd=0001 -f 03_code_seed.sql
$P -v co_cd=0001 -f 05_form_seed.sql
$P -v co_cd=0001 -v co_nm='업체명' -v admin_id=admin0001 -f 06_company_seed.sql
$P -v co_cd=0001 -f 07_company_forms.sql
```

> 초기 비밀번호는 `1234` 다. **첫 로그인 후 반드시 바꾼다.**

자동 적용을 파이프라인에 넣지 않는 이유 — 스키마 변경은 되돌리기 어렵고,
배포와 같은 트랜잭션으로 묶을 수 없어 실패하면 반쪽 상태가 남는다.

---

## 3. Build Now 를 누르면 도는 것

| 단계 | 하는 일 | 실패하면 |
|---|---|---|
| Checkout | `git log -1` | — |
| BE test & compile | `./mvnw test` → `package` | 단위 108건 중 하나라도 깨지면 중단 |
| FE test & build | `tsc --noEmit` → `lint` → `vitest` → `build` | 타입·린트 오류면 중단 |
| Build images | `scripts/build_images.sh $TAG` | — |
| Push images | `ghcr.io` 로 3개(api·web·nginx) | 레지스트리 인증 실패 |
| Deploy to prod | `scripts/deploy_remote.sh` → compose up | SSH·compose 실패 |
| Prod smoke | `scripts/prod_smoke.sh` — 로그인·화면 응답 | 배포는 됐고 확인만 실패 |

태그는 `1.0.${BUILD_NUMBER}`.

---

## 4. 누른 뒤 확인

```sh
# 화면
https://180.71.58.87/haccp/          → 로그인 화면
https://180.71.58.87/haccp/login     → 로그아웃 URL

# 컨테이너
ssh 배포서버 'cd /home/ubuntu/haccp && docker compose --env-file .env.docker -f docker-compose.prod.yml ps'
```

문제가 있으면 [`운영.md`](운영.md) 의 장애 대응 절.

---

## 5. 되돌리기

이미지 태그로 되돌린다. DB 는 **자동으로 안 돌아간다** — 스키마를 바꿨다면
되돌릴 방법을 미리 정해 두고 배포한다.

```sh
ssh 배포서버 'cd /home/ubuntu/haccp && TAG=1.0.<이전번호> docker compose --env-file .env.docker -f docker-compose.prod.yml up -d'
```

`-f` 와 `--env-file` 을 뺄 수 없다. 파일 이름이 `docker-compose.yml`·`.env` 가 아니라
compose 기본 탐색에 안 걸리고, `${REGISTRY}`·`${HACCP_SERVER_NAME}` 치환이 빈 값이 된다.
서버에 `docker-compose.override.yml` 이 있으면 `-f docker-compose.override.yml` 을 뒤에 하나 더 붙인다
(`scripts/deploy_remote.sh` 와 같은 조건) — 빼면 edge 의 `127.0.0.1:17070` publish 가 사라진다.

---

## 6. 별도 Job

| Job | 파일 | 언제 |
|---|---|---|
| `haccp-audit` | `Jenkinsfile.audit` | 문서 링크·파일 크기·삭제 규약 점검 |
| E2E | `Jenkinsfile.e2e` | 배포 뒤 실측. **DB 대조 시험은 skip 된다** — `frontend/haccp-web/e2e/README.md` 참조 |

---

## 관련

- 파이프라인: [`backend/haccp-api/PIPELINE.md`](backend/haccp-api/PIPELINE.md) · [`frontend/haccp-web/PIPELINE.md`](frontend/haccp-web/PIPELINE.md)
- DB 정본: [`db_sasshaccp/README.md`](db_sasshaccp/README.md)
- E2E 결과: [`E2E.md`](E2E.md) · [`E2E_ERRORS.md`](E2E_ERRORS.md)

## 변경

- 2026-08-26 — 신설. DB 는 파이프라인이 안 건드린다는 것과 신규 업체 개설 절차를 적었다.
- 2026-09-03 — 운영·시험에 결재 SP 개명·REVIEW 잔재 제거를 적용하고 1회성 08·09 파일을 지웠다.
