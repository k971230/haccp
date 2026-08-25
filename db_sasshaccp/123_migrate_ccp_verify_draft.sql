-- ============================================================
-- 123 — CCP 검증점검 양식 작성 (draft/ccp-chk/ccp-verify)
--
-- 파일번호: 123
-- 이전번호: 122
-- 개발자: 박승우
-- 일자: 2026-08-24
-- 코멘트:
--   1) 양식관리 ccp-verify-template 에서 사용여부 예로 둔 자사 양식(tml_ccp_chk_NNN)을 일자별로 작성한다.
--      HYG(draft/hyg/hyg-process)와 형제 화면이며 업무 규칙·상태·버튼이 같다
--   2) 데이터는 CCP 기존 테이블 tbl_ccp_verify_check / tbl_ccp_verify_item 을 그대로 쓴다.
--      HYG 테이블을 복제하지 않고, 지면이 요구하는 칸만 ALTER 로 더한다
--   3) 기존 sp_tbl_ccp_form_* 은 html_sys_006·hwp_sys_003 전용이라 건드리지 않는다.
--      이 화면 전용 SP 를 화면명 규약(sp_{화면명}_*)으로 새로 둔다
--
-- 메뉴: 대분류 draft(양식 작성) 아래 중분류 ccp-chk(CCP 양식). hyg 는 HYG 양식으로 이름만 맞춘다.
--       tbl_menu UNIQUE (co_cd, menu_cd) 때문에 docs 아래 ccp 와 겹치는 슬러그를 쓸 수 없다
--
-- 121·122 를 먼저 적용해야 한다. Jenkins는 migrate를 안 돌린다. DBeaver/수동
-- ============================================================

SET search_path TO sasshaccp;

BEGIN;

-- ------------------------------------------------------------
-- 1. DDL — 기존 CCP 작성 테이블에 지면이 쓰는 칸만 더한다
--    (기존 ccp-verification-check 화면은 새 칸을 안 쓰므로 NULL 허용이면 그대로 동작한다)
-- ------------------------------------------------------------
ALTER TABLE tbl_ccp_verify_check
    -- 작성에 쓴 자사 양식 버전 — tbl_tml_ccp_chk_ver.ver_no
    ADD COLUMN IF NOT EXISTS ver_no            int         NOT NULL DEFAULT 0,
    -- 점검자 서명 스냅샷 — 저장 시점 tbl_user.sign_img 복사
    ADD COLUMN IF NOT EXISTS checker_sign_img  bytea       NULL,
    ADD COLUMN IF NOT EXISTS approver_id       varchar(20) NULL,
    ADD COLUMN IF NOT EXISTS approver_nm       varchar(50) NULL,
    ADD COLUMN IF NOT EXISTS approver_sign_img bytea       NULL,
    ADD COLUMN IF NOT EXISTS confirm_id        varchar(20) NULL,
    ADD COLUMN IF NOT EXISTS confirm_nm        varchar(50) NULL,
    ADD COLUMN IF NOT EXISTS confirm_sign_img  bytea       NULL,
    -- 지면 하단 4열 — 특이사항·개선조치 및 결과·조치
    ADD COLUMN IF NOT EXISTS special_note      text        NULL,
    ADD COLUMN IF NOT EXISTS improve_note      text        NULL,
    ADD COLUMN IF NOT EXISTS action_nm         text        NULL;

COMMENT ON COLUMN tbl_ccp_verify_check.ver_no      IS '작성에 쓴 자사 양식 버전 — tbl_tml_ccp_chk_ver.ver_no. 0이면 표준';
COMMENT ON COLUMN tbl_ccp_verify_check.approver_nm IS '승인자명 스냅샷 — 지면 결재란';
COMMENT ON COLUMN tbl_ccp_verify_check.confirm_nm  IS '확인자명 스냅샷 — 지면 하단 확인칸';
COMMENT ON COLUMN tbl_ccp_verify_check.special_note IS '특이사항 — 개행 보존';

ALTER TABLE tbl_ccp_verify_item
    -- 점검주기 문구 — 양식 항목 스냅샷(일일/매월 등). 기록 무결성 때문에 문서에 복사한다
    ADD COLUMN IF NOT EXISTS cycle_nm   varchar(50) NULL,
    -- 입력유형 — html-input-ty (radio / radio-num / radio-text / num / text)
    ADD COLUMN IF NOT EXISTS input_type varchar(20) NOT NULL DEFAULT 'radio',
    -- 단위 — 숫자 입력 항목의 표시 단위
    ADD COLUMN IF NOT EXISTS unit_nm    varchar(20) NULL;

COMMENT ON COLUMN tbl_ccp_verify_item.cycle_nm   IS '점검주기 문구 스냅샷 — 양식 항목에서 복사';
COMMENT ON COLUMN tbl_ccp_verify_item.input_type IS '입력유형 html-input-ty — 지면 렌더·필수값 판정 기준';
COMMENT ON COLUMN tbl_ccp_verify_item.unit_nm    IS '단위 — 숫자 입력 항목 표시용';

-- ------------------------------------------------------------
-- 2. 목록 — HYG r_000 과 같은 계약(양식코드·양식명·일자구간·작성자ID·작성자명)
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_ccp_verify_r_000(varchar, varchar, varchar, varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_ccp_verify_r_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위
    p_co_cd     varchar,
    -- p_tmpl_cd: 양식코드 부분검색. 빈값이면 자사 검증점검 양식 전체
    p_tmpl_cd   varchar,
    -- p_tmpl_nm: 양식명 부분검색. 빈값이면 전체
    p_tmpl_nm   varchar,
    -- p_from_dt: 일자 시작 YYYYMMDD. 빈값이면 하한 없음
    p_from_dt   varchar,
    -- p_to_dt: 일자 종료 YYYYMMDD. 빈값이면 상한 없음
    p_to_dt     varchar,
    -- p_writer_id: 작성자 ID 부분검색. 빈값이면 전체
    p_writer_id varchar,
    -- p_writer_nm: 작성자명 부분검색. 빈값이면 전체
    p_writer_nm varchar
)
RETURNS TABLE(
    doc_idx    bigint,
    hdr_idx    bigint,
    tmpl_cd    varchar,
    tmpl_nm    varchar,
    doc_no     varchar,
    base_dt    varchar,
    checker_nm varchar,
    writer_id  varchar,
    writer_nm  varchar,
    status     varchar,
    row_cnt    int,
    ng_cnt     int
) LANGUAGE sql STABLE AS $$
    SELECT d.idx, h.idx,
           d.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm)::varchar,
           d.doc_no, h.base_dt, h.checker_nm,
           d.writer_id,
           COALESCE(u.user_nm, d.writer_id, '')::varchar,
           d.status,
           (SELECT count(*)::int FROM tbl_ccp_verify_item i WHERE i.hdr_idx = h.idx AND i.co_cd = h.co_cd),
           (SELECT count(*)::int FROM tbl_ccp_verify_item i WHERE i.hdr_idx = h.idx AND i.co_cd = h.co_cd AND i.answer_cd = 'N')
      FROM tbl_document d
      JOIN tbl_ccp_verify_check h ON h.doc_idx = d.idx AND h.co_cd = d.co_cd
      LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = d.co_cd AND ct.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_user u ON u.co_cd = d.co_cd AND u.user_id = d.writer_id
     WHERE d.co_cd = p_co_cd AND d.del_yn = 'N'
       -- 이 화면은 자사 양식만 다룬다. 예시 000 과 옛 html_sys_006 문서는 제외한다
       AND d.tmpl_cd ~ '^tml_ccp_chk_[0-9]{3}$'
       AND d.tmpl_cd <> 'tml_ccp_chk_000'
       AND (
            COALESCE(NULLIF(btrim(p_tmpl_cd), ''), '') = ''
            OR d.tmpl_cd ILIKE '%' || btrim(p_tmpl_cd) || '%'
           )
       AND (
            COALESCE(NULLIF(btrim(p_tmpl_nm), ''), '') = ''
            OR COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm, '') ILIKE '%' || btrim(p_tmpl_nm) || '%'
           )
       AND (COALESCE(NULLIF(btrim(p_from_dt), ''), '') = '' OR h.base_dt >= btrim(p_from_dt))
       AND (COALESCE(NULLIF(btrim(p_to_dt), ''), '') = '' OR h.base_dt <= btrim(p_to_dt))
       AND (
            COALESCE(NULLIF(btrim(p_writer_id), ''), '') = ''
            OR COALESCE(d.writer_id, '') ILIKE '%' || btrim(p_writer_id) || '%'
           )
       AND (
            COALESCE(NULLIF(btrim(p_writer_nm), ''), '') = ''
            OR COALESCE(u.user_nm, '') ILIKE '%' || btrim(p_writer_nm) || '%'
           )
     ORDER BY h.base_dt DESC, d.doc_no DESC;
$$;
COMMENT ON FUNCTION sp_ccp_verify_r_000(varchar, varchar, varchar, varchar, varchar, varchar, varchar) IS
  'CCP 검증점검 작성 목록 — tml_ccp_chk_NNN 자사 양식만. 결재 여부는 화면이 DOC_STATUS 로 묶어 거른다';

-- ------------------------------------------------------------
-- 3. 상세/신규 — 신규 항목은 tbl_tml_ccp_chk_ver_item 에서 빈칸으로 뜬다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_ccp_verify_r_001(varchar, varchar, bigint);
CREATE FUNCTION sp_ccp_verify_r_001(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_tmpl_cd: 양식코드. 신규(p_doc_idx 없음)일 때 어느 양식의 항목을 깔지 정한다
    p_tmpl_cd varchar,
    -- p_doc_idx: tbl_document.idx. NULL·0 이면 신규 기본행
    p_doc_idx bigint
)
RETURNS jsonb LANGUAGE plpgsql STABLE AS $$
DECLARE
    -- 적용 버전 — 자사 양식은 사용 중 버전의 MAX
    v_apply int := 0;
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
                'baseDt', h.base_dt,
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
            -- 지면 항목 계약은 HYG 와 같다 — 같은 Paper 컴포넌트를 쓴다
            'items', COALESCE((
                SELECT jsonb_agg(jsonb_build_object(
                    'itemCd', i.item_cd,
                    'sortNo', i.row_seq,
                    'cycleNm', i.cycle_nm,
                    'grpNm', i.proc_nm,
                    'itemNm', i.verify_desc,
                    'inputType', i.input_type,
                    'unitNm', i.unit_nm,
                    'yn', i.answer_cd,
                    'valNm', i.record_desc
                ) ORDER BY i.row_seq)
                FROM tbl_ccp_verify_item i WHERE i.hdr_idx = h.idx AND i.co_cd = h.co_cd
            ), '[]'::jsonb)
        )
          INTO v_out
          FROM tbl_document d
          JOIN tbl_ccp_verify_check h ON h.doc_idx = d.idx AND h.co_cd = d.co_cd
          LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd
          LEFT JOIN tbl_company_template ct ON ct.co_cd = d.co_cd AND ct.tmpl_cd = d.tmpl_cd
         WHERE d.co_cd = p_co_cd AND d.idx = p_doc_idx AND d.tmpl_cd = v_tmpl AND d.del_yn = 'N';
        IF v_out IS NULL THEN
            RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        RETURN v_out;
    END IF;

    -- 신규 — 사용 중인 자사 양식 버전의 항목을 빈칸으로 깐다
    SELECT MAX(ver_no) INTO v_apply
      FROM tbl_tml_ccp_chk_ver
     WHERE co_cd = p_co_cd AND tmpl_cd = v_tmpl AND use_yn = 'Y';
    IF COALESCE(v_apply, 0) <= 0 THEN
        RAISE EXCEPTION '양식 항목이 없습니다. 양식관리에서 먼저 등록하세요.' USING ERRCODE = '45000';
    END IF;

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
            'checkerNm', '', 'checkerId', '', 'checkerSignYn', 'N',
            'approverNm', '', 'approverId', '', 'approverSignYn', 'N',
            'verNo', v_apply,
            'specialNote', '', 'improveNote', '', 'actionNm', '',
            'confirmNm', '', 'confirmId', '', 'confirmSignYn', 'N',
            'writerNm', '', 'writerId', '', 'writerSignYn', 'N'
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
                'yn', '',
                'valNm', ''
            ) ORDER BY i.sort_no)
            FROM tbl_tml_ccp_chk_ver_item i
           WHERE i.co_cd = p_co_cd AND i.tmpl_cd = v_tmpl AND i.ver_no = v_apply
        ), '[]'::jsonb)
    ) INTO v_out;
    RETURN v_out;
END$$;
COMMENT ON FUNCTION sp_ccp_verify_r_001(varchar, varchar, bigint) IS
  'CCP 검증점검 상세/신규 — 신규 항목은 tbl_tml_ccp_chk_ver_item. 지면 계약은 HYG 와 같다';

-- ------------------------------------------------------------
-- 4. 저장 — 사용 중인 양식만 허용하고 채번 규칙이 없으면 만든다
--    (양식 복사 SP 가 tbl_doc_no_rule 을 만들지 않아 첫 저장이 채번에서 실패한다)
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_ccp_verify_c_000(varchar, varchar, bigint, varchar, varchar, jsonb, varchar);
CREATE FUNCTION sp_ccp_verify_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd      varchar,
    -- p_tmpl_cd: 작성 양식코드 — tml_ccp_chk_NNN
    p_tmpl_cd    varchar,
    -- p_doc_idx: 기존 문서 idx. NULL·0 이면 신규 INSERT
    p_doc_idx    bigint,
    -- p_base_dt: 일자 YYYYMMDD 8자리
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
        RAISE EXCEPTION '일자는 YYYYMMDD 8자리로 입력하세요.' USING ERRCODE = '45000';
    END IF;
    -- 이 화면은 자사 검증점검 양식만 다룬다
    IF v_tmpl !~ '^tml_ccp_chk_[0-9]{3}$' OR v_tmpl = 'tml_ccp_chk_000' THEN
        RAISE EXCEPTION '작성할 양식을 선택하세요.' USING ERRCODE = '45000';
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
        -- 양식 복사 SP 는 채번 규칙을 만들지 않는다. 없을 때만 기본 규칙을 깐다
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
        INSERT INTO tbl_ccp_verify_check (
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
          JOIN tbl_ccp_verify_check h ON h.doc_idx = d.idx AND h.co_cd = d.co_cd
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
        UPDATE tbl_ccp_verify_check SET
            base_dt = p_base_dt, checker_nm = NULLIF(p_checker_nm, ''), ver_no = v_ver,
            special_note = NULLIF(p_payload->>'specialNote', ''),
            improve_note = NULLIF(p_payload->>'improveNote', ''),
            action_nm = NULLIF(p_payload->>'actionNm', ''),
            confirm_nm = NULLIF(p_payload->>'confirmNm', ''),
            upd_id = p_id, upd_dt = now()
         WHERE idx = v_hdr AND co_cd = p_co_cd;
        DELETE FROM tbl_ccp_verify_item WHERE hdr_idx = v_hdr AND co_cd = p_co_cd;
    END IF;

    FOR e IN SELECT * FROM jsonb_array_elements(p_payload->'items') LOOP
        v_seq := v_seq + 1;
        INSERT INTO tbl_ccp_verify_item (
            co_cd, hdr_idx, row_seq, item_cd, cycle_nm, proc_nm, verify_desc,
            input_type, unit_nm, answer_cd, record_desc, ins_id
        ) VALUES (
            p_co_cd, v_hdr, COALESCE(NULLIF(e->>'sortNo', '')::int, v_seq),
            COALESCE(NULLIF(e->>'itemCd', ''), 'cv-u-' || lpad(v_seq::text, 3, '0')),
            NULLIF(e->>'cycleNm', ''), NULLIF(e->>'grpNm', ''),
            -- verify_desc 는 NOT NULL — 항목명이 비면 자리표시자를 넣는다
            COALESCE(NULLIF(e->>'itemNm', ''), '검증 내용'),
            COALESCE(NULLIF(e->>'inputType', ''), 'radio'), NULLIF(e->>'unitNm', ''),
            NULLIF(e->>'yn', ''), NULLIF(e->>'valNm', ''), p_id
        );
    END LOOP;
    RETURN v_doc;
END$$;
COMMENT ON FUNCTION sp_ccp_verify_c_000(varchar, varchar, bigint, varchar, varchar, jsonb, varchar) IS
  'CCP 검증점검 저장 — 양식별. 신규는 사용여부 Y 만 허용하고 채번 규칙이 없으면 만든다';

-- ------------------------------------------------------------
-- 5. 서명 스냅샷 — 이름이 사용자와 같고 서명이 있으면 이미지를 복사한다
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_ccp_verify_sign_u_000(varchar, bigint, varchar, varchar, varchar);
CREATE PROCEDURE sp_ccp_verify_sign_u_000(
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
         WHERE u.co_cd = p_co_cd AND u.use_yn = 'Y' AND u.user_nm = btrim(p_checker_nm)
         ORDER BY CASE WHEN u.sign_img IS NOT NULL THEN 0 ELSE 1 END, u.user_id
         LIMIT 1;
    END IF;
    IF btrim(COALESCE(p_approver_nm, '')) <> '' THEN
        SELECT u.user_id, u.sign_img INTO v_apv_id, v_apv_img
          FROM tbl_user u
         WHERE u.co_cd = p_co_cd AND u.use_yn = 'Y' AND u.user_nm = btrim(p_approver_nm)
         ORDER BY CASE WHEN u.sign_img IS NOT NULL THEN 0 ELSE 1 END, u.user_id
         LIMIT 1;
    END IF;
    IF btrim(COALESCE(p_confirm_nm, '')) <> '' THEN
        SELECT u.user_id, u.sign_img INTO v_cfm_id, v_cfm_img
          FROM tbl_user u
         WHERE u.co_cd = p_co_cd AND u.use_yn = 'Y' AND u.user_nm = btrim(p_confirm_nm)
         ORDER BY CASE WHEN u.sign_img IS NOT NULL THEN 0 ELSE 1 END, u.user_id
         LIMIT 1;
    END IF;
    UPDATE tbl_ccp_verify_check
       SET checker_id = v_chk_id,
           checker_sign_img = v_chk_img,
           approver_id = v_apv_id,
           approver_nm = NULLIF(btrim(COALESCE(p_approver_nm, '')), ''),
           approver_sign_img = v_apv_img,
           confirm_id = v_cfm_id,
           confirm_sign_img = v_cfm_img
     WHERE co_cd = p_co_cd AND doc_idx = p_doc_idx;
END$$;
COMMENT ON PROCEDURE sp_ccp_verify_sign_u_000(varchar, bigint, varchar, varchar, varchar) IS
  'CCP 검증점검 점검자·승인자·확인 서명 스냅샷 — 저장 직후. 이름 매칭';

-- ------------------------------------------------------------
-- 6. 삭제 — 전송대기(WRK·RJT)만
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_ccp_verify_d_000(varchar, bigint, varchar);
CREATE PROCEDURE sp_ccp_verify_d_000(
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
      JOIN tbl_ccp_verify_check h ON h.doc_idx = d.idx AND h.co_cd = d.co_cd
     WHERE d.co_cd = p_co_cd AND d.idx = p_doc_idx AND d.del_yn = 'N'
       AND d.tmpl_cd ~ '^tml_ccp_chk_[0-9]{3}$';
    IF v_hdr IS NULL THEN
        RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    -- 전송대기(WRK·RJT)가 아닐 때(= 전송·결재완료) 삭제 차단. 전송취소를 먼저 해야 한다
    IF v_status NOT IN ('WRK', 'RJT') THEN
        RAISE EXCEPTION '전송한 문서는 삭제할 수 없습니다. 전송취소 후 삭제하세요.' USING ERRCODE = '45000';
    END IF;
    DELETE FROM tbl_corrective_action WHERE co_cd = p_co_cd AND src_doc_idx = p_doc_idx;
    DELETE FROM tbl_ccp_verify_item WHERE co_cd = p_co_cd AND hdr_idx = v_hdr;
    DELETE FROM tbl_ccp_verify_check WHERE co_cd = p_co_cd AND idx = v_hdr;
    DELETE FROM tbl_document_approval WHERE co_cd = p_co_cd AND doc_idx = p_doc_idx;
    DELETE FROM tbl_document_file WHERE co_cd = p_co_cd AND doc_idx = p_doc_idx;
    DELETE FROM tbl_document WHERE co_cd = p_co_cd AND idx = p_doc_idx;
END$$;
COMMENT ON PROCEDURE sp_ccp_verify_d_000(varchar, bigint, varchar) IS
  'CCP 검증점검 삭제 — 전송대기(WRK·RJT)만. 자사 양식 문서만 대상';

-- ------------------------------------------------------------
-- 7. 화면 · 권한 · 메뉴 — 대 draft(양식 작성) / 중 hyg(HYG 양식) · ccp-chk(CCP 양식)
--    docs 아래 ccp 와 menu_cd 가 겹칠 수 없어 CCP 중분류는 ccp-chk 를 쓴다
-- ------------------------------------------------------------
INSERT INTO tbl_screen (scrn_cd, scrn_nm, module_cd, tmpl_cd, sort_no, ins_id) VALUES
    ('ccp-verify', 'CCP 검증점검 양식 작성', 'CCP', NULL, 4201, 'system')
ON CONFLICT (scrn_cd) DO UPDATE SET
    scrn_nm = EXCLUDED.scrn_nm, module_cd = EXCLUDED.module_cd, tmpl_cd = EXCLUDED.tmpl_cd,
    sort_no = EXCLUDED.sort_no, upd_id = 'system', upd_dt = now();

-- 삭제는 ADMIN 만 Y — 100·121 과 같은 관례
INSERT INTO tbl_role_screen (co_cd, usrgrp_cd, scrn_cd, read_yn, write_yn, modify_yn, delete_yn, print_yn, ins_id, ins_dt)
SELECT r.co_cd, r.usrgrp_cd, s.scrn_cd,
       'Y', 'Y', 'Y',
       CASE WHEN r.usrgrp_cd = 'ADMIN' THEN 'Y' ELSE 'N' END,
       'Y', 'system', now()
  FROM tbl_role r
  CROSS JOIN (VALUES ('ccp-verify')) AS s(scrn_cd)
ON CONFLICT (co_cd, usrgrp_cd, scrn_cd) DO NOTHING;

-- 대분류 표시명 — 「양식 작성」으로 맞춘다 (121 은 같은 이름으로 만들었다)
UPDATE tbl_menu
   SET menu_nm = '양식 작성', upd_id = 'system', upd_dt = now()
 WHERE menu_cd = 'draft' AND menu_nm IS DISTINCT FROM '양식 작성';

-- 중분류 hyg 표시명 — HYG 양식 (121 의 「위생」에서 형제 명칭으로 맞춘다)
UPDATE tbl_menu
   SET menu_nm = 'HYG 양식', upd_id = 'system', upd_dt = now()
 WHERE menu_cd = 'hyg' AND menu_nm IS DISTINCT FROM 'HYG 양식';

-- 중분류 ccp-chk — CCP 양식
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, 'ccp-chk', 'CCP 양식', 'draft', NULL, 4200, 'Y', 'system', now()
  FROM (SELECT co_cd FROM tbl_company UNION SELECT DISTINCT co_cd FROM tbl_menu) c
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm, h_menu_cd = 'draft', scrn_cd = NULL,
    use_yn = 'Y', sort_no = EXCLUDED.sort_no, upd_id = 'system', upd_dt = now();

-- 소 leaf — menu_cd = scrn_cd (120 정본 규칙)
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, s.scrn_cd, s.scrn_nm, 'ccp-chk', s.scrn_cd, s.sort_no, 'Y', 'system', now()
  FROM (SELECT co_cd FROM tbl_company UNION SELECT DISTINCT co_cd FROM tbl_menu) c
 CROSS JOIN (SELECT scrn_cd, scrn_nm, sort_no FROM tbl_screen WHERE scrn_cd = 'ccp-verify') s
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm, h_menu_cd = 'ccp-chk', scrn_cd = EXCLUDED.scrn_cd,
    sort_no = EXCLUDED.sort_no, use_yn = 'Y', upd_id = 'system', upd_dt = now();

-- ------------------------------------------------------------
-- 8. sort 인코딩 SP — 121 정의에 ccp-chk 를 더한다
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
        ('hyg', 4100), ('ccp-chk', 4200),
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
            ('hyg', 4, 1), ('ccp-chk', 4, 2),
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
  '메뉴 sort_no 인코딩 — 대(1~9)*1000+중(0~9)*100+소(0~99). draft=4(hyg·ccp-chk). p_co_cd NULL=전업체';

CALL sp_tbl_menu_sort_encode_u_000(NULL);

COMMIT;

-- ------------------------------------------------------------
-- 검증
-- ------------------------------------------------------------
-- SELECT menu_cd, h_menu_cd, scrn_cd, menu_nm, sort_no
--   FROM tbl_menu WHERE h_menu_cd = 'draft' OR menu_cd IN ('draft','hyg-process','ccp-verify') ORDER BY sort_no;
-- SELECT * FROM sp_ccp_verify_r_000('{회사코드}', '', '', '', '', '', '');
-- SELECT sp_ccp_verify_r_001('{회사코드}', 'tml_ccp_chk_001', NULL);
