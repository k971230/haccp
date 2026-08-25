# 공통코드 관리 (`common-code-management`)

정본 파이프라인 요약은 상위 [`pages/sys/README.md`](../../README.md) 1장.

## 파일

| 파일 | 책임 |
|---|---|
| `CommonCodePage.tsx` | 렌더·상태·API 호출·이벤트. 3그리드(대분류/시스템/사용자) 배치와 검색 헤더 |
| `CommonCodeRule.ts` | `SCRN_CD` · `PERSIST_ID` · 컬럼 팩터리 3종 · `GROUP_RULES`/`SYS_RULES`/`USR_RULES` · `newUsrRow` · `matchGroup` |

## 화면 규칙

- 좌 대분류: 조회 전용 (`sub_cd='*'` 행)
- 우상 시스템 코드(`sys_yn='Y'`): 조회 전용 — 플랫폼 표준이라 업체가 수정·삭제할 수 없고 SP가 다시 막는다
- 우하 사용자 코드(`sys_yn='N'`): CRUD. `mainCd`·`subCd`는 신규 행에서만 입력(`USR_RULES.newOnly`)
- 헤더 검색(대분류코드·대분류명·사용여부)은 전건 조회 후 FE 필터다. 사용여부 기본값은 `DEFAULT_USE_YN`(Y)

## API · SP · 테이블

| 동작 | API (`api/sys/commonCodeApi.ts`) | SP | 테이블 |
|---|---|---|---|
| 대분류 조회 | `listCodeGroups` | `sp_common_code_management_r_000` | `tbl_code` |
| 세부 조회 | `listCodeDetails(mainCd, sysYn)` | `sp_common_code_management_r_001` | `tbl_code` |
| 저장 | `saveCommonCodes` | `sp_common_code_management_c_000` | `tbl_code` |
| 삭제 검증 | `validateDeleteCommonCodes` | `sp_common_code_management_delete_blocker_r_000` | `tbl_code` |
| 삭제 | `deleteCommonCodes` | `sp_common_code_management_d_000` | `tbl_code` |

전역 콤보(`useCommonCodes`)도 `sp_common_code_management_r_001`을 쓰므로 이 SP를 고치면 **전 화면 콤보가 함께 바뀐다**.
사용양식·문서주기 구분 문구(`sys-yn`)도 여기 행이 정본이다. HTML 공정점검 입력유형은 `html-input-ty`, 예/아니오는 `judge-yn`. FE에 별도 formType 파일을 두지 않는다.

조회는 회사코드 완전 격리다(`WHERE c.co_cd = p_co_cd`). 표준코드 `0000`을 상속받지 않으므로 신규 업체는 온보딩 SP(`sp_tbl_company_init_c_000`)가 표준코드를 복제해 넣는다. 기존 업체분은 `db_sasshaccp/02_seed.sql`로 백필했다.

## pref 키

`scrnCd = common-code-management` · `persistId = code-mgmt-group | code-mgmt-sys | code-mgmt-usr` — 값 변경 금지.
