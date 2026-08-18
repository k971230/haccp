-- ============================================================
-- 86 — 문서주기관리 좌측 목록에 사용여부 검색·표시
--
-- 파일번호: 86
-- 이전번호: 85
-- 개발자: 박승우
-- 일자: 2026-08-14
-- 코멘트:
--   1) 화면 검색 사용여부(기본 Y, 빈값=전체)를 SP 4번째 인자로 받는다
--   2) 목록 결과에 use_yn 을 내려 그리드 사용여부 열을 그린다
--   3) 재실행 안전 — 3인자·4인자 FUNCTION 모두 DROP 후 4인자 CREATE
--
-- 선행: 85(문서주기관리) 적용 완료
-- ============================================================

SET search_path TO sasshaccp;

DROP FUNCTION IF EXISTS sp_schedule_cycle_management_form_r_000(varchar, varchar, varchar);
DROP FUNCTION IF EXISTS sp_schedule_cycle_management_form_r_000(varchar, varchar, varchar, varchar);

CREATE FUNCTION sp_schedule_cycle_management_form_r_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위. 필수 등가 조건
    p_co_cd   varchar,
    -- p_tmpl_cd: 헤더 양식코드 검색어. 공백이면 전체
    p_tmpl_cd varchar,
    -- p_tmpl_nm: 헤더 양식명 검색어. 공백이면 전체
    p_tmpl_nm varchar,
    -- p_use_yn: 사용여부 Y/N. 공백이면 전체
    p_use_yn  varchar
)
RETURNS TABLE(
    tmpl_cd  varchar,
    tmpl_nm  varchar,
    -- 구분 — sys:시스템양식, usr:자사양식
    sys_yn   varchar,
    doc_kind varchar,
    -- 등록된 주기 코드 — 미등록이면 NULL
    cycle_cd varchar,
    -- 주기 등록 여부 Y/N — 삭제 버튼 활성 판정
    rule_yn  varchar,
    -- 양식 사용여부 Y/N — 화면 검색·목록 열
    use_yn   varchar
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
      -- 양식당 주기 1건이므로 LEFT JOIN 이 행을 늘리지 않는다
      LEFT JOIN tbl_schedule_rule r ON r.co_cd = ct.co_cd AND r.tmpl_cd = ct.tmpl_cd
     WHERE ct.co_cd = p_co_cd
       -- 사용여부 공백일 때(= 전체) 필터 생략, Y/N 이면 등가
       AND (
            COALESCE(NULLIF(btrim(p_use_yn), ''), '') = ''
            OR upper(COALESCE(ct.use_yn, 'N')) = upper(btrim(p_use_yn))
           )
       AND ct.tmpl_cd LIKE CONCAT('%', COALESCE(p_tmpl_cd, ''), '%')
       AND COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm) LIKE CONCAT('%', COALESCE(p_tmpl_nm, ''), '%')
     ORDER BY t.sort_no, ct.tmpl_cd;
$$;

COMMENT ON FUNCTION sp_schedule_cycle_management_form_r_000(varchar, varchar, varchar, varchar) IS
  '문서주기관리 좌측 양식 목록 — 사용여부 검색 + 구분 + 주기 등록여부(조회 전용)';
