# HACCP SaaS

HACCP 기록·결재 SaaS. MES(`metis`)와 **별도** DB·스키마 `sasshaccp`를 사용한다.

이 저장소는 MES 모노레포에서 HACCP만 분리한 **public** 대상이다.
**시크릿·운영 접속정보는 절대 커밋하지 않는다.** JWT·DB 비밀번호·SSH 키는
서버 파일(`/opt/haccp/.env.docker`)과 Jenkins Credentials로만 주입한다.
예제(`.env.example` · `.env.docker.example`)만 저장소에 둔다.

## 구성

| 경로 | 역할 |
|------|------|
| `frontend/haccp-web/` | React 18 + Vite 5 SPA |
| `backend/haccp-api/` | Spring Boot 3.3 + MyBatis API |
| `db_sasshaccp/` | PostgreSQL 스키마·SP 정본 |
| `nginx/` | edge TLS·리버스 프록시 conf 템플릿 |
| `scripts/` | 볼륨 초기화·빌드·배포·스모크·감시 |
| `.cursor/rules/` | 에이전트·운영 규약 |

## 사전 요구

- Node.js 20+ (`frontend/haccp-web/.nvmrc`)
- Java 17 (`backend/haccp-api/.java-version`)
- 외부 PostgreSQL (DB·스키마 `sasshaccp`) — 로컬은 compose `--profile with-db` 가능
- Docker 24+ (이미지·compose 배포)

## 로컬 기동 (요약)

```bash
# DB: db_sasshaccp/ SQL을 운영·개발 DB에 적용 (순서대로)
# 또는: bash scripts/db_migrate_dryrun.sh 로 문법만 검증

# API — listen 7070 (운영 컨테이너와 동일). CORS Origin = Vite 4173
cd backend/haccp-api
cp .env.example .env   # 값 입력 후 — .env 는 git 금지
./mvnw spring-boot:run

# Web — http://localhost:4173  →  VITE_API_BASE_URL=http://localhost:7070
cd frontend/haccp-web
cp .env.example .env
npm ci
npm run dev
```

문서 정본: [`docs/`](docs/) (`1_`~`21_` · [`docs/README.md`](docs/README.md)).
배포 런북: [`docs/20_배포_런북.md`](docs/20_배포_런북.md).
FE/BE `*/docs/` 는 옛 경로 스텁. 양식 HWP(로컬): `docs/templates/`.
운영 edge 호스트 publish는 `127.0.0.1:17070:7070` (로컬 Vite 포트와 무관).

## 시크릿 (필수)

| 해도 됨 | 하면 안 됨 |
|---------|-----------|
| `*.env.example` · `.env.docker.example` | `.env` · `.env.docker` · `*_secret*` |
| Jenkins Credentials (`haccp-*`) | Jenkinsfile·compose에 실값 하드코딩 |
| 서버 `/opt/haccp/.env.docker` (0600) | git commit / PR 첨부 |

커밋 전 검사:

```bash
bash scripts/pre-commit-check-secrets.sh
# 또는: ln -sf ../../scripts/pre-commit-check-secrets.sh .git/hooks/pre-commit
```

## Docker / Jenkins

- 이미지·compose·Nginx: 런북 §8~§10
- 시크릿·Credentials·JWT 회전: 런북 §5 (시크릿)
- 파이프라인: 루트 `Jenkinsfile` · nightly `Jenkinsfile.audit`
- 첫 배포 절차·롤백·스모크: 런북 §9~§14
