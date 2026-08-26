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

| Credential ID | 종류 | 쓰는 곳 |
|---|---|---|
| `haccp-deploy-host` | Secret text | `user@host` 또는 `host` |
| `haccp-deploy-ssh-key` | SSH Username + Key | 배포 서버 접속 |
| `haccp-registry-cred` | Username + Password | `ghcr.io` push |
| `haccp-smoke-user` | Username + Password | 배포 후 스모크 로그인 |

---

## 2. DB — 파이프라인이 안 건드린다

스키마 정본은 `db_sasshaccp/` **6본**이고, 배포 담당이 **따로** 돌린다.

```sh
PGHOST=호스트 PGUSER=계정 PGPASSWORD=*** bash db_sasshaccp/apply-all.sh
```

전부 재실행 안전하다(`IF NOT EXISTS` · `ON CONFLICT` · `CREATE OR REPLACE`).
새 업체를 여는 경우:

```sh
CO_CD=0001 CO_NM='업체명' ADMIN_ID=admin0001 bash db_sasshaccp/apply-all.sh
```

> 초기 비밀번호는 `1234` 다. **첫 로그인 후 반드시 바꾼다.**

자동 적용을 파이프라인에 넣지 않는 이유 — 스키마 변경은 되돌리기 어렵고,
배포와 같은 트랜잭션으로 묶을 수 없어 실패하면 반쪽 상태가 남는다.

---

## 3. Build Now 를 누르면 도는 것

| 단계 | 하는 일 | 실패하면 |
|---|---|---|
| Checkout | `git log -1` | — |
| BE test & compile | `./mvnw test` → `package` | 단위 23건 중 하나라도 깨지면 중단 |
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
ssh 배포서버 'cd /home/ubuntu/haccp && docker compose ps'
```

문제가 있으면 [`운영.md`](운영.md) 의 장애 대응 절.

---

## 5. 되돌리기

이미지 태그로 되돌린다. DB 는 **자동으로 안 돌아간다** — 스키마를 바꿨다면
되돌릴 방법을 미리 정해 두고 배포한다.

```sh
ssh 배포서버 'cd /home/ubuntu/haccp && TAG=1.0.<이전번호> docker compose up -d'
```

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
