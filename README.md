# HACCP SaaS

HACCP 기록·결재 SaaS. MES(`metis`)와 **별도** DB·스키마 `sasshaccp`를 사용한다.

이 저장소는 MES 모노레포에서 HACCP만 분리한 **public** 대상이다. 시크릿·운영 접속정보는 커밋하지 않는다.

## 구성

| 경로 | 역할 |
|------|------|
| `frontend/haccp-web/` | React 18 + Vite 5 SPA |
| `backend/haccp-api/` | Spring Boot 3.3 + MyBatis API |
| `db_sasshaccp/` | PostgreSQL 스키마·SP 정본 |
| `.cursor/rules/` | 에이전트·운영 규약 |

## 사전 요구

- Node.js 20+ (`frontend/haccp-web/.nvmrc`)
- Java 17 (`backend/haccp-api/.java-version`)
- 외부 PostgreSQL (DB·스키마 `sasshaccp`)

## 로컬 기동 (요약)

```bash
# DB: db_sasshaccp/ SQL을 운영·개발 DB에 적용 (순서대로)

# API
cd backend/haccp-api
cp .env.example .env   # 값 입력 후 — .env 는 git 금지
./mvnw spring-boot:run

# Web
cd frontend/haccp-web
cp .env.example .env
npm ci
npm run dev
```

문서: `frontend/haccp-web/docs/`, `backend/haccp-api/docs/`.

## 시크릿

- `.env`, `.env.docker` **커밋 금지**
- 예제만 `*.env.example` 사용
- public 저장소이므로 Credentials / 서버 파일로만 주입

## Docker / Jenkins

MES용 compose·Jenkins는 이 저장소에 포함하지 않는다. HACCP 전용 배포 정의는 별도 추가한다.
