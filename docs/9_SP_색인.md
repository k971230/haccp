# 9. SP 색인 — 매퍼에서 표까지

> 개발자: 박승우 · 일자: 2026-09-03
> `db_sasshaccp/01_sp.sql` 의 정의와 `backend/haccp-api/src/main/resources/mapper` 의 호출을 맞춰 뽑았다.

**「이 화면을 고치면 어느 표가 움직이나」를 검색 없이 알려는 표다.**
화면에서 출발할 때는 [`3_화면_지도.md`](3_화면_지도.md), 태그에서 출발할 때는
[`5_PIPELINE_색인.md`](5_PIPELINE_색인.md) 를 본다. 여기는 **매퍼에서 출발**한다.

**손으로 고치지 않는다.** SP 를 더하거나 매퍼를 옮긴 뒤 다시 뽑는다.

```sh
node scripts/gen_sp_index.mjs           # 다시 만든다
node scripts/gen_sp_index.mjs --check   # 어긋나면 실패한다 (CI)
```

표 칸은 SP 본문이 `FROM`·`JOIN`·`INSERT INTO`·`UPDATE` 로 건드리는 `tbl_*` 다.
읽기와 쓰기를 가리지 않는다 — **그 표를 고치면 이 SP 가 영향을 받는다**는 뜻이다.

## 어긋난 자리

**정의 없는 호출 없음.** 매퍼가 부르는 SP 는 전부 `01_sp.sql` 에 있다.

**아무도 안 부르는 SP 없음.**

## 매퍼 → SP → 표 (150건)

| 도메인 | SP | 종류 | 매퍼 | 건드리는 표 |
|---|---|---|---|---|
| auth | `sp_role_management_screen_r_000` | 조회 | `auth/AuthMapper.xml<br>sys/code/role/RoleMgmtMapper.xml` | `tbl_role_screen<br>tbl_screen` |
| auth | `sp_tbl_login_log_c_000` | 쓰기 | `auth/AuthMapper.xml` | `tbl_login_log` |
| auth | `sp_tbl_login_log_u_000` | 쓰기 | `auth/AuthMapper.xml` | `tbl_login_log` |
| auth | `sp_tbl_user_login_r_000` | 조회 | `auth/AuthMapper.xml` | `tbl_company<br>tbl_dept<br>tbl_role<br>tbl_user` |
| auth | `sp_tbl_user_login_u_000` | 쓰기 | `auth/AuthMapper.xml` | `tbl_user` |
| code | `sp_common_code_management_r_001` | 조회 | `code/CodeMapper.xml<br>sys/code/commoncode/CommonCodeMapper.xml` | `tbl_code` |
| docs/documents | `sp_hwp_template_management_file_c_000` | 쓰기 | `docs/documents/DocumentMapper.xml` | `tbl_company_template<br>tbl_company_template_file` |
| docs/documents | `sp_tbl_document_appr_hist_r_000` | 조회 | `docs/documents/DocumentMapper.xml` | `tbl_company_template<br>tbl_corrective_action<br>tbl_document<br>tbl_document_approval<br>tbl_document_file<br>tbl_template<br>tbl_user` |
| docs/documents | `sp_tbl_document_appr_inbox_r_000` | 조회 | `docs/documents/DocumentMapper.xml` | `tbl_company_template<br>tbl_corrective_action<br>tbl_document<br>tbl_document_approval<br>tbl_document_file<br>tbl_template<br>tbl_user` |
| docs/documents | `sp_tbl_document_approval_c_000` | 쓰기 | `docs/documents/DocumentMapper.xml` | `tbl_approval_line_step<br>tbl_document<br>tbl_document_approval<br>tbl_document_file<br>tbl_document_version<br>tbl_user` |
| docs/documents | `sp_tbl_document_approval_r_000` | 조회 | `docs/documents/DocumentMapper.xml` | `tbl_document_approval<br>tbl_user` |
| docs/documents | `sp_tbl_document_approval_u_000` | 쓰기 | `docs/documents/DocumentMapper.xml` | `tbl_approval_line_step<br>tbl_document<br>tbl_document_approval<br>tbl_document_version` |
| docs/documents | `sp_tbl_document_d_000` | 쓰기 | `docs/documents/DocumentMapper.xml` | `tbl_document<br>tbl_document_approval<br>tbl_document_file<br>tbl_document_version` |
| docs/documents | `sp_tbl_document_delete_blocker_r_000` | 조회 | `docs/documents/DocumentMapper.xml<br>draft/ccpmonitoring/CcpLogDraftMapper.xml<br>draft/ccpmonitoring/CcpMtlDraftMapper.xml<br>draft/html/HtmlDraftMapper.xml` | `tbl_document` |
| docs/documents | `sp_tbl_document_file_c_000` | 조회 | `docs/documents/DocumentMapper.xml` | `tbl_document<br>tbl_document_file` |
| docs/documents | `sp_tbl_document_file_d_000` | 쓰기 | `docs/documents/DocumentMapper.xml` | `tbl_document<br>tbl_document_file` |
| docs/documents | `sp_tbl_document_file_d_001` | 쓰기 | `docs/documents/DocumentMapper.xml` | `tbl_document<br>tbl_document_file` |
| docs/documents | `sp_tbl_document_file_r_000` | 조회 | `docs/documents/DocumentMapper.xml` | `tbl_document_file` |
| docs/documents | `sp_tbl_document_file_r_001` | 조회 | `docs/documents/DocumentMapper.xml` | `tbl_document<br>tbl_document_file` |
| docs/documents | `sp_tbl_document_r_000` | 조회 | `docs/documents/DocumentMapper.xml` | `tbl_company_template<br>tbl_corrective_action<br>tbl_document<br>tbl_document_file<br>tbl_template<br>tbl_user` |
| docs/documents | `sp_tbl_document_r_001` | 조회 | `docs/documents/DocumentMapper.xml` | `tbl_company_template<br>tbl_document<br>tbl_template<br>tbl_user` |
| docs/documents | `sp_tbl_document_template_r_000` | 조회 | `docs/documents/DocumentMapper.xml<br>draft/hwpdoc/HwpDraftMapper.xml` | `tbl_company_template<br>tbl_template` |
| docs/documents | `sp_tbl_document_template_r_001` | 조회 | `docs/documents/DocumentMapper.xml` | `tbl_company_template<br>tbl_template` |
| docs/documents | `sp_tbl_document_title_u_000` | 쓰기 | `docs/documents/DocumentMapper.xml` | `tbl_document` |
| docs/documents | `sp_tbl_document_u_001` | 쓰기 | `docs/documents/DocumentMapper.xml` | `tbl_document` |
| docs/documents | `sp_tbl_document_version_r_000` | 조회 | `docs/documents/DocumentMapper.xml` | `tbl_document_version` |
| docs/documents | `sp_tbl_hwp_document_c_000` | 조회 | `docs/documents/DocumentMapper.xml` | `tbl_company_template<br>tbl_document<br>tbl_template` |
| docs/htmlform/ccphtgtemplate | `sp_tbl_tml_ccp_htg_ver_apply_u_000` | 쓰기 | `docs/htmlform/ccphtgtemplate/CcpHtgTemplateMapper.xml` | `tbl_tml_ccp_htg_ver` |
| docs/htmlform/ccphtgtemplate | `sp_tbl_tml_ccp_htg_ver_copy_c_000` | 조회 | `docs/htmlform/ccphtgtemplate/CcpHtgTemplateMapper.xml` | `tbl_check_item<br>tbl_company_template<br>tbl_template<br>tbl_tml_ccp_htg_ver<br>tbl_tml_ccp_htg_ver_item` |
| docs/htmlform/ccphtgtemplate | `sp_tbl_tml_ccp_htg_ver_d_000` | 쓰기 | `docs/htmlform/ccphtgtemplate/CcpHtgTemplateMapper.xml` | `tbl_company_template<br>tbl_schedule_rule<br>tbl_schedule_rule_detail<br>tbl_tml_ccp_htg_ver` |
| docs/htmlform/ccphtgtemplate | `sp_tbl_tml_ccp_htg_ver_delete_blocker_r_000` | 조회 | `docs/htmlform/ccphtgtemplate/CcpHtgTemplateMapper.xml` | `tbl_document<br>tbl_schedule_task<br>tbl_tml_ccp_htg_ver` |
| docs/htmlform/ccphtgtemplate | `sp_tbl_tml_ccp_htg_ver_item_r_000` | 조회 | `docs/htmlform/ccphtgtemplate/CcpHtgTemplateMapper.xml<br>draft/ccpmonitoring/CcpLogDraftMapper.xml` | `tbl_check_item<br>tbl_tml_ccp_htg_ver_item` |
| docs/htmlform/ccphtgtemplate | `sp_tbl_tml_ccp_htg_ver_item_u_000` | 쓰기 | `docs/htmlform/ccphtgtemplate/CcpHtgTemplateMapper.xml` | `tbl_tml_ccp_htg_ver<br>tbl_tml_ccp_htg_ver_item` |
| docs/htmlform/ccphtgtemplate | `sp_tbl_tml_ccp_htg_ver_nm_u_000` | 쓰기 | `docs/htmlform/ccphtgtemplate/CcpHtgTemplateMapper.xml` | `tbl_company_template<br>tbl_template<br>tbl_tml_ccp_htg_ver` |
| docs/htmlform/ccphtgtemplate | `sp_tbl_tml_ccp_htg_ver_r_000` | 조회 | `docs/htmlform/ccphtgtemplate/CcpHtgTemplateMapper.xml<br>draft/ccpmonitoring/CcpLogDraftMapper.xml` | `tbl_company_template<br>tbl_tml_ccp_htg_ver<br>tbl_user` |
| docs/htmlform/ccpmtltemplate | `sp_tbl_tml_ccp_mtl_ver_apply_u_000` | 쓰기 | `docs/htmlform/ccpmtltemplate/CcpMtlTemplateMapper.xml` | `tbl_tml_ccp_mtl_ver` |
| docs/htmlform/ccpmtltemplate | `sp_tbl_tml_ccp_mtl_ver_copy_c_000` | 조회 | `docs/htmlform/ccpmtltemplate/CcpMtlTemplateMapper.xml` | `tbl_check_item<br>tbl_company_template<br>tbl_template<br>tbl_tml_ccp_mtl_ver<br>tbl_tml_ccp_mtl_ver_item` |
| docs/htmlform/ccpmtltemplate | `sp_tbl_tml_ccp_mtl_ver_d_000` | 쓰기 | `docs/htmlform/ccpmtltemplate/CcpMtlTemplateMapper.xml` | `tbl_company_template<br>tbl_schedule_rule<br>tbl_schedule_rule_detail<br>tbl_tml_ccp_mtl_ver` |
| docs/htmlform/ccpmtltemplate | `sp_tbl_tml_ccp_mtl_ver_delete_blocker_r_000` | 조회 | `docs/htmlform/ccpmtltemplate/CcpMtlTemplateMapper.xml` | `tbl_document<br>tbl_schedule_task<br>tbl_tml_ccp_mtl_ver` |
| docs/htmlform/ccpmtltemplate | `sp_tbl_tml_ccp_mtl_ver_item_r_000` | 조회 | `docs/htmlform/ccpmtltemplate/CcpMtlTemplateMapper.xml<br>draft/ccpmonitoring/CcpMtlDraftMapper.xml` | `tbl_check_item<br>tbl_tml_ccp_mtl_ver_item` |
| docs/htmlform/ccpmtltemplate | `sp_tbl_tml_ccp_mtl_ver_item_u_000` | 쓰기 | `docs/htmlform/ccpmtltemplate/CcpMtlTemplateMapper.xml` | `tbl_tml_ccp_mtl_ver<br>tbl_tml_ccp_mtl_ver_item` |
| docs/htmlform/ccpmtltemplate | `sp_tbl_tml_ccp_mtl_ver_nm_u_000` | 쓰기 | `docs/htmlform/ccpmtltemplate/CcpMtlTemplateMapper.xml` | `tbl_company_template<br>tbl_template<br>tbl_tml_ccp_mtl_ver` |
| docs/htmlform/ccpmtltemplate | `sp_tbl_tml_ccp_mtl_ver_r_000` | 조회 | `docs/htmlform/ccpmtltemplate/CcpMtlTemplateMapper.xml<br>draft/ccpmonitoring/CcpMtlDraftMapper.xml` | `tbl_company_template<br>tbl_tml_ccp_mtl_ver<br>tbl_user` |
| docs/htmlform/ccppkgtemplate | `sp_tbl_tml_ccp_pkg_ver_apply_u_000` | 쓰기 | `docs/htmlform/ccppkgtemplate/CcpPkgTemplateMapper.xml` | `tbl_tml_ccp_pkg_ver` |
| docs/htmlform/ccppkgtemplate | `sp_tbl_tml_ccp_pkg_ver_copy_c_000` | 조회 | `docs/htmlform/ccppkgtemplate/CcpPkgTemplateMapper.xml` | `tbl_check_item<br>tbl_company_template<br>tbl_template<br>tbl_tml_ccp_pkg_ver<br>tbl_tml_ccp_pkg_ver_item` |
| docs/htmlform/ccppkgtemplate | `sp_tbl_tml_ccp_pkg_ver_d_000` | 쓰기 | `docs/htmlform/ccppkgtemplate/CcpPkgTemplateMapper.xml` | `tbl_company_template<br>tbl_schedule_rule<br>tbl_schedule_rule_detail<br>tbl_tml_ccp_pkg_ver` |
| docs/htmlform/ccppkgtemplate | `sp_tbl_tml_ccp_pkg_ver_delete_blocker_r_000` | 조회 | `docs/htmlform/ccppkgtemplate/CcpPkgTemplateMapper.xml` | `tbl_document<br>tbl_schedule_task<br>tbl_tml_ccp_pkg_ver` |
| docs/htmlform/ccppkgtemplate | `sp_tbl_tml_ccp_pkg_ver_item_r_000` | 조회 | `docs/htmlform/ccppkgtemplate/CcpPkgTemplateMapper.xml<br>draft/ccpmonitoring/CcpLogDraftMapper.xml` | `tbl_check_item<br>tbl_tml_ccp_pkg_ver_item` |
| docs/htmlform/ccppkgtemplate | `sp_tbl_tml_ccp_pkg_ver_item_u_000` | 쓰기 | `docs/htmlform/ccppkgtemplate/CcpPkgTemplateMapper.xml` | `tbl_tml_ccp_pkg_ver<br>tbl_tml_ccp_pkg_ver_item` |
| docs/htmlform/ccppkgtemplate | `sp_tbl_tml_ccp_pkg_ver_nm_u_000` | 쓰기 | `docs/htmlform/ccppkgtemplate/CcpPkgTemplateMapper.xml` | `tbl_company_template<br>tbl_template<br>tbl_tml_ccp_pkg_ver` |
| docs/htmlform/ccppkgtemplate | `sp_tbl_tml_ccp_pkg_ver_r_000` | 조회 | `docs/htmlform/ccppkgtemplate/CcpPkgTemplateMapper.xml<br>draft/ccpmonitoring/CcpLogDraftMapper.xml` | `tbl_company_template<br>tbl_tml_ccp_pkg_ver<br>tbl_user` |
| docs/htmlform/ccpverifytemplate | `sp_tbl_tml_ccp_chk_ver_apply_u_000` | 쓰기 | `docs/htmlform/ccpverifytemplate/CcpVerifyTemplateMapper.xml` | `tbl_tml_ccp_chk_ver` |
| docs/htmlform/ccpverifytemplate | `sp_tbl_tml_ccp_chk_ver_copy_c_000` | 조회 | `docs/htmlform/ccpverifytemplate/CcpVerifyTemplateMapper.xml` | `tbl_check_item<br>tbl_company_template<br>tbl_template<br>tbl_tml_ccp_chk_ver<br>tbl_tml_ccp_chk_ver_item` |
| docs/htmlform/ccpverifytemplate | `sp_tbl_tml_ccp_chk_ver_d_000` | 쓰기 | `docs/htmlform/ccpverifytemplate/CcpVerifyTemplateMapper.xml` | `tbl_company_template<br>tbl_schedule_rule<br>tbl_schedule_rule_detail<br>tbl_tml_ccp_chk_ver` |
| docs/htmlform/ccpverifytemplate | `sp_tbl_tml_ccp_chk_ver_delete_blocker_r_000` | 조회 | `docs/htmlform/ccpverifytemplate/CcpVerifyTemplateMapper.xml` | `tbl_document<br>tbl_schedule_task<br>tbl_tml_ccp_chk_ver` |
| docs/htmlform/ccpverifytemplate | `sp_tbl_tml_ccp_chk_ver_item_r_000` | 조회 | `docs/htmlform/ccpverifytemplate/CcpVerifyTemplateMapper.xml` | `tbl_check_item<br>tbl_tml_ccp_chk_ver_item` |
| docs/htmlform/ccpverifytemplate | `sp_tbl_tml_ccp_chk_ver_item_u_000` | 쓰기 | `docs/htmlform/ccpverifytemplate/CcpVerifyTemplateMapper.xml` | `tbl_tml_ccp_chk_ver<br>tbl_tml_ccp_chk_ver_item` |
| docs/htmlform/ccpverifytemplate | `sp_tbl_tml_ccp_chk_ver_nm_u_000` | 쓰기 | `docs/htmlform/ccpverifytemplate/CcpVerifyTemplateMapper.xml` | `tbl_company_template<br>tbl_template<br>tbl_tml_ccp_chk_ver` |
| docs/htmlform/ccpverifytemplate | `sp_tbl_tml_ccp_chk_ver_r_000` | 조회 | `docs/htmlform/ccpverifytemplate/CcpVerifyTemplateMapper.xml<br>draft/html/HtmlDraftMapper.xml` | `tbl_company_template<br>tbl_tml_ccp_chk_ver<br>tbl_user` |
| docs/htmlform/htmltemplate | `sp_tbl_html_hyg_prc_ver_apply_u_000` | 쓰기 | `docs/htmlform/htmltemplate/HtmlTemplateMapper.xml` | `tbl_html_hyg_prc_ver` |
| docs/htmlform/htmltemplate | `sp_tbl_html_hyg_prc_ver_copy_c_000` | 조회 | `docs/htmlform/htmltemplate/HtmlTemplateMapper.xml` | `tbl_check_item<br>tbl_company_template<br>tbl_html_hyg_prc_ver<br>tbl_html_hyg_prc_ver_item<br>tbl_template` |
| docs/htmlform/htmltemplate | `sp_tbl_html_hyg_prc_ver_d_000` | 쓰기 | `docs/htmlform/htmltemplate/HtmlTemplateMapper.xml` | `tbl_company_template<br>tbl_html_hyg_prc_ver<br>tbl_schedule_rule<br>tbl_schedule_rule_detail` |
| docs/htmlform/htmltemplate | `sp_tbl_html_hyg_prc_ver_delete_blocker_r_000` | 조회 | `docs/htmlform/htmltemplate/HtmlTemplateMapper.xml` | `tbl_document<br>tbl_html_hyg_prc_ver<br>tbl_schedule_task` |
| docs/htmlform/htmltemplate | `sp_tbl_html_hyg_prc_ver_item_r_000` | 조회 | `docs/htmlform/htmltemplate/HtmlTemplateMapper.xml` | `tbl_check_item<br>tbl_html_hyg_prc_ver_item` |
| docs/htmlform/htmltemplate | `sp_tbl_html_hyg_prc_ver_item_u_000` | 쓰기 | `docs/htmlform/htmltemplate/HtmlTemplateMapper.xml` | `tbl_html_hyg_prc_ver<br>tbl_html_hyg_prc_ver_item` |
| docs/htmlform/htmltemplate | `sp_tbl_html_hyg_prc_ver_nm_u_000` | 쓰기 | `docs/htmlform/htmltemplate/HtmlTemplateMapper.xml` | `tbl_company_template<br>tbl_html_hyg_prc_ver<br>tbl_template` |
| docs/htmlform/htmltemplate | `sp_tbl_html_hyg_prc_ver_r_000` | 조회 | `docs/htmlform/htmltemplate/HtmlTemplateMapper.xml<br>draft/html/HtmlDraftMapper.xml` | `tbl_company_template<br>tbl_html_hyg_prc_ver<br>tbl_user` |
| docs/hwp | `sp_hwp_template_management_c_000` | 쓰기 | `docs/hwp/HwpTemplateMapper.xml` | `tbl_company_template<br>tbl_doc_no_rule<br>tbl_template` |
| docs/hwp | `sp_hwp_template_management_current_u_000` | 쓰기 | `docs/hwp/HwpTemplateMapper.xml` | `tbl_company_template<br>tbl_company_template_file` |
| docs/hwp | `sp_hwp_template_management_file_r_000` | 조회 | `docs/hwp/HwpTemplateMapper.xml` | `tbl_company_template<br>tbl_company_template_file` |
| docs/hwp | `sp_hwp_template_management_r_000` | 조회 | `docs/hwp/HwpTemplateMapper.xml` | `tbl_company_template<br>tbl_company_template_file<br>tbl_template` |
| docs/hwp | `sp_tbl_company_template_d_000` | 쓰기 | `docs/hwp/HwpTemplateMapper.xml` | `tbl_company_template<br>tbl_company_template_file<br>tbl_document<br>tbl_template` |
| docs/hwp | `sp_tbl_company_template_delete_blocker_r_000` | 조회 | `docs/hwp/HwpTemplateMapper.xml` | `tbl_company_template<br>tbl_document` |
| docs/sch | `sp_schedule_cycle_management_c_000` | 쓰기 | `docs/sch/DocCycleMapper.xml` | `tbl_approval_line<br>tbl_company_template<br>tbl_schedule_rule<br>tbl_schedule_rule_detail` |
| docs/sch | `sp_schedule_cycle_management_d_000` | 쓰기 | `docs/sch/DocCycleMapper.xml` | `tbl_schedule_rule<br>tbl_schedule_rule_detail<br>tbl_schedule_task` |
| docs/sch | `sp_schedule_cycle_management_form_r_000` | 조회 | `docs/sch/DocCycleMapper.xml` | `tbl_approval_line<br>tbl_company_template<br>tbl_schedule_rule<br>tbl_template` |
| docs/sch | `sp_schedule_cycle_management_r_000` | 조회 | `docs/sch/DocCycleMapper.xml` | `tbl_approval_line<br>tbl_company_template<br>tbl_dept<br>tbl_schedule_rule<br>tbl_schedule_rule_detail<br>tbl_template<br>tbl_user` |
| docs/sch | `sp_tbl_notification_task_c_000` | 쓰기 | `docs/sch/DocCycleMapper.xml` | `tbl_company_template<br>tbl_login_log<br>tbl_notification<br>tbl_schedule_task<br>tbl_template<br>tbl_user` |
| docs/sch | `sp_tbl_schedule_rule_active_r_000` | 조회 | `docs/sch/DocCycleMapper.xml` | `tbl_company_template<br>tbl_schedule_rule<br>tbl_schedule_rule_detail` |
| docs/sch | `sp_tbl_schedule_task_regen_c_000` | 쓰기 | `docs/sch/DocCycleMapper.xml` | `tbl_schedule_task` |
| draft | `sp_tbl_document_paper_stamp_r_000` | 조회 | `draft/DraftPaperStampMapper.xml` | `tbl_document<br>tbl_document_approval<br>tbl_user` |
| draft/ccpmonitoring | `sp_ccp_log_r_000` | 조회 | `draft/ccpmonitoring/CcpLogDraftMapper.xml` | `tbl_ccp_generic_monitor<br>tbl_ccp_generic_monitor_row<br>tbl_company_template<br>tbl_document<br>tbl_template<br>tbl_user` |
| draft/ccpmonitoring | `sp_ccp_mtl_r_000` | 조회 | `draft/ccpmonitoring/CcpMtlDraftMapper.xml` | `tbl_ccp_metal_monitor<br>tbl_ccp_metal_sens_row<br>tbl_company_template<br>tbl_document<br>tbl_template<br>tbl_user` |
| draft/ccpmonitoring | `sp_tbl_ccp_generic_monitor_c_000` | 조회 | `draft/ccpmonitoring/CcpLogDraftMapper.xml` | `tbl_ccp_generic_monitor<br>tbl_ccp_generic_monitor_cell<br>tbl_ccp_generic_monitor_row<br>tbl_company_template<br>tbl_doc_no_rule<br>tbl_document<br>tbl_template<br>tbl_user` |
| draft/ccpmonitoring | `sp_tbl_ccp_generic_monitor_d_000` | 쓰기 | `draft/ccpmonitoring/CcpLogDraftMapper.xml` | `tbl_ccp_generic_monitor<br>tbl_ccp_generic_monitor_cell<br>tbl_ccp_generic_monitor_row<br>tbl_corrective_action<br>tbl_document<br>tbl_document_approval<br>tbl_document_file` |
| draft/ccpmonitoring | `sp_tbl_ccp_generic_monitor_r_000` | 조회 | `draft/ccpmonitoring/CcpLogDraftMapper.xml` | `tbl_ccp_generic_monitor<br>tbl_ccp_generic_monitor_cell<br>tbl_ccp_generic_monitor_row<br>tbl_document` |
| draft/ccpmonitoring | `sp_tbl_ccp_metal_monitor_c_000` | 조회 | `draft/ccpmonitoring/CcpMtlDraftMapper.xml` | `tbl_ccp_metal_monitor<br>tbl_ccp_metal_pass_row<br>tbl_ccp_metal_sens_row<br>tbl_company_template<br>tbl_doc_no_rule<br>tbl_document<br>tbl_template` |
| draft/ccpmonitoring | `sp_tbl_ccp_metal_monitor_d_000` | 쓰기 | `draft/ccpmonitoring/CcpMtlDraftMapper.xml` | `tbl_ccp_metal_monitor<br>tbl_ccp_metal_pass_row<br>tbl_ccp_metal_sens_row<br>tbl_corrective_action<br>tbl_document<br>tbl_document_approval<br>tbl_document_file` |
| draft/ccpmonitoring | `sp_tbl_ccp_metal_monitor_r_001` | 조회 | `draft/ccpmonitoring/CcpMtlDraftMapper.xml` | `tbl_ccp_metal_monitor<br>tbl_document` |
| draft/ccpmonitoring | `sp_tbl_ccp_metal_monitor_r_002` | 조회 | `draft/ccpmonitoring/CcpMtlDraftMapper.xml` | `tbl_ccp_metal_sens_row` |
| draft/ccpmonitoring | `sp_tbl_ccp_metal_monitor_r_003` | 조회 | `draft/ccpmonitoring/CcpMtlDraftMapper.xml` | `tbl_ccp_metal_pass_row` |
| draft/html | `sp_ccp_verify_c_000` | 조회 | `draft/html/HtmlDraftMapper.xml` | `tbl_ccp_verify_check<br>tbl_ccp_verify_item<br>tbl_company_template<br>tbl_doc_no_rule<br>tbl_document<br>tbl_template` |
| draft/html | `sp_ccp_verify_d_000` | 쓰기 | `draft/html/HtmlDraftMapper.xml` | `tbl_ccp_verify_check<br>tbl_ccp_verify_item<br>tbl_corrective_action<br>tbl_document<br>tbl_document_approval<br>tbl_document_file` |
| draft/html | `sp_ccp_verify_r_000` | 조회 | `draft/html/HtmlDraftMapper.xml` | `tbl_ccp_verify_check<br>tbl_ccp_verify_item<br>tbl_company_template<br>tbl_document<br>tbl_template<br>tbl_user` |
| draft/html | `sp_ccp_verify_r_001` | 조회 | `draft/html/HtmlDraftMapper.xml` | `tbl_ccp_verify_check<br>tbl_ccp_verify_item<br>tbl_company_template<br>tbl_document<br>tbl_document_approval<br>tbl_template<br>tbl_tml_ccp_chk_ver<br>tbl_tml_ccp_chk_ver_item<br>tbl_user` |
| draft/html | `sp_ccp_verify_sign_u_000` | 쓰기 | `draft/html/HtmlDraftMapper.xml` | `tbl_ccp_verify_check<br>tbl_user` |
| draft/html | `sp_tbl_hyg_process_c_000` | 조회 | `draft/html/HtmlDraftMapper.xml` | `tbl_company_template<br>tbl_doc_no_rule<br>tbl_document<br>tbl_hyg_process<br>tbl_hyg_process_item<br>tbl_template` |
| draft/html | `sp_tbl_hyg_process_d_000` | 쓰기 | `draft/html/HtmlDraftMapper.xml` | `tbl_corrective_action<br>tbl_document<br>tbl_document_approval<br>tbl_document_file<br>tbl_hyg_process<br>tbl_hyg_process_item` |
| draft/html | `sp_tbl_hyg_process_r_000` | 조회 | `draft/html/HtmlDraftMapper.xml` | `tbl_company_template<br>tbl_document<br>tbl_hyg_process<br>tbl_hyg_process_item<br>tbl_template<br>tbl_user` |
| draft/html | `sp_tbl_hyg_process_r_001` | 조회 | `draft/html/HtmlDraftMapper.xml` | `tbl_check_item<br>tbl_company_template<br>tbl_document<br>tbl_document_approval<br>tbl_html_form_ver<br>tbl_html_form_ver_item<br>tbl_html_hyg_prc_ver<br>tbl_html_hyg_prc_ver_item<br>tbl_hyg_process<br>tbl_hyg_process_item<br>tbl_template<br>tbl_user` |
| draft/html | `sp_tbl_hyg_process_sign_u_000` | 쓰기 | `draft/html/HtmlDraftMapper.xml` | `tbl_hyg_process<br>tbl_user` |
| draft/hwpdoc | `sp_draft_hwp_r_000` | 조회 | `draft/hwpdoc/HwpDraftMapper.xml` | `tbl_company_template<br>tbl_corrective_action<br>tbl_document<br>tbl_document_file<br>tbl_template<br>tbl_user` |
| draft/hwpdoc | `sp_draft_hwp_task_r_000` | 조회 | `draft/hwpdoc/HwpDraftMapper.xml` | `tbl_company_template<br>tbl_schedule_task<br>tbl_template` |
| flow/ca | `sp_tbl_corrective_action_c_000` | 쓰기 | `flow/ca/CorrectiveActionMapper.xml` | `tbl_corrective_action` |
| flow/ca | `sp_tbl_corrective_action_d_000` | 쓰기 | `flow/ca/CorrectiveActionMapper.xml` | `tbl_corrective_action` |
| flow/ca | `sp_tbl_corrective_action_r_000` | 조회 | `flow/ca/CorrectiveActionMapper.xml` | `tbl_company_template<br>tbl_corrective_action<br>tbl_document<br>tbl_template<br>tbl_user` |
| flow/ca | `sp_tbl_doc_corrective_r_000` | 조회 | `flow/ca/DocCorrectiveMapper.xml` | `tbl_corrective_action` |
| flow/ca | `sp_tbl_doc_corrective_u_000` | 쓰기 | `flow/ca/DocCorrectiveMapper.xml` | `tbl_corrective_action` |
| log | `sp_tbl_view_log_c_000` | 쓰기 | `log/LogMapper.xml` | `tbl_view_log` |
| log | `sp_tbl_view_stat_daily_c_000` | 쓰기 | `log/LogMapper.xml` | `tbl_view_log<br>tbl_view_stat_daily` |
| menu | `sp_menu_nav_r_000` | 조회 | `menu/MenuMapper.xml` | `tbl_menu<br>tbl_role_screen<br>tbl_screen` |
| pref | `sp_tbl_grid_pref_c_000` | 쓰기 | `pref/PrefMapper.xml` | `tbl_grid_pref` |
| pref | `sp_tbl_grid_pref_r_000` | 조회 | `pref/PrefMapper.xml` | `tbl_grid_pref` |
| sys/code/approvalline | `sp_tbl_approval_line_c_000` | 쓰기 | `sys/code/approvalline/ApprovalLineMapper.xml` | `tbl_approval_line<br>tbl_approval_line_step` |
| sys/code/approvalline | `sp_tbl_approval_line_d_000` | 쓰기 | `sys/code/approvalline/ApprovalLineMapper.xml` | `tbl_approval_line<br>tbl_approval_line_step<br>tbl_company_template<br>tbl_document` |
| sys/code/approvalline | `sp_tbl_approval_line_delete_blocker_r_000` | 조회 | `sys/code/approvalline/ApprovalLineMapper.xml` | `tbl_company_template<br>tbl_document` |
| sys/code/approvalline | `sp_tbl_approval_line_r_000` | 조회 | `sys/code/approvalline/ApprovalLineMapper.xml` | `tbl_approval_line<br>tbl_approval_line_step<br>tbl_dept<br>tbl_user` |
| sys/code/commoncode | `sp_common_code_management_c_000` | 쓰기 | `sys/code/commoncode/CommonCodeMapper.xml` | `tbl_code` |
| sys/code/commoncode | `sp_common_code_management_d_000` | 쓰기 | `sys/code/commoncode/CommonCodeMapper.xml` | `tbl_code` |
| sys/code/commoncode | `sp_common_code_management_delete_blocker_r_000` | 조회 | `sys/code/commoncode/CommonCodeMapper.xml` | `tbl_code` |
| sys/code/commoncode | `sp_common_code_management_r_000` | 조회 | `sys/code/commoncode/CommonCodeMapper.xml` | `tbl_code` |
| sys/code/department | `sp_department_management_c_000` | 쓰기 | `sys/code/department/DepartmentMapper.xml` | `tbl_dept` |
| sys/code/department | `sp_department_management_d_000` | 쓰기 | `sys/code/department/DepartmentMapper.xml` | `tbl_dept<br>tbl_user` |
| sys/code/department | `sp_department_management_delete_blocker_r_000` | 조회 | `sys/code/department/DepartmentMapper.xml` | `tbl_dept<br>tbl_user` |
| sys/code/department | `sp_department_management_r_000` | 조회 | `sys/code/department/DepartmentMapper.xml` | `tbl_dept` |
| sys/code/menu | `sp_menu_management_c_000` | 쓰기 | `sys/code/menu/MenuMgmtMapper.xml` | `tbl_menu` |
| sys/code/menu | `sp_menu_management_d_000` | 쓰기 | `sys/code/menu/MenuMgmtMapper.xml` | `tbl_menu` |
| sys/code/menu | `sp_menu_management_delete_blocker_r_000` | 조회 | `sys/code/menu/MenuMgmtMapper.xml` | `tbl_menu` |
| sys/code/menu | `sp_menu_management_r_000` | 조회 | `sys/code/menu/MenuMgmtMapper.xml` | `tbl_menu` |
| sys/code/role | `sp_role_management_c_000` | 쓰기 | `sys/code/role/RoleMgmtMapper.xml` | `tbl_role` |
| sys/code/role | `sp_role_management_d_000` | 쓰기 | `sys/code/role/RoleMgmtMapper.xml` | `tbl_role<br>tbl_role_screen<br>tbl_user` |
| sys/code/role | `sp_role_management_delete_blocker_r_000` | 조회 | `sys/code/role/RoleMgmtMapper.xml` | `tbl_role<br>tbl_user` |
| sys/code/role | `sp_role_management_r_000` | 조회 | `sys/code/role/RoleMgmtMapper.xml` | `tbl_role` |
| sys/code/role | `sp_role_management_screen_c_000` | 쓰기 | `sys/code/role/RoleMgmtMapper.xml` | `tbl_role_screen` |
| sys/code/user | `sp_user_management_c_000` | 쓰기 | `sys/code/user/UserMapper.xml` | `tbl_user` |
| sys/code/user | `sp_user_management_d_000` | 쓰기 | `sys/code/user/UserMapper.xml` | `tbl_grid_pref<br>tbl_user<br>tbl_user_noti_pref` |
| sys/code/user | `sp_user_management_delete_blocker_r_000` | 조회 | `sys/code/user/UserMapper.xml` | `tbl_user` |
| sys/code/user | `sp_user_management_r_000` | 조회 | `sys/code/user/UserMapper.xml` | `tbl_dept<br>tbl_role<br>tbl_user` |
| sys/code/user | `sp_user_management_sign_info_r_000` | 조회 | `sys/code/user/UserMapper.xml` | `tbl_user` |
| sys/code/user | `sp_user_management_sign_r_000` | 조회 | `sys/code/user/UserMapper.xml` | `tbl_user` |
| sys/code/user | `sp_user_management_sign_u_000` | 쓰기 | `sys/code/user/UserMapper.xml` | `tbl_user` |
| sys/logs/auditlog | `sp_audit_log_r_000` | 조회 | `sys/logs/auditlog/AuditLogMapper.xml` | `tbl_audit_log<br>tbl_screen<br>tbl_user` |
| sys/logs/auditlog | `sp_tbl_audit_log_c_000` | 쓰기 | `sys/logs/auditlog/AuditLogMapper.xml` | `tbl_audit_log` |
| sys/logs/loginhistory | `sp_login_history_r_000` | 조회 | `sys/logs/loginhistory/LoginHistoryMapper.xml` | `tbl_login_log<br>tbl_user` |
| sys/logs/screenusage | `sp_screen_usage_statistics_r_000` | 조회 | `sys/logs/screenusage/ScreenUsageMapper.xml` | `tbl_menu<br>tbl_screen<br>tbl_view_stat_daily` |
| tsk | `sp_tbl_notification_r_000` | 조회 | `tsk/TaskMapper.xml` | `tbl_notification` |
| tsk | `sp_tbl_notification_u_000` | 쓰기 | `tsk/TaskMapper.xml` | `tbl_notification` |
| tsk | `sp_tbl_schedule_task_generate_c_000` | 쓰기 | `tsk/TaskMapper.xml` | `tbl_schedule_task` |
| tsk | `sp_tbl_today_task_doc_r_000` | 조회 | `tsk/TaskMapper.xml` | `tbl_company_template<br>tbl_corrective_action<br>tbl_document<br>tbl_document_file<br>tbl_template<br>tbl_user` |
| tsk | `sp_tbl_today_task_r_000` | 조회 | `tsk/TaskMapper.xml` | `tbl_company_template<br>tbl_corrective_action<br>tbl_document<br>tbl_schedule_task<br>tbl_template` |

## 관련

- 화면에서 출발: [`3_화면_지도.md`](3_화면_지도.md)
- 태그에서 출발: [`5_PIPELINE_색인.md`](5_PIPELINE_색인.md)
- SP 규약: [`../db_sasshaccp/README.md`](../db_sasshaccp/README.md)
