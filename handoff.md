# handoff — 지금 무엇을 하고 있나

> 갱신: 2026-09-03 · **진행 중:** 문서 검수 2차 (지정 md 전부)
> 정본이 아니다 — 규칙은 `.cursor/rules/`, 무엇이 어디 있나는 [`INDEX.md`](INDEX.md),
> 프로젝트 상태는 [`세션_인수인계.md`](세션_인수인계.md). 여기는 **이번 작업의 진행 상태**만 담는다.

작업이 시작되면 이 파일을 메시지마다 갱신한다. 끝나면 다시 이 상태로 비운다.

---

**두 세션이 이 파일을 같이 쓴다.** 자기 절만 고치고 남의 절을 지우지 않는다.
직전에 끝난 일: HTML 양식코드 `tml_ccp_*` → `html_ccp_*`
([`docs/8_결정_이력.md`](docs/8_결정_이력.md) 「HTML 양식코드는 html_」).

## 1. 지금 하는 일

사용자가 정한 4단계 중 **2단계**.

| 단계 | 무엇 | 고치나 | 상태 |
|---|---|---|---|
| 0 | 세팅 — `INDEX.md`·`gen_index.mjs`·메모리 | 만든다 | 끝 |
| 1 | `.cursor/rules/` 체인 검수 | md 고친다 | 끝 (R1~R11 · 41건) |
| 2 | 지정 md 전부 검수 (라운드 최대 30) | **md 만 고친다** | **진행 중 (R1 끝)** |
| 3 | 프론트·백엔드 코드 검토 | **안 고친다.** 수정대상·크리티컬만 지정해 한 번에 보고 | 대기 |
| 4 | 소스 주석 계획을 여기 적는다 → 다른 에이전트가 수정 | 계획만 | 대기 |

**md 만 고친다.** `docs/8_결정_이력.md` 「문서 검수는 md 만 고친다」가 정본이다.
소스·생성기·SQL 은 이 루프에서 안 만진다.

## 2. 검수 방식

서브 둘, 메인 하나. 정의 `.claude/agents/`, 절차 `.claude/commands/doc-audit.md`.
Critic·Defender 는 `Read`·`Grep`·`Glob` 만 쓴다. 고치는 손은 메인 하나다.

판정 어휘 넷: `결함` · `결함 아님` · `재확인 대기` · `단정 불가`.
근거는 `파일:줄` 또는 함수·SP 이름. 없으면 `단정 불가` 이고 문서를 안 고친다.
종료: ① `결함 없음` ② 의미 변경 없음 ③ 같은 이슈 2회 핑퐁 ④ 30라운드.

## 3. 2차 검수 라운드 기록

대상: `docs/` 11본 · 루트 15본 · `frontend/` README 67본 · `backend/` README 101본.

| R | 대상 | A | B | 반영 |
|---|---|---|---|---|
| 1 | 미검수 루트 6본 (`깃`·`개발`·`사용자_매뉴얼`·`배포후_개선점`·`배포전_최종검증_계획`·`결과`) | 5건 | 5건 전부 결함 | 4건 · 1건 결정 대기 |

### R1 반영 내역

| # | 무엇 | 어떻게 |
|---|---|---|
| 1 | `깃.md` 가 `ccp-htg` 를 "일일위생점검표"라 부르고 없는 `HygieneCheckPage`·`api/hygieneApi.ts` 를 지목 | 전건 "CCP 가열공정 작성" 통일 · 경로를 `CcpHtgDraftPage.tsx` 로 · 없는 FE API 행 삭제 |
| 2 | `깃.md` PULL REQUEST 절차가 정본 위반 (제목에 `[STEP nn]` 없음 · 작성자 self-merge) | 제목 접두 추가 · 7절을 "승인 확인 후 리뷰어·관리자가 머지" 로 |
| 3 | `개발.md` 커밋 type·scope 가 정본과 다름 | 정본에 맞춤 · PULL REQUEST 제목 규칙 명시 |
| 4 | `깃.md`:14 만 운영 확인을 `https` 로 시킴 | `http` 로 · "https 로 열지 않는다" 근거 링크 |
| 5 | `배포전_최종검증_계획.md` 가 살아 있는 `docs/5_PIPELINE_색인.md` 를 "없어졌다"며 자기를 대체본으로 지목 | 두 줄 삭제 |

### 브랜치 접두 — 결정 났다 (2026-09-03)

**정본을 넓혔다.** 실무가 이미 그렇게 돌고 있었다.
`03-branching.mdc` 브랜치 줄이 이제 `feature/` · `fix/` · `refactor/` · `docs/` · `test/` ·
`hotfix/`(운영 급한 것) 여섯이다. `개발.md`:53-62 와 맞는다.

남은 어긋남 하나: 커밋 scope 정본은 `fe`·`be`·`db`·`infra`·`docs` 인데
최근 커밋에 `fix(draft)` 가 있다. **type·scope 는 안 넓혔다** (사용자가 브랜치만 고르셨다).

## 4. 메인이 잡은 것 — 판정 대기

**화면 수가 28↔29 로 갈렸다.** `#93` 이 일정 캘린더를 넣어 29가 됐다.

- 29: `docs/3_화면_지도.md`(생성기) · `docs/6_테스트.md` · `docs/README.md` ·
  `E2E.md`:41·75 · `frontend/haccp-web/e2e/README.md` · `frontend/haccp-web/PIPELINE.md`
- 28로 남음: 루트 `README.md` · `docs/1_시작하기.md` · `세션_인수인계.md` · `E2E.md`:3·85·278·281
- 결함 아님(과거 기록): `docs/8_결정_이력.md`:18 · `common/auth/README.md`:56 · `E2E_ERRORS.md`

## 5. 코드 쪽 — 보고만 (3단계에서 넘길 것)

**고치지 않았다.** 지정만 한다.

| # | 파일 | 무엇 | 심각도 |
|---|---|---|---|
| C1 | `tools/_rename_tml_html.mjs`:38 | `replaceAll("tml_ccp_","html_ccp_")` 에 가드가 없다. `html_ccp_` 안에 `tml_ccp_` 가 들어 있어 **두 번 돌리면 `hhtml_ccp_`** 가 된다. 재실행 금지가 안 적혀 있다 | P1 |
| C2 | `tools/_rename_tml_html.mjs`:20-22 | `EXT` 에 `.html` 이 없어 `public/manual/{ccp-htg,ccp-mtl,ccp-pkg,ccp-verify,hyg-process}.html`:292 **다섯 곳이 옛 `tml_ccp_mtl_001` 그대로다** | P1 |
| C3 | `public/manual/*.html`:292 | 다섯 파일이 화면과 무관하게 전부 `mtl_001` 을 예시로 쓴다 | P2 |

**`db_sasshaccp/08_rename_tml_html.sql` 은 안전하다.** 5블록 전부 `(^|[^a-z])tml_ccp_`
정규식 가드이고 멱등이다. 반쯤 된 DB 만 `45000` 으로 막고 전량 롤백한다.

## 6. 보고했고 아직 안 고친 것

- **`metis` 는 잔재가 아니다.** 코드·설정 0건, md 6곳은 "MES 와 상호 참조·공유 금지" 경계 선언이다
- **README 없는 소스 폴더 13개** — `INDEX.md` 「README 없는 폴더」가 정본
- `grokbot/`(96M) · `.tools/` · `.playwright-mcp/` · `test-results/` 는 gitignore 라 저장소 밖이다

## 7. 다음에 할 것

1. 브랜치 접두 결정을 받는다 (3절)
2. 화면 수 28↔29 를 닫는다
3. R2 — `docs/` 11본 · 루트 나머지 9본
4. R3~ — `frontend/`·`backend/` README 168본 (층별로 나눠 돈다)
5. 2단계가 끝나면 3단계 코드 검토 → 4단계 주석 계획

## 8. 이어받는 사람이 먼저 할 것

```sh
bash scripts/audit_docs_links.sh
bash scripts/audit_generated_docs.sh
bash scripts/audit_version_drift.sh
bash scripts/audit_ops_delete.sh
```

- **커밋 안 했다.**
- 검수 서브는 읽기 전용이다. 고치는 손은 메인 하나다
- 세션 한도로 서브가 죽을 수 있다. 죽으면 범위를 좁혀 다시 부른다
