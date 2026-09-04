-- ============================================================
--  01_sp.sql — 함수·프로시저 정본
--
--  개발자: 박승우
--  일자: 2026-08-25
--  코멘트:
--    1) 화면 단위 sp_{화면명}_* · 테이블 단위 sp_tbl_* (01-project-core)
--    2) 00_ddl.sql 다음에 적용한다 — 표가 있어야 본문이 검증된다
--    3) 안 쓰는 SP 72본은 2026-08-25 정리에서 제거됐다
--
--  적용: psql -f 00_ddl.sql ; psql -f 01_sp.sql ; psql -f 02_seed.sql
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
--  물러난 SP 정리 — 이미 있는 DB 에 다시 적용해도 안전하게 지운다
--
--  파일에서 정의를 빼는 것만으로는 운영 DB 에 남는다. 여기서 명시로 지운다.
--    sp_tbl_master_delete_blocker_r_000
--      기준정보 화면(제품·보관고·거래처 등)이 2026-08-25 28화면 정리에서 빠지면서
--      참조하던 표 15본이 함께 없어졌다. 부르는 곳도 없다
--    sp_tbl_company_code_copy_c_000
--      03_code_seed.sql 이 -v co_cd 로 같은 일을 한다. 두 갈래를 두면 한쪽만 고쳐진다
--    sp_tbl_menu_sort_encode_u_000
--      없어진 메뉴(bas·ccp·prp·logis·admin)의 정렬값을 쓴다. 돌리면 순서가 어긋난다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sasshaccp.sp_tbl_master_delete_blocker_r_000(character varying, character varying, bigint[]);
DROP PROCEDURE IF EXISTS sasshaccp.sp_tbl_company_code_copy_c_000(character varying, character varying);
DROP PROCEDURE IF EXISTS sasshaccp.sp_tbl_menu_sort_encode_u_000(character varying);
-- 결재 대기·완료 목록 — 구 이름(appr_inbox/appr_hist)을 화면명(sign-ready/sign-ok)으로 옮긴다
DROP FUNCTION IF EXISTS sasshaccp.sp_tbl_document_appr_inbox_r_000(character varying, character varying, character varying, character varying, character varying);
DROP FUNCTION IF EXISTS sasshaccp.sp_tbl_document_appr_hist_r_000(character varying, character varying, character varying, character varying, character varying);

-- Name: sp_audit_log_r_000(character varying, character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

-- 반환에 scrn_cd를 더하므로 REPLACE만으로는 시그니처가 안 바뀐다
DROP FUNCTION IF EXISTS sasshaccp.sp_audit_log_r_000(character varying, character varying, character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION sasshaccp.sp_audit_log_r_000(p_co_cd character varying, p_from_dt character varying, p_to_dt character varying, p_menu_key character varying, p_user_id character varying, p_action_cd character varying) RETURNS TABLE(idx bigint, user_id character varying, user_nm character varying, menu_nm character varying, tbl_nm character varying, scrn_cd character varying, tgt_idx bigint, action_cd character varying, before_json jsonb, after_json jsonb, reason character varying, ip_addr character varying, ins_dt timestamp without time zone)
    LANGUAGE sql
    AS $$
    SELECT a.idx,
           a.user_id,
           u.user_nm,
           -- 화면 마스터 표시명. 없으면 화면코드를 그대로 보여준다
           COALESCE(s.scrn_nm, a.scrn_cd) AS menu_nm,
           a.tbl_nm,
           a.scrn_cd,
           a.tgt_idx,
           a.action_cd,
           a.before_json,
           a.after_json,
           a.reason,
           a.ip_addr,
           a.ins_dt
      FROM tbl_audit_log a
      -- 행위자명 — 삭제된 사용자도 이력은 남으므로 LEFT JOIN. 동명 아이디가 타사에 있어도 자사 행만 붙인다
      LEFT JOIN tbl_user u ON u.co_cd = a.co_cd AND u.user_id = a.user_id
      -- 대상 메뉴명 — 적재 시점 화면코드. 공통코드 매핑을 쓰지 않는다
      LEFT JOIN tbl_screen s ON s.scrn_cd = a.scrn_cd
     WHERE a.co_cd = p_co_cd
       AND a.ins_dt >= to_timestamp(p_from_dt, 'YYYYMMDD')
       AND a.ins_dt <  to_timestamp(p_to_dt,   'YYYYMMDD') + interval '1 day'
       -- 리프 선택값 = 화면코드. 공백이면 기간 전건
       AND (
            COALESCE(p_menu_key, '') = ''
            OR a.scrn_cd = p_menu_key
       )
       AND a.user_id   LIKE CONCAT('%', COALESCE(p_user_id,   ''), '%')
       AND a.action_cd LIKE CONCAT('%', COALESCE(p_action_cd, ''), '%')
     ORDER BY a.ins_dt DESC;
$$;


--
-- Name: FUNCTION sp_audit_log_r_000(p_co_cd character varying, p_from_dt character varying, p_to_dt character varying, p_menu_key character varying, p_user_id character varying, p_action_cd character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_audit_log_r_000(p_co_cd character varying, p_from_dt character varying, p_to_dt character varying, p_menu_key character varying, p_user_id character varying, p_action_cd character varying) IS '변경 감사 이력 조회 — 기간·화면코드·행위자·행위 필터, 최신순';


--
-- Name: sp_ccp_log_r_000(character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

DROP FUNCTION IF EXISTS sasshaccp.sp_ccp_log_r_000(character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying);
DROP FUNCTION IF EXISTS sasshaccp.sp_ccp_log_r_000(character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying);
CREATE OR REPLACE FUNCTION sasshaccp.sp_ccp_log_r_000(p_co_cd character varying, p_tmpl_pfx character varying, p_tmpl_cd character varying, p_tmpl_nm character varying, p_from_dt character varying, p_to_dt character varying, p_writer_id character varying, p_writer_nm character varying, p_title character varying DEFAULT NULL::character varying) RETURNS TABLE(doc_idx bigint, hdr_idx bigint, tmpl_cd character varying, tmpl_nm character varying, doc_no character varying, base_dt character varying, checker_nm character varying, writer_id character varying, writer_nm character varying, status character varying, row_cnt integer, ng_cnt integer, title character varying)
    LANGUAGE sql STABLE
    AS $$
    SELECT d.idx, m.idx,
           d.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm)::varchar,
           d.doc_no, m.base_dt, m.mng_nm,
           d.writer_id,
           COALESCE(u.user_nm, d.writer_id, '')::varchar,
           d.status,
           (SELECT count(*)::int FROM tbl_ccp_generic_monitor_row r WHERE r.monitor_idx = m.idx AND r.co_cd = m.co_cd),
           (SELECT count(*)::int FROM tbl_ccp_generic_monitor_row r WHERE r.monitor_idx = m.idx AND r.co_cd = m.co_cd AND r.judge_cd = 'F'),
           d.title
      FROM tbl_document d
      JOIN tbl_ccp_generic_monitor m ON m.doc_idx = d.idx AND m.co_cd = d.co_cd
      -- 카탈로그는 자사 행만. 시드가 업체에 복사한다
      LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd AND t.co_cd = d.co_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = d.co_cd AND ct.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_user u ON u.co_cd = d.co_cd AND u.user_id = d.writer_id
     WHERE d.co_cd = p_co_cd AND d.del_yn = 'N'
       -- 이 화면은 해당 계열 자사 양식만 다룬다. 예시 000 은 제외
       AND d.tmpl_cd LIKE p_tmpl_pfx || '%'
       AND d.tmpl_cd <> p_tmpl_pfx || '000'
       AND (COALESCE(NULLIF(btrim(p_tmpl_cd), ''), '') = '' OR d.tmpl_cd ILIKE '%' || btrim(p_tmpl_cd) || '%')
       AND (COALESCE(NULLIF(btrim(p_tmpl_nm), ''), '') = ''
            OR COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm, '') ILIKE '%' || btrim(p_tmpl_nm) || '%')
       AND (COALESCE(NULLIF(btrim(p_from_dt), ''), '') = '' OR m.base_dt >= btrim(p_from_dt))
       AND (COALESCE(NULLIF(btrim(p_to_dt), ''), '') = '' OR m.base_dt <= btrim(p_to_dt))
       AND (COALESCE(NULLIF(btrim(p_writer_id), ''), '') = '' OR COALESCE(d.writer_id, '') ILIKE '%' || btrim(p_writer_id) || '%')
       AND (COALESCE(NULLIF(btrim(p_writer_nm), ''), '') = '' OR COALESCE(u.user_nm, '') ILIKE '%' || btrim(p_writer_nm) || '%')
       AND (COALESCE(NULLIF(btrim(p_title), ''), '') = '' OR COALESCE(d.title, '') ILIKE '%' || btrim(p_title) || '%')
     ORDER BY m.base_dt DESC, d.doc_no DESC;
$$;


--
-- Name: FUNCTION sp_ccp_log_r_000(p_co_cd character varying, p_tmpl_pfx character varying, p_tmpl_cd character varying, p_tmpl_nm character varying, p_from_dt character varying, p_to_dt character varying, p_writer_id character varying, p_writer_nm character varying, p_remark character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_ccp_log_r_000(p_co_cd character varying, p_tmpl_pfx character varying, p_tmpl_cd character varying, p_tmpl_nm character varying, p_from_dt character varying, p_to_dt character varying, p_writer_id character varying, p_writer_nm character varying, p_title character varying) IS 'CCP 포장·가열 작성 목록 — 양식군 접두로 가른다. 자사 양식만. 제목은 tbl_document.title 부분검색';


--
-- Name: sp_ccp_mtl_r_000(character varying, character varying, character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

DROP FUNCTION IF EXISTS sasshaccp.sp_ccp_mtl_r_000(character varying, character varying, character varying, character varying, character varying, character varying, character varying);
DROP FUNCTION IF EXISTS sasshaccp.sp_ccp_mtl_r_000(character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying);
CREATE OR REPLACE FUNCTION sasshaccp.sp_ccp_mtl_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_tmpl_nm character varying, p_from_dt character varying, p_to_dt character varying, p_writer_id character varying, p_writer_nm character varying, p_title character varying DEFAULT NULL::character varying) RETURNS TABLE(doc_idx bigint, hdr_idx bigint, tmpl_cd character varying, tmpl_nm character varying, doc_no character varying, base_dt character varying, checker_nm character varying, writer_id character varying, writer_nm character varying, status character varying, row_cnt integer, ng_cnt integer, title character varying)
    LANGUAGE sql STABLE
    AS $_$
    SELECT d.idx, h.idx,
           d.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm)::varchar,
           d.doc_no, h.base_dt, h.mng_nm,
           d.writer_id,
           COALESCE(u.user_nm, d.writer_id, '')::varchar,
           d.status,
           (SELECT count(*)::int FROM tbl_ccp_metal_sens_row s WHERE s.hdr_idx = h.idx AND s.co_cd = h.co_cd),
           (SELECT count(*)::int FROM tbl_ccp_metal_sens_row s WHERE s.hdr_idx = h.idx AND s.co_cd = h.co_cd AND s.judge_cd = 'F'),
           d.title
      FROM tbl_document d
      JOIN tbl_ccp_metal_monitor h ON h.doc_idx = d.idx AND h.co_cd = d.co_cd
      -- 카탈로그는 자사 행만. 시드가 업체에 복사한다
      LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd AND t.co_cd = d.co_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = d.co_cd AND ct.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_user u ON u.co_cd = d.co_cd AND u.user_id = d.writer_id
     WHERE d.co_cd = p_co_cd AND d.del_yn = 'N'
       -- 자사 금속검출 양식만. 기존 tmpl_ccp-metal-log 문서는 이 화면 대상이 아니다
       AND d.tmpl_cd ~ '^html_ccp_mtl_[0-9]{3}$'
       AND d.tmpl_cd <> 'html_ccp_mtl_000'
       AND (COALESCE(NULLIF(btrim(p_tmpl_cd), ''), '') = '' OR d.tmpl_cd ILIKE '%' || btrim(p_tmpl_cd) || '%')
       AND (COALESCE(NULLIF(btrim(p_tmpl_nm), ''), '') = ''
            OR COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm, '') ILIKE '%' || btrim(p_tmpl_nm) || '%')
       AND (COALESCE(NULLIF(btrim(p_from_dt), ''), '') = '' OR h.base_dt >= btrim(p_from_dt))
       AND (COALESCE(NULLIF(btrim(p_to_dt), ''), '') = '' OR h.base_dt <= btrim(p_to_dt))
       AND (COALESCE(NULLIF(btrim(p_writer_id), ''), '') = '' OR COALESCE(d.writer_id, '') ILIKE '%' || btrim(p_writer_id) || '%')
       AND (COALESCE(NULLIF(btrim(p_writer_nm), ''), '') = '' OR COALESCE(u.user_nm, '') ILIKE '%' || btrim(p_writer_nm) || '%')
       AND (COALESCE(NULLIF(btrim(p_title), ''), '') = '' OR COALESCE(d.title, '') ILIKE '%' || btrim(p_title) || '%')
     ORDER BY h.base_dt DESC, d.doc_no DESC;
$_$;


--
-- Name: FUNCTION sp_ccp_mtl_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_tmpl_nm character varying, p_from_dt character varying, p_to_dt character varying, p_writer_id character varying, p_writer_nm character varying, p_remark character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_ccp_mtl_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_tmpl_nm character varying, p_from_dt character varying, p_to_dt character varying, p_writer_id character varying, p_writer_nm character varying, p_title character varying) IS 'CCP 금속검출 작성 목록 — html_ccp_mtl_NNN 자사 양식만. 제목은 tbl_document.title 부분검색';


--
-- Name: sp_ccp_verify_c_000(character varying, character varying, bigint, character varying, character varying, jsonb, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_ccp_verify_c_000(p_co_cd character varying, p_tmpl_cd character varying, p_doc_idx bigint, p_base_dt character varying, p_checker_nm character varying, p_payload jsonb, p_id character varying) RETURNS bigint
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_doc bigint; v_hdr bigint; v_status varchar; v_no varchar; v_name varchar; v_appr varchar; v_retain int;
    v_ver int; e jsonb; v_seq int := 0;
    v_tmpl varchar(40) := btrim(COALESCE(p_tmpl_cd, ''));
    -- 목록 제목 — payload title 이 있으면 그 값, 없으면 신규는 자동값·수정은 기존값
    v_in varchar(300); v_auto varchar(300);
BEGIN
    IF COALESCE(p_co_cd, '') = '' OR COALESCE(p_base_dt, '') = '' OR length(p_base_dt) <> 8 THEN
        RAISE EXCEPTION '일자는 YYYYMMDD 8자리로 입력하세요.' USING ERRCODE = '45000';
    END IF;
    -- 이 화면은 자사 검증점검 양식만 다룬다
    IF v_tmpl !~ '^html_ccp_chk_[0-9]{3}$' OR v_tmpl = 'html_ccp_chk_000' THEN
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
     WHERE t.tmpl_cd = v_tmpl AND t.use_yn = 'Y' AND t.co_cd = p_co_cd;
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
    v_auto := v_name || ' (' || substr(p_base_dt, 1, 4) || '-' || substr(p_base_dt, 5, 2) || '-' || substr(p_base_dt, 7, 2) || ')';
    v_in := NULLIF(btrim(COALESCE(p_payload->>'title', '')), '');

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
            p_co_cd, v_tmpl, 'HTML', v_no, p_base_dt,
            COALESCE(v_in, v_auto),
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
            title = COALESCE(v_in, title),
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
            /*
             * 자리 번호는 **보내온 배열 순서**로 우리가 매긴다. 화면이 준 sortNo 를 쓰지 않는다.
             *
             * ux_tbl_ccp_verify_item (hdr_idx, row_seq) 가 유니크인데 예전에는
             * COALESCE(sortNo, v_seq) 로 화면 값을 그대로 받았다. 겹친 값이 오면 23505 가 나고,
             * 그게 「다른 사용자가 동시에 처리 중입니다」(409)로 둔갑해 사람을 엉뚱한 데로 보냈다.
             * 실제로 상세 조회가 지면 머리와 점검항목에 각각 1번을 붙여 내려준다 —
             * 화면이 머리를 걸러 보내서 지금은 안 터질 뿐이다.
             *
             * 배열 순서가 곧 지면에 찍히는 순서라 v_seq 로 충분하고, 겹칠 수가 없다.
             */
            p_co_cd, v_hdr, v_seq,
            COALESCE(NULLIF(e->>'itemCd', ''), 'cv-u-' || lpad(v_seq::text, 3, '0')),
            NULLIF(e->>'cycleNm', ''), NULLIF(e->>'grpNm', ''),
            -- verify_desc 는 NOT NULL — 항목명이 비면 자리표시자를 넣는다
            COALESCE(NULLIF(e->>'itemNm', ''), '검증 내용'),
            COALESCE(NULLIF(e->>'inputType', ''), 'radio'), NULLIF(e->>'unitNm', ''),
            NULLIF(e->>'yn', ''), NULLIF(e->>'valNm', ''), p_id
        );
    END LOOP;
    RETURN v_doc;
END$_$;


--
-- Name: FUNCTION sp_ccp_verify_c_000(p_co_cd character varying, p_tmpl_cd character varying, p_doc_idx bigint, p_base_dt character varying, p_checker_nm character varying, p_payload jsonb, p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_ccp_verify_c_000(p_co_cd character varying, p_tmpl_cd character varying, p_doc_idx bigint, p_base_dt character varying, p_checker_nm character varying, p_payload jsonb, p_id character varying) IS 'CCP 검증점검 저장 — 양식별. 신규는 사용여부 Y 만 허용하고 채번 규칙이 없으면 만든다';


--
-- Name: sp_ccp_verify_d_000(character varying, bigint, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_ccp_verify_d_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_id character varying)
    LANGUAGE plpgsql
    AS $_$
DECLARE v_status varchar; v_hdr bigint;
BEGIN
    SELECT d.status, h.idx INTO v_status, v_hdr
      FROM tbl_document d
      JOIN tbl_ccp_verify_check h ON h.doc_idx = d.idx AND h.co_cd = d.co_cd
     WHERE d.co_cd = p_co_cd AND d.idx = p_doc_idx AND d.del_yn = 'N'
       AND d.tmpl_cd ~ '^html_ccp_chk_[0-9]{3}$';
    IF v_hdr IS NULL THEN
        RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    -- 전송대기(WRK·RJT)가 아닐 때(= 전송·결재완료) 삭제 차단. 전송취소를 먼저 해야 한다
    IF v_status NOT IN ('WRK', 'RJT') THEN
        RAISE EXCEPTION '전송한 문서는 삭제할 수 없습니다. 전송취소 후 삭제하세요.' USING ERRCODE = '45000';
    END IF;
    -- 완료(DONE)된 개선조치는 원문서를 지워도 남긴다. 조치 기록이 초안 삭제로 사라지면 안 된다.
    -- 개선조치 목록은 LEFT JOIN tbl_document 이라 원문서가 없어도 문서 칸만 빈 채로 보인다
    DELETE FROM tbl_corrective_action WHERE co_cd = p_co_cd AND src_doc_idx = p_doc_idx AND status <> 'DONE';
    DELETE FROM tbl_ccp_verify_item WHERE co_cd = p_co_cd AND hdr_idx = v_hdr;
    DELETE FROM tbl_ccp_verify_check WHERE co_cd = p_co_cd AND idx = v_hdr;
    DELETE FROM tbl_document_approval WHERE co_cd = p_co_cd AND doc_idx = p_doc_idx;
    DELETE FROM tbl_document_file WHERE co_cd = p_co_cd AND doc_idx = p_doc_idx;
    DELETE FROM tbl_document WHERE co_cd = p_co_cd AND idx = p_doc_idx;
END$_$;


--
-- Name: PROCEDURE sp_ccp_verify_d_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_ccp_verify_d_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_id character varying) IS 'CCP 검증점검 삭제 — 전송대기(WRK·RJT)만. 자사 양식 문서만 대상';


--
-- Name: sp_ccp_verify_r_000(character varying, character varying, character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

DROP FUNCTION IF EXISTS sasshaccp.sp_ccp_verify_r_000(character varying, character varying, character varying, character varying, character varying, character varying, character varying);
DROP FUNCTION IF EXISTS sasshaccp.sp_ccp_verify_r_000(character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying);
CREATE OR REPLACE FUNCTION sasshaccp.sp_ccp_verify_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_tmpl_nm character varying, p_from_dt character varying, p_to_dt character varying, p_writer_id character varying, p_writer_nm character varying, p_title character varying DEFAULT NULL::character varying) RETURNS TABLE(doc_idx bigint, hdr_idx bigint, tmpl_cd character varying, tmpl_nm character varying, doc_no character varying, base_dt character varying, checker_nm character varying, writer_id character varying, writer_nm character varying, status character varying, row_cnt integer, ng_cnt integer, title character varying)
    LANGUAGE sql STABLE
    AS $_$
    SELECT d.idx, h.idx,
           d.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm)::varchar,
           d.doc_no, h.base_dt, h.checker_nm,
           d.writer_id,
           COALESCE(u.user_nm, d.writer_id, '')::varchar,
           d.status,
           (SELECT count(*)::int FROM tbl_ccp_verify_item i WHERE i.hdr_idx = h.idx AND i.co_cd = h.co_cd),
           (SELECT count(*)::int FROM tbl_ccp_verify_item i WHERE i.hdr_idx = h.idx AND i.co_cd = h.co_cd AND i.answer_cd = 'N'),
           d.title
      FROM tbl_document d
      JOIN tbl_ccp_verify_check h ON h.doc_idx = d.idx AND h.co_cd = d.co_cd
      -- 카탈로그는 자사 행만. 시드가 업체에 복사한다
      LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd AND t.co_cd = d.co_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = d.co_cd AND ct.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_user u ON u.co_cd = d.co_cd AND u.user_id = d.writer_id
     WHERE d.co_cd = p_co_cd AND d.del_yn = 'N'
       -- 이 화면은 자사 양식만 다룬다. 예시 000 과 옛 html_sys_006 문서는 제외한다
       AND d.tmpl_cd ~ '^html_ccp_chk_[0-9]{3}$'
       AND d.tmpl_cd <> 'html_ccp_chk_000'
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
       AND (COALESCE(NULLIF(btrim(p_title), ''), '') = '' OR COALESCE(d.title, '') ILIKE '%' || btrim(p_title) || '%')
     ORDER BY h.base_dt DESC, d.doc_no DESC;
$_$;


--
-- Name: FUNCTION sp_ccp_verify_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_tmpl_nm character varying, p_from_dt character varying, p_to_dt character varying, p_writer_id character varying, p_writer_nm character varying, p_remark character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_ccp_verify_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_tmpl_nm character varying, p_from_dt character varying, p_to_dt character varying, p_writer_id character varying, p_writer_nm character varying, p_title character varying) IS 'CCP 검증점검 작성 목록 — html_ccp_chk_NNN 자사 양식만. 제목은 tbl_document.title 부분검색. 결재 여부는 화면이 DOC_STATUS 로 묶어 거른다';


--
-- Name: sp_ccp_verify_r_001(character varying, character varying, bigint); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_ccp_verify_r_001(p_co_cd character varying, p_tmpl_cd character varying, p_doc_idx bigint) RETURNS jsonb
    LANGUAGE plpgsql STABLE
    AS $$
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
                /*
                 * 지면 도장칸의 승인자 — 결재가 끝났으면 그 결과가 정본이다.
                 *
                 * 예전에는 h.approver_nm(작성자가 지면에 친 글자)만 봤다. 그래서
                 * 결재를 승인해도 종이에는 작성 당시 글자가 그대로 남았고,
                 * 사람 이름이 아닌 값('3')이 들어간 문서도 그대로 보였다.
                 * 승인 SP 는 이미 tbl_document_approval 에 결재자 이름과
                 * tbl_user.sign_img 스냅샷을 남겨 두고 있다 — 그것을 먼저 본다.
                 * 승인 전(대기)에는 결재행이 없거나 result_cd 가 'A' 가 아니라
                 * COALESCE 가 지면 값으로 떨어진다 — 예전과 같은 화면이다.
                 */
                'approverNm', COALESCE(
                    (SELECT a.approver_nm FROM tbl_document_approval a
                      WHERE a.co_cd = d.co_cd AND a.doc_idx = d.idx
                        AND a.role_cd = 'APPROVE' AND a.result_cd = 'A'
                      ORDER BY a.step_no DESC LIMIT 1),
                    h.approver_nm),
                'approverId', COALESCE(
                    (SELECT a.approver_id FROM tbl_document_approval a
                      WHERE a.co_cd = d.co_cd AND a.doc_idx = d.idx
                        AND a.role_cd = 'APPROVE' AND a.result_cd = 'A'
                      ORDER BY a.step_no DESC LIMIT 1),
                    h.approver_id),
                -- 서명도 결재 시점 스냅샷이 먼저다. 없을 때만 지면에 붙은 이미지를 본다
                'approverSignYn', CASE WHEN COALESCE(
                    (SELECT a.sign_img FROM tbl_document_approval a
                      WHERE a.co_cd = d.co_cd AND a.doc_idx = d.idx
                        AND a.role_cd = 'APPROVE' AND a.result_cd = 'A'
                      ORDER BY a.step_no DESC LIMIT 1),
                    h.approver_sign_img) IS NOT NULL THEN 'Y' ELSE 'N' END,
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
          -- 카탈로그는 자사 행만. 시드가 업체에 복사한다
          LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd AND t.co_cd = d.co_cd
          LEFT JOIN tbl_company_template ct ON ct.co_cd = d.co_cd AND ct.tmpl_cd = d.tmpl_cd
         WHERE d.co_cd = p_co_cd AND d.idx = p_doc_idx AND d.tmpl_cd = v_tmpl AND d.del_yn = 'N';
        IF v_out IS NULL THEN
            RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        RETURN v_out;
    END IF;

    -- 신규 — 사용 중인 자사 양식 버전의 항목을 빈칸으로 깐다
    SELECT MAX(ver_no) INTO v_apply
      FROM tbl_html_ccp_chk_ver
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
                                 WHERE t.tmpl_cd = v_tmpl AND t.co_cd = p_co_cd), ''),
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
            FROM tbl_html_ccp_chk_ver_item i
           WHERE i.co_cd = p_co_cd AND i.tmpl_cd = v_tmpl AND i.ver_no = v_apply
        ), '[]'::jsonb)
    ) INTO v_out;
    RETURN v_out;
END$$;


--
-- Name: FUNCTION sp_ccp_verify_r_001(p_co_cd character varying, p_tmpl_cd character varying, p_doc_idx bigint); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_ccp_verify_r_001(p_co_cd character varying, p_tmpl_cd character varying, p_doc_idx bigint) IS 'CCP 검증점검 상세/신규 — 신규 항목은 tbl_html_ccp_chk_ver_item. 지면 계약은 HYG 와 같다';


--
-- Name: sp_ccp_verify_sign_u_000(character varying, bigint, character varying, character varying, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_ccp_verify_sign_u_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_checker_nm character varying, IN p_approver_nm character varying, IN p_confirm_nm character varying)
    LANGUAGE plpgsql
    AS $$
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
        -- 그런 이름의 사용자가 없을 때(= 사람이 아닌 값) 저장을 막는다.
        -- 예전에는 이름 글자만 남기고 통과시켰다. 그래서 승인자 칸에 '3' 이 들어간
        -- 법정 서류가 만들어졌다. 빈 칸은 그대로 통과시킨다 — 승인 전에는 비어 있는 게 정상이다
        IF v_apv_id IS NULL THEN
            RAISE EXCEPTION '승인자 "%" 를 사용자에서 찾을 수 없습니다. 등록된 사용자 이름으로 입력하세요.',
                btrim(p_approver_nm) USING ERRCODE = '45000';
        END IF;
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


--
-- Name: PROCEDURE sp_ccp_verify_sign_u_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_checker_nm character varying, IN p_approver_nm character varying, IN p_confirm_nm character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_ccp_verify_sign_u_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_checker_nm character varying, IN p_approver_nm character varying, IN p_confirm_nm character varying) IS 'CCP 검증점검 점검자·승인자·확인 서명 스냅샷 — 저장 직후. 이름 매칭';


--
-- Name: sp_common_code_management_c_000(character varying, bigint, character varying, character varying, character varying, integer, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_common_code_management_c_000(IN p_co_cd character varying, IN p_idx bigint, IN p_main_cd character varying, IN p_sub_cd character varying, IN p_code_nm character varying, IN p_sort_no integer, IN p_ref1 character varying, IN p_ref2 character varying, IN p_use_yn character varying, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- 수정 대상의 시스템코드 여부. NULL이면 대상 없음
    v_sys_yn varchar(10);
    -- 중복 검사 건수
    v_cnt    int;
BEGIN
    -- 코드명이 비면(= 화면이 값을 빠뜨림) 기존 이름을 공백으로 덮어쓰게 되므로 막는다
    IF COALESCE(trim(p_code_nm), '') = '' THEN
        RAISE EXCEPTION '코드명은 필수입니다.' USING ERRCODE = '45000';
    END IF;

    -- p_idx가 NULL일 때(= 신규 행) 업무키 중복부터 막는다
    IF p_idx IS NULL THEN
        SELECT COUNT(*) INTO v_cnt FROM tbl_code
         WHERE co_cd = p_co_cd AND main_cd = p_main_cd AND sub_cd = p_sub_cd;
        IF v_cnt > 0 THEN
            RAISE EXCEPTION '이미 등록된 코드입니다: % / %', p_main_cd, p_sub_cd USING ERRCODE = '45000';
        END IF;

        INSERT INTO tbl_code(co_cd, main_cd, sub_cd, code_nm, sort_no, ref1, ref2, sys_yn, use_yn, ins_id, ins_dt)
        VALUES (p_co_cd, p_main_cd, p_sub_cd, p_code_nm, COALESCE(p_sort_no, 0),
                p_ref1, p_ref2, 'N', COALESCE(NULLIF(p_use_yn, ''), 'Y'), p_id, now());
        RETURN;
    END IF;

    -- 수정 대상 확인 — 자기 업체 행만 본다. 없으면 테넌트 위반이든 오타든 같은 메시지로 끝낸다
    SELECT sys_yn INTO v_sys_yn
      FROM tbl_code
     WHERE idx = p_idx AND co_cd = p_co_cd;
    IF v_sys_yn IS NULL THEN
        RAISE EXCEPTION '수정할 코드를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    -- 시스템코드일 때(= 시드 고정코드) 코드명·사용여부만 허용한다
    IF v_sys_yn IN ('Y', 'y', 'sys') THEN
        UPDATE tbl_code
           SET code_nm = p_code_nm,
               use_yn  = COALESCE(NULLIF(p_use_yn, ''), use_yn),
               upd_id  = p_id, upd_dt = now()
         WHERE co_cd = p_co_cd AND idx = p_idx;
        RETURN;
    END IF;

    UPDATE tbl_code
       SET code_nm = p_code_nm,
           sort_no = COALESCE(p_sort_no, sort_no),
           ref1    = p_ref1,
           ref2    = p_ref2,
           use_yn  = COALESCE(NULLIF(p_use_yn, ''), use_yn),
           upd_id  = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND idx = p_idx;
END$$;


--
-- Name: PROCEDURE sp_common_code_management_c_000(IN p_co_cd character varying, IN p_idx bigint, IN p_main_cd character varying, IN p_sub_cd character varying, IN p_code_nm character varying, IN p_sort_no integer, IN p_ref1 character varying, IN p_ref2 character varying, IN p_use_yn character varying, IN p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_common_code_management_c_000(IN p_co_cd character varying, IN p_idx bigint, IN p_main_cd character varying, IN p_sub_cd character varying, IN p_code_nm character varying, IN p_sort_no integer, IN p_ref1 character varying, IN p_ref2 character varying, IN p_use_yn character varying, IN p_id character varying) IS '공통코드 저장 — 신규는 업무키 중복 검사, 시스템코드는 코드명·사용여부만. 0000(데모식품) 저장 허용';


--
-- Name: sp_common_code_management_d_000(character varying, bigint); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_common_code_management_d_000(IN p_co_cd character varying, IN p_idx bigint)
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- 삭제 대상의 시스템코드 여부. NULL이면 대상 없음
    v_sys_yn varchar(10);
BEGIN
    SELECT sys_yn INTO v_sys_yn FROM tbl_code WHERE co_cd = p_co_cd AND idx = p_idx;
    IF v_sys_yn IS NULL THEN
        RAISE EXCEPTION '삭제할 코드를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF v_sys_yn IN ('Y', 'y', 'sys') THEN
        RAISE EXCEPTION '시스템 코드는 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    DELETE FROM tbl_code WHERE co_cd = p_co_cd AND idx = p_idx;
END$$;


--
-- Name: PROCEDURE sp_common_code_management_d_000(IN p_co_cd character varying, IN p_idx bigint); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_common_code_management_d_000(IN p_co_cd character varying, IN p_idx bigint) IS '공통코드 삭제 — 미존재·시스템코드 차단 후 삭제';


--
-- Name: sp_common_code_management_delete_blocker_r_000(character varying, bigint[]); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_common_code_management_delete_blocker_r_000(p_co_cd character varying, p_idxs bigint[]) RETURNS TABLE(ref_key character varying, target character varying)
    LANGUAGE sql
    AS $$
    SELECT c.sub_cd::varchar AS ref_key,
           '시스템 코드'::varchar AS target
      FROM tbl_code c
     WHERE c.co_cd = p_co_cd
       AND c.idx = ANY(p_idxs)
       AND c.sys_yn IN ('Y', 'y', 'sys')
     LIMIT 1;
$$;


--
-- Name: FUNCTION sp_common_code_management_delete_blocker_r_000(p_co_cd character varying, p_idxs bigint[]); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_common_code_management_delete_blocker_r_000(p_co_cd character varying, p_idxs bigint[]) IS '공통코드 삭제 차단 — 시스템코드는 삭제 불가. 위반 첫 건만 반환';


--
-- Name: sp_common_code_management_r_000(character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_common_code_management_r_000(p_co_cd character varying, p_main_cd character varying, p_code_nm character varying) RETURNS TABLE(idx bigint, co_cd character varying, main_cd character varying, sub_cd character varying, code_nm character varying, sort_no integer, sys_yn character varying, use_yn character varying)
    LANGUAGE sql
    AS $$
    SELECT c.idx, c.co_cd, c.main_cd, c.sub_cd, c.code_nm, c.sort_no, c.sys_yn, c.use_yn
      FROM tbl_code c
     -- 회사별 완전 고유 데이터 조회 — 0000 상속 없음
     WHERE c.co_cd = p_co_cd
       AND c.sub_cd = '*'
       -- 헤더 파라미터 — 부분 일치, 공백이면 전체
       AND c.main_cd LIKE CONCAT('%', COALESCE(p_main_cd, ''), '%')
       AND c.code_nm LIKE CONCAT('%', COALESCE(p_code_nm, ''), '%')
     ORDER BY c.main_cd, c.sort_no;
$$;


--
-- Name: FUNCTION sp_common_code_management_r_000(p_co_cd character varying, p_main_cd character varying, p_code_nm character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_common_code_management_r_000(p_co_cd character varying, p_main_cd character varying, p_code_nm character varying) IS '공통코드 대분류 목록 — sub_cd=*, co_cd 완전 고유, 헤더 대분류코드·명 LIKE';


--
-- Name: sp_common_code_management_r_001(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_common_code_management_r_001(p_co_cd character varying, p_main_cd character varying, p_sys_yn character varying, p_use_yn character varying) RETURNS TABLE(idx bigint, co_cd character varying, main_cd character varying, sub_cd character varying, code_nm character varying, sort_no integer, ref1 character varying, ref2 character varying, sys_yn character varying, use_yn character varying)
    LANGUAGE sql
    AS $$
    SELECT c.idx, c.co_cd, c.main_cd, c.sub_cd, c.code_nm, c.sort_no, c.ref1, c.ref2, c.sys_yn, c.use_yn
      FROM tbl_code c
     -- 회사별 완전 고유 데이터 조회
     WHERE c.co_cd = p_co_cd
       -- 대분류 헤더 — 값이 있으면 정확 일치
       AND (COALESCE(p_main_cd, '') = '' OR c.main_cd = p_main_cd)
       -- 대분류 헤더 행(sub_cd='*')은 세부 목록에서 제외
       AND c.sub_cd <> '*'
       AND (COALESCE(p_use_yn, '') = '' OR c.use_yn = p_use_yn)
       -- sys_yn은 과거 데이터가 Y/N과 sys/usr 두 표기를 함께 쓰므로 양쪽을 모두 허용한다
       AND (
            COALESCE(p_sys_yn, '') = ''
            OR (p_sys_yn IN ('Y', 'sys') AND c.sys_yn IN ('Y', 'sys'))
            OR (p_sys_yn IN ('N', 'usr') AND c.sys_yn IN ('N', 'usr'))
           )
     ORDER BY c.main_cd, c.sort_no, c.sub_cd;
$$;


--
-- Name: FUNCTION sp_common_code_management_r_001(p_co_cd character varying, p_main_cd character varying, p_sys_yn character varying, p_use_yn character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_common_code_management_r_001(p_co_cd character varying, p_main_cd character varying, p_sys_yn character varying, p_use_yn character varying) IS '공통코드 세부 목록 — 관리화면 시스템/사용자 그리드 + 전 화면 콤보 공용. co_cd 고유, main_cd 정확 일치';


--
-- Name: sp_department_management_c_000(character varying, bigint, character varying, character varying, character varying, integer, character varying, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_department_management_c_000(IN p_co_cd character varying, IN p_idx bigint, IN p_dept_cd character varying, IN p_dept_nm character varying, IN p_h_dept_cd character varying, IN p_sort_no integer, IN p_use_yn character varying, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- 업무키 중복 검사 건수
    v_cnt int;
BEGIN
    -- 부서명이 비면(= 화면이 값을 빠뜨림) 기존 이름을 공백으로 덮어쓰게 되므로 막는다
    IF COALESCE(trim(p_dept_nm), '') = '' THEN
        RAISE EXCEPTION '부서명은 필수입니다.' USING ERRCODE = '45000';
    END IF;

    IF p_idx IS NULL THEN
        SELECT COUNT(*) INTO v_cnt FROM tbl_dept WHERE co_cd = p_co_cd AND dept_cd = p_dept_cd;
        IF v_cnt > 0 THEN
            RAISE EXCEPTION '이미 등록된 부서코드입니다: %', p_dept_cd USING ERRCODE = '45000';
        END IF;

        INSERT INTO tbl_dept(co_cd, dept_cd, dept_nm, h_dept_cd, sort_no, use_yn, ins_id, ins_dt)
        VALUES (p_co_cd, p_dept_cd, p_dept_nm, NULLIF(p_h_dept_cd, ''),
                COALESCE(p_sort_no, 0), COALESCE(NULLIF(p_use_yn, ''), 'Y'), p_id, now());
    ELSE
        -- 자기 자신을 상위로 지정하면 트리가 끊긴다
        -- 상위가 비었을 때(= 최상위 지정)는 검사 대상이 아니다. 빈 값끼리 같다고 막으면 엉뚱한 문구가 나간다
        IF NULLIF(p_h_dept_cd, '') IS NOT NULL AND p_h_dept_cd = p_dept_cd THEN
            RAISE EXCEPTION '자기 자신을 상위 부서로 지정할 수 없습니다.' USING ERRCODE = '45000';
        END IF;

        UPDATE tbl_dept
           SET dept_nm   = p_dept_nm,
               h_dept_cd = NULLIF(p_h_dept_cd, ''),
               sort_no   = COALESCE(p_sort_no, sort_no),
               use_yn    = COALESCE(NULLIF(p_use_yn, ''), use_yn),
               upd_id    = p_id, upd_dt = now()
         WHERE co_cd = p_co_cd AND idx = p_idx;
        IF NOT FOUND THEN
            RAISE EXCEPTION '수정할 부서를 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
    END IF;
END$$;


--
-- Name: PROCEDURE sp_department_management_c_000(IN p_co_cd character varying, IN p_idx bigint, IN p_dept_cd character varying, IN p_dept_nm character varying, IN p_h_dept_cd character varying, IN p_sort_no integer, IN p_use_yn character varying, IN p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_department_management_c_000(IN p_co_cd character varying, IN p_idx bigint, IN p_dept_cd character varying, IN p_dept_nm character varying, IN p_h_dept_cd character varying, IN p_sort_no integer, IN p_use_yn character varying, IN p_id character varying) IS '부서 저장 — 신규는 코드 중복 검사, 수정은 자기참조 방지';


--
-- Name: sp_department_management_d_000(character varying, bigint); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_department_management_d_000(IN p_co_cd character varying, IN p_idx bigint)
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- 삭제 대상 부서코드. NULL이면 대상 없음
    v_dept_cd varchar(20);
    -- 참조 건수 검사용
    v_cnt     int;
BEGIN
    SELECT dept_cd INTO v_dept_cd FROM tbl_dept WHERE co_cd = p_co_cd AND idx = p_idx;
    IF v_dept_cd IS NULL THEN
        RAISE EXCEPTION '삭제할 부서를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    -- 사용자관리에서 이 부서를 직접 사용 중
    SELECT COUNT(*) INTO v_cnt FROM tbl_user u
     WHERE u.co_cd = p_co_cd AND u.dept_cd = v_dept_cd;
    IF v_cnt > 0 THEN
        RAISE EXCEPTION '사용자가 사용 중인 부서는 삭제할 수 없습니다: %', v_dept_cd USING ERRCODE = '45000';
    END IF;

    -- 하위 부서 트리에 사용자가 있으면 상위도 삭제 불가
    WITH RECURSIVE sub AS (
        SELECT c.dept_cd
          FROM tbl_dept c
         WHERE c.co_cd = p_co_cd AND c.h_dept_cd = v_dept_cd
        UNION ALL
        SELECT c2.dept_cd
          FROM tbl_dept c2
          INNER JOIN sub s ON s.dept_cd = c2.h_dept_cd
         WHERE c2.co_cd = p_co_cd
    )
    SELECT COUNT(*) INTO v_cnt
      FROM sub s
      INNER JOIN tbl_user u ON u.co_cd = p_co_cd AND u.dept_cd = s.dept_cd;
    IF v_cnt > 0 THEN
        RAISE EXCEPTION '하위 부서에 사용자가 있어 삭제할 수 없습니다: %', v_dept_cd USING ERRCODE = '45000';
    END IF;

    -- 직속 하위 부서가 남으면 트리가 끊긴다
    SELECT COUNT(*) INTO v_cnt FROM tbl_dept WHERE co_cd = p_co_cd AND h_dept_cd = v_dept_cd;
    IF v_cnt > 0 THEN
        RAISE EXCEPTION '하위 부서가 있어 삭제할 수 없습니다: %', v_dept_cd USING ERRCODE = '45000';
    END IF;

    DELETE FROM tbl_dept WHERE co_cd = p_co_cd AND idx = p_idx;
END$$;


--
-- Name: PROCEDURE sp_department_management_d_000(IN p_co_cd character varying, IN p_idx bigint); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_department_management_d_000(IN p_co_cd character varying, IN p_idx bigint) IS '부서 삭제 — 사용자·하위트리 사용자·하위 부서 차단 후 삭제';


--
-- Name: sp_department_management_delete_blocker_r_000(character varying, bigint[]); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_department_management_delete_blocker_r_000(p_co_cd character varying, p_idxs bigint[]) RETURNS TABLE(ref_key character varying, target character varying)
    LANGUAGE sql
    AS $$
    WITH tgt AS (
        SELECT d.dept_cd,
               -- 이 부서를 직접 쓰는 사용자
               EXISTS (SELECT 1 FROM tbl_user u
                        WHERE u.co_cd = p_co_cd AND u.dept_cd = d.dept_cd) AS has_user,
               -- 하위 트리 어딘가에 사용자가 있으면 상위도 지울 수 없다
               EXISTS (
                   WITH RECURSIVE sub AS (
                       SELECT c.dept_cd
                         FROM tbl_dept c
                        WHERE c.co_cd = p_co_cd AND c.h_dept_cd = d.dept_cd
                       UNION ALL
                       SELECT c2.dept_cd
                         FROM tbl_dept c2
                         INNER JOIN sub s ON s.dept_cd = c2.h_dept_cd
                        WHERE c2.co_cd = p_co_cd
                   )
                   SELECT 1 FROM sub s
                    INNER JOIN tbl_user u ON u.co_cd = p_co_cd AND u.dept_cd = s.dept_cd
               ) AS has_sub_user,
               -- 직속 하위 부서
               EXISTS (SELECT 1 FROM tbl_dept c
                        WHERE c.co_cd = p_co_cd AND c.h_dept_cd = d.dept_cd) AS has_child
          FROM tbl_dept d
         WHERE d.co_cd = p_co_cd
           AND d.idx = ANY(p_idxs)
    )
    SELECT t.dept_cd::varchar AS ref_key,
           (CASE WHEN t.has_user     THEN '사용자'
                 WHEN t.has_sub_user THEN '하위 부서 사용자'
                 ELSE                     '하위 부서'
            END)::varchar AS target
      FROM tgt t
     WHERE t.has_user OR t.has_sub_user OR t.has_child
     LIMIT 1;
$$;


--
-- Name: FUNCTION sp_department_management_delete_blocker_r_000(p_co_cd character varying, p_idxs bigint[]); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_department_management_delete_blocker_r_000(p_co_cd character varying, p_idxs bigint[]) IS '부서 삭제 차단 — 사용자·하위트리 사용자·하위 부서. 위반 첫 건만 반환';


--
-- Name: sp_department_management_r_000(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_department_management_r_000(p_co_cd character varying, p_dept_cd character varying, p_dept_nm character varying, p_use_yn character varying) RETURNS TABLE(idx bigint, co_cd character varying, dept_cd character varying, dept_nm character varying, h_dept_cd character varying, h_dept_nm character varying, sort_no integer, use_yn character varying)
    LANGUAGE sql
    AS $$
    SELECT d.idx, d.co_cd, d.dept_cd, d.dept_nm, d.h_dept_cd,
           p.dept_nm AS h_dept_nm,
           d.sort_no, d.use_yn
      FROM tbl_dept d
      -- 상위부서 — 최상위면 h_dept_nm은 NULL
      LEFT JOIN tbl_dept p
        ON p.co_cd = d.co_cd
       AND p.dept_cd = d.h_dept_cd
     WHERE d.co_cd = p_co_cd
       AND d.dept_cd LIKE CONCAT('%', COALESCE(p_dept_cd, ''), '%')
       AND d.dept_nm LIKE CONCAT('%', COALESCE(p_dept_nm, ''), '%')
       AND d.use_yn  LIKE CONCAT('%', COALESCE(p_use_yn,  ''), '%')
     -- 최상위 먼저, 그다음 정렬순서·코드 순 — FE 트리 조립 순서와 동일
     ORDER BY CASE WHEN COALESCE(d.h_dept_cd, '') = '' THEN 0 ELSE 1 END, d.sort_no, d.dept_cd;
$$;


--
-- Name: FUNCTION sp_department_management_r_000(p_co_cd character varying, p_dept_cd character varying, p_dept_nm character varying, p_use_yn character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_department_management_r_000(p_co_cd character varying, p_dept_cd character varying, p_dept_nm character varying, p_use_yn character varying) IS '부서 목록 — 상위부서명 self JOIN, 최상위 우선 트리 정렬, 헤더 코드·명·사용여부 LIKE';


--
-- Name: sp_draft_hwp_r_000(character varying, character varying, character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

DROP FUNCTION IF EXISTS sasshaccp.sp_draft_hwp_r_000(character varying, character varying, character varying, character varying, character varying, character varying, character varying);
DROP FUNCTION IF EXISTS sasshaccp.sp_draft_hwp_r_000(character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying);
CREATE OR REPLACE FUNCTION sasshaccp.sp_draft_hwp_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_tmpl_nm character varying, p_from_dt character varying, p_to_dt character varying, p_writer_id character varying, p_writer_nm character varying, p_title character varying DEFAULT NULL::character varying) RETURNS TABLE(doc_idx bigint, hdr_idx bigint, tmpl_cd character varying, tmpl_nm character varying, doc_no character varying, base_dt character varying, checker_nm character varying, writer_id character varying, writer_nm character varying, status character varying, row_cnt integer, ng_cnt integer, deviation_yn character varying, title character varying)
    LANGUAGE sql STABLE
    AS $$
    SELECT d.idx,
           -- HWP 는 하위 헤더 테이블이 없다 — 문서 idx 를 그대로 쓴다
           d.idx,
           d.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm, d.tmpl_cd)::varchar,
           d.doc_no,
           d.base_dt,
           COALESCE(u.user_nm, d.writer_id)::varchar,
           d.writer_id,
           COALESCE(u.user_nm, d.writer_id)::varchar,
           d.status,
           -- 본문 파일 수 — 목록에서 HWP 본문이 붙었는지 눈으로 본다
           (SELECT count(*)::int FROM tbl_document_file f
             WHERE f.co_cd = d.co_cd AND f.doc_idx = d.idx AND f.file_kind = 'HWP_SRC'),
           -- 미완료 개선조치 수 — 다른 draft 화면의 ng_cnt 자리와 같은 뜻
           (SELECT count(*)::int FROM tbl_corrective_action ca
             WHERE ca.co_cd = d.co_cd AND ca.src_doc_idx = d.idx AND ca.status <> 'DONE'),
           -- 이탈여부 — 완료 여부와 무관하게 개선조치가 붙어 있으면 Y
           (CASE WHEN EXISTS (
                    SELECT 1 FROM tbl_corrective_action ca2
                     WHERE ca2.co_cd = d.co_cd AND ca2.src_doc_idx = d.idx
                ) THEN 'Y' ELSE 'N' END)::varchar,
           d.title
      FROM tbl_document d
      -- 카탈로그는 자사 행만. 시드가 업체에 복사한다
      LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd AND t.co_cd = d.co_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = d.co_cd AND ct.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_user u ON u.co_cd = d.co_cd AND u.user_id = d.writer_id
     WHERE d.co_cd = p_co_cd
       AND d.del_yn = 'N'
       -- HWP 문서형만. HTML 전용 화면 문서는 이 화면 대상이 아니다
       AND d.doc_kind = 'HWP'
       AND (COALESCE(NULLIF(btrim(p_tmpl_cd), ''), '') = '' OR d.tmpl_cd ILIKE '%' || btrim(p_tmpl_cd) || '%')
       AND (COALESCE(NULLIF(btrim(p_tmpl_nm), ''), '') = ''
            OR COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm, '') ILIKE '%' || btrim(p_tmpl_nm) || '%')
       AND (COALESCE(NULLIF(btrim(p_from_dt), ''), '') = '' OR d.base_dt >= btrim(p_from_dt))
       AND (COALESCE(NULLIF(btrim(p_to_dt), ''), '') = '' OR d.base_dt <= btrim(p_to_dt))
       AND (COALESCE(NULLIF(btrim(p_writer_id), ''), '') = ''
            OR COALESCE(d.writer_id, '') ILIKE '%' || btrim(p_writer_id) || '%')
       AND (COALESCE(NULLIF(btrim(p_writer_nm), ''), '') = ''
            OR COALESCE(u.user_nm, '') ILIKE '%' || btrim(p_writer_nm) || '%')
       AND (COALESCE(NULLIF(btrim(p_title), ''), '') = '' OR COALESCE(d.title, '') ILIKE '%' || btrim(p_title) || '%')
     ORDER BY d.base_dt DESC, d.idx DESC;
$$;


--
-- Name: FUNCTION sp_draft_hwp_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_tmpl_nm character varying, p_from_dt character varying, p_to_dt character varying, p_writer_id character varying, p_writer_nm character varying, p_remark character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_draft_hwp_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_tmpl_nm character varying, p_from_dt character varying, p_to_dt character varying, p_writer_id character varying, p_writer_nm character varying, p_title character varying) IS 'HWP 작성 목록 — 제목은 tbl_document.title 부분검색. 130에서 이탈여부(deviation_yn) 추가';


--
-- Name: sp_draft_hwp_task_r_000(character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_draft_hwp_task_r_000(p_co_cd character varying, p_user_id character varying, p_base_dt character varying) RETURNS TABLE(task_idx bigint, tmpl_cd character varying, tmpl_nm character varying, base_dt character varying, due_dt character varying, due_time character varying, status character varying, doc_idx bigint)
    LANGUAGE sql STABLE
    AS $$
    SELECT t.idx,
           t.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, tp.tmpl_nm, t.tmpl_cd)::varchar,
           t.base_dt,
           t.due_dt,
           t.due_time,
           t.status,
           t.doc_idx
      FROM tbl_schedule_task t
      -- 카탈로그는 자사 행만. 시드가 업체에 복사한다
      JOIN tbl_template tp ON tp.tmpl_cd = t.tmpl_cd AND tp.co_cd = t.co_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = t.co_cd AND ct.tmpl_cd = t.tmpl_cd
     WHERE t.co_cd = p_co_cd
       AND t.base_dt = p_base_dt
       -- 아직 끝나지 않은 할일만 — 오늘 할일 화면과 같은 상태 집합
       AND t.status IN ('TODO', 'ING', 'LATE')
       -- HWP 문서형 주기만. HTML 전용 화면 주기는 이 팝업 대상이 아니다
       AND tp.doc_kind = 'HWP'
       -- 담당자 미지정이거나(= 누구나 처리) 내 할일일 때만
       AND (t.user_id IS NULL OR t.user_id = p_user_id)
     ORDER BY t.due_time NULLS LAST, t.idx;
$$;


--
-- Name: FUNCTION sp_draft_hwp_task_r_000(p_co_cd character varying, p_user_id character varying, p_base_dt character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_draft_hwp_task_r_000(p_co_cd character varying, p_user_id character varying, p_base_dt character varying) IS 'HWP 작성 행추가 팝업 — 오늘 할일 중 doc_kind=hwp 문서주기만';


--
-- Name: sp_hwp_template_management_c_000(character varying, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_hwp_template_management_c_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_tmpl_nm character varying, IN p_use_yn character varying, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_owner varchar(10);
BEGIN
    IF COALESCE(trim(p_tmpl_cd), '') = '' THEN
        RAISE EXCEPTION '양식코드는 필수입니다.' USING ERRCODE = '45000';
    END IF;
    IF COALESCE(trim(p_tmpl_nm), '') = '' THEN
        RAISE EXCEPTION '양식명은 필수입니다.' USING ERRCODE = '45000';
    END IF;

    -- 이미 등록된 사용양식일 때(= 수정) 양식명·사용유무만 바꾼다. sys_yn 은 UPDATE 대상이 아니다
    IF EXISTS (SELECT 1 FROM tbl_company_template WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd) THEN
        UPDATE tbl_company_template
           SET tmpl_nm_ovr = p_tmpl_nm,
               use_yn      = COALESCE(NULLIF(p_use_yn, ''), use_yn),
               upd_id      = p_id, upd_dt = now()
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
        RETURN;
    END IF;

    -- 카탈로그는 자사 행만. 없으면 이 회사 행을 만든다
    SELECT co_cd INTO v_owner FROM tbl_template WHERE tmpl_cd = p_tmpl_cd AND co_cd = p_co_cd;
    IF NOT FOUND THEN
        INSERT INTO tbl_template(co_cd, tmpl_cd, tmpl_nm, doc_kind, use_yn, impl_yn, ins_id, ins_dt)
        VALUES (p_co_cd, p_tmpl_cd, p_tmpl_nm, 'HWP', 'Y', 'Y', p_id, now());
    END IF;

    -- 사용자가 화면에서 만드는 양식은 항상 자사양식(usr)
    INSERT INTO tbl_company_template(co_cd, tmpl_cd, tmpl_nm_ovr, use_yn, sys_yn, ins_id, ins_dt)
    VALUES (p_co_cd, p_tmpl_cd, p_tmpl_nm, COALESCE(NULLIF(p_use_yn, ''), 'Y'), 'usr', p_id, now());

    -- 자사 HWP 양식은 채번 규칙이 없으면 문서 저장이 막힌다. 없을 때만 깐다
    INSERT INTO tbl_doc_no_rule (co_cd, tmpl_cd, prefix, date_fmt, seq_len, reset_cycle, ins_id, ins_dt)
    VALUES (p_co_cd, p_tmpl_cd, left(p_tmpl_cd, 20), 'YYYYMMDD', 3, 'D', p_id, now())
    ON CONFLICT (co_cd, tmpl_cd) DO NOTHING;
END$$;


--
-- Name: PROCEDURE sp_hwp_template_management_c_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_tmpl_nm character varying, IN p_use_yn character varying, IN p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_hwp_template_management_c_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_tmpl_nm character varying, IN p_use_yn character varying, IN p_id character varying) IS '사용양식 저장 — 신규는 sys_yn=usr 강제 + 자사 카탈로그 생성, 수정은 양식명·사용유무만(구분·코드 불변)';


--
-- Name: sp_hwp_template_management_ensure_default_000(character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--
-- 시드가 tbl_company_template_file 을 안 넣고 default_file_idx 만 덤프 번호로 남긴 구멍을 메운다.
-- 불러오기 목록·초기화가 호출한다. 카탈로그 표준 경로로 SYS 이력 1건을 만든다.
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_hwp_template_management_ensure_default_000(
    p_co_cd character varying,
    p_tmpl_cd character varying
) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- 기본 제공 이력 idx
    v_idx  bigint;
    -- 카탈로그 표준 경로 — HaccpTemplates/{tmpl_cd}/...
    v_path varchar(300);
    -- SYS 행을 맨 앞에 두기 위한 순번 (기존 업로드보다 작게)
    v_seq  int;
BEGIN
    IF COALESCE(p_co_cd, '') = '' OR COALESCE(p_tmpl_cd, '') = '' THEN
        RETURN NULL;
    END IF;

    -- default_file_idx 가 살아 있는 이력과 맞으면 그대로
    SELECT f.idx INTO v_idx
      FROM tbl_company_template ct
      JOIN tbl_company_template_file f
        ON f.idx = ct.default_file_idx
       AND f.co_cd = ct.co_cd AND f.tmpl_cd = ct.tmpl_cd AND f.del_yn = 'N'
     WHERE ct.co_cd = p_co_cd AND ct.tmpl_cd = p_tmpl_cd;
    IF v_idx IS NOT NULL THEN
        RETURN v_idx;
    END IF;

    -- 이력에 SYS 행이 있으면 그걸 기본으로 붙인다 (대소문자 무시)
    SELECT f.idx INTO v_idx
      FROM tbl_company_template_file f
     WHERE f.co_cd = p_co_cd AND f.tmpl_cd = p_tmpl_cd AND f.del_yn = 'N'
       AND lower(f.src_ty) = 'sys'
     ORDER BY f.file_seq
     LIMIT 1;
    IF v_idx IS NOT NULL THEN
        UPDATE tbl_company_template
           SET default_file_idx = v_idx
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
        RETURN v_idx;
    END IF;

    -- 카탈로그 표준 경로로 SYS 이력 1건
    SELECT t.form_path INTO v_path
      FROM tbl_company_template ct
      -- 카탈로그는 자사 행만. 시드가 업체에 복사한다
      JOIN tbl_template t ON t.tmpl_cd = ct.tmpl_cd AND t.co_cd = ct.co_cd
     WHERE ct.co_cd = p_co_cd AND ct.tmpl_cd = p_tmpl_cd;

    IF COALESCE(v_path, '') = '' THEN
        RETURN NULL;
    END IF;

    SELECT COALESCE(MIN(file_seq), 1) - 1 INTO v_seq
      FROM tbl_company_template_file
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;

    INSERT INTO tbl_company_template_file(co_cd, tmpl_cd, file_seq, file_nm, form_path, file_size, src_ty, ins_id)
    VALUES (
        p_co_cd, p_tmpl_cd, v_seq,
        regexp_replace(v_path, '^.*/', ''),
        v_path, NULL, 'SYS', 'system'
    )
    RETURNING idx INTO v_idx;

    UPDATE tbl_company_template
       SET default_file_idx = v_idx,
           current_file_idx = COALESCE(current_file_idx, v_idx)
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;

    RETURN v_idx;
END$$;


--
-- Name: FUNCTION sp_hwp_template_management_ensure_default_000(character varying, character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_hwp_template_management_ensure_default_000(character varying, character varying) IS '사용양식 기본 제공 파일 — 이력이 없거나 idx 가 끊겼으면 카탈로그 경로로 SYS 행을 만든다';


--
-- Name: sp_hwp_template_management_current_u_000(character varying, character varying, bigint, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_hwp_template_management_current_u_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_file_idx bigint, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- 적용 대상 이력 idx
    v_idx  bigint;
    -- 적용 대상 경로
    v_path varchar(300);
    -- 적용 대상 출처 — SYS면 표준 원본이라 자사 경로를 비운다
    v_src  varchar(10);
BEGIN
    v_idx := p_file_idx;
    -- 초기화일 때(= fileIdx 없음) 끊긴 default_file_idx 를 카탈로그로 다시 붙인다
    IF v_idx IS NULL THEN
        v_idx := sp_hwp_template_management_ensure_default_000(p_co_cd, p_tmpl_cd);
        IF v_idx IS NULL THEN
            RAISE EXCEPTION '초기화할 기본 양식이 없습니다.' USING ERRCODE = '45000';
        END IF;
    END IF;

    SELECT form_path, src_ty INTO v_path, v_src
      FROM tbl_company_template_file
     WHERE idx = v_idx AND co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND del_yn = 'N';
    IF NOT FOUND THEN
        RAISE EXCEPTION '적용할 양식 파일을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    UPDATE tbl_company_template
       SET form_path        = CASE WHEN lower(v_src) = 'sys' THEN NULL ELSE v_path END,
           current_file_idx = v_idx,
           upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    IF NOT FOUND THEN
        RAISE EXCEPTION '사용양식을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
END$$;


--
-- Name: PROCEDURE sp_hwp_template_management_current_u_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_file_idx bigint, IN p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_hwp_template_management_current_u_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_file_idx bigint, IN p_id character varying) IS '양식 파일 불러오기·초기화 — 이력 버전 적용 또는 기본 제공본 복원. 과거 이력은 지우지 않는다';


--
-- Name: sp_hwp_template_management_file_c_000(character varying, character varying, character varying, character varying, bigint, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_hwp_template_management_file_c_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_file_nm character varying, IN p_form_path character varying, IN p_file_size bigint, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- 다음 버전 순번
    v_seq int;
    -- 방금 만든 이력 idx
    v_idx bigint;
BEGIN
    IF COALESCE(p_co_cd, '') = '' OR COALESCE(p_tmpl_cd, '') = '' OR COALESCE(p_form_path, '') = '' THEN
        RAISE EXCEPTION '양식 파일 정보가 올바르지 않습니다.' USING ERRCODE = '45000';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM tbl_company_template WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd) THEN
        RAISE EXCEPTION '사용양식을 먼저 등록하세요.' USING ERRCODE = '45000';
    END IF;

    SELECT COALESCE(MAX(file_seq), 0) + 1 INTO v_seq
      FROM tbl_company_template_file WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;

    INSERT INTO tbl_company_template_file(co_cd, tmpl_cd, file_seq, file_nm, form_path, file_size, src_ty, ins_id)
    VALUES (            p_co_cd, p_tmpl_cd, v_seq,
            COALESCE(NULLIF(p_file_nm, ''), regexp_replace(p_form_path, '^.*/', '')),
            p_form_path, p_file_size, 'USR', p_id)
    RETURNING idx INTO v_idx;

    UPDATE tbl_company_template
       SET form_path        = p_form_path,
           current_file_idx = v_idx,
           -- 기본 파일이 없을 때(= 자사양식 최초 업로드)만 기본으로 지정한다
           default_file_idx = COALESCE(default_file_idx, v_idx),
           upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
END$$;


--
-- Name: PROCEDURE sp_hwp_template_management_file_c_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_file_nm character varying, IN p_form_path character varying, IN p_file_size bigint, IN p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_hwp_template_management_file_c_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_file_nm character varying, IN p_form_path character varying, IN p_file_size bigint, IN p_id character varying) IS '양식 파일 업로드 — 이력 append + 현재 적용 갱신. 기본 파일은 없을 때만 채운다(시스템 원본 보존)';


--
-- Name: sp_hwp_template_management_file_r_000(character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

-- 인자가 같다. LANGUAGE sql STABLE → plpgsql 로 바꾸려면 먼저 지운다 (REPLACE 는 휘발성을 안 바꾼다)
DROP FUNCTION IF EXISTS sasshaccp.sp_hwp_template_management_file_r_000(character varying, character varying);

CREATE OR REPLACE FUNCTION sasshaccp.sp_hwp_template_management_file_r_000(p_co_cd character varying, p_tmpl_cd character varying) RETURNS TABLE(idx bigint, file_seq integer, file_nm character varying, file_size bigint, src_ty character varying, current_yn character varying, default_yn character varying, ins_id character varying, ins_dt timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- 불러오기 팝업을 열 때 기본 제공 행이 없으면 카탈로그에서 한 줄 만든다
    PERFORM sp_hwp_template_management_ensure_default_000(p_co_cd, p_tmpl_cd);
    RETURN QUERY
    SELECT f.idx, f.file_seq, f.file_nm, f.file_size, upper(f.src_ty)::character varying,
           -- 현재 적용 파일일 때(= current_file_idx 일치) 그리드 문구
           (CASE WHEN f.idx = ct.current_file_idx THEN '현재적용' ELSE '' END)::character varying,
           -- 기본 제공 파일일 때(= default_file_idx 일치) 그리드 문구
           (CASE WHEN f.idx = ct.default_file_idx THEN '기본양식' ELSE '' END)::character varying,
           f.ins_id, f.ins_dt
      FROM tbl_company_template_file f
      JOIN tbl_company_template ct ON ct.co_cd = f.co_cd AND ct.tmpl_cd = f.tmpl_cd
     WHERE f.co_cd = p_co_cd AND f.tmpl_cd = p_tmpl_cd AND f.del_yn = 'N'
     ORDER BY f.file_seq DESC;
END$$;


--
-- Name: FUNCTION sp_hwp_template_management_file_r_000(p_co_cd character varying, p_tmpl_cd character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_hwp_template_management_file_r_000(p_co_cd character varying, p_tmpl_cd character varying) IS '양식 파일 이력 — 최근 업로드 우선. 기본 제공 행이 없으면 카탈로그에서 SYS 를 채운다. 현재적용·기본양식 문구는 CASE';


--
-- Name: sp_hwp_template_management_r_000(character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

-- 인자가 3 → 5 로 늘었다. CREATE OR REPLACE 만 하면 옛 3인자 함수가 남아
-- 매퍼가 어느 쪽을 부를지 모호해진다. 먼저 지운다 (sp_tbl_today_task_r_000 과 같은 방식)
DROP FUNCTION IF EXISTS sasshaccp.sp_hwp_template_management_r_000(character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION sasshaccp.sp_hwp_template_management_r_000(
    -- p_co_cd: JWT 회사코드 — 사용양식 범위. 테넌트 격리는 SP 책임이다
    p_co_cd character varying,
    -- p_tmpl_cd: 양식코드 부분검색. 비면 전체
    p_tmpl_cd character varying,
    -- p_tmpl_nm: 양식명 부분검색. 비면 전체
    p_tmpl_nm character varying,
    -- p_sys_yn: 구분 — sys(시스템제공) | usr(자사). 비면 전체
    p_sys_yn character varying DEFAULT NULL,
    -- p_use_yn: 사용여부 — Y | N. 비면 전체
    p_use_yn character varying DEFAULT NULL
) RETURNS TABLE(tmpl_cd character varying, tmpl_nm character varying, sys_yn character varying, doc_kind character varying, category_cd character varying, mng_no character varying, form_path character varying, form_file_nm character varying, use_yn character varying, default_file_idx bigint, current_file_idx bigint, file_hist_cnt integer)
    LANGUAGE sql STABLE
    AS $_$
    SELECT ct.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm),
           lower(CASE WHEN COALESCE(ct.sys_yn, 'sys') IN ('N', 'n', 'usr') THEN 'usr' ELSE 'sys' END),
           t.doc_kind,
           t.category_cd,
           t.mng_no,
           COALESCE(NULLIF(ct.form_path, ''), t.form_path),
           CASE
             WHEN COALESCE(NULLIF(ct.form_path, ''), t.form_path) IS NULL THEN NULL
             ELSE regexp_replace(COALESCE(NULLIF(ct.form_path, ''), t.form_path), '^.*/', '')
           END,
           ct.use_yn,
           ct.default_file_idx,
           ct.current_file_idx,
           (SELECT COUNT(*)::int
              FROM tbl_company_template_file f
             WHERE f.co_cd = ct.co_cd AND f.tmpl_cd = ct.tmpl_cd AND f.del_yn = 'N')
      FROM tbl_company_template ct
      -- 카탈로그는 자사 행만. 시드가 업체에 복사한다
      JOIN tbl_template t ON t.tmpl_cd = ct.tmpl_cd AND t.co_cd = ct.co_cd
     WHERE ct.co_cd = p_co_cd
       -- HWP 양식만 — 양식코드 범위를 박지 않는다.
       -- 예전에는 hwp_sys_001~027 정규식이었고, 028 부터는 등록해도 목록에 안 떴다
       AND t.doc_kind = 'HWP'
       AND ct.tmpl_cd LIKE CONCAT('%', COALESCE(p_tmpl_cd, ''), '%')
       AND COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm) LIKE CONCAT('%', COALESCE(p_tmpl_nm, ''), '%')
       -- 구분 — 화면이 보내는 값과 저장값의 표기를 맞춘다.
       -- ct.sys_yn 은 옛 'N'/'n' 도 남아 있어 목록 컬럼과 같은 규칙으로 정규화해서 비교한다
       AND (NULLIF(btrim(COALESCE(p_sys_yn, '')), '') IS NULL
            OR lower(CASE WHEN COALESCE(ct.sys_yn, 'sys') IN ('N', 'n', 'usr') THEN 'usr' ELSE 'sys' END)
               = lower(btrim(p_sys_yn)))
       -- 사용여부 — 비면 미사용까지 전부 본다. 이 화면은 미사용 양식도 다뤄야 한다
       AND (NULLIF(btrim(COALESCE(p_use_yn, '')), '') IS NULL
            OR upper(COALESCE(ct.use_yn, 'Y')) = upper(btrim(p_use_yn)))
     ORDER BY t.sort_no, ct.tmpl_cd;
$_$;


--
-- Name: FUNCTION sp_hwp_template_management_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_tmpl_nm character varying, p_sys_yn character varying, p_use_yn character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_hwp_template_management_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_tmpl_nm character varying, p_sys_yn character varying, p_use_yn character varying) IS '사용양식 목록 — doc_kind=HWP 전량(미사용 포함). 검색: 양식코드·양식명 부분일치, 구분(sys|usr)·사용여부(Y|N)는 비면 전체';


--
-- Name: sp_login_history_r_000(character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_login_history_r_000(p_co_cd character varying, p_from_dt character varying, p_to_dt character varying, p_user_id character varying, p_result_cd character varying) RETURNS TABLE(idx bigint, user_id character varying, user_nm character varying, sid character varying, login_dt timestamp without time zone, logout_dt timestamp without time zone, result_cd character varying, fail_reason character varying, ip_addr character varying, device_gbn character varying)
    LANGUAGE sql
    AS $$
    SELECT l.idx, l.user_id, u.user_nm, l.sid, l.login_dt, l.logout_dt,
           l.result_cd, l.fail_reason, l.ip_addr, l.device_gbn
      FROM tbl_login_log l
      -- 사용자명 — 없는 아이디로 실패한 로그도 남기려면 LEFT JOIN이어야 한다. 테넌트도 같이 본다
      LEFT JOIN tbl_user u ON u.co_cd = l.co_cd AND u.user_id = l.user_id
     WHERE l.co_cd = p_co_cd
       AND l.login_dt >= to_timestamp(p_from_dt, 'YYYYMMDD')
       AND l.login_dt <  to_timestamp(p_to_dt,   'YYYYMMDD') + interval '1 day'
       AND l.user_id   LIKE CONCAT('%', COALESCE(p_user_id,   ''), '%')
       AND l.result_cd LIKE CONCAT('%', COALESCE(p_result_cd, ''), '%')
     ORDER BY l.login_dt DESC;
$$;


--
-- Name: FUNCTION sp_login_history_r_000(p_co_cd character varying, p_from_dt character varying, p_to_dt character varying, p_user_id character varying, p_result_cd character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_login_history_r_000(p_co_cd character varying, p_from_dt character varying, p_to_dt character varying, p_user_id character varying, p_result_cd character varying) IS '로그인 이력 조회 — 기간·아이디·결과 필터, 최신순';


--
-- Name: sp_menu_management_c_000(character varying, bigint, character varying, character varying, character varying, character varying, integer, character varying, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_menu_management_c_000(IN p_co_cd character varying, IN p_idx bigint, IN p_menu_cd character varying, IN p_menu_nm character varying, IN p_h_menu_cd character varying, IN p_scrn_cd character varying, IN p_sort_no integer, IN p_use_yn character varying, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- 저장 후 자손 전파 기준이 되는 메뉴코드
    v_menu_cd varchar;
    -- 대문자로 정규화한 사용여부. Y·N 외 값은 Y로 본다
    v_use_yn  varchar;
BEGIN
    -- 메뉴명이 비면(= 화면이 값을 빠뜨림) 기존 이름을 공백으로 덮어써 사이드바가 비게 되므로 막는다
    IF COALESCE(trim(p_menu_nm), '') = '' THEN
        RAISE EXCEPTION '메뉴명은 필수입니다.' USING ERRCODE = '45000';
    END IF;

    v_use_yn := upper(COALESCE(NULLIF(trim(p_use_yn), ''), 'Y'));
    IF v_use_yn NOT IN ('Y', 'N') THEN v_use_yn := 'Y'; END IF;

    IF p_idx IS NULL THEN
        INSERT INTO tbl_menu(co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
        VALUES (p_co_cd, p_menu_cd, p_menu_nm, NULLIF(p_h_menu_cd, ''), NULLIF(p_scrn_cd, ''),
                COALESCE(p_sort_no, 0), v_use_yn, p_id, now());
        v_menu_cd := p_menu_cd;
    ELSE
        UPDATE tbl_menu
           SET menu_nm   = p_menu_nm,
               h_menu_cd = NULLIF(p_h_menu_cd, ''),
               scrn_cd   = NULLIF(p_scrn_cd, ''),
               sort_no   = COALESCE(p_sort_no, sort_no),
               use_yn    = v_use_yn,
               upd_id    = p_id, upd_dt = now()
         WHERE co_cd = p_co_cd AND idx = p_idx
        RETURNING menu_cd INTO v_menu_cd;
        IF NOT FOUND THEN
            RAISE EXCEPTION '수정할 메뉴를 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
    END IF;

    -- 사용여부 N일 때(= 미사용 전환) 모든 자손도 N — Y로 되돌릴 때는 자동 전파하지 않는다
    IF v_use_yn = 'N' AND COALESCE(v_menu_cd, '') <> '' THEN
        WITH RECURSIVE descendants AS (
            SELECT m.menu_cd
              FROM tbl_menu m
             WHERE m.co_cd = p_co_cd
               AND m.h_menu_cd = v_menu_cd
            UNION ALL
            SELECT c.menu_cd
              FROM tbl_menu c
              JOIN descendants d ON c.co_cd = p_co_cd AND c.h_menu_cd = d.menu_cd
        )
        UPDATE tbl_menu t
           SET use_yn = 'N', upd_id = p_id, upd_dt = now()
          FROM descendants d
         WHERE t.co_cd = p_co_cd
           AND t.menu_cd = d.menu_cd
           AND t.use_yn IS DISTINCT FROM 'N';
    END IF;
END$$;


--
-- Name: PROCEDURE sp_menu_management_c_000(IN p_co_cd character varying, IN p_idx bigint, IN p_menu_cd character varying, IN p_menu_nm character varying, IN p_h_menu_cd character varying, IN p_scrn_cd character varying, IN p_sort_no integer, IN p_use_yn character varying, IN p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_menu_management_c_000(IN p_co_cd character varying, IN p_idx bigint, IN p_menu_cd character varying, IN p_menu_nm character varying, IN p_h_menu_cd character varying, IN p_scrn_cd character varying, IN p_sort_no integer, IN p_use_yn character varying, IN p_id character varying) IS '메뉴 저장 — use_yn=N이면 자손 전체 N 전파. 메뉴코드는 화면에서 수정 불가';


--
-- Name: sp_menu_management_d_000(character varying, bigint); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_menu_management_d_000(IN p_co_cd character varying, IN p_idx bigint)
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- 삭제 대상 메뉴코드. NULL이면 대상 없음
    v_menu_cd varchar(50);
    -- 하위 메뉴 건수
    v_cnt     int;
BEGIN
    SELECT menu_cd INTO v_menu_cd FROM tbl_menu WHERE co_cd = p_co_cd AND idx = p_idx;
    IF v_menu_cd IS NULL THEN
        RAISE EXCEPTION '삭제할 메뉴를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    SELECT COUNT(*) INTO v_cnt FROM tbl_menu WHERE co_cd = p_co_cd AND h_menu_cd = v_menu_cd;
    IF v_cnt > 0 THEN
        RAISE EXCEPTION '하위 메뉴가 있어 삭제할 수 없습니다: %', v_menu_cd USING ERRCODE = '45000';
    END IF;

    DELETE FROM tbl_menu WHERE co_cd = p_co_cd AND idx = p_idx;
END$$;


--
-- Name: PROCEDURE sp_menu_management_d_000(IN p_co_cd character varying, IN p_idx bigint); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_menu_management_d_000(IN p_co_cd character varying, IN p_idx bigint) IS '메뉴 삭제 — 미존재·하위 메뉴 보유 차단 후 삭제';


--
-- Name: sp_menu_management_delete_blocker_r_000(character varying, bigint[]); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_menu_management_delete_blocker_r_000(p_co_cd character varying, p_idxs bigint[]) RETURNS TABLE(ref_key character varying, target character varying)
    LANGUAGE sql
    AS $$
    SELECT m.menu_cd::varchar AS ref_key,
           '하위 메뉴'::varchar AS target
      FROM tbl_menu m
     WHERE m.co_cd = p_co_cd
       AND m.idx = ANY(p_idxs)
       AND EXISTS (SELECT 1 FROM tbl_menu c
                    WHERE c.co_cd = p_co_cd AND c.h_menu_cd = m.menu_cd)
     LIMIT 1;
$$;


--
-- Name: FUNCTION sp_menu_management_delete_blocker_r_000(p_co_cd character varying, p_idxs bigint[]); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_menu_management_delete_blocker_r_000(p_co_cd character varying, p_idxs bigint[]) IS '메뉴 삭제 차단 — 하위 메뉴 보유 시 불가. 위반 첫 건만 반환';


--
-- Name: sp_menu_management_r_000(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_menu_management_r_000(p_co_cd character varying, p_menu_cd character varying, p_menu_nm character varying, p_use_yn character varying) RETURNS TABLE(idx bigint, menu_cd character varying, menu_nm character varying, h_menu_cd character varying, scrn_cd character varying, sort_no integer, use_yn character varying)
    LANGUAGE sql
    AS $$
    SELECT m.idx, m.menu_cd, m.menu_nm, m.h_menu_cd, m.scrn_cd, m.sort_no, m.use_yn
      FROM tbl_menu m
     WHERE m.co_cd = p_co_cd
       AND m.menu_cd LIKE CONCAT('%', COALESCE(p_menu_cd, ''), '%')
       AND m.menu_nm LIKE CONCAT('%', COALESCE(p_menu_nm, ''), '%')
       AND m.use_yn  LIKE CONCAT('%', COALESCE(p_use_yn,  ''), '%')
     -- 대·중·소 인코딩 sort_no 순 (1001 → 2101 → …) — FE 트리 조립 순서와 동일
     ORDER BY m.sort_no, m.menu_cd;
$$;


--
-- Name: FUNCTION sp_menu_management_r_000(p_co_cd character varying, p_menu_cd character varying, p_menu_nm character varying, p_use_yn character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_menu_management_r_000(p_co_cd character varying, p_menu_cd character varying, p_menu_nm character varying, p_use_yn character varying) IS '메뉴 관리 목록 — 권한 필터 없음. 헤더 메뉴코드·명·사용여부 LIKE, sort_no 순';


--
-- Name: sp_menu_nav_r_000(character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_menu_nav_r_000(p_co_cd character varying, p_usrgrp_cd character varying) RETURNS TABLE(idx bigint, menu_cd character varying, menu_nm character varying, h_menu_cd character varying, scrn_cd character varying, module_cd character varying, sort_no integer, read_yn character varying, write_yn character varying, modify_yn character varying, delete_yn character varying, print_yn character varying)
    LANGUAGE sql
    AS $$
    SELECT m.idx, m.menu_cd, m.menu_nm, m.h_menu_cd, m.scrn_cd, s.module_cd, m.sort_no,
           COALESCE(rs.read_yn,   'N'),
           COALESCE(rs.write_yn,  'N'),
           COALESCE(rs.modify_yn, 'N'),
           COALESCE(rs.delete_yn, 'N'),
           COALESCE(rs.print_yn,  'N')
      FROM tbl_menu m
      -- 화면 마스터 — module_cd 표기용
      LEFT JOIN tbl_screen s ON s.scrn_cd = m.scrn_cd
      -- 권한: 등록된 행이 없으면 접근 불가로 본다(기본 거부)
      LEFT JOIN tbl_role_screen rs
             ON rs.co_cd = m.co_cd AND rs.usrgrp_cd = p_usrgrp_cd AND rs.scrn_cd = m.scrn_cd
     WHERE m.co_cd  = p_co_cd
       AND m.use_yn = 'Y'
       -- 분류 노드(scrn_cd IS NULL)는 항상 통과, leaf는 조회권한이 있을 때만
       AND (m.scrn_cd IS NULL OR COALESCE(rs.read_yn, 'N') = 'Y')
     ORDER BY m.sort_no, m.menu_cd;
$$;


--
-- Name: FUNCTION sp_menu_nav_r_000(p_co_cd character varying, p_usrgrp_cd character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_menu_nav_r_000(p_co_cd character varying, p_usrgrp_cd character varying) IS '사이드바 메뉴 트리 — 사용중 메뉴만, leaf는 조회권한 Y일 때만. sort_no 순';


--
-- Name: sp_role_management_c_000(character varying, bigint, character varying, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_role_management_c_000(IN p_co_cd character varying, IN p_idx bigint, IN p_usrgrp_cd character varying, IN p_usrgrp_nm character varying, IN p_desc_rmk character varying, IN p_use_yn character varying, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- 업무키 중복 검사 건수
    v_cnt int;
BEGIN
    -- 권한그룹명이 비면(= 화면이 값을 빠뜨림) 기존 이름을 공백으로 덮어쓰게 되므로 막는다
    IF COALESCE(trim(p_usrgrp_nm), '') = '' THEN
        RAISE EXCEPTION '권한그룹명은 필수입니다.' USING ERRCODE = '45000';
    END IF;

    IF p_idx IS NULL THEN
        SELECT COUNT(*) INTO v_cnt FROM tbl_role WHERE co_cd = p_co_cd AND usrgrp_cd = p_usrgrp_cd;
        IF v_cnt > 0 THEN
            RAISE EXCEPTION '이미 등록된 권한그룹코드입니다: %', p_usrgrp_cd USING ERRCODE = '45000';
        END IF;

        INSERT INTO tbl_role(co_cd, usrgrp_cd, usrgrp_nm, desc_rmk, use_yn, ins_id, ins_dt)
        VALUES (p_co_cd, p_usrgrp_cd, p_usrgrp_nm, NULLIF(p_desc_rmk, ''),
                COALESCE(NULLIF(p_use_yn, ''), 'Y'), p_id, now());
    ELSE
        UPDATE tbl_role
           SET usrgrp_nm = p_usrgrp_nm,
               desc_rmk  = NULLIF(p_desc_rmk, ''),
               use_yn    = COALESCE(NULLIF(p_use_yn, ''), use_yn),
               upd_id    = p_id, upd_dt = now()
         WHERE co_cd = p_co_cd AND idx = p_idx;
        IF NOT FOUND THEN
            RAISE EXCEPTION '수정할 권한그룹을 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
    END IF;
END$$;


--
-- Name: PROCEDURE sp_role_management_c_000(IN p_co_cd character varying, IN p_idx bigint, IN p_usrgrp_cd character varying, IN p_usrgrp_nm character varying, IN p_desc_rmk character varying, IN p_use_yn character varying, IN p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_role_management_c_000(IN p_co_cd character varying, IN p_idx bigint, IN p_usrgrp_cd character varying, IN p_usrgrp_nm character varying, IN p_desc_rmk character varying, IN p_use_yn character varying, IN p_id character varying) IS '권한그룹 저장 — 신규는 코드 중복 검사, 수정은 명·설명·사용여부만';


--
-- Name: sp_role_management_d_000(character varying, bigint); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_role_management_d_000(IN p_co_cd character varying, IN p_idx bigint)
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- 삭제 대상 권한그룹코드. NULL이면 대상 없음
    v_usrgrp_cd varchar(20);
    -- 이 그룹을 쓰는 사용자 건수
    v_cnt       int;
BEGIN
    SELECT usrgrp_cd INTO v_usrgrp_cd FROM tbl_role WHERE co_cd = p_co_cd AND idx = p_idx;
    IF v_usrgrp_cd IS NULL THEN
        RAISE EXCEPTION '삭제할 권한그룹을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    SELECT COUNT(*) INTO v_cnt FROM tbl_user WHERE co_cd = p_co_cd AND usrgrp_cd = v_usrgrp_cd;
    IF v_cnt > 0 THEN
        RAISE EXCEPTION '사용자가 사용 중인 권한그룹은 삭제할 수 없습니다: %', v_usrgrp_cd USING ERRCODE = '45000';
    END IF;

    -- 그룹에 종속된 화면권한 설정을 먼저 정리한다
    DELETE FROM tbl_role_screen WHERE co_cd = p_co_cd AND usrgrp_cd = v_usrgrp_cd;
    DELETE FROM tbl_role        WHERE co_cd = p_co_cd AND idx = p_idx;
END$$;


--
-- Name: PROCEDURE sp_role_management_d_000(IN p_co_cd character varying, IN p_idx bigint); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_role_management_d_000(IN p_co_cd character varying, IN p_idx bigint) IS '권한그룹 삭제 — 사용자 참조 차단 후 화면권한까지 함께 삭제';


--
-- Name: sp_role_management_delete_blocker_r_000(character varying, bigint[]); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_role_management_delete_blocker_r_000(p_co_cd character varying, p_idxs bigint[]) RETURNS TABLE(ref_key character varying, target character varying)
    LANGUAGE sql
    AS $$
    SELECT r.usrgrp_cd::varchar AS ref_key,
           '사용자'::varchar AS target
      FROM tbl_role r
     WHERE r.co_cd = p_co_cd
       AND r.idx = ANY(p_idxs)
       AND EXISTS (SELECT 1 FROM tbl_user u
                    WHERE u.co_cd = p_co_cd AND u.usrgrp_cd = r.usrgrp_cd)
     LIMIT 1;
$$;


--
-- Name: FUNCTION sp_role_management_delete_blocker_r_000(p_co_cd character varying, p_idxs bigint[]); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_role_management_delete_blocker_r_000(p_co_cd character varying, p_idxs bigint[]) IS '권한그룹 삭제 차단 — 사용 중인 사용자 존재 시 불가. 위반 첫 건만 반환';


--
-- Name: sp_role_management_r_000(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_role_management_r_000(p_co_cd character varying, p_usrgrp_cd character varying, p_usrgrp_nm character varying, p_use_yn character varying) RETURNS TABLE(idx bigint, usrgrp_cd character varying, usrgrp_nm character varying, desc_rmk character varying, use_yn character varying)
    LANGUAGE sql
    AS $$
    SELECT r.idx, r.usrgrp_cd, r.usrgrp_nm, r.desc_rmk, r.use_yn
      FROM tbl_role r
     WHERE r.co_cd = p_co_cd
       AND r.usrgrp_cd LIKE CONCAT('%', COALESCE(p_usrgrp_cd, ''), '%')
       AND r.usrgrp_nm LIKE CONCAT('%', COALESCE(p_usrgrp_nm, ''), '%')
       AND r.use_yn    LIKE CONCAT('%', COALESCE(p_use_yn,    ''), '%')
     ORDER BY r.usrgrp_cd;
$$;


--
-- Name: FUNCTION sp_role_management_r_000(p_co_cd character varying, p_usrgrp_cd character varying, p_usrgrp_nm character varying, p_use_yn character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_role_management_r_000(p_co_cd character varying, p_usrgrp_cd character varying, p_usrgrp_nm character varying, p_use_yn character varying) IS '권한그룹 목록 — 테넌트 범위 + 헤더 코드·명·사용여부 LIKE';


--
-- Name: sp_role_management_screen_c_000(character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_role_management_screen_c_000(IN p_co_cd character varying, IN p_usrgrp_cd character varying, IN p_scrn_cd character varying, IN p_read_yn character varying, IN p_write_yn character varying, IN p_modify_yn character varying, IN p_delete_yn character varying, IN p_print_yn character varying, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO tbl_role_screen(co_cd, usrgrp_cd, scrn_cd, read_yn, write_yn, modify_yn, delete_yn, print_yn, ins_id, ins_dt)
    VALUES (p_co_cd, p_usrgrp_cd, p_scrn_cd,
            COALESCE(NULLIF(p_read_yn,   ''), 'N'),
            COALESCE(NULLIF(p_write_yn,  ''), 'N'),
            COALESCE(NULLIF(p_modify_yn, ''), 'N'),
            COALESCE(NULLIF(p_delete_yn, ''), 'N'),
            COALESCE(NULLIF(p_print_yn,  ''), 'N'),
            p_id, now())
    ON CONFLICT (co_cd, usrgrp_cd, scrn_cd) DO UPDATE SET
        read_yn   = EXCLUDED.read_yn,
        write_yn  = EXCLUDED.write_yn,
        modify_yn = EXCLUDED.modify_yn,
        delete_yn = EXCLUDED.delete_yn,
        print_yn  = EXCLUDED.print_yn,
        upd_id    = p_id,
        upd_dt    = now();
END$$;


--
-- Name: PROCEDURE sp_role_management_screen_c_000(IN p_co_cd character varying, IN p_usrgrp_cd character varying, IN p_scrn_cd character varying, IN p_read_yn character varying, IN p_write_yn character varying, IN p_modify_yn character varying, IN p_delete_yn character varying, IN p_print_yn character varying, IN p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_role_management_screen_c_000(IN p_co_cd character varying, IN p_usrgrp_cd character varying, IN p_scrn_cd character varying, IN p_read_yn character varying, IN p_write_yn character varying, IN p_modify_yn character varying, IN p_delete_yn character varying, IN p_print_yn character varying, IN p_id character varying) IS '화면 권한 업서트 — 변경 행 단위 반복 호출용';


--
-- Name: sp_role_management_screen_r_000(character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_role_management_screen_r_000(p_co_cd character varying, p_usrgrp_cd character varying) RETURNS TABLE(idx bigint, scrn_cd character varying, scrn_nm character varying, module_cd character varying, read_yn character varying, write_yn character varying, modify_yn character varying, delete_yn character varying, print_yn character varying, sort_no integer)
    LANGUAGE sql
    AS $$
    SELECT rs.idx, s.scrn_cd, s.scrn_nm, s.module_cd,
           COALESCE(rs.read_yn,   'N'),
           COALESCE(rs.write_yn,  'N'),
           COALESCE(rs.modify_yn, 'N'),
           COALESCE(rs.delete_yn, 'N'),
           COALESCE(rs.print_yn,  'N'),
           s.sort_no
      FROM tbl_screen s
      -- 설정이 없으면 전 권한 N — 기본 거부
      LEFT JOIN tbl_role_screen rs
             ON rs.co_cd = p_co_cd AND rs.usrgrp_cd = p_usrgrp_cd AND rs.scrn_cd = s.scrn_cd
     WHERE s.use_yn = 'Y'
     ORDER BY s.sort_no, s.scrn_cd;
$$;


--
-- Name: FUNCTION sp_role_management_screen_r_000(p_co_cd character varying, p_usrgrp_cd character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_role_management_screen_r_000(p_co_cd character varying, p_usrgrp_cd character varying) IS '권한그룹별 화면 권한 — 미설정 화면도 N으로 채워 전체 목록 반환';


--
-- Name: sp_schedule_cycle_management_c_000(character varying, jsonb, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_schedule_cycle_management_c_000(IN p_co_cd character varying, IN p_payload jsonb, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_tmpl_cd  varchar(40) := trim(COALESCE(p_payload ->> 'tmplCd', ''));
    v_cycle    varchar(1)  := upper(trim(COALESCE(p_payload ->> 'cycleCd', '')));
    v_nonwork  varchar(10) := lower(trim(COALESCE(NULLIF(p_payload ->> 'nonworkRule', ''), 'keep')));
    v_base     varchar(8)  := regexp_replace(COALESCE(p_payload ->> 'baseDt', ''), '[^0-9]', '', 'g');
    v_due      varchar(4)  := regexp_replace(COALESCE(p_payload ->> 'dueTime', ''), '[^0-9]', '', 'g');
    v_use      varchar(1);
    -- 결재선 — 빈값이면 사용양식에서 뗀다(NULL). 상신은 COALESCE(..., 'DEFAULT')
    v_appr     varchar(20) := NULLIF(trim(COALESCE(p_payload ->> 'apprLineCd', '')), '');
    -- 레거시 호환 컬럼 — 상세에서 파생한다
    v_week     varchar(20);
    v_mday     int;
    v_mno      int;
BEGIN
    IF v_tmpl_cd = '' THEN
        RAISE EXCEPTION '주기를 설정할 양식을 선택하세요.' USING ERRCODE = '45000';
    END IF;
    -- 대문자 주기 도메인 — E(비정기)는 예정일을 만들지 않는다
    IF v_cycle NOT IN ('D', 'W', 'M', 'Q', 'H', 'Y', 'E') THEN
        RAISE EXCEPTION '주기(매일/매주/매월/분기/반기/매년/비정기)를 선택하세요.' USING ERRCODE = '45000';
    END IF;
    IF v_nonwork NOT IN ('keep', 'prev', 'next') THEN
        RAISE EXCEPTION '비영업일 처리 방식이 올바르지 않습니다.' USING ERRCODE = '45000';
    END IF;
    IF length(v_base) <> 8 THEN
        RAISE EXCEPTION '관리 시작일을 입력하세요.' USING ERRCODE = '45000';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM tbl_company_template
         WHERE co_cd = p_co_cd AND tmpl_cd = v_tmpl_cd AND upper(COALESCE(use_yn, 'N')) = 'Y'
    ) THEN
        RAISE EXCEPTION '사용 중인 양식만 문서주기를 설정할 수 있습니다.' USING ERRCODE = '45000';
    END IF;
    -- 결재선이 있을 때(= 화면에서 고른 값) 자사·사용중만 받는다
    IF v_appr IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM tbl_approval_line
         WHERE co_cd = p_co_cd AND appr_line_cd = v_appr AND upper(COALESCE(use_yn, 'N')) = 'Y'
    ) THEN
        RAISE EXCEPTION '사용 중인 결재선을 선택하세요.' USING ERRCODE = '45000';
    END IF;

    IF length(v_due) = 3 THEN v_due := lpad(v_due, 4, '0'); END IF;
    IF v_due = '' THEN v_due := '1800'; END IF;
    v_use := CASE lower(COALESCE(NULLIF(p_payload ->> 'useYn', ''), 'y')) WHEN 'n' THEN 'N' ELSE 'Y' END;

    -- 상세 전량 교체 — 부분 수정 대신 통째로 갈아 끼워 남은 행이 규칙을 오염시키지 않게 한다
    DELETE FROM tbl_schedule_rule_detail WHERE co_cd = p_co_cd AND tmpl_cd = v_tmpl_cd;
    INSERT INTO tbl_schedule_rule_detail(co_cd, tmpl_cd, seq, detail_ty, val1, val2)
    SELECT p_co_cd, v_tmpl_cd, d.ord,
           lower(trim(d.value ->> 'detailTy')),
           NULLIF(d.value ->> 'val1', '')::int,
           NULLIF(d.value ->> 'val2', '')::int
      FROM jsonb_array_elements(COALESCE(p_payload -> 'details', '[]'::jsonb)) WITH ORDINALITY AS d(value, ord)
     WHERE COALESCE(trim(d.value ->> 'detailTy'), '') <> '';

    SELECT string_agg(val1::text, ',' ORDER BY val1) INTO v_week
      FROM tbl_schedule_rule_detail
     WHERE co_cd = p_co_cd AND tmpl_cd = v_tmpl_cd AND detail_ty = 'week-day' AND val1 IS NOT NULL;
    SELECT MIN(COALESCE(val2, val1)) INTO v_mday
      FROM tbl_schedule_rule_detail
     WHERE co_cd = p_co_cd AND tmpl_cd = v_tmpl_cd AND detail_ty <> 'week-day';
    SELECT MIN(val1) INTO v_mno
      FROM tbl_schedule_rule_detail
     WHERE co_cd = p_co_cd AND tmpl_cd = v_tmpl_cd AND detail_ty = 'year-month';

    INSERT INTO tbl_schedule_rule(
        co_cd, tmpl_cd, rule_seq, cycle_cd, nonwork_rule, week_days, month_day, month_no,
        due_time, dept_cd, user_id, use_yn, base_dt, ins_id, ins_dt
    ) VALUES (
        p_co_cd, v_tmpl_cd, 1, v_cycle, v_nonwork, v_week, v_mday, v_mno,
        v_due, NULLIF(p_payload ->> 'deptCd', ''), NULLIF(p_payload ->> 'userId', ''),
        v_use, v_base, p_id, now()
    )
    ON CONFLICT (co_cd, tmpl_cd) DO UPDATE SET
        cycle_cd     = EXCLUDED.cycle_cd,
        nonwork_rule = EXCLUDED.nonwork_rule,
        week_days    = EXCLUDED.week_days,
        month_day    = EXCLUDED.month_day,
        month_no     = EXCLUDED.month_no,
        due_time     = EXCLUDED.due_time,
        dept_cd      = EXCLUDED.dept_cd,
        user_id      = EXCLUDED.user_id,
        use_yn       = EXCLUDED.use_yn,
        base_dt      = EXCLUDED.base_dt,
        upd_id       = p_id,
        upd_dt       = now();

    -- 결재선은 주기 행이 아니라 사용양식에 둔다 — 문서 상신이 이미 이 컬럼을 읽는다
    UPDATE tbl_company_template
       SET appr_line_cd = v_appr, upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = v_tmpl_cd;
END$$;


--
-- Name: PROCEDURE sp_schedule_cycle_management_c_000(IN p_co_cd character varying, IN p_payload jsonb, IN p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_schedule_cycle_management_c_000(IN p_co_cd character varying, IN p_payload jsonb, IN p_id character varying) IS '문서주기 저장 — 양식당 1건 업서트 + 반복 상세 전량 교체 + 사용양식 결재선. D/W/M/Q/H/Y/E 허용';


--
-- Name: sp_schedule_cycle_management_d_000(character varying, character varying, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_schedule_cycle_management_d_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- 오늘 — 이 날짜 이후의 미작성 예정일만 지운다
    v_today varchar(8) := to_char(current_date, 'YYYYMMDD');
BEGIN
    IF COALESCE(p_tmpl_cd, '') = '' THEN
        RAISE EXCEPTION '삭제할 문서주기를 선택하세요.' USING ERRCODE = '45000';
    END IF;

    DELETE FROM tbl_schedule_task
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd
       AND base_dt > v_today
       -- 작성 시작 전(doc_idx 없음) TODO 만 — 진행·승인분은 보존
       AND status = 'TODO' AND doc_idx IS NULL;

    DELETE FROM tbl_schedule_rule_detail WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    DELETE FROM tbl_schedule_rule WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    IF NOT FOUND THEN
        RAISE EXCEPTION '삭제할 문서주기를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
END$$;


--
-- Name: PROCEDURE sp_schedule_cycle_management_d_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_schedule_cycle_management_d_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_id character varying) IS '문서주기 삭제 — 규칙·상세 삭제 + 미래 미작성 예정일 정리(과거·진행분 보존)';


--
-- Name: sp_schedule_cycle_management_form_r_000(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_schedule_cycle_management_form_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_tmpl_nm character varying, p_use_yn character varying) RETURNS TABLE(tmpl_cd character varying, tmpl_nm character varying, sys_yn character varying, doc_kind character varying, cycle_cd character varying, rule_yn character varying, use_yn character varying, appr_line_cd character varying, appr_line_nm character varying)
    LANGUAGE sql STABLE
    AS $_$
    SELECT ct.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm),
           lower(CASE WHEN COALESCE(ct.sys_yn, 'sys') IN ('N', 'n', 'usr') THEN 'usr' ELSE 'sys' END),
           t.doc_kind,
           r.cycle_cd,
           CASE WHEN r.idx IS NULL THEN 'N' ELSE 'Y' END,
           upper(COALESCE(ct.use_yn, 'N')),
           ct.appr_line_cd,
           al.appr_line_nm
      FROM tbl_company_template ct
      -- 카탈로그는 자사 행만. 시드가 업체에 복사한다
      JOIN tbl_template t ON t.tmpl_cd = ct.tmpl_cd AND t.co_cd = ct.co_cd
      LEFT JOIN tbl_schedule_rule r ON r.co_cd = ct.co_cd AND r.tmpl_cd = ct.tmpl_cd
      LEFT JOIN tbl_approval_line al ON al.co_cd = ct.co_cd AND al.appr_line_cd = ct.appr_line_cd
     WHERE ct.co_cd = p_co_cd
       /*
        * 복사 원본은 뺀다 — 주기를 걸 대상이 아니다. 자사 양식만 남긴다.
        *
        * 지금 원본은 `*_000` 으로 이름이 통일돼 있어 규칙 하나로 걸린다.
        * 다만 이름 규칙이 생기기 전에 만든 원본이 둘 있다 —
        *   html_sys_001 → 일반위생·공정점검 (sp_tbl_html_hyg_prc_ver_copy_c_000 이 읽는다)
        *   html_sys_006 → CCP 검증점검표     (sp_tbl_html_ccp_chk_ver_copy_c_000 이 읽는다)
        * 이 둘은 지우면 복사가 죽어서 남겨 두는데, 목록에는 나오면 안 된다.
        * 새 양식이 이 이름으로 생기지 않으므로 닫힌 집합이다 —
        * 「양식코드를 나열하지 않는다」가 막으려는 「늘어나는 목록」이 아니다.
        */
       AND ct.tmpl_cd NOT LIKE '%\_000'
       AND ct.tmpl_cd NOT IN ('html_sys_001', 'html_sys_006')
       /*
        * HTML 은 지면 버전이 있어야 양식관리·작성·삭제가 된다.
        * 카탈로그만 있는 행은 주기 목록에 뜨고 양식관리에는 없어 지울 수도 없다.
        * HWP 는 파일 경로가 있으면 되므로 그대로 둔다.
        */
       AND (
            t.doc_kind <> 'HTML'
            OR EXISTS (
                 SELECT 1 FROM tbl_html_hyg_prc_ver v
                  WHERE v.co_cd = ct.co_cd AND v.tmpl_cd = ct.tmpl_cd AND v.use_yn = 'Y'
               )
            OR EXISTS (
                 SELECT 1 FROM tbl_html_ccp_chk_ver v
                  WHERE v.co_cd = ct.co_cd AND v.tmpl_cd = ct.tmpl_cd AND v.use_yn = 'Y'
               )
            OR EXISTS (
                 SELECT 1 FROM tbl_html_ccp_pkg_ver v
                  WHERE v.co_cd = ct.co_cd AND v.tmpl_cd = ct.tmpl_cd AND v.use_yn = 'Y'
               )
            OR EXISTS (
                 SELECT 1 FROM tbl_html_ccp_htg_ver v
                  WHERE v.co_cd = ct.co_cd AND v.tmpl_cd = ct.tmpl_cd AND v.use_yn = 'Y'
               )
            OR EXISTS (
                 SELECT 1 FROM tbl_html_ccp_mtl_ver v
                  WHERE v.co_cd = ct.co_cd AND v.tmpl_cd = ct.tmpl_cd AND v.use_yn = 'Y'
               )
           )
       AND (
            COALESCE(NULLIF(btrim(p_use_yn), ''), '') = ''
            OR upper(COALESCE(ct.use_yn, 'N')) = upper(btrim(p_use_yn))
           )
       AND ct.tmpl_cd LIKE CONCAT('%', COALESCE(p_tmpl_cd, ''), '%')
       AND COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm) LIKE CONCAT('%', COALESCE(p_tmpl_nm, ''), '%')
     ORDER BY t.sort_no, ct.tmpl_cd;
$_$;


--
-- Name: FUNCTION sp_schedule_cycle_management_form_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_tmpl_nm character varying, p_use_yn character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_schedule_cycle_management_form_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_tmpl_nm character varying, p_use_yn character varying) IS '문서주기관리 좌측 — 자사 양식만. 복사 원본 숨김. HTML 은 사용 중인 지면 버전이 있는 것만';


--
-- Name: sp_schedule_cycle_management_r_000(character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_schedule_cycle_management_r_000(p_co_cd character varying, p_tmpl_cd character varying) RETURNS TABLE(tmpl_cd character varying, tmpl_nm character varying, base_dt character varying, cycle_cd character varying, nonwork_rule character varying, due_time character varying, dept_cd character varying, dept_nm character varying, user_id character varying, user_nm character varying, use_yn character varying, appr_line_cd character varying, appr_line_nm character varying, details jsonb)
    LANGUAGE sql STABLE
    AS $$
    SELECT r.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm),
           r.base_dt, r.cycle_cd, r.nonwork_rule, r.due_time,
           r.dept_cd, d.dept_nm,
           r.user_id, u.user_nm,
           r.use_yn,
           ct.appr_line_cd, al.appr_line_nm,
           COALESCE((
             SELECT jsonb_agg(jsonb_build_object('detailTy', x.detail_ty, 'val1', x.val1, 'val2', x.val2)
                              ORDER BY x.seq)
               FROM tbl_schedule_rule_detail x
              WHERE x.co_cd = r.co_cd AND x.tmpl_cd = r.tmpl_cd
           ), '[]'::jsonb)
      FROM tbl_schedule_rule r
      -- 카탈로그는 자사 행만. 시드가 업체에 복사한다
      JOIN tbl_template t ON t.tmpl_cd = r.tmpl_cd AND t.co_cd = r.co_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = r.co_cd AND ct.tmpl_cd = r.tmpl_cd
      LEFT JOIN tbl_approval_line al ON al.co_cd = r.co_cd AND al.appr_line_cd = ct.appr_line_cd
      LEFT JOIN tbl_dept d ON d.co_cd = r.co_cd AND d.dept_cd = r.dept_cd
      LEFT JOIN tbl_user u ON u.co_cd = r.co_cd AND u.user_id = r.user_id
     WHERE r.co_cd = p_co_cd AND r.tmpl_cd = p_tmpl_cd;
$$;


--
-- Name: FUNCTION sp_schedule_cycle_management_r_000(p_co_cd character varying, p_tmpl_cd character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_schedule_cycle_management_r_000(p_co_cd character varying, p_tmpl_cd character varying) IS '문서주기 단건 — 주기·담당 + 사용양식 결재선 + 반복 상세 jsonb';


--
-- Name: sp_screen_usage_statistics_r_000(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_screen_usage_statistics_r_000(p_co_cd character varying, p_from_dt character varying, p_to_dt character varying, p_scrn_cd character varying) RETURNS TABLE(stat_dt character varying, scrn_cd character varying, menu_cd character varying, menu_nm character varying, scrn_nm character varying, module_cd character varying, pv_cnt integer, uv_cnt integer, sess_cnt integer, ip_cnt integer, avg_stay_sec numeric, max_stay_sec integer)
    LANGUAGE sql
    AS $$
    SELECT t.stat_dt,
           t.scrn_cd,
           m.menu_cd,
           -- 메뉴 → 화면명 → 화면코드 순으로 표시명을 정한다
           COALESCE(m.menu_nm, s.scrn_nm, t.scrn_cd) AS menu_nm,
           s.scrn_nm,
           s.module_cd,
           t.pv_cnt, t.uv_cnt, t.sess_cnt, t.ip_cnt,
           t.avg_stay_sec, t.max_stay_sec
      FROM tbl_view_stat_daily t
      -- 화면 마스터 — 화면명·모듈 표기
      LEFT JOIN tbl_screen s ON s.scrn_cd = t.scrn_cd
      -- 같은 화면이 여러 메뉴에 붙을 수 있어 정렬 우선 1건만 취한다. 메뉴명도 테넌트 범위로 제한한다
      LEFT JOIN LATERAL (
          SELECT mm.menu_cd, mm.menu_nm
            FROM tbl_menu mm
           WHERE mm.co_cd = p_co_cd
             AND mm.scrn_cd = t.scrn_cd
           ORDER BY mm.sort_no NULLS LAST, mm.menu_cd
           LIMIT 1
      ) m ON TRUE
     WHERE t.co_cd = p_co_cd
       AND t.stat_dt BETWEEN p_from_dt AND p_to_dt
       AND (COALESCE(p_scrn_cd, '') = '' OR t.scrn_cd = p_scrn_cd)
     ORDER BY t.stat_dt DESC, t.scrn_cd;
$$;


--
-- Name: FUNCTION sp_screen_usage_statistics_r_000(p_co_cd character varying, p_from_dt character varying, p_to_dt character varying, p_scrn_cd character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_screen_usage_statistics_r_000(p_co_cd character varying, p_from_dt character varying, p_to_dt character varying, p_scrn_cd character varying) IS '화면 이용 통계 조회 — 집계일·메뉴·PV/UV/세션/IP, 최신순';


--
-- Name: sp_tbl_approval_line_c_000(character varying, jsonb, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_approval_line_c_000(IN p_co_cd character varying, IN p_payload jsonb, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_cd varchar(20) := trim(COALESCE(p_payload ->> 'apprLineCd', ''));
    v_nm varchar(100) := trim(COALESCE(p_payload ->> 'apprLineNm', ''));
    -- 신규 행인가 — 화면이 알려 준다. 형제 SP 의 p_idx 자리와 같은 뜻이다
    v_new boolean := upper(COALESCE(p_payload ->> 'newYn', 'N')) = 'Y';
    v_step jsonb;
    v_step_no int;
    v_role varchar(20);
    v_use varchar(1);
BEGIN
    IF v_cd = '' OR v_nm = '' THEN
        RAISE EXCEPTION '결재선 코드와 결재선명은 필수입니다.' USING ERRCODE = '45000';
    END IF;
    IF jsonb_typeof(COALESCE(p_payload -> 'steps', '[]'::jsonb)) <> 'array'
       OR jsonb_array_length(COALESCE(p_payload -> 'steps', '[]'::jsonb)) = 0 THEN
        RAISE EXCEPTION '결재 단계는 한 건 이상 입력하세요.' USING ERRCODE = '45000';
    END IF;

    /*
     * 신규 행일 때(= 화면에서 행추가로 만든 줄) 업무키 중복을 막는다.
     *
     * 아래 UPSERT 는 기존 결재선 **수정**을 위한 것인데, 신규 행에 이미 있는 코드를 치면
     * 그 결재선의 이름을 덮고 **바로 아래에서 단계를 통째로 지운 뒤** 새 줄의 단계로 갈아 끼웠다.
     * 그 결재선을 쓰는 모든 양식의 결재가 누구에게 가는지가 바뀌고 되돌릴 자료가 없다.
     *
     * 형제 셋(sp_common_code_management_c_000·sp_department_management_c_000·
     * sp_role_management_c_000)은 신규일 때 같은 검사를 한다. 기준을 맞춘다.
     * 그쪽은 p_idx 유무로 신규를 갈랐는데 이 화면은 idx 를 안 받아 payload 의 newYn 으로 받는다.
     */
    IF v_new AND EXISTS (
        SELECT 1 FROM tbl_approval_line
         WHERE co_cd = p_co_cd AND appr_line_cd = v_cd
    ) THEN
        RAISE EXCEPTION '이미 등록된 결재선 코드입니다: %', v_cd USING ERRCODE = '45000';
    END IF;

    INSERT INTO tbl_approval_line(co_cd, appr_line_cd, appr_line_nm, use_yn, ins_id, ins_dt)
    VALUES (p_co_cd, v_cd, v_nm, COALESCE(NULLIF(p_payload ->> 'useYn', ''), 'Y'), p_id, now())
    ON CONFLICT (co_cd, appr_line_cd) DO UPDATE SET
        appr_line_nm = EXCLUDED.appr_line_nm,
        use_yn = EXCLUDED.use_yn,
        upd_id = p_id,
        upd_dt = now();

    DELETE FROM tbl_approval_line_step
     WHERE co_cd = p_co_cd AND appr_line_cd = v_cd;

    FOR v_step IN SELECT value FROM jsonb_array_elements(p_payload -> 'steps')
    LOOP
        v_step_no := NULLIF(v_step ->> 'stepNo', '')::int;
        v_role := upper(trim(COALESCE(v_step ->> 'roleCd', '')));
        IF v_step_no IS NULL OR v_step_no < 1
           OR v_role NOT IN ('WRITE', 'APPROVE') THEN
            RAISE EXCEPTION '결재 단계 순번 또는 역할이 올바르지 않습니다.' USING ERRCODE = '45000';
        END IF;
        -- 작성·승인은 항상 사용
        v_use := 'Y';
        /*
         * 결재자가 비어도 저장한다 — **여기서 막으면 결재선을 새로 못 만든다.**
         *
         * 화면이 두 걸음으로 만든다. 먼저 왼쪽에서 코드·결재선명만 저장해 줄을 만들고
         * (그때 단계 1~3 이 결재자 없이 깔린다), 그 줄을 골라 오른쪽에서 결재자를 넣는다.
         * 첫 걸음에서 막으면 두 번째 걸음으로 갈 방법이 없다.
         *
         * 「결재자 없는 결재선」이 해를 끼치는 자리는 **그 결재선을 문서주기에 걸 때**다.
         * 거기서 막는다 (ScheduleCycleManagementPage.handleSave).
         */
        INSERT INTO tbl_approval_line_step(
            co_cd, appr_line_cd, step_no, role_cd, approver_id, dept_cd, pos_cd, use_yn, ins_id, ins_dt
        ) VALUES (
            p_co_cd, v_cd, v_step_no, v_role,
            NULLIF(v_step ->> 'approverId', ''), NULLIF(v_step ->> 'deptCd', ''),
            NULL, v_use, p_id, now()
        );
    END LOOP;
END$$;


--
-- Name: PROCEDURE sp_tbl_approval_line_c_000(IN p_co_cd character varying, IN p_payload jsonb, IN p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_tbl_approval_line_c_000(IN p_co_cd character varying, IN p_payload jsonb, IN p_id character varying) IS '결재선 저장 — 헤더+단계 교체. 역할은 WRITE·APPROVE, 직위코드 미저장';


--
-- Name: sp_tbl_approval_line_d_000(character varying, character varying, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_approval_line_d_000(IN p_co_cd character varying, IN p_appr_line_cd character varying, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM tbl_company_template
         WHERE co_cd = p_co_cd AND appr_line_cd = p_appr_line_cd
    ) OR EXISTS (
        SELECT 1 FROM tbl_document
         WHERE co_cd = p_co_cd AND appr_line_cd = p_appr_line_cd AND del_yn = 'N'
    ) THEN
        RAISE EXCEPTION '참조 중인 결재선은 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    DELETE FROM tbl_approval_line_step WHERE co_cd = p_co_cd AND appr_line_cd = p_appr_line_cd;
    DELETE FROM tbl_approval_line WHERE co_cd = p_co_cd AND appr_line_cd = p_appr_line_cd;
END$$;


--
-- Name: PROCEDURE sp_tbl_approval_line_d_000(IN p_co_cd character varying, IN p_appr_line_cd character varying, IN p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_tbl_approval_line_d_000(IN p_co_cd character varying, IN p_appr_line_cd character varying, IN p_id character varying) IS '결재선 삭제 — 양식·문서 참조가 없을 때만 단계와 함께 제거';


--
-- Name: sp_tbl_approval_line_delete_blocker_r_000(character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_approval_line_delete_blocker_r_000(p_co_cd character varying, p_appr_line_cd character varying) RETURNS TABLE(ref_key character varying, target character varying)
    LANGUAGE sql STABLE
    AS $$
    SELECT p_appr_line_cd, '사용양식 또는 문서'::varchar
     WHERE EXISTS (
        SELECT 1 FROM tbl_company_template
         WHERE co_cd = p_co_cd AND appr_line_cd = p_appr_line_cd
     ) OR EXISTS (
        SELECT 1 FROM tbl_document
         WHERE co_cd = p_co_cd AND appr_line_cd = p_appr_line_cd AND del_yn = 'N'
     );
$$;


--
-- Name: FUNCTION sp_tbl_approval_line_delete_blocker_r_000(p_co_cd character varying, p_appr_line_cd character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_tbl_approval_line_delete_blocker_r_000(p_co_cd character varying, p_appr_line_cd character varying) IS '결재선 삭제 차단 — 사용양식·문서 참조 시 1행';


--
-- Name: sp_tbl_approval_line_r_000(character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_approval_line_r_000(p_co_cd character varying) RETURNS TABLE(payload jsonb)
    LANGUAGE sql STABLE
    AS $$
    SELECT jsonb_build_object(
        'idx', l.idx,
        'apprLineCd', l.appr_line_cd,
        'apprLineNm', l.appr_line_nm,
        'useYn', l.use_yn,
        'steps', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'idx', s.idx,
                'stepNo', s.step_no,
                'roleCd', s.role_cd,
                'approverId', s.approver_id,
                'approverNm', u.user_nm,
                'deptCd', s.dept_cd,
                'deptNm', d.dept_nm,
                'useYn', COALESCE(s.use_yn, 'Y')
            ) ORDER BY s.step_no)
              FROM tbl_approval_line_step s
              LEFT JOIN tbl_user u
                ON u.co_cd = s.co_cd AND u.user_id = s.approver_id
              LEFT JOIN tbl_dept d
                ON d.co_cd = s.co_cd AND d.dept_cd = s.dept_cd
             WHERE s.co_cd = l.co_cd AND s.appr_line_cd = l.appr_line_cd
        ), '[]'::jsonb)
    )
      FROM tbl_approval_line l
     WHERE l.co_cd = p_co_cd
     ORDER BY l.appr_line_cd;
$$;


--
-- Name: FUNCTION sp_tbl_approval_line_r_000(p_co_cd character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_tbl_approval_line_r_000(p_co_cd character varying) IS '결재선·단계 조회 — 결재자명·부서명·단계 사용여부 포함';


-- 감사자료 묶음 조회 SP — 화면이 없어 고아. 이미 도는 DB 에도 DROP
DROP FUNCTION IF EXISTS sasshaccp.sp_tbl_audit_export_r_000(character varying, character varying, character varying, character varying);


--
-- Name: sp_tbl_audit_log_c_000(character varying, character varying, character varying, bigint, character varying, text, text, character varying, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

DROP PROCEDURE IF EXISTS sasshaccp.sp_tbl_audit_log_c_000(character varying, character varying, character varying, bigint, character varying, text, text, character varying, character varying);
DROP PROCEDURE IF EXISTS sasshaccp.sp_tbl_audit_log_c_000(character varying, character varying, character varying, character varying, bigint, character varying, text, text, character varying, character varying);

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_audit_log_c_000(IN p_co_cd character varying, IN p_user_id character varying, IN p_scrn_cd character varying, IN p_tbl_nm character varying, IN p_tgt_idx bigint, IN p_action_cd character varying, IN p_before_json text, IN p_after_json text, IN p_reason character varying, IN p_ip_addr character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO tbl_audit_log(co_cd, user_id, scrn_cd, tbl_nm, tgt_idx, action_cd,
                              before_json, after_json, reason, ip_addr, ins_dt)
    VALUES (p_co_cd, p_user_id, COALESCE(NULLIF(p_scrn_cd, ''), ''), p_tbl_nm, p_tgt_idx, p_action_cd,
            NULLIF(p_before_json, '')::jsonb, NULLIF(p_after_json, '')::jsonb,
            -- reason 은 varchar(500). 감사 적재는 호출자 트랜잭션 안이라
            -- 여기서 22001 이 나면 업무 자체가 롤백된다
            left(NULLIF(p_reason, ''), 500), p_ip_addr, now());
END$$;


--
-- Name: PROCEDURE sp_tbl_audit_log_c_000(IN p_co_cd character varying, IN p_user_id character varying, IN p_tbl_nm character varying, IN p_tgt_idx bigint, IN p_action_cd character varying, IN p_before_json text, IN p_after_json text, IN p_reason character varying, IN p_ip_addr character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_tbl_audit_log_c_000(IN p_co_cd character varying, IN p_user_id character varying, IN p_scrn_cd character varying, IN p_tbl_nm character varying, IN p_tgt_idx bigint, IN p_action_cd character varying, IN p_before_json text, IN p_after_json text, IN p_reason character varying, IN p_ip_addr character varying) IS '변경 감사 로그 기록 — 화면코드·테이블·행위. HACCP 기록의 사후 수정 추적';


--
-- Name: sp_tbl_ccp_generic_monitor_c_000(character varying, bigint, character varying, character varying, character varying, character varying, character varying, character varying, character varying, jsonb, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

DROP FUNCTION IF EXISTS sasshaccp.sp_tbl_ccp_generic_monitor_c_000(character varying, bigint, character varying, character varying, character varying, character varying, character varying, character varying, character varying, jsonb, character varying);
CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_ccp_generic_monitor_c_000(p_co_cd character varying, p_doc_idx bigint, p_base_dt character varying, p_tmpl_cd character varying, p_ccp_cd character varying, p_diary_no character varying, p_limit_item_kind character varying, p_mng_user_id character varying, p_mng_nm character varying, p_rows jsonb, p_id character varying, p_title character varying DEFAULT NULL::character varying) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_doc_idx bigint;
    v_monitor_idx bigint;
    v_doc_no varchar;
    v_title varchar(300);
    v_appr varchar;
    v_retain int;
    v_row jsonb;
    v_cell jsonb;
    v_row_idx bigint;
BEGIN
    -- 형제 저장 SP 셋(sp_ccp_verify_c_000·sp_tbl_ccp_metal_monitor_c_000·sp_tbl_hyg_process_c_000)은
    -- 다 막는데 여기만 없었다. 아래에서 to_date·채번·varchar(8) 로 그대로 흘러간다
    IF COALESCE(p_base_dt, '') = '' OR p_base_dt !~ '^[0-9]{8}$' THEN
        RAISE EXCEPTION '작성일은 YYYYMMDD 8자리로 입력하세요.' USING ERRCODE = '45000';
    END IF;
    IF jsonb_typeof(p_rows) <> 'array' OR jsonb_array_length(p_rows) = 0 THEN
        RAISE EXCEPTION '점검 행이 없습니다.' USING ERRCODE = '45000';
    END IF;
    -- 양식명·결재선·보존기간 — 자사 양식은 tbl_company_template 오버라이드가 우선
    SELECT coalesce(nullif(ct.tmpl_nm_ovr, ''), nullif(t.tmpl_nm, ''), '공통 CCP 모니터링'),
           COALESCE(ct.appr_line_cd, 'DEFAULT'),
           COALESCE(ct.retention_month, t.default_retention_month)
      INTO v_title, v_appr, v_retain
      FROM tbl_template t
      LEFT JOIN tbl_company_template ct ON ct.co_cd = p_co_cd AND ct.tmpl_cd = t.tmpl_cd AND ct.use_yn = 'Y'
     WHERE t.tmpl_cd = p_tmpl_cd AND t.doc_kind = 'HTML' AND t.use_yn = 'Y' AND t.co_cd = p_co_cd;
    IF v_title IS NULL THEN
        RAISE EXCEPTION '사용할 공통 CCP 양식이 등록되어 있지 않습니다.' USING ERRCODE = '45000';
    END IF;

    IF coalesce(p_doc_idx, 0) <= 0 THEN
        -- 자사 양식 복사 SP 는 채번 규칙을 만들지 않는다. 없을 때만 기본 규칙을 깐다
        INSERT INTO tbl_doc_no_rule (co_cd, tmpl_cd, prefix, date_fmt, seq_len, reset_cycle, ins_id, ins_dt)
        VALUES (p_co_cd, p_tmpl_cd, left(p_tmpl_cd, 20), 'YYYYMMDD', 3, 'D', p_id, now())
        ON CONFLICT (co_cd, tmpl_cd) DO NOTHING;

        v_doc_no := sp_tbl_doc_no_gen_c_000(p_co_cd, p_tmpl_cd, p_base_dt);
        INSERT INTO tbl_document (
            co_cd, tmpl_cd, doc_kind, doc_no, base_dt, title, status, appr_line_cd,
            writer_id, write_dt, ver_no, retention_until, form_src, del_yn, ins_id
        ) VALUES (
            p_co_cd, p_tmpl_cd, 'HTML', v_doc_no, p_base_dt,
            COALESCE(NULLIF(btrim(COALESCE(p_title, '')), ''), v_title),
            'WRK', v_appr,
            p_id, now(), 1,
            to_char((to_date(p_base_dt, 'YYYYMMDD') + (COALESCE(v_retain, 24) || ' months')::interval)::date, 'YYYYMMDD'),
            'BASE', 'N', p_id
        ) RETURNING idx INTO v_doc_idx;
        INSERT INTO tbl_ccp_generic_monitor (
            co_cd, doc_idx, base_dt, tmpl_cd, ccp_cd, diary_no, limit_item_kind, mng_user_id, mng_nm, ins_id
        ) VALUES (
            p_co_cd, v_doc_idx, p_base_dt, p_tmpl_cd, nullif(p_ccp_cd, ''), nullif(p_diary_no, ''),
            nullif(p_limit_item_kind, ''), nullif(p_mng_user_id, ''), nullif(p_mng_nm, ''), p_id
        ) RETURNING idx INTO v_monitor_idx;
    ELSE
        SELECT m.idx INTO v_monitor_idx
          FROM tbl_ccp_generic_monitor m
          -- 모니터 행과 문서를 같은 회사로만 잇는다 — idx 만 보면 타사 문서에 붙을 수 있다
          JOIN tbl_document d ON d.idx = m.doc_idx AND d.co_cd = m.co_cd
         WHERE m.co_cd = p_co_cd AND m.doc_idx = p_doc_idx AND d.del_yn = 'N' AND d.status IN ('WRK', 'RJT');
        IF v_monitor_idx IS NULL THEN
            RAISE EXCEPTION '전송한 문서는 수정할 수 없습니다. 전송취소 후 수정하세요.' USING ERRCODE = '45000';
        END IF;
        v_doc_idx := p_doc_idx;
        -- 제목이 넘어오면 그 값, 없으면 기존 title 유지
        UPDATE tbl_document SET base_dt = p_base_dt,
            title = COALESCE(NULLIF(btrim(COALESCE(p_title, '')), ''), title),
            upd_id = p_id, upd_dt = now()
         WHERE idx = v_doc_idx AND co_cd = p_co_cd;
        UPDATE tbl_ccp_generic_monitor
           SET base_dt = p_base_dt, tmpl_cd = p_tmpl_cd, ccp_cd = nullif(p_ccp_cd, ''),
               diary_no = nullif(p_diary_no, ''), limit_item_kind = nullif(p_limit_item_kind, ''),
               mng_user_id = nullif(p_mng_user_id, ''), mng_nm = nullif(p_mng_nm, ''), upd_id = p_id, upd_dt = now()
         WHERE idx = v_monitor_idx AND co_cd = p_co_cd;
        DELETE FROM tbl_ccp_generic_monitor_cell c
         USING tbl_ccp_generic_monitor_row r
         WHERE c.row_idx = r.idx AND r.monitor_idx = v_monitor_idx AND r.co_cd = p_co_cd;
        DELETE FROM tbl_ccp_generic_monitor_row WHERE monitor_idx = v_monitor_idx AND co_cd = p_co_cd;
    END IF;

    FOR v_row IN SELECT value FROM jsonb_array_elements(p_rows)
    LOOP
        INSERT INTO tbl_ccp_generic_monitor_row (
            co_cd, monitor_idx, row_seq, phase_cd, check_time, equip_nm, product_nm,
            judge_cd, judge_mod_yn, checker_id, checker_nm, sign_img, ins_id
        ) VALUES (
            p_co_cd, v_monitor_idx, coalesce(nullif(v_row->>'rowSeq', '')::int, 0),
            -- 작업 전/작업 종료 구분 — 안 넘기면 NULL(기존 heat·sanitize·filter 화면)
            nullif(v_row->>'phaseCd', ''),
            nullif(v_row->>'checkTime', ''),
            nullif(v_row->>'equipNm', ''), nullif(v_row->>'productNm', ''),
            nullif(v_row->>'judgeCd', ''), coalesce(nullif(v_row->>'judgeModYn', ''), 'N'),
            nullif(v_row->>'checkerId', ''), nullif(v_row->>'checkerNm', ''),
            -- 서명은 signYn만 받고 검사자 서명 원본을 그 시점 값으로 복사한다
            CASE WHEN COALESCE(v_row->>'signYn', 'N') = 'Y'
                 THEN (SELECT u.sign_img FROM tbl_user u
                        WHERE u.co_cd = p_co_cd
                          AND u.user_id = nullif(v_row->>'checkerId', ''))
                 ELSE NULL END, p_id
        ) RETURNING idx INTO v_row_idx;
        FOR v_cell IN SELECT value FROM jsonb_array_elements(coalesce(v_row->'cells', '[]'::jsonb))
        LOOP
            INSERT INTO tbl_ccp_generic_monitor_cell (
                co_cd, row_idx, item_cd, num_val, txt_val, judge_cd, ins_id
            ) VALUES (
                p_co_cd, v_row_idx, v_cell->>'itemCd',
                nullif(v_cell->>'numVal', '')::numeric,
                nullif(v_cell->>'txtVal', ''),
                nullif(v_cell->>'judgeCd', ''), p_id
            );
        END LOOP;
    END LOOP;
    RETURN v_doc_idx;
END$$;


--
-- Name: FUNCTION sp_tbl_ccp_generic_monitor_c_000(p_co_cd character varying, p_doc_idx bigint, p_base_dt character varying, p_tmpl_cd character varying, p_ccp_cd character varying, p_diary_no character varying, p_limit_item_kind character varying, p_mng_user_id character varying, p_mng_nm character varying, p_rows jsonb, p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_tbl_ccp_generic_monitor_c_000(p_co_cd character varying, p_doc_idx bigint, p_base_dt character varying, p_tmpl_cd character varying, p_ccp_cd character varying, p_diary_no character varying, p_limit_item_kind character varying, p_mng_user_id character varying, p_mng_nm character varying, p_rows jsonb, p_id character varying, p_title character varying) IS '공통 CCP 저장 — 제목이 있으면 그 값, 없으면 신규는 양식명·수정은 기존 title';


--
-- Name: sp_tbl_ccp_generic_monitor_d_000(character varying, bigint, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_ccp_generic_monitor_d_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
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

    -- 완료(DONE)된 개선조치는 원문서를 지워도 남긴다 (형제 _d_000 셋과 같은 기준)
    DELETE FROM tbl_corrective_action
     WHERE co_cd = p_co_cd AND src_doc_idx = p_doc_idx
       AND status <> 'DONE';

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


--
-- Name: PROCEDURE sp_tbl_ccp_generic_monitor_d_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_tbl_ccp_generic_monitor_d_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_id character varying) IS '공통 CCP 모니터링 삭제 — 작성중·반려만';


--
-- Name: sp_tbl_ccp_generic_monitor_r_000(character varying, bigint); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_ccp_generic_monitor_r_000(p_co_cd character varying, p_doc_idx bigint) RETURNS TABLE(doc_idx bigint, doc_no character varying, status character varying, base_dt character varying, tmpl_cd character varying, ccp_cd character varying, diary_no character varying, limit_item_kind character varying, mng_user_id character varying, mng_nm character varying, rows_json jsonb)
    LANGUAGE plpgsql
    AS $$
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
                              -- 작업 전/작업 종료 — 재조회 때 같은 영역에 다시 붙는다
                              'phaseCd', COALESCE(r.phase_cd, ''),
                              'checkTime', COALESCE(r.check_time, ''),
                              'equipNm', COALESCE(r.equip_nm, ''),
                              'productNm', COALESCE(r.product_nm, ''),
                              'judgeCd', r.judge_cd,
                              'judgeModYn', r.judge_mod_yn,
                              'checkerId', COALESCE(r.checker_id, ''),
                              'checkerNm', COALESCE(r.checker_nm, ''),
                              'signYn', (CASE WHEN r.sign_img IS NOT NULL THEN 'Y' ELSE 'N' END),
                              'cells', COALESCE((
                                  SELECT jsonb_agg(
                                             jsonb_build_object(
                                                 'itemCd', c.item_cd,
                                                 'numVal', c.num_val,
                                                 'txtVal', COALESCE(c.txt_val, ''),
                                                 'judgeCd', c.judge_cd
                                             ) ORDER BY c.item_cd
                                         )
                                    FROM tbl_ccp_generic_monitor_cell c
                                   WHERE c.row_idx = r.idx AND c.co_cd = r.co_cd
                              ), '[]'::jsonb)
                          ) ORDER BY r.row_seq
                      )
                 FROM tbl_ccp_generic_monitor_row r
                WHERE r.monitor_idx = m.idx AND r.co_cd = m.co_cd
           ), '[]'::jsonb) AS rows_json
      FROM tbl_document d
      JOIN tbl_ccp_generic_monitor m ON m.doc_idx = d.idx AND m.co_cd = d.co_cd
     WHERE d.co_cd = p_co_cd AND d.idx = p_doc_idx AND d.del_yn = 'N';
END$$;


--
-- Name: FUNCTION sp_tbl_ccp_generic_monitor_r_000(p_co_cd character varying, p_doc_idx bigint); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_tbl_ccp_generic_monitor_r_000(p_co_cd character varying, p_doc_idx bigint) IS '공통 CCP 상세 — 124에서 rows_json 에 phaseCd 추가';


--
-- Name: sp_tbl_ccp_metal_monitor_c_000(character varying, bigint, character varying, character varying, numeric, numeric, character varying, character varying, jsonb, jsonb, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

DROP FUNCTION IF EXISTS sasshaccp.sp_tbl_ccp_metal_monitor_c_000(character varying, bigint, character varying, character varying, numeric, numeric, character varying, character varying, jsonb, jsonb, character varying, character varying);
CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_ccp_metal_monitor_c_000(p_co_cd character varying, p_doc_idx bigint, p_base_dt character varying, p_ccp_cd character varying, p_fe_size numeric, p_sts_size numeric, p_mng_user_id character varying, p_mng_nm character varying, p_sens_rows_json jsonb, p_pass_rows_json jsonb, p_id character varying, p_tmpl_cd character varying DEFAULT 'tmpl_ccp-metal-log'::character varying, p_title character varying DEFAULT NULL::character varying) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE v_doc_idx bigint; v_hdr_idx bigint; v_status varchar(4); v_name varchar; v_appr varchar; v_retain int; r jsonb;
    v_in varchar(300); v_auto varchar(300);
BEGIN
    IF COALESCE(p_base_dt, '') = '' OR length(p_base_dt) <> 8 THEN RAISE EXCEPTION '작성일은 YYYYMMDD 8자리로 입력하세요.' USING ERRCODE = '45000'; END IF;
    IF p_sens_rows_json IS NULL OR jsonb_typeof(p_sens_rows_json) <> 'array' THEN RAISE EXCEPTION '감도 점검 행 자료가 올바르지 않습니다.' USING ERRCODE = '45000'; END IF;
    SELECT COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm), COALESCE(ct.appr_line_cd, 'DEFAULT'), COALESCE(ct.retention_month, t.default_retention_month)
      INTO v_name, v_appr, v_retain FROM tbl_template t LEFT JOIN tbl_company_template ct ON ct.co_cd=p_co_cd AND ct.tmpl_cd=t.tmpl_cd AND ct.use_yn='Y'
     WHERE t.tmpl_cd=p_tmpl_cd AND t.use_yn='Y' AND t.co_cd = p_co_cd;
    IF v_name IS NULL THEN RAISE EXCEPTION 'CCP 금속검출 양식이 등록되어 있지 않습니다.' USING ERRCODE = '45000'; END IF;
    v_auto := v_name || ' (' || p_base_dt || ')';
    v_in := NULLIF(btrim(COALESCE(p_title, '')), '');
    IF p_doc_idx IS NULL OR p_doc_idx = 0 THEN
        -- 자사 양식 복사 SP 는 채번 규칙을 만들지 않는다. 없을 때만 기본 규칙을 깐다
        INSERT INTO tbl_doc_no_rule (co_cd, tmpl_cd, prefix, date_fmt, seq_len, reset_cycle, ins_id, ins_dt)
        VALUES (p_co_cd, p_tmpl_cd, left(p_tmpl_cd, 20), 'YYYYMMDD', 3, 'D', p_id, now())
        ON CONFLICT (co_cd, tmpl_cd) DO NOTHING;

        INSERT INTO tbl_document(co_cd,tmpl_cd,doc_kind,doc_no,base_dt,title,status,appr_line_cd,writer_id,write_dt,ver_no,retention_until,del_yn,ins_id)
        VALUES(p_co_cd,p_tmpl_cd,'HTML',sp_tbl_doc_no_gen_c_000(p_co_cd,p_tmpl_cd,p_base_dt),p_base_dt,COALESCE(v_in, v_auto),'WRK',v_appr,p_id,now(),1,to_char((to_date(p_base_dt,'YYYYMMDD')+(COALESCE(v_retain,24)||' months')::interval)::date,'YYYYMMDD'),'N',p_id) RETURNING idx INTO v_doc_idx;
        INSERT INTO tbl_ccp_metal_monitor(co_cd,doc_idx,base_dt,ccp_cd,fe_size,sts_size,mng_user_id,mng_nm,ins_id) VALUES(p_co_cd,v_doc_idx,p_base_dt,p_ccp_cd,p_fe_size,p_sts_size,NULLIF(p_mng_user_id,''),NULLIF(p_mng_nm,''),p_id) RETURNING idx INTO v_hdr_idx;
    ELSE
        SELECT d.idx,d.status,h.idx INTO v_doc_idx,v_status,v_hdr_idx FROM tbl_document d JOIN tbl_ccp_metal_monitor h ON h.doc_idx=d.idx AND h.co_cd=d.co_cd WHERE d.co_cd=p_co_cd AND d.idx=p_doc_idx AND d.tmpl_cd=p_tmpl_cd AND d.del_yn='N';
        IF v_doc_idx IS NULL THEN RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE='45000'; END IF;
        IF v_status IN ('REQ','APV') THEN RAISE EXCEPTION '전송한 문서는 수정할 수 없습니다. 전송취소 후 수정하세요.' USING ERRCODE='45000'; END IF;
        UPDATE tbl_document SET base_dt=p_base_dt,title=COALESCE(v_in, title),upd_id=p_id,upd_dt=now() WHERE idx=v_doc_idx AND co_cd=p_co_cd;
        UPDATE tbl_ccp_metal_monitor SET base_dt=p_base_dt,ccp_cd=p_ccp_cd,fe_size=p_fe_size,sts_size=p_sts_size,mng_user_id=NULLIF(p_mng_user_id,''),mng_nm=NULLIF(p_mng_nm,''),upd_id=p_id,upd_dt=now() WHERE idx=v_hdr_idx AND co_cd=p_co_cd;
        DELETE FROM tbl_ccp_metal_sens_row WHERE co_cd=p_co_cd AND hdr_idx=v_hdr_idx;
        DELETE FROM tbl_ccp_metal_pass_row WHERE co_cd=p_co_cd AND hdr_idx=v_hdr_idx;
    END IF;
    FOR r IN SELECT * FROM jsonb_array_elements(p_sens_rows_json) LOOP
        IF COALESCE((r->>'rowSeq')::int,0) <= 0 THEN RAISE EXCEPTION '감도 점검 행 순번이 올바르지 않습니다.' USING ERRCODE='45000'; END IF;
        /*
         * 판정은 **사람이 정한 값을 그대로** 넣는다. 포장·가열(sp_tbl_ccp_generic_monitor_c_000)과 같다.
         *
         * 예전에는 감도 5칸으로 여기서 계산했다(O,O,X,O,O 면 적합). 두 가지가 어긋났다 —
         *   1) 뒤 세 열은 양식에서 「해당 없음」이 기본이라 고정행(작업 전·작업 종료)에는
         *      입력칸 자체가 없다. 값이 안 들어오니 조건이 성립할 수 없어 **늘 부적합**이 됐다
         *   2) 그걸 덮으려고 화면이 judgeModYn=Y 를 붙여 사람 값을 이기게 했는데,
         *      그 표식을 읽는 화면이 없어 **누가 뒤집었는지 아무도 못 봤다**.
         *      실제로 5칸이 전부 X(시편 미검출 = 검출기 고장)인데 적합인 기록이 남아 있었다
         *
         * 근거와 결론이 어긋나지 않게 하는 일은 화면이 맡는다 —
         * 「모두 적합」이 판정과 감도 5칸을 같이 채운다(CcpMtlPaper.MTL_HDR.pass).
         */
        INSERT INTO tbl_ccp_metal_sens_row(co_cd,hdr_idx,row_seq,phase_cd,product_cd,product_nm,place_nm,check_time,fe_only_cd,sts_only_cd,prod_only_cd,fe_prod_cd,sts_prod_cd,judge_cd,judge_mod_yn,checker_id,checker_nm,ins_id)
        VALUES(p_co_cd,v_hdr_idx,(r->>'rowSeq')::int,COALESCE(NULLIF(r->>'phaseCd',''),'DURING'),NULLIF(r->>'productCd',''),NULLIF(r->>'productNm',''),NULLIF(r->>'placeNm',''),NULLIF(r->>'checkTime',''),NULLIF(r->>'feOnlyCd',''),NULLIF(r->>'stsOnlyCd',''),NULLIF(r->>'prodOnlyCd',''),NULLIF(r->>'feProdCd',''),NULLIF(r->>'stsProdCd',''),NULLIF(r->>'judgeCd',''),COALESCE(NULLIF(r->>'judgeModYn',''),'N'),NULLIF(r->>'checkerId',''),NULLIF(r->>'checkerNm',''),p_id);
    END LOOP;
    FOR r IN SELECT * FROM jsonb_array_elements(COALESCE(p_pass_rows_json,'[]'::jsonb)) LOOP
        INSERT INTO tbl_ccp_metal_pass_row(co_cd,hdr_idx,row_seq,product_cd,product_nm,pass_qty,detect_qty,unit_nm,remark,ins_id)
        VALUES(p_co_cd,v_hdr_idx,COALESCE((r->>'rowSeq')::int,0),NULLIF(r->>'productCd',''),NULLIF(r->>'productNm',''),NULLIF(r->>'passQty','')::numeric,NULLIF(r->>'detectQty','')::numeric,NULLIF(r->>'unitNm',''),NULLIF(r->>'remark',''),p_id);
    END LOOP;
    RETURN v_doc_idx;
END$$;


--
-- Name: FUNCTION sp_tbl_ccp_metal_monitor_c_000(p_co_cd character varying, p_doc_idx bigint, p_base_dt character varying, p_ccp_cd character varying, p_fe_size numeric, p_sts_size numeric, p_mng_user_id character varying, p_mng_nm character varying, p_sens_rows_json jsonb, p_pass_rows_json jsonb, p_id character varying, p_tmpl_cd character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_tbl_ccp_metal_monitor_c_000(p_co_cd character varying, p_doc_idx bigint, p_base_dt character varying, p_ccp_cd character varying, p_fe_size numeric, p_sts_size numeric, p_mng_user_id character varying, p_mng_nm character varying, p_sens_rows_json jsonb, p_pass_rows_json jsonb, p_id character varying, p_tmpl_cd character varying, p_title character varying) IS 'CCP 금속검출 저장 — 제목이 있으면 그 값, 없으면 신규는 양식명(일자)·수정은 기존 title';


--
-- Name: sp_tbl_ccp_metal_monitor_d_000(character varying, bigint, character varying, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_ccp_metal_monitor_d_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_id character varying, IN p_tmpl_cd character varying DEFAULT 'tmpl_ccp-metal-log'::character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE v_hdr_idx bigint; v_status varchar(4);
BEGIN
    SELECT h.idx, d.status INTO v_hdr_idx, v_status
      FROM tbl_document d
      JOIN tbl_ccp_metal_monitor h ON h.doc_idx = d.idx AND h.co_cd = d.co_cd
     WHERE d.co_cd = p_co_cd AND d.idx = p_doc_idx AND d.tmpl_cd = p_tmpl_cd AND d.del_yn = 'N';
    IF v_hdr_idx IS NULL THEN
        RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    -- 전송대기(WRK·RJT)가 아닐 때(= 전송·결재완료) 삭제 차단. 전송취소를 먼저 해야 한다
    IF v_status NOT IN ('WRK', 'RJT') THEN
        RAISE EXCEPTION '전송한 문서는 삭제할 수 없습니다. 전송취소 후 삭제하세요.' USING ERRCODE = '45000';
    END IF;
    -- 완료(DONE)된 개선조치는 원문서를 지워도 남긴다. 조치 기록이 초안 삭제로 사라지면 안 된다.
    -- 개선조치 목록은 LEFT JOIN tbl_document 이라 원문서가 없어도 문서 칸만 빈 채로 보인다
    DELETE FROM tbl_corrective_action WHERE co_cd = p_co_cd AND src_doc_idx = p_doc_idx AND status <> 'DONE';
    DELETE FROM tbl_ccp_metal_sens_row WHERE co_cd = p_co_cd AND hdr_idx = v_hdr_idx;
    DELETE FROM tbl_ccp_metal_pass_row WHERE co_cd = p_co_cd AND hdr_idx = v_hdr_idx;
    DELETE FROM tbl_ccp_metal_monitor WHERE co_cd = p_co_cd AND idx = v_hdr_idx;
    DELETE FROM tbl_document_approval WHERE co_cd = p_co_cd AND doc_idx = p_doc_idx;
    DELETE FROM tbl_document_file WHERE co_cd = p_co_cd AND doc_idx = p_doc_idx;
    DELETE FROM tbl_document WHERE co_cd = p_co_cd AND idx = p_doc_idx;
END$$;


--
-- Name: PROCEDURE sp_tbl_ccp_metal_monitor_d_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_id character varying, IN p_tmpl_cd character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_tbl_ccp_metal_monitor_d_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_id character varying, IN p_tmpl_cd character varying) IS 'CCP 금속검출 삭제 — 124에서 p_tmpl_cd 개방. 전송대기(WRK·RJT)만';


--
-- Name: sp_tbl_ccp_metal_monitor_r_001(character varying, bigint, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_ccp_metal_monitor_r_001(p_co_cd character varying, p_doc_idx bigint, p_tmpl_cd character varying DEFAULT 'tmpl_ccp-metal-log'::character varying) RETURNS TABLE(doc_idx bigint, hdr_idx bigint, doc_no character varying, base_dt character varying, ccp_cd character varying, fe_size numeric, sts_size numeric, mng_user_id character varying, mng_nm character varying, status character varying)
    LANGUAGE sql STABLE
    AS $$
    SELECT d.idx, h.idx, d.doc_no, h.base_dt, h.ccp_cd, h.fe_size, h.sts_size,
           h.mng_user_id, h.mng_nm, d.status
      FROM tbl_document d JOIN tbl_ccp_metal_monitor h ON h.doc_idx = d.idx AND h.co_cd = d.co_cd
     WHERE d.co_cd = p_co_cd AND d.idx = p_doc_idx AND d.tmpl_cd = p_tmpl_cd AND d.del_yn = 'N';
$$;


--
-- Name: FUNCTION sp_tbl_ccp_metal_monitor_r_001(p_co_cd character varying, p_doc_idx bigint, p_tmpl_cd character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_tbl_ccp_metal_monitor_r_001(p_co_cd character varying, p_doc_idx bigint, p_tmpl_cd character varying) IS 'CCP 금속검출 헤더 — 124에서 p_tmpl_cd 개방(기본값은 기존 양식)';


--
-- Name: sp_tbl_ccp_metal_monitor_r_002(character varying, bigint); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_ccp_metal_monitor_r_002(p_co_cd character varying, p_hdr_idx bigint) RETURNS TABLE(idx bigint, row_seq integer, phase_cd character varying, product_cd character varying, product_nm character varying, check_time character varying, fe_only_cd character varying, sts_only_cd character varying, prod_only_cd character varying, fe_prod_cd character varying, sts_prod_cd character varying, judge_cd character varying, checker_id character varying, checker_nm character varying)
    LANGUAGE sql STABLE
    AS $$
    SELECT idx, row_seq, phase_cd, product_cd, product_nm, check_time, fe_only_cd, sts_only_cd,
           prod_only_cd, fe_prod_cd, sts_prod_cd, judge_cd, checker_id, checker_nm
      FROM tbl_ccp_metal_sens_row
     WHERE co_cd = p_co_cd AND hdr_idx = p_hdr_idx ORDER BY row_seq;
$$;


--
-- Name: sp_tbl_ccp_metal_monitor_r_003(character varying, bigint); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_ccp_metal_monitor_r_003(p_co_cd character varying, p_hdr_idx bigint) RETURNS TABLE(idx bigint, row_seq integer, product_cd character varying, product_nm character varying, pass_qty numeric, detect_qty numeric, unit_nm character varying, remark character varying)
    LANGUAGE sql STABLE
    AS $$
    SELECT idx, row_seq, product_cd, product_nm, pass_qty, detect_qty, unit_nm, remark
      FROM tbl_ccp_metal_pass_row
     WHERE co_cd = p_co_cd AND hdr_idx = p_hdr_idx ORDER BY row_seq;
$$;


-- Name: sp_tbl_company_template_delete_blocker_r_000(character varying, character varying[]); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_company_template_delete_blocker_r_000(p_co_cd character varying, p_tmpl_cds character varying[]) RETURNS TABLE(ref_key character varying, target character varying)
    LANGUAGE sql STABLE
    AS $$
    -- 시스템 제공 양식은 회사가 지울 수 없다 — sp_tbl_company_template_d_000 과 같은 판정
    SELECT ct.tmpl_cd::varchar AS ref_key,
           '시스템 제공 양식'::varchar AS target
      FROM tbl_company_template ct
     WHERE ct.co_cd = p_co_cd
       AND ct.tmpl_cd = ANY(p_tmpl_cds)
       AND lower(COALESCE(ct.sys_yn, 'sys')) NOT IN ('usr', 'n')
     UNION ALL
    -- 이미 이 양식으로 쓴 문서가 있으면 지우지 않는다 — 기록의 근거가 사라진다
    SELECT d.tmpl_cd::varchar,
           '작성된 문서'::varchar
      FROM tbl_document d
     WHERE d.co_cd = p_co_cd
       AND d.tmpl_cd = ANY(p_tmpl_cds)
     LIMIT 1;
$$;


--
-- Name: FUNCTION sp_tbl_company_template_delete_blocker_r_000(p_co_cd character varying, p_tmpl_cds character varying[]); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_tbl_company_template_delete_blocker_r_000(p_co_cd character varying, p_tmpl_cds character varying[]) IS '사용양식 삭제 차단 — 시스템 제공분·작성된 문서가 있으면 불가. 위반 첫 건만 반환';


--
-- Name: sp_tbl_company_template_d_000(character varying, character varying, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_company_template_d_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- 출처 — sys(시스템 제공) / usr(자사 등록). 레거시 Y/N 도 함께 본다
    v_sys varchar(10);
BEGIN
    IF COALESCE(p_co_cd, '') = '' OR COALESCE(p_tmpl_cd, '') = '' THEN
        RAISE EXCEPTION '삭제할 양식을 선택하세요.' USING ERRCODE = '45000';
    END IF;

    SELECT sys_yn INTO v_sys
      FROM tbl_company_template
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    IF NOT FOUND THEN
        RAISE EXCEPTION '삭제할 양식을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    -- 자사양식(usr·N)만 삭제 가능 — 그 외는 전부 시스템 제공분으로 본다(값이 비어도 차단)
    IF lower(COALESCE(v_sys, 'sys')) NOT IN ('usr', 'n') THEN
        RAISE EXCEPTION '시스템에서 제공하는 양식은 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    -- 파일 이력은 논리 삭제 — 물리 파일과 감사 추적을 남긴다
    UPDATE tbl_company_template_file
       SET del_yn = 'Y'
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND del_yn = 'N';

    DELETE FROM tbl_company_template WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;

    -- 이 회사가 직접 만든 카탈로그 행이면 함께 정리한다
    DELETE FROM tbl_template
     WHERE tmpl_cd = p_tmpl_cd
       AND co_cd = p_co_cd
       AND NOT EXISTS (SELECT 1 FROM tbl_document d WHERE d.tmpl_cd = p_tmpl_cd AND d.co_cd = p_co_cd);
END$$;


--
-- Name: PROCEDURE sp_tbl_company_template_d_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_tbl_company_template_d_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_id character varying) IS '사용양식 삭제 — 자사양식(usr)만 허용, 시스템 제공분은 차단. 파일 이력은 논리삭제하고 자사 카탈로그 행은 함께 정리';


--
-- Name: sp_tbl_corrective_action_c_000(character varying, bigint, jsonb, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_corrective_action_c_000(IN p_co_cd character varying, IN p_idx bigint, IN p_payload jsonb, IN p_id character varying)
    LANGUAGE plpgsql
    AS $_$
DECLARE v_idx bigint := COALESCE(p_idx, 0); v_no varchar(50);
BEGIN
    IF COALESCE(trim(p_payload->>'deviationDesc'), '') = '' OR COALESCE(p_payload->>'occurDt', '') !~ '^[0-9]{8}$' THEN
        RAISE EXCEPTION '발생일자와 이탈내용을 입력하세요.' USING ERRCODE = '45000';
    END IF;
    IF v_idx = 0 THEN
        /*
         * 접두는 current_date 가 아니라 **발생일(occurDt)** 이다.
         * 세는 기준이 occur_dt 인데 접두만 오늘이면, 지난 날짜로 등록할 때
         * 이미 쓴 번호를 다시 집어 ca_no UNIQUE 에 걸린다. 형제 _u_000 도 발생일 기준이다.
         *
         * 연번은 최대+1. count(*)+1 은 행이 지워지면 번호가 되돌아온다.
         * 형식 정규식은 옛 행의 substring(...)::int 가 22P02 를 내는 것을 막는다.
         */
        v_no := 'CA-' || (p_payload->>'occurDt') || '-' || lpad((
                    SELECT (COALESCE(MAX(substring(ca_no FROM 13)::int), 0) + 1)::text
                      FROM tbl_corrective_action
                     WHERE co_cd = p_co_cd
                       AND occur_dt = p_payload->>'occurDt'
                       AND ca_no ~ '^CA-[0-9]{8}-[0-9]{3}$'
                ), 3, '0');
        INSERT INTO tbl_corrective_action(co_cd, ca_no, src_tmpl_cd, src_doc_idx, occur_dt, occur_place, deviation_desc, action_desc, action_user_id, action_user_nm, action_dt, due_dt, status, ins_id)
        VALUES(p_co_cd, v_no, NULLIF(p_payload->>'srcTmplCd',''), NULLIF(p_payload->>'srcDocIdx','')::bigint, p_payload->>'occurDt', NULLIF(p_payload->>'occurPlace',''), p_payload->>'deviationDesc', NULLIF(p_payload->>'actionDesc',''), NULLIF(p_payload->>'actionUserId',''), NULLIF(p_payload->>'actionUserNm',''), NULLIF(p_payload->>'actionDt',''), NULLIF(p_payload->>'dueDt',''), COALESCE(NULLIF(p_payload->>'status',''),'OPEN'), p_id);
    ELSE
        -- action_user_nm 은 표에도 있고 읽기 SP 도 내려주고 화면 열도 편집 가능인데 여기서 안 썼다.
        -- 그래서 개선조치 화면에서 조치자를 고치면 저장 성공 토스트만 뜨고 값이 사라졌다
        UPDATE tbl_corrective_action SET occur_place = NULLIF(p_payload->>'occurPlace',''), deviation_desc = p_payload->>'deviationDesc', action_desc = NULLIF(p_payload->>'actionDesc',''), action_user_id = NULLIF(p_payload->>'actionUserId',''), action_user_nm = NULLIF(p_payload->>'actionUserNm',''), action_dt = NULLIF(p_payload->>'actionDt',''), due_dt = NULLIF(p_payload->>'dueDt',''), status = COALESCE(NULLIF(p_payload->>'status',''), status), upd_id = p_id, upd_dt = now()
         WHERE idx = v_idx AND co_cd = p_co_cd;
        IF NOT FOUND THEN RAISE EXCEPTION '개선조치를 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    END IF;
END$_$;


--
-- Name: sp_tbl_corrective_action_delete_blocker_r_000(character varying, bigint[]); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_corrective_action_delete_blocker_r_000(p_co_cd character varying, p_idxs bigint[]) RETURNS TABLE(ref_key character varying, target character varying)
    LANGUAGE sql STABLE
    AS $$
    -- 완료(DONE)된 개선조치는 지우지 않는다 — sp_tbl_corrective_action_d_000 과 **같은 판정**이어야 한다.
    -- 예전에는 이 검사가 삭제 SP 에만 있어서, 확인창을 누른 뒤에야 실패했고
    -- 여러 건을 고르면 정상 건까지 함께 롤백됐다. 어느 건이 왜 막히는지도 안 나왔다.
    SELECT ca.ca_no::varchar AS ref_key,
           '완료된 개선조치'::varchar AS target
      FROM tbl_corrective_action ca
     WHERE ca.co_cd = p_co_cd
       AND ca.idx = ANY(p_idxs)
       AND ca.status = 'DONE'
     LIMIT 1;
$$;


--
-- Name: FUNCTION sp_tbl_corrective_action_delete_blocker_r_000(p_co_cd character varying, p_idxs bigint[]); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_tbl_corrective_action_delete_blocker_r_000(p_co_cd character varying, p_idxs bigint[]) IS '개선조치 삭제 사전 차단 — 완료(DONE) 건의 첫 하나만 반환. 삭제 SP 와 같은 기준';


--
-- Name: sp_tbl_corrective_action_d_000(character varying, bigint, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_corrective_action_d_000(IN p_co_cd character varying, IN p_idx bigint, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM tbl_corrective_action WHERE idx = p_idx AND co_cd = p_co_cd AND status <> 'DONE';
    IF NOT FOUND THEN RAISE EXCEPTION '완료된 개선조치는 삭제할 수 없습니다.' USING ERRCODE = '45000'; END IF;
END$$;


--
-- Name: sp_tbl_corrective_action_r_000(character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_corrective_action_r_000(p_co_cd character varying, p_from_dt character varying, p_to_dt character varying, p_tmpl_cd character varying, p_writer character varying) RETURNS TABLE(idx bigint, ca_no character varying, occur_dt character varying, occur_place character varying, deviation_desc text, action_desc text, action_user_id character varying, action_user_nm character varying, action_dt character varying, confirm_user_nm character varying, due_dt character varying, status character varying, src_doc_idx bigint, src_doc_no character varying, src_tmpl_cd character varying, tmpl_nm character varying, base_dt character varying, doc_status character varying, writer_id character varying, writer_nm character varying)
    LANGUAGE sql STABLE
    AS $$
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
      -- 카탈로그는 자사 행만. 시드가 업체에 복사한다
      LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd AND t.co_cd = d.co_cd
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


--
-- Name: FUNCTION sp_tbl_corrective_action_r_000(p_co_cd character varying, p_from_dt character varying, p_to_dt character varying, p_tmpl_cd character varying, p_writer character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_tbl_corrective_action_r_000(p_co_cd character varying, p_from_dt character varying, p_to_dt character varying, p_tmpl_cd character varying, p_writer character varying) IS '이탈·개선조치 목록 — 이탈로 등록된 문서를 문서 정보와 함께. 검색은 일자·양식·작성자';


--
-- Name: sp_tbl_doc_corrective_r_000(character varying, bigint); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_doc_corrective_r_000(p_co_cd character varying, p_doc_idx bigint) RETURNS TABLE(idx bigint, deviation_desc text, action_desc text, action_user_nm character varying, confirm_user_nm character varying, status character varying)
    LANGUAGE sql STABLE
    AS $$
    SELECT ca.idx, ca.deviation_desc, ca.action_desc,
           ca.action_user_nm, ca.confirm_user_nm, ca.status
      FROM tbl_corrective_action ca
     WHERE ca.co_cd = p_co_cd
       AND ca.src_doc_idx = p_doc_idx
     ORDER BY ca.idx
     LIMIT 1;
$$;


--
-- Name: FUNCTION sp_tbl_doc_corrective_r_000(p_co_cd character varying, p_doc_idx bigint); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_tbl_doc_corrective_r_000(p_co_cd character varying, p_doc_idx bigint) IS '문서형 일지 이탈 푸터 단건 조회';


--
-- Name: sp_tbl_doc_corrective_u_000(character varying, bigint, character varying, character varying, jsonb, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_doc_corrective_u_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_tmpl_cd character varying, IN p_base_dt character varying, IN p_payload jsonb, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_dev   text;
    v_act   text;
    v_anm   varchar(50);
    v_cnm   varchar(50);
    v_empty boolean;
    v_idx   bigint;
    v_no    varchar(50);
BEGIN
    IF p_doc_idx IS NULL OR p_doc_idx <= 0 THEN
        RAISE EXCEPTION '문서번호가 올바르지 않습니다.' USING ERRCODE = '45000';
    END IF;

    v_dev := COALESCE(p_payload->>'deviationDesc', '');
    v_act := COALESCE(p_payload->>'actionDesc', '');
    v_anm := NULLIF(TRIM(COALESCE(p_payload->>'actionUserNm', '')), '');
    v_cnm := NULLIF(TRIM(COALESCE(p_payload->>'confirmUserNm', '')), '');
    v_empty := (TRIM(v_dev) = '' AND TRIM(v_act) = '' AND v_anm IS NULL AND v_cnm IS NULL);

    IF v_empty THEN
        /*
         * 완료(DONE)된 개선조치는 원문서 저장으로 지우지 않는다.
         *
         * 이 프로시저는 삭제 버튼이 아니라 **문서 저장 트랜잭션 안**에서 불린다
         * (HtmlDraftService.save → saveAutoIfNg). 그래서 여기서 RAISE 하면
         * 문서 헤더·항목·서명 저장까지 통째로 롤백돼, 완료된 개선조치가 달린 문서는
         * 본문 수정이 영영 안 된다. 막지 않고 **보존만** 한다.
         *
         * 기준은 형제 sp_tbl_corrective_action_d_000 과 같다 — 거기도 DONE 은 안 지운다.
         */
        DELETE FROM tbl_corrective_action
         WHERE co_cd = p_co_cd AND src_doc_idx = p_doc_idx
           AND status <> 'DONE';
        RETURN;
    END IF;

    SELECT idx INTO v_idx
      FROM tbl_corrective_action
     WHERE co_cd = p_co_cd AND src_doc_idx = p_doc_idx
     ORDER BY idx
     LIMIT 1;

    IF v_idx IS NULL THEN
        /*
         * 연번은 count(*)+1 이 아니라 **최대 연번+1** 이다.
         * 행이 하나라도 지워지면 count 는 되돌아와 이미 쓴 번호를 다시 집는다 (ca_no UNIQUE 충돌).
         *
         * ca_no 는 'CA-YYYYMMDD-NNN' 15자라 연번이 13번째부터 세 자리다.
         * 형식이 다른 옛 행이 하나라도 있으면 substring(...)::int 가 22P02 로 저장을 통째로 죽인다 —
         * 그래서 형식 정규식을 같이 건다.
         */
        v_no := 'CA-' || COALESCE(NULLIF(p_base_dt, ''), to_char(current_date, 'YYYYMMDD'))
                || '-' || lpad((
                    SELECT (COALESCE(MAX(substring(ca_no FROM 13)::int), 0) + 1)::text
                      FROM tbl_corrective_action
                     WHERE co_cd = p_co_cd
                       AND occur_dt = COALESCE(NULLIF(p_base_dt, ''), to_char(current_date, 'YYYYMMDD'))
                       AND ca_no ~ '^CA-[0-9]{8}-[0-9]{3}$'
                ), 3, '0');
        INSERT INTO tbl_corrective_action(
            co_cd, ca_no, src_tmpl_cd, src_doc_idx, occur_dt,
            deviation_desc, action_desc, action_user_nm, confirm_user_nm,
            status, ins_id, ins_dt
        ) VALUES (
            p_co_cd, v_no, NULLIF(p_tmpl_cd, ''), p_doc_idx,
            COALESCE(NULLIF(p_base_dt, ''), to_char(current_date, 'YYYYMMDD')),
            v_dev, NULLIF(v_act, ''), v_anm, v_cnm,
            CASE WHEN TRIM(v_act) = '' THEN 'OPEN' ELSE 'ING' END,
            p_id, now()
        );
    ELSE
        /*
         * 완료(DONE)된 행은 **완료 상태와 이미 적힌 조치를 지킨다.**
         *
         * 예전에는 status 를 조건 없이 CASE 로 덮어, 푸터를 비우지 않고 원문서를 다시 저장만 해도
         * DONE 이 풀렸다. 그렇다고 UPDATE 를 통째로 막으면 사용자가 친 글이 말없이 사라진다 —
         * 그래서 **되돌리는 것만** 막고 더하는 것은 통과시킨다.
         *
         * 완료 해제는 개선조치 화면(sp_tbl_corrective_action_c_000)이 하는 일이지
         * 원문서 저장이 하는 일이 아니다.
         */
        UPDATE tbl_corrective_action SET
            src_tmpl_cd     = COALESCE(NULLIF(p_tmpl_cd, ''), src_tmpl_cd),
            occur_dt        = COALESCE(NULLIF(p_base_dt, ''), occur_dt),
            deviation_desc  = v_dev,
            -- 완료 건이면 빈 값으로 지우지 않는다. 상태만 DONE 이고 내용이 빈 행이 생기면 안 된다
            action_desc     = CASE WHEN status = 'DONE'
                                   THEN COALESCE(NULLIF(v_act, ''), action_desc)
                                   ELSE NULLIF(v_act, '') END,
            action_user_nm  = CASE WHEN status = 'DONE'
                                   THEN COALESCE(v_anm, action_user_nm) ELSE v_anm END,
            confirm_user_nm = CASE WHEN status = 'DONE'
                                   THEN COALESCE(v_cnm, confirm_user_nm) ELSE v_cnm END,
            status          = CASE WHEN status = 'DONE' THEN 'DONE'
                                   WHEN TRIM(v_act) = '' THEN 'OPEN' ELSE 'ING' END,
            upd_id          = p_id,
            upd_dt          = now()
         WHERE idx = v_idx AND co_cd = p_co_cd;
    END IF;
END$$;


--
-- Name: PROCEDURE sp_tbl_doc_corrective_u_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_tmpl_cd character varying, IN p_base_dt character varying, IN p_payload jsonb, IN p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_tbl_doc_corrective_u_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_tmpl_cd character varying, IN p_base_dt character varying, IN p_payload jsonb, IN p_id character varying) IS '문서형 일지 이탈 푸터 upsert — 빈 값이면 해당 문서 CA 삭제';


--
-- Name: sp_tbl_doc_no_gen_c_000(character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_doc_no_gen_c_000(p_co_cd character varying, p_tmpl_cd character varying, p_base_dt character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_prefix    varchar(20);
    v_date_fmt  varchar(10);
    v_seq_len   int;
    v_reset     varchar(1);
    v_last_key  varchar(10);
    v_last_seq  int;
    v_reset_key varchar(10);
    v_date_part varchar(10);
    v_next_seq  int;
BEGIN
    -- 같은 회사·템플릿 조합끼리만 직렬화한다(전역 잠금이 아니라 조합 단위)
    PERFORM pg_advisory_xact_lock(hashtext(p_co_cd || '|' || p_tmpl_cd));

    SELECT prefix, date_fmt, seq_len, reset_cycle, last_reset_key, last_seq
      INTO v_prefix, v_date_fmt, v_seq_len, v_reset, v_last_key, v_last_seq
      FROM tbl_doc_no_rule
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;

    IF NOT FOUND THEN
        RAISE EXCEPTION '문서번호 채번 규칙이 없습니다: %', p_tmpl_cd USING ERRCODE = '45000';
    END IF;

    -- 리셋 기준키: 주기에 맞춰 일자를 잘라 쓴다. 값이 바뀌면 일련번호를 1부터 다시 센다
    v_reset_key := CASE v_reset
                        WHEN 'D' THEN p_base_dt
                        WHEN 'M' THEN substr(p_base_dt, 1, 6)
                        WHEN 'Y' THEN substr(p_base_dt, 1, 4)
                        ELSE 'ALL' END;

    v_next_seq := CASE WHEN COALESCE(v_last_key, '') = v_reset_key THEN v_last_seq + 1 ELSE 1 END;

    UPDATE tbl_doc_no_rule
       SET last_seq = v_next_seq, last_reset_key = v_reset_key, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;

    -- 일자 구간: date_fmt가 비어 있으면(= 일자 미포함 번호) 생략한다
    v_date_part := CASE COALESCE(v_date_fmt, '')
                        WHEN 'YYYYMMDD' THEN p_base_dt
                        WHEN 'YYYYMM'   THEN substr(p_base_dt, 1, 6)
                        WHEN 'YYYY'     THEN substr(p_base_dt, 1, 4)
                        ELSE '' END;

    RETURN concat_ws('-',
                     NULLIF(COALESCE(v_prefix, ''), ''),
                     NULLIF(v_date_part, ''),
                     lpad(v_next_seq::text, COALESCE(v_seq_len, 3), '0'));
END$$;


--
-- Name: FUNCTION sp_tbl_doc_no_gen_c_000(p_co_cd character varying, p_tmpl_cd character varying, p_base_dt character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_tbl_doc_no_gen_c_000(p_co_cd character varying, p_tmpl_cd character varying, p_base_dt character varying) IS '문서번호 채번 — 회사·템플릿 조합 단위 자문 잠금으로 중복 방지';


--
-- Name: sp_sign_ok_r_000(character varying, character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--
-- 결재완료(sign-ok) 목록 — 내가 APPROVE 단계로 승인·반려한 문서.
-- p_keyword: 문서번호·제목 부분검색. p_writer_id: 작성자 ID·이름 부분검색. 비면 전체.

CREATE OR REPLACE FUNCTION sasshaccp.sp_sign_ok_r_000(p_co_cd character varying, p_user_id character varying, p_from_dt character varying, p_to_dt character varying, p_keyword character varying, p_writer_id character varying) RETURNS TABLE(doc_idx bigint, co_cd character varying, tmpl_cd character varying, tmpl_nm character varying, doc_kind character varying, doc_no character varying, base_dt character varying, title character varying, status character varying, appr_line_cd character varying, writer_id character varying, writer_nm character varying, write_dt timestamp without time zone, ver_no integer, retention_until character varying, file_cnt integer, open_ca_cnt integer, my_result_cd character varying, my_act_dt timestamp without time zone)
    LANGUAGE sql STABLE
    AS $$
    SELECT DISTINCT ON (d.idx)
           d.idx, d.co_cd, d.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm, d.tmpl_cd),
           d.doc_kind, d.doc_no, d.base_dt, d.title, d.status, d.appr_line_cd,
           d.writer_id, u.user_nm, d.write_dt, d.ver_no, d.retention_until,
           (SELECT count(*)::int FROM tbl_document_file f WHERE f.co_cd = d.co_cd AND f.doc_idx = d.idx AND f.file_kind IN ('ATTACH', 'PHOTO')),
           (SELECT count(*)::int FROM tbl_corrective_action ca
             WHERE ca.co_cd = d.co_cd AND ca.src_doc_idx = d.idx AND ca.status <> 'DONE'),
           a.result_cd, a.act_dt
      FROM tbl_document d
      JOIN tbl_document_approval a
        ON a.co_cd = d.co_cd AND a.doc_idx = d.idx
       AND a.approver_id = p_user_id
       AND a.result_cd IN ('A', 'R')
       -- 작성자 단계(WRITE)는 상신 때 자동 승인된다. 이력에 넣으면 작성자가 자기 미결 문서를 본다
       AND a.role_cd = 'APPROVE'
      -- 카탈로그는 자사 행만. 시드가 업체에 복사한다
      LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd AND t.co_cd = d.co_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = d.co_cd AND ct.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_user u ON u.co_cd = d.co_cd AND u.user_id = d.writer_id
     WHERE d.co_cd = p_co_cd
       AND d.del_yn = 'N'
       AND (COALESCE(p_from_dt, '') = '' OR d.base_dt >= p_from_dt)
       AND (COALESCE(p_to_dt, '') = '' OR d.base_dt <= p_to_dt)
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
     ORDER BY d.idx, a.act_dt DESC NULLS LAST;
$$;


--
-- Name: FUNCTION sp_sign_ok_r_000(p_co_cd character varying, p_user_id character varying, p_from_dt character varying, p_to_dt character varying, p_keyword character varying, p_writer_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_sign_ok_r_000(p_co_cd character varying, p_user_id character varying, p_from_dt character varying, p_to_dt character varying, p_keyword character varying, p_writer_id character varying) IS '결재완료(sign-ok) — 내가 승인·반려한 문서 (작성자 자동승인 제외)';


--
-- Name: sp_sign_ready_r_000(character varying, character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--
-- 결재대기(sign-ready) 목록 — 내 APPROVE 단계가 대기(W)인 REQ 문서.
-- p_keyword: 문서번호·제목 부분검색. p_writer_id: 작성자 ID·이름 부분검색. 비면 전체.

CREATE OR REPLACE FUNCTION sasshaccp.sp_sign_ready_r_000(p_co_cd character varying, p_user_id character varying, p_from_dt character varying, p_to_dt character varying, p_keyword character varying, p_writer_id character varying) RETURNS TABLE(doc_idx bigint, co_cd character varying, tmpl_cd character varying, tmpl_nm character varying, doc_kind character varying, doc_no character varying, base_dt character varying, title character varying, status character varying, appr_line_cd character varying, writer_id character varying, writer_nm character varying, write_dt timestamp without time zone, ver_no integer, retention_until character varying, file_cnt integer, open_ca_cnt integer)
    LANGUAGE sql STABLE
    AS $$
    SELECT d.idx, d.co_cd, d.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm, d.tmpl_cd),
           d.doc_kind, d.doc_no, d.base_dt, d.title, d.status, d.appr_line_cd,
           d.writer_id, u.user_nm, d.write_dt, d.ver_no, d.retention_until,
           (SELECT count(*)::int FROM tbl_document_file f WHERE f.co_cd = d.co_cd AND f.doc_idx = d.idx AND f.file_kind IN ('ATTACH', 'PHOTO')),
           (SELECT count(*)::int FROM tbl_corrective_action ca
             WHERE ca.co_cd = d.co_cd AND ca.src_doc_idx = d.idx AND ca.status <> 'DONE')
      FROM tbl_document d
      JOIN tbl_document_approval a
        ON a.co_cd = d.co_cd AND a.doc_idx = d.idx
       AND a.result_cd = 'W'
       AND a.approver_id = p_user_id
       AND a.role_cd = 'APPROVE'
      -- 카탈로그는 자사 행만. 시드가 업체에 복사한다
      LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd AND t.co_cd = d.co_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = d.co_cd AND ct.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_user u ON u.co_cd = d.co_cd AND u.user_id = d.writer_id
     WHERE d.co_cd = p_co_cd
       AND d.del_yn = 'N'
       AND d.status = 'REQ'
       AND (COALESCE(p_from_dt, '') = '' OR d.base_dt >= p_from_dt)
       AND (COALESCE(p_to_dt, '') = '' OR d.base_dt <= p_to_dt)
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


--
-- Name: FUNCTION sp_sign_ready_r_000(p_co_cd character varying, p_user_id character varying, p_from_dt character varying, p_to_dt character varying, p_keyword character varying, p_writer_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_sign_ready_r_000(p_co_cd character varying, p_user_id character varying, p_from_dt character varying, p_to_dt character varying, p_keyword character varying, p_writer_id character varying) IS '결재대기(sign-ready) — 내 차례(대기) 문서만';


--
-- Name: sp_tbl_document_approval_c_000(character varying, bigint, character varying, character varying, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_document_approval_c_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_action_cd character varying, IN p_opinion character varying, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_status varchar(3);
    v_writer varchar(20);
    v_line varchar(20);
    -- 본문이 파일로 오는 유형인지 — HWP 만 상신 전에 본문 존재를 확인한다
    v_kind varchar(10);
    v_step record;
    v_pending record;
    v_user_nm varchar(50);
    -- 서명은 파일 경로가 아니라 바이너리다 — tbl_user.sign_img 를 결재 시점에 스냅샷한다
    v_sign_img bytea;
BEGIN
    SELECT d.status, d.writer_id, d.appr_line_cd, d.doc_kind
      INTO v_status, v_writer, v_line, v_kind
      FROM tbl_document d
     WHERE d.idx = p_doc_idx
       AND d.co_cd = p_co_cd
       AND d.del_yn = 'N'
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    SELECT user_nm, sign_img INTO v_user_nm, v_sign_img
      FROM tbl_user
     WHERE co_cd = p_co_cd
       AND user_id = p_id
       AND use_yn = 'Y';

    IF NOT FOUND THEN
        RAISE EXCEPTION '사용자 정보를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    IF p_action_cd = 'CANCEL' THEN
        -- 승인요청일 때(= 작성자가 상신취소 가능) 결재 스냅샷을 지우고 작성중으로 되돌린다
        IF v_status <> 'REQ' THEN
            RAISE EXCEPTION '승인요청 상태만 상신취소할 수 있습니다.' USING ERRCODE = '45000';
        END IF;
        IF v_writer IS DISTINCT FROM p_id THEN
            RAISE EXCEPTION '작성자만 상신취소할 수 있습니다.' USING ERRCODE = '45000';
        END IF;
        -- 승인 단계에 서명이 들어갔을 때(= 이미 처리됨) 취소 차단
        IF EXISTS (
            SELECT 1 FROM tbl_document_approval
             WHERE co_cd = p_co_cd
               AND doc_idx = p_doc_idx
               AND role_cd = 'APPROVE'
               AND result_cd <> 'W'
        ) THEN
            RAISE EXCEPTION '승인이 진행된 문서는 상신취소할 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        DELETE FROM tbl_document_approval
         WHERE co_cd = p_co_cd
           AND doc_idx = p_doc_idx;
        UPDATE tbl_document
           SET status = 'WRK',
               write_dt = NULL,
               upd_id = p_id,
               upd_dt = now()
         WHERE idx = p_doc_idx
           AND co_cd = p_co_cd;
        RETURN;
    END IF;

    IF p_action_cd = 'REQUEST' THEN
        -- 임시·반려일 때(= 작성자가 다시 상신 가능) 결재선 단계를 새로 스냅샷한다
        IF v_status NOT IN ('WRK', 'RJT') THEN
            RAISE EXCEPTION '작성중 또는 반려 문서만 결재 요청할 수 있습니다.' USING ERRCODE = '45000';
        END IF;
        IF v_writer IS DISTINCT FROM p_id THEN
            RAISE EXCEPTION '작성자만 결재 요청할 수 있습니다.' USING ERRCODE = '45000';
        END IF;

        /*
         * HWP 문서형은 본문이 첨부 파일(HWP_SRC)이다. 항목형과 달리 화면이 볼 점검 행이 없어
         * 전송 필수값 검사가 일자만 본다 — 그래서 본문이 아예 없는 문서도 상신·승인됐다.
         * 실제로 빈 문서가 결재완료까지 갔다.
         *
         * 상신은 작성 6화면과 결재첨부가 모두 이 프로시저로 모이므로 마지막 문은 여기다.
         * 화면마다 걸면 새 화면이 또 샌다.
         *
         * 여기서 던져도 안전하다 — processApproval 은 자기 트랜잭션이고 문서 저장 안이 아니다.
         * (같은 이유로 sp_tbl_doc_corrective_u_000 에서는 던지지 않는다. 그쪽은 저장 트랜잭션 안이다.)
         */
        IF v_kind = 'HWP' AND NOT EXISTS (
            SELECT 1 FROM tbl_document_file
             WHERE co_cd = p_co_cd
               AND doc_idx = p_doc_idx
               AND upper(file_kind) = 'HWP_SRC'
        ) THEN
            RAISE EXCEPTION '본문이 저장되지 않았습니다. 편집기에서 문서를 열고 저장한 뒤 전송하세요.'
                USING ERRCODE = '45000';
        END IF;

        DELETE FROM tbl_document_approval
         WHERE co_cd = p_co_cd
           AND doc_idx = p_doc_idx;

        FOR v_step IN
            SELECT step_no, role_cd, approver_id
              FROM tbl_approval_line_step
             WHERE co_cd = p_co_cd
               AND appr_line_cd = COALESCE(v_line, 'DEFAULT')
               -- 꺼 둔 단계(use_yn='N')는 결재선에 넣지 않는다.
               AND COALESCE(use_yn, 'Y') = 'Y'
             ORDER BY step_no
        LOOP
            INSERT INTO tbl_document_approval(
                co_cd, doc_idx, step_no, role_cd, approver_id,
                approver_nm, result_cd, ins_id, ins_dt
            )
            VALUES (
                p_co_cd, p_doc_idx, v_step.step_no, v_step.role_cd,
                CASE WHEN v_step.role_cd = 'WRITE' THEN p_id ELSE v_step.approver_id END,
                CASE WHEN v_step.role_cd = 'WRITE' THEN v_user_nm ELSE NULL END,
                CASE WHEN v_step.role_cd = 'WRITE' THEN 'A' ELSE 'W' END,
                p_id, now()
            );
        END LOOP;

        IF NOT EXISTS (
            SELECT 1 FROM tbl_document_approval
             WHERE co_cd = p_co_cd
               AND doc_idx = p_doc_idx
               AND role_cd = 'APPROVE'
        ) THEN
            RAISE EXCEPTION '승인 단계가 없는 결재선입니다.' USING ERRCODE = '45000';
        END IF;

        -- 재전송해도 reject_reason · cancel_reason 은 지우지 않는다. 줄마다 쌓인 이력을 작성자가 본다
        UPDATE tbl_document
           SET status = 'REQ',
               write_dt = now(),
               upd_id = p_id,
               upd_dt = now()
         WHERE idx = p_doc_idx
           AND co_cd = p_co_cd;
        RETURN;
    END IF;

    -- 현재 대기 단계 — WRITE는 REQUEST 시 승인되므로 APPROVE만 처리한다
    SELECT * INTO v_pending
      FROM tbl_document_approval
     WHERE co_cd = p_co_cd
       AND doc_idx = p_doc_idx
       AND result_cd = 'W'
     ORDER BY step_no
     LIMIT 1
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION '처리할 결재 단계가 없습니다.' USING ERRCODE = '45000';
    END IF;

    -- 지정 결재자가 있을 때(= 담당자 고정) 본인만, 미지정이면 ADMIN만 처리한다
    IF v_pending.approver_id IS NOT NULL AND v_pending.approver_id <> p_id THEN
        RAISE EXCEPTION '지정된 결재자만 처리할 수 있습니다.' USING ERRCODE = '45000';
    END IF;
    IF v_pending.approver_id IS NULL
       AND NOT EXISTS (
           SELECT 1 FROM tbl_user
            WHERE co_cd = p_co_cd
              AND user_id = p_id
              AND usrgrp_cd = 'ADMIN'
       ) THEN
        RAISE EXCEPTION '미지정 결재 단계는 관리자만 처리할 수 있습니다.' USING ERRCODE = '45000';
    END IF;

    IF p_action_cd = 'REJECT' THEN
        IF COALESCE(trim(p_opinion), '') = '' THEN
            RAISE EXCEPTION '반려 사유를 입력하세요.' USING ERRCODE = '45000';
        END IF;

        UPDATE tbl_document_approval
           SET approver_id = p_id,
               approver_nm = v_user_nm,
               result_cd = 'R',
               -- opinion 은 varchar(500). 같은 값이 reject_reason 에서는 left 로 잘리는데
               -- 여기서 안 자르면 긴 사유가 22001 로 반려 자체를 죽인다. 기준을 맞춘다
               opinion = left(p_opinion, 500),
               act_dt = now(),
               sign_img = v_sign_img,
               upd_id = p_id,
               upd_dt = now()
         WHERE idx = v_pending.idx
           AND co_cd = p_co_cd;

        UPDATE tbl_document
           SET status = 'RJT',
               -- 최신 사유를 맨 위에 쌓는다. 다시 전송해도 지우지 않는다
               reject_reason = left(
                   btrim(p_opinion)
                   || COALESCE(E'\n' || NULLIF(btrim(reject_reason), ''), ''),
                   500
               ),
               upd_id = p_id,
               upd_dt = now()
         WHERE idx = p_doc_idx
           AND co_cd = p_co_cd;
        RETURN;
    END IF;

    IF p_action_cd <> 'APPROVE' THEN
        RAISE EXCEPTION '지원하지 않는 결재 처리입니다.' USING ERRCODE = '45000';
    END IF;
    IF v_pending.role_cd <> 'APPROVE' THEN
        RAISE EXCEPTION '현재 단계는 승인 단계가 아닙니다.' USING ERRCODE = '45000';
    END IF;

    UPDATE tbl_document_approval
       SET approver_id = p_id,
           approver_nm = v_user_nm,
           result_cd = 'A',
           -- 승인 의견도 varchar(500). 반려와 같은 기준으로 자른다
           opinion = left(NULLIF(p_opinion, ''), 500),
           act_dt = now(),
           sign_img = v_sign_img,
           upd_id = p_id,
           upd_dt = now()
     WHERE idx = v_pending.idx
       AND co_cd = p_co_cd;

    -- 완료되지 않은 대기 단계가 남았을 때(= 결재선 순서를 지키지 못함) 승인 차단
    IF EXISTS (
        SELECT 1 FROM tbl_document_approval
         WHERE co_cd = p_co_cd
           AND doc_idx = p_doc_idx
           AND result_cd = 'W'
    ) THEN
        RAISE EXCEPTION '이전 결재 단계가 남아 있습니다.' USING ERRCODE = '45000';
    END IF;

    UPDATE tbl_document
       SET status = 'APV',
           approver_id = p_id,
           approve_dt = now(),
           upd_id = p_id,
           upd_dt = now()
     WHERE idx = p_doc_idx
       AND co_cd = p_co_cd;

    -- 승인 완료일 때(= 감사용 고정본 필요) 공통 헤더와 HWP 원본 경로를 버전 1회 스냅샷
    INSERT INTO tbl_document_version(
        co_cd, doc_idx, ver_no, snap_json, file_path, change_reason, ins_id, ins_dt
    )
    SELECT d.co_cd,
           d.idx,
           d.ver_no,
           to_jsonb(d),
           (
               SELECT f.file_path
                 FROM tbl_document_file f
                WHERE f.co_cd = d.co_cd
                  AND f.doc_idx = d.idx
                  AND f.file_kind = 'HWP_SRC'
                ORDER BY f.idx DESC
                LIMIT 1
           ),
           '승인 완료본',
           p_id,
           now()
      FROM tbl_document d
     WHERE d.idx = p_doc_idx
       AND d.co_cd = p_co_cd
    ON CONFLICT (doc_idx, ver_no) DO NOTHING;
END$$;


--
-- Name: PROCEDURE sp_tbl_document_approval_c_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_action_cd character varying, IN p_opinion character varying, IN p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_tbl_document_approval_c_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_action_cd character varying, IN p_opinion character varying, IN p_id character varying) IS '문서 결재 전이 — REQUEST/CANCEL/APPROVE/REJECT. REQUEST 는 reject_reason·cancel_reason 을 비우지 않는다. 꺼 둔 결재선 단계는 제외';


--
-- Name: sp_tbl_document_approval_r_000(character varying, bigint); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_document_approval_r_000(p_co_cd character varying, p_doc_idx bigint) RETURNS TABLE(idx bigint, doc_idx bigint, step_no integer, role_cd character varying, approver_id character varying, approver_nm character varying, result_cd character varying, opinion character varying, act_dt timestamp without time zone, sign_yn character varying)
    LANGUAGE sql STABLE
    AS $$
    SELECT a.idx, a.doc_idx, a.step_no, a.role_cd, a.approver_id,
           COALESCE(a.approver_nm, u.user_nm) AS approver_nm,
           a.result_cd, a.opinion, a.act_dt,
           -- 결재 시점 서명 스냅샷 보유여부 — 실물 바이너리는 문서 출력 경로에서만 읽는다
           (CASE WHEN a.sign_img IS NOT NULL THEN 'Y' ELSE 'N' END)::varchar
      FROM tbl_document_approval a
      LEFT JOIN tbl_user u ON u.co_cd = a.co_cd AND u.user_id = a.approver_id
     WHERE a.co_cd = p_co_cd
       AND a.doc_idx = p_doc_idx
     ORDER BY a.step_no;
$$;


--
-- Name: FUNCTION sp_tbl_document_approval_r_000(p_co_cd character varying, p_doc_idx bigint); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_tbl_document_approval_r_000(p_co_cd character varying, p_doc_idx bigint) IS '문서 결재 단계 조회 — 작성·승인 서명란';


--
-- Name: sp_tbl_document_paper_stamp_r_000(character varying, bigint); Type: FUNCTION; Schema: sasshaccp; Owner: -
--
-- 지면 작성자·승인자 칸 — CCP 모니터 detail 이 헤더에 안 실어 문서함 도장이 비었다.
-- hyg·ccp-verify SP 와 같은 출처(tbl_document · tbl_document_approval)를 한 곳에서 읽는다.

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_document_paper_stamp_r_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위
    p_co_cd character varying,
    -- p_doc_idx: tbl_document.idx
    p_doc_idx bigint
) RETURNS TABLE(
    writer_id character varying,
    writer_nm character varying,
    writer_sign_yn character varying,
    approver_id character varying,
    approver_nm character varying,
    approver_sign_yn character varying
)
    LANGUAGE sql STABLE
    AS $$
    SELECT d.writer_id,
           (SELECT u.user_nm FROM tbl_user u
             WHERE u.co_cd = d.co_cd AND u.user_id = d.writer_id),
           CASE WHEN EXISTS (
               SELECT 1 FROM tbl_user u
                WHERE u.co_cd = d.co_cd AND u.user_id = d.writer_id AND u.sign_img IS NOT NULL
           ) THEN 'Y' ELSE 'N' END,
           (SELECT a.approver_id FROM tbl_document_approval a
             WHERE a.co_cd = d.co_cd AND a.doc_idx = d.idx
               AND a.role_cd = 'APPROVE' AND a.result_cd = 'A'
             ORDER BY a.step_no DESC LIMIT 1),
           (SELECT a.approver_nm FROM tbl_document_approval a
             WHERE a.co_cd = d.co_cd AND a.doc_idx = d.idx
               AND a.role_cd = 'APPROVE' AND a.result_cd = 'A'
             ORDER BY a.step_no DESC LIMIT 1),
           CASE WHEN (
               SELECT a.sign_img FROM tbl_document_approval a
                WHERE a.co_cd = d.co_cd AND a.doc_idx = d.idx
                  AND a.role_cd = 'APPROVE' AND a.result_cd = 'A'
                ORDER BY a.step_no DESC LIMIT 1
           ) IS NOT NULL THEN 'Y' ELSE 'N' END
      FROM tbl_document d
     WHERE d.co_cd = p_co_cd AND d.idx = p_doc_idx AND d.del_yn = 'N';
$$;


COMMENT ON FUNCTION sasshaccp.sp_tbl_document_paper_stamp_r_000(p_co_cd character varying, p_doc_idx bigint) IS '지면 도장칸 — 작성자·승인 완료 결재자 이름·서명여부 (CCP 모니터 detail 공용)';


--
-- Name: sp_tbl_document_approval_u_000(character varying, bigint, character varying, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

DROP PROCEDURE IF EXISTS sasshaccp.sp_tbl_document_approval_u_000(character varying, bigint, character varying);
CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_document_approval_u_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_id character varying, IN p_opinion character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_status varchar(3);
    v_line varchar(20);
    v_ver int;
    v_step record;
BEGIN
    SELECT d.status, d.appr_line_cd, d.ver_no
      INTO v_status, v_line, v_ver
      FROM tbl_document d
     WHERE d.idx = p_doc_idx
       AND d.co_cd = p_co_cd
       AND d.del_yn = 'N'
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    -- 본인이 처리한 승인 단계 중 가장 마지막 한 건
    SELECT * INTO v_step
      FROM tbl_document_approval
     WHERE co_cd = p_co_cd
       AND doc_idx = p_doc_idx
       AND role_cd = 'APPROVE'
       AND result_cd <> 'W'
       AND approver_id = p_id
     ORDER BY step_no DESC
     LIMIT 1
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION '되돌릴 본인 결재가 없습니다.' USING ERRCODE = '45000';
    END IF;

    -- 뒷 단계가 이미 처리됐을 때(= 다음 결재자가 진행함) 취소 차단
    IF EXISTS (
        SELECT 1 FROM tbl_document_approval
         WHERE co_cd = p_co_cd
           AND doc_idx = p_doc_idx
           AND step_no > v_step.step_no
           AND result_cd <> 'W'
    ) THEN
        RAISE EXCEPTION '다음 결재자가 이미 처리한 문서는 결재를 취소할 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    -- 단계를 대기(W)로 되돌린다. 결재자 지정은 결재선 스냅샷 값으로 복구한다
    UPDATE tbl_document_approval a
       SET result_cd = 'W',
           approver_id = (
               SELECT s.approver_id
                 FROM tbl_approval_line_step s
                WHERE s.co_cd = p_co_cd
                  AND s.appr_line_cd = COALESCE(v_line, 'DEFAULT')
                  AND s.step_no = v_step.step_no
           ),
           approver_nm = NULL,
           opinion = NULL,
           act_dt = NULL,
           sign_img = NULL,
           upd_id = p_id,
           upd_dt = now()
     WHERE a.idx = v_step.idx
       AND a.co_cd = p_co_cd;

    -- 승인을 되돌린다 — 승인요청(REQ)으로
    UPDATE tbl_document
       SET status = 'REQ',
           approver_id = NULL,
           approve_dt = NULL,
           -- 최신 취소 사유를 맨 위에 쌓는다. 빈 의견이면 기존 줄을 유지한다
           cancel_reason = CASE
               WHEN NULLIF(btrim(COALESCE(p_opinion, '')), '') IS NULL THEN cancel_reason
               ELSE left(
                   btrim(p_opinion)
                   || COALESCE(E'\n' || NULLIF(btrim(cancel_reason), ''), ''),
                   500
               )
           END,
           upd_id = p_id,
           upd_dt = now()
     WHERE idx = p_doc_idx
       AND co_cd = p_co_cd;

    -- 승인 시 남긴 고정본 스냅샷을 걷어낸다 — 승인이 취소됐으니 완료본이 아니다
    IF v_status = 'APV' THEN
        DELETE FROM tbl_document_version
         WHERE co_cd = p_co_cd
           AND doc_idx = p_doc_idx
           AND ver_no = v_ver
           AND change_reason = '승인 완료본';
    END IF;
END$$;


--
-- Name: PROCEDURE sp_tbl_document_approval_u_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_id character varying, IN p_opinion character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_tbl_document_approval_u_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_id character varying, IN p_opinion character varying) IS '결재취소 — 본인이 처리한 마지막 단계를 되돌린다. 다음 결재자가 처리했으면 차단. p_opinion 은 cancel_reason 으로 남긴다';


--
-- Name: sp_tbl_document_d_000(character varying, bigint, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_document_d_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_status varchar(3);
    -- doc_kind 는 varchar(10) — html(4자)이 잘리지 않게 폭을 맞춘다
    v_kind varchar(10);
BEGIN
    SELECT status, doc_kind INTO v_status, v_kind
      FROM tbl_document
     WHERE idx = p_doc_idx
       AND co_cd = p_co_cd
       AND del_yn = 'N'
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    -- DB형(HTML)일 때(= 업무 헤더·상세가 연결됨) 전용 양식 삭제 SP로만 처리한다
    IF v_kind <> 'HWP' THEN
        RAISE EXCEPTION 'DB형 문서는 해당 양식 화면에서 삭제하세요.' USING ERRCODE = '45000';
    END IF;
    -- 임시·반려가 아닐 때(= 결재 흐름 또는 보존 대상) 삭제 차단
    IF v_status NOT IN ('WRK', 'RJT') THEN
        RAISE EXCEPTION '결재 진행 중이거나 완료된 문서는 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    DELETE FROM tbl_document_approval
     WHERE co_cd = p_co_cd
       AND doc_idx = p_doc_idx;
    DELETE FROM tbl_document_version
     WHERE co_cd = p_co_cd
       AND doc_idx = p_doc_idx;
    DELETE FROM tbl_document_file
     WHERE co_cd = p_co_cd
       AND doc_idx = p_doc_idx;
    DELETE FROM tbl_document
     WHERE co_cd = p_co_cd
       AND idx = p_doc_idx;
END$$;


--
-- Name: PROCEDURE sp_tbl_document_d_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_tbl_document_d_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_id character varying) IS '문서형 작성중·반려 문서 삭제 — 첨부·결재·버전 일괄 제거';


--
-- Name: sp_tbl_document_file_c_000(character varying, bigint, character varying, character varying, character varying, bigint, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_document_file_c_000(p_co_cd character varying, p_doc_idx bigint, p_file_kind character varying, p_file_nm character varying, p_file_path character varying, p_file_size bigint, p_mime_type character varying, p_id character varying) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_idx bigint;
    v_status varchar(3);
    v_cnt int;
BEGIN
    SELECT status INTO v_status
      FROM tbl_document
     WHERE idx = p_doc_idx
       AND co_cd = p_co_cd
       AND del_yn = 'N';

    IF NOT FOUND THEN
        RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    -- 결재 진행·완료일 때(= 기록 잠금) 본문·사용자 첨부 교체 차단
    -- PDF 완료본은 문서함 인쇄 변환이 남긴다. 본문(HWP_SRC)·첨부(ATTACH/PHOTO)는 그대로 막는다
    IF v_status IN ('REQ', 'APV') AND upper(trim(p_file_kind)) <> 'PDF' THEN
        RAISE EXCEPTION '결재 진행 중이거나 완료된 문서에는 파일을 추가할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    -- 사용자 첨부일 때(= 일반첨부·사진) 문서당 5개로 막는다. 화면도 같은 기준으로 먼저 막는다
    IF p_file_kind IN ('ATTACH', 'PHOTO') THEN
        SELECT count(*) INTO v_cnt
          FROM tbl_document_file
         WHERE co_cd = p_co_cd
           AND doc_idx = p_doc_idx
           AND file_kind IN ('ATTACH', 'PHOTO');
        IF v_cnt >= 5 THEN
            RAISE EXCEPTION '첨부파일은 최대 5개까지 등록할 수 있습니다.' USING ERRCODE = '45000';
        END IF;
    END IF;

    INSERT INTO tbl_document_file(
        co_cd, doc_idx, file_kind, file_nm, file_path, file_size,
        mime_type, sort_no, ins_id, ins_dt
    )
    VALUES (
        p_co_cd, p_doc_idx, p_file_kind, p_file_nm, p_file_path, p_file_size,
        p_mime_type,
        COALESCE((SELECT max(sort_no) + 1 FROM tbl_document_file
                   WHERE co_cd = p_co_cd AND doc_idx = p_doc_idx), 1),
        p_id, now()
    )
    RETURNING idx INTO v_idx;

    RETURN v_idx;
END$$;


--
-- Name: FUNCTION sp_tbl_document_file_c_000(p_co_cd character varying, p_doc_idx bigint, p_file_kind character varying, p_file_nm character varying, p_file_path character varying, p_file_size bigint, p_mime_type character varying, p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_tbl_document_file_c_000(p_co_cd character varying, p_doc_idx bigint, p_file_kind character varying, p_file_nm character varying, p_file_path character varying, p_file_size bigint, p_mime_type character varying, p_id character varying) IS '문서 파일 메타 등록 — 물리 저장 완료 후 호출. 사용자 첨부는 문서당 5개. PDF 완료본은 결재 잠금이어도 등록';


--
-- Name: sp_tbl_document_file_d_000(character varying, bigint, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_document_file_d_000(IN p_co_cd character varying, IN p_file_idx bigint, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_status varchar(3);
BEGIN
    SELECT d.status INTO v_status
      FROM tbl_document_file f
      JOIN tbl_document d ON d.idx = f.doc_idx AND d.co_cd = f.co_cd
     WHERE f.idx = p_file_idx
       AND f.co_cd = p_co_cd
       AND d.del_yn = 'N';

    IF NOT FOUND THEN
        RAISE EXCEPTION '파일을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    -- 결재 진행·완료일 때(= 기록 잠금) 첨부 삭제 차단
    IF v_status IN ('REQ', 'APV') THEN
        RAISE EXCEPTION '결재 진행 중이거나 완료된 문서의 파일은 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    DELETE FROM tbl_document_file
     WHERE idx = p_file_idx
       AND co_cd = p_co_cd;
END$$;


--
-- Name: PROCEDURE sp_tbl_document_file_d_000(IN p_co_cd character varying, IN p_file_idx bigint, IN p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_tbl_document_file_d_000(IN p_co_cd character varying, IN p_file_idx bigint, IN p_id character varying) IS '문서 파일 메타 삭제 — 물리 파일 제거 전 잠금 검사';


--
-- Name: sp_tbl_document_file_d_001(character varying, bigint, character varying, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_document_file_d_001(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_file_kind character varying, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_status varchar(3);
BEGIN
    SELECT d.status INTO v_status
      FROM tbl_document d
     WHERE d.idx = p_doc_idx
       AND d.co_cd = p_co_cd
       AND d.del_yn = 'N';

    IF NOT FOUND THEN
        RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF v_status IN ('REQ', 'APV') THEN
        RAISE EXCEPTION '결재 진행 중이거나 완료된 문서의 파일은 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    DELETE FROM tbl_document_file
     WHERE co_cd = p_co_cd
       AND doc_idx = p_doc_idx
       AND upper(file_kind) = upper(trim(p_file_kind));
END$$;


--
-- Name: PROCEDURE sp_tbl_document_file_d_001(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_file_kind character varying, IN p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_tbl_document_file_d_001(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_file_kind character varying, IN p_id character varying) IS '문서·파일종류별 메타 일괄 삭제 — HWP_SRC 덮어쓰기 전 호출';


--
-- Name: sp_tbl_document_file_r_000(character varying, bigint); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_document_file_r_000(p_co_cd character varying, p_doc_idx bigint) RETURNS TABLE(idx bigint, doc_idx bigint, file_kind character varying, file_nm character varying, file_path character varying, file_size bigint, mime_type character varying, sort_no integer, ins_id character varying, ins_dt timestamp without time zone)
    LANGUAGE sql STABLE
    AS $$
    SELECT f.idx, f.doc_idx, f.file_kind, f.file_nm, f.file_path, f.file_size,
           f.mime_type, f.sort_no, f.ins_id, f.ins_dt
      FROM tbl_document_file f
     WHERE f.co_cd = p_co_cd
       AND f.doc_idx = p_doc_idx
     ORDER BY f.sort_no, f.idx;
$$;


--
-- Name: FUNCTION sp_tbl_document_file_r_000(p_co_cd character varying, p_doc_idx bigint); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_tbl_document_file_r_000(p_co_cd character varying, p_doc_idx bigint) IS '문서 첨부 목록 — HWPX·PDF·사진·일반파일';


--
-- Name: sp_tbl_document_file_r_001(character varying, bigint); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_document_file_r_001(p_co_cd character varying, p_file_idx bigint) RETURNS TABLE(idx bigint, doc_idx bigint, file_kind character varying, file_nm character varying, file_path character varying, file_size bigint, mime_type character varying, sort_no integer, ins_id character varying, ins_dt timestamp without time zone)
    LANGUAGE sql STABLE
    AS $$
    SELECT f.idx, f.doc_idx, f.file_kind, f.file_nm, f.file_path, f.file_size,
           f.mime_type, f.sort_no, f.ins_id, f.ins_dt
      FROM tbl_document_file f
      JOIN tbl_document d ON d.idx = f.doc_idx AND d.co_cd = f.co_cd
     WHERE f.co_cd = p_co_cd
       AND f.idx = p_file_idx
       AND d.del_yn = 'N';
$$;


--
-- Name: FUNCTION sp_tbl_document_file_r_001(p_co_cd character varying, p_file_idx bigint); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_tbl_document_file_r_001(p_co_cd character varying, p_file_idx bigint) IS '문서 파일 단건 — 다운로드·물리 삭제 전 테넌트 확인';


--
-- Name: sp_tbl_document_r_000(character varying, character varying, character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_document_r_000(p_co_cd character varying, p_from_dt character varying, p_to_dt character varying, p_tmpl_cd character varying, p_status character varying, p_keyword character varying, p_writer_id character varying) RETURNS TABLE(doc_idx bigint, co_cd character varying, tmpl_cd character varying, tmpl_nm character varying, doc_kind character varying, doc_no character varying, base_dt character varying, title character varying, status character varying, appr_line_cd character varying, writer_id character varying, writer_nm character varying, write_dt timestamp without time zone, ver_no integer, retention_until character varying, file_cnt integer, open_ca_cnt integer)
    LANGUAGE sql STABLE
    AS $$
    SELECT d.idx, d.co_cd, d.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm, d.tmpl_cd),
           d.doc_kind, d.doc_no, d.base_dt, d.title, d.status, d.appr_line_cd,
           d.writer_id, u.user_nm, d.write_dt, d.ver_no, d.retention_until,
           (SELECT count(*)::int FROM tbl_document_file f WHERE f.co_cd = d.co_cd AND f.doc_idx = d.idx AND f.file_kind IN ('ATTACH', 'PHOTO')),
           (SELECT count(*)::int FROM tbl_corrective_action ca
             WHERE ca.co_cd = d.co_cd AND ca.src_doc_idx = d.idx AND ca.status <> 'DONE')
      FROM tbl_document d
      -- 카탈로그는 자사 행만. 시드가 업체에 복사한다
      LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd AND t.co_cd = d.co_cd
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


--
-- Name: FUNCTION sp_tbl_document_r_000(p_co_cd character varying, p_from_dt character varying, p_to_dt character varying, p_tmpl_cd character varying, p_status character varying, p_keyword character varying, p_writer_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_tbl_document_r_000(p_co_cd character varying, p_from_dt character varying, p_to_dt character varying, p_tmpl_cd character varying, p_status character varying, p_keyword character varying, p_writer_id character varying) IS '문서함 목록·검색 — DB형·HWP형 통합';


--
-- Name: sp_tbl_document_r_001(character varying, bigint); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

DROP FUNCTION IF EXISTS sasshaccp.sp_tbl_document_r_001(character varying, bigint);
CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_document_r_001(p_co_cd character varying, p_doc_idx bigint) RETURNS TABLE(doc_idx bigint, co_cd character varying, tmpl_cd character varying, tmpl_nm character varying, doc_kind character varying, doc_no character varying, base_dt character varying, base_dt_to character varying, title character varying, status character varying, appr_line_cd character varying, writer_id character varying, writer_nm character varying, write_dt timestamp without time zone, approver_id character varying, approver_nm character varying, approve_dt timestamp without time zone, reject_reason character varying, ver_no integer, retention_until character varying, remark character varying, cancel_reason character varying)
    LANGUAGE sql STABLE
    AS $$
    SELECT d.idx AS doc_idx,
           d.co_cd,
           d.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm, d.tmpl_cd) AS tmpl_nm,
           d.doc_kind,
           d.doc_no,
           d.base_dt,
           d.base_dt_to,
           d.title,
           d.status,
           d.appr_line_cd,
           d.writer_id,
           wu.user_nm AS writer_nm,
           d.write_dt,
           d.approver_id,
           au.user_nm AS approver_nm,
           d.approve_dt,
           d.reject_reason,
           d.ver_no,
           d.retention_until,
           d.remark,
           d.cancel_reason
      FROM tbl_document d
      -- 카탈로그는 자사 행만. 시드가 업체에 복사한다
      LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd AND t.co_cd = d.co_cd
      LEFT JOIN tbl_company_template ct
        ON ct.co_cd = d.co_cd AND ct.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_user wu ON wu.co_cd = d.co_cd AND wu.user_id = d.writer_id
      LEFT JOIN tbl_user au ON au.co_cd = d.co_cd AND au.user_id = d.approver_id
     WHERE d.co_cd = p_co_cd
       AND d.idx = p_doc_idx
       AND d.del_yn = 'N';
$$;


--
-- Name: FUNCTION sp_tbl_document_r_001(p_co_cd character varying, p_doc_idx bigint); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_tbl_document_r_001(p_co_cd character varying, p_doc_idx bigint) IS '문서 공통 헤더 단건 — 문서함 상세·결재 패널·결재 첨부';


-- 문서 관계 SP — 화면이 안 불러 고아. 이미 도는 DB 에도 DROP
DROP PROCEDURE IF EXISTS sasshaccp.sp_tbl_document_relation_c_000(character varying, bigint, character varying, bigint, character varying);
DROP FUNCTION IF EXISTS sasshaccp.sp_tbl_document_relation_r_000(character varying, bigint);

--
-- Name: sp_tbl_document_template_r_000(character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_document_template_r_000(p_co_cd character varying) RETURNS TABLE(tmpl_cd character varying, tmpl_nm character varying, doc_kind character varying, category_cd character varying, mng_no character varying, form_path character varying, form_file_nm character varying, sys_yn character varying)
    LANGUAGE sql
    AS $$
    SELECT t.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm),
           t.doc_kind,
           t.category_cd,
           t.mng_no,
           COALESCE(NULLIF(ct.form_path, ''), t.form_path),
           CASE
             WHEN COALESCE(NULLIF(ct.form_path, ''), t.form_path) IS NULL THEN NULL
             ELSE regexp_replace(COALESCE(NULLIF(ct.form_path, ''), t.form_path), '^.*/', '')
           END,
           COALESCE(ct.sys_yn, 'Y')
      FROM tbl_company_template ct
      -- 카탈로그는 자사 행만. 시드가 업체에 복사한다
      JOIN tbl_template t ON t.tmpl_cd = ct.tmpl_cd AND t.co_cd = ct.co_cd
     -- p_co_cd 가 빠지면 전 회사 사용양식이 한 콤보에 섞인다 (HWP 작성 양식 선택)
     WHERE ct.co_cd = p_co_cd
       AND t.impl_yn = 'Y'
       AND t.use_yn = 'Y'
       AND ct.use_yn = 'Y'
       AND (
            COALESCE(NULLIF(ct.form_path, ''), t.form_path) IS NOT NULL
            OR t.category_cd = 'LAW'
       )
     ORDER BY t.sort_no, t.tmpl_cd;
$$;


--
-- Name: FUNCTION sp_tbl_document_template_r_000(p_co_cd character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_tbl_document_template_r_000(p_co_cd character varying) IS '회사 사용양식 목록 — p_co_cd 자사만. LAW는 form 없이도 노출, 그 외는 form_path 필수';


--
-- Name: sp_tbl_document_template_r_001(character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_document_template_r_001(p_co_cd character varying, p_tmpl_cd character varying) RETURNS TABLE(tmpl_cd character varying, tmpl_nm character varying, doc_kind character varying, category_cd character varying, mng_no character varying, form_path character varying, form_file_nm character varying, sys_yn character varying)
    LANGUAGE sql
    AS $$
    SELECT t.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm),
           t.doc_kind,
           t.category_cd,
           t.mng_no,
           COALESCE(NULLIF(ct.form_path, ''), t.form_path),
           CASE
             WHEN COALESCE(NULLIF(ct.form_path, ''), t.form_path) IS NULL THEN NULL
             ELSE regexp_replace(COALESCE(NULLIF(ct.form_path, ''), t.form_path), '^.*/', '')
           END,
           COALESCE(ct.sys_yn, 'Y')
      FROM tbl_company_template ct
      -- 카탈로그는 자사 행만. 시드가 업체에 복사한다
      JOIN tbl_template t ON t.tmpl_cd = ct.tmpl_cd AND t.co_cd = ct.co_cd
     -- 단건도 자사 행만. 빠지면 같은 tmpl_cd 의 타사 form_path 가 열릴 수 있다
     WHERE ct.co_cd = p_co_cd
       AND t.tmpl_cd = p_tmpl_cd
       AND t.impl_yn = 'Y'
       AND t.use_yn = 'Y'
       AND ct.use_yn = 'Y';
$$;


--
-- Name: FUNCTION sp_tbl_document_template_r_001(p_co_cd character varying, p_tmpl_cd character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_tbl_document_template_r_001(p_co_cd character varying, p_tmpl_cd character varying) IS '회사 사용양식 단건 — p_co_cd 자사만. form_path 없어도 메타 반환(법적서류 최초 업로드용)';


--
-- Name: sp_tbl_document_u_001(character varying, bigint, character varying, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_document_u_001(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_remark character varying, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_status varchar(3);
    v_writer varchar(20);
BEGIN
    SELECT status, writer_id INTO v_status, v_writer
      FROM tbl_document
     WHERE idx = p_doc_idx
       AND co_cd = p_co_cd
       AND del_yn = 'N'
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    -- 작성자가 아닐 때(= 남의 문서) 차단. 화면 필터를 우회한 직접 호출도 여기서 막힌다
    IF v_writer IS DISTINCT FROM p_id THEN
        RAISE EXCEPTION '작성자만 비고를 수정할 수 있습니다.' USING ERRCODE = '45000';
    END IF;
    -- 결재완료일 때(= 기록 확정) 비고도 잠근다
    IF v_status = 'APV' THEN
        RAISE EXCEPTION '결재가 완료된 문서의 비고는 수정할 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    UPDATE tbl_document
       SET remark = NULLIF(btrim(COALESCE(p_remark, '')), ''),
           upd_id = p_id,
           upd_dt = now()
     WHERE idx = p_doc_idx
       AND co_cd = p_co_cd;
END$$;


--
-- Name: PROCEDURE sp_tbl_document_u_001(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_remark character varying, IN p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_tbl_document_u_001(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_remark character varying, IN p_id character varying) IS '문서 비고 저장 — 결재 첨부 화면. 작성자 본인·결재완료 전까지';


--
-- Name: sp_tbl_document_title_u_000(character varying, bigint, character varying, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_document_title_u_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_title character varying, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_writer varchar(20);
BEGIN
    SELECT writer_id INTO v_writer
      FROM tbl_document
     WHERE idx = p_doc_idx
       AND co_cd = p_co_cd
       AND del_yn = 'N'
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    -- 작성자가 아닐 때(= 남의 문서) 차단
    IF v_writer IS DISTINCT FROM p_id THEN
        RAISE EXCEPTION '작성자만 제목을 수정할 수 있습니다.' USING ERRCODE = '45000';
    END IF;

    UPDATE tbl_document
       SET title = NULLIF(btrim(COALESCE(p_title, '')), ''),
           upd_id = p_id,
           upd_dt = now()
     WHERE idx = p_doc_idx
       AND co_cd = p_co_cd;
END$$;

COMMENT ON PROCEDURE sasshaccp.sp_tbl_document_title_u_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_title character varying, IN p_id character varying) IS '작성 목록 비고(제목) 저장 — tbl_document.title. 결재 첨부 remark 와 다르다. 상태와 무관';


--
-- Name: sp_tbl_document_version_r_000(character varying, bigint); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_document_version_r_000(p_co_cd character varying, p_doc_idx bigint) RETURNS TABLE(idx bigint, doc_idx bigint, ver_no integer, file_path character varying, change_reason character varying, ins_id character varying, ins_dt timestamp without time zone)
    LANGUAGE sql STABLE
    AS $$
    SELECT v.idx, v.doc_idx, v.ver_no, v.file_path, v.change_reason, v.ins_id, v.ins_dt
      FROM tbl_document_version v
     WHERE v.co_cd = p_co_cd
       AND v.doc_idx = p_doc_idx
     ORDER BY v.ver_no DESC;
$$;


--
-- Name: FUNCTION sp_tbl_document_version_r_000(p_co_cd character varying, p_doc_idx bigint); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_tbl_document_version_r_000(p_co_cd character varying, p_doc_idx bigint) IS '문서 버전 목록 — 승인 문서 변경 전 스냅샷';


--
-- Name: sp_tbl_grid_pref_c_000(character varying, character varying, character varying, character varying, text); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_grid_pref_c_000(IN p_co_cd character varying, IN p_user_id character varying, IN p_scrn_cd character varying, IN p_grid_id character varying, IN p_pref_json text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF COALESCE(p_pref_json, '') = '' THEN
        DELETE FROM tbl_grid_pref
         WHERE co_cd = p_co_cd AND user_id = p_user_id AND scrn_cd = p_scrn_cd AND grid_id = p_grid_id;
        RETURN;
    END IF;

    INSERT INTO tbl_grid_pref(co_cd, user_id, scrn_cd, grid_id, pref_json, ins_id, ins_dt)
    VALUES (p_co_cd, p_user_id, p_scrn_cd, p_grid_id, p_pref_json, p_user_id, now())
    ON CONFLICT (user_id, scrn_cd, grid_id) DO UPDATE SET
        pref_json = EXCLUDED.pref_json,
        upd_id    = p_user_id,
        upd_dt    = now();
END$$;


--
-- Name: PROCEDURE sp_tbl_grid_pref_c_000(IN p_co_cd character varying, IN p_user_id character varying, IN p_scrn_cd character varying, IN p_grid_id character varying, IN p_pref_json text); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_tbl_grid_pref_c_000(IN p_co_cd character varying, IN p_user_id character varying, IN p_scrn_cd character varying, IN p_grid_id character varying, IN p_pref_json text) IS '그리드 열 설정 업서트 — 빈 JSON이면 초기화(행 삭제)';


--
-- Name: sp_tbl_grid_pref_r_000(character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_grid_pref_r_000(p_co_cd character varying, p_user_id character varying, p_scrn_cd character varying) RETURNS TABLE(idx bigint, scrn_cd character varying, grid_id character varying, pref_json text)
    LANGUAGE sql
    AS $$
    SELECT g.idx, g.scrn_cd, g.grid_id, g.pref_json
      FROM tbl_grid_pref g
     WHERE g.co_cd = p_co_cd
       AND g.user_id = p_user_id
       AND g.scrn_cd LIKE CONCAT('%', COALESCE(p_scrn_cd, ''), '%')
     ORDER BY g.scrn_cd, g.grid_id;
$$;


--
-- Name: FUNCTION sp_tbl_grid_pref_r_000(p_co_cd character varying, p_user_id character varying, p_scrn_cd character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_tbl_grid_pref_r_000(p_co_cd character varying, p_user_id character varying, p_scrn_cd character varying) IS '사용자 그리드 열 설정 조회 — 화면 진입 시 1회';


--
-- Name: sp_tbl_html_hyg_prc_ver_apply_u_000(character varying, character varying, integer, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_html_hyg_prc_ver_apply_u_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_ver_no integer, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE tbl_html_hyg_prc_ver SET apply_yn = 'N', upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND apply_yn = 'Y';
    IF COALESCE(p_ver_no, 0) > 0 THEN
        UPDATE tbl_html_hyg_prc_ver SET apply_yn = 'Y', upd_id = p_id, upd_dt = now()
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
        IF NOT FOUND THEN RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    END IF;
END$$;


--
-- Name: sp_tbl_html_hyg_prc_ver_copy_c_000(character varying, character varying, integer, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_html_hyg_prc_ver_copy_c_000(p_co_cd character varying, p_tmpl_cd character varying, p_src_ver_no integer, p_ver_cd character varying, p_ver_nm character varying, p_id character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE v_nm varchar; v_n int; v_cd varchar; v_src tbl_template%ROWTYPE; v_try int := 0;
BEGIN
    IF COALESCE(p_co_cd, '') = '' THEN
        RAISE EXCEPTION '회사코드는 필수입니다.' USING ERRCODE = '45000';
    END IF;
    v_nm := btrim(COALESCE(p_ver_nm, ''));
    IF v_nm = '' THEN
        RAISE EXCEPTION '양식명은 필수입니다.' USING ERRCODE = '45000';
    END IF;
    SELECT * INTO v_src FROM tbl_template WHERE tmpl_cd = 'html_sys_001' AND co_cd = p_co_cd;
    IF NOT FOUND THEN
        RAISE EXCEPTION '표준 양식을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    -- 다음 번호는 이 회사 카탈로그 MAX+1
    SELECT COALESCE(MAX(substring(t.tmpl_cd from '[0-9]{3}$')::int), 0) INTO v_n
      FROM tbl_template t
     WHERE t.co_cd = p_co_cd AND t.tmpl_cd ~ '^html_hyg_prc_[0-9]{3}$' AND t.tmpl_cd <> 'html_hyg_prc_000';
    LOOP
        v_try := v_try + 1; v_n := v_n + 1;
        IF v_n > 999 OR v_try > 50 THEN
            RAISE EXCEPTION '양식코드를 더 부여할 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        v_cd := 'html_hyg_prc_' || lpad(v_n::text, 3, '0');
        IF v_cd = 'html_hyg_prc_000' THEN CONTINUE; END IF;
        EXIT WHEN NOT EXISTS (SELECT 1 FROM tbl_template WHERE tmpl_cd = v_cd AND co_cd = p_co_cd);
    END LOOP;
    INSERT INTO tbl_template (
        co_cd, tmpl_cd, tmpl_nm, mng_no, doc_kind, category_cd, scrn_cd,
        default_cycle_cd, default_retention_month, impl_yn, sort_no, use_yn, ins_id, ins_dt
    ) VALUES (
        p_co_cd, v_cd, v_nm, v_src.mng_no, 'HTML', v_src.category_cd, 'hygiene-process-check',
        'D', COALESCE(v_src.default_retention_month, 24), 'Y',
        COALESCE(v_src.sort_no, 101) + v_n, 'Y', p_id, now()
    );
    INSERT INTO tbl_company_template (
        co_cd, tmpl_cd, tmpl_nm_ovr, cycle_cd, retention_month, use_yn, sys_yn, ins_id, ins_dt
    ) VALUES (
        p_co_cd, v_cd, v_nm, 'D', COALESCE(v_src.default_retention_month, 24), 'Y', 'usr', p_id, now()
    );
    INSERT INTO tbl_html_hyg_prc_ver (co_cd, tmpl_cd, ver_no, ver_cd, ver_nm, apply_yn, use_yn, ins_id, ins_dt)
    VALUES (p_co_cd, v_cd, 1, v_cd, v_nm, 'N', 'Y', p_id, now());
    INSERT INTO tbl_html_hyg_prc_ver_item (
        co_cd, tmpl_cd, ver_no, item_cd, sort_no, cycle_nm, grp_nm, item_nm, input_type, unit_nm, ins_id
    )
    SELECT p_co_cd, v_cd, 1, c.item_cd, c.sort_no, c.cycle_nm, c.grp_nm, c.item_nm, c.input_type, c.unit_nm, p_id
      FROM tbl_check_item c WHERE c.tmpl_cd = 'html_sys_001' AND c.use_yn = 'Y';
    -- 주기는 문서주기 화면에서만 만든다. 양식 복사는 사용양식·지면만
    RETURN v_cd;
END$_$;


--
-- Name: sp_tbl_html_hyg_prc_ver_d_000(character varying, character varying, integer, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_html_hyg_prc_ver_d_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_ver_no integer, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF COALESCE(p_tmpl_cd, '') IN ('html_hyg_prc_000', 'html_hyg_000', 'html_sys_001') OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 양식은 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM tbl_html_hyg_prc_ver
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y'
    ) THEN
        RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    -- 문서 없는 예정·밀린 과제·주기·채번·사용양식은 양식과 같이 지운다
    DELETE FROM tbl_schedule_task
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd
       AND status IN ('TODO', 'LATE') AND doc_idx IS NULL;
    DELETE FROM tbl_schedule_rule_detail WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    DELETE FROM tbl_schedule_rule WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    DELETE FROM tbl_doc_no_rule WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    DELETE FROM tbl_company_template WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    UPDATE tbl_html_hyg_prc_ver SET use_yn = 'N', apply_yn = 'N', upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
END$$;


--
-- Name: sp_tbl_html_hyg_prc_ver_delete_blocker_r_000(character varying, character varying, integer); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_html_hyg_prc_ver_delete_blocker_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_ver_no integer) RETURNS TABLE(ref_key character varying, target character varying)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE v_nm varchar; v_use varchar; v_key varchar;
BEGIN
    v_key := COALESCE(NULLIF(btrim(p_tmpl_cd), ''), COALESCE(p_ver_no::varchar, ''));
    IF COALESCE(p_tmpl_cd, '') IN ('html_hyg_prc_000', 'html_hyg_000', 'html_sys_001') OR COALESCE(p_ver_no, 0) <= 0 THEN
        RETURN QUERY SELECT '표준'::varchar, '시스템 표준 항목'::varchar; RETURN;
    END IF;
    SELECT ver_nm, use_yn INTO v_nm, v_use FROM tbl_html_hyg_prc_ver
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
    IF v_nm IS NULL OR v_use = 'N' THEN
        RETURN QUERY SELECT v_key, '없는 양식'::varchar; RETURN;
    END IF;
    IF EXISTS (SELECT 1 FROM tbl_document d WHERE d.co_cd = p_co_cd AND d.tmpl_cd = p_tmpl_cd AND d.del_yn = 'N') THEN
        RETURN QUERY SELECT COALESCE(v_nm, v_key), '작성 문서'::varchar; RETURN;
    END IF;
END$$;


--
-- Name: sp_tbl_html_hyg_prc_ver_item_r_000(character varying, character varying, integer); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_html_hyg_prc_ver_item_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_ver_no integer) RETURNS TABLE(item_cd character varying, sort_no integer, cycle_nm character varying, grp_nm character varying, item_nm text, input_type character varying, unit_nm character varying)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    -- 예시·옛 코드·시드일 때(= html_sys_001)
    IF COALESCE(p_tmpl_cd, '') IN ('html_hyg_prc_000', 'html_hyg_000', 'html_sys_001', '') THEN
        RETURN QUERY
        SELECT c.item_cd, c.sort_no, c.cycle_nm, c.grp_nm, c.item_nm, c.input_type, c.unit_nm
          FROM tbl_check_item c
         WHERE c.tmpl_cd = 'html_sys_001' AND c.use_yn = 'Y'
         ORDER BY c.sort_no, c.item_cd;
        RETURN;
    END IF;
    RETURN QUERY
    SELECT i.item_cd, i.sort_no, i.cycle_nm, i.grp_nm, i.item_nm, i.input_type, i.unit_nm
      FROM tbl_html_hyg_prc_ver_item i
     WHERE i.co_cd = p_co_cd AND i.tmpl_cd = p_tmpl_cd AND i.ver_no = p_ver_no
     ORDER BY i.sort_no, i.item_cd;
END$$;


--
-- Name: sp_tbl_html_hyg_prc_ver_item_u_000(character varying, character varying, integer, jsonb, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_html_hyg_prc_ver_item_u_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_ver_no integer, IN p_items jsonb, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE e jsonb; v_cnt int := 0;
BEGIN
    IF COALESCE(p_tmpl_cd, '') IN ('html_hyg_prc_000', 'html_hyg_000', 'html_sys_001') OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 항목은 수정할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM tbl_html_hyg_prc_ver
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y'
    ) THEN
        RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' THEN
        RAISE EXCEPTION '점검항목 자료가 올바르지 않습니다.' USING ERRCODE = '45000';
    END IF;
    /*
     * 점검 항목이 하나도 없는 양식은 저장하지 않는다.
     *
     * 예전에는 0건도 저장됐다. 그런데 그 양식으로 쓴 일지는 **전송할 때** 「점검 행이 없습니다」로
     * 막힌다 — 양식을 만든 사람과 막히는 사람이 다르고, 시점도 며칠 떨어져 있어
     * 작성자는 자기가 뭘 잘못했는지 알 길이 없다. 만든 자리에서 막는다.
     */
    IF jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION '점검항목을 한 줄 이상 넣으세요.' USING ERRCODE = '45000';
    END IF;
    DELETE FROM tbl_html_hyg_prc_ver_item WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
    FOR e IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_cnt := v_cnt + 1;
        INSERT INTO tbl_html_hyg_prc_ver_item (
            co_cd, tmpl_cd, ver_no, item_cd, sort_no, cycle_nm, grp_nm, item_nm, input_type, unit_nm, ins_id, upd_id, upd_dt
        ) VALUES (
            p_co_cd, p_tmpl_cd, p_ver_no,
            COALESCE(NULLIF(e->>'itemCd', ''), 'hp-u-' || lpad(v_cnt::text, 3, '0')),
            COALESCE(NULLIF(e->>'sortNo', '')::int, v_cnt),
            NULLIF(e->>'cycleNm', ''), NULLIF(e->>'grpNm', ''), COALESCE(e->>'itemNm', ''),
            COALESCE(NULLIF(e->>'inputType', ''), 'radio'), NULLIF(e->>'unitNm', ''),
            p_id, p_id, now()
        );
    END LOOP;
    UPDATE tbl_html_hyg_prc_ver SET upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
END$$;


--
-- Name: sp_tbl_html_hyg_prc_ver_nm_u_000(character varying, character varying, integer, character varying, character varying, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_html_hyg_prc_ver_nm_u_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_ver_no integer, IN p_ver_nm character varying, IN p_use_yn character varying, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE v_nm varchar; v_use varchar;
BEGIN
    IF COALESCE(p_tmpl_cd, '') IN ('html_hyg_prc_000', 'html_hyg_000', 'html_sys_001') OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 양식명은 수정할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    v_nm := btrim(COALESCE(p_ver_nm, ''));
    IF v_nm = '' THEN RAISE EXCEPTION '양식명은 필수입니다.' USING ERRCODE = '45000'; END IF;
    v_use := CASE WHEN upper(left(btrim(COALESCE(p_use_yn, 'Y')), 1)) = 'N' THEN 'N' ELSE 'Y' END;
    UPDATE tbl_html_hyg_prc_ver SET ver_nm = v_nm, upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
    IF NOT FOUND THEN RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    UPDATE tbl_template SET tmpl_nm = v_nm, upd_id = p_id, upd_dt = now() WHERE tmpl_cd = p_tmpl_cd AND co_cd = p_co_cd;
    UPDATE tbl_company_template
       SET tmpl_nm_ovr = v_nm, use_yn = v_use, upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
END$$;


--
-- Name: sp_tbl_html_hyg_prc_ver_r_000(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_html_hyg_prc_ver_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_ver_cd character varying DEFAULT NULL::character varying, p_ver_nm character varying DEFAULT NULL::character varying) RETURNS TABLE(idx bigint, tmpl_cd character varying, ver_no integer, ver_cd character varying, ver_nm character varying, sys_yn character varying, apply_yn character varying, locked_yn character varying, ins_nm character varying, ins_dt character varying, use_yn character varying)
    LANGUAGE sql STABLE
    AS $_$
    SELECT x.idx, x.tmpl_cd, x.ver_no, x.ver_cd, x.ver_nm, x.sys_yn, x.apply_yn, x.locked_yn, x.ins_nm, x.ins_dt, x.use_yn
      FROM (
            SELECT NULL::bigint, 'html_hyg_prc_000'::varchar, 0, 'html_hyg_prc_000'::varchar,
                   '표준'::varchar, 'sys'::varchar, 'N'::varchar, 'Y'::varchar, ''::varchar, ''::varchar, 'N'::varchar
            UNION ALL
            SELECT v.idx, v.tmpl_cd, v.ver_no,
                   COALESCE(NULLIF(btrim(v.ver_cd), ''), v.tmpl_cd),
                   COALESCE(ct.tmpl_nm_ovr, v.ver_nm),
                   'usr'::varchar, v.apply_yn, 'N'::varchar,
                   COALESCE(u.user_nm, v.ins_id, '')::varchar,
                   COALESCE(to_char(v.ins_dt, 'YYYY-MM-DD'), '')::varchar,
                   CASE WHEN upper(COALESCE(ct.use_yn, 'Y')) = 'N' THEN 'N' ELSE 'Y' END
              FROM tbl_html_hyg_prc_ver v
              JOIN tbl_company_template ct ON ct.co_cd = v.co_cd AND ct.tmpl_cd = v.tmpl_cd
              LEFT JOIN tbl_user u ON u.co_cd = v.co_cd AND u.user_id = v.ins_id
             WHERE v.co_cd = p_co_cd AND v.use_yn = 'Y'
               AND v.tmpl_cd ~ '^html_hyg_prc_[0-9]{3}$' AND v.tmpl_cd <> 'html_hyg_prc_000'
           ) x(idx, tmpl_cd, ver_no, ver_cd, ver_nm, sys_yn, apply_yn, locked_yn, ins_nm, ins_dt, use_yn)
     WHERE (COALESCE(btrim(p_ver_cd), '') = '' OR x.tmpl_cd ILIKE '%' || btrim(p_ver_cd) || '%')
       AND (COALESCE(btrim(p_ver_nm), '') = '' OR x.ver_nm ILIKE '%' || btrim(p_ver_nm) || '%')
     ORDER BY x.tmpl_cd;
$_$;


--
-- Name: sp_tbl_hwp_document_c_000(character varying, bigint, character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_hwp_document_c_000(p_co_cd character varying, p_doc_idx bigint, p_tmpl_cd character varying, p_base_dt character varying, p_base_dt_to character varying, p_title character varying, p_id character varying) RETURNS bigint
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_idx bigint;
    v_tmpl_nm varchar(200);
    -- doc_kind 는 varchar(10) — hwp/html 정본
    v_doc_kind varchar(10);
    v_use_yn varchar(1);
    v_appr_line_cd varchar(20);
    v_retention_month int;
    v_doc_no varchar(50);
BEGIN
    IF COALESCE(p_base_dt, '') !~ '^[0-9]{8}$' THEN
        RAISE EXCEPTION '기준일자는 YYYYMMDD 형식이어야 합니다.' USING ERRCODE = '45000';
    END IF;

    SELECT t.tmpl_nm,
           t.doc_kind,
           ct.use_yn,
           ct.appr_line_cd,
           COALESCE(ct.retention_month, t.default_retention_month)
      INTO v_tmpl_nm, v_doc_kind, v_use_yn, v_appr_line_cd, v_retention_month
      FROM tbl_template t
      JOIN tbl_company_template ct
        ON ct.co_cd = p_co_cd AND ct.tmpl_cd = t.tmpl_cd
     WHERE t.tmpl_cd = p_tmpl_cd
       AND t.impl_yn = 'Y'
       AND t.use_yn = 'Y'
       AND t.co_cd = p_co_cd;

    -- 양식이 없거나 HWP 형이 아니거나 회사 미사용일 때(= 이 화면 대상 아님) 업무 오류
    IF NOT FOUND OR v_doc_kind <> 'HWP' OR v_use_yn <> 'Y' THEN
        RAISE EXCEPTION '사용 가능한 문서형 양식이 아닙니다.' USING ERRCODE = '45000';
    END IF;

    IF COALESCE(p_doc_idx, 0) <= 0 THEN
        v_doc_no := sp_tbl_doc_no_gen_c_000(p_co_cd, p_tmpl_cd, p_base_dt);
        INSERT INTO tbl_document(
            co_cd, tmpl_cd, doc_kind, doc_no, base_dt, base_dt_to, title,
            status, appr_line_cd, writer_id, ver_no, retention_until, del_yn,
            ins_id, ins_dt
        )
        VALUES (
            p_co_cd, p_tmpl_cd, 'HWP', v_doc_no, p_base_dt, NULLIF(p_base_dt_to, ''),
            COALESCE(NULLIF(trim(p_title), ''), v_tmpl_nm || ' (' || to_char(to_date(p_base_dt, 'YYYYMMDD'), 'YYYY-MM-DD') || ')'),
            'WRK', v_appr_line_cd, p_id, 1,
            to_char(to_date(p_base_dt, 'YYYYMMDD') + make_interval(months => v_retention_month), 'YYYYMMDD'),
            'N', p_id, now()
        )
        RETURNING idx INTO v_idx;
    ELSE
        SELECT idx INTO v_idx
          FROM tbl_document
         WHERE idx = p_doc_idx
           AND co_cd = p_co_cd
           AND doc_kind = 'HWP'
           AND writer_id = p_id
           AND status IN ('WRK', 'RJT')
           AND del_yn = 'N'
         FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION '작성자 본인의 작성중 또는 반려 문서만 수정할 수 있습니다.' USING ERRCODE = '45000';
        END IF;

        UPDATE tbl_document
           SET base_dt = p_base_dt,
               base_dt_to = NULLIF(p_base_dt_to, ''),
               title = COALESCE(NULLIF(trim(p_title), ''), title),
               upd_id = p_id,
               upd_dt = now()
         WHERE idx = v_idx
           AND co_cd = p_co_cd;
    END IF;

    RETURN v_idx;
END$_$;


--
-- Name: FUNCTION sp_tbl_hwp_document_c_000(p_co_cd character varying, p_doc_idx bigint, p_tmpl_cd character varying, p_base_dt character varying, p_base_dt_to character varying, p_title character varying, p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_tbl_hwp_document_c_000(p_co_cd character varying, p_doc_idx bigint, p_tmpl_cd character varying, p_base_dt character varying, p_base_dt_to character varying, p_title character varying, p_id character varying) IS 'HWP 문서형 공통 헤더 신규·수정 — 제목이 있으면 그 값, 없으면 신규는 양식명(일자)·수정은 기존 title';


--
-- Name: sp_tbl_hyg_process_c_000(character varying, character varying, bigint, character varying, character varying, jsonb, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_hyg_process_c_000(p_co_cd character varying, p_tmpl_cd character varying, p_doc_idx bigint, p_base_dt character varying, p_checker_nm character varying, p_payload jsonb, p_id character varying) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_doc bigint; v_hdr bigint; v_status varchar; v_no varchar; v_name varchar; v_appr varchar; v_retain int;
    v_ver int; e jsonb; v_seq int := 0;
    v_tmpl varchar(40) := btrim(COALESCE(p_tmpl_cd, ''));
    -- 목록 제목 — payload title 이 있으면 그 값, 없으면 신규는 자동값·수정은 기존값
    v_in varchar(300); v_auto varchar(300);
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
     WHERE t.tmpl_cd = v_tmpl AND t.use_yn = 'Y' AND t.co_cd = p_co_cd;
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
    v_auto := v_name || ' (' || substr(p_base_dt, 1, 4) || '-' || substr(p_base_dt, 5, 2) || '-' || substr(p_base_dt, 7, 2) || ')';
    v_in := NULLIF(btrim(COALESCE(p_payload->>'title', '')), '');

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
            p_co_cd, v_tmpl, 'HTML', v_no, p_base_dt,
            COALESCE(v_in, v_auto),
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
            title = COALESCE(v_in, title),
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
            /*
             * 자리 번호는 **보내온 배열 순서**로 우리가 매긴다. 화면이 준 sortNo 를 쓰지 않는다.
             * 까닭은 sp_ccp_verify_c_000 과 같다 —
             * ux_tbl_hyg_process_item (hdr_idx, sort_no) 가 유니크라 겹친 값이 오면
             * 23505 가 409 「다른 사용자가 동시에 처리 중입니다」로 둔갑한다.
             */
            p_co_cd, v_hdr, v_seq,
            COALESCE(NULLIF(e->>'itemCd', ''), 'hp-u-' || lpad(v_seq::text, 3, '0')),
            NULLIF(e->>'cycleNm', ''), NULLIF(e->>'grpNm', ''), NULLIF(e->>'itemNm', ''),
            COALESCE(NULLIF(e->>'inputType', ''), 'radio'), NULLIF(e->>'unitNm', ''),
            NULLIF(e->>'yn', ''), NULLIF(e->>'valNm', ''), p_id
        );
    END LOOP;
    RETURN v_doc;
END$$;


--
-- Name: FUNCTION sp_tbl_hyg_process_c_000(p_co_cd character varying, p_tmpl_cd character varying, p_doc_idx bigint, p_base_dt character varying, p_checker_nm character varying, p_payload jsonb, p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_tbl_hyg_process_c_000(p_co_cd character varying, p_tmpl_cd character varying, p_doc_idx bigint, p_base_dt character varying, p_checker_nm character varying, p_payload jsonb, p_id character varying) IS '공정점검 저장 — 양식별. 신규는 사용여부 Y 만 허용하고 채번 규칙이 없으면 만든다';


--
-- Name: sp_tbl_hyg_process_d_000(character varying, bigint, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_hyg_process_d_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
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
    -- 완료(DONE)된 개선조치는 원문서를 지워도 남긴다. 조치 기록이 초안 삭제로 사라지면 안 된다.
    -- 개선조치 목록은 LEFT JOIN tbl_document 이라 원문서가 없어도 문서 칸만 빈 채로 보인다
    DELETE FROM tbl_corrective_action WHERE co_cd = p_co_cd AND src_doc_idx = p_doc_idx AND status <> 'DONE';
    DELETE FROM tbl_hyg_process_item WHERE co_cd = p_co_cd AND hdr_idx = v_hdr;
    DELETE FROM tbl_hyg_process WHERE co_cd = p_co_cd AND idx = v_hdr;
    DELETE FROM tbl_document_approval WHERE co_cd = p_co_cd AND doc_idx = p_doc_idx;
    DELETE FROM tbl_document_file WHERE co_cd = p_co_cd AND doc_idx = p_doc_idx;
    DELETE FROM tbl_document WHERE co_cd = p_co_cd AND idx = p_doc_idx;
END$$;


--
-- Name: PROCEDURE sp_tbl_hyg_process_d_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_tbl_hyg_process_d_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_id character varying) IS '공정점검 삭제 — 전송대기(WRK·RJT)만. 양식코드는 tbl_hyg_process 조인이 좁힌다';


--
-- Name: sp_tbl_hyg_process_r_000(character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

DROP FUNCTION IF EXISTS sasshaccp.sp_tbl_hyg_process_r_000(character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying);
DROP FUNCTION IF EXISTS sasshaccp.sp_tbl_hyg_process_r_000(character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying);
CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_hyg_process_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_from_dt character varying, p_to_dt character varying, p_doc_no character varying, p_writer character varying, p_tmpl_nm character varying DEFAULT NULL::character varying, p_writer_id character varying DEFAULT NULL::character varying, p_writer_nm character varying DEFAULT NULL::character varying, p_title character varying DEFAULT NULL::character varying) RETURNS TABLE(doc_idx bigint, hdr_idx bigint, tmpl_cd character varying, tmpl_nm character varying, doc_no character varying, base_dt character varying, checker_nm character varying, writer_id character varying, writer_nm character varying, status character varying, row_cnt integer, ng_cnt integer, title character varying)
    LANGUAGE sql STABLE
    AS $_$
    SELECT d.idx, h.idx,
           d.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm)::varchar,
           d.doc_no, d.base_dt, h.checker_nm,
           d.writer_id,
           COALESCE(u.user_nm, d.writer_id, '')::varchar,
           d.status,
           (SELECT count(*)::int FROM tbl_hyg_process_item i WHERE i.hdr_idx = h.idx AND i.co_cd = h.co_cd),
           (SELECT count(*)::int FROM tbl_hyg_process_item i WHERE i.hdr_idx = h.idx AND i.co_cd = h.co_cd AND i.yn = 'N'),
           d.title
      FROM tbl_document d
      JOIN tbl_hyg_process h ON h.doc_idx = d.idx AND h.co_cd = d.co_cd
      -- 카탈로그는 자사 행만. 시드가 업체에 복사한다
      LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd AND t.co_cd = d.co_cd
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
       AND (COALESCE(NULLIF(btrim(p_title), ''), '') = '' OR COALESCE(d.title, '') ILIKE '%' || btrim(p_title) || '%')
     ORDER BY d.base_dt DESC, d.doc_no DESC;
$_$;


--
-- Name: FUNCTION sp_tbl_hyg_process_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_from_dt character varying, p_to_dt character varying, p_doc_no character varying, p_writer character varying, p_tmpl_nm character varying, p_writer_id character varying, p_writer_nm character varying, p_remark character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_tbl_hyg_process_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_from_dt character varying, p_to_dt character varying, p_doc_no character varying, p_writer character varying, p_tmpl_nm character varying, p_writer_id character varying, p_writer_nm character varying, p_title character varying) IS '공정점검 작성 목록 — 제목은 tbl_document.title 부분검색. 결재여부는 화면이 DOC_STATUS 로 묶어 거른다';


--
-- Name: sp_tbl_hyg_process_r_001(character varying, character varying, bigint); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_hyg_process_r_001(p_co_cd character varying, p_tmpl_cd character varying, p_doc_idx bigint) RETURNS jsonb
    LANGUAGE plpgsql STABLE
    AS $$
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
                /*
                 * 지면 도장칸의 승인자 — 결재가 끝났으면 그 결과가 정본이다.
                 *
                 * 예전에는 h.approver_nm(작성자가 지면에 친 글자)만 봤다. 그래서
                 * 결재를 승인해도 종이에는 작성 당시 글자가 그대로 남았고,
                 * 사람 이름이 아닌 값('3')이 들어간 문서도 그대로 보였다.
                 * 승인 SP 는 이미 tbl_document_approval 에 결재자 이름과
                 * tbl_user.sign_img 스냅샷을 남겨 두고 있다 — 그것을 먼저 본다.
                 * 승인 전(대기)에는 결재행이 없거나 result_cd 가 'A' 가 아니라
                 * COALESCE 가 지면 값으로 떨어진다 — 예전과 같은 화면이다.
                 */
                'approverNm', COALESCE(
                    (SELECT a.approver_nm FROM tbl_document_approval a
                      WHERE a.co_cd = d.co_cd AND a.doc_idx = d.idx
                        AND a.role_cd = 'APPROVE' AND a.result_cd = 'A'
                      ORDER BY a.step_no DESC LIMIT 1),
                    h.approver_nm),
                'approverId', COALESCE(
                    (SELECT a.approver_id FROM tbl_document_approval a
                      WHERE a.co_cd = d.co_cd AND a.doc_idx = d.idx
                        AND a.role_cd = 'APPROVE' AND a.result_cd = 'A'
                      ORDER BY a.step_no DESC LIMIT 1),
                    h.approver_id),
                -- 서명도 결재 시점 스냅샷이 먼저다. 없을 때만 지면에 붙은 이미지를 본다
                'approverSignYn', CASE WHEN COALESCE(
                    (SELECT a.sign_img FROM tbl_document_approval a
                      WHERE a.co_cd = d.co_cd AND a.doc_idx = d.idx
                        AND a.role_cd = 'APPROVE' AND a.result_cd = 'A'
                      ORDER BY a.step_no DESC LIMIT 1),
                    h.approver_sign_img) IS NOT NULL THEN 'Y' ELSE 'N' END,
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
          -- 카탈로그는 자사 행만. 시드가 업체에 복사한다
          LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd AND t.co_cd = d.co_cd
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
                                 WHERE t.tmpl_cd = v_tmpl AND t.co_cd = p_co_cd), ''),
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


--
-- Name: FUNCTION sp_tbl_hyg_process_r_001(p_co_cd character varying, p_tmpl_cd character varying, p_doc_idx bigint); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_tbl_hyg_process_r_001(p_co_cd character varying, p_tmpl_cd character varying, p_doc_idx bigint) IS '공정점검 상세/신규 — 신규 항목은 표준이면 tbl_html_form_ver_item, 자사면 tbl_html_hyg_prc_ver_item';


--
-- Name: sp_tbl_hyg_process_sign_u_000(character varying, bigint, character varying, character varying, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_hyg_process_sign_u_000(IN p_co_cd character varying, IN p_doc_idx bigint, IN p_checker_nm character varying, IN p_approver_nm character varying, IN p_confirm_nm character varying)
    LANGUAGE plpgsql
    AS $$
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
        -- 그런 이름의 사용자가 없을 때(= 사람이 아닌 값) 저장을 막는다.
        -- 예전에는 이름 글자만 남기고 통과시켰다. 그래서 승인자 칸에 '3' 이 들어간
        -- 법정 서류가 만들어졌다. 빈 칸은 그대로 통과시킨다 — 승인 전에는 비어 있는 게 정상이다
        IF v_apv_id IS NULL THEN
            RAISE EXCEPTION '승인자 "%" 를 사용자에서 찾을 수 없습니다. 등록된 사용자 이름으로 입력하세요.',
                btrim(p_approver_nm) USING ERRCODE = '45000';
        END IF;
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


--
-- Name: sp_tbl_login_log_c_000(character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, timestamp without time zone); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_login_log_c_000(IN p_co_cd character varying, IN p_user_id character varying, IN p_sid character varying, IN p_result_cd character varying, IN p_fail_reason character varying, IN p_ip_addr character varying, IN p_user_agent character varying, IN p_device_gbn character varying, IN p_token_exp_dt timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO tbl_login_log(co_cd, user_id, sid, login_dt, result_cd, fail_reason,
                              ip_addr, user_agent, device_gbn, token_exp_dt)
    VALUES (NULLIF(p_co_cd, ''), p_user_id, NULLIF(p_sid, ''), now(), p_result_cd,
            NULLIF(p_fail_reason, ''), p_ip_addr, p_user_agent, p_device_gbn, p_token_exp_dt);
END$$;


--
-- Name: PROCEDURE sp_tbl_login_log_c_000(IN p_co_cd character varying, IN p_user_id character varying, IN p_sid character varying, IN p_result_cd character varying, IN p_fail_reason character varying, IN p_ip_addr character varying, IN p_user_agent character varying, IN p_device_gbn character varying, IN p_token_exp_dt timestamp without time zone); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_tbl_login_log_c_000(IN p_co_cd character varying, IN p_user_id character varying, IN p_sid character varying, IN p_result_cd character varying, IN p_fail_reason character varying, IN p_ip_addr character varying, IN p_user_agent character varying, IN p_device_gbn character varying, IN p_token_exp_dt timestamp without time zone) IS '로그인 시도 기록 — 성공·실패·잠금 전수 적재';


--
-- Name: sp_tbl_login_log_u_000(character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_login_log_u_000(IN p_sid character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE tbl_login_log
       SET logout_dt = now()
     WHERE idx = (SELECT l.idx FROM tbl_login_log l
                   WHERE l.sid = p_sid AND l.logout_dt IS NULL
                   ORDER BY l.login_dt DESC LIMIT 1);
END$$;


--
-- Name: PROCEDURE sp_tbl_login_log_u_000(IN p_sid character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_tbl_login_log_u_000(IN p_sid character varying) IS '로그아웃 시각 기록 — 해당 세션의 미종료 최신 행 1건만 갱신';


-- Name: sp_tbl_notification_r_000(character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_notification_r_000(p_co_cd character varying, p_user_id character varying) RETURNS TABLE(idx bigint, noti_type_cd character varying, title character varying, content character varying, link_scrn_cd character varying, link_doc_idx bigint, read_yn character varying, ins_dt timestamp without time zone)
    LANGUAGE sql STABLE
    AS $$
    SELECT idx, noti_type_cd, title, content, link_scrn_cd, link_doc_idx, read_yn, ins_dt
      FROM tbl_notification
     WHERE co_cd = p_co_cd AND user_id = p_user_id
     ORDER BY read_yn, ins_dt DESC;
$$;


--
-- Name: sp_tbl_notification_task_c_000(character varying, integer); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

-- 인자가 1 → 2 로 늘었다. CREATE OR REPLACE 만 하면 옛 1인자 프로시저가 남아
-- 매퍼가 어느 쪽을 부를지 모호해진다. 먼저 지운다 (sp_hwp_template_management_r_000 과 같은 방식)
DROP PROCEDURE IF EXISTS sasshaccp.sp_tbl_notification_task_c_000(character varying);

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_notification_task_c_000(
    -- p_id: 갱신자 — 배치가 부르므로 'system'
    IN p_id character varying,
    -- p_dormant_days: 이 날수만큼 아무도 로그인하지 않은 회사는 건너뛴다. 0 이하·NULL 이면 안 거른다
    IN p_dormant_days integer DEFAULT NULL
)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO tbl_notification(co_cd, noti_type_cd, user_id, title, content, link_scrn_cd, link_doc_idx)
    SELECT t.co_cd, 'TASK_DUE', u.user_id,
           '문서 작성 마감이 다가옵니다.',
           COALESCE(ct.tmpl_nm_ovr, tp.tmpl_nm, t.tmpl_cd) || ' · ' || t.due_dt || ' ' || COALESCE(t.due_time, ''),
           tp.scrn_cd, t.doc_idx
      FROM tbl_schedule_task t
      -- 카탈로그는 자사 행만. 시드가 업체에 복사한다
      JOIN tbl_template tp ON tp.tmpl_cd = t.tmpl_cd AND tp.co_cd = t.co_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = t.co_cd AND ct.tmpl_cd = t.tmpl_cd
      JOIN tbl_user u ON u.co_cd = t.co_cd AND u.use_yn = 'Y'
     WHERE t.status IN ('TODO', 'ING')
       AND t.alarm_send_yn = 'N'
       AND t.alarm_dt IS NOT NULL AND t.alarm_dt <= now()
       -- 담당자 지정이 있으면 그 사람에게만, 부서 지정만 있으면 그 부서 전원에게 보낸다
       AND (t.user_id IS NULL OR t.user_id = u.user_id)
       AND (t.dept_cd IS NULL OR t.dept_cd = u.dept_cd)
       /*
        * 휴면 회사는 건너뛴다.
        *
        * 예정일은 주기를 저장할 때 1년치가 미리 깔린다. 그래서 아무도 안 들어오는 업체도
        * 예정 1,586건 × 사용자 3명 ≈ 4,700행이 저절로 쌓인다 (별담푸드 실측).
        * 읽는 사람이 없는 자료를 그만큼 적을 이유가 없다.
        *
        * 기준을 **로그인**으로 잡는다. 「문서를 안 썼다」로 잡으면 막 개설한 신규 업체가
        * 첫날부터 휴면이 돼서 정작 안내가 필요한 사람에게 안 간다.
        * ix_tbl_login_log_co (co_cd, login_dt DESC) 를 탄다.
        */
       AND (COALESCE(p_dormant_days, 0) <= 0
            OR EXISTS (SELECT 1 FROM tbl_login_log l
                        WHERE l.co_cd = t.co_cd
                          AND l.login_dt >= now() - make_interval(days => p_dormant_days)))
    /*
     * 이미 있으면 조용히 넘어간다 — ux_tbl_notification_dedup 이 막는다.
     *
     * 없으면 배치 하나가 통째로 죽는다. INSERT 는 한 문장이라 유니크에 걸리는 순간
     * 그 회사뿐 아니라 **그 실행의 모든 회사 알림**이 같이 롤백된다.
     * 시험에서 실제로 그렇게 났다 — 손으로 alarm_send_yn 을 되돌린 뒤 크론이 죽었다.
     *
     * 기본 설정(alarm-before-minutes=60)으로는 겹칠 길이 좁다.
     * alarm_send_yn 이 과제당 한 번을 이미 보장하고, content 에 due_dt·due_time 이 들어가며,
     * ux_tbl_schedule_task(co_cd, tmpl_cd, base_dt) 가 유니크라 과제가 양식·날짜당 하나다.
     * sp_tbl_schedule_task_regen_c_000 은 플래그를 되돌리지 않는다 — 확인했다.
     *
     * 그래도 붙인다. 알림 리드타임을 하루 넘게 키우면(alarm-before-minutes > 1440)
     * 「이미 알린 미래 과제」가 생기고, 그 상태에서 주기를 고쳐 저장하면 그 행이 지워졌다
     * 다시 'N' 으로 깔린다 — 그때 같은 날 같은 알림을 또 넣으려 든다.
     * 설정 하나 바꿨다고 전 회사 알림이 멎는 것은 너무 비싼 대가다.
     */
    ON CONFLICT DO NOTHING;

    /*
     * 잠그는 것은 **거르지 않는다.**
     *
     * 휴면 회사 과제도 여기서 'Y' 로 닫는다. 안 그러면 그 회사가 한 달 뒤 다시 들어왔을 때
     * 그동안 지나간 마감이 한꺼번에 터진다 — 지난 알림은 이미 쓸모가 없다.
     * 「깨어나면 그날부터 다시」가 되게 하려는 것이다.
     */
    UPDATE tbl_schedule_task
       SET alarm_send_yn = 'Y', upd_id = p_id, upd_dt = now()
     WHERE status IN ('TODO', 'ING')
       AND alarm_send_yn = 'N'
       AND alarm_dt IS NOT NULL AND alarm_dt <= now();
END$$;


--
-- Name: PROCEDURE sp_tbl_notification_task_c_000(IN p_id character varying, IN p_dormant_days integer); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_tbl_notification_task_c_000(IN p_id character varying, IN p_dormant_days integer) IS '마감 임박 알림 — 알림을 만드는 유일한 곳. alarm_dt 도달분 1회 적재 후 alarm_send_yn=Y. p_dormant_days 일간 로그인 없는 회사는 적재를 건너뛰되 플래그는 닫는다';


--
-- Name: sp_tbl_notification_u_000(character varying, bigint, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_notification_u_000(IN p_co_cd character varying, IN p_idx bigint, IN p_user_id character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE tbl_notification SET read_yn = 'Y', read_dt = now()
     WHERE idx = p_idx AND co_cd = p_co_cd AND user_id = p_user_id;
    IF NOT FOUND THEN RAISE EXCEPTION '알림을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
END$$;


--
-- Name: sp_tbl_schedule_task_generate_c_000(character varying, character varying, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_schedule_task_generate_c_000(IN p_co_cd character varying, IN p_base_dt character varying, IN p_id character varying)
    LANGUAGE plpgsql
    AS $_$
BEGIN
    IF COALESCE(p_base_dt, '') !~ '^[0-9]{8}$' THEN
        RAISE EXCEPTION '과제 생성 기준일 형식이 올바르지 않습니다.' USING ERRCODE = '45000';
    END IF;

    -- 마감 경과 미작성분 지연 처리 — 당일은 마감시각까지 기다린다
    UPDATE tbl_schedule_task
       SET status = 'LATE', upd_id = p_id, upd_dt = now()
     WHERE (COALESCE(p_co_cd, '') = '' OR co_cd = p_co_cd)
       AND status IN ('TODO', 'ING')
       AND (due_dt < p_base_dt
            OR (due_dt = p_base_dt AND COALESCE(due_time, '2359') < to_char(now(), 'HH24MI')));

    /*
     * 알림은 여기서 만들지 않는다.
     *
     * 예전에는 이 자리에서 오늘분(TASK_DUE)·지연분(TASK_LATE)을 같이 넣었다.
     * 세 가지가 겹쳐 표가 끝없이 불었다 —
     *
     *   1) 지연분이 **날마다** 다시 들어갔다. 가드가 「오늘 이미 넣었나」뿐이라
     *      날짜가 바뀌면 조건이 새로 성립했다. 안 쓰는 회사는 영원히 늘었다
     *   2) 그 가드(NOT EXISTS)는 **같은 INSERT 가 방금 넣은 행을 못 본다.**
     *      같은 양식의 지연 과제가 셋이면 한 문장이 세 행을 넣었다.
     *      운영에 중복 조합이 15개 쌓여 있었다
     *   3) 이 SP 를 **화면 조회(TaskService.todayTasks)** 도 부른다.
     *      사람이 「오늘 할 일」을 열 때마다 알림이 생겼다 — 조회가 쓰기를 했다
     *
     * 마감 임박 알림은 sp_tbl_notification_task_c_000(10분 크론)이 이미
     * **과제당 정확히 한 번** 넣는다 (alarm_send_yn 으로 잠근다). 같은 말을 두 번 하지 않는다.
     * 지연은 「오늘 할 일」 화면이 빨간 줄·맨 위 정렬로 보여 준다 — 알림으로 또 쌓을 것이 아니다.
     *
     * 이 SP 는 이름값대로 **과제 생성·지연 판정**만 한다.
     */
END$_$;


--
-- Name: PROCEDURE sp_tbl_schedule_task_generate_c_000(IN p_co_cd character varying, IN p_base_dt character varying, IN p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_tbl_schedule_task_generate_c_000(IN p_co_cd character varying, IN p_base_dt character varying, IN p_id character varying) IS '일일 배치 — 마감 경과 지연 처리만. 알림은 sp_tbl_notification_task_c_000 한 곳에서만 만든다. 예정일 생성은 CycleScheduleGenerator 담당';


--
-- Name: sp_tbl_schedule_task_regen_c_000(character varying, character varying, jsonb, character varying, character varying, character varying, integer, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_schedule_task_regen_c_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_dates jsonb, IN p_due_time character varying, IN p_dept_cd character varying, IN p_user_id character varying, IN p_alarm_min integer, IN p_id character varying)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_today varchar(8) := to_char(current_date, 'YYYYMMDD');
    v_due   varchar(4) := COALESCE(NULLIF(regexp_replace(COALESCE(p_due_time, ''), '[^0-9]', '', 'g'), ''), '1800');
    v_min   int        := COALESCE(p_alarm_min, 60);
BEGIN
    IF COALESCE(p_co_cd, '') = '' OR COALESCE(p_tmpl_cd, '') = '' THEN
        RAISE EXCEPTION '예정일 생성 대상이 올바르지 않습니다.' USING ERRCODE = '45000';
    END IF;

    -- 관리시작일 이전 미작성 밀린 행 — 시작일을 늦춰 저장하면 같이 지운다. 문서 있는 ING/APV 는 둔다
    DELETE FROM tbl_schedule_task t
     USING tbl_schedule_rule r
     WHERE t.co_cd = p_co_cd AND t.tmpl_cd = p_tmpl_cd
       AND r.co_cd = t.co_cd AND r.tmpl_cd = t.tmpl_cd
       AND t.base_dt < r.base_dt
       AND t.status IN ('TODO', 'LATE')
       AND t.doc_idx IS NULL;

    -- 규칙에서 빠진 미래 예정일 정리 — 작성 시작 전(TODO·doc 없음) 만 지운다
    DELETE FROM tbl_schedule_task t
     WHERE t.co_cd = p_co_cd AND t.tmpl_cd = p_tmpl_cd
       AND t.base_dt > v_today
       AND t.status = 'TODO' AND t.doc_idx IS NULL
       AND NOT EXISTS (
           SELECT 1 FROM jsonb_array_elements_text(COALESCE(p_dates, '[]'::jsonb)) AS d(dt)
            WHERE d.dt = t.base_dt
       );

    -- 오늘 이후 예정일 적재 — 과거는 만들지 않는다(지난 일정을 새로 밀어 넣으면 즉시 LATE 가 된다)
    INSERT INTO tbl_schedule_task(
        co_cd, tmpl_cd, base_dt, due_dt, due_time, status, dept_cd, user_id,
        alarm_dt, alarm_send_yn, ins_id, ins_dt
    )
    SELECT p_co_cd, p_tmpl_cd, d.dt, d.dt, v_due, 'TODO',
           NULLIF(p_dept_cd, ''), NULLIF(p_user_id, ''),
           to_timestamp(d.dt || v_due, 'YYYYMMDDHH24MI') - make_interval(mins => v_min), 'N',
           p_id, now()
      FROM jsonb_array_elements_text(COALESCE(p_dates, '[]'::jsonb)) AS d(dt)
     WHERE d.dt ~ '^[0-9]{8}$' AND d.dt >= v_today
    ON CONFLICT (co_cd, tmpl_cd, base_dt) DO NOTHING;

    -- 이미 있던 미래 예정일의 마감·담당·알림시각을 규칙에 맞춘다
    UPDATE tbl_schedule_task t
       SET due_time = v_due,
           dept_cd  = NULLIF(p_dept_cd, ''),
           user_id  = NULLIF(p_user_id, ''),
           alarm_dt = to_timestamp(t.base_dt || v_due, 'YYYYMMDDHH24MI') - make_interval(mins => v_min),
           upd_id = p_id, upd_dt = now()
     WHERE t.co_cd = p_co_cd AND t.tmpl_cd = p_tmpl_cd
       AND t.base_dt > v_today
       AND t.status = 'TODO'
       AND (t.due_time IS DISTINCT FROM v_due
            OR t.dept_cd IS DISTINCT FROM NULLIF(p_dept_cd, '')
            OR t.user_id IS DISTINCT FROM NULLIF(p_user_id, '')
            OR t.alarm_dt IS NULL);
END$_$;


--
-- Name: PROCEDURE sp_tbl_schedule_task_regen_c_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_dates jsonb, IN p_due_time character varying, IN p_dept_cd character varying, IN p_user_id character varying, IN p_alarm_min integer, IN p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_tbl_schedule_task_regen_c_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_dates jsonb, IN p_due_time character varying, IN p_dept_cd character varying, IN p_user_id character varying, IN p_alarm_min integer, IN p_id character varying) IS '예정일 재생성 — 관리시작일 이전 미작성 밀린 행과 미래 미작성분을 지우고, 생성기 날짜만 반영한다';


--
-- Name: sp_tbl_html_ccp_chk_ver_apply_u_000(character varying, character varying, integer, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_html_ccp_chk_ver_apply_u_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_ver_no integer, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE tbl_html_ccp_chk_ver SET apply_yn = 'N', upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND apply_yn = 'Y';
    IF COALESCE(p_ver_no, 0) > 0 THEN
        UPDATE tbl_html_ccp_chk_ver SET apply_yn = 'Y', upd_id = p_id, upd_dt = now()
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
        IF NOT FOUND THEN RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    END IF;
END$$;


--
-- Name: sp_tbl_html_ccp_chk_ver_copy_c_000(character varying, character varying, integer, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_html_ccp_chk_ver_copy_c_000(p_co_cd character varying, p_tmpl_cd character varying, p_src_ver_no integer, p_ver_cd character varying, p_ver_nm character varying, p_id character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE v_nm varchar; v_n int; v_cd varchar; v_src tbl_template%ROWTYPE; v_try int := 0; v_cycle varchar;
BEGIN
    IF COALESCE(p_co_cd, '') = '' THEN
        RAISE EXCEPTION '회사코드는 필수입니다.' USING ERRCODE = '45000';
    END IF;
    v_nm := btrim(COALESCE(p_ver_nm, ''));
    IF v_nm = '' THEN RAISE EXCEPTION '양식명은 필수입니다.' USING ERRCODE = '45000'; END IF;
    SELECT * INTO v_src FROM tbl_template WHERE tmpl_cd = 'html_sys_006' AND co_cd = p_co_cd;
    IF NOT FOUND THEN RAISE EXCEPTION '표준 양식을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    v_cycle := COALESCE(NULLIF(btrim(v_src.default_cycle_cd), ''), 'M');
    -- 다음 번호는 이 회사 카탈로그 MAX+1
    SELECT COALESCE(MAX(substring(t.tmpl_cd from '[0-9]{3}$')::int), 0) INTO v_n
      FROM tbl_template t
     WHERE t.co_cd = p_co_cd AND t.tmpl_cd ~ '^html_ccp_chk_[0-9]{3}$' AND t.tmpl_cd <> 'html_ccp_chk_000';
    LOOP
        v_try := v_try + 1; v_n := v_n + 1;
        IF v_n > 999 OR v_try > 50 THEN
            RAISE EXCEPTION '양식코드를 더 부여할 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        v_cd := 'html_ccp_chk_' || lpad(v_n::text, 3, '0');
        IF v_cd = 'html_ccp_chk_000' THEN CONTINUE; END IF;
        EXIT WHEN NOT EXISTS (SELECT 1 FROM tbl_template WHERE tmpl_cd = v_cd AND co_cd = p_co_cd);
    END LOOP;
    INSERT INTO tbl_template (
        co_cd, tmpl_cd, tmpl_nm, mng_no, doc_kind, category_cd, scrn_cd,
        default_cycle_cd, default_retention_month, impl_yn, sort_no, use_yn, ins_id, ins_dt
    ) VALUES (
        p_co_cd, v_cd, v_nm, v_src.mng_no, 'HTML', v_src.category_cd, 'ccp-verification-check',
        v_cycle, COALESCE(v_src.default_retention_month, 24), 'Y',
        COALESCE(v_src.sort_no, 106) + v_n, 'Y', p_id, now()
    );
    INSERT INTO tbl_company_template (
        co_cd, tmpl_cd, tmpl_nm_ovr, cycle_cd, retention_month, use_yn, sys_yn, ins_id, ins_dt
    ) VALUES (
        p_co_cd, v_cd, v_nm, v_cycle, COALESCE(v_src.default_retention_month, 24), 'Y', 'usr', p_id, now()
    );
    INSERT INTO tbl_html_ccp_chk_ver (co_cd, tmpl_cd, ver_no, ver_cd, ver_nm, apply_yn, use_yn, ins_id, ins_dt)
    VALUES (p_co_cd, v_cd, 1, v_cd, v_nm, 'N', 'Y', p_id, now());
    INSERT INTO tbl_html_ccp_chk_ver_item (
        co_cd, tmpl_cd, ver_no, item_cd, sort_no, cycle_nm, grp_nm, item_nm, input_type, unit_nm, ins_id
    )
    SELECT p_co_cd, v_cd, 1, c.item_cd, c.sort_no, c.cycle_nm, c.grp_nm, c.item_nm, c.input_type, c.unit_nm, p_id
      FROM tbl_check_item c WHERE c.tmpl_cd = 'html_ccp_chk_000' AND c.use_yn = 'Y';
    -- 주기는 문서주기 화면에서만 만든다. 양식 복사는 사용양식·지면만
    RETURN v_cd;
END$_$;


--
-- Name: sp_tbl_html_ccp_chk_ver_d_000(character varying, character varying, integer, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_html_ccp_chk_ver_d_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_ver_no integer, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF COALESCE(p_tmpl_cd, '') IN ('html_ccp_chk_000', 'html_sys_006') OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 양식은 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM tbl_html_ccp_chk_ver
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y'
    ) THEN
        RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    -- 문서 없는 예정·밀린 과제·주기·채번·사용양식은 양식과 같이 지운다
    DELETE FROM tbl_schedule_task
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd
       AND status IN ('TODO', 'LATE') AND doc_idx IS NULL;
    DELETE FROM tbl_schedule_rule_detail WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    DELETE FROM tbl_schedule_rule WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    DELETE FROM tbl_doc_no_rule WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    DELETE FROM tbl_company_template WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    UPDATE tbl_html_ccp_chk_ver SET use_yn = 'N', apply_yn = 'N', upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
END$$;


--
-- Name: sp_tbl_html_ccp_chk_ver_delete_blocker_r_000(character varying, character varying, integer); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_html_ccp_chk_ver_delete_blocker_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_ver_no integer) RETURNS TABLE(ref_key character varying, target character varying)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE v_nm varchar; v_use varchar; v_key varchar;
BEGIN
    v_key := COALESCE(NULLIF(btrim(p_tmpl_cd), ''), COALESCE(p_ver_no::varchar, ''));
    IF COALESCE(p_tmpl_cd, '') IN ('html_ccp_chk_000', 'html_sys_006') OR COALESCE(p_ver_no, 0) <= 0 THEN
        RETURN QUERY SELECT '표준'::varchar, '시스템 표준 항목'::varchar; RETURN;
    END IF;
    SELECT ver_nm, use_yn INTO v_nm, v_use FROM tbl_html_ccp_chk_ver
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
    IF v_nm IS NULL OR v_use = 'N' THEN
        RETURN QUERY SELECT v_key, '없는 양식'::varchar; RETURN;
    END IF;
    IF EXISTS (SELECT 1 FROM tbl_document d WHERE d.co_cd = p_co_cd AND d.tmpl_cd = p_tmpl_cd AND d.del_yn = 'N') THEN
        RETURN QUERY SELECT COALESCE(v_nm, v_key), '작성 문서'::varchar; RETURN;
    END IF;
END$$;


--
-- Name: sp_tbl_html_ccp_chk_ver_item_r_000(character varying, character varying, integer); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_html_ccp_chk_ver_item_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_ver_no integer) RETURNS TABLE(item_cd character varying, sort_no integer, cycle_nm character varying, grp_nm character varying, item_nm text, input_type character varying, unit_nm character varying)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    IF COALESCE(p_tmpl_cd, '') IN ('html_ccp_chk_000', 'html_sys_006') THEN
        RETURN QUERY
        SELECT c.item_cd, c.sort_no, c.cycle_nm, c.grp_nm, c.item_nm, c.input_type, c.unit_nm
          FROM tbl_check_item c
         WHERE c.tmpl_cd = 'html_ccp_chk_000' AND c.use_yn = 'Y'
         ORDER BY c.sort_no, c.item_cd;
        RETURN;
    END IF;
    RETURN QUERY
    SELECT i.item_cd, i.sort_no, i.cycle_nm, i.grp_nm, i.item_nm, i.input_type, i.unit_nm
      FROM tbl_html_ccp_chk_ver_item i
     WHERE i.co_cd = p_co_cd AND i.tmpl_cd = p_tmpl_cd AND i.ver_no = p_ver_no
     ORDER BY i.sort_no, i.item_cd;
END$$;


--
-- Name: sp_tbl_html_ccp_chk_ver_item_u_000(character varying, character varying, integer, jsonb, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_html_ccp_chk_ver_item_u_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_ver_no integer, IN p_items jsonb, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE e jsonb; v_cnt int := 0;
BEGIN
    IF COALESCE(p_tmpl_cd, '') IN ('html_ccp_chk_000', 'html_sys_006') OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 항목은 수정할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM tbl_html_ccp_chk_ver
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y'
    ) THEN
        RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' THEN
        RAISE EXCEPTION '점검항목 자료가 올바르지 않습니다.' USING ERRCODE = '45000';
    END IF;
    /*
     * 점검 항목이 하나도 없는 양식은 저장하지 않는다.
     *
     * 예전에는 0건도 저장됐다. 그런데 그 양식으로 쓴 일지는 **전송할 때** 「점검 행이 없습니다」로
     * 막힌다 — 양식을 만든 사람과 막히는 사람이 다르고, 시점도 며칠 떨어져 있어
     * 작성자는 자기가 뭘 잘못했는지 알 길이 없다. 만든 자리에서 막는다.
     */
    IF jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION '점검항목을 한 줄 이상 넣으세요.' USING ERRCODE = '45000';
    END IF;
    DELETE FROM tbl_html_ccp_chk_ver_item WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
    FOR e IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_cnt := v_cnt + 1;
        INSERT INTO tbl_html_ccp_chk_ver_item (
            co_cd, tmpl_cd, ver_no, item_cd, sort_no, cycle_nm, grp_nm, item_nm, input_type, unit_nm, ins_id, upd_id, upd_dt
        ) VALUES (
            p_co_cd, p_tmpl_cd, p_ver_no,
            COALESCE(NULLIF(e->>'itemCd', ''), 'hp-u-' || lpad(v_cnt::text, 3, '0')),
            COALESCE(NULLIF(e->>'sortNo', '')::int, v_cnt),
            NULLIF(e->>'cycleNm', ''), NULLIF(e->>'grpNm', ''), COALESCE(e->>'itemNm', ''),
            COALESCE(NULLIF(e->>'inputType', ''), 'radio'), NULLIF(e->>'unitNm', ''),
            p_id, p_id, now()
        );
    END LOOP;
    UPDATE tbl_html_ccp_chk_ver SET upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
END$$;


--
-- Name: sp_tbl_html_ccp_chk_ver_nm_u_000(character varying, character varying, integer, character varying, character varying, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_html_ccp_chk_ver_nm_u_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_ver_no integer, IN p_ver_nm character varying, IN p_use_yn character varying, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE v_nm varchar; v_use varchar;
BEGIN
    IF COALESCE(p_tmpl_cd, '') IN ('html_ccp_chk_000', 'html_sys_006') OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 양식명은 수정할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    v_nm := btrim(COALESCE(p_ver_nm, ''));
    IF v_nm = '' THEN RAISE EXCEPTION '양식명은 필수입니다.' USING ERRCODE = '45000'; END IF;
    v_use := CASE WHEN upper(left(btrim(COALESCE(p_use_yn, 'Y')), 1)) = 'N' THEN 'N' ELSE 'Y' END;
    UPDATE tbl_html_ccp_chk_ver SET ver_nm = v_nm, upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
    IF NOT FOUND THEN RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    UPDATE tbl_template SET tmpl_nm = v_nm, upd_id = p_id, upd_dt = now() WHERE tmpl_cd = p_tmpl_cd AND co_cd = p_co_cd;
    UPDATE tbl_company_template
       SET tmpl_nm_ovr = v_nm, use_yn = v_use, upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
END$$;


--
-- Name: sp_tbl_html_ccp_chk_ver_r_000(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_html_ccp_chk_ver_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_ver_cd character varying DEFAULT NULL::character varying, p_ver_nm character varying DEFAULT NULL::character varying) RETURNS TABLE(idx bigint, tmpl_cd character varying, ver_no integer, ver_cd character varying, ver_nm character varying, sys_yn character varying, apply_yn character varying, locked_yn character varying, ins_nm character varying, ins_dt character varying, use_yn character varying)
    LANGUAGE sql STABLE
    AS $_$
    SELECT x.idx, x.tmpl_cd, x.ver_no, x.ver_cd, x.ver_nm, x.sys_yn, x.apply_yn, x.locked_yn, x.ins_nm, x.ins_dt, x.use_yn
      FROM (
            SELECT NULL::bigint, 'html_ccp_chk_000'::varchar, 0, 'html_ccp_chk_000'::varchar,
                   '표준'::varchar, 'sys'::varchar, 'N'::varchar, 'Y'::varchar, ''::varchar, ''::varchar, 'N'::varchar
            UNION ALL
            SELECT v.idx, v.tmpl_cd, v.ver_no,
                   COALESCE(NULLIF(btrim(v.ver_cd), ''), v.tmpl_cd),
                   COALESCE(ct.tmpl_nm_ovr, v.ver_nm),
                   'usr'::varchar, v.apply_yn, 'N'::varchar,
                   COALESCE(u.user_nm, v.ins_id, '')::varchar,
                   COALESCE(to_char(v.ins_dt, 'YYYY-MM-DD'), '')::varchar,
                   CASE WHEN upper(COALESCE(ct.use_yn, 'Y')) = 'N' THEN 'N' ELSE 'Y' END
              FROM tbl_html_ccp_chk_ver v
              JOIN tbl_company_template ct ON ct.co_cd = v.co_cd AND ct.tmpl_cd = v.tmpl_cd
              LEFT JOIN tbl_user u ON u.co_cd = v.co_cd AND u.user_id = v.ins_id
             WHERE v.co_cd = p_co_cd AND v.use_yn = 'Y'
               AND v.tmpl_cd ~ '^html_ccp_chk_[0-9]{3}$' AND v.tmpl_cd <> 'html_ccp_chk_000'
           ) x(idx, tmpl_cd, ver_no, ver_cd, ver_nm, sys_yn, apply_yn, locked_yn, ins_nm, ins_dt, use_yn)
     WHERE (COALESCE(btrim(p_ver_cd), '') = '' OR x.tmpl_cd ILIKE '%' || btrim(p_ver_cd) || '%')
       AND (COALESCE(btrim(p_ver_nm), '') = '' OR x.ver_nm ILIKE '%' || btrim(p_ver_nm) || '%')
     ORDER BY x.tmpl_cd;
$_$;


--
-- Name: sp_tbl_html_ccp_htg_ver_apply_u_000(character varying, character varying, integer, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_html_ccp_htg_ver_apply_u_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_ver_no integer, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE tbl_html_ccp_htg_ver SET apply_yn = 'N', upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND apply_yn = 'Y';
    IF COALESCE(p_ver_no, 0) > 0 THEN
        UPDATE tbl_html_ccp_htg_ver SET apply_yn = 'Y', upd_id = p_id, upd_dt = now()
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
        IF NOT FOUND THEN RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    END IF;
END$$;


--
-- Name: sp_tbl_html_ccp_htg_ver_copy_c_000(character varying, character varying, integer, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_html_ccp_htg_ver_copy_c_000(p_co_cd character varying, p_tmpl_cd character varying, p_src_ver_no integer, p_ver_cd character varying, p_ver_nm character varying, p_id character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE v_nm varchar; v_n int; v_cd varchar; v_try int := 0;
BEGIN
    IF COALESCE(p_co_cd, '') = '' THEN
        RAISE EXCEPTION '회사코드는 필수입니다.' USING ERRCODE = '45000';
    END IF;
    v_nm := btrim(COALESCE(p_ver_nm, ''));
    IF v_nm = '' THEN RAISE EXCEPTION '양식명은 필수입니다.' USING ERRCODE = '45000'; END IF;
    -- 다음 번호는 이 회사 카탈로그 MAX+1
    SELECT COALESCE(MAX(substring(t.tmpl_cd from '[0-9]{3}$')::int), 0) INTO v_n
      FROM tbl_template t
     WHERE t.co_cd = p_co_cd AND t.tmpl_cd ~ '^html_ccp_htg_[0-9]{3}$' AND t.tmpl_cd <> 'html_ccp_htg_000';
    LOOP
        v_try := v_try + 1; v_n := v_n + 1;
        IF v_n > 999 OR v_try > 50 THEN
            RAISE EXCEPTION '양식코드를 더 부여할 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        v_cd := 'html_ccp_htg_' || lpad(v_n::text, 3, '0');
        IF v_cd = 'html_ccp_htg_000' THEN CONTINUE; END IF;
        EXIT WHEN NOT EXISTS (SELECT 1 FROM tbl_template WHERE tmpl_cd = v_cd AND co_cd = p_co_cd);
    END LOOP;
    -- 카탈로그 html_sys 없이 usr 행. 작성 화면 scrn_cd 는 후속
    INSERT INTO tbl_template (
        co_cd, tmpl_cd, tmpl_nm, mng_no, doc_kind, category_cd, scrn_cd,
        default_cycle_cd, default_retention_month, impl_yn, sort_no, use_yn, ins_id, ins_dt
    ) VALUES (
        p_co_cd, v_cd, v_nm, 'CCP-2B', 'HTML', 'CCP', 'ccp-htg-monitor',
        'D', 24, 'Y', 114 + v_n, 'Y', p_id, now()
    );
    INSERT INTO tbl_company_template (
        co_cd, tmpl_cd, tmpl_nm_ovr, cycle_cd, retention_month, use_yn, sys_yn, ins_id, ins_dt
    ) VALUES (
        p_co_cd, v_cd, v_nm, 'D', 24, 'Y', 'usr', p_id, now()
    );
    INSERT INTO tbl_html_ccp_htg_ver (co_cd, tmpl_cd, ver_no, ver_cd, ver_nm, apply_yn, use_yn, ins_id, ins_dt)
    VALUES (p_co_cd, v_cd, 1, v_cd, v_nm, 'N', 'Y', p_id, now());
    INSERT INTO tbl_html_ccp_htg_ver_item (
        co_cd, tmpl_cd, ver_no, item_cd, sort_no, cycle_nm, grp_nm, item_nm, input_type, unit_nm, ins_id
    )
    SELECT p_co_cd, v_cd, 1, c.item_cd, c.sort_no, c.cycle_nm, c.grp_nm, c.item_nm, c.input_type, c.unit_nm, p_id
      FROM tbl_check_item c WHERE c.tmpl_cd = 'html_ccp_htg_000' AND c.use_yn = 'Y';
    -- 주기는 문서주기 화면에서만 만든다. 양식 복사는 사용양식·지면만
    RETURN v_cd;
END$_$;


--
-- Name: sp_tbl_html_ccp_htg_ver_d_000(character varying, character varying, integer, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_html_ccp_htg_ver_d_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_ver_no integer, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF COALESCE(p_tmpl_cd, '') = 'html_ccp_htg_000' OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 양식은 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM tbl_html_ccp_htg_ver
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y'
    ) THEN
        RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    -- 문서 없는 예정·밀린 과제·주기·채번·사용양식은 양식과 같이 지운다
    DELETE FROM tbl_schedule_task
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd
       AND status IN ('TODO', 'LATE') AND doc_idx IS NULL;
    DELETE FROM tbl_schedule_rule_detail WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    DELETE FROM tbl_schedule_rule WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    DELETE FROM tbl_doc_no_rule WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    DELETE FROM tbl_company_template WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    UPDATE tbl_html_ccp_htg_ver SET use_yn = 'N', apply_yn = 'N', upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
END$$;


--
-- Name: sp_tbl_html_ccp_htg_ver_delete_blocker_r_000(character varying, character varying, integer); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_html_ccp_htg_ver_delete_blocker_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_ver_no integer) RETURNS TABLE(ref_key character varying, target character varying)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE v_nm varchar; v_use varchar; v_key varchar;
BEGIN
    v_key := COALESCE(NULLIF(btrim(p_tmpl_cd), ''), COALESCE(p_ver_no::varchar, ''));
    IF COALESCE(p_tmpl_cd, '') = 'html_ccp_htg_000' OR COALESCE(p_ver_no, 0) <= 0 THEN
        RETURN QUERY SELECT '표준'::varchar, '시스템 표준 항목'::varchar; RETURN;
    END IF;
    SELECT ver_nm, use_yn INTO v_nm, v_use FROM tbl_html_ccp_htg_ver
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
    IF v_nm IS NULL OR v_use = 'N' THEN
        RETURN QUERY SELECT v_key, '없는 양식'::varchar; RETURN;
    END IF;
    IF EXISTS (SELECT 1 FROM tbl_document d WHERE d.co_cd = p_co_cd AND d.tmpl_cd = p_tmpl_cd AND d.del_yn = 'N') THEN
        RETURN QUERY SELECT COALESCE(v_nm, v_key), '작성 문서'::varchar; RETURN;
    END IF;
END$$;


--
-- Name: sp_tbl_html_ccp_htg_ver_item_r_000(character varying, character varying, integer); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_html_ccp_htg_ver_item_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_ver_no integer) RETURNS TABLE(item_cd character varying, sort_no integer, cycle_nm character varying, grp_nm character varying, item_nm text, input_type character varying, unit_nm character varying)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    IF COALESCE(p_tmpl_cd, '') = 'html_ccp_htg_000' THEN
        RETURN QUERY
        SELECT c.item_cd, c.sort_no, c.cycle_nm, c.grp_nm, c.item_nm, c.input_type, c.unit_nm
          FROM tbl_check_item c
         WHERE c.tmpl_cd = 'html_ccp_htg_000' AND c.use_yn = 'Y'
         ORDER BY c.sort_no, c.item_cd;
        RETURN;
    END IF;
    RETURN QUERY
    SELECT i.item_cd, i.sort_no, i.cycle_nm, i.grp_nm, i.item_nm, i.input_type, i.unit_nm
      FROM tbl_html_ccp_htg_ver_item i
     WHERE i.co_cd = p_co_cd AND i.tmpl_cd = p_tmpl_cd AND i.ver_no = p_ver_no
     ORDER BY i.sort_no, i.item_cd;
END$$;


--
-- Name: sp_tbl_html_ccp_htg_ver_item_u_000(character varying, character varying, integer, jsonb, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_html_ccp_htg_ver_item_u_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_ver_no integer, IN p_items jsonb, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE e jsonb; v_cnt int := 0;
BEGIN
    IF COALESCE(p_tmpl_cd, '') = 'html_ccp_htg_000' OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 항목은 수정할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM tbl_html_ccp_htg_ver
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y'
    ) THEN
        RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' THEN
        RAISE EXCEPTION '점검항목 자료가 올바르지 않습니다.' USING ERRCODE = '45000';
    END IF;
    /*
     * 점검 항목이 하나도 없는 양식은 저장하지 않는다.
     *
     * 예전에는 0건도 저장됐다. 그런데 그 양식으로 쓴 일지는 **전송할 때** 「점검 행이 없습니다」로
     * 막힌다 — 양식을 만든 사람과 막히는 사람이 다르고, 시점도 며칠 떨어져 있어
     * 작성자는 자기가 뭘 잘못했는지 알 길이 없다. 만든 자리에서 막는다.
     */
    IF jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION '점검항목을 한 줄 이상 넣으세요.' USING ERRCODE = '45000';
    END IF;
    DELETE FROM tbl_html_ccp_htg_ver_item WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
    FOR e IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_cnt := v_cnt + 1;
        INSERT INTO tbl_html_ccp_htg_ver_item (
            co_cd, tmpl_cd, ver_no, item_cd, sort_no, cycle_nm, grp_nm, item_nm, input_type, unit_nm, ins_id, upd_id, upd_dt
        ) VALUES (
            p_co_cd, p_tmpl_cd, p_ver_no,
            COALESCE(NULLIF(e->>'itemCd', ''), 'hp-u-' || lpad(v_cnt::text, 3, '0')),
            COALESCE(NULLIF(e->>'sortNo', '')::int, v_cnt),
            NULLIF(e->>'cycleNm', ''), NULLIF(e->>'grpNm', ''), COALESCE(e->>'itemNm', ''),
            COALESCE(NULLIF(e->>'inputType', ''), 'text'), NULLIF(e->>'unitNm', ''),
            p_id, p_id, now()
        );
    END LOOP;
    UPDATE tbl_html_ccp_htg_ver SET upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
END$$;


--
-- Name: sp_tbl_html_ccp_htg_ver_nm_u_000(character varying, character varying, integer, character varying, character varying, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_html_ccp_htg_ver_nm_u_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_ver_no integer, IN p_ver_nm character varying, IN p_use_yn character varying, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE v_nm varchar; v_use varchar;
BEGIN
    IF COALESCE(p_tmpl_cd, '') = 'html_ccp_htg_000' OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 양식명은 수정할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    v_nm := btrim(COALESCE(p_ver_nm, ''));
    IF v_nm = '' THEN RAISE EXCEPTION '양식명은 필수입니다.' USING ERRCODE = '45000'; END IF;
    v_use := CASE WHEN upper(left(btrim(COALESCE(p_use_yn, 'Y')), 1)) = 'N' THEN 'N' ELSE 'Y' END;
    UPDATE tbl_html_ccp_htg_ver SET ver_nm = v_nm, upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
    IF NOT FOUND THEN RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    UPDATE tbl_template SET tmpl_nm = v_nm, upd_id = p_id, upd_dt = now() WHERE tmpl_cd = p_tmpl_cd AND co_cd = p_co_cd;
    UPDATE tbl_company_template
       SET tmpl_nm_ovr = v_nm, use_yn = v_use, upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
END$$;


--
-- Name: sp_tbl_html_ccp_htg_ver_r_000(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_html_ccp_htg_ver_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_ver_cd character varying DEFAULT NULL::character varying, p_ver_nm character varying DEFAULT NULL::character varying) RETURNS TABLE(idx bigint, tmpl_cd character varying, ver_no integer, ver_cd character varying, ver_nm character varying, sys_yn character varying, apply_yn character varying, locked_yn character varying, ins_nm character varying, ins_dt character varying, use_yn character varying)
    LANGUAGE sql STABLE
    AS $_$
    SELECT x.idx, x.tmpl_cd, x.ver_no, x.ver_cd, x.ver_nm, x.sys_yn, x.apply_yn, x.locked_yn, x.ins_nm, x.ins_dt, x.use_yn
      FROM (
            SELECT NULL::bigint, 'html_ccp_htg_000'::varchar, 0, 'html_ccp_htg_000'::varchar,
                   '표준'::varchar, 'sys'::varchar, 'N'::varchar, 'Y'::varchar, ''::varchar, ''::varchar, 'N'::varchar
            UNION ALL
            SELECT v.idx, v.tmpl_cd, v.ver_no,
                   COALESCE(NULLIF(btrim(v.ver_cd), ''), v.tmpl_cd),
                   COALESCE(ct.tmpl_nm_ovr, v.ver_nm),
                   'usr'::varchar, v.apply_yn, 'N'::varchar,
                   COALESCE(u.user_nm, v.ins_id, '')::varchar,
                   COALESCE(to_char(v.ins_dt, 'YYYY-MM-DD'), '')::varchar,
                   CASE WHEN upper(COALESCE(ct.use_yn, 'Y')) = 'N' THEN 'N' ELSE 'Y' END
              FROM tbl_html_ccp_htg_ver v
              JOIN tbl_company_template ct ON ct.co_cd = v.co_cd AND ct.tmpl_cd = v.tmpl_cd
              LEFT JOIN tbl_user u ON u.co_cd = v.co_cd AND u.user_id = v.ins_id
             WHERE v.co_cd = p_co_cd AND v.use_yn = 'Y'
               AND v.tmpl_cd ~ '^html_ccp_htg_[0-9]{3}$' AND v.tmpl_cd <> 'html_ccp_htg_000'
           ) x(idx, tmpl_cd, ver_no, ver_cd, ver_nm, sys_yn, apply_yn, locked_yn, ins_nm, ins_dt, use_yn)
     WHERE (COALESCE(btrim(p_ver_cd), '') = '' OR x.tmpl_cd ILIKE '%' || btrim(p_ver_cd) || '%')
       AND (COALESCE(btrim(p_ver_nm), '') = '' OR x.ver_nm ILIKE '%' || btrim(p_ver_nm) || '%')
     ORDER BY x.tmpl_cd;
$_$;


--
-- Name: sp_tbl_html_ccp_mtl_ver_apply_u_000(character varying, character varying, integer, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_html_ccp_mtl_ver_apply_u_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_ver_no integer, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE tbl_html_ccp_mtl_ver SET apply_yn = 'N', upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND apply_yn = 'Y';
    IF COALESCE(p_ver_no, 0) > 0 THEN
        UPDATE tbl_html_ccp_mtl_ver SET apply_yn = 'Y', upd_id = p_id, upd_dt = now()
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
        IF NOT FOUND THEN RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    END IF;
END$$;


--
-- Name: sp_tbl_html_ccp_mtl_ver_copy_c_000(character varying, character varying, integer, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_html_ccp_mtl_ver_copy_c_000(p_co_cd character varying, p_tmpl_cd character varying, p_src_ver_no integer, p_ver_cd character varying, p_ver_nm character varying, p_id character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE v_nm varchar; v_n int; v_cd varchar; v_try int := 0;
BEGIN
    IF COALESCE(p_co_cd, '') = '' THEN
        RAISE EXCEPTION '회사코드는 필수입니다.' USING ERRCODE = '45000';
    END IF;
    v_nm := btrim(COALESCE(p_ver_nm, ''));
    IF v_nm = '' THEN RAISE EXCEPTION '양식명은 필수입니다.' USING ERRCODE = '45000'; END IF;
    -- 다음 번호는 이 회사 카탈로그 MAX+1
    SELECT COALESCE(MAX(substring(t.tmpl_cd from '[0-9]{3}$')::int), 0) INTO v_n
      FROM tbl_template t
     WHERE t.co_cd = p_co_cd AND t.tmpl_cd ~ '^html_ccp_mtl_[0-9]{3}$' AND t.tmpl_cd <> 'html_ccp_mtl_000';
    LOOP
        v_try := v_try + 1; v_n := v_n + 1;
        IF v_n > 999 OR v_try > 50 THEN
            RAISE EXCEPTION '양식코드를 더 부여할 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        v_cd := 'html_ccp_mtl_' || lpad(v_n::text, 3, '0');
        IF v_cd = 'html_ccp_mtl_000' THEN CONTINUE; END IF;
        EXIT WHEN NOT EXISTS (SELECT 1 FROM tbl_template WHERE tmpl_cd = v_cd AND co_cd = p_co_cd);
    END LOOP;
    -- 카탈로그 html_sys 없이 usr 행. 작성 화면 scrn_cd 는 후속
    INSERT INTO tbl_template (
        co_cd, tmpl_cd, tmpl_nm, mng_no, doc_kind, category_cd, scrn_cd,
        default_cycle_cd, default_retention_month, impl_yn, sort_no, use_yn, ins_id, ins_dt
    ) VALUES (
        p_co_cd, v_cd, v_nm, 'CCP-3P', 'HTML', 'CCP', 'ccp-mtl-monitor',
        'D', 24, 'Y', 115 + v_n, 'Y', p_id, now()
    );
    INSERT INTO tbl_company_template (
        co_cd, tmpl_cd, tmpl_nm_ovr, cycle_cd, retention_month, use_yn, sys_yn, ins_id, ins_dt
    ) VALUES (
        p_co_cd, v_cd, v_nm, 'D', 24, 'Y', 'usr', p_id, now()
    );
    INSERT INTO tbl_html_ccp_mtl_ver (co_cd, tmpl_cd, ver_no, ver_cd, ver_nm, apply_yn, use_yn, ins_id, ins_dt)
    VALUES (p_co_cd, v_cd, 1, v_cd, v_nm, 'N', 'Y', p_id, now());
    INSERT INTO tbl_html_ccp_mtl_ver_item (
        co_cd, tmpl_cd, ver_no, item_cd, sort_no, cycle_nm, grp_nm, item_nm, input_type, unit_nm, ins_id
    )
    SELECT p_co_cd, v_cd, 1, c.item_cd, c.sort_no, c.cycle_nm, c.grp_nm, c.item_nm, c.input_type, c.unit_nm, p_id
      FROM tbl_check_item c WHERE c.tmpl_cd = 'html_ccp_mtl_000' AND c.use_yn = 'Y';
    -- 주기는 문서주기 화면에서만 만든다. 양식 복사는 사용양식·지면만
    RETURN v_cd;
END$_$;


--
-- Name: sp_tbl_html_ccp_mtl_ver_d_000(character varying, character varying, integer, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_html_ccp_mtl_ver_d_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_ver_no integer, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF COALESCE(p_tmpl_cd, '') = 'html_ccp_mtl_000' OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 양식은 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM tbl_html_ccp_mtl_ver
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y'
    ) THEN
        RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    -- 문서 없는 예정·밀린 과제·주기·채번·사용양식은 양식과 같이 지운다
    DELETE FROM tbl_schedule_task
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd
       AND status IN ('TODO', 'LATE') AND doc_idx IS NULL;
    DELETE FROM tbl_schedule_rule_detail WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    DELETE FROM tbl_schedule_rule WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    DELETE FROM tbl_doc_no_rule WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    DELETE FROM tbl_company_template WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    UPDATE tbl_html_ccp_mtl_ver SET use_yn = 'N', apply_yn = 'N', upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
END$$;


--
-- Name: sp_tbl_html_ccp_mtl_ver_delete_blocker_r_000(character varying, character varying, integer); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_html_ccp_mtl_ver_delete_blocker_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_ver_no integer) RETURNS TABLE(ref_key character varying, target character varying)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE v_nm varchar; v_use varchar; v_key varchar;
BEGIN
    v_key := COALESCE(NULLIF(btrim(p_tmpl_cd), ''), COALESCE(p_ver_no::varchar, ''));
    IF COALESCE(p_tmpl_cd, '') = 'html_ccp_mtl_000' OR COALESCE(p_ver_no, 0) <= 0 THEN
        RETURN QUERY SELECT '표준'::varchar, '시스템 표준 항목'::varchar; RETURN;
    END IF;
    SELECT ver_nm, use_yn INTO v_nm, v_use FROM tbl_html_ccp_mtl_ver
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
    IF v_nm IS NULL OR v_use = 'N' THEN
        RETURN QUERY SELECT v_key, '없는 양식'::varchar; RETURN;
    END IF;
    IF EXISTS (SELECT 1 FROM tbl_document d WHERE d.co_cd = p_co_cd AND d.tmpl_cd = p_tmpl_cd AND d.del_yn = 'N') THEN
        RETURN QUERY SELECT COALESCE(v_nm, v_key), '작성 문서'::varchar; RETURN;
    END IF;
END$$;


--
-- Name: sp_tbl_html_ccp_mtl_ver_item_r_000(character varying, character varying, integer); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_html_ccp_mtl_ver_item_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_ver_no integer) RETURNS TABLE(item_cd character varying, sort_no integer, cycle_nm character varying, grp_nm character varying, item_nm text, input_type character varying, unit_nm character varying)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    IF COALESCE(p_tmpl_cd, '') = 'html_ccp_mtl_000' THEN
        RETURN QUERY
        SELECT c.item_cd, c.sort_no, c.cycle_nm, c.grp_nm, c.item_nm, c.input_type, c.unit_nm
          FROM tbl_check_item c
         WHERE c.tmpl_cd = 'html_ccp_mtl_000' AND c.use_yn = 'Y'
         ORDER BY c.sort_no, c.item_cd;
        RETURN;
    END IF;
    RETURN QUERY
    SELECT i.item_cd, i.sort_no, i.cycle_nm, i.grp_nm, i.item_nm, i.input_type, i.unit_nm
      FROM tbl_html_ccp_mtl_ver_item i
     WHERE i.co_cd = p_co_cd AND i.tmpl_cd = p_tmpl_cd AND i.ver_no = p_ver_no
     ORDER BY i.sort_no, i.item_cd;
END$$;


--
-- Name: sp_tbl_html_ccp_mtl_ver_item_u_000(character varying, character varying, integer, jsonb, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_html_ccp_mtl_ver_item_u_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_ver_no integer, IN p_items jsonb, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE e jsonb; v_cnt int := 0;
BEGIN
    IF COALESCE(p_tmpl_cd, '') = 'html_ccp_mtl_000' OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 항목은 수정할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM tbl_html_ccp_mtl_ver
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y'
    ) THEN
        RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' THEN
        RAISE EXCEPTION '점검항목 자료가 올바르지 않습니다.' USING ERRCODE = '45000';
    END IF;
    /*
     * 점검 항목이 하나도 없는 양식은 저장하지 않는다.
     *
     * 예전에는 0건도 저장됐다. 그런데 그 양식으로 쓴 일지는 **전송할 때** 「점검 행이 없습니다」로
     * 막힌다 — 양식을 만든 사람과 막히는 사람이 다르고, 시점도 며칠 떨어져 있어
     * 작성자는 자기가 뭘 잘못했는지 알 길이 없다. 만든 자리에서 막는다.
     */
    IF jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION '점검항목을 한 줄 이상 넣으세요.' USING ERRCODE = '45000';
    END IF;
    DELETE FROM tbl_html_ccp_mtl_ver_item WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
    FOR e IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_cnt := v_cnt + 1;
        INSERT INTO tbl_html_ccp_mtl_ver_item (
            co_cd, tmpl_cd, ver_no, item_cd, sort_no, cycle_nm, grp_nm, item_nm, input_type, unit_nm, ins_id, upd_id, upd_dt
        ) VALUES (
            p_co_cd, p_tmpl_cd, p_ver_no,
            COALESCE(NULLIF(e->>'itemCd', ''), 'hp-u-' || lpad(v_cnt::text, 3, '0')),
            COALESCE(NULLIF(e->>'sortNo', '')::int, v_cnt),
            NULLIF(e->>'cycleNm', ''), NULLIF(e->>'grpNm', ''), COALESCE(e->>'itemNm', ''),
            COALESCE(NULLIF(e->>'inputType', ''), 'text'), NULLIF(e->>'unitNm', ''),
            p_id, p_id, now()
        );
    END LOOP;
    UPDATE tbl_html_ccp_mtl_ver SET upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
END$$;


--
-- Name: sp_tbl_html_ccp_mtl_ver_nm_u_000(character varying, character varying, integer, character varying, character varying, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_html_ccp_mtl_ver_nm_u_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_ver_no integer, IN p_ver_nm character varying, IN p_use_yn character varying, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE v_nm varchar; v_use varchar;
BEGIN
    IF COALESCE(p_tmpl_cd, '') = 'html_ccp_mtl_000' OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 양식명은 수정할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    v_nm := btrim(COALESCE(p_ver_nm, ''));
    IF v_nm = '' THEN RAISE EXCEPTION '양식명은 필수입니다.' USING ERRCODE = '45000'; END IF;
    v_use := CASE WHEN upper(left(btrim(COALESCE(p_use_yn, 'Y')), 1)) = 'N' THEN 'N' ELSE 'Y' END;
    UPDATE tbl_html_ccp_mtl_ver SET ver_nm = v_nm, upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
    IF NOT FOUND THEN RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    UPDATE tbl_template SET tmpl_nm = v_nm, upd_id = p_id, upd_dt = now() WHERE tmpl_cd = p_tmpl_cd AND co_cd = p_co_cd;
    UPDATE tbl_company_template
       SET tmpl_nm_ovr = v_nm, use_yn = v_use, upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
END$$;


--
-- Name: sp_tbl_html_ccp_mtl_ver_r_000(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_html_ccp_mtl_ver_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_ver_cd character varying DEFAULT NULL::character varying, p_ver_nm character varying DEFAULT NULL::character varying) RETURNS TABLE(idx bigint, tmpl_cd character varying, ver_no integer, ver_cd character varying, ver_nm character varying, sys_yn character varying, apply_yn character varying, locked_yn character varying, ins_nm character varying, ins_dt character varying, use_yn character varying)
    LANGUAGE sql STABLE
    AS $_$
    SELECT x.idx, x.tmpl_cd, x.ver_no, x.ver_cd, x.ver_nm, x.sys_yn, x.apply_yn, x.locked_yn, x.ins_nm, x.ins_dt, x.use_yn
      FROM (
            SELECT NULL::bigint, 'html_ccp_mtl_000'::varchar, 0, 'html_ccp_mtl_000'::varchar,
                   '표준'::varchar, 'sys'::varchar, 'N'::varchar, 'Y'::varchar, ''::varchar, ''::varchar, 'N'::varchar
            UNION ALL
            SELECT v.idx, v.tmpl_cd, v.ver_no,
                   COALESCE(NULLIF(btrim(v.ver_cd), ''), v.tmpl_cd),
                   COALESCE(ct.tmpl_nm_ovr, v.ver_nm),
                   'usr'::varchar, v.apply_yn, 'N'::varchar,
                   COALESCE(u.user_nm, v.ins_id, '')::varchar,
                   COALESCE(to_char(v.ins_dt, 'YYYY-MM-DD'), '')::varchar,
                   CASE WHEN upper(COALESCE(ct.use_yn, 'Y')) = 'N' THEN 'N' ELSE 'Y' END
              FROM tbl_html_ccp_mtl_ver v
              JOIN tbl_company_template ct ON ct.co_cd = v.co_cd AND ct.tmpl_cd = v.tmpl_cd
              LEFT JOIN tbl_user u ON u.co_cd = v.co_cd AND u.user_id = v.ins_id
             WHERE v.co_cd = p_co_cd AND v.use_yn = 'Y'
               AND v.tmpl_cd ~ '^html_ccp_mtl_[0-9]{3}$' AND v.tmpl_cd <> 'html_ccp_mtl_000'
           ) x(idx, tmpl_cd, ver_no, ver_cd, ver_nm, sys_yn, apply_yn, locked_yn, ins_nm, ins_dt, use_yn)
     WHERE (COALESCE(btrim(p_ver_cd), '') = '' OR x.tmpl_cd ILIKE '%' || btrim(p_ver_cd) || '%')
       AND (COALESCE(btrim(p_ver_nm), '') = '' OR x.ver_nm ILIKE '%' || btrim(p_ver_nm) || '%')
     ORDER BY x.tmpl_cd;
$_$;


--
-- Name: sp_tbl_html_ccp_pkg_ver_apply_u_000(character varying, character varying, integer, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_html_ccp_pkg_ver_apply_u_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_ver_no integer, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE tbl_html_ccp_pkg_ver SET apply_yn = 'N', upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND apply_yn = 'Y';
    IF COALESCE(p_ver_no, 0) > 0 THEN
        UPDATE tbl_html_ccp_pkg_ver SET apply_yn = 'Y', upd_id = p_id, upd_dt = now()
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
        IF NOT FOUND THEN RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    END IF;
END$$;


--
-- Name: sp_tbl_html_ccp_pkg_ver_copy_c_000(character varying, character varying, integer, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_html_ccp_pkg_ver_copy_c_000(p_co_cd character varying, p_tmpl_cd character varying, p_src_ver_no integer, p_ver_cd character varying, p_ver_nm character varying, p_id character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE v_nm varchar; v_n int; v_cd varchar; v_try int := 0;
BEGIN
    IF COALESCE(p_co_cd, '') = '' THEN
        RAISE EXCEPTION '회사코드는 필수입니다.' USING ERRCODE = '45000';
    END IF;
    v_nm := btrim(COALESCE(p_ver_nm, ''));
    IF v_nm = '' THEN RAISE EXCEPTION '양식명은 필수입니다.' USING ERRCODE = '45000'; END IF;
    -- 다음 번호는 이 회사 카탈로그 MAX+1
    SELECT COALESCE(MAX(substring(t.tmpl_cd from '[0-9]{3}$')::int), 0) INTO v_n
      FROM tbl_template t
     WHERE t.co_cd = p_co_cd AND t.tmpl_cd ~ '^html_ccp_pkg_[0-9]{3}$' AND t.tmpl_cd <> 'html_ccp_pkg_000';
    LOOP
        v_try := v_try + 1; v_n := v_n + 1;
        IF v_n > 999 OR v_try > 50 THEN
            RAISE EXCEPTION '양식코드를 더 부여할 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        v_cd := 'html_ccp_pkg_' || lpad(v_n::text, 3, '0');
        IF v_cd = 'html_ccp_pkg_000' THEN CONTINUE; END IF;
        EXIT WHEN NOT EXISTS (SELECT 1 FROM tbl_template WHERE tmpl_cd = v_cd AND co_cd = p_co_cd);
    END LOOP;
    -- 카탈로그 html_sys 없이 usr 행. 작성 화면 scrn_cd 는 후속
    INSERT INTO tbl_template (
        co_cd, tmpl_cd, tmpl_nm, mng_no, doc_kind, category_cd, scrn_cd,
        default_cycle_cd, default_retention_month, impl_yn, sort_no, use_yn, ins_id, ins_dt
    ) VALUES (
        p_co_cd, v_cd, v_nm, 'CCP-1B', 'HTML', 'CCP', 'ccp-pkg-monitor',
        'D', 24, 'Y', 113 + v_n, 'Y', p_id, now()
    );
    INSERT INTO tbl_company_template (
        co_cd, tmpl_cd, tmpl_nm_ovr, cycle_cd, retention_month, use_yn, sys_yn, ins_id, ins_dt
    ) VALUES (
        p_co_cd, v_cd, v_nm, 'D', 24, 'Y', 'usr', p_id, now()
    );
    INSERT INTO tbl_html_ccp_pkg_ver (co_cd, tmpl_cd, ver_no, ver_cd, ver_nm, apply_yn, use_yn, ins_id, ins_dt)
    VALUES (p_co_cd, v_cd, 1, v_cd, v_nm, 'N', 'Y', p_id, now());
    INSERT INTO tbl_html_ccp_pkg_ver_item (
        co_cd, tmpl_cd, ver_no, item_cd, sort_no, cycle_nm, grp_nm, item_nm, input_type, unit_nm, ins_id
    )
    SELECT p_co_cd, v_cd, 1, c.item_cd, c.sort_no, c.cycle_nm, c.grp_nm, c.item_nm, c.input_type, c.unit_nm, p_id
      FROM tbl_check_item c WHERE c.tmpl_cd = 'html_ccp_pkg_000' AND c.use_yn = 'Y';
    -- 주기는 문서주기 화면에서만 만든다. 양식 복사는 사용양식·지면만
    RETURN v_cd;
END$_$;


--
-- Name: sp_tbl_html_ccp_pkg_ver_d_000(character varying, character varying, integer, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_html_ccp_pkg_ver_d_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_ver_no integer, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF COALESCE(p_tmpl_cd, '') = 'html_ccp_pkg_000' OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 양식은 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM tbl_html_ccp_pkg_ver
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y'
    ) THEN
        RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    -- 문서 없는 예정·밀린 과제·주기·채번·사용양식은 양식과 같이 지운다
    DELETE FROM tbl_schedule_task
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd
       AND status IN ('TODO', 'LATE') AND doc_idx IS NULL;
    DELETE FROM tbl_schedule_rule_detail WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    DELETE FROM tbl_schedule_rule WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    DELETE FROM tbl_doc_no_rule WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    DELETE FROM tbl_company_template WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    UPDATE tbl_html_ccp_pkg_ver SET use_yn = 'N', apply_yn = 'N', upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
END$$;


--
-- Name: sp_tbl_html_ccp_pkg_ver_delete_blocker_r_000(character varying, character varying, integer); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_html_ccp_pkg_ver_delete_blocker_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_ver_no integer) RETURNS TABLE(ref_key character varying, target character varying)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE v_nm varchar; v_use varchar; v_key varchar;
BEGIN
    v_key := COALESCE(NULLIF(btrim(p_tmpl_cd), ''), COALESCE(p_ver_no::varchar, ''));
    IF COALESCE(p_tmpl_cd, '') = 'html_ccp_pkg_000' OR COALESCE(p_ver_no, 0) <= 0 THEN
        RETURN QUERY SELECT '표준'::varchar, '시스템 표준 항목'::varchar; RETURN;
    END IF;
    SELECT ver_nm, use_yn INTO v_nm, v_use FROM tbl_html_ccp_pkg_ver
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
    IF v_nm IS NULL OR v_use = 'N' THEN
        RETURN QUERY SELECT v_key, '없는 양식'::varchar; RETURN;
    END IF;
    IF EXISTS (SELECT 1 FROM tbl_document d WHERE d.co_cd = p_co_cd AND d.tmpl_cd = p_tmpl_cd AND d.del_yn = 'N') THEN
        RETURN QUERY SELECT COALESCE(v_nm, v_key), '작성 문서'::varchar; RETURN;
    END IF;
END$$;


--
-- Name: sp_tbl_html_ccp_pkg_ver_item_r_000(character varying, character varying, integer); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_html_ccp_pkg_ver_item_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_ver_no integer) RETURNS TABLE(item_cd character varying, sort_no integer, cycle_nm character varying, grp_nm character varying, item_nm text, input_type character varying, unit_nm character varying)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    IF COALESCE(p_tmpl_cd, '') = 'html_ccp_pkg_000' THEN
        RETURN QUERY
        SELECT c.item_cd, c.sort_no, c.cycle_nm, c.grp_nm, c.item_nm, c.input_type, c.unit_nm
          FROM tbl_check_item c
         WHERE c.tmpl_cd = 'html_ccp_pkg_000' AND c.use_yn = 'Y'
         ORDER BY c.sort_no, c.item_cd;
        RETURN;
    END IF;
    RETURN QUERY
    SELECT i.item_cd, i.sort_no, i.cycle_nm, i.grp_nm, i.item_nm, i.input_type, i.unit_nm
      FROM tbl_html_ccp_pkg_ver_item i
     WHERE i.co_cd = p_co_cd AND i.tmpl_cd = p_tmpl_cd AND i.ver_no = p_ver_no
     ORDER BY i.sort_no, i.item_cd;
END$$;


--
-- Name: sp_tbl_html_ccp_pkg_ver_item_u_000(character varying, character varying, integer, jsonb, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_html_ccp_pkg_ver_item_u_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_ver_no integer, IN p_items jsonb, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE e jsonb; v_cnt int := 0;
BEGIN
    IF COALESCE(p_tmpl_cd, '') = 'html_ccp_pkg_000' OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 항목은 수정할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM tbl_html_ccp_pkg_ver
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y'
    ) THEN
        RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' THEN
        RAISE EXCEPTION '점검항목 자료가 올바르지 않습니다.' USING ERRCODE = '45000';
    END IF;
    /*
     * 점검 항목이 하나도 없는 양식은 저장하지 않는다.
     *
     * 예전에는 0건도 저장됐다. 그런데 그 양식으로 쓴 일지는 **전송할 때** 「점검 행이 없습니다」로
     * 막힌다 — 양식을 만든 사람과 막히는 사람이 다르고, 시점도 며칠 떨어져 있어
     * 작성자는 자기가 뭘 잘못했는지 알 길이 없다. 만든 자리에서 막는다.
     */
    IF jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION '점검항목을 한 줄 이상 넣으세요.' USING ERRCODE = '45000';
    END IF;
    DELETE FROM tbl_html_ccp_pkg_ver_item WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
    FOR e IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_cnt := v_cnt + 1;
        INSERT INTO tbl_html_ccp_pkg_ver_item (
            co_cd, tmpl_cd, ver_no, item_cd, sort_no, cycle_nm, grp_nm, item_nm, input_type, unit_nm, ins_id, upd_id, upd_dt
        ) VALUES (
            p_co_cd, p_tmpl_cd, p_ver_no,
            COALESCE(NULLIF(e->>'itemCd', ''), 'hp-u-' || lpad(v_cnt::text, 3, '0')),
            COALESCE(NULLIF(e->>'sortNo', '')::int, v_cnt),
            NULLIF(e->>'cycleNm', ''), NULLIF(e->>'grpNm', ''), COALESCE(e->>'itemNm', ''),
            COALESCE(NULLIF(e->>'inputType', ''), 'text'), NULLIF(e->>'unitNm', ''),
            p_id, p_id, now()
        );
    END LOOP;
    UPDATE tbl_html_ccp_pkg_ver SET upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
END$$;


--
-- Name: sp_tbl_html_ccp_pkg_ver_nm_u_000(character varying, character varying, integer, character varying, character varying, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_html_ccp_pkg_ver_nm_u_000(IN p_co_cd character varying, IN p_tmpl_cd character varying, IN p_ver_no integer, IN p_ver_nm character varying, IN p_use_yn character varying, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE v_nm varchar; v_use varchar;
BEGIN
    IF COALESCE(p_tmpl_cd, '') = 'html_ccp_pkg_000' OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 양식명은 수정할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    v_nm := btrim(COALESCE(p_ver_nm, ''));
    IF v_nm = '' THEN RAISE EXCEPTION '양식명은 필수입니다.' USING ERRCODE = '45000'; END IF;
    v_use := CASE WHEN upper(left(btrim(COALESCE(p_use_yn, 'Y')), 1)) = 'N' THEN 'N' ELSE 'Y' END;
    UPDATE tbl_html_ccp_pkg_ver SET ver_nm = v_nm, upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
    IF NOT FOUND THEN RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    UPDATE tbl_template SET tmpl_nm = v_nm, upd_id = p_id, upd_dt = now() WHERE tmpl_cd = p_tmpl_cd AND co_cd = p_co_cd;
    UPDATE tbl_company_template
       SET tmpl_nm_ovr = v_nm, use_yn = v_use, upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
END$$;


--
-- Name: sp_tbl_html_ccp_pkg_ver_r_000(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_html_ccp_pkg_ver_r_000(p_co_cd character varying, p_tmpl_cd character varying, p_ver_cd character varying DEFAULT NULL::character varying, p_ver_nm character varying DEFAULT NULL::character varying) RETURNS TABLE(idx bigint, tmpl_cd character varying, ver_no integer, ver_cd character varying, ver_nm character varying, sys_yn character varying, apply_yn character varying, locked_yn character varying, ins_nm character varying, ins_dt character varying, use_yn character varying)
    LANGUAGE sql STABLE
    AS $_$
    SELECT x.idx, x.tmpl_cd, x.ver_no, x.ver_cd, x.ver_nm, x.sys_yn, x.apply_yn, x.locked_yn, x.ins_nm, x.ins_dt, x.use_yn
      FROM (
            SELECT NULL::bigint, 'html_ccp_pkg_000'::varchar, 0, 'html_ccp_pkg_000'::varchar,
                   '표준'::varchar, 'sys'::varchar, 'N'::varchar, 'Y'::varchar, ''::varchar, ''::varchar, 'N'::varchar
            UNION ALL
            SELECT v.idx, v.tmpl_cd, v.ver_no,
                   COALESCE(NULLIF(btrim(v.ver_cd), ''), v.tmpl_cd),
                   COALESCE(ct.tmpl_nm_ovr, v.ver_nm),
                   'usr'::varchar, v.apply_yn, 'N'::varchar,
                   COALESCE(u.user_nm, v.ins_id, '')::varchar,
                   COALESCE(to_char(v.ins_dt, 'YYYY-MM-DD'), '')::varchar,
                   CASE WHEN upper(COALESCE(ct.use_yn, 'Y')) = 'N' THEN 'N' ELSE 'Y' END
              FROM tbl_html_ccp_pkg_ver v
              JOIN tbl_company_template ct ON ct.co_cd = v.co_cd AND ct.tmpl_cd = v.tmpl_cd
              LEFT JOIN tbl_user u ON u.co_cd = v.co_cd AND u.user_id = v.ins_id
             WHERE v.co_cd = p_co_cd AND v.use_yn = 'Y'
               AND v.tmpl_cd ~ '^html_ccp_pkg_[0-9]{3}$' AND v.tmpl_cd <> 'html_ccp_pkg_000'
           ) x(idx, tmpl_cd, ver_no, ver_cd, ver_nm, sys_yn, apply_yn, locked_yn, ins_nm, ins_dt, use_yn)
     WHERE (COALESCE(btrim(p_ver_cd), '') = '' OR x.tmpl_cd ILIKE '%' || btrim(p_ver_cd) || '%')
       AND (COALESCE(btrim(p_ver_nm), '') = '' OR x.ver_nm ILIKE '%' || btrim(p_ver_nm) || '%')
     ORDER BY x.tmpl_cd;
$_$;


--
-- Name: sp_tbl_today_task_doc_r_000(character varying, character varying, character varying, integer, integer); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

-- 시그니처에 p_user_id 추가 — 라이브는 기존 5인자 오버로드를 먼저 지운다
DROP FUNCTION IF EXISTS sasshaccp.sp_tbl_today_task_doc_r_000(character varying, character varying, character varying, integer, integer);

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_today_task_doc_r_000(
    p_co_cd character varying,
    p_user_id character varying,
    p_from_dt character varying,
    p_to_dt character varying,
    p_offset integer,
    p_limit integer
) RETURNS TABLE(doc_idx bigint, co_cd character varying, tmpl_cd character varying, tmpl_nm character varying, doc_kind character varying, doc_no character varying, base_dt character varying, title character varying, status character varying, appr_line_cd character varying, writer_id character varying, writer_nm character varying, write_dt timestamp without time zone, ver_no integer, retention_until character varying, file_cnt integer, open_ca_cnt integer, total_cnt integer)
    LANGUAGE sql STABLE
    AS $$
    -- 대시보드 최근 문서 — 로그인 사용자가 쓴 문서만
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
             WHERE f.co_cd = d.co_cd AND f.doc_idx = d.idx
               AND f.file_kind IN ('ATTACH', 'PHOTO')),
           (SELECT count(*)::int
              FROM tbl_corrective_action ca
             WHERE ca.co_cd = d.co_cd
               AND ca.src_doc_idx = d.idx
               AND ca.status <> 'DONE'),
           COUNT(*) OVER()::int
      FROM tbl_document d
      -- 카탈로그는 자사 행만. 시드가 업체에 복사한다
      LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd AND t.co_cd = d.co_cd
      LEFT JOIN tbl_company_template ct
        ON ct.co_cd = d.co_cd AND ct.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_user u ON u.co_cd = d.co_cd AND u.user_id = d.writer_id
     WHERE d.co_cd = p_co_cd
       AND d.writer_id = p_user_id
       AND d.del_yn = 'N'
       AND (COALESCE(p_from_dt, '') = '' OR d.base_dt >= p_from_dt)
       AND (COALESCE(p_to_dt, '') = '' OR d.base_dt <= p_to_dt)
     ORDER BY d.base_dt DESC, d.idx DESC
     OFFSET GREATEST(COALESCE(p_offset, 0), 0)
     LIMIT GREATEST(COALESCE(p_limit, 1), 1);
$$;


--
-- Name: FUNCTION sp_tbl_today_task_doc_r_000(...); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_tbl_today_task_doc_r_000(character varying, character varying, character varying, character varying, integer, integer)
    IS '오늘 할 일 최근 문서 — 본인 작성분만. 기간 + OFFSET/LIMIT + 총건수';


--
-- Name: sp_tbl_today_task_r_000(character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

DROP FUNCTION IF EXISTS sasshaccp.sp_tbl_today_task_r_000(character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_today_task_r_000(p_co_cd character varying, p_user_id character varying, p_base_dt character varying) RETURNS TABLE(task_idx bigint, task_type character varying, title character varying, status character varying, due_dt character varying, due_time character varying, link_scrn_cd character varying, doc_idx bigint, ref_idx bigint, content character varying, tmpl_cd character varying, base_dt character varying)
    LANGUAGE sql STABLE
    AS $$
    -- 작성과제: 오늘(미작성·진행·기한경과·승인완료) + 전날·기한이 지난 미완료
    -- content 는 양식코드 폴백, tmpl_cd·base_dt 는 예정 행추가에 그대로 싣는다
    SELECT t.idx, 'TASK', COALESCE(ct.tmpl_nm_ovr, tp.tmpl_nm, t.tmpl_cd),
           /*
            * 그 날짜·그 양식으로 쓴 문서가 있으면 **문서 상태**를 보여 준다.
            *
            * 예전에는 일정 과제의 status 만 봤다. 문서를 쓰고 전송해도 아무도
            * tbl_schedule_task 를 안 고쳐서 오늘 할 일이 계속 「예정」이었다 —
            * 화면에는 승인요청인데 할 일에는 예정이라 사람이 헷갈렸다.
            * 저장 SP 마다 과제를 고치게 하면 다섯 군데가 갈린다. 읽을 때 이어 붙인다.
            */
           COALESCE(dc.status, t.status), t.due_dt, t.due_time,
           tp.scrn_cd, COALESCE(dc.idx, t.doc_idx), t.idx, t.tmpl_cd, t.tmpl_cd, t.base_dt
      FROM tbl_schedule_task t
      -- 카탈로그는 자사 행만. 시드가 업체에 복사한다
      JOIN tbl_template tp ON tp.tmpl_cd = t.tmpl_cd AND tp.co_cd = t.co_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = t.co_cd AND ct.tmpl_cd = t.tmpl_cd
      -- 같은 회사·양식·기준일 문서 중 가장 나중 것. 하루에 여러 장을 쓰면 마지막 것을 본다
      LEFT JOIN LATERAL (
          SELECT d.idx, d.status
            FROM tbl_document d
           WHERE d.co_cd = t.co_cd AND d.tmpl_cd = t.tmpl_cd
             AND d.base_dt = t.base_dt AND d.del_yn = 'N'
           ORDER BY d.idx DESC
           LIMIT 1
      ) dc ON TRUE
     WHERE t.co_cd = p_co_cd
       AND (t.user_id IS NULL OR t.user_id = p_user_id)
       AND (
            -- 오늘 칸: 관리시작일·사용양식과 관계없이 그대로
            (t.base_dt = p_base_dt AND t.status IN ('TODO','ING','LATE','APV'))
         OR (
             -- 밀린 칸: 관리시작일 이전·주기 목록에 없는 양식은 숨긴다
             t.status IN ('TODO','ING','LATE')
             AND NULLIF(btrim(t.due_dt), '') IS NOT NULL
             AND t.due_dt < p_base_dt
             AND EXISTS (
                 SELECT 1 FROM tbl_schedule_rule sr
                  WHERE sr.co_cd = t.co_cd AND sr.tmpl_cd = t.tmpl_cd
                    AND t.base_dt >= sr.base_dt
             )
             AND EXISTS (
                 SELECT 1 FROM tbl_company_template ct2
                  WHERE ct2.co_cd = t.co_cd AND ct2.tmpl_cd = t.tmpl_cd
             )
         )
       )
    UNION ALL
    -- 개선조치: DONE 이 아닌 건. content=조치내용
    SELECT ca.idx, 'CA', '미완료 개선조치: ' || ca.ca_no, ca.status, ca.due_dt, NULL,
           'corrective-action-management', ca.src_doc_idx, ca.idx, ca.action_desc::varchar,
           ca.src_tmpl_cd, ca.occur_dt
      FROM tbl_corrective_action ca
     WHERE ca.co_cd = p_co_cd AND ca.status <> 'DONE'
       AND (ca.action_user_id IS NULL OR ca.action_user_id = p_user_id)
    ORDER BY 5 NULLS LAST, 6 NULLS LAST, 1;
$$;

COMMENT ON FUNCTION sasshaccp.sp_tbl_today_task_r_000(character varying, character varying, character varying) IS '오늘 할 일 — 오늘 칸 + 관리시작일 이후·사용양식 있는 밀린 과제 + 미완료 개선조치. tmpl_cd·base_dt 는 예정 행추가용';


--
-- Name: sp_tbl_user_login_r_000(character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_user_login_r_000(p_user_id character varying) RETURNS TABLE(user_idx bigint, user_id character varying, user_nm character varying, user_pw character varying, co_cd character varying, co_nm character varying, usrgrp_cd character varying, usrgrp_nm character varying, dept_cd character varying, dept_nm character varying, email character varying, sign_yn character varying, gridsave_yn character varying, login_fail_cnt integer, lock_yn character varying, user_use_yn character varying, co_use_yn character varying, svc_fn_dt character varying)
    LANGUAGE sql
    AS $$
    SELECT u.idx, u.user_id, u.user_nm, u.user_pw,
           u.co_cd, c.co_nm,
           u.usrgrp_cd, r.usrgrp_nm,
           u.dept_cd, d.dept_nm,
           u.email,
           -- 서명 보유여부만 내린다 — 로그인 응답에 16KB급 바이너리를 실을 이유가 없다
           (CASE WHEN u.sign_img IS NOT NULL THEN 'Y' ELSE 'N' END)::varchar,
           u.gridsave_yn,
           u.login_fail_cnt, u.lock_yn,
           u.use_yn, COALESCE(c.use_yn, 'N'), c.svc_fn_dt
      FROM tbl_user u
      -- 회사: 서비스 기간 만료·비활성 업체를 로그인 단계에서 걸러내기 위해 함께 읽는다
      LEFT JOIN tbl_company c ON c.co_cd = u.co_cd
      -- 권한그룹명: 로그인 응답과 화면 우측 상단 표기에 사용
      LEFT JOIN tbl_role    r ON r.co_cd = u.co_cd AND r.usrgrp_cd = u.usrgrp_cd
      -- 부서명: 문서 작성자란 기본값
      LEFT JOIN tbl_dept    d ON d.co_cd = u.co_cd AND d.dept_cd   = u.dept_cd
     WHERE u.user_id = p_user_id;
$$;


--
-- Name: FUNCTION sp_tbl_user_login_r_000(p_user_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_tbl_user_login_r_000(p_user_id character varying) IS '로그인 인증용 사용자 조회 — user_id 전역 UNIQUE 전제. 회사·권한그룹·부서를 한 번에 반환';


--
-- Name: sp_tbl_user_login_u_000(character varying, character varying, integer); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_user_login_u_000(IN p_user_id character varying, IN p_result_cd character varying, IN p_max_fail integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF p_result_cd = 'S' THEN
        UPDATE tbl_user
           SET login_fail_cnt = 0,
               last_login_dt  = now()
         WHERE user_id = p_user_id;
    ELSE
        UPDATE tbl_user
           SET login_fail_cnt = login_fail_cnt + 1,
               -- 임계 도달 시 즉시 잠금. 해제는 관리자가 사용자 관리 화면에서 처리한다
               lock_yn = CASE WHEN p_max_fail > 0 AND login_fail_cnt + 1 >= p_max_fail
                              THEN 'Y' ELSE lock_yn END
         WHERE user_id = p_user_id;
    END IF;
END$$;


--
-- Name: PROCEDURE sp_tbl_user_login_u_000(IN p_user_id character varying, IN p_result_cd character varying, IN p_max_fail integer); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_tbl_user_login_u_000(IN p_user_id character varying, IN p_result_cd character varying, IN p_max_fail integer) IS '로그인 결과 반영 — 성공 시 실패횟수 초기화, 실패 시 증가 및 임계 초과 잠금';


--
-- Name: sp_tbl_view_log_c_000(character varying, character varying, character varying, character varying, timestamp without time zone, timestamp without time zone, character varying, character varying, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_view_log_c_000(IN p_co_cd character varying, IN p_user_id character varying, IN p_sid character varying, IN p_scrn_cd character varying, IN p_enter_dt timestamp without time zone, IN p_leave_dt timestamp without time zone, IN p_ref_scrn_cd character varying, IN p_ip_addr character varying, IN p_user_agent character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO tbl_view_log(co_cd, user_id, sid, scrn_cd, enter_dt, leave_dt, stay_sec,
                             ref_scrn_cd, ip_addr, user_agent, ins_dt)
    VALUES (p_co_cd, p_user_id, NULLIF(p_sid, ''), p_scrn_cd, p_enter_dt, p_leave_dt,
            CASE WHEN p_leave_dt IS NULL THEN NULL
                 ELSE GREATEST(0, EXTRACT(EPOCH FROM (p_leave_dt - p_enter_dt))::int) END,
            NULLIF(p_ref_scrn_cd, ''), p_ip_addr, p_user_agent, now());
END$$;


--
-- Name: PROCEDURE sp_tbl_view_log_c_000(IN p_co_cd character varying, IN p_user_id character varying, IN p_sid character varying, IN p_scrn_cd character varying, IN p_enter_dt timestamp without time zone, IN p_leave_dt timestamp without time zone, IN p_ref_scrn_cd character varying, IN p_ip_addr character varying, IN p_user_agent character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_tbl_view_log_c_000(IN p_co_cd character varying, IN p_user_id character varying, IN p_sid character varying, IN p_scrn_cd character varying, IN p_enter_dt timestamp without time zone, IN p_leave_dt timestamp without time zone, IN p_ref_scrn_cd character varying, IN p_ip_addr character varying, IN p_user_agent character varying) IS '화면 조회 이벤트 적재 — 체류시간은 서버가 계산';


--
-- Name: sp_tbl_view_stat_daily_c_000(character varying, character varying, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_tbl_view_stat_daily_c_000(IN p_co_cd character varying, IN p_stat_dt character varying, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO tbl_view_stat_daily(co_cd, stat_dt, scrn_cd, pv_cnt, uv_cnt, sess_cnt, ip_cnt,
                                    avg_stay_sec, max_stay_sec, ins_id, ins_dt)
    SELECT v.co_cd,
           p_stat_dt,
           v.scrn_cd,
           COUNT(*),
           COUNT(DISTINCT v.user_id),
           COUNT(DISTINCT v.sid),
           COUNT(DISTINCT NULLIF(TRIM(v.ip_addr), '')),
           ROUND(AVG(v.stay_sec)::numeric, 1),
           MAX(v.stay_sec),
           p_id, now()
      FROM tbl_view_log v
     WHERE v.enter_dt >= to_timestamp(p_stat_dt, 'YYYYMMDD')
       AND v.enter_dt <  to_timestamp(p_stat_dt, 'YYYYMMDD') + interval '1 day'
       AND (COALESCE(p_co_cd, '') = '' OR v.co_cd = p_co_cd)
     GROUP BY v.co_cd, v.scrn_cd
    ON CONFLICT (co_cd, stat_dt, scrn_cd) DO UPDATE SET
        pv_cnt       = EXCLUDED.pv_cnt,
        uv_cnt       = EXCLUDED.uv_cnt,
        sess_cnt     = EXCLUDED.sess_cnt,
        ip_cnt       = EXCLUDED.ip_cnt,
        avg_stay_sec = EXCLUDED.avg_stay_sec,
        max_stay_sec = EXCLUDED.max_stay_sec,
        upd_id       = p_id,
        upd_dt       = now();
END$$;


--
-- Name: PROCEDURE sp_tbl_view_stat_daily_c_000(IN p_co_cd character varying, IN p_stat_dt character varying, IN p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_tbl_view_stat_daily_c_000(IN p_co_cd character varying, IN p_stat_dt character varying, IN p_id character varying) IS '화면별 일자 UV/PV/IP 집계 업서트 — 재실행 안전';


--
-- Name: sp_user_management_c_000(character varying, bigint, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_user_management_c_000(IN p_co_cd character varying, IN p_idx bigint, IN p_user_id character varying, IN p_emp_cd character varying, IN p_user_nm character varying, IN p_user_pw character varying, IN p_usrgrp_cd character varying, IN p_dept_cd character varying, IN p_email character varying, IN p_mobile character varying, IN p_lock_yn character varying, IN p_use_yn character varying, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- 아이디 전역 중복 검사 건수
    v_cnt int;
BEGIN
    -- 사용자명·권한그룹이 비면(= 화면이 값을 빠뜨림) 기존 값을 공백으로 덮어써
    -- 해당 계정의 메뉴 권한이 통째로 사라지므로 저장 자체를 막는다
    IF COALESCE(trim(p_user_nm), '') = '' THEN
        RAISE EXCEPTION '사용자명은 필수입니다.' USING ERRCODE = '45000';
    END IF;
    IF COALESCE(trim(p_usrgrp_cd), '') = '' THEN
        RAISE EXCEPTION '권한그룹은 필수입니다.' USING ERRCODE = '45000';
    END IF;

    IF p_idx IS NULL THEN
        -- UNIQUE 제약에 걸리기 전에 업무 문구로 막는다
        SELECT COUNT(*) INTO v_cnt FROM tbl_user WHERE user_id = p_user_id;
        IF v_cnt > 0 THEN
            RAISE EXCEPTION '이미 사용 중인 아이디입니다: %', p_user_id USING ERRCODE = '45000';
        END IF;

        INSERT INTO tbl_user(user_id, co_cd, emp_cd, user_nm, user_pw, usrgrp_cd, dept_cd,
                             email, mobile, lock_yn, use_yn, pw_upd_dt, ins_id, ins_dt)
        VALUES (p_user_id, p_co_cd, NULLIF(p_emp_cd, ''), p_user_nm, p_user_pw, p_usrgrp_cd,
                NULLIF(p_dept_cd, ''), p_email, p_mobile,
                COALESCE(NULLIF(p_lock_yn, ''), 'N'), COALESCE(NULLIF(p_use_yn, ''), 'Y'),
                now(), p_id, now());
    ELSE
        UPDATE tbl_user
           SET emp_cd    = NULLIF(p_emp_cd, ''),
               user_nm   = p_user_nm,
               -- 비밀번호는 값이 있을 때만 교체하고 변경일시를 함께 갱신한다
               user_pw   = COALESCE(NULLIF(p_user_pw, ''), user_pw),
               pw_upd_dt = CASE WHEN NULLIF(p_user_pw, '') IS NOT NULL THEN now() ELSE pw_upd_dt END,
               usrgrp_cd = p_usrgrp_cd,
               dept_cd   = NULLIF(p_dept_cd, ''),
               email     = p_email,
               mobile    = p_mobile,
               lock_yn   = COALESCE(NULLIF(p_lock_yn, ''), lock_yn),
               -- 잠금을 푸는 저장이면 실패횟수도 0으로 되돌린다
               login_fail_cnt = CASE WHEN p_lock_yn = 'N' THEN 0 ELSE login_fail_cnt END,
               use_yn    = COALESCE(NULLIF(p_use_yn, ''), use_yn),
               upd_id    = p_id, upd_dt = now()
         WHERE co_cd = p_co_cd AND idx = p_idx;
        IF NOT FOUND THEN
            RAISE EXCEPTION '수정할 사용자를 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
    END IF;
END$$;


--
-- Name: PROCEDURE sp_user_management_c_000(IN p_co_cd character varying, IN p_idx bigint, IN p_user_id character varying, IN p_emp_cd character varying, IN p_user_nm character varying, IN p_user_pw character varying, IN p_usrgrp_cd character varying, IN p_dept_cd character varying, IN p_email character varying, IN p_mobile character varying, IN p_lock_yn character varying, IN p_use_yn character varying, IN p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_user_management_c_000(IN p_co_cd character varying, IN p_idx bigint, IN p_user_id character varying, IN p_emp_cd character varying, IN p_user_nm character varying, IN p_user_pw character varying, IN p_usrgrp_cd character varying, IN p_dept_cd character varying, IN p_email character varying, IN p_mobile character varying, IN p_lock_yn character varying, IN p_use_yn character varying, IN p_id character varying) IS '사용자 저장 — 신규는 아이디 전역 중복 검사, 수정은 비밀번호가 있을 때만 교체. 서명은 받지 않음';


--
-- Name: sp_user_management_d_000(character varying, bigint); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_user_management_d_000(IN p_co_cd character varying, IN p_idx bigint)
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- 삭제 대상 로그인 아이디. NULL이면 대상 없음
    v_user_id varchar(20);
BEGIN
    SELECT user_id INTO v_user_id FROM tbl_user WHERE co_cd = p_co_cd AND idx = p_idx;
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION '삭제할 사용자를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    DELETE FROM tbl_user_noti_pref WHERE co_cd = p_co_cd AND user_id = v_user_id;
    DELETE FROM tbl_grid_pref      WHERE co_cd = p_co_cd AND user_id = v_user_id;
    DELETE FROM tbl_user           WHERE co_cd = p_co_cd AND idx = p_idx;
END$$;


--
-- Name: PROCEDURE sp_user_management_d_000(IN p_co_cd character varying, IN p_idx bigint); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_user_management_d_000(IN p_co_cd character varying, IN p_idx bigint) IS '사용자 삭제 — 개인 설정까지 정리, 작성 문서는 이력 보존';


--
-- Name: sp_user_management_delete_blocker_r_000(character varying, bigint[]); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_user_management_delete_blocker_r_000(p_co_cd character varying, p_idxs bigint[]) RETURNS TABLE(ref_key character varying, target character varying)
    LANGUAGE sql
    AS $$
    -- 차단 사유 없음 — 시그니처를 맞추기 위해 빈 결과를 반환한다
    SELECT u.user_id::varchar, ''::varchar
      FROM tbl_user u
     WHERE u.co_cd = p_co_cd
       AND u.idx = ANY(p_idxs)
       AND FALSE;
$$;


--
-- Name: FUNCTION sp_user_management_delete_blocker_r_000(p_co_cd character varying, p_idxs bigint[]); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_user_management_delete_blocker_r_000(p_co_cd character varying, p_idxs bigint[]) IS '사용자 삭제 차단 — 문서는 이력 보존이라 차단 사유 없음(항상 0행)';


--
-- Name: sp_user_management_r_000(character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_user_management_r_000(p_co_cd character varying, p_user_id character varying, p_user_nm character varying, p_dept_cd character varying, p_use_yn character varying) RETURNS TABLE(idx bigint, user_id character varying, co_cd character varying, emp_cd character varying, user_nm character varying, usrgrp_cd character varying, usrgrp_nm character varying, dept_cd character varying, dept_nm character varying, email character varying, mobile character varying, sign_yn character varying, gridsave_yn character varying, last_login_dt timestamp without time zone, login_fail_cnt integer, lock_yn character varying, use_yn character varying)
    LANGUAGE sql
    AS $$
    SELECT u.idx, u.user_id, u.co_cd, u.emp_cd, u.user_nm,
           u.usrgrp_cd, r.usrgrp_nm, u.dept_cd, d.dept_nm,
           u.email, u.mobile,
           -- 서명 보유여부만 내린다 — 16KB급 바이너리를 목록에 실으면 그리드가 무거워진다
           (CASE WHEN u.sign_img IS NOT NULL THEN 'Y' ELSE 'N' END)::varchar,
           u.gridsave_yn,
           u.last_login_dt, u.login_fail_cnt, u.lock_yn, u.use_yn
      FROM tbl_user u
      -- 권한그룹명 — 그리드 표시 전용
      LEFT JOIN tbl_role r ON r.co_cd = u.co_cd AND r.usrgrp_cd = u.usrgrp_cd
      -- 부서명 — 그리드 표시 전용
      LEFT JOIN tbl_dept d ON d.co_cd = u.co_cd AND d.dept_cd   = u.dept_cd
     WHERE u.co_cd = p_co_cd
       AND u.user_id LIKE CONCAT('%', COALESCE(p_user_id, ''), '%')
       AND u.user_nm LIKE CONCAT('%', COALESCE(p_user_nm, ''), '%')
       AND COALESCE(u.dept_cd, '') LIKE CONCAT('%', COALESCE(p_dept_cd, ''), '%')
       AND u.use_yn  LIKE CONCAT('%', COALESCE(p_use_yn,  ''), '%')
     ORDER BY u.user_id;
$$;


--
-- Name: FUNCTION sp_user_management_r_000(p_co_cd character varying, p_user_id character varying, p_user_nm character varying, p_dept_cd character varying, p_use_yn character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_user_management_r_000(p_co_cd character varying, p_user_id character varying, p_user_nm character varying, p_dept_cd character varying, p_use_yn character varying) IS '사용자 목록 — 비밀번호 해시 제외, 서명은 보유여부(sign_yn)만. 헤더 아이디·이름·부서·사용여부 LIKE';


--
-- Name: sp_user_management_sign_info_r_000(character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_user_management_sign_info_r_000(p_co_cd character varying, p_user_id character varying) RETURNS TABLE(sign_yn character varying, sign_nm character varying, sign_mime character varying)
    LANGUAGE sql
    AS $$
    SELECT
           -- 보유여부 — NULL 검사만 하므로 바이너리 본문을 읽지 않는다
           (CASE WHEN u.sign_img IS NOT NULL THEN 'Y' ELSE 'N' END)::varchar,
           -- 파일명 — 미등록이면 빈 문자열. 화면은 이 값으로도 유무를 판단할 수 있다
           (CASE WHEN u.sign_img IS NOT NULL THEN COALESCE(u.sign_nm, 'sign.png') ELSE '' END)::varchar,
           -- MIME — 미등록이면 빈 문자열, 구 데이터로 비어 있으면 PNG로 본다
           (CASE WHEN u.sign_img IS NOT NULL THEN COALESCE(u.sign_mime, 'image/png') ELSE '' END)::varchar
      FROM tbl_user u
     WHERE u.co_cd = p_co_cd
       AND u.user_id = p_user_id;
$$;


--
-- Name: FUNCTION sp_user_management_sign_info_r_000(p_co_cd character varying, p_user_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_user_management_sign_info_r_000(p_co_cd character varying, p_user_id character varying) IS '사용자 서명 메타데이터 — 보유여부·파일명·MIME만. 바이너리를 읽지 않는다';


--
-- Name: sp_user_management_sign_r_000(character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_user_management_sign_r_000(p_co_cd character varying, p_user_id character varying) RETURNS TABLE(sign_img bytea, sign_mime character varying, sign_nm character varying)
    LANGUAGE sql
    AS $$
    SELECT u.sign_img,
           -- MIME이 비어 있으면(= 구 데이터) PNG로 본다
           COALESCE(u.sign_mime, 'image/png')::varchar,
           COALESCE(u.sign_nm, 'sign.png')::varchar
      FROM tbl_user u
     WHERE u.co_cd = p_co_cd
       AND u.user_id = p_user_id;
$$;


--
-- Name: FUNCTION sp_user_management_sign_r_000(p_co_cd character varying, p_user_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON FUNCTION sasshaccp.sp_user_management_sign_r_000(p_co_cd character varying, p_user_id character varying) IS '사용자 서명 바이너리 조회 — 미등록이면 sign_img NULL 1행';


--
-- Name: sp_user_management_sign_u_000(character varying, character varying, bytea, character varying, character varying, character varying); Type: PROCEDURE; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE PROCEDURE sasshaccp.sp_user_management_sign_u_000(IN p_co_cd character varying, IN p_user_id character varying, IN p_sign_img bytea, IN p_sign_mime character varying, IN p_sign_nm character varying, IN p_id character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE tbl_user
       SET sign_img  = p_sign_img,
           -- 삭제(p_sign_img IS NULL)일 때 부가정보도 같이 비워 잔여값이 남지 않게 한다
           sign_mime = CASE WHEN p_sign_img IS NULL THEN NULL
                            ELSE COALESCE(NULLIF(p_sign_mime, ''), 'image/png') END,
           sign_nm   = CASE WHEN p_sign_img IS NULL THEN NULL
                            ELSE COALESCE(NULLIF(p_sign_nm, ''), 'sign.png') END,
           upd_id    = p_id,
           upd_dt    = now()
     WHERE co_cd = p_co_cd
       AND user_id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION '서명을 저장할 사용자를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
END$$;


--
-- Name: PROCEDURE sp_user_management_sign_u_000(IN p_co_cd character varying, IN p_user_id character varying, IN p_sign_img bytea, IN p_sign_mime character varying, IN p_sign_nm character varying, IN p_id character varying); Type: COMMENT; Schema: sasshaccp; Owner: -
--

COMMENT ON PROCEDURE sasshaccp.sp_user_management_sign_u_000(IN p_co_cd character varying, IN p_user_id character varying, IN p_sign_img bytea, IN p_sign_mime character varying, IN p_sign_nm character varying, IN p_id character varying) IS '사용자 서명 바이너리 저장·삭제 — NULL이면 서명 제거. 대상 없으면 45000';


SET default_tablespace = '';

SET default_table_access_method = heap;

--

--
-- Name: sp_tbl_document_delete_blocker_r_000(character varying, bigint[]); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_document_delete_blocker_r_000(
    p_co_cd character varying,
    p_doc_idxs bigint[]
) RETURNS TABLE(ref_key character varying, target character varying)
    LANGUAGE sql STABLE
    AS $$
    SELECT d.doc_no,
           CASE d.status
               WHEN 'REQ' THEN '전송'
               WHEN 'APV' THEN '결재완료'
               ELSE d.status
           END
      FROM tbl_document d
     WHERE d.co_cd = p_co_cd
       AND d.del_yn = 'N'
       AND d.status IN ('REQ', 'APV')
       AND d.idx = ANY(p_doc_idxs)
     ORDER BY d.doc_no
     LIMIT 1;
$$;

COMMENT ON FUNCTION sasshaccp.sp_tbl_document_delete_blocker_r_000(character varying, bigint[])
    IS '문서 삭제 차단 — 전송·결재완료 문서 첫 건. 작성 6화면·문서 허브 공용';

--
-- Name: sp_tbl_schedule_rule_active_r_000(); Type: FUNCTION; Schema: sasshaccp; Owner: -
--

CREATE OR REPLACE FUNCTION sasshaccp.sp_tbl_schedule_rule_active_r_000()
RETURNS TABLE(
    co_cd character varying,
    tmpl_cd character varying,
    cycle_cd character varying,
    nonwork_rule character varying,
    base_dt character varying,
    due_time character varying,
    dept_cd character varying,
    user_id character varying,
    details text
)
    LANGUAGE sql STABLE
    AS $$
    SELECT r.co_cd,
           r.tmpl_cd,
           r.cycle_cd,
           r.nonwork_rule,
           r.base_dt,
           r.due_time,
           r.dept_cd,
           r.user_id,
           COALESCE((
               SELECT jsonb_agg(
                          jsonb_build_object('detailTy', x.detail_ty, 'val1', x.val1, 'val2', x.val2)
                          ORDER BY x.seq)
                 FROM tbl_schedule_rule_detail x
                WHERE x.co_cd = r.co_cd AND x.tmpl_cd = r.tmpl_cd
           ), '[]'::jsonb)::text
      FROM tbl_schedule_rule r
      JOIN tbl_company_template ct
        ON ct.co_cd = r.co_cd
       AND ct.tmpl_cd = r.tmpl_cd
       AND upper(COALESCE(ct.use_yn, 'N')) = 'Y'
     WHERE upper(COALESCE(r.use_yn, 'N')) = 'Y'
     ORDER BY r.co_cd, r.tmpl_cd;
$$;

COMMENT ON FUNCTION sasshaccp.sp_tbl_schedule_rule_active_r_000()
    IS '예정일 배치 재생성 대상 — 전 업체의 사용 중 주기 + 반복 상세. 테넌트 인자 없음';


--
-- Name: sp_calendar_r_000(character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--
-- p_co_cd: JWT 회사코드 — 테넌트 범위
-- p_from_ymd: 조회 시작일 YYYYMMDD — 캘린더가 그리는 첫 칸
-- p_to_ymd: 조회 종료일 YYYYMMDD — 캘린더가 그리는 마지막 칸

-- 반환 컬럼(due_time) 추가 — 라이브는 반환 타입이 바뀌므로 DROP 후 CREATE
DROP FUNCTION IF EXISTS sasshaccp.sp_calendar_r_000(character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION sasshaccp.sp_calendar_r_000(
    p_co_cd character varying,
    p_from_ymd character varying,
    p_to_ymd character varying
) RETURNS TABLE(
    task_idx bigint,
    tmpl_cd character varying,
    tmpl_nm character varying,
    base_dt character varying,
    due_dt character varying,
    due_time character varying,
    status character varying,
    user_id character varying,
    dept_cd character varying,
    doc_idx bigint
)
    LANGUAGE sql STABLE
    AS $$
    -- 회사 전체 작성과제 — 오늘 할 일과 달리 담당자 필터를 걸지 않는다
    -- doc_idx: 이미 쓴 문서면 더블클릭 시 그 문서를 연다. 없으면 0
    SELECT t.idx,
           t.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, tp.tmpl_nm, t.tmpl_cd),
           t.base_dt,
           t.due_dt,
           t.due_time,
           COALESCE(dc.status, t.status),
           t.user_id,
           t.dept_cd,
           COALESCE(dc.idx, t.doc_idx)
      FROM tbl_schedule_task t
      JOIN tbl_template tp ON tp.tmpl_cd = t.tmpl_cd AND tp.co_cd = t.co_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = t.co_cd AND ct.tmpl_cd = t.tmpl_cd
      LEFT JOIN LATERAL (
          SELECT d.idx, d.status
            FROM tbl_document d
           WHERE d.co_cd = t.co_cd AND d.tmpl_cd = t.tmpl_cd
             AND d.base_dt = t.base_dt AND d.del_yn = 'N'
           ORDER BY d.idx DESC
           LIMIT 1
      ) dc ON TRUE
     WHERE t.co_cd = p_co_cd
       AND t.base_dt >= p_from_ymd
       AND t.base_dt <= p_to_ymd
     ORDER BY t.base_dt, t.idx;
$$;

COMMENT ON FUNCTION sasshaccp.sp_calendar_r_000(character varying, character varying, character varying)
    IS '일정 캘린더 — 회사 전체 작성과제. 담당 색상은 서버가 JWT로 mine 을 붙인다';


--
-- Name: sp_calendar_workday_r_000(character varying, character varying, character varying); Type: FUNCTION; Schema: sasshaccp; Owner: -
--
-- p_co_cd: JWT 회사코드
-- p_from_ymd: 조회 시작일 YYYYMMDD
-- p_to_ymd: 조회 종료일 YYYYMMDD

CREATE OR REPLACE FUNCTION sasshaccp.sp_calendar_workday_r_000(
    p_co_cd character varying,
    p_from_ymd character varying,
    p_to_ymd character varying
) RETURNS TABLE(ymd character varying)
    LANGUAGE sql STABLE
    AS $$
    SELECT w.ymd
      FROM tbl_workday_override w
     WHERE w.co_cd = p_co_cd
       AND w.ymd >= p_from_ymd
       AND w.ymd <= p_to_ymd
     ORDER BY w.ymd;
$$;

COMMENT ON FUNCTION sasshaccp.sp_calendar_workday_r_000(character varying, character varying, character varying)
    IS '영업일 전환 목록 — 행이 있는 날을 영업일로 취급한다';


--
-- Name: sp_calendar_workday_u_000; Type: PROCEDURE; Schema: sasshaccp; Owner: -
--
-- p_co_cd: JWT 회사코드
-- p_ymd: 대상일 YYYYMMDD
-- p_work_yn: Y면 영업일 INSERT, N이면 DELETE
-- p_user_id: JWT 작업자

CREATE OR REPLACE PROCEDURE sasshaccp.sp_calendar_workday_u_000(
    IN p_co_cd character varying,
    IN p_ymd character varying,
    IN p_work_yn character varying,
    IN p_user_id character varying
)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Y일 때(= 주말·공휴일을 영업일로) 행을 넣는다. 이미 있으면 그대로 둔다
    IF upper(COALESCE(p_work_yn, '')) = 'Y' THEN
        INSERT INTO tbl_workday_override (co_cd, ymd, ins_id, ins_dt)
        VALUES (p_co_cd, p_ymd, p_user_id, now())
        ON CONFLICT (co_cd, ymd) DO NOTHING;
        RETURN;
    END IF;
    -- N일 때(= 다시 비영업일) 전환 행을 지운다
    DELETE FROM tbl_workday_override
     WHERE co_cd = p_co_cd AND ymd = p_ymd;
END;
$$;

COMMENT ON PROCEDURE sasshaccp.sp_calendar_workday_u_000(character varying, character varying, character varying, character varying)
    IS '영업일 전환 저장 — Y INSERT(중복 무시), N DELETE. 테넌트는 p_co_cd';


--
-- Name: sp_auth_password_u_000; Type: PROCEDURE; Schema: sasshaccp; Owner: -
--
-- p_co_cd: JWT 회사코드 — 테넌트 범위
-- p_user_id: JWT 본인 아이디 — 남의 비밀번호를 바꾸지 못하게
-- p_user_pw: BCrypt 해시 — 평문은 서비스에서만 받는다

CREATE OR REPLACE PROCEDURE sasshaccp.sp_auth_password_u_000(
    IN p_co_cd character varying,
    IN p_user_id character varying,
    IN p_user_pw character varying
)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE tbl_user
       SET user_pw = p_user_pw,
           pw_upd_dt = now(),
           upd_id = p_user_id,
           upd_dt = now()
     WHERE co_cd = p_co_cd
       AND user_id = p_user_id;
    -- 대상이 없을 때(= 테넌트 밖이거나 없는 아이디) 업무 예외
    IF NOT FOUND THEN
        RAISE EXCEPTION '비밀번호를 변경할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
END;
$$;

COMMENT ON PROCEDURE sasshaccp.sp_auth_password_u_000(character varying, character varying, character varying)
    IS '본인 비밀번호 변경 — JWT 회사·아이디만. 해시는 서비스가 넘긴다';
