-- ============================================================
-- 90 — 양식 파일 이력 현재적용·기본양식 문구를 SP CASE로 내린다
--
-- 파일번호: 90
-- 이전번호: 89
-- 개발자: 박승우
-- 일자: 2026-08-18
-- 코멘트:
--   1) 불러오기 그리드 현재적용·기본양식은 FE codeMap이 아니라 조회 SP가 문구를 만든다
--   2) 적용 판정(current_file_idx·default_file_idx)은 그대로다. 목록 표시만 바꾼다
--   3) 컬럼명 current_yn·default_yn 은 유지한다. 값만 '현재적용'/'기본양식'/빈 문자열이다
--
-- Jenkins는 migrate를 안 돌리므로 적용은 DBeaver/수동
-- ============================================================

SET search_path TO sasshaccp;

DROP FUNCTION IF EXISTS sp_hwp_template_management_file_r_000(varchar, varchar);

CREATE FUNCTION sp_hwp_template_management_file_r_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위
    p_co_cd   varchar,
    -- p_tmpl_cd: 선택한 양식코드
    p_tmpl_cd varchar
)
RETURNS TABLE(
    idx        bigint,
    file_seq   int,
    file_nm    varchar,
    file_size  bigint,
    -- 출처 — sys:기본 제공본, usr:회사 업로드본
    src_ty     varchar,
    -- 현재 적용 문구 — 지금 쓰는 파일이면 '현재적용', 아니면 빈 문자열
    current_yn varchar,
    -- 기본 제공 문구 — 초기화 대상이면 '기본양식', 아니면 빈 문자열
    default_yn varchar,
    ins_id     varchar,
    ins_dt     timestamp
) LANGUAGE sql STABLE AS $$
    SELECT f.idx, f.file_seq, f.file_nm, f.file_size, f.src_ty,
           -- 현재 적용 파일일 때(= current_file_idx 일치) 그리드 문구
           CASE WHEN f.idx = ct.current_file_idx THEN '현재적용' ELSE '' END,
           -- 기본 제공 파일일 때(= default_file_idx 일치) 그리드 문구
           CASE WHEN f.idx = ct.default_file_idx THEN '기본양식' ELSE '' END,
           f.ins_id, f.ins_dt
      FROM tbl_company_template_file f
      JOIN tbl_company_template ct ON ct.co_cd = f.co_cd AND ct.tmpl_cd = f.tmpl_cd
     WHERE f.co_cd = p_co_cd AND f.tmpl_cd = p_tmpl_cd AND f.del_yn = 'N'
     ORDER BY f.file_seq DESC;
$$;
COMMENT ON FUNCTION sp_hwp_template_management_file_r_000(varchar, varchar) IS
  '양식 파일 이력 — 최근 업로드 우선. 현재적용·기본양식 문구는 CASE';
