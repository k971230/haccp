-- ============================================================
-- 52 — 메뉴 대·중·소 3단 IA · menu_cd kebab 전면 개편
--
-- 개발자: 박승우
-- 일자: 2026-08-12
-- 코멘트:
--   1) 사이드바를 대·중·소 3단으로 재시드하고 구 MWRK/MAPR/MFRM/MCOD/MSYS 를 숨긴다
--   2) 소메뉴 menu_cd = menu-{scrn_cd}, 문서작성 중분류는 ccp/prp/logis/admin
--   3) 권한은 scrn_cd 기준이라 재매핑하지 않는다 (화면코드 유지)
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 0. h_menu_cd 길이 — kebab 상위코드(최대 약 20자+) 여유
-- ------------------------------------------------------------
ALTER TABLE tbl_menu ALTER COLUMN h_menu_cd TYPE varchar(40);

-- ------------------------------------------------------------
-- 1. 구 대메뉴·구 leaf(메뉴코드=화면코드) 숨김
-- ------------------------------------------------------------
UPDATE tbl_menu
   SET use_yn = 'N', upd_id = 'system', upd_dt = now()
 WHERE menu_cd IN (
    'MWRK', 'MAPR', 'MFRM', 'MCOD', 'MSYS',
    'MTSK', 'MCCP', 'MHYG', 'MPRC', 'MFAC', 'MINV', 'MDOC', 'MBAS', 'MSET',
    'MLAW', 'MEDU', 'MTST', 'MCA', 'MAUD', 'MPSTHIST'
 );

-- 메뉴코드가 화면코드와 같은 구 leaf — 새 menu-* 로 대체
UPDATE tbl_menu m
   SET use_yn = 'N', upd_id = 'system', upd_dt = now()
  FROM tbl_screen s
 WHERE m.scrn_cd = s.scrn_cd
   AND m.menu_cd = s.scrn_cd
   AND m.menu_cd <> 'today-tasks';

-- ------------------------------------------------------------
-- 2. 대분류
-- ------------------------------------------------------------
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, v.menu_cd, v.menu_nm, NULL, NULL, v.sort_no, 'Y', 'system', now()
  FROM tbl_company c
 CROSS JOIN (VALUES
    ('menu-doc-write',  '문서 작성',       100),
    ('menu-doc-flow',   '문서 현황·결재',  200),
    ('menu-doc-master', '문서 기준관리',   300),
    ('menu-base',       '기초정보',        400),
    ('menu-sys',        '시스템',          900)
  ) AS v(menu_cd, menu_nm, sort_no)
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm,
    h_menu_cd = NULL,
    scrn_cd = NULL,
    sort_no = EXCLUDED.sort_no,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- 오늘 할 일 — 최상위 leaf 유지
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

-- ------------------------------------------------------------
-- 3. 중분류
-- ------------------------------------------------------------
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, v.menu_cd, v.menu_nm, v.h_menu_cd, NULL, v.sort_no, 'Y', 'system', now()
  FROM tbl_company c
 CROSS JOIN (VALUES
    -- 문서 작성
    ('menu-write-ccp',   'CCP(공정)',       'menu-doc-write',  110),
    ('menu-write-prp',   'PRP(위생·설비)',  'menu-doc-write',  120),
    ('menu-write-logis', '물류',            'menu-doc-write',  130),
    ('menu-write-admin', '운영·법정',       'menu-doc-write',  140),
    -- 문서 현황·결재
    ('menu-flow-appr',   '결재',            'menu-doc-flow',   210),
    ('menu-flow-box',    '문서함·법적서류', 'menu-doc-flow',   220),
    ('menu-flow-ca',     '이탈·개선조치',   'menu-doc-flow',   230),
    -- 문서 기준관리
    ('menu-master-doc',  '작성 문서·주기',  'menu-doc-master', 310),
    ('menu-master-form', 'HWP·양식 원본',   'menu-doc-master', 320),
    ('menu-master-item', '점검항목/한계',   'menu-doc-master', 330),
    ('menu-master-appr', '결재선',          'menu-doc-master', 340),
    -- 기초정보 / 시스템
    ('menu-base-master', '기준정보',        'menu-base',       410),
    ('menu-sys-auth',    '권한·메뉴·코드',  'menu-sys',        910),
    ('menu-sys-log',     '이력·통계',       'menu-sys',        920)
  ) AS v(menu_cd, menu_nm, h_menu_cd, sort_no)
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm,
    h_menu_cd = EXCLUDED.h_menu_cd,
    scrn_cd = NULL,
    sort_no = EXCLUDED.sort_no,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- ------------------------------------------------------------
-- 4. 소분류 leaf — menu_cd = menu-{scrn_cd}
-- ------------------------------------------------------------
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd,
       'menu-' || v.scrn_cd,
       COALESCE(s.scrn_nm, v.scrn_cd),
       v.h_menu_cd,
       v.scrn_cd,
       COALESCE(s.sort_no, v.sort_no),
       COALESCE(s.use_yn, 'Y'),
       'system',
       now()
  FROM tbl_company c
 CROSS JOIN (VALUES
    -- CCP
    ('ccp-cold-monitor',         'menu-write-ccp',   105),
    ('ccp-heat-monitor',         'menu-write-ccp',   106),
    ('ccp-sanitize-monitor',     'menu-write-ccp',   107),
    ('ccp-filter-monitor',       'menu-write-ccp',   108),
    ('ccp-metal-monitor',        'menu-write-ccp',   109),
    ('ccp-verification-check',   'menu-write-ccp',   110),
    ('process-hwp',              'menu-write-ccp',   129),
    -- PRP
    ('daily-hygiene-check',      'menu-write-prp',   101),
    ('health-cert-record',       'menu-write-prp',   102),
    ('pest-control-check',       'menu-write-prp',   104),
    ('facility-equipment-check', 'menu-write-prp',   112),
    ('equipment-history',        'menu-write-prp',   111),
    ('pest-device-history',      'menu-write-prp',   113),
    ('visual-insp-standard',     'menu-write-prp',   114),
    ('calib-self-hwp',           'menu-write-prp',   116),
    ('calib-ext-hwp',            'menu-write-prp',   117),
    ('waste-hwp',                'menu-write-prp',   119),
    ('personal-hyg-hwp',         'menu-write-prp',   131),
    ('area-hyg-hwp',             'menu-write-prp',   132),
    ('water-hwp',                'menu-write-prp',   133),
    ('verify-plan-hwp',          'menu-write-prp',   134),
    ('verify-check-hwp',         'menu-write-prp',   135),
    ('verify-report-hwp',        'menu-write-prp',   136),
    ('verify-ca-hwp',            'menu-write-prp',   127),
    ('prod-test-hwp',            'menu-write-prp',   137),
    ('surface-test-hwp',         'menu-write-prp',   138),
    -- 물류
    ('receiving-insp-hwp',       'menu-write-logis', 114),
    ('submaterial-recv-hwp',     'menu-write-logis', 115),
    ('shipment-log-hwp',         'menu-write-logis', 118),
    ('inventory-hwp',            'menu-write-logis', 120),
    ('vehicle-hwp',              'menu-write-logis', 130),
    -- 운영·법정
    ('visitor-log',              'menu-write-admin', 103),
    ('edu-plan-hwp',             'menu-write-admin', 121),
    ('edu-log-hwp',              'menu-write-admin', 122),
    ('bad-product-hwp',          'menu-write-admin', 123),
    ('claim-hwp',                'menu-write-admin', 124),
    ('recall-hwp',               'menu-write-admin', 125),
    ('eval-hwp',                 'menu-write-admin', 126),
    ('handover-hwp',             'menu-write-admin', 128),
    -- 결재·문서함·CA
    ('approval-inbox',           'menu-flow-appr',   210),
    ('approval-history',         'menu-flow-appr',   230),
    ('document-inbox',           'menu-flow-box',    220),
    ('legal-document-upload',    'menu-flow-box',    240),
    ('corrective-action-management', 'menu-flow-ca', 250),
    -- 기준관리
    ('schedule-cycle-management','menu-master-doc',  340),
    ('hwp-template-management',  'menu-master-form', 310),
    ('daily-hyg-item-admin',     'menu-master-item', 311),
    ('ccp-cold-limit-admin',     'menu-master-item', 321),
    ('ccp-heat-limit-admin',     'menu-master-item', 322),
    ('ccp-sanitize-limit-admin', 'menu-master-item', 323),
    ('ccp-filter-limit-admin',   'menu-master-item', 324),
    ('ccp-metal-limit-admin',    'menu-master-item', 325),
    ('ccp-verify-standard-admin','menu-master-item', 326),
    ('facility-check-item-admin','menu-master-item', 331),
    ('ccp-limit-management',     'menu-master-item', 330),
    ('equipment-management',     'menu-master-item', 360),
    ('pest-device-management',   'menu-master-item', 370),
    ('approval-line-management', 'menu-master-appr', 350),
    -- 기초정보
    ('company-management',       'menu-base-master', 401),
    ('department-management',    'menu-base-master', 402),
    ('user-management',          'menu-base-master', 403),
    ('partner-management',       'menu-base-master', 420),
    ('product-management',       'menu-base-master', 430),
    ('material-management',      'menu-base-master', 440),
    ('storage-management',       'menu-base-master', 450),
    ('measuring-device-management','menu-base-master',460),
    ('vehicle-management',       'menu-base-master', 470),
    ('work-area-management',     'menu-base-master', 480),
    -- 시스템
    ('role-management',          'menu-sys-auth',    940),
    ('menu-management',          'menu-sys-auth',    950),
    ('common-code-management',   'menu-sys-auth',    960),
    ('login-history',            'menu-sys-log',     970),
    ('screen-usage-statistics',  'menu-sys-log',     980),
    ('audit-log',                'menu-sys-log',     990)
  ) AS v(scrn_cd, h_menu_cd, sort_no)
  LEFT JOIN tbl_screen s ON s.scrn_cd = v.scrn_cd
 WHERE COALESCE(s.use_yn, 'Y') = 'Y'
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm,
    h_menu_cd = EXCLUDED.h_menu_cd,
    scrn_cd = EXCLUDED.scrn_cd,
    sort_no = EXCLUDED.sort_no,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- 화면 미사용이면 대응 메뉴도 숨김
UPDATE tbl_menu m
   SET use_yn = 'N', upd_id = 'system', upd_dt = now()
  FROM tbl_screen s
 WHERE m.scrn_cd = s.scrn_cd
   AND s.use_yn = 'N'
   AND m.menu_cd LIKE 'menu-%';

-- 구 대·중 부모 아래 잔존 leaf 숨김 (메뉴코드≠화면코드 orphan 포함)
UPDATE tbl_menu
   SET use_yn = 'N', upd_id = 'system', upd_dt = now()
 WHERE use_yn = 'Y'
   AND (
     h_menu_cd IN (
       'MWRK', 'MAPR', 'MFRM', 'MCOD', 'MSYS',
       'MTSK', 'MCCP', 'MHYG', 'MPRC', 'MFAC', 'MINV', 'MDOC', 'MBAS', 'MSET',
       'MLAW', 'MEDU', 'MTST', 'MCA', 'MAUD'
     )
     OR menu_cd IN (
       'MWRK', 'MAPR', 'MFRM', 'MCOD', 'MSYS',
       'MTSK', 'MCCP', 'MHYG', 'MPRC', 'MFAC', 'MINV', 'MDOC', 'MBAS', 'MSET',
       'MLAW', 'MEDU', 'MTST', 'MCA', 'MAUD', 'MPSTHIST'
     )
   );
