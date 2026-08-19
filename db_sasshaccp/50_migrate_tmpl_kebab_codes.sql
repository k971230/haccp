-- ============================================================
-- 50 — 양식코드 kebab(tmpl_*) 1차 14종 · 컬럼 길이 · 작성문서목록 sys_yn
--
-- 파일번호: 50
-- 이전번호: 49
-- 개발자: 박승우
-- 일자: 2026-08-12
-- 코멘트:
--   1) tmpl_cd varchar(40)으로 확장하고 1차 14종 구코드를 신코드로 치환한다
--   2) 업체 사용양식 목록 SP에 sys_yn을 반환해 작성문서관리 그리드에 쓴다
--   3) 작성주기 관리 메뉴 표시명을 작성 문서 관리로 맞춘다
--
-- 운영 정본은 94/95. 신규 설치는 09 정본을 쓰고 이 파일을 재실행하지 않는다.
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 컬럼 길이 — tmpl_logis-receive-inspect(25) 수용
-- ------------------------------------------------------------
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT c.table_schema, c.table_name, c.column_name, c.character_maximum_length
      FROM information_schema.columns c
     WHERE c.table_schema = 'sasshaccp'
       AND c.column_name IN ('tmpl_cd', 'src_tmpl_cd')
       AND c.data_type = 'character varying'
       AND (c.character_maximum_length IS NULL OR c.character_maximum_length < 40)
  LOOP
    EXECUTE format(
      'ALTER TABLE %I.%I ALTER COLUMN %I TYPE varchar(40)',
      r.table_schema, r.table_name, r.column_name
    );
  END LOOP;
END$$;

-- ------------------------------------------------------------
-- 2. 구코드 → 신코드 (재실행 안전: 구코드 행만 UPDATE)
-- ------------------------------------------------------------
CREATE TEMP TABLE tmp_tmpl_map (
  old_cd varchar(40) PRIMARY KEY,
  new_cd varchar(40) NOT NULL
);
INSERT INTO tmp_tmpl_map(old_cd, new_cd) VALUES
  ('CCP_COLD',       'tmpl_ccp-cold-log'),
  ('CCP_METAL',      'tmpl_ccp-metal-log'),
  ('CCP_HEAT',       'tmpl_ccp-heat-log'),
  ('CCP_SANITIZE',   'tmpl_ccp-sanitize-log'),
  ('CCP_FILTER',     'tmpl_ccp-filter-log'),
  ('DAILY_HYG',      'tmpl_prp-hygiene-daily'),
  ('CALIB_LOG_TEMP', 'tmpl_prp-calib-temp'),
  ('CALIB_LOG_WGT',  'tmpl_prp-calib-weight'),
  ('CALIB_LOG_SCL',  'tmpl_prp-calib-scale'),
  ('RECV_INSP',      'tmpl_logis-receive-inspect'),
  ('SHIPMENT',       'tmpl_logis-shipment-log'),
  ('VEHICLE_LOG',    'tmpl_logis-vehicle-log'),
  ('EDU_LOG',        'tmpl_admin-edu-log'),
  ('CLAIM',          'tmpl_admin-claim-log');

DO $$
DECLARE
  pair record;
BEGIN
  FOR pair IN SELECT old_cd, new_cd FROM tmp_tmpl_map LOOP
    UPDATE tbl_company_template SET tmpl_cd = pair.new_cd WHERE tmpl_cd = pair.old_cd
      AND NOT EXISTS (
        SELECT 1 FROM tbl_company_template x
         WHERE x.co_cd = tbl_company_template.co_cd AND x.tmpl_cd = pair.new_cd
      );
    UPDATE tbl_check_item SET tmpl_cd = pair.new_cd WHERE tmpl_cd = pair.old_cd
      AND NOT EXISTS (
        SELECT 1 FROM tbl_check_item x
         WHERE x.tmpl_cd = pair.new_cd AND x.item_cd = tbl_check_item.item_cd
      );
    IF to_regclass('sasshaccp.tbl_company_check_item') IS NOT NULL THEN
      UPDATE tbl_company_check_item SET tmpl_cd = pair.new_cd WHERE tmpl_cd = pair.old_cd
        AND NOT EXISTS (
          SELECT 1 FROM tbl_company_check_item x
           WHERE x.co_cd = tbl_company_check_item.co_cd
             AND x.tmpl_cd = pair.new_cd
             AND x.item_cd = tbl_company_check_item.item_cd
        );
    END IF;
    UPDATE tbl_document SET tmpl_cd = pair.new_cd WHERE tmpl_cd = pair.old_cd;
    UPDATE tbl_schedule_rule SET tmpl_cd = pair.new_cd WHERE tmpl_cd = pair.old_cd;
    UPDATE tbl_doc_no_rule SET tmpl_cd = pair.new_cd WHERE tmpl_cd = pair.old_cd;
    UPDATE tbl_screen SET tmpl_cd = pair.new_cd WHERE tmpl_cd = pair.old_cd;

    IF to_regclass('sasshaccp.tbl_company_form') IS NOT NULL THEN
      EXECUTE 'UPDATE tbl_company_form SET src_tmpl_cd = $1 WHERE src_tmpl_cd = $2'
        USING pair.new_cd, pair.old_cd;
    END IF;
    IF to_regclass('sasshaccp.tbl_diary_tmpl_map') IS NOT NULL THEN
      EXECUTE 'UPDATE tbl_diary_tmpl_map SET tmpl_cd = $1 WHERE tmpl_cd = $2'
        USING pair.new_cd, pair.old_cd;
    END IF;

    UPDATE tbl_template SET tmpl_cd = pair.new_cd WHERE tmpl_cd = pair.old_cd
      AND NOT EXISTS (SELECT 1 FROM tbl_template WHERE tmpl_cd = pair.new_cd);
  END LOOP;
END$$;

DROP TABLE IF EXISTS tmp_tmpl_map;

-- ------------------------------------------------------------
-- 3. 작성문서관리 — 사용양식 목록에 sys_yn 포함
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_company_template_r_000(varchar, varchar, varchar);
CREATE OR REPLACE FUNCTION sp_tbl_company_template_r_000(
    p_co_cd varchar,
    p_category_cd varchar,
    p_use_yn varchar
) RETURNS TABLE(
    idx bigint, tmpl_cd varchar, tmpl_nm varchar, mng_no varchar, doc_kind varchar, category_cd varchar,
    scrn_cd varchar, cycle_cd varchar, retention_month int, appr_line_cd varchar, appr_line_nm varchar,
    use_yn varchar, sort_no int, base_use_yn varchar, co_form_idx bigint, sys_yn varchar
)
LANGUAGE sql STABLE AS $$
    SELECT ct.idx, t.tmpl_cd, coalesce(ct.tmpl_nm_ovr, t.tmpl_nm),
           t.mng_no, t.doc_kind, t.category_cd, t.scrn_cd,
           coalesce(ct.cycle_cd, t.default_cycle_cd), coalesce(ct.retention_month, t.default_retention_month),
           ct.appr_line_cd, al.appr_line_nm, coalesce(ct.use_yn, 'N'), t.sort_no,
           coalesce(ct.base_use_yn, 'Y'), ct.co_form_idx,
           coalesce(ct.sys_yn, 'Y')
      FROM tbl_template t
      LEFT JOIN tbl_company_template ct ON ct.co_cd = p_co_cd AND ct.tmpl_cd = t.tmpl_cd
      LEFT JOIN tbl_approval_line al ON al.co_cd = p_co_cd AND al.appr_line_cd = ct.appr_line_cd
     WHERE t.use_yn = 'Y' AND t.impl_yn = 'Y'
       AND t.category_cd LIKE concat('%', coalesce(p_category_cd, ''), '%')
       AND coalesce(ct.use_yn, 'N') LIKE concat('%', coalesce(p_use_yn, ''), '%')
     ORDER BY t.sort_no;
$$;
COMMENT ON FUNCTION sp_tbl_company_template_r_000(varchar, varchar, varchar) IS
  '업체 사용양식 조회 — sys_yn·기본/자사 출처 포함(작성 문서 관리)';

-- ------------------------------------------------------------
-- 4. 메뉴 표시명 — 작성 문서 관리
-- ------------------------------------------------------------
UPDATE tbl_screen
   SET scrn_nm = '작성 문서 관리', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd = 'schedule-cycle-management';

UPDATE tbl_menu
   SET menu_nm = '작성 문서 관리', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd = 'schedule-cycle-management';
