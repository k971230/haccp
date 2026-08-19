-- ============================================================
-- 95 — 남은 kebab 11건을 hwp_sys_028~038 로 옮긴다 · 사용양식은 001~027만
--
-- 파일번호: 95
-- 이전번호: 94
-- 개발자: 박승우
-- 일자: 2026-08-19
-- 코멘트:
--   1) 공정·부자재입고·외부검교정·출고·실시상황평가·법적서류 6건 코드를 바꾼다
--   2) 사용양식 목록은 hwp_sys_001~027 + hwp_usr_% 만 보여 028+ 를 숨긴다
--   3) 거래처구분·폐기구분 값 tmpl_prp-waste-check 는 양식코드가 아니라서 건드리지 않는다
--
-- Jenkins는 migrate를 안 돌리므로 적용은 DBeaver/수동
-- 운영 정본은 94/95. 신규 설치는 09 정본을 쓰고 50~94 를 재실행하지 않는다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 매핑표
-- ------------------------------------------------------------
DROP TABLE IF EXISTS tmp_tmpl_remap;
CREATE TEMP TABLE tmp_tmpl_remap (
    old_cd varchar(40) PRIMARY KEY,
    new_cd varchar(40) NOT NULL
);

INSERT INTO tmp_tmpl_remap (old_cd, new_cd) VALUES
    ('tmpl_ccp-process-check',      'hwp_sys_028'),
    ('tmpl_logis-submat-receive',    'hwp_sys_029'),
    ('tmpl_prp-calib-ext',           'hwp_sys_030'),
    ('tmpl_logis-shipment-log',      'hwp_sys_031'),
    ('tmpl_admin-eval-check',        'hwp_sys_032'),
    ('tmpl_logis-material-ledger',   'hwp_sys_033'),
    ('tmpl_admin-building-ledger',   'hwp_sys_034'),
    ('tmpl_admin-production-ledger', 'hwp_sys_035'),
    ('tmpl_admin-license-manage',    'hwp_sys_036'),
    ('tmpl_admin-self-test',         'hwp_sys_037'),
    ('tmpl_admin-cert-manage',       'hwp_sys_038');

-- ------------------------------------------------------------
-- 2. 카탈로그 복사 — 옛 kebab 행을 hwp_sys_028~038 로 복제한다
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
       'hwp',
       t.category_cd,
       t.scrn_cd,
       t.default_cycle_cd,
       t.default_retention_month,
       t.impl_yn,
       t.sort_no,
       'Y',
       t.form_path,
       'system',
       now()
  FROM tmp_tmpl_remap m
  JOIN tbl_template t ON t.tmpl_cd = m.old_cd
ON CONFLICT (tmpl_cd) DO UPDATE SET
    tmpl_nm     = EXCLUDED.tmpl_nm,
    mng_no      = EXCLUDED.mng_no,
    doc_kind    = 'hwp',
    category_cd = EXCLUDED.category_cd,
    scrn_cd     = EXCLUDED.scrn_cd,
    impl_yn     = EXCLUDED.impl_yn,
    use_yn      = 'Y',
    form_path   = COALESCE(EXCLUDED.form_path, tbl_template.form_path),
    upd_id      = 'system',
    upd_dt      = now();

-- kebab 이 없는 환경 — 최소 시드
INSERT INTO tbl_template (
    co_cd, tmpl_cd, tmpl_nm, mng_no, doc_kind, category_cd, scrn_cd,
    default_cycle_cd, default_retention_month, impl_yn, sort_no, use_yn, form_path, ins_id, ins_dt
)
SELECT '0000', v.tmpl_cd, v.tmpl_nm, v.mng_no, 'hwp', v.category_cd, v.scrn_cd,
       v.cycle_cd, 36, 'Y', v.sort_no, 'Y', v.form_path, 'system', now()
  FROM (VALUES
    ('hwp_sys_028', '공정관리 점검표',       '26', 'PRC', 'process-hwp',            'M', 128, 'HaccpTemplates/hwp_sys_028/공정관리_점검표.hwp'),
    ('hwp_sys_029', '부자재입고검수점검표',   NULL, 'INV', 'submaterial-recv-hwp',   'E', 129, 'HaccpTemplates/hwp_sys_029/부자재입고검수점검표.hwp'),
    ('hwp_sys_030', '외부검교정기록부',       NULL, 'FAC', 'calib-ext-hwp',          'Y', 130, 'HaccpTemplates/hwp_sys_030/외부 검교정기록부.hwp'),
    ('hwp_sys_031', '제품출고관리일지',       NULL, 'INV', 'shipment-log-hwp',       'E', 131, 'HaccpTemplates/hwp_sys_031/제품출고관리일지.hwp'),
    ('hwp_sys_032', '실시상황평가표',         NULL, 'VER', 'eval-hwp',               'Y', 132, 'HaccpTemplates/hwp_sys_032/실시상황평가표.hwp'),
    ('hwp_sys_033', '원료수불대장관리',       NULL, 'LAW', 'law-material-ledger',    'M', 133, 'HaccpTemplates/hwp_sys_033/LAW_MATERIAL.hwp'),
    ('hwp_sys_034', '건축물대장관리',         NULL, 'LAW', 'law-building-ledger',    'E', 134, 'HaccpTemplates/hwp_sys_034/LAW_BUILDING.hwp'),
    ('hwp_sys_035', '생산대장관리',           NULL, 'LAW', 'law-production-ledger',  'D', 135, 'HaccpTemplates/hwp_sys_035/LAW_PRODUCTION.hwp'),
    ('hwp_sys_036', '영업등록증관리',         NULL, 'LAW', 'law-business-license',   'E', 136, 'HaccpTemplates/hwp_sys_036/LAW_LICENSE.hwp'),
    ('hwp_sys_037', '자가품질검사관리',       NULL, 'LAW', 'law-self-quality-test',  'M', 137, 'HaccpTemplates/hwp_sys_037/LAW_SELF_TEST.hwp'),
    ('hwp_sys_038', '수료증관리',             NULL, 'LAW', 'law-completion-cert',    'E', 138, 'HaccpTemplates/hwp_sys_038/LAW_CERT.hwp')
  ) AS v(tmpl_cd, tmpl_nm, mng_no, category_cd, scrn_cd, cycle_cd, sort_no, form_path)
ON CONFLICT (tmpl_cd) DO NOTHING;

UPDATE tbl_template t
   SET scrn_cd  = v.scrn_cd,
       doc_kind = 'hwp',
       upd_id   = 'system',
       upd_dt   = now()
  FROM (VALUES
    ('hwp_sys_028', 'process-hwp'),
    ('hwp_sys_029', 'submaterial-recv-hwp'),
    ('hwp_sys_030', 'calib-ext-hwp'),
    ('hwp_sys_031', 'shipment-log-hwp'),
    ('hwp_sys_032', 'eval-hwp'),
    ('hwp_sys_033', 'law-material-ledger'),
    ('hwp_sys_034', 'law-building-ledger'),
    ('hwp_sys_035', 'law-production-ledger'),
    ('hwp_sys_036', 'law-business-license'),
    ('hwp_sys_037', 'law-self-quality-test'),
    ('hwp_sys_038', 'law-completion-cert')
  ) AS v(tmpl_cd, scrn_cd)
 WHERE t.tmpl_cd = v.tmpl_cd;

INSERT INTO tbl_company_template (
    co_cd, tmpl_cd, tmpl_nm_ovr, use_yn, sys_yn, cycle_cd, retention_month, form_path, ins_id, ins_dt
)
SELECT c.co_cd, t.tmpl_cd, t.tmpl_nm, 'Y', 'sys', t.default_cycle_cd, t.default_retention_month, t.form_path, 'system', now()
  FROM tbl_company c
  JOIN tbl_template t ON t.tmpl_cd IN (SELECT new_cd FROM tmp_tmpl_remap)
ON CONFLICT (co_cd, tmpl_cd) DO UPDATE SET
    tmpl_nm_ovr = EXCLUDED.tmpl_nm_ovr,
    sys_yn      = 'sys',
    use_yn      = 'Y',
    form_path   = COALESCE(EXCLUDED.form_path, tbl_company_template.form_path),
    upd_id      = 'system',
    upd_dt      = now();

-- ------------------------------------------------------------
-- 3. tmpl_cd 를 매핑대로 옮긴다
-- ------------------------------------------------------------
UPDATE tbl_document d SET tmpl_cd = m.new_cd FROM tmp_tmpl_remap m WHERE d.tmpl_cd = m.old_cd;
UPDATE tbl_screen s SET tmpl_cd = m.new_cd FROM tmp_tmpl_remap m WHERE s.tmpl_cd = m.old_cd;

DELETE FROM tbl_company_template_file f
 USING tmp_tmpl_remap m
 WHERE f.tmpl_cd = m.old_cd
   AND EXISTS (
        SELECT 1 FROM tbl_company_template_file x
         WHERE x.co_cd = f.co_cd AND x.tmpl_cd = m.new_cd AND x.file_seq = f.file_seq
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

INSERT INTO tbl_doc_no_rule(co_cd, tmpl_cd, prefix, date_fmt, seq_len, reset_cycle, ins_id, ins_dt)
SELECT ct.co_cd, ct.tmpl_cd, ct.tmpl_cd, 'YYYYMMDD', 3, 'D', 'system', now()
  FROM tbl_company_template ct
 WHERE ct.tmpl_cd IN (SELECT new_cd FROM tmp_tmpl_remap)
ON CONFLICT (co_cd, tmpl_cd) DO NOTHING;

-- ------------------------------------------------------------
-- 4. 대체된 kebab 카탈로그·회사양식 삭제
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

-- ------------------------------------------------------------
-- 5. 살아있는 SP 본문의 kebab 리터럴을 새 코드로 바꾼다
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
-- 6. 사용양식 목록 SP — hwp_sys_001~027 + 사용자추가 HWP 만
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
            ct.tmpl_cd ~ '^hwp_sys_0(0[1-9]|1[0-9]|2[0-7])$'
         OR ct.tmpl_cd LIKE 'hwp_usr_%'
       )
       AND ct.tmpl_cd LIKE CONCAT('%', COALESCE(p_tmpl_cd, ''), '%')
       AND COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm) LIKE CONCAT('%', COALESCE(p_tmpl_nm, ''), '%')
     ORDER BY t.sort_no, ct.tmpl_cd;
$$;
COMMENT ON FUNCTION sp_hwp_template_management_r_000(varchar, varchar, varchar) IS
  '사용양식 목록 — hwp_sys_001~027 시스템제공 + hwp_usr_* 사용자추가. html_sys·028+·옛 kebab 은 숨김';

-- 확인
SELECT 'hwp_sys_001_027' AS gbn, count(*) FROM tbl_template WHERE tmpl_cd ~ '^hwp_sys_0(0[1-9]|1[0-9]|2[0-7])$'
UNION ALL
SELECT 'hwp_sys_028_038', count(*) FROM tbl_template WHERE tmpl_cd ~ '^hwp_sys_0(2[8-9]|3[0-8])$'
UNION ALL
SELECT 'html_sys', count(*) FROM tbl_template WHERE tmpl_cd LIKE 'html_sys_%'
UNION ALL
SELECT 'old_kebab_left', count(*) FROM tbl_template WHERE tmpl_cd LIKE 'tmpl_%';
