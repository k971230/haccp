# db_sasshaccp

PostgreSQL `sasshaccp` 스키마 **정본**. 여기 7본이 곧 DB 다 — 손으로 친 DDL·데이터는 남기지 않는다.

## 파이프라인

```
00_ddl        구조        표 53 · 인덱스 · 제약           회사코드 없음
01_sp         로직        SP·함수 152                     회사코드 없음
02_seed       플랫폼 기준  화면 28 · 양식 46 · 0000 업체   0000 고정
     │
     ├─ 03_code_seed   공통코드 86 (18그룹)      -v co_cd=  업체별
     ├─ 05_form_seed   HTML 표준 지면 항목        -v co_cd=  업체별
     └─ 06_company_seed 업체 개설 일습            -v co_cd=  업체별
04_migrate_code_upper  구 DB 1회용 — 신규 설치에는 안 쓴다
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

## 새 업체를 여는 법 (0001 …)

```sh
CO_CD=0001 CO_NM='별담푸드' ADMIN_ID=admin0001 bash apply-all.sh
```

`06_company_seed.sql` 이 **로그인해서 HWP 문서를 쓸 수 있는 상태**까지 만든다.

> **HTML 작성 5화면은 한 걸음이 더 있다** — 아래 「10. 다음 단계」를 본다.

| # | 무엇 | 왜 필요한가 |
|---|---|---|
| 1 | 회사 | 테넌트 자체 |
| 2 | 권한그룹 3 (ADMIN·USER·VIEWER) | 사용자에게 붙일 그룹 |
| 3 | 메뉴 43 | `tbl_menu` 는 업체별이다. 비면 좌측이 통째로 빈다 |
| 4 | 화면권한 84 | 비면 로그인해도 아무 화면이 안 열린다 |
| 5 | 부서 1 (HQ 본사) | 사용자에게 부서가 필수다 |
| 6 | 초기 관리자 | 첫 로그인 계정. **비밀번호 1234 — 첫 로그인 후 반드시 변경** |
| 7 | 기본 결재선 + 3단계 | 검토(REVIEW)는 꺼 둔다. 켜면 전송한 문서가 승인으로 못 넘어간다 |
| 8 | 사용양식 38 (시스템 제공만) | 원본 업체의 `sys` 양식을 물려준다. `usr`(자사 제작)은 안 준다 |
| 9 | 문서번호 규칙 38 | 없으면 문서를 만들 때 번호가 안 붙는다 |

### 10. 다음 단계 — 시드가 안 해 주는 것

시드는 **표준 지면**(`tbl_check_item`)까지만 깐다. HTML 작성 5화면은
**회사 지면 버전**(`tbl_*_ver`)을 읽는데 그건 안 만든다 — 업체마다 지면이 달라
표준을 그대로 주면 안 되기 때문이다.

그래서 갓 개설한 업체는 HTML 작성 화면이 **빈 목록**으로 뜬다. 확인하려면

```sql
SELECT count(*) FROM tbl_tml_ccp_htg_ver WHERE co_cd = '0001';  -- 0 이면 아직이다
```

개설한 업체의 관리자로 로그인해 **양식 원본 5화면에서 「행추가」를 누른다.**
행추가는 신규 등록이 아니라 **표준 복사**다.

```
문서 > HTML·양식 원본 > 일반위생·공정점검 양식관리      행추가 후 저장
                      > CCP 검증점검표 양식관리         행추가 후 저장
                      > CCP 포장공정 일지관리           행추가 후 저장
                      > CCP 가열공정 일지관리           행추가 후 저장
                      > CCP 금속검출공정 일지관리        행추가 후 저장
```

다섯 화면 모두 해야 작성 화면 5개가 다 열린다. **HWP 작성은 이 단계가 필요 없다.**

메뉴·화면권한을 이 파일에 손으로 적지 않고 **0000 을 복제**한다.
그래야 화면이 하나 늘 때 `02_seed.sql` 한 곳만 고치면 된다.

검증(2026-08-26): 0001 을 실제로 만들어 `admin0001/1234` 로그인 → 메뉴 43 조회 →
HWP 문서 작성 → 문서번호 `hwp_sys_001-20260826-001` 채번까지 확인했다.

## 규칙

| 항목 | 정본 |
|---|---|
| 표 이름 | `tbl_{업무}` · 하위 표는 `tbl_{업무}_{행}` |
| SP 이름 | `sp_{화면}_{동작}_000` · 공용은 `sp_tbl_{표}_{동작}_000` |
| 동작 | `r`=조회 `c`=등록 `u`=수정 `d`=삭제 |
| 공통코드 | `main_cd`·`sub_cd` 둘 다 **UPPER_SNAKE**. `sub_cd` 는 업무 표에 저장되는 값과 같은 표기 |
| 업무 오류 | SP 에서 `RAISE ... USING ERRCODE='45000'` → 400 + 그 문구 |
| 삭제 | HTTP DELETE 를 쓰지 않는다. `validate-delete` → `delete` 2단계 |
| 재실행 | 7본 모두 몇 번을 돌려도 결과가 같아야 한다 |

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
- **표준 원본 양식코드를 지우지 않는다** — 복사 SP 가 여기서 읽는다 (E2E-007)

  | 화면 | 표준 원본 | 읽는 SP |
  |---|---|---|
  | 일반위생·공정점검 양식관리 | `html_sys_001` | `sp_tbl_html_hyg_prc_ver_copy_c_000` |
  | CCP 검증점검표 양식관리 | `html_sys_006` | `sp_tbl_tml_ccp_chk_ver_copy_c_000` |
  | CCP 포장·가열·금속검출 양식관리 | `tml_ccp_{pkg,htg,mtl}_000` | 각 `*_ver_copy_c_000` |

  양식코드를 지우기 전에 `grep "그 코드" 01_sp.sql` 로 참조를 먼저 본다

## 검증

```sh
# 빈 DB 에 7본을 순서대로 → 표 53 / SP 152 / 메뉴 43 / 코드 86 / 사용양식 45 / 회사지면 5
bash apply-all.sh

# 화면까지 도는지 — 프론트 E2E 152건
cd ../frontend/haccp-web ; npx playwright test
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

## 새 업체를 열 때

```sh
CO_CD=0001 CO_NM='별담푸드' ADMIN_ID=admin0001 bash apply-all.sh
```

**07 까지 돌아야 쓸 수 있다.** 06 까지만 돌리면 로그인·메뉴·권한은 되는데
작성 화면의 양식 선택 팝업이 **0건**이라 일지를 한 장도 못 쓴다 —
시드는 표준 지면까지만 깔고 회사 지면 버전(`tbl_*_ver`)은 안 만들기 때문이다.

개설 뒤 **사람이 해야 하는 것 둘**:

| | 무엇 | 왜 |
|---|---|---|
| 1 | 실무 계정 만들기 (팀원·팀장) | `06` 은 관리자 하나만 만든다. 실존 인물이어야 한다 |
| 2 | **기본 결재선 승인자를 팀장으로** | `06` 은 개설 관리자를 승인자로 박는다. 그대로 두면 팀원이 올린 일지가 관리자에게만 가고 팀장 함은 0건으로 남는다 — 데모식품에서 실제로 그렇게 굴러갔다. 결재선관리 화면이 이 상태를 경고한다 |

```sql
UPDATE tbl_approval_line_step
   SET approver_id = '팀장아이디', upd_id = 'admin', upd_dt = now()
 WHERE co_cd = '0001' AND appr_line_cd = 'DEFAULT' AND role_cd = 'APPROVE';
```

## 변경

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
