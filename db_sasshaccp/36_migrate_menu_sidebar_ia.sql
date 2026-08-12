-- ============================================================
-- 36 — 사이드바 IA: 오늘할일 + 문서작성/현황결재/기준관리/기초정보/시스템
--
-- 개발자: 박승우
-- 일자: 2026-08-07
-- 코멘트:
--   1) 구 모듈 대메뉴(MCCP/MHYG/…)를 숨기고 5대메뉴로 leaf를 재배치한다
--   2) 오늘 할 일은 최상위 leaf(h_menu_cd NULL)로 둔다
--   3) 문서번호(mng_no)를 HA-* 로 맞추고 불필요 화면·메뉴는 use_yn=N
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 화면 모듈·정렬·사용여부 (IA 버킷)
-- ------------------------------------------------------------
UPDATE tbl_screen SET module_cd = 'TSK', sort_no = 10, use_yn = 'Y', scrn_nm = '오늘 할 일', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd = 'today-tasks';

-- 문서 작성 버킷
UPDATE tbl_screen SET module_cd = 'WRK', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd IN (
  'daily-hygiene-check', 'pest-control-check',
  'ccp-cold-monitor', 'ccp-heat-monitor', 'ccp-sanitize-monitor', 'ccp-filter-monitor', 'ccp-metal-monitor',
  'ccp-verification-check', 'facility-equipment-check',
  'hwp-document-editor'
 );

UPDATE tbl_screen SET scrn_nm = v.nm, sort_no = v.sort_no, use_yn = 'Y', module_cd = 'WRK', upd_id = 'system', upd_dt = now()
  FROM (VALUES
    ('daily-hygiene-check', '일일위생점검표', 101),
    ('pest-control-check', '방충방서관리점검표', 104),
    ('ccp-cold-monitor', '냉장냉동보관모니터링', 105),
    ('ccp-heat-monitor', '가열공정CCP일지', 106),
    ('ccp-sanitize-monitor', '멸균공정CCP일지', 107),
    ('ccp-filter-monitor', '여과공정CCP일지', 108),
    ('ccp-metal-monitor', '금속검출CCP일지', 109),
    ('ccp-verification-check', 'CCP검증점검표', 110),
    ('facility-equipment-check', '설비및시설점검표', 112)
  ) AS v(scrn_cd, nm, sort_no)
 WHERE tbl_screen.scrn_cd = v.scrn_cd;

-- HWP 문서만 — 화면 행 확보 (공용 editor 컴포넌트에 맵핑, 메뉴·권한은 분리)
INSERT INTO tbl_screen (scrn_cd, scrn_nm, module_cd, tmpl_cd, sort_no, use_yn, ins_id)
VALUES
    ('health-cert-record', '건강진단관리기록부', 'WRK', 'tmpl_admin-law-health', 102, 'Y', 'system'),
    ('visitor-log', '입출입대장', 'WRK', NULL, 103, 'Y', 'system'),
    ('equipment-history', '설비이력기록부', 'WRK', 'tmpl_prp-equip-card', 111, 'Y', 'system'),
    ('visual-insp-standard', '육안검사기준', 'WRK', NULL, 113, 'Y', 'system'),
    ('receiving-insp-hwp', '입고검사일지', 'WRK', 'tmpl_logis-receive-inspect', 114, 'Y', 'system'),
    ('submaterial-recv-hwp', '부자재입고검수점검표', 'WRK', NULL, 115, 'Y', 'system'),
    ('calib-self-hwp', '자체검교정기록부', 'WRK', 'tmpl_prp-calib-temp', 116, 'Y', 'system'),
    ('calib-ext-hwp', '외부검교정기록부', 'WRK', NULL, 117, 'Y', 'system'),
    ('shipment-log-hwp', '제품출고관리일지', 'WRK', NULL, 118, 'Y', 'system'),
    ('waste-hwp', '폐기물처리점검표', 'WRK', 'tmpl_prp-waste-check', 119, 'Y', 'system'),
    ('inventory-hwp', '입출고및재고점검표', 'WRK', 'tmpl_logis-inventory-check', 120, 'Y', 'system'),
    ('edu-plan-hwp', '연간교육계획표', 'WRK', 'tmpl_admin-edu-plan', 121, 'Y', 'system'),
    ('edu-log-hwp', '교육및회의결과보고서', 'WRK', 'tmpl_admin-edu-log', 122, 'Y', 'system'),
    ('bad-product-hwp', '부적합품발생보고서', 'WRK', 'tmpl_admin-bad-product', 123, 'Y', 'system'),
    ('claim-hwp', '클레임및이물혼입보고서', 'WRK', 'tmpl_admin-claim-log', 124, 'Y', 'system'),
    ('recall-hwp', '회수결과보고서', 'WRK', NULL, 125, 'Y', 'system'),
    ('eval-hwp', '실시상황평가표', 'WRK', NULL, 126, 'Y', 'system'),
    ('verify-ca-hwp', '검증개선조치보고서', 'WRK', 'tmpl_prp-verify-action', 127, 'Y', 'system'),
    ('handover-hwp', '업무인수인계서', 'WRK', 'tmpl_admin-handover-doc', 128, 'Y', 'system'),
    ('process-hwp', '공정관리점검표', 'WRK', 'tmpl_ccp-process-check', 129, 'Y', 'system'),
    ('vehicle-hwp', '차량운행일지', 'WRK', 'tmpl_logis-vehicle-log', 130, 'Y', 'system'),
    ('personal-hyg-hwp', '개인위생관리점검표', 'WRK', 'tmpl_prp-hygiene-personal', 131, 'Y', 'system'),
    ('area-hyg-hwp', '작업장환경위생점검표', 'WRK', 'tmpl_prp-hygiene-area', 132, 'Y', 'system'),
    ('water-hwp', '용수관리점검표', 'WRK', 'tmpl_prp-water-check', 133, 'Y', 'system'),
    ('verify-plan-hwp', '연간검증계획서', 'WRK', 'tmpl_prp-verify-plan', 134, 'Y', 'system'),
    ('verify-check-hwp', '검증점검표', 'WRK', 'tmpl_prp-verify-check', 135, 'Y', 'system'),
    ('verify-report-hwp', '검증결과보고서', 'WRK', 'tmpl_prp-verify-report', 136, 'Y', 'system'),
    ('prod-test-hwp', '제품검사성적서', 'WRK', 'tmpl_prp-test-product', 137, 'Y', 'system'),
    ('surface-test-hwp', '표면오염도검사성적서', 'WRK', 'tmpl_prp-test-surface', 138, 'Y', 'system')
ON CONFLICT (scrn_cd) DO UPDATE SET
    scrn_nm = EXCLUDED.scrn_nm,
    module_cd = 'WRK',
    tmpl_cd = COALESCE(EXCLUDED.tmpl_cd, tbl_screen.tmpl_cd),
    sort_no = EXCLUDED.sort_no,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- 문서 현황·결재
UPDATE tbl_screen SET module_cd = 'APR', use_yn = 'Y', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd IN ('approval-inbox', 'document-inbox', 'approval-history', 'legal-document-upload', 'corrective-action-management');

UPDATE tbl_screen SET scrn_nm = v.nm, sort_no = v.sort_no, upd_id = 'system', upd_dt = now()
  FROM (VALUES
    ('approval-inbox', '결재함', 210),
    ('document-inbox', '문서함', 220),
    ('approval-history', '결재·변경이력', 230),
    ('legal-document-upload', '법적서류', 240),
    ('corrective-action-management', '이탈·개선조치', 250)
  ) AS v(scrn_cd, nm, sort_no)
 WHERE tbl_screen.scrn_cd = v.scrn_cd;

-- 문서 기준관리
UPDATE tbl_screen SET module_cd = 'FRM', use_yn = 'Y', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd IN (
  'hwp-template-management', 'template-check-item-management',
  'schedule-cycle-management', 'approval-line-management', 'ccp-limit-management',
  'equipment-management', 'pest-device-management'
 );

UPDATE tbl_screen SET scrn_nm = v.nm, sort_no = v.sort_no, upd_id = 'system', upd_dt = now()
  FROM (VALUES
    ('hwp-template-management', 'HWP문서관리', 310),
    ('template-check-item-management', '점검항목관리', 320),
    ('ccp-limit-management', 'CCP한계기준 관리', 330),
    ('schedule-cycle-management', '작성주기 관리', 340),
    ('approval-line-management', '결재선 관리', 350),
    ('equipment-management', '설비마스터', 360),
    ('pest-device-management', '방충방서 설비·위치', 370)
  ) AS v(scrn_cd, nm, sort_no)
 WHERE tbl_screen.scrn_cd = v.scrn_cd;

-- 기초정보
UPDATE tbl_screen SET module_cd = 'COD', use_yn = 'Y', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd IN (
  'common-code-management', 'partner-management', 'product-management', 'material-management',
  'storage-management', 'measuring-device-management', 'vehicle-management', 'work-area-management'
 );

UPDATE tbl_screen SET sort_no = v.sort_no, upd_id = 'system', upd_dt = now()
  FROM (VALUES
    ('common-code-management', 410),
    ('partner-management', 420),
    ('product-management', 430),
    ('material-management', 440),
    ('storage-management', 450),
    ('measuring-device-management', 460),
    ('vehicle-management', 470),
    ('work-area-management', 480)
  ) AS v(scrn_cd, sort_no)
 WHERE tbl_screen.scrn_cd = v.scrn_cd;

-- 시스템 — 유지
UPDATE tbl_screen SET module_cd = 'SYS', use_yn = 'Y', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd IN (
  'company-management', 'user-management', 'department-management', 'role-management',
  'menu-management', 'login-history', 'screen-usage-statistics', 'audit-log'
 );

-- 숨김 — IA 밖·DB→HWP 전환된 구 화면
UPDATE tbl_screen SET use_yn = 'N', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd IN (
  'smart-diary-type-management', 'audit-export', 'ccp-generic-monitor',
  'ccp-wash-monitor', 'ccp-iqf-monitor',
  'personal-hygiene-check', 'area-hygiene-check', 'water-management-check',
  'waste-disposal-check', 'inventory-check', 'process-control-check',
  'receiving-inspection', 'annual-verification-plan', 'calibration-target-management',
  'hwp-document-editor',
  'law-health-cert', 'law-material-ledger', 'law-building-ledger', 'law-production-ledger',
  'law-business-license', 'law-self-quality-test', 'law-completion-cert',
  'edu-annual-plan', 'edu-training-log', 'test-product-report', 'test-surface-report'
 );

-- ------------------------------------------------------------
-- 2. 문서번호 HA-* (tbl_template.mng_no)
-- ------------------------------------------------------------
-- HA-CCP-06-01 등 12자는 기존 varchar(10)에 안 들어감 — 관리번호 자리 확장
ALTER TABLE tbl_template ALTER COLUMN mng_no TYPE varchar(20);

UPDATE tbl_template SET mng_no = v.ha, upd_id = 'system', upd_dt = now()
  FROM (VALUES
    ('tmpl_prp-hygiene-daily', 'HA-HYG-01'),
    ('tmpl_admin-law-health', 'HA-HYG-02'),
    ('tmpl_prp-pest-check', 'HA-HYG-04'),
    ('tmpl_prp-hygiene-personal', 'HA-HYG-05'),
    ('tmpl_prp-hygiene-area', 'HA-HYG-06'),
    ('tmpl_prp-water-check', 'HA-HYG-07'),
    ('tmpl_ccp-cold-log', 'HA-CCP-05'),
    ('tmpl_ccp-heat-log', 'HA-CCP-06-01'),
    ('tmpl_ccp-sanitize-log', 'HA-CCP-06-02'),
    ('tmpl_ccp-filter-log', 'HA-CCP-06-03'),
    ('tmpl_ccp-metal-log', 'HA-CCP-06-04'),
    ('tmpl_ccp-verify-check', 'HA-CCP-07'),
    ('tmpl_prp-equip-card', 'HA-FAC-08'),
    ('tmpl_prp-facility-check', 'HA-FAC-09'),
    ('tmpl_prp-calib-temp', 'HA-FAC-14'),
    ('tmpl_prp-calib-weight', 'HA-FAC-14'),
    ('tmpl_prp-calib-scale', 'HA-FAC-14'),
    ('tmpl_prp-waste-check', 'HA-FAC-18'),
    ('tmpl_logis-vehicle-log', 'HA-FAC-27'),
    ('tmpl_logis-receive-inspect', 'HA-INV-11'),
    ('tmpl_logis-inventory-check', 'HA-INV-19'),
    ('tmpl_admin-edu-plan', 'HA-EDU-18'),
    ('tmpl_admin-edu-log', 'HA-EDU-19'),
    ('tmpl_admin-bad-product', 'HA-DOC-20'),
    ('tmpl_admin-claim-log', 'HA-DOC-21'),
    ('tmpl_prp-verify-action', 'HA-VER-24'),
    ('tmpl_admin-handover-doc', 'HA-DOC-25'),
    ('tmpl_ccp-process-check', 'HA-PRC-26'),
    ('tmpl_prp-verify-plan', 'HA-VER-04'),
    ('tmpl_prp-verify-check', 'HA-VER-05'),
    ('tmpl_prp-verify-report', 'HA-VER-06'),
    ('tmpl_prp-test-product', 'HA-VER-21'),
    ('tmpl_prp-test-surface', 'HA-VER-22')
  ) AS v(tmpl_cd, ha)
 WHERE tbl_template.tmpl_cd = v.tmpl_cd;

-- ------------------------------------------------------------
-- 3. 대메뉴 5 + 오늘할일
-- ------------------------------------------------------------
-- 구 부모 전부 숨김
UPDATE tbl_menu SET use_yn = 'N', upd_id = 'system', upd_dt = now()
 WHERE h_menu_cd IS NULL
   AND menu_cd IN (
    'MTSK', 'MCCP', 'MHYG', 'MPRC', 'MFAC', 'MINV', 'MDOC', 'MBAS', 'MSET',
    'MLAW', 'MEDU', 'MTST', 'MCA', 'MAUD', 'MWRK', 'MAPR', 'MFRM', 'MCOD'
   );

INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, v.menu_cd, v.menu_nm, NULL, NULL, v.sort_no, 'Y', 'system', now()
  FROM tbl_company c
 CROSS JOIN (VALUES
    ('MWRK', '문서 작성', 100),
    ('MAPR', '문서 현황·결재', 200),
    ('MFRM', '문서 기준관리', 300),
    ('MCOD', '기초정보 관리', 400),
    ('MSYS', '시스템 관리', 900)
  ) AS v(menu_cd, menu_nm, sort_no)
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm,
    h_menu_cd = NULL,
    scrn_cd = NULL,
    sort_no = EXCLUDED.sort_no,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- 오늘 할 일 — 최상위 leaf
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, 'today-tasks', '오늘 할 일', NULL, 'today-tasks', 10, 'Y', 'system', now()
  FROM tbl_company c
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = '오늘 할 일',
    h_menu_cd = NULL,
    scrn_cd = 'today-tasks',
    sort_no = 10,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- leaf 재배치 — 사용 화면만 부모 연결
UPDATE tbl_menu m
   SET h_menu_cd = CASE s.module_cd
                     WHEN 'WRK' THEN 'MWRK'
                     WHEN 'APR' THEN 'MAPR'
                     WHEN 'FRM' THEN 'MFRM'
                     WHEN 'COD' THEN 'MCOD'
                     WHEN 'SYS' THEN 'MSYS'
                     WHEN 'TSK' THEN NULL
                     ELSE m.h_menu_cd END,
       menu_nm = s.scrn_nm,
       scrn_cd = s.scrn_cd,
       sort_no = s.sort_no,
       use_yn = s.use_yn,
       upd_id = 'system',
       upd_dt = now()
  FROM tbl_screen s
 WHERE m.menu_cd = s.scrn_cd
   AND m.scrn_cd IS NOT NULL;

-- 신규 화면 메뉴 삽입
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, s.scrn_cd, s.scrn_nm,
       CASE s.module_cd
         WHEN 'WRK' THEN 'MWRK' WHEN 'APR' THEN 'MAPR' WHEN 'FRM' THEN 'MFRM'
         WHEN 'COD' THEN 'MCOD' WHEN 'SYS' THEN 'MSYS' ELSE NULL END,
       s.scrn_cd, s.sort_no, s.use_yn, 'system', now()
  FROM tbl_company c
 CROSS JOIN tbl_screen s
 WHERE s.use_yn = 'Y'
   AND s.scrn_cd <> 'today-tasks'
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm,
    h_menu_cd = EXCLUDED.h_menu_cd,
    scrn_cd = EXCLUDED.scrn_cd,
    sort_no = EXCLUDED.sort_no,
    use_yn = EXCLUDED.use_yn,
    upd_id = 'system',
    upd_dt = now();

-- 화면 미사용이면 메뉴도 숨김
UPDATE tbl_menu m
   SET use_yn = 'N', upd_id = 'system', upd_dt = now()
  FROM tbl_screen s
 WHERE m.scrn_cd = s.scrn_cd
   AND s.use_yn = 'N';

-- 고아 leaf(부모만 남은 구 메뉴코드) 숨김
UPDATE tbl_menu
   SET use_yn = 'N', upd_id = 'system', upd_dt = now()
 WHERE h_menu_cd IN (
    'MTSK', 'MCCP', 'MHYG', 'MPRC', 'MFAC', 'MINV', 'MDOC', 'MBAS', 'MSET',
    'MLAW', 'MEDU', 'MTST', 'MCA', 'MAUD'
 );

-- ADMIN 권한 — 신규 화면
INSERT INTO tbl_role_screen (
    co_cd, usrgrp_cd, scrn_cd, read_yn, write_yn, modify_yn, delete_yn, print_yn, ins_id, ins_dt
)
SELECT g.co_cd, g.usrgrp_cd, s.scrn_cd, 'Y', 'Y', 'Y', 'Y', 'Y', 'system', now()
  FROM tbl_role g
 CROSS JOIN tbl_screen s
 WHERE g.usrgrp_cd = 'ADMIN'
   AND s.use_yn = 'Y'
ON CONFLICT (co_cd, usrgrp_cd, scrn_cd) DO NOTHING;
