-- ============================================================
-- 107 — 공정점검 상세 작성자명·서명여부
--
-- 파일번호: 107
-- 이전번호: 106
-- 개발자: 박승우
-- 일자: 2026-08-20
-- 코멘트:
--   1) r_001 writerNm을 user_id가 아니라 tbl_user.user_nm으로 내린다
--   2) writerId·writerSignYn을 헤더 결재란 작성자 칸에 쓴다
--   3) 106 재실행 금지. 서명 저장 SP는 그대로 둔다
--
-- ============================================================

SET search_path TO sasshaccp;

CREATE OR REPLACE FUNCTION sp_tbl_hyg_process_r_001(
    p_co_cd   varchar,
    p_doc_idx bigint
)
RETURNS jsonb LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_apply int := 0;
    v_out jsonb;
BEGIN
    IF COALESCE(p_doc_idx, 0) > 0 THEN
        SELECT jsonb_build_object(
            'header', jsonb_build_object(
                'docIdx', d.idx,
                'docNo', d.doc_no,
                'status', d.status,
                'baseDt', d.base_dt,
                'checkerNm', h.checker_nm,
                'checkerId', h.checker_id,
                'checkerSignYn', CASE WHEN h.checker_sign_img IS NOT NULL THEN 'Y' ELSE 'N' END,
                'approverNm', h.approver_nm,
                'approverId', h.approver_id,
                'approverSignYn', CASE WHEN h.approver_sign_img IS NOT NULL THEN 'Y' ELSE 'N' END,
                'verNo', h.ver_no,
                'specialNote', h.special_note,
                'improveNote', h.improve_note,
                'actionNm', h.action_nm,
                'confirmNm', h.confirm_nm,
                'confirmId', h.confirm_id,
                'confirmSignYn', CASE WHEN h.confirm_sign_img IS NOT NULL THEN 'Y' ELSE 'N' END,
                'writerNm', (SELECT u.user_nm FROM tbl_user u
                              WHERE u.co_cd = d.co_cd AND u.user_id = d.writer_id),
                'writerId', d.writer_id,
                'writerSignYn', CASE WHEN EXISTS (
                    SELECT 1 FROM tbl_user u
                     WHERE u.co_cd = d.co_cd AND u.user_id = d.writer_id AND u.sign_img IS NOT NULL
                ) THEN 'Y' ELSE 'N' END
            ),
            'items', COALESCE((
                SELECT jsonb_agg(jsonb_build_object(
                    'itemCd', i.item_cd,
                    'sortNo', i.sort_no,
                    'cycleNm', i.cycle_nm,
                    'grpNm', i.grp_nm,
                    'itemNm', i.item_nm,
                    'inputType', i.input_type,
                    'unitNm', i.unit_nm,
                    'yn', i.yn,
                    'valNm', i.val_nm
                ) ORDER BY i.sort_no)
                FROM tbl_hyg_process_item i WHERE i.hdr_idx = h.idx AND i.co_cd = h.co_cd
            ), '[]'::jsonb)
        )
          INTO v_out
          FROM tbl_document d
          JOIN tbl_hyg_process h ON h.doc_idx = d.idx AND h.co_cd = d.co_cd
         WHERE d.co_cd = p_co_cd AND d.idx = p_doc_idx AND d.tmpl_cd = 'html_sys_001' AND d.del_yn = 'N';
        IF v_out IS NULL THEN
            RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        RETURN v_out;
    END IF;

    SELECT ver_no INTO v_apply
      FROM tbl_html_form_ver
     WHERE co_cd = p_co_cd AND tmpl_cd = 'html_sys_001' AND apply_yn = 'Y' AND use_yn = 'Y';
    v_apply := COALESCE(v_apply, 0);

    SELECT jsonb_build_object(
        'header', jsonb_build_object(
            'docIdx', NULL,
            'docNo', '',
            'status', NULL,
            'baseDt', to_char(CURRENT_DATE, 'YYYYMMDD'),
            'checkerNm', '',
            'checkerId', '',
            'checkerSignYn', 'N',
            'approverNm', '',
            'approverId', '',
            'approverSignYn', 'N',
            'verNo', v_apply,
            'specialNote', '',
            'improveNote', '',
            'actionNm', '',
            'confirmNm', '',
            'confirmId', '',
            'confirmSignYn', 'N',
            'writerNm', '',
            'writerId', '',
            'writerSignYn', 'N'
        ),
        'items', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'itemCd', x.item_cd,
                'sortNo', x.sort_no,
                'cycleNm', x.cycle_nm,
                'grpNm', x.grp_nm,
                'itemNm', x.item_nm,
                'inputType', x.input_type,
                'unitNm', x.unit_nm,
                'yn', '',
                'valNm', ''
            ) ORDER BY x.sort_no)
            FROM (
                SELECT c.item_cd, c.sort_no, c.cycle_nm, c.grp_nm, c.item_nm, c.input_type, c.unit_nm
                  FROM tbl_check_item c
                 WHERE c.tmpl_cd = 'html_sys_001' AND c.use_yn = 'Y' AND COALESCE(v_apply, 0) <= 0
                UNION ALL
                SELECT i.item_cd, i.sort_no, i.cycle_nm, i.grp_nm, i.item_nm, i.input_type, i.unit_nm
                  FROM tbl_html_form_ver_item i
                 WHERE i.co_cd = p_co_cd AND i.tmpl_cd = 'html_sys_001' AND i.ver_no = v_apply
                   AND COALESCE(v_apply, 0) > 0
            ) x
        ), '[]'::jsonb)
    ) INTO v_out;
    RETURN v_out;
END$$;
