-- ============================================================
-- 121 — 위생공정 양식 작성 (draft/hyg/hyg-process)
--
-- 파일번호: 121
-- 이전번호: 120
-- 개발자: 박승우
-- 일자: 2026-08-24
-- 코멘트:
--   1) 공정점검 작성 SP 4종(r_000·r_001·c_000·d_000)에 p_tmpl_cd 를 열어
--      기존 hygiene-process-check(html_sys_001)와 신규 화면(html_hyg_prc_NNN)이 같은 SP 를 쓴다
--   2) 자사 양식은 복사 SP 가 tbl_doc_no_rule 을 만들지 않아 첫 저장이 채번에서 실패했다.
--      c_000 이 저장 직전에 규칙 행을 ON CONFLICT DO NOTHING 으로 보강한다 (기존 자사 양식 백필 포함)
--   3) 화면·권한·메뉴(대 draft / 중 hyg / 소 hyg-process) 등록 + sort encode SP 에 draft·hyg 를 넣는다
--
-- 결재 상태는 신규 도메인을 만들지 않는다. DOC_STATUS 를 그대로 쓰고 화면이 3단계로 묶어 보여 준다:
--   전송대기 = WRK·RJT / 전송 = REQ·REV / 결재완료 = APV
-- 전송·전송취소는 sp_tbl_document_approval_c_000(REQUEST/CANCEL) 을 그대로 쓴다. 별도 SP 를 만들지 않는다.
--
-- Jenkins는 migrate를 안 돌린다. DBeaver/수동. 이력 100·106·107 은 고치지 않는다
-- ============================================================

SET search_path TO sasshaccp;

BEGIN;

-- ------------------------------------------------------------
-- 1. 목록 — p_tmpl_cd 추가. 양식코드·양식명·작성자를 좌측 그리드에 내린다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_hyg_process_r_000(varchar, varchar, varchar, varchar, varchar);
DROP FUNCTION IF EXISTS sp_tbl_hyg_process_r_000(varchar, varchar, varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_hyg_process_r_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위
    p_co_cd   varchar,
    -- p_tmpl_cd: 양식코드. 빈값이면 공정점검 계열 전체(html_sys_001 + html_hyg_prc_NNN)
    p_tmpl_cd varchar,
    -- p_from_dt: 점검일자 시작 YYYYMMDD. 빈값이면 하한 없음
    p_from_dt varchar,
    -- p_to_dt: 점검일자 종료 YYYYMMDD. 빈값이면 상한 없음
    p_to_dt   varchar,
    -- p_doc_no: 문서번호 부분검색. 빈값이면 전체
    p_doc_no  varchar,
    -- p_writer: 작성자 ID·이름 또는 점검자명 부분검색. 빈값이면 전체
    p_writer  varchar
)
RETURNS TABLE(
    doc_idx    bigint,
    hdr_idx    bigint,
    -- 양식코드 — 좌측 그리드 버튼. 이 값으로 우측 지면을 연다
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
       -- 양식코드를 줬을 때(= 좌측에서 한 양식만) 정확히 그 양식, 안 줬으면 공정점검 계열 전체
       AND (
            CASE WHEN COALESCE(NULLIF(btrim(p_tmpl_cd), ''), '') = ''
                 THEN d.tmpl_cd = 'html_sys_001' OR d.tmpl_cd ~ '^html_hyg_prc_[0-9]{3}$'
                 ELSE d.tmpl_cd = btrim(p_tmpl_cd)
            END
           )
       AND (COALESCE(NULLIF(btrim(p_from_dt), ''), '') = '' OR d.base_dt >= btrim(p_from_dt))
       AND (COALESCE(NULLIF(btrim(p_to_dt), ''), '') = '' OR d.base_dt <= btrim(p_to_dt))
       AND d.doc_no LIKE '%' || COALESCE(p_doc_no, '') || '%'
       AND (
            COALESCE(NULLIF(btrim(p_writer), ''), '') = ''
            OR d.writer_id LIKE '%' || btrim(p_writer) || '%'
            OR COALESCE(u.user_nm, '') LIKE '%' || btrim(p_writer) || '%'
            OR COALESCE(h.checker_nm, '') LIKE '%' || btrim(p_writer) || '%'
           )
     ORDER BY d.base_dt DESC, d.doc_no DESC;
$$;
COMMENT ON FUNCTION sp_tbl_hyg_process_r_000(varchar, varchar, varchar, varchar, varchar, varchar) IS
  '공정점검 작성 목록 — p_tmpl_cd 빈값이면 html_sys_001 + html_hyg_prc_NNN 전체';

-- ------------------------------------------------------------
-- 2. 상세/신규 — p_tmpl_cd 추가.
--    신규 항목은 표준(html_sys_001)이면 tbl_html_form_ver_item,
--    자사 양식이면 tbl_html_hyg_prc_ver_item 에서 빈칸으로 뜬다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_hyg_process_r_001(varchar, bigint);
DROP FUNCTION IF EXISTS sp_tbl_hyg_process_r_001(varchar, varchar, bigint);
CREATE FUNCTION sp_tbl_hyg_process_r_001(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_tmpl_cd: 양식코드. 신규(p_doc_idx 없음)일 때 어느 양식의 항목을 깔지 정한다
    p_tmpl_cd varchar,
    -- p_doc_idx: tbl_document.idx. NULL·0 이면 신규 기본행
    p_doc_idx bigint
)
RETURNS jsonb LANGUAGE plpgsql STABLE AS $$
DECLARE
    -- 적용 버전 — 0이면 표준 시드(tbl_check_item)
    v_apply int := 0;
    -- 표준 양식일 때(= html_sys_001) 옛 tbl_html_form_ver 경로를 탄다
    v_std   boolean := (btrim(COALESCE(p_tmpl_cd, '')) = 'html_sys_001');
    v_tmpl  varchar(40) := btrim(COALESCE(p_tmpl_cd, ''));
    v_out   jsonb;
BEGIN
    IF v_tmpl = '' THEN
        RAISE EXCEPTION '양식을 선택하세요.' USING ERRCODE = '45000';
    END IF;

    IF COALESCE(p_doc_idx, 0) > 0 THEN
        SELECT jsonb_build_object(
            'header', jsonb_build_object(
                'docIdx', d.idx,
                'docNo', d.doc_no,
                'tmplCd', d.tmpl_cd,
                'tmplNm', COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm, ''),
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
          LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd
          LEFT JOIN tbl_company_template ct ON ct.co_cd = d.co_cd AND ct.tmpl_cd = d.tmpl_cd
         WHERE d.co_cd = p_co_cd AND d.idx = p_doc_idx AND d.tmpl_cd = v_tmpl AND d.del_yn = 'N';
        IF v_out IS NULL THEN
            RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        RETURN v_out;
    END IF;

    -- 신규 — 적용 버전 번호를 양식 계열에 맞춰 고른다
    IF v_std THEN
        SELECT ver_no INTO v_apply
          FROM tbl_html_form_ver
         WHERE co_cd = p_co_cd AND tmpl_cd = v_tmpl AND apply_yn = 'Y' AND use_yn = 'Y';
    ELSE
        SELECT MAX(ver_no) INTO v_apply
          FROM tbl_html_hyg_prc_ver
         WHERE co_cd = p_co_cd AND tmpl_cd = v_tmpl AND use_yn = 'Y';
        IF COALESCE(v_apply, 0) <= 0 THEN
            RAISE EXCEPTION '양식 항목이 없습니다. 양식관리에서 먼저 등록하세요.' USING ERRCODE = '45000';
        END IF;
    END IF;
    v_apply := COALESCE(v_apply, 0);

    SELECT jsonb_build_object(
        'header', jsonb_build_object(
            'docIdx', NULL,
            'docNo', '',
            'tmplCd', v_tmpl,
            'tmplNm', COALESCE((SELECT COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm)
                                  FROM tbl_template t
                                  LEFT JOIN tbl_company_template ct
                                         ON ct.co_cd = p_co_cd AND ct.tmpl_cd = t.tmpl_cd
                                 WHERE t.tmpl_cd = v_tmpl), ''),
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
                -- 표준 양식이고 적용 버전이 없을 때(= 시드 그대로) 플랫폼 점검항목
                SELECT c.item_cd, c.sort_no, c.cycle_nm, c.grp_nm, c.item_nm, c.input_type, c.unit_nm
                  FROM tbl_check_item c
                 WHERE v_std AND c.tmpl_cd = v_tmpl AND c.use_yn = 'Y' AND v_apply <= 0
                UNION ALL
                -- 표준 양식이고 적용 버전이 있을 때(= 회사가 고른 버전) 옛 버전 항목
                SELECT i.item_cd, i.sort_no, i.cycle_nm, i.grp_nm, i.item_nm, i.input_type, i.unit_nm
                  FROM tbl_html_form_ver_item i
                 WHERE v_std AND i.co_cd = p_co_cd AND i.tmpl_cd = v_tmpl AND i.ver_no = v_apply
                   AND v_apply > 0
                UNION ALL
                -- 자사 양식일 때(= html_hyg_prc_NNN) 양식관리에서 만든 항목
                SELECT i.item_cd, i.sort_no, i.cycle_nm, i.grp_nm, i.item_nm, i.input_type, i.unit_nm
                  FROM tbl_html_hyg_prc_ver_item i
                 WHERE NOT v_std AND i.co_cd = p_co_cd AND i.tmpl_cd = v_tmpl AND i.ver_no = v_apply
            ) x
        ), '[]'::jsonb)
    ) INTO v_out;
    RETURN v_out;
END$$;
COMMENT ON FUNCTION sp_tbl_hyg_process_r_001(varchar, varchar, bigint) IS
  '공정점검 상세/신규 — 신규 항목은 표준이면 tbl_html_form_ver_item, 자사면 tbl_html_hyg_prc_ver_item';

-- ------------------------------------------------------------
-- 3. 저장 — p_tmpl_cd 추가. 사용 중인 양식만 허용하고 채번 규칙을 보강한다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_hyg_process_c_000(varchar, bigint, varchar, varchar, jsonb, varchar);
DROP FUNCTION IF EXISTS sp_tbl_hyg_process_c_000(varchar, varchar, bigint, varchar, varchar, jsonb, varchar);
CREATE FUNCTION sp_tbl_hyg_process_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd      varchar,
    -- p_tmpl_cd: 작성 양식코드 — html_sys_001 또는 html_hyg_prc_NNN
    p_tmpl_cd    varchar,
    -- p_doc_idx: 기존 문서 idx. NULL·0 이면 신규 INSERT
    p_doc_idx    bigint,
    -- p_base_dt: 점검일자 YYYYMMDD 8자리
    p_base_dt    varchar,
    -- p_checker_nm: 점검자명. 빈값 허용(전송 전에는 필수값을 보지 않는다)
    p_checker_nm varchar,
    -- p_payload: {verNo, items[], specialNote, improveNote, actionNm, confirmNm}
    p_payload    jsonb,
    -- p_id: JWT 작업자 ID — 작성자·감사 컬럼
    p_id         varchar
) RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE
    v_doc bigint; v_hdr bigint; v_status varchar; v_no varchar; v_name varchar; v_appr varchar; v_retain int;
    v_ver int; e jsonb; v_seq int := 0;
    v_tmpl varchar(40) := btrim(COALESCE(p_tmpl_cd, ''));
BEGIN
    IF COALESCE(p_co_cd, '') = '' OR COALESCE(p_base_dt, '') = '' OR length(p_base_dt) <> 8 THEN
        RAISE EXCEPTION '점검일자는 YYYYMMDD 8자리로 입력하세요.' USING ERRCODE = '45000';
    END IF;
    IF v_tmpl = '' THEN
        RAISE EXCEPTION '양식을 선택하세요.' USING ERRCODE = '45000';
    END IF;
    IF p_payload IS NULL OR jsonb_typeof(COALESCE(p_payload->'items', 'null'::jsonb)) <> 'array' THEN
        RAISE EXCEPTION '점검행 자료가 올바르지 않습니다.' USING ERRCODE = '45000';
    END IF;

    SELECT COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm), COALESCE(ct.appr_line_cd, 'DEFAULT'),
           COALESCE(ct.retention_month, t.default_retention_month)
      INTO v_name, v_appr, v_retain
      FROM tbl_template t
      LEFT JOIN tbl_company_template ct ON ct.co_cd = p_co_cd AND ct.tmpl_cd = t.tmpl_cd AND ct.use_yn = 'Y'
     WHERE t.tmpl_cd = v_tmpl AND t.use_yn = 'Y';
    IF v_name IS NULL THEN
        RAISE EXCEPTION '등록되지 않은 양식입니다.' USING ERRCODE = '45000';
    END IF;
    -- 사용여부가 N 일 때(= 양식관리에서 내린 양식) 새 문서를 만들지 않는다. 기존 문서 수정은 막지 않는다
    IF COALESCE(p_doc_idx, 0) = 0 AND NOT EXISTS (
        SELECT 1 FROM tbl_company_template
         WHERE co_cd = p_co_cd AND tmpl_cd = v_tmpl AND upper(COALESCE(use_yn, 'N')) = 'Y'
    ) THEN
        RAISE EXCEPTION '사용 중인 양식만 작성할 수 있습니다.' USING ERRCODE = '45000';
    END IF;

    v_ver := COALESCE(NULLIF(p_payload->>'verNo', '')::int, 0);

    IF COALESCE(p_doc_idx, 0) = 0 THEN
        -- 자사 양식 복사 SP 는 채번 규칙을 만들지 않는다. 없을 때만 기본 규칙을 깐다
        INSERT INTO tbl_doc_no_rule (co_cd, tmpl_cd, prefix, date_fmt, seq_len, reset_cycle, ins_id, ins_dt)
        VALUES (p_co_cd, v_tmpl, left(v_tmpl, 20), 'YYYYMMDD', 3, 'D', p_id, now())
        ON CONFLICT (co_cd, tmpl_cd) DO NOTHING;

        v_no := sp_tbl_doc_no_gen_c_000(p_co_cd, v_tmpl, p_base_dt);
        INSERT INTO tbl_document (
            co_cd, tmpl_cd, doc_kind, doc_no, base_dt, title, status, appr_line_cd,
            writer_id, write_dt, ver_no, retention_until, del_yn, ins_id, ins_dt
        ) VALUES (
            p_co_cd, v_tmpl, 'html', v_no, p_base_dt,
            v_name || ' (' || substr(p_base_dt, 1, 4) || '-' || substr(p_base_dt, 5, 2) || '-' || substr(p_base_dt, 7, 2) || ')',
            'WRK', v_appr, p_id, now(), 1,
            to_char((to_date(p_base_dt, 'YYYYMMDD') + (COALESCE(v_retain, 24) || ' months')::interval)::date, 'YYYYMMDD'),
            'N', p_id, now()
        ) RETURNING idx INTO v_doc;
        INSERT INTO tbl_hyg_process (
            co_cd, doc_idx, base_dt, checker_nm, ver_no,
            special_note, improve_note, action_nm, confirm_nm, ins_id
        ) VALUES (
            p_co_cd, v_doc, p_base_dt, NULLIF(p_checker_nm, ''), v_ver,
            NULLIF(p_payload->>'specialNote', ''), NULLIF(p_payload->>'improveNote', ''),
            NULLIF(p_payload->>'actionNm', ''), NULLIF(p_payload->>'confirmNm', ''), p_id
        ) RETURNING idx INTO v_hdr;
    ELSE
        SELECT d.idx, d.status, h.idx INTO v_doc, v_status, v_hdr
          FROM tbl_document d
          JOIN tbl_hyg_process h ON h.doc_idx = d.idx AND h.co_cd = d.co_cd
         WHERE d.co_cd = p_co_cd AND d.idx = p_doc_idx AND d.tmpl_cd = v_tmpl AND d.del_yn = 'N';
        IF v_doc IS NULL THEN
            RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        -- 전송대기(WRK·RJT)가 아닐 때(= 전송·결재완료) 수정 차단. 전송취소를 먼저 해야 한다
        IF v_status NOT IN ('WRK', 'RJT') THEN
            RAISE EXCEPTION '전송한 문서는 수정할 수 없습니다. 전송취소 후 수정하세요.' USING ERRCODE = '45000';
        END IF;
        UPDATE tbl_document SET
            base_dt = p_base_dt,
            title = v_name || ' (' || substr(p_base_dt, 1, 4) || '-' || substr(p_base_dt, 5, 2) || '-' || substr(p_base_dt, 7, 2) || ')',
            upd_id = p_id, upd_dt = now()
         WHERE idx = v_doc AND co_cd = p_co_cd;
        UPDATE tbl_hyg_process SET
            base_dt = p_base_dt, checker_nm = NULLIF(p_checker_nm, ''), ver_no = v_ver,
            special_note = NULLIF(p_payload->>'specialNote', ''),
            improve_note = NULLIF(p_payload->>'improveNote', ''),
            action_nm = NULLIF(p_payload->>'actionNm', ''),
            confirm_nm = NULLIF(p_payload->>'confirmNm', ''),
            upd_id = p_id, upd_dt = now()
         WHERE idx = v_hdr AND co_cd = p_co_cd;
        DELETE FROM tbl_hyg_process_item WHERE hdr_idx = v_hdr AND co_cd = p_co_cd;
    END IF;

    FOR e IN SELECT * FROM jsonb_array_elements(p_payload->'items') LOOP
        v_seq := v_seq + 1;
        INSERT INTO tbl_hyg_process_item (
            co_cd, hdr_idx, sort_no, item_cd, cycle_nm, grp_nm, item_nm, input_type, unit_nm, yn, val_nm, ins_id
        ) VALUES (
            p_co_cd, v_hdr, COALESCE(NULLIF(e->>'sortNo', '')::int, v_seq),
            COALESCE(NULLIF(e->>'itemCd', ''), 'hp-u-' || lpad(v_seq::text, 3, '0')),
            NULLIF(e->>'cycleNm', ''), NULLIF(e->>'grpNm', ''), NULLIF(e->>'itemNm', ''),
            COALESCE(NULLIF(e->>'inputType', ''), 'radio'), NULLIF(e->>'unitNm', ''),
            NULLIF(e->>'yn', ''), NULLIF(e->>'valNm', ''), p_id
        );
    END LOOP;
    RETURN v_doc;
END$$;
COMMENT ON FUNCTION sp_tbl_hyg_process_c_000(varchar, varchar, bigint, varchar, varchar, jsonb, varchar) IS
  '공정점검 저장 — 양식별. 신규는 사용여부 Y 만 허용하고 채번 규칙이 없으면 만든다';

-- ------------------------------------------------------------
-- 4. 삭제 — 양식코드 리터럴 제거. tbl_hyg_process 조인이 이미 계열을 좁힌다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_hyg_process_d_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_doc_idx: 삭제할 tbl_document.idx
    p_doc_idx bigint,
    -- p_id: JWT 작업자 ID
    p_id      varchar
)
LANGUAGE plpgsql AS $$
DECLARE v_status varchar; v_hdr bigint;
BEGIN
    SELECT d.status, h.idx INTO v_status, v_hdr
      FROM tbl_document d
      JOIN tbl_hyg_process h ON h.doc_idx = d.idx AND h.co_cd = d.co_cd
     WHERE d.co_cd = p_co_cd AND d.idx = p_doc_idx AND d.del_yn = 'N';
    IF v_hdr IS NULL THEN
        RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    -- 전송대기(WRK·RJT)가 아닐 때(= 전송·결재완료) 삭제 차단. 전송취소를 먼저 해야 한다
    IF v_status NOT IN ('WRK', 'RJT') THEN
        RAISE EXCEPTION '전송한 문서는 삭제할 수 없습니다. 전송취소 후 삭제하세요.' USING ERRCODE = '45000';
    END IF;
    DELETE FROM tbl_corrective_action WHERE co_cd = p_co_cd AND src_doc_idx = p_doc_idx;
    DELETE FROM tbl_hyg_process_item WHERE co_cd = p_co_cd AND hdr_idx = v_hdr;
    DELETE FROM tbl_hyg_process WHERE co_cd = p_co_cd AND idx = v_hdr;
    DELETE FROM tbl_document_approval WHERE co_cd = p_co_cd AND doc_idx = p_doc_idx;
    DELETE FROM tbl_document_file WHERE co_cd = p_co_cd AND doc_idx = p_doc_idx;
    DELETE FROM tbl_document WHERE co_cd = p_co_cd AND idx = p_doc_idx;
END$$;
COMMENT ON PROCEDURE sp_tbl_hyg_process_d_000(varchar, bigint, varchar) IS
  '공정점검 삭제 — 전송대기(WRK·RJT)만. 양식코드는 tbl_hyg_process 조인이 좁힌다';

-- ------------------------------------------------------------
-- 5. 화면 · 권한 · 메뉴 — 대 draft / 중 hyg / 소 hyg-process
-- ------------------------------------------------------------
INSERT INTO tbl_screen (scrn_cd, scrn_nm, module_cd, tmpl_cd, sort_no, ins_id) VALUES
    ('hyg-process', '위생공정 양식 작성', 'HYG', NULL, 4101, 'system')
ON CONFLICT (scrn_cd) DO UPDATE SET
    scrn_nm = EXCLUDED.scrn_nm, module_cd = EXCLUDED.module_cd, tmpl_cd = EXCLUDED.tmpl_cd,
    sort_no = EXCLUDED.sort_no, upd_id = 'system', upd_dt = now();

-- 삭제는 ADMIN 만 Y — 100 과 같은 관례
INSERT INTO tbl_role_screen (co_cd, usrgrp_cd, scrn_cd, read_yn, write_yn, modify_yn, delete_yn, print_yn, ins_id, ins_dt)
SELECT r.co_cd, r.usrgrp_cd, s.scrn_cd,
       'Y', 'Y', 'Y',
       CASE WHEN r.usrgrp_cd = 'ADMIN' THEN 'Y' ELSE 'N' END,
       'Y', 'system', now()
  FROM tbl_role r
  CROSS JOIN (VALUES ('hyg-process')) AS s(scrn_cd)
ON CONFLICT (co_cd, usrgrp_cd, scrn_cd) DO NOTHING;

-- 대분류 draft — URL /draft. menu_cd 는 URL 슬러그와 같다
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, 'draft', '양식 작성', NULL, NULL, 4000, 'Y', 'system', now()
  FROM (SELECT co_cd FROM tbl_company UNION SELECT DISTINCT co_cd FROM tbl_menu) c
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm, h_menu_cd = NULL, scrn_cd = NULL,
    use_yn = 'Y', sort_no = EXCLUDED.sort_no, upd_id = 'system', upd_dt = now();

-- 중분류 hyg — docs 아래 html 과 menu_cd 가 겹치지 않게 hyg 를 쓴다 (UNIQUE (co_cd, menu_cd))
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, 'hyg', '위생', 'draft', NULL, 4100, 'Y', 'system', now()
  FROM (SELECT co_cd FROM tbl_company UNION SELECT DISTINCT co_cd FROM tbl_menu) c
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm, h_menu_cd = 'draft', scrn_cd = NULL,
    use_yn = 'Y', sort_no = EXCLUDED.sort_no, upd_id = 'system', upd_dt = now();

-- 소 leaf — menu_cd = scrn_cd (120 정본 규칙)
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, s.scrn_cd, s.scrn_nm, 'hyg', s.scrn_cd, s.sort_no, 'Y', 'system', now()
  FROM (SELECT co_cd FROM tbl_company UNION SELECT DISTINCT co_cd FROM tbl_menu) c
 CROSS JOIN (SELECT scrn_cd, scrn_nm, sort_no FROM tbl_screen WHERE scrn_cd = 'hyg-process') s
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm, h_menu_cd = 'hyg', scrn_cd = EXCLUDED.scrn_cd,
    sort_no = EXCLUDED.sort_no, use_yn = 'Y', upd_id = 'system', upd_dt = now();

-- ------------------------------------------------------------
-- 6. sort 인코딩 SP — 120 정의에 draft(4) · hyg 를 더한다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_menu_sort_encode_u_000(
    -- p_co_cd: NULL이면 전 업체, 값이면 해당 업체만
    p_co_cd varchar DEFAULT NULL
)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE tbl_menu m
       SET sort_no = v.sn, upd_id = 'system', upd_dt = now()
      FROM (VALUES
        ('today-tasks', 1001),
        ('docs', 2000), ('flow', 3000), ('draft', 4000), ('bas', 5000), ('sys', 6000),
        ('ccp', 2100), ('prp', 2200), ('logis', 2300), ('admin', 2400),
        ('sch', 2500), ('hwp', 2600), ('html', 2700), ('appr-hidden', 2800),
        ('appr', 3100), ('box', 3200), ('ca', 3300),
        ('hyg', 4100),
        ('master', 5100),
        ('code', 6100), ('logs', 6200)
      ) AS v(menu_cd, sn)
     WHERE m.menu_cd = v.menu_cd
       AND m.use_yn = 'Y'
       AND (p_co_cd IS NULL OR m.co_cd = p_co_cd);

    -- sys/code leaf: 공통코드 → 메뉴 → 권한그룹 → 부서 → 사용자 → 결재선
    UPDATE tbl_menu m
       SET sort_no = v.ord, upd_id = 'system', upd_dt = now()
      FROM (VALUES
        ('common-code-management', 1),
        ('menu-management', 2),
        ('role-management', 3),
        ('department-management', 4),
        ('user-management', 5),
        ('approval-line-management', 6)
      ) AS v(scrn_cd, ord)
     WHERE m.scrn_cd = v.scrn_cd
       AND m.h_menu_cd = 'code'
       AND m.use_yn = 'Y'
       AND (p_co_cd IS NULL OR m.co_cd = p_co_cd);

    WITH mid AS (
        SELECT * FROM (VALUES
            ('ccp', 2, 1), ('prp', 2, 2),
            ('logis', 2, 3), ('admin', 2, 4),
            ('sch', 2, 5), ('hwp', 2, 6), ('html', 2, 7), ('appr-hidden', 2, 8),
            ('appr', 3, 1), ('box', 3, 2), ('ca', 3, 3),
            ('hyg', 4, 1),
            ('master', 5, 1),
            ('code', 6, 1), ('logs', 6, 2)
        ) AS t(mid_cd, dae_no, jung_no)
    ),
    ranked AS (
        SELECT m.co_cd, m.menu_cd,
               (mid.dae_no * 1000 + mid.jung_no * 100
                 + ROW_NUMBER() OVER (
                       PARTITION BY m.co_cd, m.h_menu_cd
                       ORDER BY m.sort_no, m.menu_cd
                   ))::int AS sn
          FROM tbl_menu m
          JOIN mid ON mid.mid_cd = m.h_menu_cd
         WHERE m.use_yn = 'Y'
           AND m.scrn_cd IS NOT NULL
           AND (p_co_cd IS NULL OR m.co_cd = p_co_cd)
    )
    UPDATE tbl_menu m
       SET sort_no = r.sn, upd_id = 'system', upd_dt = now()
      FROM ranked r
     WHERE m.co_cd = r.co_cd AND m.menu_cd = r.menu_cd;
END;
$$;
COMMENT ON PROCEDURE sp_tbl_menu_sort_encode_u_000(varchar) IS
  '메뉴 sort_no 인코딩 — 대(1~9)*1000+중(0~9)*100+소(0~99). draft=4. p_co_cd NULL=전업체';

CALL sp_tbl_menu_sort_encode_u_000(NULL);

COMMIT;

-- ------------------------------------------------------------
-- 검증
-- ------------------------------------------------------------
-- SELECT menu_cd, h_menu_cd, scrn_cd, menu_nm, sort_no
--   FROM tbl_menu WHERE menu_cd IN ('draft', 'hyg', 'hyg-process') ORDER BY sort_no;
-- SELECT * FROM sp_tbl_hyg_process_r_000('{회사코드}', '', '', '', '', '');
-- SELECT sp_tbl_hyg_process_r_001('{회사코드}', 'html_hyg_prc_001', NULL);
