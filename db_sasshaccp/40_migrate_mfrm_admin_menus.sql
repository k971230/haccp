-- ============================================================
-- 40 — 문서 기준관리(C3) 문서별 admin 메뉴
--
-- 개발자: 박승우
-- 일자: 2026-08-07
-- 코멘트:
--   1) 일일위생·CCP별·검증·시설점검 기준관리 leaf를 MFRM 아래에 둔다
--   2) FE는 기존 페이지에 fixedTmplCd/ccpCd prop으로 연결한다
--   3) ADMIN 권한을 신규 화면에 부여한다
-- ============================================================

SET search_path TO sasshaccp;

INSERT INTO tbl_screen (scrn_cd, scrn_nm, module_cd, tmpl_cd, sort_no, use_yn, ins_id)
VALUES
    ('daily-hyg-item-admin',      '일일위생 점검항목관리',     'FRM', 'DAILY_HYG',  311, 'Y', 'system'),
    ('ccp-cold-limit-admin',      '냉장냉동 CCP 기준관리',     'FRM', 'CCP_COLD',   321, 'Y', 'system'),
    ('ccp-heat-limit-admin',      '가열 CCP 기준관리',         'FRM', 'CCP_HEAT',   322, 'Y', 'system'),
    ('ccp-sanitize-limit-admin',  '멸균 CCP 기준관리',         'FRM', 'CCP_SANITIZE',323,'Y', 'system'),
    ('ccp-filter-limit-admin',    '여과 CCP 기준관리',         'FRM', 'CCP_FILTER', 324, 'Y', 'system'),
    ('ccp-metal-limit-admin',     '금속검출 CCP 기준관리',     'FRM', 'CCP_METAL',  325, 'Y', 'system'),
    ('ccp-verify-standard-admin', 'CCP검증 기준·주기관리',     'FRM', 'CCP_VERIFY', 326, 'Y', 'system'),
    ('facility-check-item-admin', '설비시설점검 항목·주기',    'FRM', 'FACILITY',   331, 'Y', 'system')
ON CONFLICT (scrn_cd) DO UPDATE SET
    scrn_nm = EXCLUDED.scrn_nm,
    module_cd = 'FRM',
    tmpl_cd = EXCLUDED.tmpl_cd,
    sort_no = EXCLUDED.sort_no,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

UPDATE tbl_screen SET scrn_nm = '방충방서 설비·위치관리', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd = 'pest-device-management';
UPDATE tbl_screen SET scrn_nm = '설비마스터등록', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd = 'equipment-management';

INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, s.scrn_cd, s.scrn_nm, 'MFRM', s.scrn_cd, s.sort_no, 'Y', 'system', now()
  FROM tbl_company c
 CROSS JOIN tbl_screen s
 WHERE s.scrn_cd IN (
    'daily-hyg-item-admin','ccp-cold-limit-admin','ccp-heat-limit-admin',
    'ccp-sanitize-limit-admin','ccp-filter-limit-admin','ccp-metal-limit-admin',
    'ccp-verify-standard-admin','facility-check-item-admin'
 )
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm,
    h_menu_cd = 'MFRM',
    scrn_cd = EXCLUDED.scrn_cd,
    sort_no = EXCLUDED.sort_no,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

UPDATE tbl_menu m SET menu_nm = s.scrn_nm, upd_id = 'system', upd_dt = now()
  FROM tbl_screen s
 WHERE m.scrn_cd = s.scrn_cd
   AND s.scrn_cd IN ('pest-device-management','equipment-management');

INSERT INTO tbl_role_screen (
    co_cd, usrgrp_cd, scrn_cd, read_yn, write_yn, modify_yn, delete_yn, print_yn, ins_id, ins_dt
)
SELECT g.co_cd, g.usrgrp_cd, s.scrn_cd, 'Y', 'Y', 'Y', 'Y', 'Y', 'system', now()
  FROM tbl_role g
 CROSS JOIN tbl_screen s
 WHERE g.usrgrp_cd = 'ADMIN'
   AND s.scrn_cd IN (
    'daily-hyg-item-admin','ccp-cold-limit-admin','ccp-heat-limit-admin',
    'ccp-sanitize-limit-admin','ccp-filter-limit-admin','ccp-metal-limit-admin',
    'ccp-verify-standard-admin','facility-check-item-admin'
 )
ON CONFLICT (co_cd, usrgrp_cd, scrn_cd) DO NOTHING;
