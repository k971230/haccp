-- ============================================================
-- 117 — HTML 양식 원본 목록 사용여부 (회사 양식 use_yn)
--
-- 파일번호: 117
-- 이전번호: 116
-- 개발자: 박승우
-- 일자: 2026-08-20
-- 코멘트:
--   1) 좌측 그리드 사용여부는 tbl_company_template.use_yn. 버전 use_yn 은 소프트 삭제 유지
--   2) 표준 *_000 가상행은 항상 N. 자사 신규는 복사 SP가 Y. 이름 SP가 사용여부도 같이 저장
--   3) 미사용 자사 양식도 원본 화면에는 남긴다. 문서주기는 회사 use_yn=Y 만
--
-- Jenkins는 migrate를 안 돌린다. DBeaver/수동
-- ============================================================

SET search_path TO sasshaccp;

-- 표준 가상코드 — 문서주기·작성 대상이 아니다. 있으면 N
UPDATE tbl_company_template
   SET use_yn = 'N',
       upd_id = 'system',
       upd_dt = now()
 WHERE tmpl_cd IN (
       'html_hyg_prc_000', 'html_hyg_000',
       'tml_ccp_chk_000', 'tml_ccp_pkg_000', 'tml_ccp_htg_000', 'tml_ccp_mtl_000'
 );

-- ------------------------------------------------------------
-- 목록 — RETURNS에 use_yn 추가. DROP 후 CREATE
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
    sys_yn varchar, apply_yn varchar, locked_yn varchar, ins_nm varchar, ins_dt varchar, use_yn varchar
) LANGUAGE sql STABLE AS $$
    SELECT x.idx, x.tmpl_cd, x.ver_no, x.ver_cd, x.ver_nm, x.sys_yn, x.apply_yn, x.locked_yn, x.ins_nm, x.ins_dt, x.use_yn
      FROM (
            SELECT NULL::bigint, 'html_hyg_prc_000'::varchar, 0, 'html_hyg_prc_000'::varchar,
                   '표준'::varchar, 'sys'::varchar, 'N'::varchar, 'Y'::varchar, ''::varchar, ''::varchar, 'N'::varchar
            UNION ALL
            SELECT v.idx, v.tmpl_cd, v.ver_no,
                   COALESCE(NULLIF(btrim(v.ver_cd), ''), v.tmpl_cd),
                   COALESCE(ct.tmpl_nm_ovr, v.ver_nm),
                   'usr'::varchar, v.apply_yn, 'N'::varchar,
                   COALESCE(u.user_nm, v.ins_id, '')::varchar,
                   COALESCE(to_char(v.ins_dt, 'YYYY-MM-DD'), '')::varchar,
                   CASE WHEN upper(COALESCE(ct.use_yn, 'Y')) = 'N' THEN 'N' ELSE 'Y' END
              FROM tbl_html_hyg_prc_ver v
              JOIN tbl_company_template ct ON ct.co_cd = v.co_cd AND ct.tmpl_cd = v.tmpl_cd
              LEFT JOIN tbl_user u ON u.co_cd = v.co_cd AND u.user_id = v.ins_id
             WHERE v.co_cd = p_co_cd AND v.use_yn = 'Y'
               AND v.tmpl_cd ~ '^html_hyg_prc_[0-9]{3}$' AND v.tmpl_cd <> 'html_hyg_prc_000'
           ) x(idx, tmpl_cd, ver_no, ver_cd, ver_nm, sys_yn, apply_yn, locked_yn, ins_nm, ins_dt, use_yn)
     WHERE (COALESCE(btrim(p_ver_cd), '') = '' OR x.tmpl_cd ILIKE '%' || btrim(p_ver_cd) || '%')
       AND (COALESCE(btrim(p_ver_nm), '') = '' OR x.ver_nm ILIKE '%' || btrim(p_ver_nm) || '%')
     ORDER BY x.tmpl_cd;
$$;

DROP FUNCTION IF EXISTS sp_tbl_tml_ccp_chk_ver_r_000(varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_tml_ccp_chk_ver_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_tmpl_cd: 호환. 목록은 tml_ccp_chk 고정
    p_tmpl_cd varchar,
    -- p_ver_cd: 양식코드 부분검색
    p_ver_cd varchar DEFAULT NULL,
    -- p_ver_nm: 양식명 부분검색
    p_ver_nm varchar DEFAULT NULL
)
RETURNS TABLE(
    idx bigint, tmpl_cd varchar, ver_no int, ver_cd varchar, ver_nm varchar,
    sys_yn varchar, apply_yn varchar, locked_yn varchar, ins_nm varchar, ins_dt varchar, use_yn varchar
) LANGUAGE sql STABLE AS $$
    SELECT x.idx, x.tmpl_cd, x.ver_no, x.ver_cd, x.ver_nm, x.sys_yn, x.apply_yn, x.locked_yn, x.ins_nm, x.ins_dt, x.use_yn
      FROM (
            SELECT NULL::bigint, 'tml_ccp_chk_000'::varchar, 0, 'tml_ccp_chk_000'::varchar,
                   '표준'::varchar, 'sys'::varchar, 'N'::varchar, 'Y'::varchar, ''::varchar, ''::varchar, 'N'::varchar
            UNION ALL
            SELECT v.idx, v.tmpl_cd, v.ver_no,
                   COALESCE(NULLIF(btrim(v.ver_cd), ''), v.tmpl_cd),
                   COALESCE(ct.tmpl_nm_ovr, v.ver_nm),
                   'usr'::varchar, v.apply_yn, 'N'::varchar,
                   COALESCE(u.user_nm, v.ins_id, '')::varchar,
                   COALESCE(to_char(v.ins_dt, 'YYYY-MM-DD'), '')::varchar,
                   CASE WHEN upper(COALESCE(ct.use_yn, 'Y')) = 'N' THEN 'N' ELSE 'Y' END
              FROM tbl_tml_ccp_chk_ver v
              JOIN tbl_company_template ct ON ct.co_cd = v.co_cd AND ct.tmpl_cd = v.tmpl_cd
              LEFT JOIN tbl_user u ON u.co_cd = v.co_cd AND u.user_id = v.ins_id
             WHERE v.co_cd = p_co_cd AND v.use_yn = 'Y'
               AND v.tmpl_cd ~ '^tml_ccp_chk_[0-9]{3}$' AND v.tmpl_cd <> 'tml_ccp_chk_000'
           ) x(idx, tmpl_cd, ver_no, ver_cd, ver_nm, sys_yn, apply_yn, locked_yn, ins_nm, ins_dt, use_yn)
     WHERE (COALESCE(btrim(p_ver_cd), '') = '' OR x.tmpl_cd ILIKE '%' || btrim(p_ver_cd) || '%')
       AND (COALESCE(btrim(p_ver_nm), '') = '' OR x.ver_nm ILIKE '%' || btrim(p_ver_nm) || '%')
     ORDER BY x.tmpl_cd;
$$;

DROP FUNCTION IF EXISTS sp_tbl_tml_ccp_pkg_ver_r_000(varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_tml_ccp_pkg_ver_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_tmpl_cd: 호환. 목록은 tml_ccp_pkg 고정
    p_tmpl_cd varchar,
    -- p_ver_cd: 양식코드 부분검색
    p_ver_cd varchar DEFAULT NULL,
    -- p_ver_nm: 양식명 부분검색
    p_ver_nm varchar DEFAULT NULL
)
RETURNS TABLE(
    idx bigint, tmpl_cd varchar, ver_no int, ver_cd varchar, ver_nm varchar,
    sys_yn varchar, apply_yn varchar, locked_yn varchar, ins_nm varchar, ins_dt varchar, use_yn varchar
) LANGUAGE sql STABLE AS $$
    SELECT x.idx, x.tmpl_cd, x.ver_no, x.ver_cd, x.ver_nm, x.sys_yn, x.apply_yn, x.locked_yn, x.ins_nm, x.ins_dt, x.use_yn
      FROM (
            SELECT NULL::bigint, 'tml_ccp_pkg_000'::varchar, 0, 'tml_ccp_pkg_000'::varchar,
                   '표준'::varchar, 'sys'::varchar, 'N'::varchar, 'Y'::varchar, ''::varchar, ''::varchar, 'N'::varchar
            UNION ALL
            SELECT v.idx, v.tmpl_cd, v.ver_no,
                   COALESCE(NULLIF(btrim(v.ver_cd), ''), v.tmpl_cd),
                   COALESCE(ct.tmpl_nm_ovr, v.ver_nm),
                   'usr'::varchar, v.apply_yn, 'N'::varchar,
                   COALESCE(u.user_nm, v.ins_id, '')::varchar,
                   COALESCE(to_char(v.ins_dt, 'YYYY-MM-DD'), '')::varchar,
                   CASE WHEN upper(COALESCE(ct.use_yn, 'Y')) = 'N' THEN 'N' ELSE 'Y' END
              FROM tbl_tml_ccp_pkg_ver v
              JOIN tbl_company_template ct ON ct.co_cd = v.co_cd AND ct.tmpl_cd = v.tmpl_cd
              LEFT JOIN tbl_user u ON u.co_cd = v.co_cd AND u.user_id = v.ins_id
             WHERE v.co_cd = p_co_cd AND v.use_yn = 'Y'
               AND v.tmpl_cd ~ '^tml_ccp_pkg_[0-9]{3}$' AND v.tmpl_cd <> 'tml_ccp_pkg_000'
           ) x(idx, tmpl_cd, ver_no, ver_cd, ver_nm, sys_yn, apply_yn, locked_yn, ins_nm, ins_dt, use_yn)
     WHERE (COALESCE(btrim(p_ver_cd), '') = '' OR x.tmpl_cd ILIKE '%' || btrim(p_ver_cd) || '%')
       AND (COALESCE(btrim(p_ver_nm), '') = '' OR x.ver_nm ILIKE '%' || btrim(p_ver_nm) || '%')
     ORDER BY x.tmpl_cd;
$$;

DROP FUNCTION IF EXISTS sp_tbl_tml_ccp_htg_ver_r_000(varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_tml_ccp_htg_ver_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_tmpl_cd: 호환. 목록은 tml_ccp_htg 고정
    p_tmpl_cd varchar,
    -- p_ver_cd: 양식코드 부분검색
    p_ver_cd varchar DEFAULT NULL,
    -- p_ver_nm: 양식명 부분검색
    p_ver_nm varchar DEFAULT NULL
)
RETURNS TABLE(
    idx bigint, tmpl_cd varchar, ver_no int, ver_cd varchar, ver_nm varchar,
    sys_yn varchar, apply_yn varchar, locked_yn varchar, ins_nm varchar, ins_dt varchar, use_yn varchar
) LANGUAGE sql STABLE AS $$
    SELECT x.idx, x.tmpl_cd, x.ver_no, x.ver_cd, x.ver_nm, x.sys_yn, x.apply_yn, x.locked_yn, x.ins_nm, x.ins_dt, x.use_yn
      FROM (
            SELECT NULL::bigint, 'tml_ccp_htg_000'::varchar, 0, 'tml_ccp_htg_000'::varchar,
                   '표준'::varchar, 'sys'::varchar, 'N'::varchar, 'Y'::varchar, ''::varchar, ''::varchar, 'N'::varchar
            UNION ALL
            SELECT v.idx, v.tmpl_cd, v.ver_no,
                   COALESCE(NULLIF(btrim(v.ver_cd), ''), v.tmpl_cd),
                   COALESCE(ct.tmpl_nm_ovr, v.ver_nm),
                   'usr'::varchar, v.apply_yn, 'N'::varchar,
                   COALESCE(u.user_nm, v.ins_id, '')::varchar,
                   COALESCE(to_char(v.ins_dt, 'YYYY-MM-DD'), '')::varchar,
                   CASE WHEN upper(COALESCE(ct.use_yn, 'Y')) = 'N' THEN 'N' ELSE 'Y' END
              FROM tbl_tml_ccp_htg_ver v
              JOIN tbl_company_template ct ON ct.co_cd = v.co_cd AND ct.tmpl_cd = v.tmpl_cd
              LEFT JOIN tbl_user u ON u.co_cd = v.co_cd AND u.user_id = v.ins_id
             WHERE v.co_cd = p_co_cd AND v.use_yn = 'Y'
               AND v.tmpl_cd ~ '^tml_ccp_htg_[0-9]{3}$' AND v.tmpl_cd <> 'tml_ccp_htg_000'
           ) x(idx, tmpl_cd, ver_no, ver_cd, ver_nm, sys_yn, apply_yn, locked_yn, ins_nm, ins_dt, use_yn)
     WHERE (COALESCE(btrim(p_ver_cd), '') = '' OR x.tmpl_cd ILIKE '%' || btrim(p_ver_cd) || '%')
       AND (COALESCE(btrim(p_ver_nm), '') = '' OR x.ver_nm ILIKE '%' || btrim(p_ver_nm) || '%')
     ORDER BY x.tmpl_cd;
$$;

DROP FUNCTION IF EXISTS sp_tbl_tml_ccp_mtl_ver_r_000(varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_tml_ccp_mtl_ver_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_tmpl_cd: 호환. 목록은 tml_ccp_mtl 고정
    p_tmpl_cd varchar,
    -- p_ver_cd: 양식코드 부분검색
    p_ver_cd varchar DEFAULT NULL,
    -- p_ver_nm: 양식명 부분검색
    p_ver_nm varchar DEFAULT NULL
)
RETURNS TABLE(
    idx bigint, tmpl_cd varchar, ver_no int, ver_cd varchar, ver_nm varchar,
    sys_yn varchar, apply_yn varchar, locked_yn varchar, ins_nm varchar, ins_dt varchar, use_yn varchar
) LANGUAGE sql STABLE AS $$
    SELECT x.idx, x.tmpl_cd, x.ver_no, x.ver_cd, x.ver_nm, x.sys_yn, x.apply_yn, x.locked_yn, x.ins_nm, x.ins_dt, x.use_yn
      FROM (
            SELECT NULL::bigint, 'tml_ccp_mtl_000'::varchar, 0, 'tml_ccp_mtl_000'::varchar,
                   '표준'::varchar, 'sys'::varchar, 'N'::varchar, 'Y'::varchar, ''::varchar, ''::varchar, 'N'::varchar
            UNION ALL
            SELECT v.idx, v.tmpl_cd, v.ver_no,
                   COALESCE(NULLIF(btrim(v.ver_cd), ''), v.tmpl_cd),
                   COALESCE(ct.tmpl_nm_ovr, v.ver_nm),
                   'usr'::varchar, v.apply_yn, 'N'::varchar,
                   COALESCE(u.user_nm, v.ins_id, '')::varchar,
                   COALESCE(to_char(v.ins_dt, 'YYYY-MM-DD'), '')::varchar,
                   CASE WHEN upper(COALESCE(ct.use_yn, 'Y')) = 'N' THEN 'N' ELSE 'Y' END
              FROM tbl_tml_ccp_mtl_ver v
              JOIN tbl_company_template ct ON ct.co_cd = v.co_cd AND ct.tmpl_cd = v.tmpl_cd
              LEFT JOIN tbl_user u ON u.co_cd = v.co_cd AND u.user_id = v.ins_id
             WHERE v.co_cd = p_co_cd AND v.use_yn = 'Y'
               AND v.tmpl_cd ~ '^tml_ccp_mtl_[0-9]{3}$' AND v.tmpl_cd <> 'tml_ccp_mtl_000'
           ) x(idx, tmpl_cd, ver_no, ver_cd, ver_nm, sys_yn, apply_yn, locked_yn, ins_nm, ins_dt, use_yn)
     WHERE (COALESCE(btrim(p_ver_cd), '') = '' OR x.tmpl_cd ILIKE '%' || btrim(p_ver_cd) || '%')
       AND (COALESCE(btrim(p_ver_nm), '') = '' OR x.ver_nm ILIKE '%' || btrim(p_ver_nm) || '%')
     ORDER BY x.tmpl_cd;
$$;

-- ------------------------------------------------------------
-- 이름+사용여부 — 버전 use_yn(소프트삭제)은 건드리지 않는다
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_tbl_html_hyg_prc_ver_nm_u_000(varchar, varchar, int, varchar, varchar);
DROP PROCEDURE IF EXISTS sp_tbl_html_hyg_prc_ver_nm_u_000(varchar, varchar, int, varchar, varchar, varchar);
CREATE PROCEDURE sp_tbl_html_hyg_prc_ver_nm_u_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_tmpl_cd: 자사 양식코드. 표준이면 거부
    p_tmpl_cd varchar,
    -- p_ver_no: 회사 순번. 0이면 표준
    p_ver_no int,
    -- p_ver_nm: 바꿀 양식명
    p_ver_nm varchar,
    -- p_use_yn: 회사 양식 사용여부 Y/N. 공통코드 y/n 도 받는다
    p_use_yn varchar,
    -- p_id: 로그인 사용자
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE v_nm varchar; v_use varchar;
BEGIN
    IF COALESCE(p_tmpl_cd, '') IN ('html_hyg_prc_000', 'html_hyg_000', 'html_sys_001') OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 양식명은 수정할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    v_nm := btrim(COALESCE(p_ver_nm, ''));
    IF v_nm = '' THEN RAISE EXCEPTION '양식명은 필수입니다.' USING ERRCODE = '45000'; END IF;
    v_use := CASE WHEN upper(left(btrim(COALESCE(p_use_yn, 'Y')), 1)) = 'N' THEN 'N' ELSE 'Y' END;
    UPDATE tbl_html_hyg_prc_ver SET ver_nm = v_nm, upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
    IF NOT FOUND THEN RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    UPDATE tbl_template SET tmpl_nm = v_nm, upd_id = p_id, upd_dt = now() WHERE tmpl_cd = p_tmpl_cd AND co_cd = p_co_cd;
    UPDATE tbl_company_template
       SET tmpl_nm_ovr = v_nm, use_yn = v_use, upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
END$$;

DROP PROCEDURE IF EXISTS sp_tbl_tml_ccp_chk_ver_nm_u_000(varchar, varchar, int, varchar, varchar);
DROP PROCEDURE IF EXISTS sp_tbl_tml_ccp_chk_ver_nm_u_000(varchar, varchar, int, varchar, varchar, varchar);
CREATE PROCEDURE sp_tbl_tml_ccp_chk_ver_nm_u_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_tmpl_cd: 자사 양식코드. 표준이면 거부
    p_tmpl_cd varchar,
    -- p_ver_no: 회사 순번. 0이면 표준
    p_ver_no int,
    -- p_ver_nm: 바꿀 양식명
    p_ver_nm varchar,
    -- p_use_yn: 회사 양식 사용여부 Y/N
    p_use_yn varchar,
    -- p_id: 로그인 사용자
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE v_nm varchar; v_use varchar;
BEGIN
    IF COALESCE(p_tmpl_cd, '') IN ('tml_ccp_chk_000', 'html_sys_006') OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 양식명은 수정할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    v_nm := btrim(COALESCE(p_ver_nm, ''));
    IF v_nm = '' THEN RAISE EXCEPTION '양식명은 필수입니다.' USING ERRCODE = '45000'; END IF;
    v_use := CASE WHEN upper(left(btrim(COALESCE(p_use_yn, 'Y')), 1)) = 'N' THEN 'N' ELSE 'Y' END;
    UPDATE tbl_tml_ccp_chk_ver SET ver_nm = v_nm, upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
    IF NOT FOUND THEN RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    UPDATE tbl_template SET tmpl_nm = v_nm, upd_id = p_id, upd_dt = now() WHERE tmpl_cd = p_tmpl_cd AND co_cd = p_co_cd;
    UPDATE tbl_company_template
       SET tmpl_nm_ovr = v_nm, use_yn = v_use, upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
END$$;

DROP PROCEDURE IF EXISTS sp_tbl_tml_ccp_pkg_ver_nm_u_000(varchar, varchar, int, varchar, varchar);
DROP PROCEDURE IF EXISTS sp_tbl_tml_ccp_pkg_ver_nm_u_000(varchar, varchar, int, varchar, varchar, varchar);
CREATE PROCEDURE sp_tbl_tml_ccp_pkg_ver_nm_u_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_tmpl_cd: 자사 양식코드. 표준이면 거부
    p_tmpl_cd varchar,
    -- p_ver_no: 회사 순번. 0이면 표준
    p_ver_no int,
    -- p_ver_nm: 바꿀 양식명
    p_ver_nm varchar,
    -- p_use_yn: 회사 양식 사용여부 Y/N
    p_use_yn varchar,
    -- p_id: 로그인 사용자
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE v_nm varchar; v_use varchar;
BEGIN
    IF COALESCE(p_tmpl_cd, '') = 'tml_ccp_pkg_000' OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 양식명은 수정할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    v_nm := btrim(COALESCE(p_ver_nm, ''));
    IF v_nm = '' THEN RAISE EXCEPTION '양식명은 필수입니다.' USING ERRCODE = '45000'; END IF;
    v_use := CASE WHEN upper(left(btrim(COALESCE(p_use_yn, 'Y')), 1)) = 'N' THEN 'N' ELSE 'Y' END;
    UPDATE tbl_tml_ccp_pkg_ver SET ver_nm = v_nm, upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
    IF NOT FOUND THEN RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    UPDATE tbl_template SET tmpl_nm = v_nm, upd_id = p_id, upd_dt = now() WHERE tmpl_cd = p_tmpl_cd AND co_cd = p_co_cd;
    UPDATE tbl_company_template
       SET tmpl_nm_ovr = v_nm, use_yn = v_use, upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
END$$;

DROP PROCEDURE IF EXISTS sp_tbl_tml_ccp_htg_ver_nm_u_000(varchar, varchar, int, varchar, varchar);
DROP PROCEDURE IF EXISTS sp_tbl_tml_ccp_htg_ver_nm_u_000(varchar, varchar, int, varchar, varchar, varchar);
CREATE PROCEDURE sp_tbl_tml_ccp_htg_ver_nm_u_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_tmpl_cd: 자사 양식코드. 표준이면 거부
    p_tmpl_cd varchar,
    -- p_ver_no: 회사 순번. 0이면 표준
    p_ver_no int,
    -- p_ver_nm: 바꿀 양식명
    p_ver_nm varchar,
    -- p_use_yn: 회사 양식 사용여부 Y/N
    p_use_yn varchar,
    -- p_id: 로그인 사용자
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE v_nm varchar; v_use varchar;
BEGIN
    IF COALESCE(p_tmpl_cd, '') = 'tml_ccp_htg_000' OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 양식명은 수정할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    v_nm := btrim(COALESCE(p_ver_nm, ''));
    IF v_nm = '' THEN RAISE EXCEPTION '양식명은 필수입니다.' USING ERRCODE = '45000'; END IF;
    v_use := CASE WHEN upper(left(btrim(COALESCE(p_use_yn, 'Y')), 1)) = 'N' THEN 'N' ELSE 'Y' END;
    UPDATE tbl_tml_ccp_htg_ver SET ver_nm = v_nm, upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
    IF NOT FOUND THEN RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    UPDATE tbl_template SET tmpl_nm = v_nm, upd_id = p_id, upd_dt = now() WHERE tmpl_cd = p_tmpl_cd AND co_cd = p_co_cd;
    UPDATE tbl_company_template
       SET tmpl_nm_ovr = v_nm, use_yn = v_use, upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
END$$;

DROP PROCEDURE IF EXISTS sp_tbl_tml_ccp_mtl_ver_nm_u_000(varchar, varchar, int, varchar, varchar);
DROP PROCEDURE IF EXISTS sp_tbl_tml_ccp_mtl_ver_nm_u_000(varchar, varchar, int, varchar, varchar, varchar);
CREATE PROCEDURE sp_tbl_tml_ccp_mtl_ver_nm_u_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_tmpl_cd: 자사 양식코드. 표준이면 거부
    p_tmpl_cd varchar,
    -- p_ver_no: 회사 순번. 0이면 표준
    p_ver_no int,
    -- p_ver_nm: 바꿀 양식명
    p_ver_nm varchar,
    -- p_use_yn: 회사 양식 사용여부 Y/N
    p_use_yn varchar,
    -- p_id: 로그인 사용자
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE v_nm varchar; v_use varchar;
BEGIN
    IF COALESCE(p_tmpl_cd, '') = 'tml_ccp_mtl_000' OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 양식명은 수정할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    v_nm := btrim(COALESCE(p_ver_nm, ''));
    IF v_nm = '' THEN RAISE EXCEPTION '양식명은 필수입니다.' USING ERRCODE = '45000'; END IF;
    v_use := CASE WHEN upper(left(btrim(COALESCE(p_use_yn, 'Y')), 1)) = 'N' THEN 'N' ELSE 'Y' END;
    UPDATE tbl_tml_ccp_mtl_ver SET ver_nm = v_nm, upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
    IF NOT FOUND THEN RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    UPDATE tbl_template SET tmpl_nm = v_nm, upd_id = p_id, upd_dt = now() WHERE tmpl_cd = p_tmpl_cd AND co_cd = p_co_cd;
    UPDATE tbl_company_template
       SET tmpl_nm_ovr = v_nm, use_yn = v_use, upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
END$$;
