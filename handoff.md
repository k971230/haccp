# handoff — 지금 무엇을 하고 있나

> 갱신: 2026-09-03 · **진행 중:** 문서 검수 2차 (지정 md 전부)
> 정본이 아니다 — 규칙은 `.cursor/rules/`, 무엇이 어디 있나는 [`INDEX.md`](INDEX.md),
> 프로젝트 상태는 [`세션_인수인계.md`](세션_인수인계.md). 여기는 **이번 작업의 진행 상태**만 담는다.

작업이 시작되면 이 파일을 메시지마다 갱신한다. 끝나면 다시 이 상태로 비운다.

---

**두 세션이 이 파일을 같이 쓴다.** 자기 절만 고치고 남의 절을 지우지 않는다.
직전에 끝난 일: HTML 양식코드 `tml_ccp_*` → `html_ccp_*`
([`docs/8_결정_이력.md`](docs/8_결정_이력.md) 「HTML 양식코드는 html_」).
운영·시험 적용 뒤 `08_rename_tml_html.sql` 과 로컬 `_apply_sql.mjs` 는 지웠다.

## 0. 다른 세션 — CCP 작성 /forms 500 (2026-09-03)

라이브 `/forms` 4건 500. **DB 새 SP 는 정상.** 배포 JAR 는 `main`(PR #94) 이라
아직 `sp_tbl_tml_ccp_*` 를 부른다. 이름 변경은 `refactor/html-ccp-form-codes` 에만 있다.
`main` 머지 후 Jenkins 를 다시 눌러야 화면이 산다. 아래 검수 절은 그대로 둔다.

---

## 1. 지금 하는 일

사용자가 정한 4단계 중 **2단계**.

| 단계 | 무엇 | 고치나 | 상태 |
|---|---|---|---|
| 0 | 세팅 — `INDEX.md`·`gen_index.mjs`·메모리 | 만든다 | 끝 |
| 1 | `.cursor/rules/` 체인 검수 | md 고친다 | 끝 (R1~R11 · 41건) |
| 2 | 지정 md 전부 검수 (라운드 최대 30) | **md 만 고친다** | **진행 중 — R1·R2 끝, R3 도는 중** |
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
| 1 | 미검수 루트 6본 (`깃`·`개발`·`사용자_매뉴얼`·`배포후_개선점`·`배포전_최종검증_계획`·`결과`) | 5건 | 5건 전부 결함 | 5건 (브랜치 접두는 결정 받고 반영) |
| 2 | `docs/` 11본 | 5건 | 5건 전부 결함 | 5건 |

### R1 반영 내역

| # | 무엇 | 어떻게 |
|---|---|---|
| 1 | `깃.md` 가 `ccp-htg` 를 "일일위생점검표"라 부르고 없는 `HygieneCheckPage`·`api/hygieneApi.ts` 를 지목 | 전건 "CCP 가열공정 작성" 통일 · 경로를 `CcpHtgDraftPage.tsx` 로 · 없는 FE API 행 삭제 |
| 2 | `깃.md` PULL REQUEST 절차가 정본 위반 (제목에 `[STEP nn]` 없음 · 작성자 self-merge) | 제목 접두 추가 · 7절을 "승인 확인 후 리뷰어·관리자가 머지" 로 |
| 3 | `개발.md` 커밋 type·scope 가 정본과 다름 | 정본에 맞춤 · PULL REQUEST 제목 규칙 명시 |
| 4 | `깃.md`:14 만 운영 확인을 `https` 로 시킴 | `http` 로 · "https 로 열지 않는다" 근거 링크 |
| 5 | `배포전_최종검증_계획.md` 가 살아 있는 `docs/5_PIPELINE_색인.md` 를 "없어졌다"며 자기를 대체본으로 지목 | 두 줄 삭제 |

### R2 반영 내역 (`docs/` 11본)

| # | 무엇 | 어떻게 |
|---|---|---|
| 1 | `7_보안과_파일.md` 권한 매트릭스가 28 기준이고 USER 행 수·삭제 수가 틀림 | ADMIN 29 / USER 17·16·16·1 / VIEWER 18 로. **USER 는 12화면에 권한행이 아예 없다**·삭제는 `attach` 하나·VIEWER 못 읽는 11화면 내역을 명시 |
| 2 | `1_시작하기.md` 설치 후 기대 출력이 `53 155 43 …` | `53 156 45 …` 로. 앞 셋은 정본에서 세는 법을 붙이고, 코드·사용양식은 실행 결과로만 확정된다고 적음 |
| 3 | `7_보안과_파일.md`:95 업로드 경로가 `{root}/{co_cd}/{yyyy}/{mm}/` | 실제 `{root}/HaccpLogBooks/{co_cd}/{tmpl_cd}/{yyyy-MM-dd}/…` 로 (`DocumentFileStorage.logbookFolder`) |
| 4 | `2_화면_추가하기.md` 에 스모크 배열 갱신 단계가 없음 | 7단계에 `SCREENS` 배열 추가 절차 · 마지막 점검 10번 신설. 그 배열은 `SCREEN_PATH` 를 안 읽어 자동으로 안 는다 |
| 5 | `2_화면_추가하기.md`:166 "빠뜨리면 403 이 나거나" — **실제는 검사 없이 통과** | 뒤집어 적음. `resolve` 가 `Optional.empty()` → 인터셉터가 로그도 없이 통과. 403 이 나는 두 갈래를 따로 적고, `7_보안과_파일.md` 2겹 표에도 "등록 누락은 열린 문" 한 줄 추가 |

### 채번 규칙 `tml_` → `html_` — 문서 쪽 마감 (2026-09-03)

DB·시드(`tbl_doc_no_rule` 의 `tmpl_cd`·`prefix`)·`E2E.md`:237 은 이미 `html_` 로 맞았다.
**빠져 있던 곳은 사용자 매뉴얼 웹페이지 5본**(`public/manual/*.html`:292) 뿐이었다 —
현장 담당자가 문서번호를 찾을 때 보는 예시다. 고치면서 화면별 코드도 맞췄다.

| 매뉴얼 | 전 | 후 |
|---|---|---|
| `ccp-htg.html` | `tml_ccp_mtl_001-…` | `html_ccp_htg_001-…` |
| `ccp-mtl.html` | `tml_ccp_mtl_001-…` | `html_ccp_mtl_001-…` |
| `ccp-pkg.html` | `tml_ccp_mtl_001-…` | `html_ccp_pkg_001-…` |
| `ccp-verify.html` | `tml_ccp_mtl_001-…` | `html_ccp_chk_001-…` |
| `hyg-process.html` | `tml_ccp_mtl_001-…` | `html_hyg_prc_001-…` |

다섯 파일이 화면과 무관하게 전부 `mtl_001` 을 쓰던 것(C3)도 이걸로 같이 닫혔다.
남은 `tml_` 은 `dist/`(빌드 산출물)와 `grokbot/` 뿐이고 둘 다 gitignore 다.

### 브랜치 접두 — 결정 났다 (2026-09-03)

**정본을 넓혔다.** 실무가 이미 그렇게 돌고 있었다.
`03-branching.mdc` 브랜치 줄이 이제 `feature/` · `fix/` · `refactor/` · `docs/` · `test/` ·
`hotfix/`(운영 급한 것) 여섯이다. `개발.md`:53-62 와 맞는다.

남은 어긋남 하나: 커밋 scope 정본은 `fe`·`be`·`db`·`infra`·`docs` 인데
최근 커밋에 `fix(draft)` 가 있다. **type·scope 는 안 넓혔다** (사용자가 브랜치만 고르셨다).

## 4. 화면 수 — 닫혔다 (2026-09-03)

**정본은 29다.** `tabRoute.ts` 의 `SCREEN_PATH` 를 직접 세서 확인했다
(board 2 · docs 7 · draft 6 · flow 5 · sys 9 = 29).

현재형 서술은 전부 29로 맞다 — 루트 `README.md`:19 · `세션_인수인계.md`:54 ·
`docs/1_시작하기.md`:106 · `docs/README.md` · `docs/6_테스트.md` · `E2E.md`:41·75 ·
`e2e/README.md` · `frontend/PIPELINE.md`.

남은 28 은 전부 **과거 기록이라 결함이 아니다** — 회차 결과(`E2E.md`:3·85·278·281 ·
`배포전_최종검증_*`), 사고 이력(`E2E_ERRORS.md`), 결정 이력(`8_결정_이력.md`:11·18),
실측표(`운영.md`:286 · `세션_인수인계.md`:284·375), `common/auth/README.md`:56.

## 5. 코드 쪽 — 보고만 (3단계에서 넘길 것)

**고치지 않았다.** 지정만 한다.

| # | 파일 | 무엇 | 상태 |
|---|---|---|---|
| C1·C2 | `tools/_rename_tml_html.mjs` | 무가드 `replaceAll` · `EXT` 에 `.html` 없음 | **무효** — 08 적용 뒤 도구·SQL 을 지웠다 |
| C3 | `public/manual/*.html`:292 | 채번 예시가 옛 `tml_` 이고 다섯 파일이 전부 `mtl_001` | **닫힘** — 화면별 코드로 고쳤다 |
| C4 | `e2e/screens.smoke.spec.ts`:17-47 | `SCREENS` 가 `SCREEN_PATH` 를 안 읽고 경로 29개를 하드코딩. 화면이 늘면 손으로 늘려야 한다 | 보고만 |
| C5 | `DocumentFileStorage.java`:70·141 · `application.yml`:101 | 주석이 실제 경로와 순서가 뒤집혀 있다 — 주석 `{coCd}/{일자}/{양식코드}` vs 코드 `{coCd}/{양식코드}/{일자}`. `:70` 은 파일명을 `{uuid}_{원본명}` 이라 하는데 실제는 `{일자}_{원본명}_{연번}` | 보고만 |

3단계에서 C4·C5 를 포함해 한 번에 낸다.

## 6. 보고했고 아직 안 고친 것

- **`metis` 는 잔재가 아니다.** 코드·설정 0건, md 6곳은 "MES 와 상호 참조·공유 금지" 경계 선언이다
- **README 없는 소스 폴더 13개** — `INDEX.md` 「README 없는 폴더」가 정본
- `grokbot/`(96M) · `.tools/` · `.playwright-mcp/` · `test-results/` 는 gitignore 라 저장소 밖이다

## 7. 다음에 할 것

1. R3 — 루트 나머지 9본 (`README`·`CLAUDE`·`AGENTS`·`DEPLOY`·`E2E`·`E2E_ERRORS`·
   `환경구축`·`운영`·`세션_인수인계`)
2. R4~ — `frontend/` README 67본 · `backend/` README 101본 (층별로 나눠 돈다)
3. 2단계가 끝나면 3단계 코드 검토 → 4단계 주석 계획

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
