-- ============================================================
-- 역할 — 수동 서류 메뉴(법적·교육·성적서·일지설정) 및 CCP 유형 leaf 동기화
--
-- 개발자: 박승우
-- 일자: 2026-08-06
-- 코멘트:
--   1) 가이드 수동 서류군을 tbl_screen·tbl_menu leaf로 열어 HWP/공통 CCP로 진입한다
--   2) 기존 테넌트에 부모 모듈·관리자 권한을 중복 없이 추가한다
--   3) 자동일지·센서 화면은 넣지 않는다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 화면 마스터 — LAW / EDU / TST / SET + CCP 유형별 공통 화면
-- ------------------------------------------------------------
INSERT INTO tbl_screen (scrn_cd, scrn_nm, module_cd, tmpl_cd, sort_no, use_yn, ins_id) VALUES
    -- 법적서류 (HWP)
    ('law-health-cert',        '보건증관리',           'LAW', 'LAW_HEALTH',     1010, 'Y', 'system'),
    ('law-material-ledger',    '원료수불대장관리',     'LAW', 'LAW_MATERIAL',   1020, 'Y', 'system'),
    ('law-building-ledger',    '건축물대장관리',       'LAW', 'LAW_BUILDING',   1030, 'Y', 'system'),
    ('law-production-ledger',  '생산대장관리',         'LAW', 'LAW_PRODUCTION', 1040, 'Y', 'system'),
    ('law-business-license',   '영업등록증관리',       'LAW', 'LAW_LICENSE',    1050, 'Y', 'system'),
    ('law-self-quality-test',  '자가품질검사관리',     'LAW', 'LAW_SELF_TEST',  1060, 'Y', 'system'),
    ('law-completion-cert',    '수료증관리',           'LAW', 'LAW_CERT',       1070, 'Y', 'system'),
    -- 교육 (HWP)
    ('edu-annual-plan',        '연간 교육·훈련 계획서','EDU', 'EDU_PLAN',       1110, 'Y', 'system'),
    ('edu-training-log',       '교육일지',             'EDU', 'EDU_LOG',        1120, 'Y', 'system'),
    -- 성적서 (HWP)
    ('test-product-report',    '제품검사 성적서',      'TST', 'PROD_TEST',      1210, 'Y', 'system'),
    ('test-surface-report',    '표면오염도 검사 성적서','TST','SURFACE_TEST',   1220, 'Y', 'system'),
    -- 일지설정 (기존 BAS 화면을 SET 모듈로도 묶을 leaf — 동일 화면코드 재사용은 불가하므로 설정 허브용 별칭 없이 이동)
    -- 기준정보의 설정성 화면은 메뉴만 SET 부모 아래로 재배치한다(scrn_cd 유지)
    -- CCP 유형별 공통 화면 (동일 CcpGenericMonitorPage, tmpl_cd로 고정)
    ('ccp-heat-monitor',       '가열·삶기 CCP',        'CCP', 'CCP_HEAT',       151, 'Y', 'system'),
    ('ccp-wash-monitor',       '세척 CCP',             'CCP', 'CCP_WASH',       152, 'Y', 'system'),
    ('ccp-sanitize-monitor',   '소독·헹굼 CCP',        'CCP', 'CCP_SANITIZE',   153, 'Y', 'system'),
    ('ccp-filter-monitor',     '여과 CCP',             'CCP', 'CCP_FILTER',     154, 'Y', 'system'),
    ('ccp-iqf-monitor',        '급속냉동 CCP',         'CCP', 'CCP_IQF',        155, 'Y', 'system')
ON CONFLICT (scrn_cd) DO UPDATE SET
    scrn_nm = EXCLUDED.scrn_nm,
    module_cd = EXCLUDED.module_cd,
    tmpl_cd = EXCLUDED.tmpl_cd,
    sort_no = EXCLUDED.sort_no,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- 일지설정 화면은 기존 BAS scrn_cd를 SET 모듈로 옮긴다 (메뉴 트리 정리)
UPDATE tbl_screen
   SET module_cd = 'SET',
       sort_no = CASE scrn_cd
           WHEN 'template-check-item-management' THEN 1310
           WHEN 'ccp-limit-management' THEN 1320
           WHEN 'approval-line-management' THEN 1330
           WHEN 'schedule-cycle-management' THEN 1340
           WHEN 'smart-diary-type-management' THEN 1350
           ELSE sort_no END,
       upd_id = 'system',
       upd_dt = now()
 WHERE scrn_cd IN (
    'template-check-item-management',
    'ccp-limit-management',
    'approval-line-management',
    'schedule-cycle-management',
    'smart-diary-type-management'
 );

-- ------------------------------------------------------------
-- 2. 공통코드 — 결재 행위 (화면 하드코딩 제거용)
-- ------------------------------------------------------------
INSERT INTO tbl_code (co_cd, main_cd, sub_cd, code_nm, sort_no, ref1, sys_yn, ins_id) VALUES
    ('0000', 'APPR_ACTION', '*',        '결재 행위', 0, NULL, 'Y', 'system'),
    ('0000', 'APPR_ACTION', 'REQUEST',  '상신',       1, NULL, 'Y', 'system'),
    ('0000', 'APPR_ACTION', 'REVIEW',   '검토완료',   2, NULL, 'Y', 'system'),
    ('0000', 'APPR_ACTION', 'APPROVE',  '승인',       3, NULL, 'Y', 'system'),
    ('0000', 'APPR_ACTION', 'REJECT',   '반려',       4, NULL, 'Y', 'system'),
    ('0000', 'APPR_ACTION', 'CANCEL',   '상신취소',   5, NULL, 'Y', 'system'),
    ('0000', 'APPR_ROLE',   '*',        '결재 역할', 0, NULL, 'Y', 'system'),
    ('0000', 'APPR_ROLE',   'WRITE',    '작성',       1, NULL, 'Y', 'system'),
    ('0000', 'APPR_ROLE',   'REVIEW',   '검토',       2, NULL, 'Y', 'system'),
    ('0000', 'APPR_ROLE',   'APPROVE',  '승인',       3, NULL, 'Y', 'system'),
    ('0000', 'APPR_RESULT', '*',        '결재 결과', 0, NULL, 'Y', 'system'),
    ('0000', 'APPR_RESULT', 'W',        '대기',       1, NULL, 'Y', 'system'),
    ('0000', 'APPR_RESULT', 'A',        '승인',       2, NULL, 'Y', 'system'),
    ('0000', 'APPR_RESULT', 'R',        '반려',       3, NULL, 'Y', 'system')
ON CONFLICT (co_cd, main_cd, sub_cd) DO UPDATE SET
    code_nm = EXCLUDED.code_nm,
    sort_no = EXCLUDED.sort_no,
    upd_id = 'system',
    upd_dt = now();

-- ------------------------------------------------------------
-- 3. 기존 테넌트 메뉴 부모
-- ------------------------------------------------------------
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, v.menu_cd, v.menu_nm, NULL, NULL, v.sort_no, 'Y', 'system', now()
  FROM tbl_company c
 CROSS JOIN (VALUES
    ('MLAW', '법적서류', 1000),
    ('MEDU', '교육',     1100),
    ('MTST', '성적서',   1200),
    ('MSET', '일지설정', 1300)
 ) AS v(menu_cd, menu_nm, sort_no)
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm,
    sort_no = EXCLUDED.sort_no,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- ------------------------------------------------------------
-- 4. leaf 메뉴 — 신규 화면
-- ------------------------------------------------------------
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, s.scrn_cd, s.scrn_nm, 'M' || s.module_cd, s.scrn_cd, s.sort_no, 'Y', 'system', now()
  FROM tbl_company c
 CROSS JOIN tbl_screen s
 WHERE s.scrn_cd IN (
    'law-health-cert', 'law-material-ledger', 'law-building-ledger', 'law-production-ledger',
    'law-business-license', 'law-self-quality-test', 'law-completion-cert',
    'edu-annual-plan', 'edu-training-log',
    'test-product-report', 'test-surface-report',
    'ccp-heat-monitor', 'ccp-wash-monitor', 'ccp-sanitize-monitor', 'ccp-filter-monitor', 'ccp-iqf-monitor'
 )
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm,
    h_menu_cd = EXCLUDED.h_menu_cd,
    scrn_cd = EXCLUDED.scrn_cd,
    sort_no = EXCLUDED.sort_no,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- 일지설정 leaf — 기존 BAS 화면을 MSET 아래로 재배치
UPDATE tbl_menu m
   SET h_menu_cd = 'MSET',
       sort_no = s.sort_no,
       upd_id = 'system',
       upd_dt = now()
  FROM tbl_screen s
 WHERE m.scrn_cd = s.scrn_cd
   AND s.module_cd = 'SET'
   AND m.menu_cd = s.scrn_cd;

-- ------------------------------------------------------------
-- 5. 관리자 권한
-- ------------------------------------------------------------
INSERT INTO tbl_role_screen (
    co_cd, usrgrp_cd, scrn_cd, read_yn, write_yn, modify_yn, delete_yn, print_yn, ins_id, ins_dt
)
SELECT g.co_cd, g.usrgrp_cd, s.scrn_cd, 'Y', 'Y', 'Y', 'Y', 'Y', 'system', now()
  FROM tbl_role g
 CROSS JOIN tbl_screen s
 WHERE g.usrgrp_cd = 'ADMIN'
   AND s.scrn_cd IN (
    'law-health-cert', 'law-material-ledger', 'law-building-ledger', 'law-production-ledger',
    'law-business-license', 'law-self-quality-test', 'law-completion-cert',
    'edu-annual-plan', 'edu-training-log',
    'test-product-report', 'test-surface-report',
    'ccp-heat-monitor', 'ccp-wash-monitor', 'ccp-sanitize-monitor', 'ccp-filter-monitor', 'ccp-iqf-monitor'
 )
ON CONFLICT (co_cd, usrgrp_cd, scrn_cd) DO NOTHING;

-- ------------------------------------------------------------
-- 6. 법적·교육·성적서 템플릿 → 전용 화면 코드 연결
-- ------------------------------------------------------------
UPDATE tbl_template t
   SET scrn_cd = s.scrn_cd,
       upd_id = 'system',
       upd_dt = now()
  FROM tbl_screen s
 WHERE s.tmpl_cd = t.tmpl_cd
   AND s.module_cd IN ('LAW', 'EDU', 'TST')
   AND (t.scrn_cd IS DISTINCT FROM s.scrn_cd);

UPDATE tbl_template
   SET scrn_cd = CASE tmpl_cd
           WHEN 'CCP_HEAT' THEN 'ccp-heat-monitor'
           WHEN 'CCP_WASH' THEN 'ccp-wash-monitor'
           WHEN 'CCP_SANITIZE' THEN 'ccp-sanitize-monitor'
           WHEN 'CCP_FILTER' THEN 'ccp-filter-monitor'
           WHEN 'CCP_IQF' THEN 'ccp-iqf-monitor'
           ELSE scrn_cd END,
       upd_id = 'system',
       upd_dt = now()
 WHERE tmpl_cd IN ('CCP_HEAT', 'CCP_WASH', 'CCP_SANITIZE', 'CCP_FILTER', 'CCP_IQF');
