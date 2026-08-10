-- ============================================================
-- 35 — 메뉴 IA 정리: 서류·교육 숨김, 일지설정 활성 유지
--
-- 개발자: 박승우
-- 일자: 2026-08-07
-- 코멘트:
--   1) 개별 law/edu/test leaf·구 대메뉴를 비활성한다 (교육=문서작성 흡수, 서류=법적서류 그리드만)
--   2) 일지설정(MSET)은 사용양식·점검항목 + CCP한계·결재선·작성주기·스마트일지유형을 켠다
--   3) 화면명·정렬을 시드와 맞추고 ADMIN 권한 누락을 보완한다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 화면명·정렬 — 일지설정
-- ------------------------------------------------------------
INSERT INTO tbl_screen (scrn_cd, scrn_nm, module_cd, tmpl_cd, sort_no, use_yn, ins_id)
VALUES
    ('hwp-template-management', '사용양식관리', 'SET', NULL, 1310, 'Y', 'system'),
    ('template-check-item-management', '점검항목관리', 'SET', NULL, 1320, 'Y', 'system'),
    ('ccp-limit-management', 'CCP 한계기준 관리', 'SET', NULL, 1330, 'Y', 'system'),
    ('approval-line-management', '결재선 관리', 'SET', NULL, 1340, 'Y', 'system'),
    ('schedule-cycle-management', '작성주기 관리', 'SET', NULL, 1350, 'Y', 'system'),
    ('smart-diary-type-management', '스마트일지유형 관리', 'SET', NULL, 1360, 'Y', 'system')
ON CONFLICT (scrn_cd) DO UPDATE SET
    scrn_nm = EXCLUDED.scrn_nm,
    module_cd = 'SET',
    sort_no = EXCLUDED.sort_no,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- 법적서류 — 문서·결재 하위, 그리드 첨부 전용 (미존재 시 INSERT)
INSERT INTO tbl_screen (scrn_cd, scrn_nm, module_cd, tmpl_cd, sort_no, use_yn, ins_id)
VALUES ('legal-document-upload', '법적서류', 'DOC', NULL, 615, 'Y', 'system')
ON CONFLICT (scrn_cd) DO UPDATE SET
    scrn_nm = '법적서류',
    module_cd = 'DOC',
    sort_no = 615,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- ------------------------------------------------------------
-- 2. 교육·성적서·개별 법적 leaf 화면 비활성
-- ------------------------------------------------------------
UPDATE tbl_screen
   SET use_yn = 'N',
       upd_id = 'system',
       upd_dt = now()
 WHERE scrn_cd IN (
    'law-health-cert', 'law-material-ledger', 'law-building-ledger', 'law-production-ledger',
    'law-business-license', 'law-self-quality-test', 'law-completion-cert',
    'edu-annual-plan', 'edu-training-log',
    'test-product-report', 'test-surface-report'
 );

-- ------------------------------------------------------------
-- 3. 대메뉴·leaf 메뉴
-- ------------------------------------------------------------
-- 구 대메뉴 숨김
UPDATE tbl_menu
   SET use_yn = 'N',
       upd_id = 'system',
       upd_dt = now()
 WHERE menu_cd IN ('MLAW', 'MEDU', 'MTST')
    OR menu_cd LIKE 'MLAW%'
    OR menu_cd LIKE 'MEDU%'
    OR menu_cd LIKE 'MTST%';

-- 흡수 leaf 메뉴 숨김
UPDATE tbl_menu
   SET use_yn = 'N',
       upd_id = 'system',
       upd_dt = now()
 WHERE scrn_cd IN (
    'law-health-cert', 'law-material-ledger', 'law-building-ledger', 'law-production-ledger',
    'law-business-license', 'law-self-quality-test', 'law-completion-cert',
    'edu-annual-plan', 'edu-training-log',
    'test-product-report', 'test-surface-report'
 );

-- MSET 부모 유지
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, 'MSET', '일지설정', NULL, NULL, 1300, 'Y', 'system', now()
  FROM tbl_company c
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = '일지설정',
    h_menu_cd = NULL,
    scrn_cd = NULL,
    sort_no = 1300,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- 사용양식관리 (HWP)
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, 'hwp-template-management', '사용양식관리', 'MSET', 'hwp-template-management', 1310, 'Y', 'system', now()
  FROM tbl_company c
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = '사용양식관리',
    h_menu_cd = 'MSET',
    scrn_cd = 'hwp-template-management',
    sort_no = 1310,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- 점검항목관리 (DB)
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, 'template-check-item-management', '점검항목관리', 'MSET', 'template-check-item-management', 1320, 'Y', 'system', now()
  FROM tbl_company c
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = '점검항목관리',
    h_menu_cd = 'MSET',
    scrn_cd = 'template-check-item-management',
    sort_no = 1320,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- CCP 한계기준 관리
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, 'ccp-limit-management', 'CCP 한계기준 관리', 'MSET', 'ccp-limit-management', 1330, 'Y', 'system', now()
  FROM tbl_company c
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = 'CCP 한계기준 관리',
    h_menu_cd = 'MSET',
    scrn_cd = 'ccp-limit-management',
    sort_no = 1330,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- 결재선 관리
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, 'approval-line-management', '결재선 관리', 'MSET', 'approval-line-management', 1340, 'Y', 'system', now()
  FROM tbl_company c
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = '결재선 관리',
    h_menu_cd = 'MSET',
    scrn_cd = 'approval-line-management',
    sort_no = 1340,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- 작성주기 관리
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, 'schedule-cycle-management', '작성주기 관리', 'MSET', 'schedule-cycle-management', 1350, 'Y', 'system', now()
  FROM tbl_company c
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = '작성주기 관리',
    h_menu_cd = 'MSET',
    scrn_cd = 'schedule-cycle-management',
    sort_no = 1350,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- 스마트일지유형 관리
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, 'smart-diary-type-management', '스마트일지유형 관리', 'MSET', 'smart-diary-type-management', 1360, 'Y', 'system', now()
  FROM tbl_company c
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = '스마트일지유형 관리',
    h_menu_cd = 'MSET',
    scrn_cd = 'smart-diary-type-management',
    sort_no = 1360,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- 법적서류 — 문서·결재
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, 'legal-document-upload', '법적서류', 'MDOC', 'legal-document-upload', 615, 'Y', 'system', now()
  FROM tbl_company c
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = '법적서류',
    h_menu_cd = 'MDOC',
    scrn_cd = 'legal-document-upload',
    sort_no = 615,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- ------------------------------------------------------------
-- 4. 관리자 화면 권한 — IA 활성 화면 누락 보완
-- ------------------------------------------------------------
INSERT INTO tbl_role_screen (
    co_cd, usrgrp_cd, scrn_cd, read_yn, write_yn, modify_yn, delete_yn, print_yn, ins_id, ins_dt
)
SELECT g.co_cd, g.usrgrp_cd, s.scrn_cd, 'Y', 'Y', 'Y', 'Y', 'Y', 'system', now()
  FROM tbl_role g
 CROSS JOIN tbl_screen s
 WHERE g.usrgrp_cd = 'ADMIN'
   AND s.scrn_cd IN (
    'legal-document-upload',
    'hwp-template-management',
    'template-check-item-management',
    'ccp-limit-management',
    'approval-line-management',
    'schedule-cycle-management',
    'smart-diary-type-management'
 )
ON CONFLICT (co_cd, usrgrp_cd, scrn_cd) DO NOTHING;
