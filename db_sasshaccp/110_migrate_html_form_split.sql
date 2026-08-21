-- ============================================================
-- 110 — HTML 양식 원본 테이블 분할 + html_hyg_prc 채번
--
-- 파일번호: 110
-- 이전번호: 109
-- 개발자: 박승우
-- 일자: 2026-08-20
-- 코멘트:
--   1) 공정점검 저장은 tbl_html_hyg_prc_ver, CCP는 tbl_tml_ccp_chk_ver. 작성 html_sys_001은 tbl_html_form_ver 유지
--   2) 양식코드 html_hyg_NNN → html_hyg_prc_NNN (tml_ccp_chk_NNN 과 같은 3단 순번)
--   3) 109 가족분기 SP는 테이블별 SP로 나눈다
--
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. DDL
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_html_hyg_prc_ver (
    idx      bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd    varchar(10)  NOT NULL,
    tmpl_cd  varchar(40)  NOT NULL,
    ver_no   int          NOT NULL,
    ver_cd   varchar(20)  NOT NULL,
    ver_nm   varchar(100) NOT NULL,
    apply_yn varchar(1)   NOT NULL DEFAULT 'N',
    use_yn   varchar(1)   NOT NULL DEFAULT 'Y',
    ins_id   varchar(20)  NULL,
    ins_dt   timestamp    NULL DEFAULT now(),
    upd_id   varchar(20)  NULL,
    upd_dt   timestamp    NULL,
    CONSTRAINT ux_tbl_html_hyg_prc_ver UNIQUE (co_cd, tmpl_cd, ver_no),
    CONSTRAINT ck_tbl_html_hyg_prc_ver_no CHECK (ver_no >= 1),
    CONSTRAINT ck_tbl_html_hyg_prc_ver_apply CHECK (apply_yn IN ('Y', 'N')),
    CONSTRAINT ck_tbl_html_hyg_prc_ver_use CHECK (use_yn IN ('Y', 'N'))
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_tbl_html_hyg_prc_ver_apply
    ON tbl_html_hyg_prc_ver (co_cd, tmpl_cd) WHERE apply_yn = 'Y';
CREATE UNIQUE INDEX IF NOT EXISTS ux_tbl_html_hyg_prc_ver_cd
    ON tbl_html_hyg_prc_ver (co_cd, tmpl_cd, ver_cd) WHERE use_yn = 'Y';
COMMENT ON TABLE tbl_html_hyg_prc_ver IS '일반위생·공정점검 자사 양식 버전 — 예시는 html_hyg_prc_000 가상';

CREATE TABLE IF NOT EXISTS tbl_html_hyg_prc_ver_item (
    idx        bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd      varchar(10)  NOT NULL,
    tmpl_cd    varchar(40)  NOT NULL,
    ver_no     int          NOT NULL,
    item_cd    varchar(20)  NOT NULL,
    sort_no    int          NOT NULL DEFAULT 0,
    cycle_nm   varchar(50)  NULL,
    grp_nm     varchar(100) NULL,
    item_nm    text         NOT NULL,
    input_type varchar(20)  NOT NULL DEFAULT 'radio',
    unit_nm    varchar(20)  NULL,
    ins_id     varchar(20)  NULL,
    ins_dt     timestamp    NULL DEFAULT now(),
    upd_id     varchar(20)  NULL,
    upd_dt     timestamp    NULL,
    CONSTRAINT ux_tbl_html_hyg_prc_ver_item UNIQUE (co_cd, tmpl_cd, ver_no, item_cd)
);
COMMENT ON TABLE tbl_html_hyg_prc_ver_item IS '일반위생·공정점검 자사 양식 항목';

CREATE TABLE IF NOT EXISTS tbl_tml_ccp_chk_ver (
    idx      bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd    varchar(10)  NOT NULL,
    tmpl_cd  varchar(40)  NOT NULL,
    ver_no   int          NOT NULL,
    ver_cd   varchar(20)  NOT NULL,
    ver_nm   varchar(100) NOT NULL,
    apply_yn varchar(1)   NOT NULL DEFAULT 'N',
    use_yn   varchar(1)   NOT NULL DEFAULT 'Y',
    ins_id   varchar(20)  NULL,
    ins_dt   timestamp    NULL DEFAULT now(),
    upd_id   varchar(20)  NULL,
    upd_dt   timestamp    NULL,
    CONSTRAINT ux_tbl_tml_ccp_chk_ver UNIQUE (co_cd, tmpl_cd, ver_no),
    CONSTRAINT ck_tbl_tml_ccp_chk_ver_no CHECK (ver_no >= 1),
    CONSTRAINT ck_tbl_tml_ccp_chk_ver_apply CHECK (apply_yn IN ('Y', 'N')),
    CONSTRAINT ck_tbl_tml_ccp_chk_ver_use CHECK (use_yn IN ('Y', 'N'))
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_tbl_tml_ccp_chk_ver_apply
    ON tbl_tml_ccp_chk_ver (co_cd, tmpl_cd) WHERE apply_yn = 'Y';
CREATE UNIQUE INDEX IF NOT EXISTS ux_tbl_tml_ccp_chk_ver_cd
    ON tbl_tml_ccp_chk_ver (co_cd, tmpl_cd, ver_cd) WHERE use_yn = 'Y';
COMMENT ON TABLE tbl_tml_ccp_chk_ver IS 'CCP 검증점검 자사 양식 버전 — 예시는 tml_ccp_chk_000 가상';

CREATE TABLE IF NOT EXISTS tbl_tml_ccp_chk_ver_item (
    idx        bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd      varchar(10)  NOT NULL,
    tmpl_cd    varchar(40)  NOT NULL,
    ver_no     int          NOT NULL,
    item_cd    varchar(20)  NOT NULL,
    sort_no    int          NOT NULL DEFAULT 0,
    cycle_nm   varchar(50)  NULL,
    grp_nm     varchar(100) NULL,
    item_nm    text         NOT NULL,
    input_type varchar(20)  NOT NULL DEFAULT 'radio',
    unit_nm    varchar(20)  NULL,
    ins_id     varchar(20)  NULL,
    ins_dt     timestamp    NULL DEFAULT now(),
    upd_id     varchar(20)  NULL,
    upd_dt     timestamp    NULL,
    CONSTRAINT ux_tbl_tml_ccp_chk_ver_item UNIQUE (co_cd, tmpl_cd, ver_no, item_cd)
);
COMMENT ON TABLE tbl_tml_ccp_chk_ver_item IS 'CCP 검증점검 자사 양식 항목';

-- ------------------------------------------------------------
-- 2. 기존 tbl_html_form_ver 행 이전 (코드 치환 포함)
-- ------------------------------------------------------------
INSERT INTO tbl_html_hyg_prc_ver (
    co_cd, tmpl_cd, ver_no, ver_cd, ver_nm, apply_yn, use_yn, ins_id, ins_dt, upd_id, upd_dt
)
SELECT v.co_cd,
       replace(v.tmpl_cd, 'html_hyg_', 'html_hyg_prc_'),
       v.ver_no,
       replace(COALESCE(NULLIF(btrim(v.ver_cd), ''), v.tmpl_cd), 'html_hyg_', 'html_hyg_prc_'),
       v.ver_nm, v.apply_yn, v.use_yn, v.ins_id, v.ins_dt, v.upd_id, v.upd_dt
  FROM tbl_html_form_ver v
 WHERE v.tmpl_cd ~ '^html_hyg_[0-9]{3}$'
ON CONFLICT (co_cd, tmpl_cd, ver_no) DO NOTHING;

INSERT INTO tbl_html_hyg_prc_ver_item (
    co_cd, tmpl_cd, ver_no, item_cd, sort_no, cycle_nm, grp_nm, item_nm, input_type, unit_nm, ins_id, ins_dt, upd_id, upd_dt
)
SELECT i.co_cd,
       replace(i.tmpl_cd, 'html_hyg_', 'html_hyg_prc_'),
       i.ver_no, i.item_cd, i.sort_no, i.cycle_nm, i.grp_nm, i.item_nm, i.input_type, i.unit_nm,
       i.ins_id, i.ins_dt, i.upd_id, i.upd_dt
  FROM tbl_html_form_ver_item i
 WHERE i.tmpl_cd ~ '^html_hyg_[0-9]{3}$'
ON CONFLICT (co_cd, tmpl_cd, ver_no, item_cd) DO NOTHING;

INSERT INTO tbl_tml_ccp_chk_ver (
    co_cd, tmpl_cd, ver_no, ver_cd, ver_nm, apply_yn, use_yn, ins_id, ins_dt, upd_id, upd_dt
)
SELECT v.co_cd, v.tmpl_cd, v.ver_no,
       COALESCE(NULLIF(btrim(v.ver_cd), ''), v.tmpl_cd),
       v.ver_nm, v.apply_yn, v.use_yn, v.ins_id, v.ins_dt, v.upd_id, v.upd_dt
  FROM tbl_html_form_ver v
 WHERE v.tmpl_cd ~ '^tml_ccp_chk_[0-9]{3}$'
ON CONFLICT (co_cd, tmpl_cd, ver_no) DO NOTHING;

INSERT INTO tbl_tml_ccp_chk_ver_item (
    co_cd, tmpl_cd, ver_no, item_cd, sort_no, cycle_nm, grp_nm, item_nm, input_type, unit_nm, ins_id, ins_dt, upd_id, upd_dt
)
SELECT i.co_cd, i.tmpl_cd, i.ver_no, i.item_cd, i.sort_no, i.cycle_nm, i.grp_nm, i.item_nm, i.input_type, i.unit_nm,
       i.ins_id, i.ins_dt, i.upd_id, i.upd_dt
  FROM tbl_html_form_ver_item i
 WHERE i.tmpl_cd ~ '^tml_ccp_chk_[0-9]{3}$'
ON CONFLICT (co_cd, tmpl_cd, ver_no, item_cd) DO NOTHING;

DELETE FROM tbl_html_form_ver_item
 WHERE tmpl_cd ~ '^html_hyg_[0-9]{3}$' OR tmpl_cd ~ '^tml_ccp_chk_[0-9]{3}$';
DELETE FROM tbl_html_form_ver
 WHERE tmpl_cd ~ '^html_hyg_[0-9]{3}$' OR tmpl_cd ~ '^tml_ccp_chk_[0-9]{3}$';

-- ------------------------------------------------------------
-- 3. 카탈로그·주기·문서 tmpl_cd 치환 html_hyg_NNN → html_hyg_prc_NNN
-- ------------------------------------------------------------
DO $$
DECLARE r record;
BEGIN
    FOR r IN
        SELECT c.table_name, c.column_name
          FROM information_schema.columns c
          JOIN information_schema.tables t
            ON t.table_schema = c.table_schema AND t.table_name = c.table_name
         WHERE c.table_schema = 'sasshaccp'
           AND t.table_type = 'BASE TABLE'
           AND c.column_name IN ('tmpl_cd', 'src_tmpl_cd', 'ref_tmpl_cd')
           AND c.table_name NOT IN ('tbl_html_hyg_prc_ver', 'tbl_html_hyg_prc_ver_item')
    LOOP
        EXECUTE format(
            'UPDATE %I SET %I = replace(%I, ''html_hyg_'', ''html_hyg_prc_'') WHERE %I ~ ''^html_hyg_[0-9]{3}$''',
            r.table_name, r.column_name, r.column_name, r.column_name
        );
    END LOOP;
END$$;

-- ------------------------------------------------------------
-- 4. 공정점검 SP — tbl_html_hyg_prc_ver
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_html_hyg_prc_ver_r_000(varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_html_hyg_prc_ver_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_tmpl_cd: 호환. 목록은 html_hyg_prc 고정
    p_tmpl_cd varchar,
    -- p_ver_cd: 양식코드 부분검색
    p_ver_cd  varchar DEFAULT NULL,
    -- p_ver_nm: 양식명 부분검색
    p_ver_nm  varchar DEFAULT NULL
)
RETURNS TABLE(
    idx bigint, tmpl_cd varchar, ver_no int, ver_cd varchar, ver_nm varchar,
    sys_yn varchar, apply_yn varchar, locked_yn varchar, ins_nm varchar, ins_dt varchar
) LANGUAGE sql STABLE AS $$
    SELECT x.idx, x.tmpl_cd, x.ver_no, x.ver_cd, x.ver_nm, x.sys_yn, x.apply_yn, x.locked_yn, x.ins_nm, x.ins_dt
      FROM (
            SELECT NULL::bigint, 'html_hyg_prc_000'::varchar, 0, 'html_hyg_prc_000'::varchar,
                   '표준'::varchar, 'sys'::varchar, 'N'::varchar, 'Y'::varchar, ''::varchar, ''::varchar
            UNION ALL
            SELECT v.idx, v.tmpl_cd, v.ver_no,
                   COALESCE(NULLIF(btrim(v.ver_cd), ''), v.tmpl_cd),
                   COALESCE(ct.tmpl_nm_ovr, v.ver_nm),
                   'usr'::varchar, v.apply_yn, 'N'::varchar,
                   COALESCE(u.user_nm, v.ins_id, '')::varchar,
                   COALESCE(to_char(v.ins_dt, 'YYYY-MM-DD'), '')::varchar
              FROM tbl_html_hyg_prc_ver v
              JOIN tbl_company_template ct ON ct.co_cd = v.co_cd AND ct.tmpl_cd = v.tmpl_cd
              LEFT JOIN tbl_user u ON u.co_cd = v.co_cd AND u.user_id = v.ins_id
             WHERE v.co_cd = p_co_cd AND v.use_yn = 'Y'
               AND v.tmpl_cd ~ '^html_hyg_prc_[0-9]{3}$' AND v.tmpl_cd <> 'html_hyg_prc_000'
           ) x(idx, tmpl_cd, ver_no, ver_cd, ver_nm, sys_yn, apply_yn, locked_yn, ins_nm, ins_dt)
     WHERE (COALESCE(btrim(p_ver_cd), '') = '' OR x.tmpl_cd ILIKE '%' || btrim(p_ver_cd) || '%')
       AND (COALESCE(btrim(p_ver_nm), '') = '' OR x.ver_nm ILIKE '%' || btrim(p_ver_nm) || '%')
     ORDER BY x.tmpl_cd;
$$;

DROP FUNCTION IF EXISTS sp_tbl_html_hyg_prc_ver_item_r_000(varchar, varchar, int);
CREATE FUNCTION sp_tbl_html_hyg_prc_ver_item_r_000(
    p_co_cd varchar, p_tmpl_cd varchar, p_ver_no int
)
RETURNS TABLE(
    item_cd varchar, sort_no int, cycle_nm varchar, grp_nm varchar, item_nm text, input_type varchar, unit_nm varchar
) LANGUAGE plpgsql STABLE AS $$
BEGIN
    -- 예시·옛 코드·시드일 때(= html_sys_001)
    IF COALESCE(p_tmpl_cd, '') IN ('html_hyg_prc_000', 'html_hyg_000', 'html_sys_001', '') THEN
        RETURN QUERY
        SELECT c.item_cd, c.sort_no, c.cycle_nm, c.grp_nm, c.item_nm, c.input_type, c.unit_nm
          FROM tbl_check_item c
         WHERE c.tmpl_cd = 'html_sys_001' AND c.use_yn = 'Y'
         ORDER BY c.sort_no, c.item_cd;
        RETURN;
    END IF;
    RETURN QUERY
    SELECT i.item_cd, i.sort_no, i.cycle_nm, i.grp_nm, i.item_nm, i.input_type, i.unit_nm
      FROM tbl_html_hyg_prc_ver_item i
     WHERE i.co_cd = p_co_cd AND i.tmpl_cd = p_tmpl_cd AND i.ver_no = p_ver_no
     ORDER BY i.sort_no, i.item_cd;
END$$;

DROP FUNCTION IF EXISTS sp_tbl_html_hyg_prc_ver_copy_c_000(varchar, varchar, int, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_html_hyg_prc_ver_copy_c_000(
    p_co_cd varchar, p_tmpl_cd varchar, p_src_ver_no int, p_ver_cd varchar, p_ver_nm varchar, p_id varchar
)
RETURNS varchar LANGUAGE plpgsql AS $$
DECLARE v_nm varchar; v_n int; v_cd varchar; v_src tbl_template%ROWTYPE; v_try int := 0;
BEGIN
    IF COALESCE(p_co_cd, '') = '' THEN
        RAISE EXCEPTION '회사코드는 필수입니다.' USING ERRCODE = '45000';
    END IF;
    v_nm := btrim(COALESCE(p_ver_nm, ''));
    IF v_nm = '' THEN
        RAISE EXCEPTION '양식명은 필수입니다.' USING ERRCODE = '45000';
    END IF;
    SELECT * INTO v_src FROM tbl_template WHERE tmpl_cd = 'html_sys_001';
    IF NOT FOUND THEN
        RAISE EXCEPTION '표준 양식을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    SELECT COALESCE(MAX(substring(t.tmpl_cd from '[0-9]{3}$')::int), 0) INTO v_n
      FROM tbl_template t
     WHERE t.tmpl_cd ~ '^html_hyg_prc_[0-9]{3}$' AND t.tmpl_cd <> 'html_hyg_prc_000';
    LOOP
        v_try := v_try + 1; v_n := v_n + 1;
        IF v_n > 999 OR v_try > 50 THEN
            RAISE EXCEPTION '양식코드를 더 부여할 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        v_cd := 'html_hyg_prc_' || lpad(v_n::text, 3, '0');
        IF v_cd = 'html_hyg_prc_000' THEN CONTINUE; END IF;
        EXIT WHEN NOT EXISTS (SELECT 1 FROM tbl_template WHERE tmpl_cd = v_cd);
    END LOOP;
    INSERT INTO tbl_template (
        co_cd, tmpl_cd, tmpl_nm, mng_no, doc_kind, category_cd, scrn_cd,
        default_cycle_cd, default_retention_month, impl_yn, sort_no, use_yn, ins_id, ins_dt
    ) VALUES (
        p_co_cd, v_cd, v_nm, v_src.mng_no, 'html', v_src.category_cd, 'hygiene-process-check',
        'D', COALESCE(v_src.default_retention_month, 24), 'Y',
        COALESCE(v_src.sort_no, 101) + v_n, 'Y', p_id, now()
    );
    INSERT INTO tbl_company_template (
        co_cd, tmpl_cd, tmpl_nm_ovr, cycle_cd, retention_month, use_yn, sys_yn, ins_id, ins_dt
    ) VALUES (
        p_co_cd, v_cd, v_nm, 'D', COALESCE(v_src.default_retention_month, 24), 'Y', 'usr', p_id, now()
    );
    INSERT INTO tbl_html_hyg_prc_ver (co_cd, tmpl_cd, ver_no, ver_cd, ver_nm, apply_yn, use_yn, ins_id, ins_dt)
    VALUES (p_co_cd, v_cd, 1, v_cd, v_nm, 'N', 'Y', p_id, now());
    INSERT INTO tbl_html_hyg_prc_ver_item (
        co_cd, tmpl_cd, ver_no, item_cd, sort_no, cycle_nm, grp_nm, item_nm, input_type, unit_nm, ins_id
    )
    SELECT p_co_cd, v_cd, 1, c.item_cd, c.sort_no, c.cycle_nm, c.grp_nm, c.item_nm, c.input_type, c.unit_nm, p_id
      FROM tbl_check_item c WHERE c.tmpl_cd = 'html_sys_001' AND c.use_yn = 'Y';
    INSERT INTO tbl_schedule_rule (co_cd, tmpl_cd, rule_seq, cycle_cd, nonwork_rule, due_time, use_yn, ins_id, ins_dt)
    VALUES (p_co_cd, v_cd, 1, 'D', 'keep', '1800', 'Y', p_id, now())
    ON CONFLICT (co_cd, tmpl_cd) DO NOTHING;
    RETURN v_cd;
END$$;

DROP PROCEDURE IF EXISTS sp_tbl_html_hyg_prc_ver_item_u_000(varchar, varchar, int, jsonb, varchar);
CREATE PROCEDURE sp_tbl_html_hyg_prc_ver_item_u_000(
    p_co_cd varchar, p_tmpl_cd varchar, p_ver_no int, p_items jsonb, p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE e jsonb; v_cnt int := 0;
BEGIN
    IF COALESCE(p_tmpl_cd, '') IN ('html_hyg_prc_000', 'html_hyg_000', 'html_sys_001') OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 항목은 수정할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM tbl_html_hyg_prc_ver
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y'
    ) THEN
        RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' THEN
        RAISE EXCEPTION '점검항목 자료가 올바르지 않습니다.' USING ERRCODE = '45000';
    END IF;
    DELETE FROM tbl_html_hyg_prc_ver_item WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
    FOR e IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_cnt := v_cnt + 1;
        INSERT INTO tbl_html_hyg_prc_ver_item (
            co_cd, tmpl_cd, ver_no, item_cd, sort_no, cycle_nm, grp_nm, item_nm, input_type, unit_nm, ins_id, upd_id, upd_dt
        ) VALUES (
            p_co_cd, p_tmpl_cd, p_ver_no,
            COALESCE(NULLIF(e->>'itemCd', ''), 'hp-u-' || lpad(v_cnt::text, 3, '0')),
            COALESCE(NULLIF(e->>'sortNo', '')::int, v_cnt),
            NULLIF(e->>'cycleNm', ''), NULLIF(e->>'grpNm', ''), COALESCE(e->>'itemNm', ''),
            COALESCE(NULLIF(e->>'inputType', ''), 'radio'), NULLIF(e->>'unitNm', ''),
            p_id, p_id, now()
        );
    END LOOP;
    UPDATE tbl_html_hyg_prc_ver SET upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
END$$;

DROP PROCEDURE IF EXISTS sp_tbl_html_hyg_prc_ver_nm_u_000(varchar, varchar, int, varchar, varchar);
CREATE PROCEDURE sp_tbl_html_hyg_prc_ver_nm_u_000(
    p_co_cd varchar, p_tmpl_cd varchar, p_ver_no int, p_ver_nm varchar, p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE v_nm varchar;
BEGIN
    IF COALESCE(p_tmpl_cd, '') IN ('html_hyg_prc_000', 'html_hyg_000', 'html_sys_001') OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 양식명은 수정할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    v_nm := btrim(COALESCE(p_ver_nm, ''));
    IF v_nm = '' THEN RAISE EXCEPTION '양식명은 필수입니다.' USING ERRCODE = '45000'; END IF;
    UPDATE tbl_html_hyg_prc_ver SET ver_nm = v_nm, upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
    IF NOT FOUND THEN RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    UPDATE tbl_template SET tmpl_nm = v_nm, upd_id = p_id, upd_dt = now() WHERE tmpl_cd = p_tmpl_cd AND co_cd = p_co_cd;
    UPDATE tbl_company_template SET tmpl_nm_ovr = v_nm, upd_id = p_id, upd_dt = now() WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
END$$;

DROP FUNCTION IF EXISTS sp_tbl_html_hyg_prc_ver_delete_blocker_r_000(varchar, varchar, int);
CREATE FUNCTION sp_tbl_html_hyg_prc_ver_delete_blocker_r_000(p_co_cd varchar, p_tmpl_cd varchar, p_ver_no int)
RETURNS TABLE(ref_key varchar, target varchar) LANGUAGE plpgsql STABLE AS $$
DECLARE v_nm varchar; v_use varchar; v_key varchar;
BEGIN
    v_key := COALESCE(NULLIF(btrim(p_tmpl_cd), ''), COALESCE(p_ver_no::varchar, ''));
    IF COALESCE(p_tmpl_cd, '') IN ('html_hyg_prc_000', 'html_hyg_000', 'html_sys_001') OR COALESCE(p_ver_no, 0) <= 0 THEN
        RETURN QUERY SELECT '표준'::varchar, '시스템 표준 항목'::varchar; RETURN;
    END IF;
    SELECT ver_nm, use_yn INTO v_nm, v_use FROM tbl_html_hyg_prc_ver
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
    IF v_nm IS NULL OR v_use = 'N' THEN
        RETURN QUERY SELECT v_key, '없는 양식'::varchar; RETURN;
    END IF;
    IF EXISTS (SELECT 1 FROM tbl_document d WHERE d.co_cd = p_co_cd AND d.tmpl_cd = p_tmpl_cd AND d.del_yn = 'N') THEN
        RETURN QUERY SELECT COALESCE(v_nm, v_key), '작성 문서'::varchar; RETURN;
    END IF;
    IF EXISTS (SELECT 1 FROM tbl_schedule_task t WHERE t.co_cd = p_co_cd AND t.tmpl_cd = p_tmpl_cd) THEN
        RETURN QUERY SELECT COALESCE(v_nm, v_key), '오늘 할 일'::varchar;
    END IF;
END$$;

DROP PROCEDURE IF EXISTS sp_tbl_html_hyg_prc_ver_d_000(varchar, varchar, int, varchar);
CREATE PROCEDURE sp_tbl_html_hyg_prc_ver_d_000(p_co_cd varchar, p_tmpl_cd varchar, p_ver_no int, p_id varchar)
LANGUAGE plpgsql AS $$
BEGIN
    IF COALESCE(p_tmpl_cd, '') IN ('html_hyg_prc_000', 'html_hyg_000', 'html_sys_001') OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 양식은 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM tbl_html_hyg_prc_ver
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y'
    ) THEN
        RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    DELETE FROM tbl_schedule_rule_detail WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    DELETE FROM tbl_schedule_rule WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    DELETE FROM tbl_company_template WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    UPDATE tbl_html_hyg_prc_ver SET use_yn = 'N', apply_yn = 'N', upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
END$$;

DROP PROCEDURE IF EXISTS sp_tbl_html_hyg_prc_ver_apply_u_000(varchar, varchar, int, varchar);
CREATE PROCEDURE sp_tbl_html_hyg_prc_ver_apply_u_000(p_co_cd varchar, p_tmpl_cd varchar, p_ver_no int, p_id varchar)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE tbl_html_hyg_prc_ver SET apply_yn = 'N', upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND apply_yn = 'Y';
    IF COALESCE(p_ver_no, 0) > 0 THEN
        UPDATE tbl_html_hyg_prc_ver SET apply_yn = 'Y', upd_id = p_id, upd_dt = now()
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
        IF NOT FOUND THEN RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    END IF;
END$$;

-- ------------------------------------------------------------
-- 5. CCP SP — tbl_tml_ccp_chk_ver
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_tml_ccp_chk_ver_r_000(varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_tml_ccp_chk_ver_r_000(
    p_co_cd varchar, p_tmpl_cd varchar, p_ver_cd varchar DEFAULT NULL, p_ver_nm varchar DEFAULT NULL
)
RETURNS TABLE(
    idx bigint, tmpl_cd varchar, ver_no int, ver_cd varchar, ver_nm varchar,
    sys_yn varchar, apply_yn varchar, locked_yn varchar, ins_nm varchar, ins_dt varchar
) LANGUAGE sql STABLE AS $$
    SELECT x.idx, x.tmpl_cd, x.ver_no, x.ver_cd, x.ver_nm, x.sys_yn, x.apply_yn, x.locked_yn, x.ins_nm, x.ins_dt
      FROM (
            SELECT NULL::bigint, 'tml_ccp_chk_000'::varchar, 0, 'tml_ccp_chk_000'::varchar,
                   '표준'::varchar, 'sys'::varchar, 'N'::varchar, 'Y'::varchar, ''::varchar, ''::varchar
            UNION ALL
            SELECT v.idx, v.tmpl_cd, v.ver_no,
                   COALESCE(NULLIF(btrim(v.ver_cd), ''), v.tmpl_cd),
                   COALESCE(ct.tmpl_nm_ovr, v.ver_nm),
                   'usr'::varchar, v.apply_yn, 'N'::varchar,
                   COALESCE(u.user_nm, v.ins_id, '')::varchar,
                   COALESCE(to_char(v.ins_dt, 'YYYY-MM-DD'), '')::varchar
              FROM tbl_tml_ccp_chk_ver v
              JOIN tbl_company_template ct ON ct.co_cd = v.co_cd AND ct.tmpl_cd = v.tmpl_cd
              LEFT JOIN tbl_user u ON u.co_cd = v.co_cd AND u.user_id = v.ins_id
             WHERE v.co_cd = p_co_cd AND v.use_yn = 'Y'
               AND v.tmpl_cd ~ '^tml_ccp_chk_[0-9]{3}$' AND v.tmpl_cd <> 'tml_ccp_chk_000'
           ) x(idx, tmpl_cd, ver_no, ver_cd, ver_nm, sys_yn, apply_yn, locked_yn, ins_nm, ins_dt)
     WHERE (COALESCE(btrim(p_ver_cd), '') = '' OR x.tmpl_cd ILIKE '%' || btrim(p_ver_cd) || '%')
       AND (COALESCE(btrim(p_ver_nm), '') = '' OR x.ver_nm ILIKE '%' || btrim(p_ver_nm) || '%')
     ORDER BY x.tmpl_cd;
$$;

DROP FUNCTION IF EXISTS sp_tbl_tml_ccp_chk_ver_item_r_000(varchar, varchar, int);
CREATE FUNCTION sp_tbl_tml_ccp_chk_ver_item_r_000(p_co_cd varchar, p_tmpl_cd varchar, p_ver_no int)
RETURNS TABLE(
    item_cd varchar, sort_no int, cycle_nm varchar, grp_nm varchar, item_nm text, input_type varchar, unit_nm varchar
) LANGUAGE plpgsql STABLE AS $$
BEGIN
    IF COALESCE(p_tmpl_cd, '') IN ('tml_ccp_chk_000', 'html_sys_006') THEN
        RETURN QUERY
        SELECT c.item_cd, c.sort_no, c.cycle_nm, c.grp_nm, c.item_nm, c.input_type, c.unit_nm
          FROM tbl_check_item c
         WHERE c.tmpl_cd = 'tml_ccp_chk_000' AND c.use_yn = 'Y'
         ORDER BY c.sort_no, c.item_cd;
        RETURN;
    END IF;
    RETURN QUERY
    SELECT i.item_cd, i.sort_no, i.cycle_nm, i.grp_nm, i.item_nm, i.input_type, i.unit_nm
      FROM tbl_tml_ccp_chk_ver_item i
     WHERE i.co_cd = p_co_cd AND i.tmpl_cd = p_tmpl_cd AND i.ver_no = p_ver_no
     ORDER BY i.sort_no, i.item_cd;
END$$;

DROP FUNCTION IF EXISTS sp_tbl_tml_ccp_chk_ver_copy_c_000(varchar, varchar, int, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_tml_ccp_chk_ver_copy_c_000(
    p_co_cd varchar, p_tmpl_cd varchar, p_src_ver_no int, p_ver_cd varchar, p_ver_nm varchar, p_id varchar
)
RETURNS varchar LANGUAGE plpgsql AS $$
DECLARE v_nm varchar; v_n int; v_cd varchar; v_src tbl_template%ROWTYPE; v_try int := 0; v_cycle varchar;
BEGIN
    IF COALESCE(p_co_cd, '') = '' THEN
        RAISE EXCEPTION '회사코드는 필수입니다.' USING ERRCODE = '45000';
    END IF;
    v_nm := btrim(COALESCE(p_ver_nm, ''));
    IF v_nm = '' THEN RAISE EXCEPTION '양식명은 필수입니다.' USING ERRCODE = '45000'; END IF;
    SELECT * INTO v_src FROM tbl_template WHERE tmpl_cd = 'html_sys_006';
    IF NOT FOUND THEN RAISE EXCEPTION '표준 양식을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    v_cycle := COALESCE(NULLIF(btrim(v_src.default_cycle_cd), ''), 'M');
    SELECT COALESCE(MAX(substring(t.tmpl_cd from '[0-9]{3}$')::int), 0) INTO v_n
      FROM tbl_template t
     WHERE t.tmpl_cd ~ '^tml_ccp_chk_[0-9]{3}$' AND t.tmpl_cd <> 'tml_ccp_chk_000';
    LOOP
        v_try := v_try + 1; v_n := v_n + 1;
        IF v_n > 999 OR v_try > 50 THEN
            RAISE EXCEPTION '양식코드를 더 부여할 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        v_cd := 'tml_ccp_chk_' || lpad(v_n::text, 3, '0');
        IF v_cd = 'tml_ccp_chk_000' THEN CONTINUE; END IF;
        EXIT WHEN NOT EXISTS (SELECT 1 FROM tbl_template WHERE tmpl_cd = v_cd);
    END LOOP;
    INSERT INTO tbl_template (
        co_cd, tmpl_cd, tmpl_nm, mng_no, doc_kind, category_cd, scrn_cd,
        default_cycle_cd, default_retention_month, impl_yn, sort_no, use_yn, ins_id, ins_dt
    ) VALUES (
        p_co_cd, v_cd, v_nm, v_src.mng_no, 'html', v_src.category_cd, 'ccp-verification-check',
        v_cycle, COALESCE(v_src.default_retention_month, 24), 'Y',
        COALESCE(v_src.sort_no, 106) + v_n, 'Y', p_id, now()
    );
    INSERT INTO tbl_company_template (
        co_cd, tmpl_cd, tmpl_nm_ovr, cycle_cd, retention_month, use_yn, sys_yn, ins_id, ins_dt
    ) VALUES (
        p_co_cd, v_cd, v_nm, v_cycle, COALESCE(v_src.default_retention_month, 24), 'Y', 'usr', p_id, now()
    );
    INSERT INTO tbl_tml_ccp_chk_ver (co_cd, tmpl_cd, ver_no, ver_cd, ver_nm, apply_yn, use_yn, ins_id, ins_dt)
    VALUES (p_co_cd, v_cd, 1, v_cd, v_nm, 'N', 'Y', p_id, now());
    INSERT INTO tbl_tml_ccp_chk_ver_item (
        co_cd, tmpl_cd, ver_no, item_cd, sort_no, cycle_nm, grp_nm, item_nm, input_type, unit_nm, ins_id
    )
    SELECT p_co_cd, v_cd, 1, c.item_cd, c.sort_no, c.cycle_nm, c.grp_nm, c.item_nm, c.input_type, c.unit_nm, p_id
      FROM tbl_check_item c WHERE c.tmpl_cd = 'tml_ccp_chk_000' AND c.use_yn = 'Y';
    INSERT INTO tbl_schedule_rule (co_cd, tmpl_cd, rule_seq, cycle_cd, nonwork_rule, due_time, use_yn, ins_id, ins_dt)
    VALUES (p_co_cd, v_cd, 1, v_cycle, 'keep', '1800', 'Y', p_id, now())
    ON CONFLICT (co_cd, tmpl_cd) DO NOTHING;
    RETURN v_cd;
END$$;

DROP PROCEDURE IF EXISTS sp_tbl_tml_ccp_chk_ver_item_u_000(varchar, varchar, int, jsonb, varchar);
CREATE PROCEDURE sp_tbl_tml_ccp_chk_ver_item_u_000(
    p_co_cd varchar, p_tmpl_cd varchar, p_ver_no int, p_items jsonb, p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE e jsonb; v_cnt int := 0;
BEGIN
    IF COALESCE(p_tmpl_cd, '') IN ('tml_ccp_chk_000', 'html_sys_006') OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 항목은 수정할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM tbl_tml_ccp_chk_ver
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y'
    ) THEN
        RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' THEN
        RAISE EXCEPTION '점검항목 자료가 올바르지 않습니다.' USING ERRCODE = '45000';
    END IF;
    DELETE FROM tbl_tml_ccp_chk_ver_item WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
    FOR e IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_cnt := v_cnt + 1;
        INSERT INTO tbl_tml_ccp_chk_ver_item (
            co_cd, tmpl_cd, ver_no, item_cd, sort_no, cycle_nm, grp_nm, item_nm, input_type, unit_nm, ins_id, upd_id, upd_dt
        ) VALUES (
            p_co_cd, p_tmpl_cd, p_ver_no,
            COALESCE(NULLIF(e->>'itemCd', ''), 'hp-u-' || lpad(v_cnt::text, 3, '0')),
            COALESCE(NULLIF(e->>'sortNo', '')::int, v_cnt),
            NULLIF(e->>'cycleNm', ''), NULLIF(e->>'grpNm', ''), COALESCE(e->>'itemNm', ''),
            COALESCE(NULLIF(e->>'inputType', ''), 'radio'), NULLIF(e->>'unitNm', ''),
            p_id, p_id, now()
        );
    END LOOP;
    UPDATE tbl_tml_ccp_chk_ver SET upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
END$$;

DROP PROCEDURE IF EXISTS sp_tbl_tml_ccp_chk_ver_nm_u_000(varchar, varchar, int, varchar, varchar);
CREATE PROCEDURE sp_tbl_tml_ccp_chk_ver_nm_u_000(
    p_co_cd varchar, p_tmpl_cd varchar, p_ver_no int, p_ver_nm varchar, p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE v_nm varchar;
BEGIN
    IF COALESCE(p_tmpl_cd, '') IN ('tml_ccp_chk_000', 'html_sys_006') OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 양식명은 수정할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    v_nm := btrim(COALESCE(p_ver_nm, ''));
    IF v_nm = '' THEN RAISE EXCEPTION '양식명은 필수입니다.' USING ERRCODE = '45000'; END IF;
    UPDATE tbl_tml_ccp_chk_ver SET ver_nm = v_nm, upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
    IF NOT FOUND THEN RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    UPDATE tbl_template SET tmpl_nm = v_nm, upd_id = p_id, upd_dt = now() WHERE tmpl_cd = p_tmpl_cd AND co_cd = p_co_cd;
    UPDATE tbl_company_template SET tmpl_nm_ovr = v_nm, upd_id = p_id, upd_dt = now() WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
END$$;

DROP FUNCTION IF EXISTS sp_tbl_tml_ccp_chk_ver_delete_blocker_r_000(varchar, varchar, int);
CREATE FUNCTION sp_tbl_tml_ccp_chk_ver_delete_blocker_r_000(p_co_cd varchar, p_tmpl_cd varchar, p_ver_no int)
RETURNS TABLE(ref_key varchar, target varchar) LANGUAGE plpgsql STABLE AS $$
DECLARE v_nm varchar; v_use varchar; v_key varchar;
BEGIN
    v_key := COALESCE(NULLIF(btrim(p_tmpl_cd), ''), COALESCE(p_ver_no::varchar, ''));
    IF COALESCE(p_tmpl_cd, '') IN ('tml_ccp_chk_000', 'html_sys_006') OR COALESCE(p_ver_no, 0) <= 0 THEN
        RETURN QUERY SELECT '표준'::varchar, '시스템 표준 항목'::varchar; RETURN;
    END IF;
    SELECT ver_nm, use_yn INTO v_nm, v_use FROM tbl_tml_ccp_chk_ver
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
    IF v_nm IS NULL OR v_use = 'N' THEN
        RETURN QUERY SELECT v_key, '없는 양식'::varchar; RETURN;
    END IF;
    IF EXISTS (SELECT 1 FROM tbl_document d WHERE d.co_cd = p_co_cd AND d.tmpl_cd = p_tmpl_cd AND d.del_yn = 'N') THEN
        RETURN QUERY SELECT COALESCE(v_nm, v_key), '작성 문서'::varchar; RETURN;
    END IF;
    IF EXISTS (SELECT 1 FROM tbl_schedule_task t WHERE t.co_cd = p_co_cd AND t.tmpl_cd = p_tmpl_cd) THEN
        RETURN QUERY SELECT COALESCE(v_nm, v_key), '오늘 할 일'::varchar;
    END IF;
END$$;

DROP PROCEDURE IF EXISTS sp_tbl_tml_ccp_chk_ver_d_000(varchar, varchar, int, varchar);
CREATE PROCEDURE sp_tbl_tml_ccp_chk_ver_d_000(p_co_cd varchar, p_tmpl_cd varchar, p_ver_no int, p_id varchar)
LANGUAGE plpgsql AS $$
BEGIN
    IF COALESCE(p_tmpl_cd, '') IN ('tml_ccp_chk_000', 'html_sys_006') OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 양식은 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM tbl_tml_ccp_chk_ver
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y'
    ) THEN
        RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    DELETE FROM tbl_schedule_rule_detail WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    DELETE FROM tbl_schedule_rule WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    DELETE FROM tbl_company_template WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    UPDATE tbl_tml_ccp_chk_ver SET use_yn = 'N', apply_yn = 'N', upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
END$$;

DROP PROCEDURE IF EXISTS sp_tbl_tml_ccp_chk_ver_apply_u_000(varchar, varchar, int, varchar);
CREATE PROCEDURE sp_tbl_tml_ccp_chk_ver_apply_u_000(p_co_cd varchar, p_tmpl_cd varchar, p_ver_no int, p_id varchar)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE tbl_tml_ccp_chk_ver SET apply_yn = 'N', upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND apply_yn = 'Y';
    IF COALESCE(p_ver_no, 0) > 0 THEN
        UPDATE tbl_tml_ccp_chk_ver SET apply_yn = 'Y', upd_id = p_id, upd_dt = now()
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
        IF NOT FOUND THEN RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    END IF;
END$$;

-- ------------------------------------------------------------
-- 6. 문서주기 — html_hyg_prc_001+ · tml_ccp_chk_001+
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_schedule_cycle_management_form_r_000(
    p_co_cd varchar, p_tmpl_cd varchar, p_tmpl_nm varchar, p_use_yn varchar
)
RETURNS TABLE(
    tmpl_cd varchar, tmpl_nm varchar, sys_yn varchar, doc_kind varchar, cycle_cd varchar, rule_yn varchar, use_yn varchar
) LANGUAGE sql STABLE AS $$
    SELECT ct.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm),
           lower(CASE WHEN COALESCE(ct.sys_yn, 'sys') IN ('N', 'n', 'usr') THEN 'usr' ELSE 'sys' END),
           t.doc_kind,
           r.cycle_cd,
           CASE WHEN r.idx IS NULL THEN 'N' ELSE 'Y' END,
           upper(COALESCE(ct.use_yn, 'N'))
      FROM tbl_company_template ct
      JOIN tbl_template t ON t.tmpl_cd = ct.tmpl_cd
      LEFT JOIN tbl_schedule_rule r ON r.co_cd = ct.co_cd AND r.tmpl_cd = ct.tmpl_cd
     WHERE ct.co_cd = p_co_cd
       AND (
            ct.tmpl_cd ~ '^html_sys_0(0[2-57-9]|10|12)$'
         OR (ct.tmpl_cd ~ '^html_hyg_prc_[0-9]{3}$' AND ct.tmpl_cd <> 'html_hyg_prc_000')
         OR (ct.tmpl_cd ~ '^tml_ccp_chk_[0-9]{3}$' AND ct.tmpl_cd <> 'tml_ccp_chk_000')
         OR ct.tmpl_cd ~ '^hwp_sys_0(0[1-9]|1[0-9]|2[0-7])$'
         OR ct.tmpl_cd LIKE 'hwp_usr_%'
       )
       AND (
            COALESCE(NULLIF(btrim(p_use_yn), ''), '') = ''
            OR upper(COALESCE(ct.use_yn, 'N')) = upper(btrim(p_use_yn))
           )
       AND ct.tmpl_cd LIKE CONCAT('%', COALESCE(p_tmpl_cd, ''), '%')
       AND COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm) LIKE CONCAT('%', COALESCE(p_tmpl_nm, ''), '%')
     ORDER BY t.sort_no, ct.tmpl_cd;
$$;
COMMENT ON FUNCTION sp_schedule_cycle_management_form_r_000(varchar, varchar, varchar, varchar) IS
  '문서주기관리 좌측 — html_hyg_prc_001+ · tml_ccp_chk_001+ · html_sys_002~005·007~010·012 · hwp. 예시 000·html_sys_001·006 숨김';
