-- ============================================================
-- 99 — 안 쓰는 화면 삭제 + 메뉴 리프 복구
--
-- 파일번호: 99
-- 이전번호: 97
-- 개발자: 박승우
-- 일자: 2026-08-19
-- 코멘트:
--   1) 점검항목·CCP한계 admin 화면은 쓰지 않는다. use_yn=N 이 아니라 행을 지운다
--   2) 이전 판의 빈 폴더 DELETE가 리프까지 지웠다.
--      리프 menu_cd 는 menu-{scrn_cd} 이라 tbl_screen.scrn_cd 에 없고, 자식도 없다.
--      이 파일은 시드와 같은 대·중·소를 다시 넣은 뒤 drop 목록만 지운다
--   3) 빈 폴더 삭제는 scrn_cd IS NULL 인 분류 노드만. 이미 실행한 환경도 재실행하면 복구된다
--
-- Jenkins는 migrate를 안 돌린다. DBeaver/수동
-- ============================================================

SET search_path TO sasshaccp;

-- 삭제 대상 화면코드 — 레지스트리에 없는 admin + 시설 점검항목
-- equipment-management · pest-device-management 는 이력 화면이 같은 코드로 남아 있으므로 제외
CREATE TEMP TABLE tmp_drop_scrn (
    scrn_cd varchar(50) PRIMARY KEY
);
INSERT INTO tmp_drop_scrn (scrn_cd) VALUES
    ('daily-hyg-item-admin'),
    ('ccp-cold-limit-admin'),
    ('ccp-heat-limit-admin'),
    ('ccp-sanitize-limit-admin'),
    ('ccp-filter-limit-admin'),
    ('ccp-metal-limit-admin'),
    ('ccp-verify-standard-admin'),
    ('ccp-limit-management'),
    ('facility-check-item-admin'),
    ('template-check-item-management'),
    ('smart-diary-type-management'),
    ('company-management');

-- ------------------------------------------------------------
-- 1. 대·중 분류 복구 — 리프가 날아간 뒤에도 폴더는 남아 있을 수 있다
--    업체: tbl_company + 메뉴에만 남은 co_cd (0000 실측 포함)
-- ------------------------------------------------------------
INSERT INTO tbl_menu(co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, v.menu_cd, v.menu_nm, NULL, NULL, v.sort_no, 'Y', 'system', now()
  FROM (
        SELECT co_cd FROM tbl_company
        UNION
        SELECT DISTINCT co_cd FROM tbl_menu
       ) c
 CROSS JOIN (VALUES
        ('menu-doc-write',  '문서 작성',      2000),
        ('menu-doc-flow',   '문서 현황·결재', 3000),
        ('menu-doc-master', '문서 기준관리',  4000),
        ('menu-base',       '기초정보',       5000),
        ('menu-sys',        '시스템',         6000)
       ) AS v(menu_cd, menu_nm, sort_no)
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm, h_menu_cd = NULL, scrn_cd = NULL,
    use_yn = 'Y', sort_no = EXCLUDED.sort_no, upd_id = 'system', upd_dt = now();

INSERT INTO tbl_menu(co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, 'today-tasks', '오늘 할 일', NULL, 'today-tasks', 1001, 'Y', 'system', now()
  FROM (
        SELECT co_cd FROM tbl_company
        UNION
        SELECT DISTINCT co_cd FROM tbl_menu
       ) c
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = '오늘 할 일', h_menu_cd = NULL, scrn_cd = 'today-tasks',
    sort_no = 1001, use_yn = 'Y', upd_id = 'system', upd_dt = now();

INSERT INTO tbl_menu(co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, v.menu_cd, v.menu_nm, v.h_menu_cd, NULL, v.sort_no, v.use_yn, 'system', now()
  FROM (
        SELECT co_cd FROM tbl_company
        UNION
        SELECT DISTINCT co_cd FROM tbl_menu
       ) c
 CROSS JOIN (VALUES
        ('menu-write-ccp',   'CCP(공정)',        'menu-doc-write',  2100, 'Y'),
        ('menu-write-prp',   'PRP(위생·설비)',   'menu-doc-write',  2200, 'Y'),
        ('menu-write-logis', '물류',             'menu-doc-write',  2300, 'Y'),
        ('menu-write-admin', '운영·법정',        'menu-doc-write',  2400, 'Y'),
        ('menu-flow-appr',   '결재',             'menu-doc-flow',   3100, 'Y'),
        ('menu-flow-box',    '문서함·법적서류',  'menu-doc-flow',   3200, 'Y'),
        ('menu-flow-ca',     '이탈·개선조치',    'menu-doc-flow',   3300, 'Y'),
        ('menu-master-doc',  '작성 문서·주기',   'menu-doc-master', 4100, 'Y'),
        ('menu-master-form', 'HWP·양식 원본',    'menu-doc-master', 4200, 'Y'),
        ('menu-master-html', 'HTML양식 원본',    'menu-doc-master', 4250, 'Y'),
        ('menu-master-item', '점검항목/한계',    'menu-doc-master', 4300, 'Y'),
        ('menu-master-appr', '결재선',           'menu-doc-master', 4400, 'N'),
        ('menu-base-master', '기준정보',         'menu-base',       5100, 'Y'),
        ('menu-sys-auth',    '권한·사용자·코드', 'menu-sys',        6100, 'Y'),
        ('menu-sys-log',     '이력·통계',        'menu-sys',        6200, 'Y')
       ) AS v(menu_cd, menu_nm, h_menu_cd, sort_no, use_yn)
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm, h_menu_cd = EXCLUDED.h_menu_cd, scrn_cd = NULL,
    use_yn = EXCLUDED.use_yn, sort_no = EXCLUDED.sort_no, upd_id = 'system', upd_dt = now();

-- ------------------------------------------------------------
-- 2. 소 leaf 복구 — menu_cd = menu-{scrn_cd}. drop 목록·미사용 화면은 넣지 않는다
--    결재선은 menu-sys-auth (97)
-- ------------------------------------------------------------
INSERT INTO tbl_menu(co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, 'menu-' || v.scrn_cd, COALESCE(s.scrn_nm, v.scrn_cd),
       v.h_menu_cd, v.scrn_cd, COALESCE(s.sort_no, v.sort_no), 'Y', 'system', now()
  FROM (
        SELECT co_cd FROM tbl_company
        UNION
        SELECT DISTINCT co_cd FROM tbl_menu
       ) c
 CROSS JOIN (VALUES
        ('ccp-cold-monitor', 'menu-write-ccp', 105),
        ('ccp-heat-monitor', 'menu-write-ccp', 106),
        ('ccp-sanitize-monitor', 'menu-write-ccp', 107),
        ('ccp-filter-monitor', 'menu-write-ccp', 108),
        ('ccp-metal-monitor', 'menu-write-ccp', 109),
        ('ccp-verification-check', 'menu-write-ccp', 110),
        ('process-hwp', 'menu-write-ccp', 129),
        ('daily-hygiene-check', 'menu-write-prp', 101),
        ('hygiene-process-check', 'menu-write-prp', 103),
        ('health-cert-record', 'menu-write-prp', 102),
        ('pest-control-check', 'menu-write-prp', 104),
        ('facility-equipment-check', 'menu-write-prp', 112),
        ('equipment-history', 'menu-write-prp', 111),
        ('pest-device-history', 'menu-write-prp', 113),
        ('visual-insp-standard', 'menu-write-prp', 114),
        ('calib-self-hwp', 'menu-write-prp', 116),
        ('calib-ext-hwp', 'menu-write-prp', 117),
        ('waste-hwp', 'menu-write-prp', 119),
        ('personal-hyg-hwp', 'menu-write-prp', 131),
        ('area-hyg-hwp', 'menu-write-prp', 132),
        ('water-hwp', 'menu-write-prp', 133),
        ('verify-plan-hwp', 'menu-write-prp', 134),
        ('verify-check-hwp', 'menu-write-prp', 135),
        ('verify-report-hwp', 'menu-write-prp', 136),
        ('verify-ca-hwp', 'menu-write-prp', 127),
        ('prod-test-hwp', 'menu-write-prp', 137),
        ('surface-test-hwp', 'menu-write-prp', 138),
        ('receiving-insp-hwp', 'menu-write-logis', 114),
        ('submaterial-recv-hwp', 'menu-write-logis', 115),
        ('shipment-log-hwp', 'menu-write-logis', 118),
        ('inventory-hwp', 'menu-write-logis', 120),
        ('vehicle-hwp', 'menu-write-logis', 130),
        ('visitor-log', 'menu-write-admin', 103),
        ('edu-plan-hwp', 'menu-write-admin', 121),
        ('edu-log-hwp', 'menu-write-admin', 122),
        ('bad-product-hwp', 'menu-write-admin', 123),
        ('claim-hwp', 'menu-write-admin', 124),
        ('recall-hwp', 'menu-write-admin', 125),
        ('eval-hwp', 'menu-write-admin', 126),
        ('handover-hwp', 'menu-write-admin', 128),
        ('approval-inbox', 'menu-flow-appr', 210),
        ('approval-history', 'menu-flow-appr', 230),
        ('document-inbox', 'menu-flow-box', 220),
        ('legal-document-upload', 'menu-flow-box', 240),
        ('corrective-action-management', 'menu-flow-ca', 250),
        ('schedule-cycle-management', 'menu-master-doc', 340),
        ('hwp-template-management', 'menu-master-form', 310),
        ('hyg-process-template', 'menu-master-html', 311),
        ('ccp-verify-template', 'menu-master-html', 312),
        ('ccp-pkg-template', 'menu-master-html', 313),
        ('ccp-htg-template', 'menu-master-html', 314),
        ('ccp-mtl-template', 'menu-master-html', 315),
        ('equipment-management', 'menu-master-item', 360),
        ('pest-device-management', 'menu-master-item', 370),
        ('approval-line-management', 'menu-sys-auth', 960),
        ('partner-management', 'menu-base-master', 420),
        ('product-management', 'menu-base-master', 430),
        ('material-management', 'menu-base-master', 440),
        ('storage-management', 'menu-base-master', 450),
        ('measuring-device-management', 'menu-base-master', 460),
        ('vehicle-management', 'menu-base-master', 470),
        ('work-area-management', 'menu-base-master', 480),
        ('common-code-management', 'menu-sys-auth', 910),
        ('menu-management', 'menu-sys-auth', 920),
        ('role-management', 'menu-sys-auth', 930),
        ('department-management', 'menu-sys-auth', 940),
        ('user-management', 'menu-sys-auth', 950),
        ('login-history', 'menu-sys-log', 970),
        ('screen-usage-statistics', 'menu-sys-log', 980),
        ('audit-log', 'menu-sys-log', 990)
      ) AS v(scrn_cd, h_menu_cd, sort_no)
  JOIN tbl_screen s ON s.scrn_cd = v.scrn_cd AND s.use_yn = 'Y'
 WHERE v.scrn_cd NOT IN (SELECT scrn_cd FROM tmp_drop_scrn)
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm,
    h_menu_cd = EXCLUDED.h_menu_cd,
    scrn_cd = EXCLUDED.scrn_cd,
    sort_no = EXCLUDED.sort_no,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- ------------------------------------------------------------
-- 3. 안 쓰는 화면 행 삭제 (멱등)
-- ------------------------------------------------------------
DELETE FROM tbl_role_screen
 WHERE scrn_cd IN (SELECT scrn_cd FROM tmp_drop_scrn);

DELETE FROM tbl_grid_pref
 WHERE scrn_cd IN (SELECT scrn_cd FROM tmp_drop_scrn);

DELETE FROM tbl_menu
 WHERE scrn_cd IN (SELECT scrn_cd FROM tmp_drop_scrn);

DELETE FROM tbl_screen
 WHERE scrn_cd IN (SELECT scrn_cd FROM tmp_drop_scrn);

-- ------------------------------------------------------------
-- 4. 자식이 0인 중분류만 삭제 — 화면 리프(scrn_cd 있음)는 절대 지우지 않는다
-- ------------------------------------------------------------
DELETE FROM tbl_menu p
 WHERE p.scrn_cd IS NULL
   AND COALESCE(p.h_menu_cd, '') <> ''
   AND NOT EXISTS (
        SELECT 1 FROM tbl_menu c
         WHERE c.co_cd = p.co_cd
           AND c.h_menu_cd = p.menu_cd
           AND c.use_yn = 'Y'
   );

DROP TABLE tmp_drop_scrn;

CALL sp_tbl_menu_sort_encode_u_000(NULL);
