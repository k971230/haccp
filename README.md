# HACCP SaaS

HACCP 기록·결재 SaaS. MES(`metis`)와 **별도** DB·스키마 `sasshaccp`를 사용한다.

이 저장소는 MES 모노레포에서 HACCP만 분리한 **public** 대상이다.
**시크릿·운영 접속정보는 절대 커밋하지 않는다.** JWT·DB 비밀번호·SSH 키는
서버 파일(`.env.docker`)과 Jenkins Credentials로만 주입한다.
예제(`.env.example` · `.env.docker.example`)만 저장소에 둔다.

## 핸드북 (시작은 여기)

| 문서 | 내용 |
|------|------|
| [`환경구축.md`](환경구축.md) | 도구·DB·로컬 4173/7070 · **Jenkins 설치·Credentials·Job** |
| [`개발.md`](개발.md) | 브랜치·FE/BE 규약·인증·Path `/haccp` · 검증 |
| [`운영.md`](운영.md) | `haccp-deploy` Build Now · 스테이지·스모크·장애 대응 |

상세 스펙·런북: [`frontend/haccp-web/docs/`](frontend/haccp-web/docs/) · [`backend/haccp-api/docs/`](backend/haccp-api/docs/) · [`docs/12_배포_런북.md`](docs/12_배포_런북.md).

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

포트: **API 7070** · **Vite 4173** (MES 5173/8080과 분리). 상세는 [`환경구축.md`](환경구축.md).

```bash
# DB: db_sasshaccp/ SQL을 운영·개발 DB에 적용 (순서대로)
# 또는: bash scripts/db_migrate_dryrun.sh 로 문법만 검증

# API — listen 7070 · CORS Origin = http://localhost:4173
cd backend/haccp-api
cp .env.example .env   # 값 입력 후 — .env 는 git 금지
./mvnw spring-boot:run

# Web — http://localhost:4173  →  VITE_API_BASE_URL=http://localhost:7070
cd frontend/haccp-web
cp .env.example .env
npm ci
npm run dev
```

## 시크릿 (필수)

| 해도 됨 | 하면 안 됨 |
|---------|-----------|
| `*.env.example` · `.env.docker.example` | `.env` · `.env.docker` · `*_secret*` |
| Jenkins Credentials (`haccp-*`) | Jenkinsfile·compose에 실값 하드코딩 |
| 서버 `.env.docker` (0600) | git commit / PR 첨부 |

커밋 전 검사:

```bash
bash scripts/pre-commit-check-secrets.sh
# 또는: ln -sf ../../scripts/pre-commit-check-secrets.sh .git/hooks/pre-commit
```

## Docker / Jenkins

- 이미지·compose·Nginx: [`docs/12_배포_런북.md`](docs/12_배포_런북.md) §8~§10 · [`운영.md`](운영.md)
- Job: `haccp-deploy` (`Jenkinsfile`) · `haccp-audit` (`Jenkinsfile.audit`)
- 트리거(현재): localhost Jenkins → **Build Now** (webhook 없음). 설치는 [`환경구축.md`](환경구축.md) §11
- 운영 Path: `/haccp/` · 로그아웃 URL은 `/haccp/login`
