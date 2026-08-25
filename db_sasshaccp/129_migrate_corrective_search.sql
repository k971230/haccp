-- ============================================================
--  129_migrate_corrective_search.sql — 이탈·개선조치 조회 조건 정리
--
--  파일번호: 129
--  이전번호: 128
--  개발자: 박승우
--  일자: 2026-08-25
--  코멘트:
--    1) 이탈로 등록된 문서를 한 표에서 바로 작성하도록 목록에 문서 정보를 붙인다
--       — 양식코드·양식명·문서번호·기준일·작성자. 화면이 그리드 하나로 끝난다
--    2) 검색을 다른 작성 화면과 맞춘다 — 일자 구간·양식·작성자
--       기존 p_status 조건은 뺀다. 상태는 목록 셀에서 바로 고친다
--    3) 반환 컬럼이 늘어 DROP 후 재생성한다
--
--  일자는 이탈 발생일(occur_dt)이 아니라 문서 기준일(base_dt)로 본다.
--  사용자가 「일자」로 찾는 것은 그 일지를 쓴 날이지 이탈을 등록한 날이 아니다.
--
--  실행: psql -f 129_migrate_corrective_search.sql (수동·DBeaver)
-- ============================================================

SET search_path TO sasshaccp;

BEGIN;

DROP FUNCTION IF EXISTS sp_tbl_corrective_action_r_000(varchar, varchar, varchar, varchar);

CREATE FUNCTION sp_tbl_corrective_action_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_from_dt: 문서 기준일 시작 YYYYMMDD. 공백이면 전체
    p_from_dt varchar,
    -- p_to_dt: 문서 기준일 종료 YYYYMMDD. 공백이면 전체
    p_to_dt varchar,
    -- p_tmpl_cd: 양식코드. 공백이면 전체
    p_tmpl_cd varchar,
    -- p_writer: 작성자 ID·이름 부분검색. 공백이면 전체
    p_writer varchar
)
RETURNS TABLE(
    idx bigint,
    ca_no varchar,
    occur_dt varchar,
    occur_place varchar,
    deviation_desc text,
    action_desc text,
    action_user_id varchar,
    action_user_nm varchar,
    action_dt varchar,
    confirm_user_nm varchar,
    due_dt varchar,
    status varchar,
    src_doc_idx bigint,
    src_doc_no varchar,
    src_tmpl_cd varchar,
    tmpl_nm varchar,
    base_dt varchar,
    doc_status varchar,
    writer_id varchar,
    writer_nm varchar
)
LANGUAGE sql STABLE AS $$
    SELECT ca.idx,
           ca.ca_no,
           ca.occur_dt,
           ca.occur_place,
           ca.deviation_desc,
           ca.action_desc,
           ca.action_user_id,
           ca.action_user_nm,
           ca.action_dt,
           ca.confirm_user_nm,
           ca.due_dt,
           ca.status,
           ca.src_doc_idx,
           d.doc_no,
           COALESCE(ca.src_tmpl_cd, d.tmpl_cd) AS src_tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm, d.tmpl_cd) AS tmpl_nm,
           d.base_dt,
           d.status AS doc_status,
           d.writer_id,
           u.user_nm AS writer_nm
      FROM tbl_corrective_action ca
      LEFT JOIN tbl_document d
             ON d.co_cd = ca.co_cd AND d.idx = ca.src_doc_idx AND d.del_yn = 'N'
      LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = d.co_cd AND ct.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_user u ON u.co_cd = d.co_cd AND u.user_id = d.writer_id
     WHERE ca.co_cd = p_co_cd
       -- 일자는 문서 기준일 기준. 원문서가 지워진 이탈 행은 발생일로 대신 본다
       AND (COALESCE(p_from_dt, '') = '' OR COALESCE(d.base_dt, ca.occur_dt) >= p_from_dt)
       AND (COALESCE(p_to_dt, '')   = '' OR COALESCE(d.base_dt, ca.occur_dt) <= p_to_dt)
       AND (COALESCE(p_tmpl_cd, '') = '' OR COALESCE(ca.src_tmpl_cd, d.tmpl_cd) = p_tmpl_cd)
       AND (
           COALESCE(p_writer, '') = ''
           OR COALESCE(d.writer_id, '') ILIKE '%' || p_writer || '%'
           OR COALESCE(u.user_nm, '')   ILIKE '%' || p_writer || '%'
       )
     ORDER BY COALESCE(d.base_dt, ca.occur_dt) DESC, ca.idx DESC;
$$;
COMMENT ON FUNCTION sp_tbl_corrective_action_r_000(varchar, varchar, varchar, varchar, varchar) IS
  '이탈·개선조치 목록 — 이탈로 등록된 문서를 문서 정보와 함께. 검색은 일자·양식·작성자';

COMMIT;

-- 확인용
-- SELECT * FROM sp_tbl_corrective_action_r_000('<co_cd>', '', '', '', '');
