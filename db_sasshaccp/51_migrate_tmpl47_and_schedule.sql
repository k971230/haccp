-- ============================================================
-- 51 — 양식 47종 kebab 잔여 치환 · doc_kind html/hwp · sys-yn · 작성주기 base_dt
--
-- 파일번호: 51
-- 이전번호: 50
-- 개발자: 박승우
-- 일자: 2026-08-12
-- 코멘트:
--   1) 50 이후 남은 UPPER tmpl_cd를 47종 정본으로 맞춘다
--   2) doc_kind DB/HWP → html/hwp, company_template.sys_yn Y/N → sys/usr
--   3) 작성주기 base_dt·목록에 ins_id/ins_dt·양식별 최신 규칙 함수
--
-- 운영 정본은 94/95. 신규 설치는 09 정본을 쓰고 이 파일을 재실행하지 않는다.
-- ============================================================

SET search_path TO sasshaccp;

CREATE TEMP TABLE tmp_tmpl_map51 (
  old_cd varchar(40) PRIMARY KEY,
  new_cd varchar(40) NOT NULL
);
INSERT INTO tmp_tmpl_map51(old_cd, new_cd) VALUES
  ('CALIB_LOG_TEMP', 'tmpl_prp-calib-temp'),
  ('LAW_PRODUCTION', 'tmpl_admin-production-ledger'),
  ('VERIFY_REPORT', 'tmpl_prp-verify-report'),
  ('CALIB_LOG_WGT', 'tmpl_prp-calib-weight'),
  ('CALIB_LOG_SCL', 'tmpl_prp-calib-scale'),
  ('LAW_SELF_TEST', 'tmpl_admin-self-test'),
  ('VERIFY_CHECK', 'tmpl_prp-verify-check'),
  ('PERSONAL_HYG', 'tmpl_prp-hygiene-personal'),
  ('CALIB_TARGET', 'tmpl_prp-calib-target'),
  ('SURFACE_TEST', 'tmpl_prp-test-surface'),
  ('CCP_SANITIZE', 'tmpl_ccp-sanitize-log'),
  ('LAW_MATERIAL', 'tmpl_logis-material-ledger'),
  ('LAW_BUILDING', 'tmpl_admin-building-ledger'),
  ('VERIFY_PLAN', 'tmpl_prp-verify-plan'),
  ('BAD_PRODUCT', 'tmpl_admin-bad-product'),
  ('VEHICLE_LOG', 'tmpl_logis-vehicle-log'),
  ('LAW_LICENSE', 'tmpl_admin-license-manage'),
  ('VISITOR_LOG', 'tmpl_admin-visitor-log'),
  ('VISUAL_INSP', 'tmpl_prp-visual-inspect'),
  ('SUBMAT_RECV', 'tmpl_logis-submat-receive'),
  ('CCP_VERIFY', 'tmpl_ccp-verify-check'),
  ('EQUIP_CARD', 'tmpl_prp-equip-card'),
  ('CCP_FILTER', 'tmpl_ccp-filter-log'),
  ('LAW_HEALTH', 'tmpl_admin-law-health'),
  ('CCP_METAL', 'tmpl_ccp-metal-log'),
  ('VERIFY_CA', 'tmpl_prp-verify-action'),
  ('DAILY_HYG', 'tmpl_prp-hygiene-daily'),
  ('INV_CHECK', 'tmpl_logis-inventory-check'),
  ('RECV_INSP', 'tmpl_logis-receive-inspect'),
  ('PROD_TEST', 'tmpl_prp-test-product'),
  ('CALIB_EXT', 'tmpl_prp-calib-ext'),
  ('HANDOVER', 'tmpl_admin-handover-doc'),
  ('CCP_COLD', 'tmpl_ccp-cold-log'),
  ('EDU_PLAN', 'tmpl_admin-edu-plan'),
  ('AREA_HYG', 'tmpl_prp-hygiene-area'),
  ('FACILITY', 'tmpl_prp-facility-check'),
  ('CCP_HEAT', 'tmpl_ccp-heat-log'),
  ('LAW_CERT', 'tmpl_admin-cert-manage'),
  ('SHIPMENT', 'tmpl_logis-shipment-log'),
  ('EDU_LOG', 'tmpl_admin-edu-log'),
  ('PROCESS', 'tmpl_ccp-process-check'),
  ('RECALL', 'tmpl_admin-recall-report'),
  ('WASTE', 'tmpl_prp-waste-check'),
  ('WATER', 'tmpl_prp-water-check'),
  ('CLAIM', 'tmpl_admin-claim-log'),
  ('PEST', 'tmpl_prp-pest-check'),
  ('EVAL', 'tmpl_admin-eval-check');

DO $$
DECLARE pair record;
BEGIN
  FOR pair IN SELECT old_cd, new_cd FROM tmp_tmpl_map51 LOOP
    UPDATE tbl_company_template SET tmpl_cd = pair.new_cd WHERE tmpl_cd = pair.old_cd
      AND NOT EXISTS (SELECT 1 FROM tbl_company_template x WHERE x.co_cd = tbl_company_template.co_cd AND x.tmpl_cd = pair.new_cd);
    UPDATE tbl_check_item SET tmpl_cd = pair.new_cd WHERE tmpl_cd = pair.old_cd
      AND NOT EXISTS (SELECT 1 FROM tbl_check_item x WHERE x.tmpl_cd = pair.new_cd AND x.item_cd = tbl_check_item.item_cd);
    IF to_regclass('sasshaccp.tbl_company_check_item') IS NOT NULL THEN
      UPDATE tbl_company_check_item SET tmpl_cd = pair.new_cd WHERE tmpl_cd = pair.old_cd
        AND NOT EXISTS (SELECT 1 FROM tbl_company_check_item x WHERE x.co_cd = tbl_company_check_item.co_cd AND x.tmpl_cd = pair.new_cd AND x.item_cd = tbl_company_check_item.item_cd);
    END IF;
    UPDATE tbl_document SET tmpl_cd = pair.new_cd WHERE tmpl_cd = pair.old_cd;
    UPDATE tbl_schedule_rule SET tmpl_cd = pair.new_cd WHERE tmpl_cd = pair.old_cd;
    UPDATE tbl_doc_no_rule SET tmpl_cd = pair.new_cd WHERE tmpl_cd = pair.old_cd;
    UPDATE tbl_screen SET tmpl_cd = pair.new_cd WHERE tmpl_cd = pair.old_cd;
    IF to_regclass('sasshaccp.tbl_company_form') IS NOT NULL THEN
      EXECUTE 'UPDATE tbl_company_form SET src_tmpl_cd = $1 WHERE src_tmpl_cd = $2' USING pair.new_cd, pair.old_cd;
    END IF;
    IF to_regclass('sasshaccp.tbl_diary_tmpl_map') IS NOT NULL THEN
      EXECUTE 'UPDATE tbl_diary_tmpl_map SET tmpl_cd = $1 WHERE tmpl_cd = $2' USING pair.new_cd, pair.old_cd;
    END IF;
    UPDATE tbl_template SET tmpl_cd = pair.new_cd WHERE tmpl_cd = pair.old_cd
      AND NOT EXISTS (SELECT 1 FROM tbl_template WHERE tmpl_cd = pair.new_cd);
  END LOOP;
END$$;
DROP TABLE IF EXISTS tmp_tmpl_map51;

-- sys_yn 이 varchar(1)이면 sys/usr 불가 — 확장
ALTER TABLE tbl_company_template ALTER COLUMN sys_yn TYPE varchar(10);
COMMENT ON COLUMN tbl_company_template.sys_yn IS '시스템유무 — sys=플랫폼, usr=사용자(공통코드 sys-yn)';

-- doc_kind 가 varchar(3)이면 html(4) 불가 — 확장 후 치환
ALTER TABLE tbl_template ALTER COLUMN doc_kind TYPE varchar(10);
ALTER TABLE tbl_document ALTER COLUMN doc_kind TYPE varchar(10);

UPDATE tbl_template SET doc_kind = 'html' WHERE doc_kind = 'DB';
UPDATE tbl_template SET doc_kind = 'hwp' WHERE doc_kind = 'HWP';
UPDATE tbl_document SET doc_kind = 'html' WHERE doc_kind = 'DB';
UPDATE tbl_document SET doc_kind = 'hwp' WHERE doc_kind = 'HWP';
UPDATE tbl_company_template SET sys_yn = 'sys' WHERE sys_yn IN ('Y', 'y', 'sys');
UPDATE tbl_company_template SET sys_yn = 'usr' WHERE sys_yn IN ('N', 'n', 'usr');

INSERT INTO tbl_code (co_cd, main_cd, sub_cd, code_nm, sort_no, ref1, sys_yn, ins_id) VALUES
  ('0000', 'sys-yn', '*', '시스템유무', 0, NULL, 'Y', 'system'),
  ('0000', 'sys-yn', 'sys', '시스템', 1, NULL, 'Y', 'system'),
  ('0000', 'sys-yn', 'usr', '사용자', 2, NULL, 'Y', 'system'),
  ('0000', 'tmpl-ty', '*', '양식타입', 0, NULL, 'Y', 'system'),
  ('0000', 'tmpl-ty', 'html', 'HTML', 1, NULL, 'Y', 'system'),
  ('0000', 'tmpl-ty', 'hwp', 'HWP', 2, NULL, 'Y', 'system'),
  ('0000', 'use-yn', '*', '사용여부', 0, NULL, 'Y', 'system'),
  ('0000', 'use-yn', 'y', '사용', 1, NULL, 'Y', 'system'),
  ('0000', 'use-yn', 'n', '미사용', 2, NULL, 'Y', 'system')
ON CONFLICT (co_cd, main_cd, sub_cd) DO UPDATE SET
  code_nm = EXCLUDED.code_nm, sort_no = EXCLUDED.sort_no, use_yn = 'Y', upd_id = 'system', upd_dt = now();

ALTER TABLE tbl_schedule_rule ADD COLUMN IF NOT EXISTS base_dt varchar(8) NULL;
COMMENT ON COLUMN tbl_schedule_rule.base_dt IS '기준일 yyyyMMdd — 주/월/연 주기 기준. 화면은 yyyy-mm-dd 달력';

DROP FUNCTION IF EXISTS sp_tbl_schedule_rule_r_000(varchar);
CREATE OR REPLACE FUNCTION sp_tbl_schedule_rule_r_000(p_co_cd varchar)
RETURNS TABLE(
    idx bigint, tmpl_cd varchar, tmpl_nm varchar, rule_seq int, cycle_cd varchar,
    week_days varchar, month_day int, month_no int, due_time varchar,
    dept_cd varchar, user_id varchar, use_yn varchar,
    base_dt varchar, ins_id varchar, ins_dt timestamp, upd_id varchar, upd_dt timestamp
)
LANGUAGE sql STABLE AS $$
    SELECT r.idx, r.tmpl_cd, COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm), r.rule_seq, r.cycle_cd,
           r.week_days, r.month_day, r.month_no, r.due_time, r.dept_cd, r.user_id, r.use_yn,
           r.base_dt, r.ins_id, r.ins_dt, r.upd_id, r.upd_dt
      FROM tbl_schedule_rule r
      JOIN tbl_template t ON t.tmpl_cd = r.tmpl_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = r.co_cd AND ct.tmpl_cd = r.tmpl_cd
     WHERE r.co_cd = p_co_cd
     ORDER BY r.tmpl_cd, COALESCE(r.upd_dt, r.ins_dt) DESC NULLS LAST, r.rule_seq;
$$;
COMMENT ON FUNCTION sp_tbl_schedule_rule_r_000(varchar) IS
  '작성주기 목록 — 동일 양식은 최신(upd/ins) 우선. base_dt·감사컬럼 포함';

CREATE OR REPLACE PROCEDURE sp_tbl_schedule_rule_c_000(
    p_co_cd varchar, p_payload jsonb, p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_idx bigint := NULLIF(p_payload ->> 'idx', '')::bigint;
    v_tmpl_cd varchar(40) := trim(COALESCE(p_payload ->> 'tmplCd', ''));
    v_cycle_cd varchar(1) := upper(trim(COALESCE(p_payload ->> 'cycleCd', '')));
    v_base varchar(8) := regexp_replace(COALESCE(p_payload ->> 'baseDt', ''), '[^0-9]', '', 'g');
    v_due varchar(4) := regexp_replace(COALESCE(p_payload ->> 'dueTime', ''), '[^0-9]', '', 'g');
    v_seq int;
    v_month_day int;
    v_use varchar(1);
BEGIN
    IF v_tmpl_cd = '' OR v_cycle_cd NOT IN ('D', 'W', 'M', 'Y') THEN
        RAISE EXCEPTION '양식과 작성주기(일/주/월/연)를 확인하세요.' USING ERRCODE = '45000';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM tbl_company_template WHERE co_cd = p_co_cd AND tmpl_cd = v_tmpl_cd AND upper(use_yn) = 'Y'
    ) THEN
        RAISE EXCEPTION '사용 중인 업체 양식만 작성주기를 설정할 수 있습니다.' USING ERRCODE = '45000';
    END IF;
    IF length(v_base) = 8 THEN
        v_month_day := substring(v_base, 7, 2)::int;
    ELSE
        v_base := NULL;
        v_month_day := NULLIF(p_payload ->> 'monthDay', '')::int;
    END IF;
    IF length(v_due) = 3 THEN v_due := lpad(v_due, 4, '0'); END IF;
    IF v_due = '' THEN v_due := '1800'; END IF;
    -- 화면 use-yn(y/n) 또는 레거시 Y/N → 저장은 Y/N
    v_use := CASE lower(COALESCE(NULLIF(p_payload ->> 'useYn', ''), 'y'))
               WHEN 'n' THEN 'N' WHEN 'y' THEN 'Y' WHEN 'N' THEN 'N' WHEN 'Y' THEN 'Y'
               ELSE 'Y' END;
    IF v_idx IS NULL THEN
        SELECT COALESCE(MAX(rule_seq), 0) + 1 INTO v_seq
          FROM tbl_schedule_rule WHERE co_cd = p_co_cd AND tmpl_cd = v_tmpl_cd;
        INSERT INTO tbl_schedule_rule(
            co_cd, tmpl_cd, rule_seq, cycle_cd, week_days, month_day, month_no, due_time,
            dept_cd, user_id, use_yn, base_dt, ins_id, ins_dt
        ) VALUES (
            p_co_cd, v_tmpl_cd, v_seq, v_cycle_cd, NULL,
            v_month_day, NULL,
            v_due, NULLIF(p_payload ->> 'deptCd', ''),
            NULLIF(COALESCE(p_payload ->> 'userNm', p_payload ->> 'userId'), ''),
            v_use, v_base, p_id, now()
        );
    ELSE
        UPDATE tbl_schedule_rule SET
            cycle_cd = v_cycle_cd, week_days = NULL,
            month_day = v_month_day, month_no = NULL,
            due_time = v_due,
            dept_cd = NULLIF(p_payload ->> 'deptCd', ''),
            user_id = NULLIF(COALESCE(p_payload ->> 'userNm', p_payload ->> 'userId'), ''),
            use_yn = v_use,
            base_dt = v_base,
            upd_id = p_id, upd_dt = now()
         WHERE idx = v_idx AND co_cd = p_co_cd;
        IF NOT FOUND THEN RAISE EXCEPTION '작성주기 규칙을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    END IF;
END$$;

CREATE OR REPLACE FUNCTION sp_tbl_schedule_rule_latest_r_000(p_co_cd varchar)
RETURNS SETOF tbl_schedule_rule
LANGUAGE sql STABLE AS $$
    SELECT DISTINCT ON (r.tmpl_cd) r.*
      FROM tbl_schedule_rule r
     WHERE r.co_cd = p_co_cd AND upper(r.use_yn) = 'Y'
     ORDER BY r.tmpl_cd, COALESCE(r.upd_dt, r.ins_dt) DESC NULLS LAST, r.idx DESC;
$$;
COMMENT ON FUNCTION sp_tbl_schedule_rule_latest_r_000(varchar) IS
  '양식별 가장 최근 작성주기 1건 — 오늘 할 일 배치 입력';

-- 오늘 할 일 생성 — 양식·회사별 최신 규칙만, 기준일(base_dt) 기준 주/월/연
CREATE OR REPLACE PROCEDURE sp_tbl_schedule_task_gen_c_000(
    p_co_cd varchar,
    p_base_dt varchar,
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_date date := to_date(p_base_dt, 'YYYYMMDD');
BEGIN
    IF COALESCE(p_base_dt, '') !~ '^[0-9]{8}$' THEN
        RAISE EXCEPTION '과제 생성 기준일 형식이 올바르지 않습니다.' USING ERRCODE = '45000';
    END IF;

    INSERT INTO tbl_schedule_task(co_cd, tmpl_cd, base_dt, due_dt, due_time, status, dept_cd, user_id, ins_id, ins_dt)
    SELECT r.co_cd, r.tmpl_cd, p_base_dt, p_base_dt, r.due_time, 'TODO', r.dept_cd, r.user_id, p_id, now()
      FROM (
            SELECT DISTINCT ON (r0.co_cd, r0.tmpl_cd) r0.*
              FROM tbl_schedule_rule r0
             WHERE upper(r0.use_yn) = 'Y'
               AND (COALESCE(p_co_cd, '') = '' OR r0.co_cd = p_co_cd)
             ORDER BY r0.co_cd, r0.tmpl_cd, COALESCE(r0.upd_dt, r0.ins_dt) DESC NULLS LAST, r0.idx DESC
           ) r
      JOIN tbl_company c ON c.co_cd = r.co_cd AND c.use_yn = 'Y'
     WHERE (
           r.cycle_cd = 'D'
           OR (r.cycle_cd = 'W' AND r.base_dt ~ '^[0-9]{8}$'
               AND extract(isodow FROM v_date) = extract(isodow FROM to_date(r.base_dt, 'YYYYMMDD')))
           OR (r.cycle_cd = 'W' AND COALESCE(r.base_dt, '') = ''
               AND position(extract(isodow FROM v_date)::text IN COALESCE(r.week_days, '')) > 0)
           OR (r.cycle_cd = 'M' AND r.base_dt ~ '^[0-9]{8}$'
               AND extract(day FROM v_date) = substring(r.base_dt, 7, 2)::int)
           OR (r.cycle_cd = 'M' AND COALESCE(r.base_dt, '') = ''
               AND extract(day FROM v_date) = r.month_day)
           OR (r.cycle_cd = 'Y' AND r.base_dt ~ '^[0-9]{8}$'
               AND extract(month FROM v_date) = substring(r.base_dt, 5, 2)::int
               AND extract(day FROM v_date) = substring(r.base_dt, 7, 2)::int)
           OR (r.cycle_cd = 'Y' AND COALESCE(r.base_dt, '') = ''
               AND extract(month FROM v_date) = r.month_no AND extract(day FROM v_date) = r.month_day)
       )
    ON CONFLICT (co_cd, tmpl_cd, base_dt) DO NOTHING;

    UPDATE tbl_schedule_task
       SET status = 'LATE', upd_id = p_id, upd_dt = now()
     WHERE (COALESCE(p_co_cd, '') = '' OR co_cd = p_co_cd)
       AND status IN ('TODO', 'ING')
       AND (due_dt < p_base_dt OR (due_dt = p_base_dt AND COALESCE(due_time, '2359') < to_char(now(), 'HH24MI')));
END$$;
