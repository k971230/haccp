# db_sasshaccp

PostgreSQL `sasshaccp` 스키마 **정본**. 여기 6본이 곧 DB 다 — 손으로 친 DDL·데이터는 남기지 않는다.

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

`06_company_seed.sql` 이 **로그인해서 문서를 쓸 수 있는 상태**까지 만든다.

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
| 재실행 | 6본 모두 몇 번을 돌려도 결과가 같아야 한다 |

## 손대면 안 되는 것

- **`sp_*` 를 `CREATE PROCEDURE` 로 되돌리지 않는다** — 재적용이 막힌다 (E2E-002)
- **양식코드를 SP 안에 정규식으로 나열하지 않는다** — 새 양식이 목록에서 사라진다.
  구분이 필요하면 `tbl_template.doc_kind` 처럼 값으로 판단한다
- **서명은 `sign_img`(bytea)** 다. 옛 `sign_path` 를 참조하면 결재가 통째로 죽는다 (E2E-001)
- **표준 원본 양식코드를 지우지 않는다** — 복사 SP 가 여기서 읽는다 (E2E-007)

  | 화면 | 표준 원본 | 읽는 SP |
  |---|---|---|
  | 일반위생·공정점검 양식관리 | `html_sys_001` | `sp_tbl_html_hyg_prc_ver_copy_c_000` |
  | CCP 검증점검표 양식관리 | `html_sys_006` | `sp_tbl_tml_ccp_chk_ver_copy_c_000` |
  | CCP 포장·가열·금속검출 양식관리 | `tml_ccp_{pkg,htg,mtl}_000` | 각 `*_ver_copy_c_000` |

  양식코드를 지우기 전에 `grep "그 코드" 01_sp.sql` 로 참조를 먼저 본다

## 검증

```sh
# 빈 DB 에 6본을 순서대로 → 표 53 / SP 152 / 메뉴 43 / 코드 86 / 사용양식 45
bash apply-all.sh

# 화면까지 도는지 — 프론트 E2E 64건
cd ../frontend/haccp-web ; npx playwright test
```

## 관련

- 규칙: `.cursor/rules/07-haccp-db.mdc`
- 전수표: `docs/14_메뉴_화면_API_DB_전수.md`
- E2E 결과: [`../E2E.md`](../E2E.md) · [`../E2E_ERRORS.md`](../E2E_ERRORS.md)
- 배포: `Dockerfile.migrate` (컨테이너에서 `apply-all.sh` 실행)

## 변경

- 2026-08-26 — `06_company_seed.sql` 신설(신규 업체 개설 정본). 소스가 안 쓰는 표 18개와
  삭제된 화면에 딸린 양식 27종을 걷어냈다(표 71→53, 양식 73→46).
  SP 안에 박혀 있던 양식코드 정규식 2곳을 `doc_kind` 기준으로 바꿨다 —
  그동안 `hwp_sys_028`~`038` 11종이 목록에서 안 보였다.
- 2026-08-25 — 번호 마이그레이션 133본을 5본으로 접었다. SP 152본을 `CREATE OR REPLACE` 로 바꿔
  재적용이 되게 했다. 공통코드를 UPPER_SNAKE 로 통일했다.
