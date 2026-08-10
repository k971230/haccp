-- ============================================================
-- 마이그레이션 — DB형 문서 목록 검색 통일 (문서번호·작성자)
--
-- 개발자: 박승우
-- 일자: 2026-08-06
-- 코멘트:
--   1) Cold·CCP Form·위생·BizOps·문서함 목록 SP에 문서번호·작성자 부분검색을 동일 계약으로 넣는다
--   2) 작성자는 writer_id·user_nm ILIKE, 문서번호는 doc_no ILIKE
--   3) 파라미터 개수가 늘어난 함수는 DROP 후 재생성한다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 문서함 — 작성자 필터를 ID·이름 부분검색으로 완화 (시그니처 동일)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_document_r_000(
    p_co_cd varchar,
    p_from_dt varchar,
    p_to_dt varchar,
    p_tmpl_cd varchar,
    p_status varchar,
    p_keyword varchar,
    p_writer_id varchar
)
RETURNS TABLE (
    doc_idx bigint, co_cd varchar, tmpl_cd varchar, tmpl_nm varchar, doc_kind varchar,
    doc_no varchar, base_dt varchar, title varchar, status varchar, appr_line_cd varchar,
    writer_id varchar, writer_nm varchar, write_dt timestamp, ver_no int, retention_until varchar,
    file_cnt int, open_ca_cnt int
)
LANGUAGE sql STABLE AS $$
    SELECT d.idx, d.co_cd, d.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm, d.tmpl_cd),
           d.doc_kind, d.doc_no, d.base_dt, d.title, d.status, d.appr_line_cd,
           d.writer_id, u.user_nm, d.write_dt, d.ver_no, d.retention_until,
           (SELECT count(*)::int FROM tbl_document_file f WHERE f.co_cd = d.co_cd AND f.doc_idx = d.idx),
           (SELECT count(*)::int FROM tbl_corrective_action ca
             WHERE ca.co_cd = d.co_cd AND ca.src_doc_idx = d.idx AND ca.status <> 'DONE')
      FROM tbl_document d
      LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = d.co_cd AND ct.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_user u ON u.co_cd = d.co_cd AND u.user_id = d.writer_id
     WHERE d.co_cd = p_co_cd
       AND d.del_yn = 'N'
       AND (COALESCE(p_from_dt, '') = '' OR d.base_dt >= p_from_dt)
       AND (COALESCE(p_to_dt, '') = '' OR d.base_dt <= p_to_dt)
       AND (COALESCE(p_tmpl_cd, '') = '' OR d.tmpl_cd = p_tmpl_cd)
       AND (COALESCE(p_status, '') = '' OR d.status = p_status)
       AND (
           COALESCE(p_writer_id, '') = ''
           OR d.writer_id ILIKE '%' || p_writer_id || '%'
           OR COALESCE(u.user_nm, '') ILIKE '%' || p_writer_id || '%'
       )
       AND (
           COALESCE(p_keyword, '') = ''
           OR d.doc_no ILIKE '%' || p_keyword || '%'
           OR COALESCE(d.title, '') ILIKE '%' || p_keyword || '%'
       )
     ORDER BY d.base_dt DESC, d.idx DESC;
$$;

-- ------------------------------------------------------------
-- CCP 냉장 — p_doc_no, p_writer 추가
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_ccp_cold_monitor_r_000(varchar, varchar, varchar, varchar);

CREATE OR REPLACE FUNCTION sp_tbl_ccp_cold_monitor_r_000(
    p_co_cd   varchar,
    p_from_dt varchar,
    p_to_dt   varchar,
    p_ccp_cd  varchar,
    -- p_doc_no: 문서번호 부분검색. 공백이면 전체
    p_doc_no  varchar DEFAULT '',
    -- p_writer: 작성자 ID·이름 부분검색. 공백이면 전체
    p_writer  varchar DEFAULT ''
)
RETURNS TABLE (
    doc_idx     bigint,
    hdr_idx     bigint,
    co_cd       varchar,
    doc_no      varchar,
    base_dt     varchar,
    ccp_cd      varchar,
    title       varchar,
    status      varchar,
    mng_user_id varchar,
    mng_nm      varchar,
    writer_id   varchar,
    write_dt    timestamp,
    row_cnt     int,
    ng_cnt      int
)
LANGUAGE sql STABLE AS $$
    SELECT d.idx, h.idx, d.co_cd, d.doc_no, h.base_dt, h.ccp_cd, d.title, d.status,
           h.mng_user_id, h.mng_nm, d.writer_id, d.write_dt,
           (SELECT COUNT(*)::int FROM tbl_ccp_cold_monitor_row r
             WHERE r.hdr_idx = h.idx AND r.co_cd = h.co_cd),
           (SELECT COUNT(*)::int FROM tbl_ccp_cold_monitor_row r
             WHERE r.hdr_idx = h.idx AND r.co_cd = h.co_cd AND r.judge_cd = 'F')
      FROM tbl_ccp_cold_monitor h
      JOIN tbl_document d ON d.idx = h.doc_idx AND d.co_cd = h.co_cd
      LEFT JOIN tbl_user u ON u.co_cd = d.co_cd AND u.user_id = d.writer_id
     WHERE h.co_cd = p_co_cd
       AND d.del_yn = 'N'
       AND d.tmpl_cd = 'CCP_COLD'
       AND (COALESCE(p_from_dt, '') = '' OR h.base_dt >= p_from_dt)
       AND (COALESCE(p_to_dt, '') = '' OR h.base_dt <= p_to_dt)
       AND (COALESCE(p_ccp_cd, '') = '' OR h.ccp_cd = p_ccp_cd)
       AND (COALESCE(p_doc_no, '') = '' OR d.doc_no ILIKE '%' || p_doc_no || '%')
       AND (
           COALESCE(p_writer, '') = ''
           OR d.writer_id ILIKE '%' || p_writer || '%'
           OR COALESCE(u.user_nm, '') ILIKE '%' || p_writer || '%'
       )
     ORDER BY h.base_dt DESC, d.doc_no DESC;
$$;
COMMENT ON FUNCTION sp_tbl_ccp_cold_monitor_r_000(varchar, varchar, varchar, varchar, varchar, varchar) IS
  'CCP 냉장보관 일지 목록 — 기간·CCP·문서번호·작성자';

-- ------------------------------------------------------------
-- CCP Form 공통 목록
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_ccp_form_list_r_000(varchar, varchar, varchar, varchar);

CREATE OR REPLACE FUNCTION sp_tbl_ccp_form_list_r_000(
    p_co_cd varchar,
    p_tmpl_cd varchar,
    p_from_dt varchar,
    p_to_dt varchar,
    p_doc_no varchar DEFAULT '',
    p_writer varchar DEFAULT ''
)
RETURNS TABLE (
    doc_idx bigint, hdr_idx bigint, doc_no varchar, base_dt varchar, title varchar,
    status varchar, row_cnt int, ng_cnt int
)
LANGUAGE sql STABLE AS $$
    SELECT d.idx,
           CASE p_tmpl_cd
             WHEN 'CCP_METAL' THEN m.idx
             WHEN 'CCP_VERIFY' THEN v.idx
             ELSE p.idx
           END,
           d.doc_no,
           CASE p_tmpl_cd
             WHEN 'CCP_METAL' THEN m.base_dt
             WHEN 'CCP_VERIFY' THEN v.base_dt
             ELSE p.plan_year || '0101'
           END,
           d.title, d.status,
           CASE p_tmpl_cd
             WHEN 'CCP_METAL' THEN (SELECT count(*)::int FROM tbl_ccp_metal_sens_row r WHERE r.co_cd = p_co_cd AND r.hdr_idx = m.idx)
             WHEN 'CCP_VERIFY' THEN (SELECT count(*)::int FROM tbl_ccp_verify_item i WHERE i.co_cd = p_co_cd AND i.hdr_idx = v.idx)
             ELSE (SELECT count(*)::int FROM tbl_verify_plan_item i WHERE i.co_cd = p_co_cd AND i.hdr_idx = p.idx)
           END,
           CASE p_tmpl_cd
             WHEN 'CCP_METAL' THEN (SELECT count(*)::int FROM tbl_ccp_metal_sens_row r WHERE r.co_cd = p_co_cd AND r.hdr_idx = m.idx AND r.judge_cd = 'F')
             WHEN 'CCP_VERIFY' THEN (SELECT count(*)::int FROM tbl_ccp_verify_item i WHERE i.co_cd = p_co_cd AND i.hdr_idx = v.idx AND i.answer_cd = 'N')
             ELSE 0
           END
      FROM tbl_document d
      LEFT JOIN tbl_ccp_metal_monitor m ON m.doc_idx = d.idx AND m.co_cd = d.co_cd AND p_tmpl_cd = 'CCP_METAL'
      LEFT JOIN tbl_ccp_verify_check v ON v.doc_idx = d.idx AND v.co_cd = d.co_cd AND p_tmpl_cd = 'CCP_VERIFY'
      LEFT JOIN tbl_verify_plan p ON p.doc_idx = d.idx AND p.co_cd = d.co_cd AND p_tmpl_cd = 'VERIFY_PLAN'
      LEFT JOIN tbl_user u ON u.co_cd = d.co_cd AND u.user_id = d.writer_id
     WHERE d.co_cd = p_co_cd
       AND d.tmpl_cd = p_tmpl_cd
       AND d.del_yn = 'N'
       AND (COALESCE(p_from_dt, '') = '' OR d.base_dt >= p_from_dt)
       AND (COALESCE(p_to_dt, '') = '' OR d.base_dt <= p_to_dt)
       AND (COALESCE(p_doc_no, '') = '' OR d.doc_no ILIKE '%' || p_doc_no || '%')
       AND (
           COALESCE(p_writer, '') = ''
           OR d.writer_id ILIKE '%' || p_writer || '%'
           OR COALESCE(u.user_nm, '') ILIKE '%' || p_writer || '%'
       )
     ORDER BY d.base_dt DESC, d.doc_no DESC;
$$;
COMMENT ON FUNCTION sp_tbl_ccp_form_list_r_000(varchar, varchar, varchar, varchar, varchar, varchar) IS
  'CCP DB형 양식 공통 목록 — 기간·문서번호·작성자';

-- ------------------------------------------------------------
-- 위생 목록
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_hygiene_document_r_000(varchar, varchar, varchar, varchar);

CREATE OR REPLACE FUNCTION sp_tbl_hygiene_document_r_000(
    p_co_cd varchar,
    p_tmpl_cd varchar,
    p_from_dt varchar,
    p_to_dt varchar,
    p_doc_no varchar DEFAULT '',
    p_writer varchar DEFAULT ''
) RETURNS TABLE(doc_idx bigint, hdr_idx bigint, doc_no varchar, base_dt varchar, base_dt_to varchar,
                checker_nm varchar, status varchar, row_cnt int, ng_cnt int)
LANGUAGE sql STABLE AS $$
    SELECT d.idx, x.hdr_idx, d.doc_no, x.base_dt, x.base_dt_to, x.checker_nm, d.status,
           x.row_cnt, x.ng_cnt
      FROM tbl_document d
      LEFT JOIN tbl_user u ON u.co_cd = d.co_cd AND u.user_id = d.writer_id
      JOIN LATERAL (
          SELECT h.idx hdr_idx, h.base_dt, NULL::varchar base_dt_to, h.checker_nm,
                 (SELECT count(*)::int FROM tbl_daily_hygiene_item i WHERE i.hdr_idx=h.idx AND i.co_cd=h.co_cd) row_cnt,
                 (SELECT count(*)::int FROM tbl_daily_hygiene_item i WHERE i.hdr_idx=h.idx AND i.co_cd=h.co_cd AND i.judge_cd='X') ng_cnt
            FROM tbl_daily_hygiene h WHERE p_tmpl_cd='DAILY_HYG' AND h.doc_idx=d.idx AND h.co_cd=d.co_cd
          UNION ALL
          SELECT h.idx, h.base_dt, NULL, h.checker_nm,
                 (SELECT count(*)::int FROM tbl_personal_hygiene_row r WHERE r.hdr_idx=h.idx AND r.co_cd=h.co_cd),
                 (SELECT count(*)::int FROM tbl_personal_hygiene_row r WHERE r.hdr_idx=h.idx AND r.co_cd=h.co_cd
                   AND 'X' IN (r.health_cd,r.cloth_cd,r.belongings_cd,r.worker_state_cd,r.anteroom_cd,r.handwash_cd))
            FROM tbl_personal_hygiene h WHERE p_tmpl_cd='PERSONAL_HYG' AND h.doc_idx=d.idx AND h.co_cd=d.co_cd
          UNION ALL
          SELECT h.idx, h.base_dt, h.base_dt_to, h.checker_nm,
                 (SELECT count(*)::int FROM tbl_area_hygiene_item i WHERE i.hdr_idx=h.idx AND i.co_cd=h.co_cd),
                 (SELECT count(*)::int FROM tbl_area_hygiene_result r JOIN tbl_area_hygiene_item i ON i.idx=r.item_idx AND i.co_cd=r.co_cd WHERE i.hdr_idx=h.idx AND r.co_cd=h.co_cd AND r.judge_cd='X')
            FROM tbl_area_hygiene h WHERE p_tmpl_cd='AREA_HYG' AND h.doc_idx=d.idx AND h.co_cd=d.co_cd
          UNION ALL
          SELECT h.idx, h.base_dt, NULL, h.checker_nm,
                 (SELECT count(*)::int FROM tbl_pest_check_row r WHERE r.hdr_idx=h.idx AND r.co_cd=h.co_cd),
                 (SELECT count(*)::int FROM tbl_pest_check_row r WHERE r.hdr_idx=h.idx AND r.co_cd=h.co_cd AND (r.device_ng_cd='X' OR r.rat_sum>0))
            FROM tbl_pest_check h WHERE p_tmpl_cd='PEST' AND h.doc_idx=d.idx AND h.co_cd=d.co_cd
          UNION ALL
          SELECT h.idx, h.base_dt, h.base_dt_to, NULL,
                 (SELECT count(*)::int FROM tbl_water_check_item i WHERE i.hdr_idx=h.idx AND i.co_cd=h.co_cd),
                 (SELECT count(*)::int FROM tbl_water_check_result r JOIN tbl_water_check_item i ON i.idx=r.item_idx AND i.co_cd=r.co_cd WHERE i.hdr_idx=h.idx AND r.co_cd=h.co_cd AND r.judge_cd='X')
            FROM tbl_water_check h WHERE p_tmpl_cd='WATER' AND h.doc_idx=d.idx AND h.co_cd=d.co_cd
      ) x ON true
     WHERE d.co_cd=p_co_cd AND d.tmpl_cd=p_tmpl_cd AND d.del_yn='N'
       AND (coalesce(p_from_dt,'')='' OR x.base_dt>=p_from_dt)
       AND (coalesce(p_to_dt,'')='' OR x.base_dt<=p_to_dt)
       AND (coalesce(p_doc_no,'')='' OR d.doc_no ILIKE '%' || p_doc_no || '%')
       AND (
           coalesce(p_writer,'')=''
           OR d.writer_id ILIKE '%' || p_writer || '%'
           OR coalesce(u.user_nm,'') ILIKE '%' || p_writer || '%'
       )
     ORDER BY x.base_dt DESC, d.doc_no DESC;
$$;
COMMENT ON FUNCTION sp_tbl_hygiene_document_r_000(varchar, varchar, varchar, varchar, varchar, varchar) IS
  '위생 문서 목록 — 기간·문서번호·작성자';

-- ------------------------------------------------------------
-- BizOps 목록
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_biz_ops_r_000(varchar, varchar, varchar, varchar);

CREATE OR REPLACE FUNCTION sp_tbl_biz_ops_r_000(
    p_co_cd varchar,
    p_tmpl_cd varchar,
    p_from_dt varchar,
    p_to_dt varchar,
    p_doc_no varchar DEFAULT '',
    p_writer varchar DEFAULT ''
)
RETURNS TABLE (
    doc_idx bigint, doc_no varchar, base_dt varchar, title varchar, status varchar,
    writer_id varchar, write_dt timestamp, row_cnt int, ng_cnt int
)
LANGUAGE sql STABLE AS $$
    SELECT d.idx, d.doc_no, d.base_dt, d.title, d.status, d.writer_id, d.write_dt,
           CASE p_tmpl_cd
             WHEN 'FACILITY' THEN (SELECT count(*)::int FROM tbl_facility_check_item r JOIN tbl_facility_check h ON h.idx = r.hdr_idx AND h.co_cd = r.co_cd WHERE h.doc_idx = d.idx AND r.co_cd = d.co_cd)
             WHEN 'CALIB_TARGET' THEN (SELECT count(*)::int FROM tbl_calib_target_row r JOIN tbl_calib_target h ON h.idx = r.hdr_idx AND h.co_cd = r.co_cd WHERE h.doc_idx = d.idx AND r.co_cd = d.co_cd)
             WHEN 'WASTE' THEN (SELECT count(*)::int FROM tbl_waste_check_row r JOIN tbl_waste_check h ON h.idx = r.hdr_idx AND h.co_cd = r.co_cd WHERE h.doc_idx = d.idx AND r.co_cd = d.co_cd)
             WHEN 'INV_CHECK' THEN (SELECT count(*)::int FROM tbl_inv_txn r WHERE r.src_tmpl_cd = 'INV_CHECK' AND r.src_doc_idx = d.idx AND r.co_cd = d.co_cd)
             WHEN 'RECV_INSP' THEN (SELECT count(*)::int FROM tbl_recv_inspect_item r JOIN tbl_recv_inspect h ON h.idx = r.hdr_idx AND h.co_cd = r.co_cd WHERE h.doc_idx = d.idx AND r.co_cd = d.co_cd)
             WHEN 'PROCESS' THEN (SELECT count(*)::int FROM tbl_process_check_item r JOIN tbl_process_check h ON h.idx = r.hdr_idx AND h.co_cd = r.co_cd WHERE h.doc_idx = d.idx AND r.co_cd = d.co_cd)
             ELSE 0
           END,
           CASE p_tmpl_cd
             WHEN 'FACILITY' THEN (SELECT count(*)::int FROM tbl_facility_check_item r JOIN tbl_facility_check h ON h.idx = r.hdr_idx AND h.co_cd = r.co_cd WHERE h.doc_idx = d.idx AND r.co_cd = d.co_cd AND r.judge_cd = 'X')
             WHEN 'RECV_INSP' THEN (SELECT count(*)::int FROM tbl_recv_inspect_item r JOIN tbl_recv_inspect h ON h.idx = r.hdr_idx AND h.co_cd = r.co_cd WHERE h.doc_idx = d.idx AND r.co_cd = d.co_cd AND r.judge_cd = 'F')
             ELSE 0
           END
      FROM tbl_document d
      LEFT JOIN tbl_user u ON u.co_cd = d.co_cd AND u.user_id = d.writer_id
     WHERE d.co_cd = p_co_cd AND d.tmpl_cd = p_tmpl_cd AND d.del_yn = 'N'
       AND (coalesce(p_from_dt, '') = '' OR d.base_dt >= p_from_dt)
       AND (coalesce(p_to_dt, '') = '' OR d.base_dt <= p_to_dt)
       AND (coalesce(p_doc_no, '') = '' OR d.doc_no ILIKE '%' || p_doc_no || '%')
       AND (
           coalesce(p_writer, '') = ''
           OR d.writer_id ILIKE '%' || p_writer || '%'
           OR coalesce(u.user_nm, '') ILIKE '%' || p_writer || '%'
       )
     ORDER BY d.base_dt DESC, d.doc_no DESC;
$$;
COMMENT ON FUNCTION sp_tbl_biz_ops_r_000(varchar, varchar, varchar, varchar, varchar, varchar) IS
  '시설·재고·공정 목록 — 기간·문서번호·작성자';
