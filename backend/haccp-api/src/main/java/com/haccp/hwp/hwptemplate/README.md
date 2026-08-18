# hwptemplate — 사용양식 관리 (`hwp-template-management`)

화면 1개 = 패키지 1개. 파이프라인 표는 FE `pages/hwp/README.md` 1장 · 이 패키지 상위 `com.haccp.hwp/README.md`.

XML `resources/mapper/hwp/hwptemplate/HwpTemplateMapper.xml` · SP `db_sasshaccp/84_migrate_form_master_type.sql` · `87_migrate_hwp_template_list_all.sql`

## 엔드포인트

| Method | URL | Service | SP | 테이블 |
|---|---|---|---|---|
| GET | `/api/v1/hwp/hwp-templates/list` | `list` | `sp_hwp_template_management_r_000` | `tbl_company_template` `tbl_template` |
| PUT | `/api/v1/hwp/hwp-templates/save` | `save` | `sp_hwp_template_management_c_000` | `tbl_company_template` `tbl_template` |
| GET | `/api/v1/hwp/hwp-templates/files` | `listFiles` | `sp_hwp_template_management_file_r_000` | `tbl_company_template_file` |
| POST | `/api/v1/hwp/hwp-templates/apply-file` | `applyFile` | `sp_hwp_template_management_current_u_000` | `tbl_company_template` `tbl_company_template_file` |
| POST | `/api/v1/doc/templates/{tmplCd}/form` | `doc.TemplateService.saveForm` | `sp_hwp_template_management_file_c_000` | `tbl_company_template_file` |
| GET | `/api/v1/doc/templates/{tmplCd}/form` | 파일 볼륨 읽기 | (SP 없음) | `HaccpTemplates` / `CustomTemplates` |
| POST | `/api/v1/bas/company-templates/validate-delete` | Workflow `validateDelete` | `sp_tbl_company_template_delete_blocker_r_000` | `tbl_company_template` |
| POST | `/api/v1/bas/company-templates/delete` | Workflow `delete` | `sp_tbl_company_template_d_000` | `tbl_company_template` |

| 파일 | 역할 |
|------|------|
| `HwpTemplateController` | `/api/v1/hwp/hwp-templates/{list,save,files,apply-file}` |
| `HwpTemplateService` | 목록·저장·이력·불러오기/초기화. sysYn 무시, 신규는 SP가 usr 강제 |
| `HwpTemplateMapper` | 위 목록·저장·이력·적용 SP |

삭제는 법적서류 업로드도 `/api/v1/bas/company-templates/{validate-delete,delete}` 를 쓰므로 **Workflow에 잔류**한다. 그 메뉴를 손볼 때 이전한다.
파일 업로드 I/O는 `doc/TemplateService.saveForm` 그대로.
목록 SP는 `87_migrate_hwp_template_list_all.sql` — 시스템양식 예제 전부(html 포함). Jenkins migrate 안 함.
