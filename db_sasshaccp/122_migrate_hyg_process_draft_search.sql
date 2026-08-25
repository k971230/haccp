-- ============================================================
-- 122 — 위생공정 양식 작성 검색조건 확장 (양식명·작성자ID·작성자명)
--
-- 파일번호: 122
-- 이전번호: 121
-- 개발자: 박승우
-- 일자: 2026-08-24
-- 코멘트:
--   1) 작성 화면 상단 검색이 일자·양식코드·양식명·작성자ID·작성자명·결재여부 6개로 확정됐다.
--      121 의 sp_tbl_hyg_process_r_000 뒤에 p_tmpl_nm·p_writer_id·p_writer_nm 3개를 더한다
--   2) 앞 6개 인자 순서·의미는 121 과 같다. 기존 hygiene-process-check 는 새 3개에 빈값을 넘겨 동작이 그대로다
--   3) 결재여부는 DOC_STATUS 파생 3단계라 SP 인자로 두지 않는다. 화면이 묶어서 거른다
--
-- 121 을 먼저 적용해야 한다. 122 는 목록 SP 하나만 교체한다
-- Jenkins는 migrate를 안 돌린다. DBeaver/수동
-- ============================================================

SET search_path TO sasshaccp;

BEGIN;

-- 121 의 6인자 정의를 걷어내고 9인자로 다시 만든다
DROP FUNCTION IF EXISTS sp_tbl_hyg_process_r_000(varchar, varchar, varchar, varchar, varchar, varchar);
DROP FUNCTION IF EXISTS sp_tbl_hyg_process_r_000(varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_hyg_process_r_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위
    p_co_cd     varchar,
    -- p_tmpl_cd: 양식코드 부분검색. 빈값이면 공정점검 계열 전체(html_sys_001 + html_hyg_prc_NNN)
    p_tmpl_cd   varchar,
    -- p_from_dt: 일자 시작 YYYYMMDD. 빈값이면 하한 없음
    p_from_dt   varchar,
    -- p_to_dt: 일자 종료 YYYYMMDD. 빈값이면 상한 없음
    p_to_dt     varchar,
    -- p_doc_no: 문서번호 부분검색. 빈값이면 전체 (hygiene-process-check 호환)
    p_doc_no    varchar,
    -- p_writer: 작성자ID·작성자명·점검자명 통합 부분검색 (hygiene-process-check 호환). 빈값이면 전체
    p_writer    varchar,
    -- p_tmpl_nm: 양식명 부분검색. 빈값이면 전체
    p_tmpl_nm   varchar DEFAULT NULL,
    -- p_writer_id: 작성자 ID 부분검색. 빈값이면 전체
    p_writer_id varchar DEFAULT NULL,
    -- p_writer_nm: 작성자명 부분검색. 빈값이면 전체
    p_writer_nm varchar DEFAULT NULL
)
RETURNS TABLE(
    doc_idx    bigint,
    hdr_idx    bigint,
    -- 양식코드 — 좌측 그리드 팝업 버튼. 이 값으로 우측 지면을 연다
    tmpl_cd    varchar,
    -- 양식명 — 자사 양식명(tmpl_nm_ovr) 우선
    tmpl_nm    varchar,
    doc_no     varchar,
    base_dt    varchar,
    checker_nm varchar,
    -- 작성자 ID — tbl_document.writer_id. 전송·전송취소 권한 판정에 쓴다
    writer_id  varchar,
    -- 작성자명 — tbl_user.user_nm. 없으면 ID
    writer_nm  varchar,
    status     varchar,
    row_cnt    int,
    ng_cnt     int
) LANGUAGE sql STABLE AS $$
    SELECT d.idx, h.idx,
           d.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm)::varchar,
           d.doc_no, d.base_dt, h.checker_nm,
           d.writer_id,
           COALESCE(u.user_nm, d.writer_id, '')::varchar,
           d.status,
           (SELECT count(*)::int FROM tbl_hyg_process_item i WHERE i.hdr_idx = h.idx AND i.co_cd = h.co_cd),
           (SELECT count(*)::int FROM tbl_hyg_process_item i WHERE i.hdr_idx = h.idx AND i.co_cd = h.co_cd AND i.yn = 'N')
      FROM tbl_document d
      JOIN tbl_hyg_process h ON h.doc_idx = d.idx AND h.co_cd = d.co_cd
      LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = d.co_cd AND ct.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_user u ON u.co_cd = d.co_cd AND u.user_id = d.writer_id
     WHERE d.co_cd = p_co_cd AND d.del_yn = 'N'
       -- 양식코드가 비었을 때(= 전체) 공정점검 계열만, 값이 있으면 그 코드 부분검색
       AND (
            CASE WHEN COALESCE(NULLIF(btrim(p_tmpl_cd), ''), '') = ''
                 THEN d.tmpl_cd = 'html_sys_001' OR d.tmpl_cd ~ '^html_hyg_prc_[0-9]{3}$'
                 ELSE d.tmpl_cd ILIKE '%' || btrim(p_tmpl_cd) || '%'
            END
           )
       -- 양식명 부분검색 — 자사 양식명 우선값 기준
       AND (
            COALESCE(NULLIF(btrim(p_tmpl_nm), ''), '') = ''
            OR COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm, '') ILIKE '%' || btrim(p_tmpl_nm) || '%'
           )
       AND (COALESCE(NULLIF(btrim(p_from_dt), ''), '') = '' OR d.base_dt >= btrim(p_from_dt))
       AND (COALESCE(NULLIF(btrim(p_to_dt), ''), '') = '' OR d.base_dt <= btrim(p_to_dt))
       AND d.doc_no LIKE '%' || COALESCE(p_doc_no, '') || '%'
       -- 작성자 ID 단독 검색 — 신규 화면 상단 검색
       AND (
            COALESCE(NULLIF(btrim(p_writer_id), ''), '') = ''
            OR COALESCE(d.writer_id, '') ILIKE '%' || btrim(p_writer_id) || '%'
           )
       -- 작성자명 단독 검색 — 신규 화면 상단 검색
       AND (
            COALESCE(NULLIF(btrim(p_writer_nm), ''), '') = ''
            OR COALESCE(u.user_nm, '') ILIKE '%' || btrim(p_writer_nm) || '%'
           )
       -- 통합 작성자 검색 — hygiene-process-check 호환. 신규 화면은 빈값을 넘긴다
       AND (
            COALESCE(NULLIF(btrim(p_writer), ''), '') = ''
            OR d.writer_id LIKE '%' || btrim(p_writer) || '%'
            OR COALESCE(u.user_nm, '') LIKE '%' || btrim(p_writer) || '%'
            OR COALESCE(h.checker_nm, '') LIKE '%' || btrim(p_writer) || '%'
           )
     ORDER BY d.base_dt DESC, d.doc_no DESC;
$$;
COMMENT ON FUNCTION sp_tbl_hyg_process_r_000(varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar) IS
  '공정점검 작성 목록 — 121 6인자 + 양식명·작성자ID·작성자명. 결재여부는 화면이 DOC_STATUS 로 묶어 거른다';

COMMIT;

-- ------------------------------------------------------------
-- 검증
-- ------------------------------------------------------------
-- SELECT * FROM sp_tbl_hyg_process_r_000('{회사코드}', '', '', '', '', '', '', '', '');
-- SELECT * FROM sp_tbl_hyg_process_r_000('{회사코드}', 'html_hyg_prc', '공정', '', '', '', '', 'admin', '');
