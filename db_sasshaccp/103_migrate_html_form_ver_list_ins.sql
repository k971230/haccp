-- ============================================================
-- 103 — HTML 양식 버전 목록 작성자·작성일시
--
-- 파일번호: 103
-- 이전번호: 102
-- 개발자: 박승우
-- 일자: 2026-08-20
-- 코멘트:
--   1) 목록에 ins_nm·ins_dt를 돌려 좌측 그리드가 작성자·일자를 그린다
--   2) 일시는 YYYY-MM-DD. 표준 가상행은 빈칸
--   3) 102 목록 SP를 교체한다. 102 재실행 금지
--
-- ============================================================

SET search_path TO sasshaccp;

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
    locked_yn varchar,
    ins_nm    varchar,
    ins_dt    varchar
) LANGUAGE sql STABLE AS $$
    SELECT x.idx, x.ver_no, x.ver_cd, x.ver_nm, x.sys_yn, x.apply_yn, x.locked_yn, x.ins_nm, x.ins_dt
      FROM (
            SELECT NULL::bigint AS idx, 0 AS ver_no, '0.1'::varchar AS ver_cd, '표준'::varchar AS ver_nm,
                   'sys'::varchar AS sys_yn,
                   CASE WHEN EXISTS (
                        SELECT 1 FROM tbl_html_form_ver v
                         WHERE v.co_cd = p_co_cd AND v.tmpl_cd = p_tmpl_cd
                           AND v.apply_yn = 'Y' AND v.use_yn = 'Y'
                   ) THEN 'N'::varchar ELSE 'Y'::varchar END AS apply_yn,
                   'Y'::varchar AS locked_yn,
                   ''::varchar AS ins_nm,
                   ''::varchar AS ins_dt
            UNION ALL
            SELECT v.idx, v.ver_no, v.ver_cd, v.ver_nm, 'usr'::varchar, v.apply_yn, 'N'::varchar,
                   COALESCE(u.user_nm, v.ins_id, '')::varchar,
                   COALESCE(to_char(v.ins_dt, 'YYYY-MM-DD'), '')::varchar
              FROM tbl_html_form_ver v
              LEFT JOIN tbl_user u ON u.co_cd = v.co_cd AND u.user_id = v.ins_id
             WHERE v.co_cd = p_co_cd AND v.tmpl_cd = p_tmpl_cd AND v.use_yn = 'Y'
           ) x
     WHERE (COALESCE(btrim(p_ver_cd), '') = '' OR x.ver_cd ILIKE '%' || btrim(p_ver_cd) || '%')
       AND (COALESCE(btrim(p_ver_nm), '') = '' OR x.ver_nm ILIKE '%' || btrim(p_ver_nm) || '%')
     ORDER BY 2;
$$;
