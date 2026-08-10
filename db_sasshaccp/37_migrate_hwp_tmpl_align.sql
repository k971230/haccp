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
    ('VISITOR_LOG',  '입출입대장',               'HA-HYG-03', 'HWP', 'HYG', 'visitor-log',          'E', 24, 'Y', 103, '_template/VISITOR_LOG.hwp',  'system'),
    ('VISUAL_INSP',  '육안검사기준',             'HA-INV-10', 'HWP', 'INV', 'visual-insp-standard', 'E', 36, 'Y', 113, '_template/VISUAL_INSP.hwp',  'system'),
    ('SUBMAT_RECV',  '부자재입고검수점검표',     'HA-INV-12', 'HWP', 'INV', 'submaterial-recv-hwp', 'E', 24, 'Y', 115, '_template/SUBMAT_RECV.hwp',  'system'),
    ('CALIB_EXT',    '외부검교정기록부',         'HA-FAC-15', 'HWP', 'FAC', 'calib-ext-hwp',        'Y', 24, 'Y', 117, '_template/CALIB_EXT.hwp',    'system'),
    ('SHIPMENT',     '제품출고관리일지',         'HA-INV-17', 'HWP', 'INV', 'shipment-log-hwp',     'E', 24, 'Y', 118, '_template/SHIPMENT.hwp',     'system'),
    ('RECALL',       '회수결과보고서',           'HA-DOC-22', 'HWP', 'DOC', 'recall-hwp',           'E', 36, 'Y', 125, '_template/RECALL.hwp',       'system'),
    ('EVAL',         '실시상황평가표',           'HA-VER-23', 'HWP', 'VER', 'eval-hwp',             'Y', 36, 'Y', 126, '_template/EVAL.hwp',         'system')
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
    ('PERSONAL_HYG', 'personal-hyg-hwp',   'HA-HYG-05'),
    ('AREA_HYG',     'area-hyg-hwp',       'HA-HYG-06'),
    ('WATER',        'water-hwp',          'HA-HYG-07'),
    ('WASTE',        'waste-hwp',          'HA-FAC-18'),
    ('INV_CHECK',    'inventory-hwp',      'HA-INV-19'),
    ('RECV_INSP',    'receiving-insp-hwp', 'HA-INV-11'),
    ('PROCESS',      'process-hwp',        'HA-PRC-26'),
    ('VERIFY_PLAN',  'verify-plan-hwp',    'HA-VER-04'),
    ('VERIFY_CHECK', 'verify-check-hwp',   'HA-VER-05'),
    ('VERIFY_REPORT','verify-report-hwp',  'HA-VER-06'),
    ('VERIFY_CA',    'verify-ca-hwp',      'HA-VER-24'),
    ('EDU_PLAN',     'edu-plan-hwp',       'HA-EDU-18'),
    ('EDU_LOG',      'edu-log-hwp',        'HA-EDU-19'),
    ('BAD_PRODUCT',  'bad-product-hwp',    'HA-DOC-20'),
    ('CLAIM',        'claim-hwp',          'HA-DOC-21'),
    ('HANDOVER',     'handover-hwp',       'HA-DOC-25'),
    ('VEHICLE_LOG',  'vehicle-hwp',        'HA-FAC-27'),
    ('EQUIP_CARD',   'equipment-history',  'HA-FAC-08'),
    ('PROD_TEST',    'prod-test-hwp',      'HA-VER-21'),
    ('SURFACE_TEST', 'surface-test-hwp',   'HA-VER-22'),
    ('CALIB_LOG_TEMP','calib-self-hwp',    'HA-FAC-14'),
    ('CALIB_LOG_WGT','calib-self-hwp',     'HA-FAC-14'),
    ('CALIB_LOG_SCL','calib-self-hwp',     'HA-FAC-14'),
    ('LAW_HEALTH',   'health-cert-record', 'HA-HYG-02')
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
    ('DAILY_HYG',  'daily-hygiene-check',    'HA-HYG-01'),
    ('PEST',       'pest-control-check',     'HA-HYG-04'),
    ('CCP_COLD',   'ccp-cold-monitor',       'HA-CCP-05'),
    ('CCP_HEAT',   'ccp-heat-monitor',       'HA-CCP-06-01'),
    ('CCP_SANITIZE','ccp-sanitize-monitor',  'HA-CCP-06-02'),
    ('CCP_FILTER', 'ccp-filter-monitor',     'HA-CCP-06-03'),
    ('CCP_METAL',  'ccp-metal-monitor',      'HA-CCP-06-04'),
    ('CCP_VERIFY', 'ccp-verification-check', 'HA-CCP-07'),
    ('FACILITY',   'facility-equipment-check','HA-FAC-09')
  ) AS v(tmpl_cd, scrn_cd, mng_no)
 WHERE tbl_template.tmpl_cd = v.tmpl_cd;

-- ------------------------------------------------------------
-- 3. 화면 tmpl_cd 연결 (NULL 이었던 leaf)
-- ------------------------------------------------------------
UPDATE tbl_screen SET tmpl_cd = v.tmpl_cd, upd_id = 'system', upd_dt = now()
  FROM (VALUES
    ('visitor-log',          'VISITOR_LOG'),
    ('visual-insp-standard', 'VISUAL_INSP'),
    ('submaterial-recv-hwp', 'SUBMAT_RECV'),
    ('calib-ext-hwp',        'CALIB_EXT'),
    ('shipment-log-hwp',     'SHIPMENT'),
    ('recall-hwp',           'RECALL'),
    ('eval-hwp',             'EVAL'),
    ('health-cert-record',   'LAW_HEALTH'),
    ('equipment-history',    'EQUIP_CARD'),
    ('receiving-insp-hwp',   'RECV_INSP'),
    ('calib-self-hwp',       'CALIB_LOG_TEMP'),
    ('waste-hwp',            'WASTE'),
    ('inventory-hwp',        'INV_CHECK'),
    ('edu-plan-hwp',         'EDU_PLAN'),
    ('edu-log-hwp',          'EDU_LOG'),
    ('bad-product-hwp',      'BAD_PRODUCT'),
    ('claim-hwp',            'CLAIM'),
    ('handover-hwp',         'HANDOVER'),
    ('process-hwp',          'PROCESS'),
    ('vehicle-hwp',          'VEHICLE_LOG'),
    ('personal-hyg-hwp',     'PERSONAL_HYG'),
    ('area-hyg-hwp',         'AREA_HYG'),
    ('water-hwp',            'WATER'),
    ('verify-plan-hwp',      'VERIFY_PLAN'),
    ('verify-check-hwp',     'VERIFY_CHECK'),
    ('verify-report-hwp',    'VERIFY_REPORT'),
    ('verify-ca-hwp',        'VERIFY_CA'),
    ('prod-test-hwp',        'PROD_TEST'),
    ('surface-test-hwp',     'SURFACE_TEST')
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
    'VISITOR_LOG','VISUAL_INSP','SUBMAT_RECV','CALIB_EXT','SHIPMENT','RECALL','EVAL'
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
    'VISITOR_LOG','VISUAL_INSP','SUBMAT_RECV','CALIB_EXT','SHIPMENT','RECALL','EVAL'
 )
ON CONFLICT (co_cd, tmpl_cd) DO NOTHING;
