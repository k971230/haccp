-- ============================================================
-- 61_migrate_dept_h_dept_nm.sql
-- 부서 조회 — 상위부서명 self LEFT JOIN (h_dept_nm)
--
-- 개발자: 박승우
-- 일자: 2026-08-12
-- 코멘트:
--   1) sp_tbl_dept_r_000에 상위부서명 컬럼을 추가한다
--   2) FE 부서관리 그리드는 코드 숨김·명+룩업 박스에 쓴다
--   3) 기존 RETURNS 시그니처가 바뀌므로 CREATE OR REPLACE로 교체한다
-- ============================================================
SET search_path TO sasshaccp, public;

-- RETURNS에 h_dept_nm 추가 — OUT 시그니처 변경이라 DROP 후 재생성
DROP FUNCTION IF EXISTS sp_tbl_dept_r_000(varchar, varchar, varchar);

CREATE OR REPLACE FUNCTION sp_tbl_dept_r_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위
    p_co_cd  varchar,
    -- p_dept_nm: 부서명 부분검색어
    p_dept_nm varchar,
    -- p_use_yn: 사용여부 필터. 공백이면 전체
    p_use_yn varchar
)
RETURNS TABLE(
    idx       bigint,
    co_cd     varchar,
    dept_cd   varchar,
    dept_nm   varchar,
    h_dept_cd varchar,
    -- 상위부서명 — self LEFT JOIN (그리드 표시용)
    h_dept_nm varchar,
    sort_no   int,
    use_yn    varchar
) LANGUAGE sql AS $$
    SELECT d.idx, d.co_cd, d.dept_cd, d.dept_nm, d.h_dept_cd,
           p.dept_nm AS h_dept_nm,
           d.sort_no, d.use_yn
      FROM tbl_dept d
      LEFT JOIN tbl_dept p
        ON p.co_cd = d.co_cd
       AND p.dept_cd = d.h_dept_cd
     WHERE d.co_cd = p_co_cd
       AND d.dept_nm LIKE CONCAT('%', COALESCE(p_dept_nm, ''), '%')
       AND d.use_yn  LIKE CONCAT('%', COALESCE(p_use_yn,  ''), '%')
     ORDER BY CASE WHEN COALESCE(d.h_dept_cd, '') = '' THEN 0 ELSE 1 END, d.sort_no, d.dept_cd;
$$;
COMMENT ON FUNCTION sp_tbl_dept_r_000(varchar, varchar, varchar) IS '부서 조회 — 상위부서명(self JOIN)·트리 정렬';
