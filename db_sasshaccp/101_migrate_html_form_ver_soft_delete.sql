-- ============================================================
-- 101 — HTML 양식 버전 소프트 삭제 · 적용 중 차단
--
-- 파일번호: 101
-- 이전번호: 100
-- 개발자: 박승우
-- 일자: 2026-08-19
-- 코멘트:
--   1) use_yn=N 소프트 삭제. 항목 행은 남겨 과거 작성 문서의 버전 순번을 되짚을 수 있다
--   2) apply_yn=Y 버전은 삭제 차단. 표준 적용은 apply_yn=Y 행이 없는 상태
--   3) 목록은 UNION ALL 가상 표준행 + use_yn=Y. idx는 PK, ver_no는 표시 순번
--
-- ============================================================

SET search_path TO sasshaccp;

ALTER TABLE tbl_html_form_ver
    ADD COLUMN IF NOT EXISTS use_yn varchar(1) NOT NULL DEFAULT 'Y';
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conname = 'ck_tbl_html_form_ver_use'
    ) THEN
        ALTER TABLE tbl_html_form_ver
            ADD CONSTRAINT ck_tbl_html_form_ver_use CHECK (use_yn IN ('Y', 'N'));
    END IF;
END$$;
COMMENT ON COLUMN tbl_html_form_ver.idx      IS '대리키 PK — identity';
COMMENT ON COLUMN tbl_html_form_ver.ver_no   IS '표시 순번 — 1부터. 소프트 삭제 후에도 재사용 금지';
COMMENT ON COLUMN tbl_html_form_ver.ver_nm   IS '버전명 — 유니크 아님';
COMMENT ON COLUMN tbl_html_form_ver.use_yn   IS '사용여부 — N=소프트 삭제';
COMMENT ON COLUMN tbl_html_form_ver.apply_yn IS '작성 신규 적용. 없으면(전부 N) 표준';

DROP FUNCTION IF EXISTS sp_tbl_html_form_ver_r_000(varchar, varchar);
CREATE FUNCTION sp_tbl_html_form_ver_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_tmpl_cd: 양식코드
    p_tmpl_cd varchar
)
RETURNS TABLE(
    idx       bigint,
    ver_no    int,
    ver_nm    varchar,
    sys_yn    varchar,
    apply_yn  varchar,
    locked_yn varchar
) LANGUAGE sql STABLE AS $$
    SELECT NULL::bigint, 0, '표준'::varchar, 'sys'::varchar,
           CASE WHEN EXISTS (
                SELECT 1 FROM tbl_html_form_ver v
                 WHERE v.co_cd = p_co_cd AND v.tmpl_cd = p_tmpl_cd
                   AND v.apply_yn = 'Y' AND v.use_yn = 'Y'
           ) THEN 'N' ELSE 'Y' END,
           'Y'::varchar
    UNION ALL
    SELECT v.idx, v.ver_no, v.ver_nm, 'usr'::varchar, v.apply_yn, 'N'::varchar
      FROM tbl_html_form_ver v
     WHERE v.co_cd = p_co_cd AND v.tmpl_cd = p_tmpl_cd AND v.use_yn = 'Y'
     ORDER BY 2;
$$;

CREATE OR REPLACE PROCEDURE sp_tbl_html_form_ver_copy_c_000(
    p_co_cd      varchar,
    p_tmpl_cd    varchar,
    p_src_ver_no int,
    p_ver_nm     varchar,
    p_id         varchar
)
LANGUAGE plpgsql AS $$
DECLARE v_no int;
BEGIN
    IF COALESCE(p_co_cd, '') = '' OR COALESCE(p_tmpl_cd, '') = '' THEN
        RAISE EXCEPTION '회사·양식코드는 필수입니다.' USING ERRCODE = '45000';
    END IF;
    IF COALESCE(btrim(p_ver_nm), '') = '' THEN
        RAISE EXCEPTION '버전명을 입력하세요.' USING ERRCODE = '45000';
    END IF;
    IF COALESCE(p_src_ver_no, 0) > 0 AND NOT EXISTS (
        SELECT 1 FROM tbl_html_form_ver
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd
           AND ver_no = p_src_ver_no AND use_yn = 'Y'
    ) THEN
        RAISE EXCEPTION '복사할 버전을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    -- 삭제분 포함 MAX — ver_no 재사용 금지
    SELECT COALESCE(MAX(ver_no), 0) + 1 INTO v_no
      FROM tbl_html_form_ver WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    INSERT INTO tbl_html_form_ver (co_cd, tmpl_cd, ver_no, ver_nm, apply_yn, use_yn, ins_id, ins_dt)
    VALUES (p_co_cd, p_tmpl_cd, v_no, btrim(p_ver_nm), 'N', 'Y', p_id, now());
    IF COALESCE(p_src_ver_no, 0) <= 0 THEN
        INSERT INTO tbl_html_form_ver_item (
            co_cd, tmpl_cd, ver_no, item_cd, sort_no, cycle_nm, grp_nm, item_nm, input_type, unit_nm, ins_id
        )
        SELECT p_co_cd, p_tmpl_cd, v_no, c.item_cd, c.sort_no, c.cycle_nm, c.grp_nm, c.item_nm, c.input_type, c.unit_nm, p_id
          FROM tbl_check_item c
         WHERE c.tmpl_cd = p_tmpl_cd AND c.use_yn = 'Y';
    ELSE
        INSERT INTO tbl_html_form_ver_item (
            co_cd, tmpl_cd, ver_no, item_cd, sort_no, cycle_nm, grp_nm, item_nm, input_type, unit_nm, ins_id
        )
        SELECT p_co_cd, p_tmpl_cd, v_no, i.item_cd, i.sort_no, i.cycle_nm, i.grp_nm, i.item_nm, i.input_type, i.unit_nm, p_id
          FROM tbl_html_form_ver_item i
         WHERE i.co_cd = p_co_cd AND i.tmpl_cd = p_tmpl_cd AND i.ver_no = p_src_ver_no;
    END IF;
END$$;

CREATE OR REPLACE PROCEDURE sp_tbl_html_form_ver_item_u_000(
    p_co_cd   varchar,
    p_tmpl_cd varchar,
    p_ver_no  int,
    p_items   jsonb,
    p_id      varchar
)
LANGUAGE plpgsql AS $$
DECLARE e jsonb; v_cnt int := 0;
BEGIN
    IF COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 항목은 수정할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM tbl_html_form_ver
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y'
    ) THEN
        RAISE EXCEPTION '버전을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' THEN
        RAISE EXCEPTION '점검항목 자료가 올바르지 않습니다.' USING ERRCODE = '45000';
    END IF;
    DELETE FROM tbl_html_form_ver_item
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
    FOR e IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_cnt := v_cnt + 1;
        INSERT INTO tbl_html_form_ver_item (
            co_cd, tmpl_cd, ver_no, item_cd, sort_no, cycle_nm, grp_nm, item_nm, input_type, unit_nm, ins_id, upd_id, upd_dt
        ) VALUES (
            p_co_cd, p_tmpl_cd, p_ver_no,
            COALESCE(NULLIF(e->>'itemCd', ''), 'hp-u-' || lpad(v_cnt::text, 3, '0')),
            COALESCE(NULLIF(e->>'sortNo', '')::int, v_cnt),
            NULLIF(e->>'cycleNm', ''),
            NULLIF(e->>'grpNm', ''),
            COALESCE(e->>'itemNm', ''),
            COALESCE(NULLIF(e->>'inputType', ''), 'YN'),
            NULLIF(e->>'unitNm', ''),
            p_id, p_id, now()
        );
    END LOOP;
    UPDATE tbl_html_form_ver SET upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
END$$;

CREATE OR REPLACE PROCEDURE sp_tbl_html_form_ver_apply_u_000(
    p_co_cd   varchar,
    p_tmpl_cd varchar,
    p_ver_no  int,
    p_id      varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE tbl_html_form_ver SET apply_yn = 'N', upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND apply_yn = 'Y';
    IF COALESCE(p_ver_no, 0) > 0 THEN
        UPDATE tbl_html_form_ver SET apply_yn = 'Y', upd_id = p_id, upd_dt = now()
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
        IF NOT FOUND THEN
            RAISE EXCEPTION '버전을 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
    END IF;
END$$;

DROP FUNCTION IF EXISTS sp_tbl_html_form_ver_delete_blocker_r_000(varchar, varchar, int);
CREATE FUNCTION sp_tbl_html_form_ver_delete_blocker_r_000(
    p_co_cd   varchar,
    p_tmpl_cd varchar,
    p_ver_no  int
)
RETURNS TABLE(ref_key varchar, target varchar) LANGUAGE plpgsql STABLE AS $$
DECLARE v_nm varchar; v_apply varchar; v_use varchar;
BEGIN
    IF COALESCE(p_ver_no, 0) <= 0 THEN
        RETURN QUERY SELECT '표준'::varchar, '시스템 표준 항목'::varchar;
        RETURN;
    END IF;
    SELECT ver_nm, apply_yn, use_yn INTO v_nm, v_apply, v_use
      FROM tbl_html_form_ver
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
    IF v_nm IS NULL OR v_use = 'N' THEN
        RETURN QUERY SELECT COALESCE(p_ver_no::varchar, '')::varchar, '없는 버전'::varchar;
        RETURN;
    END IF;
    IF v_apply = 'Y' THEN
        RETURN QUERY SELECT v_nm, '작성 적용'::varchar;
    END IF;
END$$;

CREATE OR REPLACE PROCEDURE sp_tbl_html_form_ver_d_000(
    p_co_cd   varchar,
    p_tmpl_cd varchar,
    p_ver_no  int,
    p_id      varchar
)
LANGUAGE plpgsql AS $$
DECLARE v_apply varchar;
BEGIN
    IF COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 항목은 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    SELECT apply_yn INTO v_apply
      FROM tbl_html_form_ver
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
    IF v_apply IS NULL THEN
        RAISE EXCEPTION '버전을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF v_apply = 'Y' THEN
        RAISE EXCEPTION '적용 중인 버전은 삭제할 수 없습니다. 다른 버전 또는 표준으로 바꾼 뒤 삭제하세요.' USING ERRCODE = '45000';
    END IF;
    UPDATE tbl_html_form_ver
       SET use_yn = 'N', apply_yn = 'N', upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
END$$;
