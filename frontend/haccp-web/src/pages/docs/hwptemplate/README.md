# 사용양식 관리 (`hwp-template-management`)

정본 파이프라인 요약은 상위 [`pages/docs/README.md`](../README.md) 1장.

## 파일

| 파일 | 책임 |
|---|---|
| `HwpTemplateManagementPage.tsx` | 렌더·상태·API·미리보기. 목록은 신규/저장/삭제, 파일 버튼은 미리보기 헤더 |
| `HwpTemplateManagementRule.ts` | `SCRN_CD` · `PERSIST_ID` · `SPLIT_KEY` · `FILE_HIST_PERSIST_ID` · `SRC_TY_MAIN_CD` · `LIST_GRID_RULES` · `buildListColumns` · `buildFileHistColumns` · `buildButtonState` |
| `HwpTemplateFileHistModal.tsx` | 불러오기 팝업 — 코드조회와 같은 보라 헤더·파일명/src-ty 검색행·MesDataGrid·라디오 1건. 공통 모달에 넣지 않음 |

## 화면 규칙

- 구분(시스템/자사)은 서버가 정하고 badge 표시 전용. 문구는 공통코드 관리 `sys-yn`. 신규는 항상 자사양식
- 시스템양식은 플랫폼 카탈로그 예제 전부(html 전용 화면 양식 포함)가 조회된다. SP는 `87_migrate_hwp_template_list_all.sql`(Jenkins migrate 안 함, DBeaver/수동)
- `tmplCd` 는 신규도 잠금. 사용자추가는 `hwp_usr_NNN` 자동 채번
- 파일 기능은 구분과 무관. 삭제만 자사양식(+ 신규 draft) 허용
- 업로드는 덮어쓰지 않고 버전 1건을 쌓는다
- 불러오기 구분 콤보·열은 공통코드 `src-ty`(기본양식/사용자양식). 시드 `88_migrate_src_ty_code.sql`(Jenkins migrate 안 함, DBeaver/수동)

## API · SP · 테이블

| 동작 | API | SP | 테이블 |
|---|---|---|---|
| 목록 | `hwpTemplateApi.listHwpTemplates` | `sp_hwp_template_management_r_000` | `tbl_company_template` `tbl_template` |
| 저장 | `hwpTemplateApi.saveHwpTemplate` | `sp_hwp_template_management_c_000` | `tbl_company_template` `tbl_template` |
| 파일이력 | `hwpTemplateApi.listHwpTemplateFiles` | `sp_hwp_template_management_file_r_000` | `tbl_company_template_file` |
| 불러오기/초기화 | `hwpTemplateApi.applyHwpTemplateFile` | `sp_hwp_template_management_current_u_000` | `tbl_company_template` `tbl_company_template_file` |
| 업로드 | `documentApi.saveHwpTemplateForm` | `sp_hwp_template_management_file_c_000` | `tbl_company_template_file` |
| 내보내기 | `documentApi.loadHwpTemplateFile` | (파일 볼륨 읽기, SP 없음) | `HaccpTemplates` / `CustomTemplates` |
| 삭제 검증 | `workflowApi.validateDeleteCompanyTemplates` | `sp_tbl_company_template_delete_blocker_r_000` | `tbl_company_template` |
| 삭제 | `workflowApi.deleteCompanyTemplates` | `sp_tbl_company_template_d_000` | `tbl_company_template` |

삭제는 `/api/v1/bas/company-templates/*` — 법적서류와 URL 공유. 그 메뉴 분할 때 이전.

## pref 키

`scrnCd = hwp-template-management` · `persistId = hwp-template-management-list` · 불러오기 팝업 `hwp-template-file-hist` · split `haccp-split-hwp-template` — 값 변경 금지.
