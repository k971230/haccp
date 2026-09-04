# plan — 코드 수정 계획 (2026-09-03)

> 검수(문서 10라운드 · 코드 2라운드)와 **라스트 현장 라운드**(2026-09-03~04)에서
> 확정한 결함을 고치는 계획이다.
> **이 문서는 계획만 담는다.** 고치는 것은 다른 세션이 한다.
> 결함 목록과 근거는 [`handoff.md`](handoff.md) 「코드검토 R1·R2」 절 ·
> `grokbot/test/따까리_메뉴얼검증/12_라스트판정.md` — **저장소 밖이다**(`.gitignore:82` `grokbot/`).
> 새로 받은 사람은 그 파일이 없다. 이 계획 본문이 근거를 다 담고 있다.
>
> **P0 넷 중 둘(K8·K9)은 현장에서 실제로 일어났다** — 내용 없는 HACCP 기록이 결재까지 통과했다.

층이 넷이다 — DB 구조(`db_sasshaccp/00_ddl.sql`) · SP(`01_sp.sql`) ·
백엔드(`backend/haccp-api`) · 프론트(`frontend/haccp-web`).

---

## 0. 먼저 정하고 가는 것

### 0-1. 1회성 마이그레이션 번호는 `10` 이다

`08`·`09` 는 이미 쓰고 지웠다 (`08_rename_tml_html` · `08_remove_review` · `09_rename_appr`).
`07-haccp-db.mdc` 가 **기존 번호 재사용을 금지**하므로 다음은 `10_` 이다.

`apply-all.sh` 에 넣지 않는다. 빈 DB 는 `00`+`01` 이 처음부터 고쳐진 상태로 깔린다.

### 0-2. 정본과 라이브를 같이 고친다

| 대상 | 어떻게 |
|---|---|
| 빈 DB | `00_ddl.sql`·`01_sp.sql` 을 고쳐 두면 끝 |
| 라이브 `sasshaccp` · 시험 `sasshaccp_test` | `10_*.sql` 로 데이터 정리 + `01_sp.sql` 의 해당 SP 만 `CREATE OR REPLACE` |

**반환 타입이 바뀌는 SP 는 `DROP` 후 `CREATE`** 다. 이번 계획의 신설은 **K1 의 `sp_tbl_corrective_action_delete_blocker_r_000` 하나**다
(P3 의 `sp_tbl_company_r_000` 은 별건). 나머지는 본문만 바뀌어 `CREATE OR REPLACE` 로 충분하다.

### 0-3. 커밋을 나눈다

한 커밋 = 한 결함. 되돌릴 때 갈라진다.
K1 은 **DB+BE 두 층**을 한 커밋에 넣는다 — FE 는 이미 `validate-delete` 를 부르고 있어 안 바뀐다.

---

## 1. P0 — 먼저 고친다

### K5. HWP 저장이 편집기에 떠 있는 내용을 그대로 올린다

**층: FE 만.** DB·BE 안 건드린다.

**`docIdx` 단독 대조는 안 된다.** 신규 행은 `hwpOpenMode(null, false)` → `template` 로 열려
편집기가 아는 `docIdx` 가 `null` 인데, 저장은 서버가 방금 발급한 새 idx 로 `afterSave(saved)` 를 부른다.
`openedDocIdx !== docIdx` 로 막으면 **모든 HWP 문서의 첫 저장에서 본문이 안 올라간다** — 지금보다 나쁘다.

**대조하는 것은 `mode` 다. 그리고 `mode` 는 「읽기 성공」에만 열린다.**

`template` 을 그냥 통과시키면 **로드 중(in-flight) 창**이 남는다 — 행 A(신규)를 열어 두고
행 B(신규)를 클릭하면 로드가 끝날 때까지 편집기에는 A 가 있고, 그때 저장하면 A 가 B 로 올라간다.
그래서 **효과 진입 직후·로드 시작 전에 `wait` 로 잠그고, 성공했을 때만 푼다.**

| 파일 | 무엇 |
|---|---|
| `HwpEditorPane.tsx` | ① 효과 진입 직후 **로드 전에** `onOpened("wait", docIdx)` — 차단 상태로 시작<br>② 성공했을 때만 `onOpened("source"\|"template", …)` 로 푼다. 통지 위치는 `loadFile` 직후가 아니라 **`onCleanRef.current?.()` 옆** — 그 앞에는 표식이 바뀌면 **재귀 로드**하는 자리가 있어, 거기서 통지하면 방금 버린 문서를 「열렸다」고 올린다<br>③ `onOpened` 는 `onDirtyRef`·`onCleanRef` 와 같이 **ref 에 담는다.** 인라인 화살표로 넘기면 부모가 리렌더할 때마다 효과가 다시 돌아 **사용자가 쓰던 내용을 날린다** |
| `HwpDraftPage.tsx` | `openedRef` **초기값은 `{ mode: "wait", docIdx: null }`**. 편집기가 준비되기 전(`!ready \|\| !editor \|\| !tmplCd`)에는 통지가 없어서, 초기값이 `template` 이면 빈 파일이 올라간다<br>`uploadBody` 첫 줄에 두 줄 — `if (openedRef.current.mode === "wait") return;` · `if (openedRef.current.mode === "source" && openedRef.current.docIdx !== docIdx) return;` |
| 같은 파일 | 가드에 걸려 `return` 하면 **사용자는 저장된 줄 안다** — `runSaveDetail` 이 `true` 를 돌려주고 `clearBodyDirty()` 까지 한다. `mesToast("이 문서는 편집기에 열려 있지 않습니다. 문서를 다시 연 뒤 저장하세요.", "warn")` 를 같이 넣는다 |

**왜 `mode` 인가:** `wait` 는 「이 문서는 idx 가 있는데 본문 파일이 없고, 편집기가 이 문서를 위해
아무것도 안 읽었다」는 뜻이다. 그 상태의 편집기 내용은 **정의상 남의 것**이다.
`template`(신규 첫 저장)은 통과시켜야 하고, `source`(기존 덮어쓰기)만 idx 를 대조한다.

**이 파일에 이미 같은 계열 사고 주석이 있다** — `HtmlFormDraftPage.tsx`:565-569
「모든 행에 걸면 그 하나의 본문이 저장된 문서 전부에 붙는다」. 그때는 `isOpenRow` 로 막았고,
남은 구멍이 **열린 행인데 편집기가 그 행을 못 읽은 경우**다. 이번 수정이 그 구멍을 닫는다.

**안 하는 것:** `selecting` 잠금을 HWP 경로까지 넓히지 않는다. 잠금은 UX 를 막는 것이고
이 결함은 저장 로직이라 층이 다르다. 잠금으로 막으면 다른 경로가 열리면 또 샌다.

**시험:** `e2e/draft-all.spec.ts` 에 한 건 —
행 2개 추가 → 좌측 저장 → 비활성 행 클릭 → **상태 줄이 `문서를 여는 중입니다…` 인 것을 먼저 단언** →
저장 → 그 행의 `HWP_SRC` 가 없거나 자기 것인지 DB 로 판정.

**상태 단언을 빼면 시험이 우연히 초록일 수 있다** — `wait` 에 멈춘 것을 확정해야 판정이 선다.
지금 코드에서는 앞 문서 바이트가 들어가므로 시험이 먼저 빨개져야 한다.

### K5-b. 완료된 개선조치가 저장 한 번에 물리 삭제된다

**층: SP 만.**

**DELETE 만 막으면 목적이 안 선다.** 같은 SP 의 UPDATE 가 `status` 를 조건 없이 덮는다 —
`status = CASE WHEN TRIM(v_act) = '' THEN 'OPEN' ELSE 'ING' END`.
푸터를 비우지 않고 **원문서를 다시 저장만 해도 `DONE` 이 풀린다.** 두 자리를 같이 막는다.

| 파일 | 무엇 |
|---|---|
| `01_sp.sql` `sp_tbl_doc_corrective_u_000` DELETE 절 | `AND status <> 'DONE'` |
| 같은 SP **UPDATE 절 전체** | `AND status <> 'DONE'` |
| `db_sasshaccp/10_fix_ca_guard.sql` | 라이브·시험에 그 SP 만 `CREATE OR REPLACE` |

**`status` 만 `CASE` 로 막으면 부족하다.** UPDATE 는 `action_desc`·`action_user_nm`·
`confirm_user_nm`·`occur_dt` 까지 조건 없이 덮는다 — 상태만 `DONE` 으로 남고 조치 내용이 비는
행이 생긴다. 「물리 삭제」가 「내용 삭제」로 바뀔 뿐이다. **UPDATE 문 전체를 막는다.**

**왜:** 형제 `sp_tbl_corrective_action_d_000` 이 이미 `status <> 'DONE'` 가드를 쓴다. 기준을 맞춘다.
완료 지정·해제 정상 경로는 개선조치 화면 → `sp_tbl_corrective_action_c_000` 이라 **안 막힌다.**

### 갈림 — `45000` 으로 막지 않는다 (권고를 뒤집었다)

처음에는 「막고 문구를 준다」를 권했으나 **그러면 안 된다.**
`_u_000` 은 삭제 버튼이 아니라 **문서 저장 트랜잭션 안**에서 불린다
(`HtmlDraftService.save` `@Transactional` → `saveAutoIfNg` → `DocCorrectiveSupport.upsertByDoc`).
여기서 `RAISE 45000` 이면 **문서 헤더·항목·서명 저장까지 통째로 롤백**된다 —
완료된 개선조치가 달린 문서는 푸터가 빈 순간부터 **본문 수정이 영영 안 된다.**

**정한 것:** SP 는 **조용히 보존**한다(위 가드). 알리는 것은 **화면 몫**이다 —
푸터를 비우고 저장하려 할 때 FE 가 먼저 「완료된 개선조치가 있어 이탈을 지울 수 없습니다」를 띄운다.
HWP 경로는 `HwpDraftService.applyDeviation` 이 이미 한 겹 막고 있어 이 사고는 **HTML·CCP 화면**에서 난다.

**시험:** 이탈 적고 저장 → 개선조치를 완료로 → 원문서 푸터 비우고 저장 →
`tbl_corrective_action` 행이 **남아 있는지** DB 로 판정.

### K8. 본문 없는 HWP 문서가 전송·승인된다

**층: FE + SP.** **K5 와 같은 커밋**이다 — K5 만 넣으면 결함이 옮겨갈 뿐이다.

지금 계약이 실패를 위로 못 올린다. `afterSave?: (docIdx) => Promise<void>`
(`HtmlFormDraftPage.tsx`:144) 라 `uploadBody` 가 무엇을 하든 :689-691 이 `return true` 를 준다.
전송 검사는 `htmlFormDraftShared.ts`:356 `if (!itemPaper) return null` 로 HWP 는 **일자 8자리만** 본다.
BE(`DocumentService.processApproval`:437-451)·SP 에도 검사가 없다.
그래서 `HwpDraftPage.tsx`:98 `if (!editor) return;` 이면 본문이 아예 안 올라가는데 저장은 성공으로 보고된다.

| 파일 | 무엇 |
|---|---|
| `HtmlFormDraftPage.tsx`:144 | `afterSave?: (docIdx) => Promise<boolean>` 로 올린다 |
| 같은 파일 :689-691 | `const ok = afterSave ? await afterSave(b.docIdx) : true;` — `ok` 를 그대로 돌려주고 `clearBodyDirty` 는 `ok` 일 때만 |
| 같은 파일 :570 | 좌측 저장 분기도 같은 처리 |
| `HwpDraftPage.tsx` `uploadBody` | `Promise<boolean>` — 가드에 걸리면 `false`, 올렸으면 `true` |
| `01_sp.sql` `sp_tbl_document_approval_c_000` REQUEST 분기 | 아래 가드 |

REQUEST 분기 맨 앞, 결재선 스냅샷 전에 넣는다.

```sql
IF (SELECT doc_kind FROM tbl_document WHERE idx = p_doc_idx AND co_cd = p_co_cd) = 'HWP'
   AND NOT EXISTS (
       SELECT 1 FROM tbl_document_file
        WHERE co_cd = p_co_cd AND doc_idx = p_doc_idx
          AND upper(file_kind) = 'HWP_SRC'
   ) THEN
    RAISE EXCEPTION '본문이 저장되지 않았습니다. 편집기에서 문서를 열고 저장한 뒤 전송하세요.'
        USING ERRCODE = '45000';
END IF;
```

**여기서는 `45000` 을 던져도 된다 — K5-b 와 반대다.** `processApproval` 은 자기 `@Transactional` 이고
문서 저장 트랜잭션 **안이 아니다** (`DocumentService.java`:430). 롤백해도 문서가 잠기지 않는다.
`tbl_document_file` 에는 `del_yn` 이 없어(물리 삭제) `EXISTS` 한 줄로 끝난다.

**왜 SP 인가:** REQUEST 는 작성 6화면·결재첨부가 전부 여기로 모인다. 화면마다 걸면 새 화면이 또 샌다.
FE 의 boolean 은 **저장이 안 됐다는 것을 그 자리에서** 알리는 몫이고, SP 가 마지막 문이다.

**시험:** ① `uploadBody` 가 `false` 면 `runSaveDetail` 이 `false` 인지 단위
② HWP 행 저장 → `tbl_document_file` 에서 `HWP_SRC` 를 지우고 전송 → `45000` 인지 DB 로 판정

### K9. 부적합인데 이탈내용이 공란인 채 승인된다

**층: FE 만.**

`DocCorrectiveSupport.java`:91 이 자동문구를 넣고, `htmlFormDraftShared.ts`:50-56 `paperNote()` 가
지면에서 그 문구를 **빈칸으로 그린다.** 공란 처리 자체는 의도다 — 자동문구를 사람 글로 보이게 하지 않는다.
빠진 것은 그다음이다. **자동문구인 채로 전송을 막는 자리가 없다** (`firstInvalidTarget`:354-377).
승인된 기록의 `deviation_desc` 는 시스템 문구, `action_desc` 는 NULL, 지면은 체크만 켜지고 내용은 빈칸이다.

| 파일 | 무엇 |
|---|---|
| `htmlFormDraftShared.ts` `firstInvalidTarget` | 판정 `F` 가 하나라도 있고 이탈내용이 비었거나 `AUTO_DEVIATION_DESC` 면 `TransferBlock` 을 돌려준다 |
| 같은 파일 | 문구는 「부적합이 있습니다. 이탈내용을 입력하세요.」 |

**BE 에는 안 건다.** 자동문구는 BE 가 **일부러** 넣는 것이라 BE 에서 막으면 자기가 만든 값을 자기가 거절한다.
막을 자리는 사람이 채울 수 있는 화면이다.

**안 하는 것:** 조치내용(`actionDesc`)까지 필수로 올리지 않는다. 조치는 나중에 하는 것이고
`status='OPEN'` 으로 개선조치 화면이 이어받는다. **이탈내용만** 막는다.

**시험:** `e2e/draft-all.spec.ts` — CCP 한 행을 부적합으로 찍고 특이사항을 비운 채 전송 → 토스트로 막히는지

---

## 2. P1

### K6. 개선조치 번호를 `count(*)+1` 로 채번한다

**층: SP.**

`ca_no` 형식은 `CA-YYYYMMDD-NNN` (15자) — **연번은 13번째부터** 세 자리다. 확인함.

| 파일 | 무엇 |
|---|---|
| `01_sp.sql` `sp_tbl_doc_corrective_u_000` | `count(*)+1` → 같은 `occur_dt` 안의 **최대 연번 +1** |
| `01_sp.sql` `sp_tbl_corrective_action_c_000` | 접두를 `current_date` → `p_payload->>'occurDt'` 로. **카운트 기준과 맞춘다** |
| `10_*.sql` | 두 SP `CREATE OR REPLACE` |

두 SP 모두 `lpad((SELECT (count(*)+1)::text FROM …), 3, '0')` 자리를 이렇게 바꾼다.

```sql
lpad((
    SELECT (COALESCE(MAX(substring(ca_no FROM 13)::int), 0) + 1)::text
      FROM tbl_corrective_action
     WHERE co_cd = p_co_cd AND occur_dt = <접두와 같은 값>
), 3, '0')
```

**서브쿼리에 형식 필터를 같이 건다** — `AND ca_no ~ '^CA-[0-9]{8}-[0-9]{3}$'`.
형식이 다른 legacy 행이 하나라도 있으면 `substring(...)::int` 가 **`22P02` 로 저장을 통째로 죽인다.**

**`_c_000` 접두를 바꾸면 `ca_no` 의 날짜 뜻이 바뀐다** — 발급일이 아니라 **발생일**이 된다.
이미 발급된 번호는 안 바꾸므로 한 표에 두 규칙이 섞인다. 채번은 `occur_dt` 로 묶어 세니 충돌은 없지만,
**`ca_no` 의 날짜가 발생일이라는 것**을 `사용자_매뉴얼.md` 와 SP 주석에 한 문장으로 못박는다.
(`_u_000` 은 이미 `p_base_dt` 접두라 발생일 기준이다 — 그쪽에 맞추는 것이다.)

`_u_000` 은 접두·카운트가 이미 `COALESCE(NULLIF(p_base_dt,''), current_date)` 로 **서로 일치**한다 —
채번식만 바꾸면 된다. `_c_000` 은 접두(`current_date`)와 카운트(`occur_dt`)가 **어긋나 있어**
접두도 같이 고쳐야 한다. 안 고치면 삭제가 없어도 충돌한다.

**골드:** 같은 파일 `sp_tbl_doc_no_gen_c_000` — 채번 표 + `pg_advisory_xact_lock`(회사·템플릿 조합 단위).
**다만 `ca_no` 에 채번 표를 새로 만들지는 않는다.** `max+1` 로 충분하고 표가 하나 늘면
`06_company_seed`·`INDEX` 까지 따라 움직인다. 동시 저장 충돌이 실제로 관측되면 그때 표로 올린다.

**안 하는 것:** `_c_000` 의 INSERT 분기는 화면에서 도달 불가지만 **그대로 둔다.**
REST 로 열리는 경로라 접두만 맞추면 충돌이 사라진다.

### K7. HWP 본문 덮어쓸 때 옛 실물을 먼저 지운다

**층: BE 만.**

**호출을 insert 뒤로 옮기면 안 된다.** `deleteFilesByKind` → `sp_tbl_document_file_d_001` 은
`doc_idx + file_kind` **전건 DELETE** 다 — 뒤로 옮기면 방금 넣은 새 행까지 지운다.

**고칠 것은 순서가 아니라 실물 삭제 시점 하나뿐이다. BE 만, DB 안 건드린다.**

| 파일 | 무엇 |
|---|---|
| `DocumentService.replaceExistingHwpSrc` | 옛 경로 `List<String>` 를 **반환**하게 바꾼다. 메타 DELETE 는 지금 자리 그대로, `storage.delete` 루프는 여기서 뺀다 |
| `DocumentService.upload` | `String path = storage.save(...)` 뒤에 `oldPaths.stream().filter(p -> !p.equals(path))` 만 `afterCommit` 에 등록한다 |

**등록 지점이 `upload` 로 올라가야 한다.** `replaceExistingHwpSrc` 안에서는 새 경로를 몰라
아래 필터를 쓸 수 없다.

**왜 필터가 필요한가 — 계획 1차가 놓친 자리다.** `storeWithSeq` 는 `REPLACE_EXISTING` 없이
`Files.copy` 하고 충돌하면 연번을 올린다. 옛 파일이 디스크에 남아 있으면 새 저장이 `_002` 로 밀려
경로가 안 겹치지만, **메타는 있는데 실물이 이미 없는 행**(앞선 실패·운영 정리의 잔재)이면
새 저장이 같은 `_001` 을 집는다 — 그때 `afterCommit` 이 **방금 올린 본문을 지운다.**

이렇게 하면 두 경우가 다 맞는다.

| | 메타 | 실물 |
|---|---|---|
| 성공 | 새 행으로 교체 | `afterCommit` 이 옛 파일 삭제 |
| 실패(롤백) | 옛 행 되살아남 | **안 지워짐** — `afterCommit` 이 안 돈다 |

**왜:** 메타는 트랜잭션이 되돌리는데 `Files.deleteIfExists` 는 안 되돌린다.
되돌림 단위가 다른 둘을 한 트랜잭션에 섞은 게 뿌리다.

**주의:** 새 파일만 지우는 롤백 블록은 **그대로 둔다.** 그건 옳다.

**`catch (RuntimeException ignored)` 는 유지한다.** `afterCommit` 에서 던지면 **이미 커밋된 업로드가
HTTP 오류로 보인다.** 주석을 「afterCommit 이라 더더욱 삼킨다」로 보강한다.

**시험:** 단위 둘. E2E 는 안 만든다.
① `storage.save` 를 던지게 스텁 → 옛 파일이 남는지
② **옛 경로 == 새 경로면 삭제하지 않는지** — 위 필터가 빠지면 이 시험만 빨개진다

### K10. 개선조치 「조치자」가 저장되지 않는데 성공 토스트가 뜬다

**층: FE + SP.** `10_*.sql` 에 K5-b·K6 와 같이 담는다.

컬럼(`tbl_corrective_action.action_user_nm`)도 있고 읽기 SP(`sp_tbl_corrective_action_r_000`:2890·2900)도
내려주고 그리드도 `editable:true` 인데(`CorrectiveActionManagementRule.ts`:78) **쓰기 두 층이 같이 빠졌다.**
**형제 SP `sp_tbl_doc_corrective_u_000`:3013·3028 은 쓴다** — 그래서 원문서 푸터로 고치면 남고
개선조치 화면으로 고치면 사라진다. 그런데 토스트는 「저장했습니다」다 (`…Page.tsx`:166).

| 파일 | 무엇 |
|---|---|
| `CorrectiveActionManagementPage.tsx`:154-164 | payload 에 `actionUserNm: row.actionUserNm` 한 줄 |
| `01_sp.sql` `sp_tbl_corrective_action_c_000` INSERT | 컬럼·값에 `action_user_nm` / `NULLIF(p_payload->>'actionUserNm','')` |
| 같은 SP UPDATE | `action_user_nm = NULLIF(p_payload->>'actionUserNm','')` |

**한쪽만 고치면 여전히 안 남는다.** 두 층이 한 커밋이다.
**`confirm_user_nm` 은 안 건드린다** — 그 칸은 화면에 없다. 열을 안 낸 것과 못 쓰는 것은 다르다.

**시험:** 단위 하나 — payload 에 `actionUserNm` 이 실리는지. DB 판정은 E2E 로 조치자 입력 → 재조회.

### K11. 잠긴 계정을 화면에서 풀 수 없다

**층: FE 만.** DB·SP·BE 는 이미 열려 있다.

`01_sp.sql`:6556 이 실패 임계에서 `lock_yn='Y'` 로 잠그고 `AuthService.java`:182 가 로그인을 거절한다.
푸는 길도 이미 있다 — `sp_user_management_c_000`:6682-6684 는 `p_lock_yn='N'` 이면
`login_fail_cnt` 까지 0 으로 되돌리고 `UserService.java`:111 이 값을 그대로 넘긴다.
막고 있는 것은 `UserManagementRule.ts`:41 하나다.

| 파일 | 무엇 |
|---|---|
| `UserManagementRule.ts`:41 | `NON_EDITABLE_FIELDS` 에서 `lockYn` 을 **뺀다** |
| 같은 파일 `buildUserColumns` | 「잠금」 열 하나 — `type:"code"` Y/N, `editable` |

**잠그는 방향도 같이 열린다.** 그것이 맞다 — `AuthService.java`:182 가 「관리자 해제 전까지」라고 적었고,
해제가 관리자 몫이면 설정도 관리자 몫이다.

**지금 유일한 해제 수단은 DB 직접 SQL 이다** (`운영.md`). 현장에서 계정이 잠기면 개발자를 부른다.

**시험:** 단위 하나 — payload 에 `lockYn` 이 남는지.

### K12. 결재 상세 적재에 경합 가드가 없어 오승인 창이 열린다

**층: FE 만.**

`DocumentBoxPage.tsx`:221-229 `loadDetail` 은 `setSelected`·`setListActiveKey` 를 **동기**로 바꾸고
`getDocumentDetail` 만 `await` 한다. 그 사이 **좌측 강조는 새 행, 우측 본문·툴바(:508)는 옛 문서**다.
그 창에서 승인을 누르면 옛 문서가 승인된다.

| 파일 | 무엇 |
|---|---|
| `DocumentBoxPage.tsx` `loadDetail` | 호출 순번 `useRef<number>` — 응답이 **최신 순번일 때만** `setDetail` |
| 같은 파일 | 적재 중에는 `setDetail(null)` 로 우측을 비운다 — 툴바가 옛 문서로 남지 않게 |

**골드:** 같은 계열 `HtmlDocumentPreview.tsx`:60·74 의 `alive` 가드.
다만 거기는 언마운트만 본다 — **여기는 순번이 필요하다.** 응답이 역순으로 오면 `alive` 로는 안 막힌다.

**주장 하나는 깎았다.** `MesEditableGrid.tsx`:575-579 는 `onClick` 에 **클릭한 행**을 넘긴다 —
off-by-one 이 아니다. 현장의 「항상 한 박자 늦는다」는 이 경합만으로는 설명이 안 되므로
그 부분은 **스테이징 빌드 시각 확인**이 남는다. 경합 자체는 코드로 확정이다.

**시험:** 단위 — `loadDetail` 을 A→B 로 연달아 부르고 A 응답을 늦게 풀었을 때 `detail` 이 B 인지.

### C7. DDL 주석의 `doc_kind=DB`

**층: DB 구조 + 생성 문서.**

| 파일 | 무엇 |
|---|---|
| `00_ddl.sql`:2713·4901·4915 | `COMMENT ON COLUMN` 의 `DB:` → `HTML:` |
| 그 뒤 | `node scripts/gen_table_layout.mjs` 재생성 |

**순서가 중요하다.** 문서를 먼저 고치면 `--check` 가 깨진다. DDL → 생성기 순.
라이브 DB 의 COMMENT 도 바꾸려면 `10_*.sql` 에 `COMMENT ON` 세 줄을 넣는다 — **선택**이다
(주석이라 동작에 영향 없음).

---

## 3. P2 — 규칙 위반

### K1. 개선조치 `validate-delete` 가 Single Check

**층: DB + BE 두 층.** 한 커밋이다. FE 는 안 바뀐다.

| 파일 | 무엇 |
|---|---|
| `01_sp.sql` | `sp_tbl_corrective_action_delete_blocker_r_000(p_co_cd varchar, p_idxs bigint[]) RETURNS TABLE(ref_key varchar, target varchar)` 신설. 형태는 기존 `*_delete_blocker_r_000` **9본** 중 아무거나 (예: `sp_tbl_company_template_delete_blocker_r_000`) |
| `flow/ca/CorrectiveActionMapper.java` + `mapper/flow/ca/CorrectiveActionMapper.xml` | `selectDeleteBlocker`. `foreach` 는 `mapper/draft/html/HtmlDraftMapper.xml` 의 `ARRAY[…]::bigint[]` 복제 |
| `flow/ca/CorrectiveActionService.java`:104·124 | `normalizeKeys` 를 `assertDeletable` 로 올리고 `DeleteValidation.throwIfBlocked` 를 양쪽에서 |

**골드:** `DocumentService.assertDeletable` (`validateDelete`·`delete` 양쪽에서 부른다).
**차단 조건:** `status = 'DONE'`. 지금 `_d_000`:2881 이 막는 것과 같은 기준이어야 한다.

**부수 효과 — 이게 목적이기도 하다:** 지금은 완료 건을 고르면 확인창을 누른 뒤 실패하고
여러 건이면 정상 건까지 롤백된다. 고치면 확인창 전에 어느 건이 왜 막히는지 나온다.

### K3. 죽은 env knob 2개

**층: FE.**

| 파일 | 무엇 |
|---|---|
| `main.tsx`:35 | `retry: 1` → `retry: API_RETRY_COUNT` + import |
| `config/envConfig.ts`:73-77 | `SEARCH_DEBOUNCE_MS` — 소비자가 없다. **「예약」으로 명시**하거나 `.env.example`:18 과 함께 지운다 |

**지우는 쪽을 권한다.** `GRID_DEFAULT_PAGE_SIZE` 는 "(예약)" 이라 규칙 표에 적혀 있지만
`SEARCH_DEBOUNCE_MS` 는 `06-operations.mdc` 표에 **쓰는 값처럼** 올라 있다.
지우면 규칙 표에서도 그 줄을 뺀다 — 그때 `06-operations.mdc` 를 같이 고친다.

**안 하는 것:** `GridChrome.tsx`:33 의 `250` 은 **안 건드린다.**
클라이언트 메모리 필터라 서버 호출 debounce 와 다른 knob 이다 (검수에서 기각됨).

### C4. 스모크 배열 하드코딩

**층: FE 시험.**

`e2e/screens.smoke.spec.ts`:17-47 의 `SCREENS` 가 `SCREEN_PATH` 를 안 읽는다.

**두 갈래 — 사용자 결정:**
(a) `SCREEN_PATH` 에서 뽑게 바꾼다 — 화면이 늘면 자동으로 는다. 대신 이름 열을 잃는다
(b) 지금처럼 두고 `docs/2_화면_추가하기.md` 절차(이미 10번 항목으로 넣었다)에 맡긴다

**(a) 를 권한다.** 절차에 맡기면 또 빠진다 — `#93` 때 실제로 그럴 뻔했다.

### K13. HWP 결재 미리보기가 승인 뒤에도 안 바뀐다

**층: FE.** HTML 은 `8497736` 에서 닫혔고 **HWP 갈래만 남았다** (03_판정 3 의 잔여).

`ApprovalDocumentPreview.tsx`:61 이 `HwpDocumentPreview` 에 `status` 를 안 넘기고,
`HwpDocumentPreview` props(:24-31)에도 `status` 가 없다.

| 파일 | 무엇 |
|---|---|
| `ApprovalDocumentPreview.tsx`:61 | HWP 갈래에도 `status={status}` |
| `HwpDocumentPreview.tsx` | `status` props 추가 → `HwpEditorPane` 열기 효과 의존에 넣는다 |

**같이 닫히는 것:** 본문 없는 문서를 결재자가 열면 `HwpEditorPane.tsx`:136-140 의 `mode="wait"` 에 걸려
「문서를 여는 중입니다…」에서 영영 멈춘다. `readOnly` 일 때 문구를
「본문이 저장되지 않은 문서입니다.」로 가른다 — K8 이 **새** 문서를 막고, 이건 **이미 승인된 것**을 보이게 한다.

### K14. 같은 「첫 클릭이 안 붙는」 결함이 공통 코드 팝업에 남았다

**층: FE.** 한 줄 삭제다.

`HtmlFormLookupModal.tsx`:164 에 「autoFocus 금지 — 켜면 첫 행 클릭이 포커스만 가져가고 선택이 안 붙는다」가
적혀 있다 (03_판정 A 로 고친 자리). `CodeLookupModal.tsx`:151 `autoFocus` + :199 `onRowClick={pick}` 이
**같은 조합 그대로**다. 쓰는 곳은 사용자관리 권한그룹·부서, 부서관리.

| 파일 | 무엇 |
|---|---|
| `CodeLookupModal.tsx`:151 | `autoFocus` 삭제 + `HtmlFormLookupModal.tsx`:164 와 같은 이유 주석 |

### K15. 승인 화면이 미조치 개선조치 건수를 버린다

**층: FE.**

`sp_sign_ready_r_000`:3176-3177 이 `open_ca_cnt` 를 세고 매퍼가 `resultType="map"` +
`map-underscore-to-camel-case`(`application.yml`:55)로 `openCaCnt` 를 올려 보내는데,
`documentApi.ts`:35 가 **저장소에서 이 이름이 나오는 유일한 자리**다 — 어느 화면도 안 그린다.
팀장이 승인할 때 그 문서에 미조치 개선조치가 몇 건 달렸는지 볼 자리가 없다.

| 파일 | 무엇 |
|---|---|
| `DocumentBoxPage.tsx` 목록 열 | `openCaCnt > 0` 이면 배지 한 칸 |

**막지는 않는다.** 미조치 개선조치가 있어도 승인은 되는 것이 맞다 — 조치는 문서보다 늦게 끝난다.
보이기만 하면 된다.

---

## 4. P3 — 나중에 해도 된다

| # | 무엇 | 층 |
|---|---|---|
| K2 | `mapper/board/TaskMapper.xml`:17 네이티브 SQL → `sp_tbl_company_r_000` 신설 후 호출 | DB + BE |
| K4 | 인쇄 대기 `180_000` 중복 → `components/document/` 공유 상수. **`API_TIMEOUT_FILE_MS` 재사용 아님** | FE |
| C5 | `DocumentFileStorage.java`:70·141 · `application.yml`:101 · `.env.example`:74 경로 주석 역순 | BE |
| C6 | `Jenkinsfile`:174 · 셸 7본 머리주석의 `런북 §9·§10·§11·§15·§19` | 인프라 |
| C8 | `docs/3_화면_지도.md`·`docs/5_PIPELINE_색인.md` 재생성 | 생성기 |

C8 은 지금 `audit_generated_docs` 를 빨갛게 만들고 있다 — **두 줄이면 닫힌다.**
`node scripts/gen_screen_map.mjs` · `node scripts/gen_pipeline_index.mjs`.

---

## 5. 순서

```
1) C8            생성기 두 줄 — 야간 감시부터 초록으로
2) K5 + K8       FE 계약(boolean) + SP 가드 — P0. **한 커밋**. K5 만 넣으면 결함이 옮겨간다
3) K9            FE 전송 검사 — P0
4) K5-b·K6·K10   SP 세 곳 — 10_*.sql 한 본에 같이. 라이브·시험 적용
5) K11·K12       FE — P1
6) C7            DDL 주석 + 생성기 재생성
7) K7            BE 순서 교정
8) K1            DB+BE 한 커밋
9) K3·C4·K13·K14·K15  FE
10) P3 다섯 건
```

### 배포와 DB 의 간격 — 깨지는 곳은 8번이다

**Jenkins 는 DB 를 안 건드린다.** 그래서 DB 와 앱의 순서를 사람이 맞춰야 한다.

| 단계 | 순서 | 왜 |
|---|---|---|
| **2 (K8 의 SP 가드)** | **DB 먼저, 앱은 그 다음** | 가드가 먼저 서면 본문 없는 문서의 전송이 즉시 막힌다 — 그게 목적이다. 앱이 먼저 가면 FE 의 boolean 만 돌고 **마지막 문이 없는 창**이 열린다.<br>**남는 것을 미리 본다:** 이미 `WRK` 로 남아 있는 본문 없는 HWP 문서는 가드 뒤로 전송이 막힌다. `SELECT d.doc_no FROM tbl_document d WHERE d.doc_kind='HWP' AND d.status='WRK' AND NOT EXISTS (SELECT 1 FROM tbl_document_file f WHERE f.doc_idx=d.idx AND upper(f.file_kind)='HWP_SRC')` 로 먼저 세고 작성자에게 알린다 |
| 4 (K5-b·K6·K10) | **DB 먼저, 앱은 아무 때나** | SP 의 `45000` 문구는 앱 변경 없이 그대로 화면에 뜬다 (`GlobalExceptionHandler` → `SqlUserMessage`). 앱이 몰라도 된다 |
| 6 (C7) | 아무 때나 | DDL COMMENT 라 동작과 무관 |
| **8 (K1)** | **함수를 라이브·시험에 먼저 만들고 그 다음 앱 배포** | 신설 함수다. 앱만 먼저 올라가면 매퍼가 없는 함수를 불러 **`42883`** — 개선조치 삭제가 확인창 전에 전부 죽는다 |

**되돌리는 법 (8번):** 앱을 이전 TAG 로 롤백(`DEPLOY.md` §5)한 뒤
`DROP FUNCTION sasshaccp.sp_tbl_corrective_action_delete_blocker_r_000(varchar, bigint[]);`.
**순서를 지킨다** — 함수를 먼저 지우면 아직 도는 앱이 `42883` 을 만난다.

**4번 되돌리기:** `01_sp.sql` 의 이전 판본으로 그 SP 만 `CREATE OR REPLACE`.
데이터를 안 건드리므로 되돌림이 깨끗하다 — `10_*.sql` 은 SP 재정의만 담고 `UPDATE`·`DELETE` 를 넣지 않는다.

---

## 6. 각 단계 공통

- **`db_sasshaccp/` 를 고치면 `01_sp.sql` 정본과 라이브·시험 DB 셋을 같이 맞춘다.** 하나만 고치면 다음 세션이 못 찾는다
- **주석은 고치는 커밋에 같이 넣는다.** 무엇을 적을지는 `handoff.md` 「4단계 — 소스 주석 계획」
- 각 건마다 **E2E 를 먼저 빨갛게** 만들고 고친다. 통과만 보고 넘기지 않는다 (`docs/6_테스트.md`)
- `scrnCd` · `persistId` · 이미 발급된 `doc_no`·`ca_no` 는 **안 바꾼다**
- 검증: `npx tsc --noEmit` · `npx vitest run` · `npm run build` · `npm run preview &` · `npx playwright test` ·
  `./mvnw -q -o test` · `bash scripts/audit_generated_docs.sh`

---

## 7. 이 계획이 거쳐 온 것

초안을 Critic·Defender 에 두 번 걸었다. **초안에 P0 가 둘 있었다** — 그대로 했으면 지금보다 나빠진다.

| 라운드 | 잡힌 것 |
|---|---|
| 1차 Critic | **K5** `docIdx` 단독 대조가 모든 HWP 첫 저장의 본문 업로드를 막는다 (신규는 `docIdx=null`)<br>**K7** 호출을 insert 뒤로 옮기면 `doc_idx+kind` 전건 DELETE 가 방금 넣은 행을 지운다<br>K5-b 는 DELETE 만 막고 UPDATE 가 `DONE` 을 되돌린다<br>배포 경고가 엉뚱한 구간을 가리키고 K1 신설 함수의 라이브 적용 시점이 없다 |
| 2차 Defender | K5 `template` 통과가 **로드 중 창**을 남긴다 → 로드 전 `wait` 잠금<br>K5 통지 위치·`onOpened` ref 화·초기값·토스트<br>K7 **옛 경로 == 새 경로**면 방금 올린 본문을 지운다 → 새 경로 필터<br>**K5-b 를 `45000` 으로 막으면 안 된다** — 문서 저장 트랜잭션이 통째로 롤백된다<br>K6 `substring(...)::int` 가 legacy 행에 `22P02` · `_c_000` 접두 변경이 `ca_no` 의 날짜 뜻을 바꾼다<br>K1 은 두 층이지 세 층이 아니다 |

| 3차 (라스트 현장) | **K8** K5 가 조용히 `return` 해도 `afterSave` 가 `Promise<void>` 라 `runSaveDetail` 이 `true` 를 준다 — 계획대로면 「남의 본문이 올라간다」가 **「본문이 없는데 승인된다」로 옮겨갈 뿐**이다<br>**K9** 부적합인데 이탈내용이 자동문구인 채로 전송을 막는 자리가 없다<br>K10 조치자가 두 층 다 안 써지는데 성공 토스트가 뜬다<br>K11 잠금 해제가 DB·SP·BE 는 열려 있고 FE 만 막혀 있다<br>K12 결재 상세에 순번 가드가 없어 오승인 창이 열린다<br>K13·K14·K15 HWP 도장·형제 팝업 autoFocus·버려지는 `openCaCnt` |

**뒤집은 권고 하나:** K5-b 를 「`45000` 으로 막는다」에서 **「SP 는 조용히 보존, 알림은 화면」** 으로.
막으면 완료된 개선조치가 달린 문서는 본문 수정이 영영 안 된다.

**`45000` 을 쓰는 곳과 안 쓰는 곳을 갈랐다.** K5-b 는 **문서 저장 트랜잭션 안**이라 못 던지고,
K8 은 `processApproval` 자기 트랜잭션이라 **던져야 한다.** 같은 `RAISE` 라도 부르는 자리가 판단을 가른다.

**깎은 주장 하나:** 「행 첫 클릭이 이전 문서」의 off-by-one 은 없다 —
`MesEditableGrid.tsx`:575-579 는 클릭한 행을 넘긴다. 남은 것은 경합(K12)이다.

**남은 재확인 넷:** `ca_no` 의 날짜 뜻(발생일)을 매뉴얼에 못박는 것 · K5 E2E 가 `wait` 상태를 확정하는지 ·
K12 의 「항상 한 박자 늦는다」가 스테이징 구버전인지 · HWP 본문이 화면 밖으로 밀리는 레이아웃(브라우저로 재야 한다).
