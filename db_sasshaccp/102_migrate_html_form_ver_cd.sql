-- ============================================================
-- 102 — HTML 양식 버전코드 ver_cd
--
-- 파일번호: 102
-- 이전번호: 101
-- 개발자: 박승우
-- 일자: 2026-08-19
-- 코멘트:
--   1) 사용자 버전은 ver_cd 필수. 표준 가상행만 0.1
--   2) ver_cd는 활성(use_yn=Y)만 부분 유니크. ver_no는 전체 UNIQUE(재사용 금지)
--   3) 복사 SP가 ver_cd를 받아 INSERT한다. 목록은 코드·이름 LIKE. 101 재실행 금지
--
-- ============================================================

SET search_path TO sasshaccp;

ALTER TABLE tbl_html_form_ver
    ADD COLUMN IF NOT EXISTS ver_cd varchar(20);

UPDATE tbl_html_form_ver
   SET ver_cd = ver_no::text
 WHERE ver_cd IS NULL OR btrim(ver_cd) = '';

ALTER TABLE tbl_html_form_ver
    ALTER COLUMN ver_cd SET NOT NULL;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conname = 'ux_tbl_html_form_ver_code'
    ) THEN
        ALTER TABLE tbl_html_form_ver DROP CONSTRAINT ux_tbl_html_form_ver_code;
    END IF;
END$$;

CREATE UNIQUE INDEX IF NOT EXISTS ux_tbl_html_form_ver_cd
    ON tbl_html_form_ver (co_cd, tmpl_cd, ver_cd) WHERE use_yn = 'Y';

COMMENT ON COLUMN tbl_html_form_ver.ver_cd IS '버전코드 — 표준 가상행 0.1. 활성(use_yn=Y)만 업체+양식당 유니크. 삭제 후 재사용 가능';
COMMENT ON COLUMN tbl_html_form_ver.ver_no IS '표시 순번 — 1부터. 0은 표준 가상행. 항목·작성 문서가 참조하므로 재사용 금지';

DROP FUNCTION IF EXISTS sp_tbl_html_form_ver_r_000(varchar, varchar);
DROP FUNCTION IF EXISTS sp_tbl_html_form_ver_r_000(varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_html_form_ver_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_tmpl_cd: 양식코드
    p_tmpl_cd varchar,
    -- p_ver_cd: 버전코드 부분검색. 빈값이면 전체
    p_ver_cd  varchar DEFAULT NULL,
    -- p_ver_nm: 버전명 부분검색. 빈값이면 전체
    p_ver_nm  varchar DEFAULT NULL
)
RETURNS TABLE(
    idx       bigint,
    ver_no    int,
    ver_cd    varchar,
    ver_nm    varchar,
    sys_yn    varchar,
    apply_yn  varchar,
    locked_yn varchar
) LANGUAGE sql STABLE AS $$
    SELECT x.idx, x.ver_no, x.ver_cd, x.ver_nm, x.sys_yn, x.apply_yn, x.locked_yn
      FROM (
            SELECT NULL::bigint AS idx, 0 AS ver_no, '0.1'::varchar AS ver_cd, '표준'::varchar AS ver_nm,
                   'sys'::varchar AS sys_yn,
                   CASE WHEN EXISTS (
                        SELECT 1 FROM tbl_html_form_ver v
                         WHERE v.co_cd = p_co_cd AND v.tmpl_cd = p_tmpl_cd
                           AND v.apply_yn = 'Y' AND v.use_yn = 'Y'
                   ) THEN 'N'::varchar ELSE 'Y'::varchar END AS apply_yn,
                   'Y'::varchar AS locked_yn
            UNION ALL
            SELECT v.idx, v.ver_no, v.ver_cd, v.ver_nm, 'usr'::varchar, v.apply_yn, 'N'::varchar
              FROM tbl_html_form_ver v
             WHERE v.co_cd = p_co_cd AND v.tmpl_cd = p_tmpl_cd AND v.use_yn = 'Y'
           ) x
     WHERE (COALESCE(btrim(p_ver_cd), '') = '' OR x.ver_cd ILIKE '%' || btrim(p_ver_cd) || '%')
       AND (COALESCE(btrim(p_ver_nm), '') = '' OR x.ver_nm ILIKE '%' || btrim(p_ver_nm) || '%')
     ORDER BY 2;
$$;

DROP PROCEDURE IF EXISTS sp_tbl_html_form_ver_copy_c_000(varchar, varchar, int, varchar, varchar);
DROP PROCEDURE IF EXISTS sp_tbl_html_form_ver_copy_c_000(varchar, varchar, int, varchar, varchar, varchar);
CREATE PROCEDURE sp_tbl_html_form_ver_copy_c_000(
    p_co_cd      varchar,
    p_tmpl_cd    varchar,
    p_src_ver_no int,
    p_ver_cd     varchar,
    p_ver_nm     varchar,
    p_id         varchar
)
LANGUAGE plpgsql AS $$
DECLARE v_no int; v_cd varchar;
BEGIN
    IF COALESCE(p_co_cd, '') = '' OR COALESCE(p_tmpl_cd, '') = '' THEN
        RAISE EXCEPTION '회사·양식코드는 필수입니다.' USING ERRCODE = '45000';
    END IF;
    v_cd := btrim(COALESCE(p_ver_cd, ''));
    IF v_cd = '' THEN
        RAISE EXCEPTION '버전코드는 필수입니다.' USING ERRCODE = '45000';
    END IF;
    IF v_cd = '0.1' THEN
        RAISE EXCEPTION '0.1은 표준 코드입니다. 다른 버전코드를 입력하세요.' USING ERRCODE = '45000';
    END IF;
    IF COALESCE(btrim(p_ver_nm), '') = '' THEN
        RAISE EXCEPTION '버전명은 필수입니다.' USING ERRCODE = '45000';
    END IF;
    IF EXISTS (
        SELECT 1 FROM tbl_html_form_ver
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_cd = v_cd AND use_yn = 'Y'
    ) THEN
        RAISE EXCEPTION '이미 사용 중인 버전코드입니다.' USING ERRCODE = '45000';
    END IF;
    IF COALESCE(p_src_ver_no, 0) > 0 AND NOT EXISTS (
        SELECT 1 FROM tbl_html_form_ver
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd
           AND ver_no = p_src_ver_no AND use_yn = 'Y'
    ) THEN
        RAISE EXCEPTION '복사할 버전을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    -- 삭제분 포함 MAX — ver_no는 항목·작성 문서가 참조하므로 재사용 금지
    SELECT COALESCE(MAX(ver_no), 0) + 1 INTO v_no
      FROM tbl_html_form_ver WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    INSERT INTO tbl_html_form_ver (co_cd, tmpl_cd, ver_no, ver_cd, ver_nm, apply_yn, use_yn, ins_id, ins_dt)
    VALUES (p_co_cd, p_tmpl_cd, v_no, v_cd, btrim(p_ver_nm), 'N', 'Y', p_id, now());
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
