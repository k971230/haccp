-- ============================================================
-- 역할 — 스마트 HACCP 공통 CCP·기준일지 관리 화면과 기존 테넌트 메뉴 동기화
--
-- 개발자: 박승우
-- 일자: 2026-08-06
-- 코멘트:
--   1) 신규 공통 CCP 화면과 기준일지 유형 관리 화면을 화면 마스터에 등록한다
--   2) 기존 업체에도 중복 없이 CCP·BAS 메뉴와 관리자 권한을 추가한다
--   3) 기본 양식과 자사 양식은 같은 사용양식 관리 화면에서 분리하므로 별도 메뉴를 만들지 않는다
-- ============================================================

SET search_path TO sasshaccp;

INSERT INTO tbl_screen (scrn_cd, scrn_nm, module_cd, tmpl_cd, sort_no, use_yn, ins_id) VALUES
    ('ccp-generic-monitor', '공통 CCP 모니터링', 'CCP', NULL, 150, 'Y', 'system'),
    ('smart-diary-type-management', '스마트 HACCP 기준일지 유형', 'BAS', NULL, 840, 'Y', 'system')
ON CONFLICT (scrn_cd) DO UPDATE SET
    scrn_nm = EXCLUDED.scrn_nm, module_cd = EXCLUDED.module_cd, tmpl_cd = EXCLUDED.tmpl_cd,
    sort_no = EXCLUDED.sort_no, use_yn = 'Y', upd_id = 'system', upd_dt = now();

-- 신규 업체 초기화 이전에 이미 등록된 회사 — CCP 모듈 부모가 없을 때 생성
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, 'MCCP', '중요관리점', NULL, NULL, 100, 'Y', 'system', now()
  FROM tbl_company c
 WHERE NOT EXISTS (
    SELECT 1 FROM tbl_menu m WHERE m.co_cd = c.co_cd AND m.menu_cd = 'MCCP'
 )
ON CONFLICT (co_cd, menu_cd) DO NOTHING;

-- 공통 CCP 화면 leaf — 양식 선택 후 공정별 문서로 진입한다
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, 'ccp-generic-monitor', '공통 CCP 모니터링', 'MCCP', 'ccp-generic-monitor', 150, 'Y', 'system', now()
  FROM tbl_company c
 WHERE NOT EXISTS (
    SELECT 1 FROM tbl_menu m WHERE m.co_cd = c.co_cd AND m.menu_cd = 'ccp-generic-monitor'
 )
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm, h_menu_cd = EXCLUDED.h_menu_cd, scrn_cd = EXCLUDED.scrn_cd,
    sort_no = EXCLUDED.sort_no, use_yn = 'Y', upd_id = 'system', upd_dt = now();

-- 기준정보 부모와 기준일지 관리 leaf — 기존 BAS 메뉴가 없을 수 있는 테넌트도 안전하게 생성
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, 'MBAS', '기준정보', NULL, NULL, 700, 'Y', 'system', now()
  FROM tbl_company c
 WHERE NOT EXISTS (
    SELECT 1 FROM tbl_menu m WHERE m.co_cd = c.co_cd AND m.menu_cd = 'MBAS'
 )
ON CONFLICT (co_cd, menu_cd) DO NOTHING;

INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, 'smart-diary-type-management', '스마트 HACCP 기준일지 유형', 'MBAS',
       'smart-diary-type-management', 840, 'Y', 'system', now()
  FROM tbl_company c
 WHERE NOT EXISTS (
    SELECT 1 FROM tbl_menu m WHERE m.co_cd = c.co_cd AND m.menu_cd = 'smart-diary-type-management'
 )
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm, h_menu_cd = EXCLUDED.h_menu_cd, scrn_cd = EXCLUDED.scrn_cd,
    sort_no = EXCLUDED.sort_no, use_yn = 'Y', upd_id = 'system', upd_dt = now();

-- 기존 회사에 신규 스마트 양식 사용 설정·채번 규칙 보강 — 기본은 미사용, 업체가 사용양식 관리에서 켠다
INSERT INTO tbl_company_template (co_cd, tmpl_cd, cycle_cd, retention_month, use_yn, base_use_yn, ins_id, ins_dt)
SELECT c.co_cd, t.tmpl_cd, t.default_cycle_cd, t.default_retention_month, 'N', 'Y', 'system', now()
  FROM tbl_company c
 CROSS JOIN tbl_template t
 WHERE t.tmpl_cd IN (
    'tmpl_ccp-heat-log', 'CCP_WASH', 'tmpl_ccp-sanitize-log', 'tmpl_ccp-filter-log', 'CCP_BOTTLE', 'CCP_IRON', 'CCP_AW', 'CCP_IQF', 'CCP_CO2',
    'ILLUMINATION', 'TEMP_HUMIDITY', 'WASH_EFFICACY', 'CROSS_CONTAM', 'tmpl_admin-recall-report', 'EMERGENCY',
    'tmpl_admin-law-health', 'tmpl_logis-material-ledger', 'tmpl_admin-building-ledger', 'tmpl_admin-production-ledger', 'tmpl_admin-license-manage', 'tmpl_admin-self-test', 'tmpl_admin-cert-manage',
    'AUTO_COLD', 'AUTO_ILLUM', 'AUTO_TEMP', 'AUTO_PEST'
 )
ON CONFLICT (co_cd, tmpl_cd) DO NOTHING;

INSERT INTO tbl_doc_no_rule (co_cd, tmpl_cd, prefix, date_fmt, seq_len, reset_cycle, ins_id, ins_dt)
SELECT c.co_cd, t.tmpl_cd, t.tmpl_cd, 'YYYYMMDD', 3, 'D', 'system', now()
  FROM tbl_company c
 CROSS JOIN tbl_template t
 WHERE t.tmpl_cd IN ('tmpl_ccp-heat-log', 'CCP_WASH', 'tmpl_ccp-sanitize-log', 'tmpl_ccp-filter-log', 'CCP_BOTTLE', 'CCP_IRON', 'CCP_AW', 'CCP_IQF', 'CCP_CO2',
                      'AUTO_COLD', 'AUTO_ILLUM', 'AUTO_TEMP', 'AUTO_PEST')
ON CONFLICT (co_cd, tmpl_cd) DO NOTHING;

-- 관리자에게 신규 화면 전 권한 — 비관리자 권한은 메뉴관리에서 명시 부여한다
INSERT INTO tbl_role_screen (
    co_cd, usrgrp_cd, scrn_cd, read_yn, write_yn, modify_yn, delete_yn, print_yn, ins_id, ins_dt
)
SELECT g.co_cd, g.usrgrp_cd, s.scrn_cd, 'Y', 'Y', 'Y', 'Y', 'Y', 'system', now()
  FROM tbl_role g
 CROSS JOIN (VALUES ('ccp-generic-monitor'), ('smart-diary-type-management')) AS s(scrn_cd)
 WHERE g.usrgrp_cd = 'ADMIN'
ON CONFLICT (co_cd, usrgrp_cd, scrn_cd) DO NOTHING;
