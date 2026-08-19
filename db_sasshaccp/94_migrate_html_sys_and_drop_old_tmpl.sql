-- ============================================================
-- 94 — HTML 양식 html_sys_NNN 매김 · 대체된 tmpl_* 삭제 · 사용양식 목록 정리
--
-- 파일번호: 94
-- 이전번호: 93
-- 개발자: 박승우
-- 일자: 2026-08-19
-- 코멘트:
--   1) 사용양식 관리는 hwp_sys_001~027 + hwp_usr_* 만 보여 준다
--   2) 전용 HTML 화면 코드는 html_sys_001~011 로 바꾸고, 옛 kebab 은 지운다
--   3) HWP 메뉴가 쓰던 kebab 은 이미 시드된 hwp_sys_* 로 붙인 뒤 옛 행을 지운다
--      공정관리·부자재입고·외부검교정·출고·실시상황평가 kebab 은 27건에 없어 카탈로그에 남긴다
--   4) 거래처구분·폐기구분 값 tmpl_prp-waste-check 는 양식코드가 아니라서 건드리지 않는다
--
-- Jenkins는 migrate를 안 돌리므로 적용은 DBeaver/수동
-- 운영 정본은 94/95. 신규 설치는 09 정본을 쓰고 50~94 를 재실행하지 않는다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 매핑표 — old_cd 를 new_cd 로. kind 는 html(신규 시드) / hwp(기존 hwp_sys)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS tmp_tmpl_remap;
CREATE TEMP TABLE tmp_tmpl_remap (
    old_cd varchar(40) PRIMARY KEY,
    new_cd varchar(40) NOT NULL,
    kind   varchar(10) NOT NULL
);

INSERT INTO tmp_tmpl_remap (old_cd, new_cd, kind) VALUES
    -- HTML 전용 화면
    ('tmpl_ccp-cold-log',         'html_sys_001', 'html'),
    ('tmpl_ccp-metal-log',        'html_sys_002', 'html'),
    ('tmpl_ccp-heat-log',         'html_sys_003', 'html'),
    ('tmpl_ccp-sanitize-log',     'html_sys_004', 'html'),
    ('tmpl_ccp-filter-log',       'html_sys_005', 'html'),
    ('tmpl_ccp-verify-check',     'html_sys_006', 'html'),
    ('tmpl_prp-hygiene-daily',    'html_sys_007', 'html'),
    ('tmpl_prp-pest-check',       'html_sys_008', 'html'),
    ('tmpl_prp-facility-check',   'html_sys_009', 'html'),
    ('tmpl_prp-calib-target',     'html_sys_010', 'html'),
    ('tmpl_admin-law-health',     'html_sys_011', 'html'),
    -- HWP 27건으로 대체
    ('tmpl_admin-visitor-log',    'hwp_sys_001', 'hwp'),
    ('tmpl_admin-handover-doc',   'hwp_sys_002', 'hwp'),
    ('tmpl_prp-verify-plan',      'hwp_sys_003', 'hwp'),
    ('tmpl_prp-verify-check',     'hwp_sys_004', 'hwp'),
    ('tmpl_prp-verify-report',    'hwp_sys_005', 'hwp'),
    ('tmpl_prp-verify-action',    'hwp_sys_006', 'hwp'),
    ('tmpl_admin-edu-plan',       'hwp_sys_007', 'hwp'),
    ('tmpl_admin-edu-log',        'hwp_sys_008', 'hwp'),
    ('tmpl_prp-hygiene-personal', 'hwp_sys_009', 'hwp'),
    ('tmpl_prp-hygiene-area',     'hwp_sys_010', 'hwp'),
    ('tmpl_prp-calib-temp',       'hwp_sys_014', 'hwp'),
    ('tmpl_prp-calib-weight',     'hwp_sys_014', 'hwp'),
    ('tmpl_prp-calib-scale',      'hwp_sys_014', 'hwp'),
    ('tmpl_prp-waste-check',      'hwp_sys_015', 'hwp'),
    ('tmpl_logis-inventory-check','hwp_sys_016', 'hwp'),
    ('tmpl_logis-receive-inspect','hwp_sys_017', 'hwp'),
    ('tmpl_prp-test-product',     'hwp_sys_018', 'hwp'),
    ('tmpl_prp-test-surface',     'hwp_sys_019', 'hwp'),
    ('tmpl_admin-bad-product',    'hwp_sys_020', 'hwp'),
    ('tmpl_prp-water-check',      'hwp_sys_021', 'hwp'),
    ('tmpl_admin-claim-log',      'hwp_sys_022', 'hwp'),
    ('tmpl_logis-vehicle-log',    'hwp_sys_023', 'hwp'),
    ('tmpl_admin-recall-report',  'hwp_sys_025', 'hwp'),
    ('tmpl_prp-visual-inspect',   'hwp_sys_026', 'hwp');

-- ------------------------------------------------------------
-- 2. html_sys 카탈로그·회사양식 시드 — 옛 HTML kebab 행을 복사한다
-- ------------------------------------------------------------
INSERT INTO tbl_template (
    co_cd, tmpl_cd, tmpl_nm, mng_no, doc_kind, category_cd, scrn_cd,
    default_cycle_cd, default_retention_month, impl_yn, sort_no, use_yn,
    form_path, ins_id, ins_dt
)
SELECT COALESCE(t.co_cd, '0000'),
       m.new_cd,
       t.tmpl_nm,
       t.mng_no,
       'html',
       t.category_cd,
       t.scrn_cd,
       t.default_cycle_cd,
       t.default_retention_month,
       t.impl_yn,
       t.sort_no,
       'Y',
       NULL,
       'system',
       now()
  FROM tmp_tmpl_remap m
  JOIN tbl_template t ON t.tmpl_cd = m.old_cd
 WHERE m.kind = 'html'
ON CONFLICT (tmpl_cd) DO UPDATE SET
    tmpl_nm     = EXCLUDED.tmpl_nm,
    mng_no      = EXCLUDED.mng_no,
    doc_kind    = 'html',
    category_cd = EXCLUDED.category_cd,
    scrn_cd     = EXCLUDED.scrn_cd,
    impl_yn     = EXCLUDED.impl_yn,
    use_yn      = 'Y',
    form_path   = NULL,
    upd_id      = 'system',
    upd_dt      = now();

-- html_sys 가 카탈로그에만 있고 옛 kebab 이 없는 환경 — 최소 시드
INSERT INTO tbl_template (
    co_cd, tmpl_cd, tmpl_nm, mng_no, doc_kind, category_cd, scrn_cd,
    default_cycle_cd, default_retention_month, impl_yn, sort_no, use_yn, form_path, ins_id, ins_dt
)
SELECT '0000', v.tmpl_cd, v.tmpl_nm, v.mng_no, 'html', v.category_cd, v.scrn_cd,
       v.cycle_cd, 24, 'Y', v.sort_no, 'Y', NULL, 'system', now()
  FROM (VALUES
    ('html_sys_001', 'CCP 냉장·냉동 보관 모니터링 일지', '2-1', 'CCP', 'ccp-cold-monitor',        'D', 101),
    ('html_sys_002', 'CCP 금속검출 모니터링 일지',       '2-2', 'CCP', 'ccp-metal-monitor',       'D', 102),
    ('html_sys_003', '가열 모니터링 일지',               NULL,  'CCP', 'ccp-heat-monitor',        'D', 103),
    ('html_sys_004', '멸균 모니터링 일지',               NULL,  'CCP', 'ccp-sanitize-monitor',    'D', 104),
    ('html_sys_005', '여과 모니터링 일지',               NULL,  'CCP', 'ccp-filter-monitor',      'D', 105),
    ('html_sys_006', '중요관리점(CCP) 검증점검표',        '3',   'CCP', 'ccp-verification-check',  'M', 106),
    ('html_sys_007', '일일 위생 점검일지',                '10',  'HYG', 'daily-hygiene-check',     'D', 107),
    ('html_sys_008', '방충·방서 점검표',                  '13',  'HYG', 'pest-control-check',      'W', 108),
    ('html_sys_009', '시설·설비·처리도구 점검표',         '14',  'FAC', 'facility-equipment-check','W', 109),
    ('html_sys_010', '검·교정 대상',                      '15',  'FAC', 'calibration-target-management','Y', 110),
    ('html_sys_011', '보건증관리',                        NULL,  'LAW', 'health-cert-record',      'E', 111)
  ) AS v(tmpl_cd, tmpl_nm, mng_no, category_cd, scrn_cd, cycle_cd, sort_no)
ON CONFLICT (tmpl_cd) DO NOTHING;

INSERT INTO tbl_company_template (
    co_cd, tmpl_cd, tmpl_nm_ovr, use_yn, sys_yn, cycle_cd, retention_month, form_path, ins_id, ins_dt
)
SELECT c.co_cd, t.tmpl_cd, t.tmpl_nm, 'Y', 'sys', t.default_cycle_cd, t.default_retention_month, NULL, 'system', now()
  FROM tbl_company c
  JOIN tbl_template t ON t.tmpl_cd LIKE 'html_sys_%'
ON CONFLICT (co_cd, tmpl_cd) DO UPDATE SET
    tmpl_nm_ovr = EXCLUDED.tmpl_nm_ovr,
    sys_yn      = 'sys',
    use_yn      = 'Y',
    form_path   = NULL,
    upd_id      = 'system',
    upd_dt      = now();

-- ------------------------------------------------------------
-- 3. tmpl_cd 를 매핑대로 옮긴다
--    문서처럼 양식당 여러 행인 표는 UPDATE 만 한다
--    (co_cd, tmpl_cd) 유니크 표는 대상이 이미 있으면 옛 행만 지운다
-- ------------------------------------------------------------
-- 문서·화면 — 여러 행이 같은 양식을 가진다
UPDATE tbl_document d SET tmpl_cd = m.new_cd FROM tmp_tmpl_remap m WHERE d.tmpl_cd = m.old_cd;
UPDATE tbl_screen s SET tmpl_cd = m.new_cd FROM tmp_tmpl_remap m WHERE s.tmpl_cd = m.old_cd;

-- 회사양식: html_sys 는 위에서 시드됨. hwp_sys 도 93 시드됨. 옛 kebab 행은 나중에 DELETE
-- 파일 이력은 html 은 버리고, hwp 는 대상에 이미 파일이 있으면 옛 파일만 지운다
DELETE FROM tbl_company_template_file f
 USING tmp_tmpl_remap m
 WHERE f.tmpl_cd = m.old_cd
   AND (
        m.kind = 'html'
     OR EXISTS (
            SELECT 1 FROM tbl_company_template_file x
             WHERE x.co_cd = f.co_cd AND x.tmpl_cd = m.new_cd AND x.file_seq = f.file_seq
        )
   );
DELETE FROM tbl_company_template_file f
 WHERE f.idx IN (
        SELECT s.idx FROM (
            SELECT f2.idx,
                   row_number() OVER (PARTITION BY f2.co_cd, m.new_cd, f2.file_seq ORDER BY f2.idx) AS rn
              FROM tbl_company_template_file f2
              JOIN tmp_tmpl_remap m ON m.old_cd = f2.tmpl_cd
        ) s WHERE s.rn > 1
 );
UPDATE tbl_company_template_file f
   SET tmpl_cd = m.new_cd
  FROM tmp_tmpl_remap m
 WHERE f.tmpl_cd = m.old_cd;

DELETE FROM tbl_company_template ct
 USING tmp_tmpl_remap m
 WHERE ct.tmpl_cd = m.old_cd
   AND EXISTS (SELECT 1 FROM tbl_company_template x WHERE x.co_cd = ct.co_cd AND x.tmpl_cd = m.new_cd);
DELETE FROM tbl_company_template ct
 WHERE ct.idx IN (
        SELECT s.idx FROM (
            SELECT ct2.idx,
                   row_number() OVER (PARTITION BY ct2.co_cd, m.new_cd ORDER BY ct2.idx) AS rn
              FROM tbl_company_template ct2
              JOIN tmp_tmpl_remap m ON m.old_cd = ct2.tmpl_cd
        ) s WHERE s.rn > 1
 );
UPDATE tbl_company_template ct
   SET tmpl_cd = m.new_cd
  FROM tmp_tmpl_remap m
 WHERE ct.tmpl_cd = m.old_cd;

-- 점검항목: 대상에 같은 item_cd 가 있으면 옛 행 삭제
DELETE FROM tbl_check_item i
 USING tmp_tmpl_remap m
 WHERE i.tmpl_cd = m.old_cd
   AND EXISTS (SELECT 1 FROM tbl_check_item x WHERE x.tmpl_cd = m.new_cd AND x.item_cd = i.item_cd);
DELETE FROM tbl_check_item i
 WHERE i.idx IN (
        SELECT s.idx FROM (
            SELECT i2.idx,
                   row_number() OVER (PARTITION BY m.new_cd, i2.item_cd ORDER BY i2.idx) AS rn
              FROM tbl_check_item i2
              JOIN tmp_tmpl_remap m ON m.old_cd = i2.tmpl_cd
        ) s WHERE s.rn > 1
 );
UPDATE tbl_check_item i SET tmpl_cd = m.new_cd FROM tmp_tmpl_remap m WHERE i.tmpl_cd = m.old_cd;

DELETE FROM tbl_company_check_item i
 USING tmp_tmpl_remap m
 WHERE i.tmpl_cd = m.old_cd
   AND EXISTS (
        SELECT 1 FROM tbl_company_check_item x
         WHERE x.co_cd = i.co_cd AND x.tmpl_cd = m.new_cd AND x.item_cd = i.item_cd
   );
DELETE FROM tbl_company_check_item i
 WHERE i.idx IN (
        SELECT s.idx FROM (
            SELECT i2.idx,
                   row_number() OVER (PARTITION BY i2.co_cd, m.new_cd, i2.item_cd ORDER BY i2.idx) AS rn
              FROM tbl_company_check_item i2
              JOIN tmp_tmpl_remap m ON m.old_cd = i2.tmpl_cd
        ) s WHERE s.rn > 1
 );
UPDATE tbl_company_check_item i SET tmpl_cd = m.new_cd FROM tmp_tmpl_remap m WHERE i.tmpl_cd = m.old_cd;

-- 채번·주기
DELETE FROM tbl_doc_no_rule r
 USING tmp_tmpl_remap m
 WHERE r.tmpl_cd = m.old_cd
   AND EXISTS (SELECT 1 FROM tbl_doc_no_rule x WHERE x.co_cd = r.co_cd AND x.tmpl_cd = m.new_cd);
DELETE FROM tbl_doc_no_rule r
 WHERE r.idx IN (
        SELECT s.idx FROM (
            SELECT r2.idx,
                   row_number() OVER (PARTITION BY r2.co_cd, m.new_cd ORDER BY r2.idx) AS rn
              FROM tbl_doc_no_rule r2
              JOIN tmp_tmpl_remap m ON m.old_cd = r2.tmpl_cd
        ) s WHERE s.rn > 1
 );
UPDATE tbl_doc_no_rule r SET tmpl_cd = m.new_cd FROM tmp_tmpl_remap m WHERE r.tmpl_cd = m.old_cd;

DELETE FROM tbl_schedule_rule_detail d
 USING tmp_tmpl_remap m
 WHERE d.tmpl_cd = m.old_cd
   AND EXISTS (
        SELECT 1 FROM tbl_schedule_rule_detail x
         WHERE x.co_cd = d.co_cd AND x.tmpl_cd = m.new_cd AND x.seq = d.seq
   );
DELETE FROM tbl_schedule_rule_detail d
 WHERE d.idx IN (
        SELECT s.idx FROM (
            SELECT d2.idx,
                   row_number() OVER (PARTITION BY d2.co_cd, m.new_cd, d2.seq ORDER BY d2.idx) AS rn
              FROM tbl_schedule_rule_detail d2
              JOIN tmp_tmpl_remap m ON m.old_cd = d2.tmpl_cd
        ) s WHERE s.rn > 1
 );
UPDATE tbl_schedule_rule_detail d SET tmpl_cd = m.new_cd FROM tmp_tmpl_remap m WHERE d.tmpl_cd = m.old_cd;

DELETE FROM tbl_schedule_rule r
 USING tmp_tmpl_remap m
 WHERE r.tmpl_cd = m.old_cd
   AND EXISTS (SELECT 1 FROM tbl_schedule_rule x WHERE x.co_cd = r.co_cd AND x.tmpl_cd = m.new_cd);
DELETE FROM tbl_schedule_rule r
 WHERE r.idx IN (
        SELECT s.idx FROM (
            SELECT r2.idx,
                   row_number() OVER (PARTITION BY r2.co_cd, m.new_cd ORDER BY r2.idx) AS rn
              FROM tbl_schedule_rule r2
              JOIN tmp_tmpl_remap m ON m.old_cd = r2.tmpl_cd
        ) s WHERE s.rn > 1
 );
UPDATE tbl_schedule_rule r SET tmpl_cd = m.new_cd FROM tmp_tmpl_remap m WHERE r.tmpl_cd = m.old_cd;

-- 나머지 *tmpl_cd 컬럼(문서 없는 참조) — 대상 충돌 없이 UPDATE
DO $$
DECLARE
    r record;
    v_sql text;
BEGIN
    FOR r IN
        SELECT c.table_name, c.column_name
          FROM information_schema.columns c
         WHERE c.table_schema = 'sasshaccp'
           AND c.column_name LIKE '%tmpl_cd%'
           AND c.table_name NOT IN (
                'tbl_template', 'tbl_document', 'tbl_screen',
                'tbl_company_template', 'tbl_company_template_file',
                'tbl_check_item', 'tbl_company_check_item',
                'tbl_doc_no_rule', 'tbl_schedule_rule', 'tbl_schedule_rule_detail'
           )
           AND c.table_name NOT LIKE 'tmp_%'
    LOOP
        v_sql := format(
            'UPDATE %I t SET %I = m.new_cd FROM tmp_tmpl_remap m WHERE t.%I = m.old_cd',
            r.table_name, r.column_name, r.column_name
        );
        BEGIN
            EXECUTE v_sql;
        EXCEPTION
            WHEN undefined_table THEN NULL;
            WHEN unique_violation THEN
                RAISE NOTICE 'skip unique % %', r.table_name, r.column_name;
        END;
    END LOOP;
END$$;

-- 문서 연결 유형 — 교육계획·검교정 접미사 유지
UPDATE tbl_document_relation
   SET rel_type = 'hwp_sys_007_LOG'
 WHERE rel_type = 'tmpl_admin-edu-plan_LOG';
UPDATE tbl_document_relation
   SET rel_type = 'html_sys_010_LOG'
 WHERE rel_type = 'tmpl_prp-calib-target_LOG';

INSERT INTO tbl_doc_no_rule(co_cd, tmpl_cd, prefix, date_fmt, seq_len, reset_cycle, ins_id, ins_dt)
SELECT ct.co_cd, ct.tmpl_cd, ct.tmpl_cd, 'YYYYMMDD', 3, 'D', 'system', now()
  FROM tbl_company_template ct
 WHERE ct.tmpl_cd LIKE 'html_sys_%'
ON CONFLICT (co_cd, tmpl_cd) DO NOTHING;

-- ------------------------------------------------------------
-- 4. 대체된 kebab 카탈로그·회사양식 삭제
--    27건에 없는 HWP 메뉴 5개와 법적서류 kebab 은 남긴다
-- ------------------------------------------------------------
DELETE FROM tbl_company_template_file f
 USING tmp_tmpl_remap m
 WHERE f.tmpl_cd = m.old_cd;

DELETE FROM tbl_company_template ct
 USING tmp_tmpl_remap m
 WHERE ct.tmpl_cd = m.old_cd;

DELETE FROM tbl_check_item i
 USING tmp_tmpl_remap m
 WHERE i.tmpl_cd = m.old_cd;

DELETE FROM tbl_template t
 USING tmp_tmpl_remap m
 WHERE t.tmpl_cd = m.old_cd
   AND NOT EXISTS (SELECT 1 FROM tbl_document d WHERE d.tmpl_cd = t.tmpl_cd)
   AND NOT EXISTS (SELECT 1 FROM tbl_company_template ct WHERE ct.tmpl_cd = t.tmpl_cd);

-- 미사용 카탈로그(화면 없음) — 문서가 없을 때만 회사양식·카탈로그 제거
DELETE FROM tbl_company_template_file
 WHERE tmpl_cd IN ('HAZARD_ANAL','CCP_DECIDE','CCP_PLAN','FLOW_CHART','LAYOUT',
                   'PRODUCT_SPEC','RAW_SPEC','PRE_REQ','SUPPLIER_EVAL','TRACE_DRILL',
                   'INTERNAL_AUDIT','ALLERGEN','tmpl_prp-equip-card');
DELETE FROM tbl_company_template ct
 WHERE ct.tmpl_cd IN ('HAZARD_ANAL','CCP_DECIDE','CCP_PLAN','FLOW_CHART','LAYOUT',
                      'PRODUCT_SPEC','RAW_SPEC','PRE_REQ','SUPPLIER_EVAL','TRACE_DRILL',
                      'INTERNAL_AUDIT','ALLERGEN','tmpl_prp-equip-card')
   AND NOT EXISTS (SELECT 1 FROM tbl_document d WHERE d.co_cd = ct.co_cd AND d.tmpl_cd = ct.tmpl_cd);
DELETE FROM tbl_template t
 WHERE t.tmpl_cd IN ('HAZARD_ANAL','CCP_DECIDE','CCP_PLAN','FLOW_CHART','LAYOUT',
                     'PRODUCT_SPEC','RAW_SPEC','PRE_REQ','SUPPLIER_EVAL','TRACE_DRILL',
                     'INTERNAL_AUDIT','ALLERGEN','tmpl_prp-equip-card')
   AND NOT EXISTS (SELECT 1 FROM tbl_document d WHERE d.tmpl_cd = t.tmpl_cd)
   AND NOT EXISTS (SELECT 1 FROM tbl_company_template ct WHERE ct.tmpl_cd = t.tmpl_cd);

-- html_sys 회사양식에는 HWP 파일 이력이 필요 없다
DELETE FROM tbl_company_template_file
 WHERE tmpl_cd LIKE 'html_sys_%';
UPDATE tbl_company_template
   SET default_file_idx = NULL,
       current_file_idx = NULL,
       form_path        = NULL
 WHERE tmpl_cd LIKE 'html_sys_%';

-- ------------------------------------------------------------
-- 5. 살아있는 SP/프로시저 본문의 kebab 리터럴을 새 코드로 바꾼다
-- ------------------------------------------------------------
DO $$
DECLARE
    r record;
    src text;
    nxt text;
    m record;
BEGIN
    FOR r IN
        SELECT p.oid
          FROM pg_proc p
          JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'sasshaccp'
           AND p.prokind IN ('f', 'p')
    LOOP
        src := pg_get_functiondef(r.oid);
        nxt := src;
        FOR m IN
            SELECT old_cd, new_cd
              FROM tmp_tmpl_remap
             ORDER BY length(old_cd) DESC
        LOOP
            nxt := replace(nxt, m.old_cd, m.new_cd);
        END LOOP;
        nxt := replace(nxt, 'tmpl_admin-edu-plan_LOG', 'hwp_sys_007_LOG');
        nxt := replace(nxt, 'tmpl_prp-calib-target_LOG', 'html_sys_010_LOG');
        IF nxt IS DISTINCT FROM src THEN
            BEGIN
                EXECUTE nxt;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE NOTICE 'SP 치환 건너뜀 oid=% : %', r.oid, SQLERRM;
            END;
        END IF;
    END LOOP;
END$$;

-- ------------------------------------------------------------
-- 6. 사용양식 목록 SP — hwp_sys + 사용자추가 HWP 만
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_hwp_template_management_r_000(varchar, varchar, varchar);
CREATE FUNCTION sp_hwp_template_management_r_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위. 필수 등가 조건
    p_co_cd   varchar,
    -- p_tmpl_cd: 헤더 양식코드 검색어. 공백이면 전체
    p_tmpl_cd varchar,
    -- p_tmpl_nm: 헤더 양식명 검색어. 공백이면 전체
    p_tmpl_nm varchar
)
RETURNS TABLE(
    tmpl_cd          varchar,
    tmpl_nm          varchar,
    sys_yn           varchar,
    doc_kind         varchar,
    category_cd      varchar,
    mng_no           varchar,
    form_path        varchar,
    form_file_nm     varchar,
    use_yn           varchar,
    default_file_idx bigint,
    current_file_idx bigint,
    file_hist_cnt    int
) LANGUAGE sql STABLE AS $$
    SELECT ct.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm),
           lower(CASE WHEN COALESCE(ct.sys_yn, 'sys') IN ('N', 'n', 'usr') THEN 'usr' ELSE 'sys' END),
           t.doc_kind,
           t.category_cd,
           t.mng_no,
           COALESCE(NULLIF(ct.form_path, ''), t.form_path),
           CASE
             WHEN COALESCE(NULLIF(ct.form_path, ''), t.form_path) IS NULL THEN NULL
             ELSE regexp_replace(COALESCE(NULLIF(ct.form_path, ''), t.form_path), '^.*/', '')
           END,
           ct.use_yn,
           ct.default_file_idx,
           ct.current_file_idx,
           (SELECT COUNT(*)::int
              FROM tbl_company_template_file f
             WHERE f.co_cd = ct.co_cd AND f.tmpl_cd = ct.tmpl_cd AND f.del_yn = 'N')
      FROM tbl_company_template ct
      JOIN tbl_template t ON t.tmpl_cd = ct.tmpl_cd
     WHERE ct.co_cd = p_co_cd
       AND (
            ct.tmpl_cd LIKE 'hwp_sys_%'
         OR ct.tmpl_cd LIKE 'hwp_usr_%'
         OR (
                lower(CASE WHEN COALESCE(ct.sys_yn, 'sys') IN ('N', 'n', 'usr') THEN 'usr' ELSE 'sys' END) = 'usr'
            AND lower(COALESCE(t.doc_kind, 'hwp')) IN ('hwp')
            AND ct.tmpl_cd NOT LIKE 'tmpl_%'
            AND ct.tmpl_cd NOT LIKE 'html_sys_%'
         )
       )
       AND ct.tmpl_cd LIKE CONCAT('%', COALESCE(p_tmpl_cd, ''), '%')
       AND COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm) LIKE CONCAT('%', COALESCE(p_tmpl_nm, ''), '%')
     ORDER BY t.sort_no, ct.tmpl_cd;
$$;
COMMENT ON FUNCTION sp_hwp_template_management_r_000(varchar, varchar, varchar) IS
  '사용양식 목록 — hwp_sys_NNN 시스템제공 + 사용자추가 HWP. html_sys·옛 kebab 시스템 행은 숨김';

-- 확인
SELECT 'hwp_sys' AS gbn, count(*) FROM tbl_template WHERE tmpl_cd LIKE 'hwp_sys_%'
UNION ALL
SELECT 'html_sys', count(*) FROM tbl_template WHERE tmpl_cd LIKE 'html_sys_%'
UNION ALL
SELECT 'old_kebab_left', count(*) FROM tbl_template WHERE tmpl_cd LIKE 'tmpl_%';
