# HACCP SaaS

HACCP 기록·결재 SaaS. MES(`metis`)와 **별도** DB·스키마 `sasshaccp`를 사용한다.

이 저장소는 MES 모노레포에서 HACCP만 분리한 **public** 대상이다.
**시크릿·운영 접속정보는 절대 커밋하지 않는다.** JWT·DB 비밀번호·SSH 키는
서버 파일(`.env.docker`)과 Jenkins Credentials로만 주입한다.
예제(`.env.example` · `.env.docker.example`)만 저장소에 둔다.

## 읽기 순서 (주니어·에이전트)

이 파일 E2E 절 → [`docs/23_PIPELINE.md`](docs/23_PIPELINE.md) (태그→파일) → [`docs/15_HACCP_FE_BE_통합_상세스펙.md`](docs/15_HACCP_FE_BE_통합_상세스펙.md) (유형별 이야기) → 해당 도메인 README (`pages/sys/`, `pages/docs/`, `pages/ccp/` …) → 화면 README가 있으면 그 파일 → 소스 주석.

화면마다 `<Route>`가 없다. 식별자는 `scrnCd`. URL은 `tabRoute.routeOf(scrnCd)` 계층 경로다. Vite·Router **basename은 `/haccp/`** 이고, 라우터 pathname에는 `/haccp`를 다시 넣지 않는다 (`/docs/ccp/ccp-cold-monitor`).

## E2E 요청 흐름

```
브라우저 (4173, base /haccp/)
  → main.tsx [HF1] → AppRoutes [HF2]
    → 미로그인: /login (LoginPage)
    → 로그인: HaccpShell [HF49]  (path /*)
      → tabRoute.parseRoute: pathname → scrnCd
      → SCREEN_REGISTRY[scrnCd] keep-alive
      → api/*  http|httpBatch|httpFile + JWT Bearer
        → JwtFilter → Controller → Service → Mapper.xml → SP → tbl_*
```

탭 닫기: Zustand `afterRemove`로 배열을 한 번만 갱신한다. `navigate`는 셸 `onTabClosed`만. 활성 탭이 지워지면 **오른쪽 → 왼쪽 → `/`(홈)**. today-tasks를 첫 칸에 고정하지 않는다.

PIPELINE 전수 표는 이 파일이 아니라 [`docs/23_PIPELINE.md`](docs/23_PIPELINE.md)다. 새 모듈은 표에 없는 빈 번호를 쓰고 코드에 `PIPELINE[HFn]`/`[HBn]`을 단다. 같은 번호가 여러 파일에 있으면 클러스터다. 재채번하지 않는다.

## 핸드북

| 문서 | 내용 |
|------|------|
| [`환경구축.md`](환경구축.md) | 도구·DB·로컬 4173/7070 · **Jenkins 설치·Credentials·Job** |
| [`깃.md`](깃.md) | **팀 인수인계** — 일일위생점검표 예시로 Git Bash 전 구간 |
| [`개발.md`](개발.md) | 브랜치·FE/BE 규약·인증·Path `/haccp` · 검증 |
| [`운영.md`](운영.md) | `haccp-deploy` Build Now · 스테이지·스모크·장애 대응 |
| [`완성.md`](완성.md) | 2026-08-11 타 AI 덤프. **살아 있는 정본 아님** (루트 README · docs/15 · docs/23) |

상세 스펙·런북 정본: [`docs/`](docs/) (`1_`~`23_` · [`docs/README.md`](docs/README.md)).  
배포 런북: [`docs/20_배포_런북.md`](docs/20_배포_런북.md).  
양식 HWP(로컬): `docs/templates/`. 폴더 역할은 각 디렉터리 `README.md`.

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
# DB: 당분간 스키마 정본은 DBeaver(운영 DB). 저장소 SQL 자동 migrate는 CI에서 제외.
# 필요 시 수동: bash scripts/db_migrate_dryrun.sh (문법) · compose --profile migrate (적용)

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

운영 edge 호스트 publish는 `127.0.0.1:17070:7070` (로컬 Vite 포트와 무관).

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

- 이미지·compose·Nginx: [`docs/20_배포_런북.md`](docs/20_배포_런북.md) §8~§10 · [`운영.md`](운영.md)
- Job: `haccp-deploy` (`Jenkinsfile`) · `haccp-audit` (`Jenkinsfile.audit`)
- 트리거(현재): localhost Jenkins → **Build Now** (webhook 없음). 설치는 [`환경구축.md`](환경구축.md) §11
- 운영 Path: `/haccp/` · 로그아웃 URL은 `/haccp/login`
