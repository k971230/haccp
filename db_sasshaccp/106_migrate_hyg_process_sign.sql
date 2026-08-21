-- ============================================================
-- 106 — 공정점검 헤더 서명 스냅샷 (점검자·승인자·확인)
--
-- 파일번호: 106
-- 이전번호: 105
-- 개발자: 박승우
-- 일자: 2026-08-20
-- 코멘트:
--   1) 점검자·승인자·확인은 이름이 사용자와 같고 서명이 있으면 이미지를 문서에 복사한다
--   2) 서명이 없으면 이름 텍스트만 남긴다. 동명이인은 서명 있는 행 우선
--   3) 105 재실행 금지. 저장 SP 본문은 건드리지 않고 저장 후 이 SP를 부른다
--
-- ============================================================

SET search_path TO sasshaccp;

ALTER TABLE tbl_hyg_process
    ADD COLUMN IF NOT EXISTS checker_id varchar(20);
ALTER TABLE tbl_hyg_process
    ADD COLUMN IF NOT EXISTS checker_sign_img bytea;
ALTER TABLE tbl_hyg_process
    ADD COLUMN IF NOT EXISTS approver_id varchar(20);
ALTER TABLE tbl_hyg_process
    ADD COLUMN IF NOT EXISTS approver_nm varchar(50);
ALTER TABLE tbl_hyg_process
    ADD COLUMN IF NOT EXISTS approver_sign_img bytea;
ALTER TABLE tbl_hyg_process
    ADD COLUMN IF NOT EXISTS confirm_id varchar(20);
ALTER TABLE tbl_hyg_process
    ADD COLUMN IF NOT EXISTS confirm_sign_img bytea;

COMMENT ON COLUMN tbl_hyg_process.checker_id IS '점검자 로그인 ID — 저장 시 이름 매칭';
COMMENT ON COLUMN tbl_hyg_process.checker_sign_img IS '점검자 서명 스냅샷 — 없으면 이름만';
COMMENT ON COLUMN tbl_hyg_process.approver_nm IS '승인자명 — 헤더 스냅샷';
COMMENT ON COLUMN tbl_hyg_process.approver_sign_img IS '승인자 서명 스냅샷 — 없으면 이름만';
COMMENT ON COLUMN tbl_hyg_process.confirm_sign_img IS '확인 서명 스냅샷 — 없으면 confirm_nm만';

DROP PROCEDURE IF EXISTS sp_tbl_hyg_process_sign_u_000(varchar, bigint, varchar, varchar, varchar);
CREATE PROCEDURE sp_tbl_hyg_process_sign_u_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd       varchar,
    -- p_doc_idx: tbl_document.idx
    p_doc_idx     bigint,
    -- p_checker_nm: 점검자명. 빈값이면 서명 비움
    p_checker_nm  varchar,
    -- p_approver_nm: 승인자명
    p_approver_nm varchar,
    -- p_confirm_nm: 확인란 이름
    p_confirm_nm  varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_chk_id varchar; v_chk_img bytea;
    v_apv_id varchar; v_apv_img bytea;
    v_cfm_id varchar; v_cfm_img bytea;
BEGIN
    IF COALESCE(p_doc_idx, 0) <= 0 THEN
        RETURN;
    END IF;
    -- 이름이 비면 서명 비움. 동명이인일 때(= 서명 있는 사용자 우선, 그다음 user_id)
    IF btrim(COALESCE(p_checker_nm, '')) <> '' THEN
        SELECT u.user_id, u.sign_img INTO v_chk_id, v_chk_img
          FROM tbl_user u
         WHERE u.co_cd = p_co_cd AND u.use_yn = 'Y'
           AND u.user_nm = btrim(p_checker_nm)
         ORDER BY CASE WHEN u.sign_img IS NOT NULL THEN 0 ELSE 1 END, u.user_id
         LIMIT 1;
    END IF;
    IF btrim(COALESCE(p_approver_nm, '')) <> '' THEN
        SELECT u.user_id, u.sign_img INTO v_apv_id, v_apv_img
          FROM tbl_user u
         WHERE u.co_cd = p_co_cd AND u.use_yn = 'Y'
           AND u.user_nm = btrim(p_approver_nm)
         ORDER BY CASE WHEN u.sign_img IS NOT NULL THEN 0 ELSE 1 END, u.user_id
         LIMIT 1;
    END IF;
    IF btrim(COALESCE(p_confirm_nm, '')) <> '' THEN
        SELECT u.user_id, u.sign_img INTO v_cfm_id, v_cfm_img
          FROM tbl_user u
         WHERE u.co_cd = p_co_cd AND u.use_yn = 'Y'
           AND u.user_nm = btrim(p_confirm_nm)
         ORDER BY CASE WHEN u.sign_img IS NOT NULL THEN 0 ELSE 1 END, u.user_id
         LIMIT 1;
    END IF;
    UPDATE tbl_hyg_process
       SET checker_id = v_chk_id,
           checker_sign_img = v_chk_img,
           approver_id = v_apv_id,
           approver_nm = NULLIF(btrim(COALESCE(p_approver_nm, '')), ''),
           approver_sign_img = v_apv_img,
           confirm_id = v_cfm_id,
           confirm_sign_img = v_cfm_img
     WHERE co_cd = p_co_cd AND doc_idx = p_doc_idx;
END$$;

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
                'writerNm', d.writer_id
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
            'confirmSignYn', 'N'
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
