-- ============================================================
-- 37 — HWP leaf 양식·문서번호 정합 (DB→HWP 전환 + 신규 tmpl)
--
-- 개발자: 박승우
-- 일자: 2026-08-07
-- 코멘트:
--   1) IA 문서작성 leaf마다 tmpl_cd·HA-*·doc_kind=HWP 를 1:1로 맞춘다
--   2) 구 DB형(개인위생·폐기물 등)은 메뉴만 HWP이던 갭을 양식 메타로 닫는다
--   3) 신규 카탈로그(입출입·육안검사 등)를 넣고 업체 사용양식·화면 tmpl를 연결한다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 신규 HWP 양식 (메뉴만 있고 tmpl 없던 leaf)
-- ------------------------------------------------------------
INSERT INTO tbl_template
    (tmpl_cd, tmpl_nm, mng_no, doc_kind, category_cd, scrn_cd,
     default_cycle_cd, default_retention_month, impl_yn, sort_no, form_path, ins_id)
VALUES
    ('tmpl_admin-visitor-log',  '입출입대장',               'HA-HYG-03', 'HWP', 'HYG', 'visitor-log',          'E', 24, 'Y', 103, '_template/tmpl_admin-visitor-log.hwp',  'system'),
    ('tmpl_prp-visual-inspect',  '육안검사기준',             'HA-INV-10', 'HWP', 'INV', 'visual-insp-standard', 'E', 36, 'Y', 113, '_template/tmpl_prp-visual-inspect.hwp',  'system'),
    ('tmpl_logis-submat-receive',  '부자재입고검수점검표',     'HA-INV-12', 'HWP', 'INV', 'submaterial-recv-hwp', 'E', 24, 'Y', 115, '_template/tmpl_logis-submat-receive.hwp',  'system'),
    ('tmpl_prp-calib-ext',    '외부검교정기록부',         'HA-FAC-15', 'HWP', 'FAC', 'calib-ext-hwp',        'Y', 24, 'Y', 117, '_template/tmpl_prp-calib-ext.hwp',    'system'),
    ('tmpl_logis-shipment-log',     '제품출고관리일지',         'HA-INV-17', 'HWP', 'INV', 'shipment-log-hwp',     'E', 24, 'Y', 118, '_template/tmpl_logis-shipment-log.hwp',     'system'),
    ('tmpl_admin-recall-report',       '회수결과보고서',           'HA-DOC-22', 'HWP', 'DOC', 'recall-hwp',           'E', 36, 'Y', 125, '_template/RECALL.hwp',       'system'),
    ('tmpl_admin-eval-check',         '실시상황평가표',           'HA-VER-23', 'HWP', 'VER', 'eval-hwp',             'Y', 36, 'Y', 126, '_template/EVAL.hwp',         'system')
ON CONFLICT (tmpl_cd) DO UPDATE SET
    tmpl_nm     = EXCLUDED.tmpl_nm,
    mng_no      = EXCLUDED.mng_no,
    doc_kind    = 'HWP',
    category_cd = EXCLUDED.category_cd,
    scrn_cd     = EXCLUDED.scrn_cd,
    impl_yn     = 'Y',
    sort_no     = EXCLUDED.sort_no,
    form_path   = EXCLUDED.form_path,
    upd_id      = 'system',
    upd_dt      = now();

-- ------------------------------------------------------------
-- 2. 기존 양식 — DB→HWP 전환 + 작성 화면코드 연결
-- ------------------------------------------------------------
UPDATE tbl_template SET
    doc_kind = 'HWP',
    scrn_cd  = v.scrn_cd,
    mng_no   = COALESCE(v.mng_no, tbl_template.mng_no),
    form_path = COALESCE(tbl_template.form_path, '_template/' || tbl_template.tmpl_cd || '.hwp'),
    upd_id   = 'system',
    upd_dt   = now()
  FROM (VALUES
    ('tmpl_prp-hygiene-personal', 'personal-hyg-hwp',   'HA-HYG-05'),
    ('tmpl_prp-hygiene-area',     'area-hyg-hwp',       'HA-HYG-06'),
    ('tmpl_prp-water-check',        'water-hwp',          'HA-HYG-07'),
    ('tmpl_prp-waste-check',        'waste-hwp',          'HA-FAC-18'),
    ('tmpl_logis-inventory-check',    'inventory-hwp',      'HA-INV-19'),
    ('tmpl_logis-receive-inspect',    'receiving-insp-hwp', 'HA-INV-11'),
    ('tmpl_ccp-process-check',      'process-hwp',        'HA-PRC-26'),
    ('tmpl_prp-verify-plan',  'verify-plan-hwp',    'HA-VER-04'),
    ('tmpl_prp-verify-check', 'verify-check-hwp',   'HA-VER-05'),
    ('tmpl_prp-verify-report','verify-report-hwp',  'HA-VER-06'),
    ('tmpl_prp-verify-action',    'verify-ca-hwp',      'HA-VER-24'),
    ('tmpl_admin-edu-plan',     'edu-plan-hwp',       'HA-EDU-18'),
    ('tmpl_admin-edu-log',      'edu-log-hwp',        'HA-EDU-19'),
    ('tmpl_admin-bad-product',  'bad-product-hwp',    'HA-DOC-20'),
    ('tmpl_admin-claim-log',        'claim-hwp',          'HA-DOC-21'),
    ('tmpl_admin-handover-doc',     'handover-hwp',       'HA-DOC-25'),
    ('tmpl_logis-vehicle-log',  'vehicle-hwp',        'HA-FAC-27'),
    ('tmpl_prp-equip-card',   'equipment-history',  'HA-FAC-08'),
    ('tmpl_prp-test-product',    'prod-test-hwp',      'HA-VER-21'),
    ('tmpl_prp-test-surface', 'surface-test-hwp',   'HA-VER-22'),
    ('tmpl_prp-calib-temp','calib-self-hwp',    'HA-FAC-14'),
    ('tmpl_prp-calib-weight','calib-self-hwp',     'HA-FAC-14'),
    ('tmpl_prp-calib-scale','calib-self-hwp',     'HA-FAC-14'),
    ('tmpl_admin-law-health',   'health-cert-record', 'HA-HYG-02')
  ) AS v(tmpl_cd, scrn_cd, mng_no)
 WHERE tbl_template.tmpl_cd = v.tmpl_cd;

-- DB로 남는 작성 양식 — scrn·문서번호만 재확인
UPDATE tbl_template SET
    doc_kind = 'DB',
    scrn_cd  = v.scrn_cd,
    mng_no   = v.mng_no,
    upd_id   = 'system',
    upd_dt   = now()
  FROM (VALUES
    ('tmpl_prp-hygiene-daily',  'daily-hygiene-check',    'HA-HYG-01'),
    ('tmpl_prp-pest-check',       'pest-control-check',     'HA-HYG-04'),
    ('tmpl_ccp-cold-log',   'ccp-cold-monitor',       'HA-CCP-05'),
    ('tmpl_ccp-heat-log',   'ccp-heat-monitor',       'HA-CCP-06-01'),
    ('tmpl_ccp-sanitize-log','ccp-sanitize-monitor',  'HA-CCP-06-02'),
    ('tmpl_ccp-filter-log', 'ccp-filter-monitor',     'HA-CCP-06-03'),
    ('tmpl_ccp-metal-log',  'ccp-metal-monitor',      'HA-CCP-06-04'),
    ('tmpl_ccp-verify-check', 'ccp-verification-check', 'HA-CCP-07'),
    ('tmpl_prp-facility-check',   'facility-equipment-check','HA-FAC-09')
  ) AS v(tmpl_cd, scrn_cd, mng_no)
 WHERE tbl_template.tmpl_cd = v.tmpl_cd;

-- ------------------------------------------------------------
-- 3. 화면 tmpl_cd 연결 (NULL 이었던 leaf)
-- ------------------------------------------------------------
UPDATE tbl_screen SET tmpl_cd = v.tmpl_cd, upd_id = 'system', upd_dt = now()
  FROM (VALUES
    ('visitor-log',          'tmpl_admin-visitor-log'),
    ('visual-insp-standard', 'tmpl_prp-visual-inspect'),
    ('submaterial-recv-hwp', 'tmpl_logis-submat-receive'),
    ('calib-ext-hwp',        'tmpl_prp-calib-ext'),
    ('shipment-log-hwp',     'tmpl_logis-shipment-log'),
    ('recall-hwp',           'tmpl_admin-recall-report'),
    ('eval-hwp',             'tmpl_admin-eval-check'),
    ('health-cert-record',   'tmpl_admin-law-health'),
    ('equipment-history',    'tmpl_prp-equip-card'),
    ('receiving-insp-hwp',   'tmpl_logis-receive-inspect'),
    ('calib-self-hwp',       'tmpl_prp-calib-temp'),
    ('waste-hwp',            'tmpl_prp-waste-check'),
    ('inventory-hwp',        'tmpl_logis-inventory-check'),
    ('edu-plan-hwp',         'tmpl_admin-edu-plan'),
    ('edu-log-hwp',          'tmpl_admin-edu-log'),
    ('bad-product-hwp',      'tmpl_admin-bad-product'),
    ('claim-hwp',            'tmpl_admin-claim-log'),
    ('handover-hwp',         'tmpl_admin-handover-doc'),
    ('process-hwp',          'tmpl_ccp-process-check'),
    ('vehicle-hwp',          'tmpl_logis-vehicle-log'),
    ('personal-hyg-hwp',     'tmpl_prp-hygiene-personal'),
    ('area-hyg-hwp',         'tmpl_prp-hygiene-area'),
    ('water-hwp',            'tmpl_prp-water-check'),
    ('verify-plan-hwp',      'tmpl_prp-verify-plan'),
    ('verify-check-hwp',     'tmpl_prp-verify-check'),
    ('verify-report-hwp',    'tmpl_prp-verify-report'),
    ('verify-ca-hwp',        'tmpl_prp-verify-action'),
    ('prod-test-hwp',        'tmpl_prp-test-product'),
    ('surface-test-hwp',     'tmpl_prp-test-surface')
  ) AS v(scrn_cd, tmpl_cd)
 WHERE tbl_screen.scrn_cd = v.scrn_cd;

-- ------------------------------------------------------------
-- 4. 기존 업체 사용양식 — 신규 tmpl 활성화
-- ------------------------------------------------------------
INSERT INTO tbl_company_template (co_cd, tmpl_cd, use_yn, cycle_cd, retention_month, ins_id, ins_dt)
SELECT c.co_cd, t.tmpl_cd, 'Y', t.default_cycle_cd, t.default_retention_month, 'system', now()
  FROM tbl_company c
 CROSS JOIN tbl_template t
 WHERE t.tmpl_cd IN (
    'tmpl_admin-visitor-log','tmpl_prp-visual-inspect','tmpl_logis-submat-receive','tmpl_prp-calib-ext','tmpl_logis-shipment-log','tmpl_admin-recall-report','tmpl_admin-eval-check'
 )
ON CONFLICT (co_cd, tmpl_cd) DO UPDATE SET
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- ------------------------------------------------------------
-- 5. 기존 업체 문서번호 채번 규칙 — HWP 신규 작성 시 sp_tbl_doc_no_gen_c_000
-- ------------------------------------------------------------
INSERT INTO tbl_doc_no_rule (co_cd, tmpl_cd, prefix, date_fmt, seq_len, reset_cycle, ins_id, ins_dt)
SELECT c.co_cd, t.tmpl_cd, t.tmpl_cd, 'YYYYMMDD', 3, 'D', 'system', now()
  FROM tbl_company c
 CROSS JOIN tbl_template t
 WHERE t.tmpl_cd IN (
    'tmpl_admin-visitor-log','tmpl_prp-visual-inspect','tmpl_logis-submat-receive','tmpl_prp-calib-ext','tmpl_logis-shipment-log','tmpl_admin-recall-report','tmpl_admin-eval-check'
 )
ON CONFLICT (co_cd, tmpl_cd) DO NOTHING;
