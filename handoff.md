# handoff — 지금 무엇을 하고 있나

> 갱신: 2026-09-03 · **이 세션 끝:** 결재 4화면 통일 · 운영·시험 DB 맞춤 · 1회성 08·09 삭제 · **main 머지 뒤 Jenkins 대기**
> **다른 세션 진행:** 문서 검수 2차 (1절부터)
> 정본이 아니다 — 규칙은 `.cursor/rules/`, 무엇이 어디 있나는 [`INDEX.md`](INDEX.md),
> 프로젝트 상태는 [`세션_인수인계.md`](세션_인수인계.md). 여기는 **이번 작업의 진행 상태**만 담는다.

작업이 시작되면 이 파일을 메시지마다 갱신한다. 끝나면 다시 이 상태로 비운다.

---

**여러 세션이 이 파일을 같이 쓴다.** 자기 절만 고치고 남의 절을 지우지 않는다.
직전에 끝난 일: HTML 양식코드 `tml_ccp_*` → `html_ccp_*` (PR #95 머지됨).
운영·시험 적용 뒤 `08_rename_tml_html.sql` 과 로컬 `_apply_sql.mjs` 는 지웠다.

## 0. 이 세션 — 결재 4화면 통일 · DB 맞춤 · Jenkins 대기 (2026-09-03)

결재 4화면(첨부·대기·완료·문서함)을 이름·API·SP·UI 로 맞추고,
운영(`sasshaccp`)·시험(`sasshaccp_test`) DB 를 정본 `00_ddl`·`01_sp` 와 같게 맞춘 뒤
1회성 `08_remove_review.sql`·`09_rename_appr.sql` 을 저장소에서 지웠다.
**젠킨스는 안 눌렀다.** 사용자가 `haccp-deploy` Build Now.

### DB — 이미 맞춰 둠 (젠킨스가 안 건드린다)

| 항목 | 운영 | 시험 |
|---|---|---|
| `tbl_document.status` DEFAULT | `WRK` | `WRK` |
| `reviewer_id`·`review_dt` | 없음 | 없음 |
| `sp_sign_ready_r_000` / `sp_sign_ok_r_000` | 있음 | 있음 |
| 구 `sp_tbl_document_appr_inbox/hist` | 없음 | 없음 |
| `role_cd='REVIEW'` 결재선 단계 | 0 | 0 |
| SP 개수 (`sp_%`) | 156 | 156 |

적용 순서(운영): `08_remove_review` → `09_rename_appr` → `01_sp.sql` 전체.
시험은 컬럼·신 SP 가 먼저 있었고, 남은 REVIEW 코드·`01_sp` 를 이어서 맞췄다.
파일은 적용 후 지웠다. 빈 DB 는 7본만 깐다.

### 한 일

| # | 무엇 | 결과 |
|---|---|---|
| 1 | API·SP 이름 | `GET /sign-ready` · `GET /sign-ok` · `sp_sign_ready_r_000` · `sp_sign_ok_r_000` |
| 2 | REVIEW 잔재 | reviewer 컬럼 DROP, status DEFAULT `WRK`, 꺼 둔 REVIEW 단계 삭제 |
| 3 | FE 통일 | 전송/전송취소 = `DocumentApprovalToolbar`. `DocSectionHead`·`DocReasonBox`·`DocFileList`·`stepperTone` |
| 4 | 검색 | 결재 2화면 `keyword`/`writerId` 분리. `DOC_STATUS` 상수 |
| 5 | 앞 세션 미커밋 | 문서함 인쇄·도장·rhwp 0.8.4, 결재 사유 유지, 제목=양식명 — **이번 커밋에 포함** |

### 젠킨스 전에 할 것 / 안 할 것

1. **DB 는 다시 돌리지 않는다.** 운영·시험 이미 정본과 같다. `apply-all` 금지
2. `main` 머지 확인 후 Jenkins **`haccp-deploy` Build Now** 만 누른다
3. 배포 뒤 확인: 로그인 → 결재첨부 전송 → 결재대기 승인 → 문서함. 구 URL `/approval-inbox` 는 404 여야 한다
4. Docker API 이미지에 rhwp 0.8.4·noble 이 들어간다 — 이번 커밋에 Dockerfile 이 있다

### 안 한 것

- Jenkins Build Now — 사용자
- 오늘 할 일 E2E 3건·문서주기 삭제 1건은 시험 데이터(오늘 과제·주기 규칙 없음)라 이번 변경과 무관
- `scrnCd`·`persistId` 불변

---

## 0c. 앞 세션 — 결재 사유 유지 · 확인/닫기 · 첨부 한 스크롤 · 제목=양식명 (2026-09-03)

결재 취소/반려 팝업 푸터를 **확인 / 닫기**로 맞추고, 재전송(`REQUEST`) 후에도 취소 사유가 남게 했다.
결재대기·완료에도 사유 칸을 두었고, 결재첨부 우측은 스크롤 하나다.
이어서 **문서 제목은 양식명(템플릿)** 이고 작성 목록 `title` 은 식별용만이라는 규칙을 화면에 반영했다.
**이번 커밋에 포함.** 운영·시험 SP 는 이미 적용했다.

### 한 일

| # | 무엇 | 결과 |
|---|---|---|
| 1 | 사유 팝업 버튼 | `ReasonActionModal` `confirmLabel` 기본 `"확인"`. 취소·반려 제목은 `결재 취소` / `반려` 유지. 푸터는 확인·닫기 풀폭. 빈 사유면 막힘 |
| 2 | E2E | `flow-approval.spec.ts` · `scenario.spec.ts` 다이얼로그 안 버튼 `"반려"` → `"확인"`. 헤더 `btn("반려")` 는 그대로 |
| 3 | 재전송 후 취소 사유 | `sp_tbl_document_approval_c_000` `REQUEST` 는 `reject_reason` · `cancel_reason` 을 **비우지 않는다**. 정본 `01_sp.sql` 주석·PROCEDURE COMMENT. 로컬 PG 재적용함 |
| 4 | 결재대기·완료 사유 칸 | `DocumentBoxPage` 미리보기 아래 읽기 전용 textarea 두 칸 (반려 / 결재 취소). 값 있을 때만. 첨부의 `AttachReasonBox` 패턴 복제(공용 추출 안 함) |
| 5 | 결재첨부 한 스크롤 | 우측 `overflow-auto` 하나. 원본 파일 헤더는 고정/`shrink-0` 이 아니라 카드와 같은 흐름. 내리면 헤더도 같이 내려감. 칸 높이(`min-h-3`·`min-h-4`·원본 `min-h-10`)로 점프만 막음 |
| 6 | 문서 제목 ≠ 식별 제목 | 상세 `h2` 는 `tmplNm`(양식명). 작성 목록 `tbl_document.title` 은 언제·무엇을 썼는지 식별용. 지면은 `hdr-title`(템플릿) 그대로. 식별 제목을 바꿔도 지면 안 바뀜 |

### 손댄 곳 (대표)

- FE: `ReasonActionModal.tsx` · `DocumentApprovalToolbar.tsx` · `ApprovalAttachPage.tsx` · `DocumentBoxPage.tsx` · `htmlFormPaperShared.tsx` · `htmlFormDraftShared.ts` · `HtmlFormDraftPage.tsx` · `DocumentBoxRule.ts` · `ApprovalAttachRule.ts`
- FE README: `pages/flow/appr/attach/README.md` · `pages/flow/box/documentbox/README.md`
- E2E: `e2e/flow-approval.spec.ts` · `e2e/scenario.spec.ts`
- DB: `db_sasshaccp/01_sp.sql` `sp_tbl_document_approval_c_000` REQUEST 절

### 시험 DB에 이미 반영한 것

`sp_tbl_document_approval_c_000` — 로컬 PG에 `CREATE OR REPLACE` 해 두었다.
구버전이면 `REQUEST` 가 `cancel_reason = NULL` 이라 취소 → 반려 → 재전송 → 반려 뒤에 취소 사유가 사라진다.

### 이어받는 사람이 할 것

1. (닫힘) 운영·시험에 `01_sp` 를 적용했다 — 아래 0절
2. 흐름 한 번: 취소 → 반려 → 재전송 → 반려. 결재첨부·결재대기 상세에 취소 사유가 남아 있는지
3. 팝업: 취소/반려 모두 제목은 행위, 푸터는 확인·닫기. 빈 사유면 막힘
4. 결재첨부: 우측을 내리면 원본 파일 헤더도 같이 내려간다. 문서 전환 때 위쪽이 점프하지 않는지
5. 결재완료 상세 `h2` 가 `표준 복사 (2026-09-03)` 이 아니라 **양식명**(`표준 복사`)인지. 지면 머릿글은 템플릿(`일반위생관리 및 공정점검표`)인지

### 안 한 것 · 주의

- **이번 커밋에 포함**
- 전체 결재 흐름(취소→반려→재전송→반려)은 당시 목록이 APV 뿐이라 브라우저에서 끝까지 재현하지 못함. 팝업 확인/닫기·빈 사유 차단·첨부 한 스크롤·`h2`=양식명은 결재완료에서 확인함
- `npx tsc --noEmit` 통과
- `scrnCd` / `persistId` / HWP `HWP_SRC` 계약은 안 건드림
- 식별 제목 컬럼명 「제목」은 그대로. 목록에서만 보이고 지면·상세 `h2` 에 안 실린다

## 0b. 이 세션 — 문서함 인쇄 · HTML 도장 · rhwp 0.8.4 (2026-09-03)

문서함(`document-inbox`)에서 HTML A4 일괄 인쇄 + HWP PDF 인쇄를 붙였고,
미리보기·결재 스테퍼·지면 도장·인쇄 색을 고쳤다. 이어서 CLI를 편집기와 같은 **v0.8.4**로 맞췄다.
결재완료 HWP 인쇄가 「파일을 추가할 수 없습니다」로 죽던 것도 닫았다.
**이번 커밋에 포함.** 운영·시험 SP 는 이미 적용했다.

### 한 일

| # | 무엇 | 결과 |
|---|---|---|
| 1 | 문서함 체크박스 인쇄 | HTML은 `DocumentPrintLayer` A4 한 작업. HWP는 `printHwpDocuments` → `export-pdf` → iframe.print() 건별 |
| 2 | 미리보기 | 기본 펼침, 접기 토글, 하단 드래그 높이. HTML `variant="a4"` |
| 3 | 결재 스테퍼 | 이력 그리드 삭제 → `ApprovalLineSteps`. detail은 **날짜만** (`승인 · 2026-09-03`, 시각 없음) |
| 4 | HTML 도장 | 점검자 비면 작성자명 (`detailToDraftBuf` · `DraftPaperStamp`). 잠금 `SignSlot`은 서명 이미지가 있어도 **이름 항상 표시** |
| 5 | 인쇄 색 | 지면 input `disabled` → `readOnly`. 라디오는 readonly 가 없어 `paperRadioLock`(클릭만 막음). `global.css` 검정·opacity 1. `@media print` `print-color-adjust: exact` |
| 6 | rhwp CLI | FE `@rhwp/editor` 0.8.4 유지. `scripts/install_rhwp.sh` · `.env.docker.example` 기본 **v0.8.4**. 로컬 `tools/rhwp/rhwp.exe` · Docker 볼륨 `haccp-rhwp` 재설치 완료 |
| 7 | glibc | 리눅스 0.8.4는 **GLIBC 2.39**. API 실행 이미지 `eclipse-temurin:17-jre-noble`. jammy면 `--version` 실패. noble uid 1000은 `ubuntu` → `usermod -l haccp` |
| 8 | HWP 인쇄 잠금 | 문서함은 APV라 `sp_tbl_document_file_c_000`가 파일 추가를 막음. **PDF만** 잠금에서 뺌. 잠금이고 PDF가 있으면 변환 없이 재사용 |

### 손댄 곳 (대표)

- FE: `DocumentBoxPage.tsx` · `printHwpDocuments.ts` · `DocumentPrintLayer.tsx` · `htmlFormPaperShared.tsx` · `htmlFormDraftShared.ts` · `docDateTime.ts` · `global.css`
- BE: `DocumentService.exportPdf` · `DraftPaperStamp` · `RhwpCliClient` · `backend/haccp-api/Dockerfile`
- DB: `db_sasshaccp/01_sp.sql` `sp_tbl_document_file_c_000`
- 설치: `scripts/install_rhwp.sh` · `.env.docker.example` `RHWP_VERSION=v0.8.4`

### 시험 DB에 이미 반영한 것

`sp_tbl_document_file_c_000` — `sasshaccp_test`에 `CREATE OR REPLACE` 해 두었다.
PDF 완료본은 REQ/APV여도 INSERT 된다. 본문(`HWP_SRC`)·사용자첨부(`ATTACH`/`PHOTO`)는 그대로 막힌다.

### 이어받는 사람이 할 것

1. (닫힘) 운영 SP 적용·Docker 이미지는 Jenkins Build Now 가 한다
2. 문서함에서 **DB형 1건** 미리보기: 작성자·승인자·점검자 이름, 스테퍼에 시각 없는지, 글자 흐림 없는지
3. 문서함에서 **한글 1건** 인쇄: 예전에 뜨던 「결재 진행 중이거나 완료된 문서에는 파일을 추가할 수 없습니다」가 안 나와야 한다
4. Docker API로 HWP PDF를 쓰면 **noble 이미지 다시 빌드**. 안 하면 컨테이너 안 CLI가 glibc로 죽는다
5. 로컬: `tools/rhwp/rhwp.exe --version` → `rhwp v0.8.4`. `.env` `APP_RHWP_CLI_PATH` 비워도 `RhwpCliClient`가 exe·`/opt/rhwp/rhwp`를 찾는다

### 안 한 것 · 주의

- **이번 커밋에 포함.** `tools/rhwp` 는 gitignore
- 브라우저에서 그리드 행 클릭 자동화는 못 했다. 사람이 문서함에서 한 번 찍어 봐야 한다
- `npx tsc --noEmit`가 `ApprovalAttachPage.tsx` JSX 닫힘 오류를 냄 — **이번 diff와 무관**, 안 고침
- 인쇄할 때마다 PDF가 없을 때만 새로 남긴다. 잠금 문서에 이미 PDF가 있으면 그걸 찍는다 (본문은 안 바뀜)

## 0a. 이 세션 — HTML 고아 카탈로그 삭제 (2026-09-03)

버전 없는 HTML 사용양식을 지웠다. 버전 행을 만들어 붙이지 않았다.
시험 DB 8코드(과제 7·채번 6·사용양식 7·카탈로그 8). 라이브는 0건.
시드 `02_seed.sql` 21 INSERT 제거. 주기 목록 SP 는 HTML 에 사용 버전 있을 때만.
E2E 는 `liveHtmlChkTmpl()` — 고아 코드 하드코딩 안 함.
결정: [`docs/8_결정_이력.md`](docs/8_결정_이력.md) 「HTML 사용양식은 지면 버전이 있어야 한다」.
**이번 커밋에 포함.** 아래 검수 절은 그대로 둔다.

## 0d. 다른 세션 — CCP 작성 /forms 500 (2026-09-03)

PR #95 머지됨 (`6362c68`). 08 은 지운 채. Jenkins 는 안 눌렀다 — 이번 배포에 같이 탄다.

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
| 3 | 루트 나머지 9본 (`README`·`CLAUDE`·`AGENTS`·`DEPLOY`·`E2E`·`E2E_ERRORS`·`환경구축`·`운영`·`세션_인수인계`) | 5건 | 5건 결함 (4번은 `:8` 만) | 5건 |
| 4 | `frontend/` README 67본 + `PIPELINE.md` | 5건 | 5건 전부 결함 | 5건 + 파생 6본 |

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

### R3 반영 내역 (루트 9본)

| # | 무엇 | 어떻게 |
|---|---|---|
| 1 | `운영.md`·`환경구축.md` 가 **없는 DB migrate 스테이지**를 파이프라인 정본으로 적음 | 도식·표에서 `DB migrate dry-run`·`Prod DB migrate` 삭제. `Jenkinsfile` 은 7스테이지고 DB 를 안 건드린다. compose `migrate` 프로필·`db_migrate_dryrun.sh` 는 **설비는 있으나 수동 전용**임을 §4.1 에 명시 |
| 2 | `DEPLOY.md` 는 §6 까지인데 세 문서가 **§8~§14 를 정본으로 지목** (삭제된 `docs/20_배포_런북.md` 의 절 번호) | 8곳을 실제 파일·절로 재지정 — 볼륨·compose→`docker-compose.prod.yml`, Credentials→`운영.md` §2.1, 롤백→`DEPLOY.md` §5, webhook→`환경구축.md` §11.6. 갈 곳 없는 참조는 삭제 |
| 3 | `환경구축.md` 로컬 URL 이 `/haccp/` 접두 누락 | `http://localhost:4173/haccp/login` 로 3곳. **`/login` 은 302 가 아니라 404 다** (`baseMiddleware` — 루트만 302) |
| 4 | `세션_인수인계.md`:8 `main` 이 `dbc53c1`(#93) 인데 실제는 `c8c4b15`(#94) | 갱신. `:10` 「작업 트리 깨끗」은 인수인계 시점 서술이라 **결함 아님** |
| 5 | `운영.md` nightly 감시 표가 4본인데 `Jenkinsfile.audit` 는 5본을 돈다 | `audit_generated_docs.sh` 행 추가 (생성기 5본 drift). `환경구축.md`:319 도 같이 |

`scripts/README.md`:12·15·16 의 `런북 §9·§10·§11` 도 같은 유령 참조라 같이 닫았다 (md 라서).
**소스 주석에 남은 것은 안 고쳤다** — 아래 C6.

### R4 반영 내역 (프론트 README)

`pages/docs/README.md` 가 **없는 폴더 6개·없는 화면 5종**을 적고 있었다.
앞머리 체인표는 맞고 트리 세 곳만 낡은 것이라 그 줄만 갈았다.

| # | 무엇 | 어떻게 |
|---|---|---|
| 1 | `pages/docs/README.md`:37-51 FE 트리에 `html/`·`ccp/`·`prp/`·`logis/`·`admin/`·`html/hygprocess` | 실물 `hwp/`·`html-form/`(+하위 5)·`sch/` 로 교체. **작성 화면은 `pages/draft/`** 임을 명시 |
| 2 | 같은 파일 BE 트리가 `docs/html/…`·`docs/document/`·`docs/template/`, 「법적서류」 화면 `legal-document-upload` | `htmlform/…`·`documents/`·`templates/` 로. 법적서류 행·절 삭제 (저장소 전체에서 그 README 한 줄에만 있던 유령) |
| 3 | `html-form/README.md`:12 `hygprocess` / `hygiene-process-check` | 행 삭제 · 제목 `# pages/docs/html` → `html-form` · 작성은 `pages/draft/html/` 임을 명시 |
| 4 | `PIPELINE.md`:149 가 없는 `09-frontend-conventions.mdc` 지목 | `09-haccp-frontend.mdc` |
| 5 | `components/form/README.md` 표에 `DocCell.tsx`·`DocDeviationFooter.tsx` 누락 | 두 줄 추가. `DocDeviationFooter` 는 **컴포넌트를 쓰는 곳이 없고 타입만 5곳이 import** 한다고 명시 |

**파생 6본** — 같은 유령이 백엔드 README 에도 있어 같이 닫았다:
`com/haccp/docs/README.md`(트리·없는 URL `/api/v1/docs/prp/hygiene-process-check`) ·
`docs/htmlform/README.md` · `mapper/docs/README.md`(트리 통째) ·
`mapper/docs/htmlform/README.md` · `html-form/htmltemplate/README.md`.

`api/docs/README.md`:24 의 `hygiene-process-check` 는 "삭제된 화면" 이라는 **과거 기록이라 뒀다**.

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

| C6 | `Jenkinsfile`:174 · `scripts/{audit_docs_links,audit_file_size_alignment,audit_ops_delete,gen_selfsigned,init_volumes,install_rhwp,prod_smoke}.sh` 머리주석 | **삭제된 런북(`docs/20_배포_런북.md`)의 절 번호 `§9·§10·§11·§15·§19`** 를 8곳이 아직 호출처로 적는다. 문서 쪽은 전부 재지정했다 | 보고만 |

3단계에서 C4·C5·C6 를 포함해 한 번에 낸다.

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
