# com.haccp.sys.code.commoncode — 공통코드 관리

화면코드 `common-code-management` · XML `resources/mapper/sys/code/commoncode/CommonCodeMapper.xml` · SP `db_sasshaccp/02_seed.sql`

## 엔드포인트

| Method | URL | Service | SP | 테이블 |
|---|---|---|---|---|
| GET | `/api/v1/sys/code/common-code-management/groups` | `listGroups` | `sp_common_code_management_r_000` | `tbl_code` |
| GET | `/api/v1/sys/code/common-code-management/details?mainCd&sysYn` | `listDetails` | `sp_common_code_management_r_001` | `tbl_code` |
| PUT | `/api/v1/sys/code/common-code-management/save` | `save` | `sp_common_code_management_c_000` | `tbl_code` |
| POST | `/api/v1/sys/code/common-code-management/validate-delete` | `validateDelete` | `sp_common_code_management_delete_blocker_r_000` | `tbl_code` |
| POST | `/api/v1/sys/code/common-code-management/delete` | `delete` | `sp_common_code_management_d_000` | `tbl_code` |

대분류는 `tbl_code` 에서 `sub_cd='*'` 행이다.

## 규칙

- `listDetails`는 `mainCd`가 비면 `BizException`. FE `useCommonCodes`도 `enabled` 가드로 빈 호출을 막는다
- 시스템 코드(`sys_yn='Y'`)는 수정·삭제 불가. FE 잠금과 별개로 SP가 다시 막는다
- `co_cd`는 `LoginUserContext.coCd()`에서만 온다
- 조회는 회사코드 완전 격리다. `WHERE c.co_cd = p_co_cd`만 쓰고 표준코드 `0000`을 병합하지 않는다. 대신 업체 생성 시 표준코드를 복제해 넣는다(`sp_tbl_company_code_copy_c_000`)
- 저장은 `p_co_cd = '0000'`(플랫폼 테넌트)일 때 차단한다. 표준코드는 화면에서 고치지 않는다

## 영향 범위 (주의)

`sp_common_code_management_r_001`은 전역 콤보 경로(`mapper/code/CodeMapper.xml` → `useCommonCodes`)가 함께 쓴다. 전역 조회는 `sys_yn` 구분 없이 전건을 원하므로 빈 문자열을 넘긴다. 시그니처·컬럼을 바꾸면 **모든 화면의 콤보**를 회귀 확인해야 한다.
