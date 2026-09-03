# handoff — 지금 무엇을 하고 있나

> 갱신: 2026-09-03 · **메시지마다 갱신한다.** 컨텍스트를 꺼도 이 파일만 읽으면 이어간다.
> 정본이 아니다 — 규칙은 `.cursor/rules/`, 무엇이 어디 있나는 [`INDEX.md`](INDEX.md),
> 프로젝트 상태는 [`세션_인수인계.md`](세션_인수인계.md). 여기는 **이번 작업의 진행 상태**만 담는다.

---

## 1. 지금 하는 일

**기본은 검수는 md 만, 코드는 보고만.** 2026-09-03 에 확정했다 —
한쪽 세션이 검수 중 코드까지 고쳐서 작업 트리가 섞인 뒤에 갈래를 닫았다.
정본: [`docs/8_결정_이력.md`](docs/8_결정_이력.md) · `.claude/commands/doc-audit.md`.

| 단계 | 무엇 | 고치나 | 상태 |
|---|---|---|---|
| 0 | 세팅 — `handoff.md`·`INDEX.md`·생성기·메모리 | 만든다 | **끝** |
| 1 | 지정된 md 전부 검수 (라운드 최대 30) | **문서만 고친다** | 진행 중 |
| 2 | 프론트·백엔드 코드가 규칙에 맞는가 | **안 고친다.** 수정대상·크리티컬 오류만 지정 | 대기 |
| 3 | 소스 주석 계획을 이 파일에 적는다 | 계획만 | 대기 |
| 4 | 다른 에이전트가 이 파일을 읽고 수정 | 그쪽이 고친다 — **별도 지시·별도 커밋** | 대기 |

코드 패치는 4단계이고, 사용자가 보고를 본 뒤에 따로 시킨다. 검수 루프 안에서 승인·진행으로 코드를 열지 않는다.

---

## 2. 검수 방식 (Red Team–Blue Team)

서브 둘, 메인 하나. 정의는 `.claude/agents/`, 절차는 `.claude/commands/doc-audit.md`.

| 역 | 누구 | 권한 |
|---|---|---|
| Critic | `doc-critic` | 읽기만 (`Read`·`Grep`·`Glob`). 결함 후보만 |
| Defender | `doc-defender` | 읽기만. 저장소 실물 근거만 |
| Supervisor | 메인 | 판정·수정·정리 |

판정 어휘 넷: `결함` · `결함 아님` · `재확인 대기` · `단정 불가`.
근거는 `파일:줄` 또는 함수·SP 이름이다. 없으면 `단정 불가`이고 문서를 안 고친다.

종료조건: ① Critic 이 `결함 없음` ② 의미 변경 없음 ③ 같은 이슈 2회 핑퐁 ④ 30라운드.

---

## 3. 1차 검수 (규칙 체인) — 끝

**R1~R11, 41건 전부 결함, 기각 0.** 대상은 `.cursor/rules/` 13본 + 진입점.

굵직한 것만:

| 무엇 | 어떻게 닫았나 |
|---|---|
| `apply-all.sh` 가 빈 DB 전용인데 6곳이 새 업체를 그걸로 열라고 했다 | 업체분 4본(03·05·06·07) 직접 실행으로 교체 |
| `DEPLOY.md` 에 external 볼륨 3개 생성 선행이 없었다 | §1-4 추가 + `install_rhwp.sh` 명시 |
| 서버 `docker compose` 에 `-f`·`--env-file` 누락 | 8곳 정정 |
| E2E 앞 `npm run preview` 선행 없음 | 10곳 추가 |
| `doc_kind` 를 "소문자 정본" 이라 못박음 (실물 전부 대문자) | 뒤집음 |
| 배포 경로 `/opt/haccp` (root 소유라 실제로 막힌다) | 호스트 경로 전부 `/home/ubuntu/haccp` |
| 삭제된 문서를 정본으로 가리키는 죽은 링크 | 57개 파일 재지정 |
| 문서에 박힌 숫자 (SP·컬럼·양식·본수·E2E 건수) | 실물값 또는 세는 명령으로 교체 |

**반전 하나:** `nonwork_rule` 은 저장이 소문자다(`01_sp.sql` 의 `lower()`).
공통코드 `sub_cd` 만 대문자고 FE·Java 가 비교 전에 올려서 붙는다 —
"`sub_cd` = 저장값" 규칙이 깨진 유일한 칸이라 어느 쪽도 혼자 고치지 않는다.

---

## 4. 2차 검수 (지정 md 전부) — 진행 중

대상 (추적 md 183본 중 아래):

- `docs/` 11본 (`1_`~`10_` + `README.md`)
- 루트 15본 — `README`·`CLAUDE`·`AGENTS`·`DEPLOY`·`E2E`·`E2E_ERRORS`·`개발`·`깃`·
  `환경구축`·`운영`·`세션_인수인계`·`사용자_매뉴얼`·`배포후_개선점`·`배포전_최종검증_계획`·`배포전_최종검증_결과`
- `frontend/` 폴더 README 67본 · `backend/` 폴더 README 101본
- `.cursor/` (1차에서 끝)

### 라운드 기록

| R | A 지적 | B 판정 | 반영 |
|---|---|---|---|
| — | (아직 없음) | | |

---

## 5. 지금까지 확인된 것 — 아직 안 고친 것

### 루트 이물질

- `metis` 는 **잔재가 아니다.** 코드·설정에 0건이고, md 6곳은 "MES 와 별개다" 라는
  경계 선언이다. 지우면 그 가드가 사라진다 — **안 지운다**
- `grokbot/`(96M) · `.tools/` · `.playwright-mcp/` · `test-results/` 는 전부 gitignore.
  저장소에는 안 들어간다. 로컬 디스크만 먹는다
- 추적 `.class` 0건 · 추적 md 183본

### README 없는 소스 폴더 13개

`INDEX.md` 「README 없는 폴더」 절이 정본이다. 대부분 `src/test/java/**` 시험 패키지이고,
`tools/`(E2E 가 실제로 쓰는 8본)만 성격이 다르다.

---

## 6. 만든 것

| 파일 | 무엇 |
|---|---|
| `handoff.md` | 이 파일. 매 메시지 갱신 |
| `INDEX.md` | 폴더 목차 — **생성기가 만든다** |
| `scripts/gen_index.mjs` | 그 생성기. `--check` 로 CI 에 붙는다 |
| `.claude/agents/doc-critic.md` · `doc-defender.md` | 검수 서브에이전트 (읽기 전용) |
| `.claude/commands/doc-audit.md` | `/doc-audit <문서경로>` 루프 절차 |
| `.claude/README.md` | 그 폴더가 무엇을 맡나 |

`scripts/audit_generated_docs.sh` 에 `gen_index` 를 붙였다 — 생성 문서가 이제 5본이다.

---

## 7. 이어받는 사람이 먼저 할 것

```sh
# 지금 상태 확인 — 넷 다 OK 여야 한다
bash scripts/audit_docs_links.sh
bash scripts/audit_generated_docs.sh
bash scripts/audit_version_drift.sh
bash scripts/audit_ops_delete.sh
```

- 검수 기본은 **md 만**. 코드·생성기는 이 루프에서 안 돌린다
- `docs/5_PIPELINE_색인.md`·`docs/9_SP_색인.md` 는 HtmlDraftMapper 통합(세션 전부터
  있던 미커밋)에 맞춰 다시 뽑힌 상태다. **그 코드와 같이 둔다.** 검수 커밋에 넣으면
  소스 없이 색인만 올라가 `audit_generated_docs` 가 깨진다
- HtmlDraft 통합·FE 작성 화면·E2E 스펙은 세션 전 변경이라 검수 커밋에 안 넣는다
