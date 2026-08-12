-- ============================================================
-- 역할 — Wave 1 잔여: 공통 CCP 상세·삭제, LAW 템플릿 시드 보강
--
-- 개발자: 박승우
-- 일자: 2026-08-06
-- 코멘트:
--   1) Generic CCP 재조회·OPS_DELETE를 기존 테넌트에 반영한다
--   2) LAW_* 템플릿이 09에 없던 환경에서도 법적서류 leaf가 동작하게 한다
--   3) 결재 SP(sp_tbl_document_approval_c_000)는 이 파일에서 덮어쓰지 않는다
--      — 정본은 15_sp_doc.sql, apply 후 보강은 33_migrate_cancel_before_review.sql
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 공통 CCP 상세 — 헤더 + 행·셀 JSON
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_ccp_generic_monitor_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_doc_idx: 문서 idx
    p_doc_idx bigint
)
RETURNS TABLE (
    doc_idx bigint,
    doc_no varchar,
    status varchar,
    base_dt varchar,
    tmpl_cd varchar,
    ccp_cd varchar,
    diary_no varchar,
    limit_item_kind varchar,
    mng_user_id varchar,
    mng_nm varchar,
    rows_json jsonb
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT d.idx AS doc_idx,
           d.doc_no,
           d.status,
           m.base_dt,
           m.tmpl_cd,
           m.ccp_cd,
           m.diary_no,
           m.limit_item_kind,
           m.mng_user_id,
           m.mng_nm,
           COALESCE((
               SELECT jsonb_agg(
                          jsonb_build_object(
                              'rowSeq', r.row_seq,
                              'checkTime', COALESCE(r.check_time, ''),
                              'judgeCd', r.judge_cd,
                              'judgeModYn', r.judge_mod_yn,
                              'checkerId', COALESCE(r.checker_id, ''),
                              'checkerNm', COALESCE(r.checker_nm, ''),
                              'cells', COALESCE((
                                  SELECT jsonb_agg(
                                             jsonb_build_object(
                                                 'itemCd', c.item_cd,
                                                 'numVal', c.num_val,
                                                 'txtVal', COALESCE(c.txt_val, ''),
                                                 'judgeCd', c.judge_cd
                                             )
                                             ORDER BY c.item_cd
                                         )
                                    FROM tbl_ccp_generic_monitor_cell c
                                   WHERE c.row_idx = r.idx
                                     AND c.co_cd = r.co_cd
                              ), '[]'::jsonb)
                          )
                          ORDER BY r.row_seq
                      )
                 FROM tbl_ccp_generic_monitor_row r
                WHERE r.monitor_idx = m.idx
                  AND r.co_cd = m.co_cd
           ), '[]'::jsonb) AS rows_json
      FROM tbl_document d
      JOIN tbl_ccp_generic_monitor m
        ON m.doc_idx = d.idx
       AND m.co_cd = d.co_cd
     WHERE d.co_cd = p_co_cd
       AND d.idx = p_doc_idx
       AND d.del_yn = 'N';
END;
$$;
COMMENT ON FUNCTION sp_tbl_ccp_generic_monitor_r_000(varchar, bigint) IS '공통 CCP 모니터링 상세 — 헤더와 행·셀 JSON';

-- ------------------------------------------------------------
-- 2. 공통 CCP 삭제 — 임시·반려만
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_ccp_generic_monitor_d_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_doc_idx: 삭제 문서 idx
    p_doc_idx bigint,
    -- p_id: 작업자
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_status varchar(4);
    v_monitor_idx bigint;
BEGIN
    IF p_doc_idx IS NULL OR p_doc_idx = 0 THEN
        RAISE EXCEPTION '삭제할 문서를 선택하세요.' USING ERRCODE = '45000';
    END IF;

    SELECT d.status, m.idx
      INTO v_status, v_monitor_idx
      FROM tbl_document d
      JOIN tbl_ccp_generic_monitor m ON m.doc_idx = d.idx AND m.co_cd = d.co_cd
     WHERE d.co_cd = p_co_cd
       AND d.idx = p_doc_idx
       AND d.del_yn = 'N';

    IF v_monitor_idx IS NULL THEN
        RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    -- 작성중·반려일 때만 삭제 (TMP 폐기 후 WRK 정본)
    IF v_status NOT IN ('WRK', 'RJT') THEN
        RAISE EXCEPTION '결재 진행 중이거나 완료된 문서는 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    DELETE FROM tbl_corrective_action
     WHERE co_cd = p_co_cd AND src_doc_idx = p_doc_idx;

    DELETE FROM tbl_ccp_generic_monitor_cell c
     USING tbl_ccp_generic_monitor_row r
     WHERE c.row_idx = r.idx AND r.monitor_idx = v_monitor_idx AND r.co_cd = p_co_cd;

    DELETE FROM tbl_ccp_generic_monitor_row
     WHERE monitor_idx = v_monitor_idx AND co_cd = p_co_cd;

    DELETE FROM tbl_ccp_generic_monitor
     WHERE idx = v_monitor_idx AND co_cd = p_co_cd;

    DELETE FROM tbl_document_approval
     WHERE doc_idx = p_doc_idx AND co_cd = p_co_cd;

    DELETE FROM tbl_document_file
     WHERE doc_idx = p_doc_idx AND co_cd = p_co_cd;

    DELETE FROM tbl_document
     WHERE idx = p_doc_idx AND co_cd = p_co_cd;
END;
$$;
COMMENT ON PROCEDURE sp_tbl_ccp_generic_monitor_d_000(varchar, bigint, varchar) IS '공통 CCP 모니터링 삭제 — 작성중·반려만';

-- ------------------------------------------------------------
-- 3. 결재 SP — 의도적 미포함
--    구버전은 TMP 기준으로 덮어써 상신을 깨뜨렸다.
--    정본: 15_sp_doc.sql / 재적용 안전망: 33_migrate_cancel_before_review.sql
-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- 4. LAW 템플릿 보강 (09에 없던 환경)
-- ------------------------------------------------------------
INSERT INTO tbl_template (
    tmpl_cd, tmpl_nm, mng_no, doc_kind, category_cd, scrn_cd, default_cycle_cd, default_retention_month, impl_yn, sort_no, ins_id
) VALUES
    ('tmpl_admin-law-health',   '보건증관리',       NULL, 'HWP', 'LAW', 'law-health-cert',        'E', 36, 'Y', 61, 'system'),
    ('tmpl_logis-material-ledger', '원료수불대장관리', NULL, 'HWP', 'LAW', 'law-material-ledger',    'M', 36, 'Y', 62, 'system'),
    ('tmpl_admin-building-ledger', '건축물대장관리',   NULL, 'HWP', 'LAW', 'law-building-ledger',    'E', 36, 'Y', 63, 'system'),
    ('tmpl_admin-production-ledger','생산대장관리',    NULL, 'HWP', 'LAW', 'law-production-ledger',  'D', 36, 'Y', 64, 'system'),
    ('tmpl_admin-license-manage',  '영업등록증관리',   NULL, 'HWP', 'LAW', 'law-business-license',   'E', 36, 'Y', 65, 'system'),
    ('tmpl_admin-self-test','자가품질검사관리', NULL, 'HWP', 'LAW', 'law-self-quality-test',  'M', 36, 'Y', 66, 'system'),
    ('tmpl_admin-cert-manage',     '수료증관리',       NULL, 'HWP', 'LAW', 'law-completion-cert',    'E', 36, 'Y', 67, 'system')
ON CONFLICT (tmpl_cd) DO UPDATE SET
    tmpl_nm = EXCLUDED.tmpl_nm,
    doc_kind = EXCLUDED.doc_kind,
    category_cd = EXCLUDED.category_cd,
    scrn_cd = EXCLUDED.scrn_cd,
    impl_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

UPDATE tbl_template
   SET form_path = '_template/' || tmpl_cd || '.hwp',
       upd_id = 'system',
       upd_dt = now()
 WHERE tmpl_cd LIKE 'LAW_%'
   AND (form_path IS NULL OR form_path = '');

-- 기존 테넌트 회사 양식에 LAW 사용 등록
INSERT INTO tbl_company_template (co_cd, tmpl_cd, cycle_cd, retention_month, use_yn, ins_id, ins_dt)
SELECT c.co_cd, t.tmpl_cd, t.default_cycle_cd, t.default_retention_month, 'Y', 'system', now()
  FROM tbl_company c
 CROSS JOIN tbl_template t
 WHERE t.tmpl_cd LIKE 'LAW_%'
   AND t.impl_yn = 'Y'
ON CONFLICT (co_cd, tmpl_cd) DO UPDATE SET
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();
