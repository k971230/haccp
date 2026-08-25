-- ============================================================
--  131_migrate_today_task_doc_page.sql — 오늘 할 일 최근 문서 페이지
--
--  파일번호: 131
--  이전번호: 130
--  개발자: 박승우
--  일자: 2026-08-25
--  코멘트:
--    1) 오늘 할 일 최근 문서를 OFFSET/LIMIT 으로 자른다 — 달 전체·상한 slice 를 쓰지 않는다
--    2) 필터는 문서함(sp_tbl_document_r_000)과 같고 양식·상태·검색은 비운다. 기간만 받는다
--    3) COUNT(*) OVER() 로 총건수를 각 행에 붙여 20건만 받아도 KPI·페이저가 전체 건수를 안다
--
--  실행: psql -f 131_migrate_today_task_doc_page.sql (수동·DBeaver)
-- ============================================================

SET search_path TO sasshaccp;

BEGIN;

DROP FUNCTION IF EXISTS sp_tbl_today_task_doc_r_000(varchar, varchar, varchar, integer, integer);

CREATE FUNCTION sp_tbl_today_task_doc_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_from_dt: 기준일 시작 YYYYMMDD. 공백이면 하한 없음
    p_from_dt varchar,
    -- p_to_dt: 기준일 종료 YYYYMMDD. 공백이면 상한 없음
    p_to_dt varchar,
    -- p_offset: 건너뛸 행 수. 음수·NULL 이면 0
    p_offset integer,
    -- p_limit: 가져올 행 수. 1 미만·NULL 이면 1
    p_limit integer
)
RETURNS TABLE (
    doc_idx bigint,
    co_cd varchar,
    tmpl_cd varchar,
    tmpl_nm varchar,
    doc_kind varchar,
    doc_no varchar,
    base_dt varchar,
    title varchar,
    status varchar,
    appr_line_cd varchar,
    writer_id varchar,
    writer_nm varchar,
    write_dt timestamp,
    ver_no int,
    retention_until varchar,
    file_cnt int,
    open_ca_cnt int,
    -- 기간 조건 전체 건수 — LIMIT 앞. KPI·페이저용
    total_cnt int
)
LANGUAGE sql STABLE AS $$
    SELECT d.idx,
           d.co_cd,
           d.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm, d.tmpl_cd),
           d.doc_kind,
           d.doc_no,
           d.base_dt,
           d.title,
           d.status,
           d.appr_line_cd,
           d.writer_id,
           u.user_nm,
           d.write_dt,
           d.ver_no,
           d.retention_until,
           (SELECT count(*)::int
              FROM tbl_document_file f
             WHERE f.co_cd = d.co_cd AND f.doc_idx = d.idx),
           (SELECT count(*)::int
              FROM tbl_corrective_action ca
             WHERE ca.co_cd = d.co_cd
               AND ca.src_doc_idx = d.idx
               AND ca.status <> 'DONE'),
           COUNT(*) OVER()::int
      FROM tbl_document d
      LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_company_template ct
        ON ct.co_cd = d.co_cd AND ct.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_user u ON u.co_cd = d.co_cd AND u.user_id = d.writer_id
     WHERE d.co_cd = p_co_cd
       AND d.del_yn = 'N'
       AND (COALESCE(p_from_dt, '') = '' OR d.base_dt >= p_from_dt)
       AND (COALESCE(p_to_dt, '') = '' OR d.base_dt <= p_to_dt)
     ORDER BY d.base_dt DESC, d.idx DESC
     OFFSET GREATEST(COALESCE(p_offset, 0), 0)
     LIMIT GREATEST(COALESCE(p_limit, 1), 1);
$$;

COMMENT ON FUNCTION sp_tbl_today_task_doc_r_000(varchar, varchar, varchar, integer, integer) IS
    '오늘 할 일 최근 문서 — 기간 필터 + OFFSET/LIMIT + 총건수';

COMMIT;
