# HACCP SaaS

HACCP 기록·결재 SaaS. MES(`metis`)와 **별도** DB·스키마 `sasshaccp`를 사용한다.

이 저장소는 MES 모노레포에서 HACCP만 분리한 **public** 대상이다.
**시크릿·운영 접속정보는 절대 커밋하지 않는다.** JWT·DB 비밀번호·SSH 키는
서버 파일(`.env.docker`)과 Jenkins Credentials로만 주입한다.
예제(`.env.example` · `.env.docker.example`)만 저장소에 둔다.

---

## 지금 어디까지 왔나 (2026-09-03)

| 항목 | 값 |
|---|---|
| 단계 | **개발은 어느 정도 끝났다.** 남은 것은 매뉴얼과 현장 검증이다 |
| 배포 서버 | `http://180.71.58.87/haccp/` — **운영 개시 전**. `https` 로 열지 않는다(아래) |
| 업무 고리 | 팀원이 쓰고 팀장이 결재하고 **종이에 결재자가 남는** 고리가 두 업체에서 돈다 |
| 화면 | **29화면.** 전수 URL 은 [`docs/3_화면_지도.md`](docs/3_화면_지도.md) — 생성기가 만든다 |
| 시험 | `vitest` · `playwright`(스펙 23본) · `mvnw`. 건수는 문서에 박지 않는다 — 각 러너로 센다 |
| DB | 정본 7본. 표·컬럼 수는 [`docs/10_테이블_레이아웃.md`](docs/10_테이블_레이아웃.md) · SP 는 [`docs/9_SP_색인.md`](docs/9_SP_색인.md) |

**남은 일 넷은 사람 손에 있다** — 서명 등록 · 매뉴얼 작성 · 알림 방향 결정 · 현장 한 달 사용.
**#93 머지 뒤 운영 반영은 Jenkins `haccp-deploy` Build Now.**
자세한 것은 [`세션_인수인계.md`](세션_인수인계.md).

> **배포 서버는 `http://` 로 본다.** 지금 인증서가 자체서명이라 `https` 로 열면
> rhwp 편집기 ServiceWorker 오류가 70건 쌓여 **진짜 신호를 덮는다**(화면·저장은 정상).
> `http` 로는 0건이다. 까닭과 실측은 [`운영.md`](운영.md) 10.2.

---

## 읽기 순서

**작업을 이어받는 사람은 [`세션_인수인계.md`](세션_인수인계.md) 부터 읽는다.**
지금 무엇이 되어 있고, 무엇을 조심해야 하고, 어디를 먼저 보는지가 거기 있다.
**작업이 진행 중이면 [`handoff.md`](handoff.md) 가 그 위에 있다** — 지금 무엇을 하는 중인지.
무엇이 어느 폴더에 있는지는 [`INDEX.md`](INDEX.md) (생성기가 만든다).

그다음은 필요한 만큼만 —
이 파일 E2E 절 → [`docs/5_PIPELINE_색인.md`](docs/5_PIPELINE_색인.md) (태그→파일) → [`docs/1_시작하기.md`](docs/1_시작하기.md) (유형별 이야기) → 해당 도메인 README (`pages/docs/`, `pages/sys/` …) → 화면 README가 있으면 그 파일 → 소스 주석.

화면마다 `<Route>`가 없다. 식별자는 `scrnCd`. URL은 `tabRoute.routeOf(scrnCd)` 계층 경로다. Vite·Router **basename은 `/haccp/`** 이고, 라우터 pathname에는 `/haccp`를 다시 넣지 않는다 (`/draft/ccp-monitoring/ccp-htg`).  
경로(URL=DB=폴더=패키지) 정본: [`docs/4_명명과_경로.md`](docs/4_명명과_경로.md).

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

PIPELINE 전수 표는 이 파일이 아니라 [`docs/5_PIPELINE_색인.md`](docs/5_PIPELINE_색인.md)다. 새 모듈은 표에 없는 빈 번호를 쓰고 코드에 `PIPELINE[HFn]`/`[HBn]`을 단다. 같은 번호가 여러 파일에 있으면 클러스터다. 재채번하지 않는다.

## 어디를 보나

**하려는 일**로 찾는다.

| 하려는 일 | 볼 곳 |
|---|---|
| PC 를 처음 잡는다 (Jenkins 포함) | [`환경구축.md`](환경구축.md) |
| 프로젝트가 뭔지·업무가 어떻게 흐르는지 | [`docs/1_시작하기.md`](docs/1_시작하기.md) |
| 코드가 어떤 순서로 도는지 | [`backend/haccp-api/PIPELINE.md`](backend/haccp-api/PIPELINE.md) · [`frontend/haccp-web/PIPELINE.md`](frontend/haccp-web/PIPELINE.md) |
| 브랜치 → PR → main | [`개발.md`](개발.md) · 명령 실습 [`깃.md`](깃.md) |
| 화면을 하나 만든다 | [`docs/2_화면_추가하기.md`](docs/2_화면_추가하기.md) |
| 기존 화면을 고친다 | [`docs/3_화면_지도.md`](docs/3_화면_지도.md) |
| 이름·경로를 정한다 | [`docs/4_명명과_경로.md`](docs/4_명명과_경로.md) |
| DB 를 깐다 / 새 업체를 연다 | [`db_sasshaccp/README.md`](db_sasshaccp/README.md) |
| 배포한다 | [`DEPLOY.md`](DEPLOY.md) |
| 배포 뒤 감시·장애 대응 | [`운영.md`](운영.md) |
| 테스트를 돌린다 / 결과를 본다 | [`docs/6_테스트.md`](docs/6_테스트.md) · [`E2E.md`](E2E.md) |
| 왜 이렇게 돼 있나 | [`docs/8_결정_이력.md`](docs/8_결정_이력.md) |
| 표에 어떤 칸이 있나 | [`docs/10_테이블_레이아웃.md`](docs/10_테이블_레이아웃.md) — 생성기 · 엑셀본 동봉 |
| 이 표를 고치면 어느 SP 가 걸리나 | [`docs/9_SP_색인.md`](docs/9_SP_색인.md) — 생성기 |
| 사용자에게 무엇을 안내하나 | [`사용자_매뉴얼.md`](사용자_매뉴얼.md) |
| **작업을 이어받는다** | [`세션_인수인계.md`](세션_인수인계.md) — 지금 어디까지 왔고 무엇을 조심하나 |

문서 전체 지도는 [`docs/README.md`](docs/README.md) — **정본 10본**이다.
양식 HWP(로컬)는 `docs/templates/`. 폴더 역할은 각 디렉터리 `README.md`.

### 지난 회차 기록 (읽을 필요는 없다)

아래는 **그때의 기록**이다. 지금 상태를 알려면 위 표를 본다.

| 파일 | 무엇 |
|---|---|
| [`배포전_최종검증_계획.md`](배포전_최종검증_계획.md) · [`배포전_최종검증_결과.md`](배포전_최종검증_결과.md) | 첫 배포 전 점검 |
| [`배포후_개선점.md`](배포후_개선점.md) | 배포 직후 나온 것들 |
| [`E2E_ERRORS.md`](E2E_ERRORS.md) | E2E 가 잡아낸 결함 대장 (`E2E-001`…) |

## 구성

| 경로 | 역할 |
|------|------|
| `frontend/haccp-web/` | React 18 + Vite 5 SPA |
| `backend/haccp-api/` | Spring Boot 3.3 + MyBatis API |
| `db_sasshaccp/` | PostgreSQL 스키마·SP 정본 |
| `nginx/` | edge TLS·리버스 프록시 conf 템플릿 |
| `scripts/` | 볼륨 초기화·빌드·배포·스모크·감시 |
| `.cursor/rules/` | 에이전트·운영 규약 (정본. `CLAUDE.md`·`AGENTS.md` 는 여기를 가리킨다) |
| `.claude/` | Claude Code 서브에이전트·슬래시 명령 (규칙 아님. `.claude/README.md`) |
| `INDEX.md` · `handoff.md` | 폴더 목차(생성기) · 진행 중인 작업 상태 |
| `frontend/haccp-web/e2e/` | Playwright E2E — 화면·API·SP·DB 를 한 줄로 꿴다 |

## 사전 요구

- Node.js 20+ (`frontend/haccp-web/.nvmrc`)
- Java 17 (`backend/haccp-api/.java-version`)
- 외부 PostgreSQL (DB·스키마 `sasshaccp`) — 로컬은 compose `--profile with-db` 가능
- Docker 24+ (이미지·compose 배포)

## 로컬 기동 (요약)

포트: **API 7070** · **Vite 4173** (MES 5173/8080과 분리). 상세는 [`환경구축.md`](환경구축.md).

```bash
# DB — 정본은 db_sasshaccp/ 7본이다. 빈 DB 에 순서대로 깔면 끝난다
#   PGHOST=... PGUSER=... PGPASSWORD=*** bash db_sasshaccp/apply-all.sh
#   새 업체:  apply-all.sh 를 다시 부르지 않는다 — 00_ddl 이 42P06 으로 죽는다.
#             업체분 4본(03·05·06·07)만 직접 돌린다 — db_sasshaccp/README.md 「새 업체를 여는 법」

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

## 검증

바꾼 뒤에는 이 순서로 본다. **`mvn test` 통과가 기동 성공을 뜻하지 않는다** —
MyBatis 매퍼 XML 은 컴파일에 안 잡혀서, 패키지를 옮기면 반드시 기동해서 확인한다.

```bash
# 프론트
cd frontend/haccp-web
npx tsc --noEmit ; npx eslint src e2e ; npx vitest run ; npm run build

# 화면까지 실제로 도는지 — Playwright E2E (DB 대조 포함). 건수는 --list 로 센다
# E2E 는 4173 의 dist/ 를 본다. 띄우는 건 Playwright 가 아니라 우리다
npm run preview &
npx playwright test

# 백엔드
cd backend/haccp-api ; ./mvnw -q -o test

# 생성 문서 — 화면·SP·표를 고쳤으면 표도 다시 뽑는다
bash scripts/audit_generated_docs.sh
```

**여기서 자주 데인다.**

- **E2E 는 `dist/` 를 본다.** 프론트를 고쳤으면 **반드시 다시 빌드**한다.
  `tsc` 오류로 빌드가 멈추면 **옛 `dist` 가 그대로 남아** 고치기 전 화면을 시험하게 된다
- **시험은 통과만 보고 넘기지 않는다.** 새 시험은 **깨뜨려서 무는지** 확인한다 —
  이번 회차에 「통과하는데 실은 안 잡는 시험」을 여러 번 걸렀다
- **운영에 전체 E2E 를 돌리지 않는다.** `resetDocuments()` 가 **문서를 전량 삭제**하고 시작한다.
  배포 서버 상대 시험은 `Jenkinsfile.e2e` 가 전용 계정으로 한다
- **배포된 것이 맞는지는 번들 문자열로 본다.** 화면을 눌러 보는 것보다 확실하다 —
  JS 가 파일 하나라 새 회차의 문구가 있으면 그 회차가 올라간 것이다

  ```sh
  B=$(curl -s http://180.71.58.87/haccp/ | grep -o 'index-[A-Za-z0-9_-]*\.js' | head -1)
  curl -s "http://180.71.58.87/haccp/assets/$B" | grep -c "열 초기화"   # 0 이면 옛 프론트다
  ```

층별로 무엇이 어떤 순서로 도는지는 파이프라인 문서에 파일명까지 적혀 있다 —
[`backend/haccp-api/PIPELINE.md`](backend/haccp-api/PIPELINE.md) ·
[`frontend/haccp-web/PIPELINE.md`](frontend/haccp-web/PIPELINE.md).

E2E 는 화면 문구가 아니라 **DB 를 직접 읽어** 판정한다. 결과와 발견한 결함은
[`E2E.md`](E2E.md) · [`E2E_ERRORS.md`](E2E_ERRORS.md), 스펙 구조는
[`frontend/haccp-web/e2e/README.md`](frontend/haccp-web/e2e/README.md).

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

**배포 전 체크리스트: [`DEPLOY.md`](DEPLOY.md)** — Build Now 하나만 누르면 되는 상태인지,
DB 는 어떻게 반영하는지가 여기 있다.

- 이미지·compose·Nginx: [`DEPLOY.md`](DEPLOY.md) §8~§10 · [`운영.md`](운영.md)
- Job: `haccp-deploy` (`Jenkinsfile`) · `haccp-audit` (`Jenkinsfile.audit`)
- 트리거(현재): localhost Jenkins → **Build Now** (webhook 없음). 설치는 [`환경구축.md`](환경구축.md) §11
- 운영 Path: `/haccp/` · 로그아웃 URL은 `/haccp/login`
