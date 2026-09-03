# db_sasshaccp

PostgreSQL `sasshaccp` 스키마 **정본**. 여기 7본이 곧 DB 다 — 손으로 친 DDL·데이터는 남기지 않는다.

## 파이프라인

```
00_ddl        구조        표 · 인덱스 · 제약 (수는 docs/10) 회사코드 없음
01_sp         로직        SP·함수 (수는 docs/9)            회사코드 없음
02_seed       플랫폼 기준  화면 · 양식 · 0000 업체          0000 고정
     │
     ├─ 03_code_seed    공통코드                    -v co_cd=  업체별
     ├─ 05_form_seed    HTML 표준 지면 항목         -v co_cd=  업체별
     ├─ 06_company_seed 업체·계정·결재선·사용양식   -v co_cd=  업체별
     ├─ 07_company_forms 회사 지면 5본 복사         -v co_cd=  업체별
04_migrate_code_upper  구 DB 1회용 — 신규 설치에는 안 쓴다
08·09 (검토 제거·결재 SP 개명) 는 운영·시험에 적용한 뒤 지웠다. 정본은 00_ddl·01_sp 다.
```

**업무 로직은 SP 에 둔다.** 백엔드는 SP 를 부르고 결과를 담아 넘기는 일만 한다
(`.cursor/rules/07-haccp-db.mdc`). 화면이 늘어도 이 구조는 안 바뀐다.

## 처음 까는 법

```sh
# 플랫폼 초기화 — 0000(데모식품)까지
PGHOST=호스트 PGUSER=계정 PGPASSWORD=*** bash apply-all.sh

# 손으로 하려면
psql -f 00_ddl.sql
psql -f 01_sp.sql
psql -f 02_seed.sql
psql -v co_cd=0000 -f 03_code_seed.sql
psql -v co_cd=0000 -f 05_form_seed.sql
```

## 새 업체를 여는 법 (0004, 0005 …)

**SQL 파일을 새로 만들지 않는다.** `02_seed.sql` 에 업체를 넣지 않는다.
`apply-all.sh` 가 `03`→`05`→`06`→`07` 을 그 `CO_CD` 로 돌리는 것은 **빈 DB 초기화 1회에 한정된다.**
이미 깔린 DB 에 다시 부르면 1단계가 `00_ddl.sql` 을 돌려 `42P06 duplicate schema` 로 죽는다.
업체를 더 얹을 때는 업체분 4본만 직접 돌린다.

```sh
export PGHOST=호스트 PGUSER=계정 PGPASSWORD=*** PGDATABASE=sasshaccp
P="psql -v ON_ERROR_STOP=1"

$P -v co_cd=0004 -f 03_code_seed.sql
$P -v co_cd=0004 -f 05_form_seed.sql
$P -v co_cd=0004 -v co_nm='업체한글명' -v admin_id=팀장아이디 -v writer_id=팀원아이디 \
   -f 06_company_seed.sql
$P -v co_cd=0004 -f 07_company_forms.sql
```

`06` 의 초기 비밀번호는 `1234` 다. 첫 로그인 후 반드시 바꾼다.

| 변수 | 예 (0003 알엠에이) | 규칙 |
|---|---|---|
| `CO_CD` | `0003` | 네 자리. 이미 있는 코드면 시드가 기존 행을 덮지 않는다 |
| `CO_NM` | `알엠에이` | 회사명. 계정 표시명은 `{CO_NM}팀장` / `{CO_NM}팀원` |
| `ADMIN_ID` | `rmasys` | 팀장. `user_id` 는 **전역 UNIQUE** — 다른 업체 ID 와 겹치면 안 된다 |
| `WRITER_ID` | `rmausr` | 팀원. 빼면 팀장 혼자(WRITE·APPROVE 모두 팀장) |

`WRITER_ID` 를 주면 기본 결재선은 0001(별담)·0003 과 같다.

| 단계 | 계정 | 그룹 |
|---|---|---|
| WRITE | `WRITER_ID` | `HACCP_TEAM` |
| APPROVE | `ADMIN_ID` | `HACCP_MASTER` |

초기 비밀번호는 둘 다 **1234**. Jenkins 는 DB 를 안 돌린다 — 이 스크립트를 배포와 따로 실행한다.

시드가 넣는 것: 회사, 권한그룹(0000 복제), 메뉴, 화면권한, 부서 HQ, 계정 1~2, 기본 결재선, sys 사용양식, 문서번호 규칙, 공통코드(`03`), HTML 회사 지면 5본(`07`). HWP 실물은 볼륨 `HaccpTemplates/` 공유라 업체별 복사가 없다.

### 개설 뒤 사람이 하는 것

| | 무엇 |
|---|---|
| 1 | 팀장·팀원으로 로그인되는지 확인한 뒤 **비밀번호 변경** |
| 2 | 사용자 관리에서 **서명 이미지** 등록 (없으면 지면 도장칸 사인만 비어 있다) |
| 3 | 필요하면 회사 관리에서 사업자번호·주소 |

계정과 결재선은 시드가 이미 넣는다. 화면에서 팀원을 다시 만들거나 `APPROVE` 를 UPDATE 하지 않는다.

`psql` 이 PATH 에 없으면 `apply-all.sh` 가 실패한다. 그때는 같은 네 변수를 넘겨 `03_code_seed.sql` → `05_form_seed.sql` → `06_company_seed.sql` → `07_company_forms.sql` 만 순서대로 적용한다 (`00`·`01`·`02` 는 이미 있는 플랫폼이라 건너뛴다).

메뉴·화면권한 INSERT 를 업체마다 손으로 적지 않는다. **0000 을 복제**하므로 화면이 늘면 `02_seed.sql` 한 곳만 고친다.

## 규칙

| 항목 | 정본 |
|---|---|
| 표 이름 | `tbl_{업무}` · 하위 표는 `tbl_{업무}_{행}` |
| SP 이름 | `sp_{화면}_{동작}_000` · 공용은 `sp_tbl_{표}_{동작}_000` |
| 동작 | `r`=조회 `c`=등록 `u`=수정 `d`=삭제 |
| 공통코드 | `main_cd`·`sub_cd` 둘 다 **UPPER_SNAKE**. `sub_cd` 는 업무 표에 저장되는 값과 같은 표기 |
| 업무 오류 | SP 에서 `RAISE ... USING ERRCODE='45000'` → 400 + 그 문구 |
| 삭제 | HTTP DELETE 를 쓰지 않는다. `validate-delete` → `delete` 2단계 |
| 재실행 | 7본 모두 몇 번을 돌려도 결과가 같아야 한다 — **목표다. 지금은 아니다.** `00_ddl`(`CREATE SCHEMA`·`CREATE TABLE` 에 `IF NOT EXISTS` 없음)·`02_seed`(`ON CONFLICT` 0건)는 빈 DB 전용 |

## 손대면 안 되는 것

- **`sp_*` 를 `CREATE PROCEDURE` 로 되돌리지 않는다** — 재적용이 막힌다 (E2E-002)
- **양식코드를 SP 안에 정규식으로 나열하지 않는다** — 새 양식이 목록에서 사라진다.
  구분이 필요하면 `tbl_template.doc_kind` 처럼 값으로 판단한다
- **서명은 `sign_img`(bytea)** 다. 옛 `sign_path` 를 참조하면 결재가 통째로 죽는다 (E2E-001)
- **유니크가 걸린 자리 번호를 화면 값으로 받지 않는다.** 지면 저장 SP 둘
  (`sp_tbl_hyg_process_c_000`·`sp_ccp_verify_c_000`)은 `sort_no`·`row_seq` 를
  **보내온 배열 순서(`v_seq`)로 우리가 매긴다**. 예전에는 `COALESCE(sortNo, v_seq)` 로
  화면 값을 그대로 받았는데, 그 자리에 유니크(`hdr_idx, sort_no`)가 걸려 있어
  겹친 값이 오면 `23505` 가 나고 그게 **409 「다른 사용자가 동시에 처리 중입니다」**로
  둔갑해 사람을 엉뚱한 데로 보냈다. 상세 조회가 지면 머리와 점검항목에 각각 1번을
  붙여 내려주므로 **읽은 것을 그대로 저장하면 터진다**.
  양식 원본 표(`*_ver_item`)는 유니크가 `item_cd` 라 해당 없다
- **자사 HTML 양식코드는 회사 안에서 001부터** — `ux_tbl_template UNIQUE (co_cd, tmpl_cd)`.
  `html_hyg_prc_NNN` · `html_ccp_{chk,htg,mtl,pkg}_NNN` 복사 SP 가 전역 MAX 를 보면
  0000 이 012 일 때 새 업체가 013 을 받는다. 표준(`html_sys_001`, `hwp_sys_*`) 은 계속 `co_cd=0000` 한 줄
- **표준 원본 양식코드를 지우지 않는다** — 복사 SP 가 여기서 읽는다 (E2E-007)

  | 화면 | 표준 원본 | 읽는 SP |
  |---|---|---|
  | 일반위생·공정점검 양식관리 | `html_sys_001` | `sp_tbl_html_hyg_prc_ver_copy_c_000` |
  | CCP 검증점검표 양식관리 | `html_sys_006` | `sp_tbl_html_ccp_chk_ver_copy_c_000` |
  | CCP 포장·가열·금속검출 양식관리 | `html_ccp_{pkg,htg,mtl}_000` | 각 `*_ver_copy_c_000` |

  양식코드를 지우기 전에 `grep "그 코드" 01_sp.sql` 로 참조를 먼저 본다

## 검증

```sh
# 빈 DB 에 7본을 순서대로 → 표는 docs/10 · SP 는 01_sp.sql · 메뉴·코드·양식은 시드
bash apply-all.sh

# 화면까지 도는지 — 프론트 E2E. 건수는 npx playwright test --list 로 센다
cd ../frontend/haccp-web ; npm run build ; npm run preview &
npx playwright test
```

### 알림이 한 번만 쌓이는지

**두 번 이상 불러 봐야 뜻이 있다.** 한 번만 부르고 넘어가면 막으려던 것을 시험하지 않은 셈이다.

```sh
# 1) 일일 배치는 알림을 만들지 않는다 — 지연 과제가 있어도 건수가 그대로여야 한다
node ../tools/q.mjs "SELECT count(*) FROM tbl_notification"
node ../tools/q.mjs "CALL sp_tbl_schedule_task_generate_c_000('0000','20260828','system')"
node ../tools/q.mjs "SELECT count(*) FROM tbl_notification"     # 위와 같아야 한다

# 2) 휴면 회사는 건너뛴다 — 로그인 이력을 밀어 두고 부른다
node ../tools/q.mjs "UPDATE tbl_login_log SET login_dt = login_dt - interval '60 days' WHERE co_cd='0000'"
node ../tools/q.mjs "CALL sp_tbl_notification_task_c_000('system', 30)"
node ../tools/q.mjs "SELECT count(*) FROM tbl_notification"     # 안 늘어야 한다
# 다만 alarm_send_yn 은 'Y' 로 닫혀야 한다 — 깨어났을 때 지난 마감이 몰려 터지지 않게
node ../tools/q.mjs "SELECT alarm_send_yn, count(*) FROM tbl_schedule_task WHERE co_cd='0000' AND alarm_dt <= now() GROUP BY 1"
node ../tools/q.mjs "UPDATE tbl_login_log SET login_dt = login_dt + interval '60 days' WHERE co_cd='0000'"

# 3) 중복 인덱스가 무는지 — 막히지 않으면 인덱스가 없는 것이다
node ../tools/q.mjs "INSERT INTO tbl_notification(co_cd,noti_type_cd,user_id,title,content) SELECT co_cd,noti_type_cd,user_id,title,content FROM tbl_notification LIMIT 1"
# → duplicate key value violates unique constraint "ux_tbl_notification_dedup"
```

**시험 DB 에서만 한다** (`tbl_login_log` 를 되돌려 놓는 것을 잊지 않는다).

## 관련

- 규칙: `.cursor/rules/07-haccp-db.mdc`
- 화면 전수표: [`../docs/3_화면_지도.md`](../docs/3_화면_지도.md) — 생성기가 만든다
- SP → 표 전수표: [`../docs/9_SP_색인.md`](../docs/9_SP_색인.md) — 생성기가 만든다
- E2E 결과: [`../E2E.md`](../E2E.md) · [`../E2E_ERRORS.md`](../E2E_ERRORS.md)
- 배포: `Dockerfile.migrate` (컨테이너에서 `apply-all.sh` 실행)

## 변경

- 2026-09-01 — 새 업체 개설은 변수 네 개(`CO_CD`·`CO_NM`·`ADMIN_ID`·`WRITER_ID`)만 바꾼다.
  `WRITER_ID` 가 있으면 팀원·팀장과 기본 결재선(WRITE/APPROVE)까지 시드가 넣는다.
  `02_seed.sql` 에 업체를 덤프하지 않는다. HTML 지면은 `07_company_forms.sql` 이 복사한다.
- 2026-08-29 — **저장이 되는데 일이 안 되는 자리 넷을 막았다.**
  DB 가 NULL 을 받는다고 업무가 성립하는 것은 아니다 — 저장은 됐는데 아무 일도
  일어나지 않으면 사람이 원인을 못 찾는다. 그래서 SP 에서 막는다.
  - **결재선의 결재자는 SP 에서 안 막는다.** 막아 봤다가 되돌렸다 —
    화면이 두 걸음으로 만든다(코드·명만 저장해 줄을 만들고, 그 줄을 골라 결재자를 넣는다).
    첫 걸음에서 막으면 **결재선을 새로 못 만든다**. E2E 가 그걸 잡았다.
    해가 나는 자리는 **그 결재선을 문서주기에 걸 때**라 거기서 막는다
    (`ScheduleCycleManagementRule.validateCycleSave`)
  - `*_ver_item_u_000` **5본** — **점검항목 0건이면 막는다.** 예전에는 저장됐고,
    그 양식으로 쓴 일지가 **전송할 때** 「점검 행이 없습니다」로 막혔다 —
    만든 사람과 막히는 사람이 다르고 시점도 떨어져 있어 원인을 알 길이 없었다
  - `sp_tbl_ccp_metal_monitor_c_000` — **감도 5칸 자동 판정을 걷어냈다.**
    뒤 세 열은 양식에서 「해당 없음」이 기본이라 고정행에 입력칸이 없어 늘 부적합이 됐고,
    그걸 덮던 `judge_mod_yn` 을 읽는 화면이 없어 **누가 뒤집었는지 아무도 못 봤다**.
    판정은 이제 포장·가열과 같이 사람이 정한 값을 그대로 넣는다.
    근거는 화면이 채운다 — 「모두 적합」이 판정과 감도 5칸을 같이 채운다
- 2026-08-28 — **알림을 만드는 곳을 하나로 줄였다.** `sp_tbl_schedule_task_generate_c_000` 에서
  알림 INSERT 를 걷어내고, `sp_tbl_notification_task_c_000`(10분 크론)만 남겼다.
  셋이 겹쳐 있었다 — 지연분이 날마다 다시 들어갔고, `NOT EXISTS` 가드가
  **같은 INSERT 가 방금 넣은 행을 못 봐서** 한 문장이 여러 행을 넣었고(운영 중복 조합 15개),
  그 SP 를 화면 조회(`TaskService.todayTasks`)도 불러 사람이 화면을 열 때마다 알림이 생겼다.
  남은 SP 에는 `p_dormant_days` 를 더해 **로그인 없는 회사를 건너뛴다** —
  예정일이 1년치 미리 깔려 있어 안 쓰는 업체도 저절로 쌓였다.
  `00_ddl.sql` 에 `ux_tbl_notification_dedup` 을 두고, 그 INSERT 에 `ON CONFLICT DO NOTHING` 을 붙였다.
  안 붙이면 유니크에 걸리는 순간 **그 실행의 모든 회사 알림이 같이 롤백된다** — 시험에서 실제로 그렇게 났다.
  기본 설정으로는 겹칠 길이 좁지만 `alarm-before-minutes` 를 하루 넘게 키우면 열린다.
  1회성 정리: `DELETE FROM tbl_notification WHERE noti_type_cd='TASK_LATE'`
- 2026-09-01 — `ux_tbl_template` 를 `UNIQUE (co_cd, tmpl_cd)` 로. 자사 HTML 복사는 회사별 001부터.
  `06_company_seed` 8절은 HWP sys 를 `hwp_sys_001`~`027` 만 물려 준다(028~038 유령 차단).
- 2026-08-31 — 볼륨 실물 없는 HWP `hwp_sys_028`~`038` 11종을 운영 DB·시드·매니페스트에서
  삭제(문서 0건). 화면 삭제 SP는 시스템 제공을 막아 직접 `DELETE`.
- 2026-08-28 — `07_company_forms.sql` 신설. 업체 개설 뒤 **회사 지면 5본**을 표준에서 복사한다.
  이게 없으면 새 업체는 작성 화면에 고를 양식이 0건이라 아무것도 못 쓴다.
  별담푸드(0001)를 실제로 열어 보고 알았다. `apply-all.sh` 가 06 다음에 돌린다.
  `DO $$` 를 안 쓴다 — psql 이 달러 인용부호 안에서는 변수를 치환하지 않는다.
- 2026-08-27 — **결재와 지면 도장칸을 이었다.** 상세 SP 두 본(`sp_tbl_hyg_process_r_001`·
  `sp_ccp_verify_r_001`)이 승인자·서명을 `tbl_document_approval`(결재 결과)에서 먼저 읽는다.
  예전에는 지면에 적힌 글자만 봐서, 결재를 승인해도 종이에는 작성 당시 값이 그대로 남았다.
  서명 스냅샷은 승인 SP 가 이미 남기고 있었다 — 아무도 안 읽었을 뿐이다.
  지면 서명 SP 두 본(`sp_tbl_hyg_process_sign_u_000`·`sp_ccp_verify_sign_u_000`)은
  승인자 이름이 `tbl_user` 에 없으면 `45000` 으로 막는다. 사람 이름이 아닌 값이 저장된 적이 있다.
  `tbl_ccp_metal_sens_row.check_time` 을 `varchar(4)` → `varchar(10)` 으로 넓혔다 —
  화면이 보내는 `09:10` 이 5자라 금속검출 일지가 저장·전송 단계에서 전부 `22001` 로 막혔다.
  나머지 CCP 표는 처음부터 `varchar(10)` 이다. `00_ddl.sql` 꼬리에 `ALTER` 를 뒀다(재실행 안전).
- 2026-08-26 — `06_company_seed.sql` 신설(신규 업체 개설 정본). 소스가 안 쓰는 표 18개와
  삭제된 화면에 딸린 양식 27종을 걷어냈다(표 71→53, 양식 73→46).
  SP 안에 박혀 있던 양식코드 정규식 2곳을 `doc_kind` 기준으로 바꿨다 —
  그동안 `hwp_sys_028`~`038` 11종이 목록에서 안 보였다.
- 2026-08-25 — 번호 마이그레이션 133본을 5본으로 접었다. SP 152본을 `CREATE OR REPLACE` 로 바꿔
  재적용이 되게 했다. 공통코드를 UPPER_SNAKE 로 통일했다.
