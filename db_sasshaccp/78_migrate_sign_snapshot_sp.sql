-- ============================================================
--  migrate 78 — 서명 스냅샷 SP를 bytea 기반으로 전환
--
--  개발자: 박승우
--  일자: 2026-08-12
--  코멘트:
--    1) 71에서 붙인 sign_img(bytea)를 실제로 쓰는 SP 6개를 다시 정의한다
--       (로그인 조회 · 결재 단계 조회/처리 · CCP 냉장 행 조회/저장 · CCP 범용 조회/저장)
--    2) 스냅샷 방식이 바뀐다 — FE가 서명 경로를 실어 보내지 않고 signYn만 보낸다
--       저장 SP가 tbl_user.sign_img를 그 시점 값으로 복사한다(사용자가 서명을 바꿔도 과거 기록은 불변)
--    3) 조회 SP는 바이너리를 내리지 않고 sign_yn(= sign_img IS NOT NULL)만 내린다
--       그리드는 보유여부만 필요하고, 실물은 /users/{id}/sign 단건 API로만 나간다
--    4) 본문은 각 정본(11·15·33·39·43)과 동일하고 서명 부분만 다르다 — 33이 15를 덮는 방식과 같은 패턴이다
--
--  적용 순서: 70 → 71 → 71b → 72~79 → BE/FE 교체 → 회귀 통과 → 80 DROP
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. sp_tbl_user_login_r_000 (11 정본) — 로그인 조회. sign_path OUT을 sign_yn으로 교체
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_user_login_r_000(varchar);
CREATE FUNCTION sp_tbl_user_login_r_000(
    -- p_user_id: 로그인 화면에서 입력한 아이디 (대소문자 구분)
    p_user_id varchar
)
RETURNS TABLE(
    user_idx       bigint,
    user_id        varchar,
    user_nm        varchar,
    user_pw        varchar,
    co_cd          varchar,
    co_nm          varchar,
    usrgrp_cd      varchar,
    usrgrp_nm      varchar,
    dept_cd        varchar,
    dept_nm        varchar,
    email          varchar,
    sign_yn        varchar,
    gridsave_yn    varchar,
    login_fail_cnt int,
    lock_yn        varchar,
    user_use_yn    varchar,
    co_use_yn      varchar,
    svc_fn_dt      varchar
) LANGUAGE sql AS $$
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
COMMENT ON FUNCTION sp_tbl_user_login_r_000(varchar) IS '로그인 인증용 사용자 조회 — user_id 전역 UNIQUE 전제. 회사·권한그룹·부서를 한 번에 반환';

-- ------------------------------------------------------------
-- 2. sp_tbl_document_approval_r_000 (15 정본) — 결재 단계 조회. sign_path OUT을 sign_yn으로 교체
-- ------------------------------------------------------------
-- 반환 컬럼명이 바뀌므로 CREATE OR REPLACE만으로는 안 된다 — 선 DROP
DROP FUNCTION IF EXISTS sp_tbl_document_approval_r_000(varchar, bigint);
CREATE OR REPLACE FUNCTION sp_tbl_document_approval_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_doc_idx: 문서 idx
    p_doc_idx bigint
)
RETURNS TABLE (
    idx bigint,
    doc_idx bigint,
    step_no int,
    role_cd varchar,
    approver_id varchar,
    approver_nm varchar,
    result_cd varchar,
    opinion varchar,
    act_dt timestamp,
    sign_yn varchar
)
LANGUAGE sql STABLE AS $$
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
COMMENT ON FUNCTION sp_tbl_document_approval_r_000(varchar, bigint) IS '문서 결재 단계 조회 — 작성·검토·승인 서명란';

-- ------------------------------------------------------------
-- 3. sp_tbl_document_approval_c_000 (33 정본) — 결재 처리. 서명 스냅샷을 bytea로 복사
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_document_approval_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_doc_idx: 처리 대상 문서 idx
    p_doc_idx bigint,
    -- p_action_cd: REQUEST/CANCEL/REVIEW/APPROVE/REJECT
    p_action_cd varchar,
    -- p_opinion: 결재 의견. REJECT일 때 필수
    p_opinion varchar,
    -- p_id: 현재 로그인 사용자 ID
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_status varchar(3);
    v_writer varchar(20);
    v_line varchar(20);
    v_step record;
    v_pending record;
    v_user_nm varchar(50);
    -- 결재자 서명 원본 — 이 결재 시점의 값을 결재행에 스냅샷으로 복사한다
    v_sign_img bytea;
BEGIN
    SELECT d.status, d.writer_id, d.appr_line_cd
      INTO v_status, v_writer, v_line
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
        -- 검토요청일 때(= 작성자가 상신취소 가능) 결재 스냅샷을 지우고 작성중으로 되돌린다
        IF v_status <> 'REQ' THEN
            RAISE EXCEPTION '검토요청 상태만 상신취소할 수 있습니다.' USING ERRCODE = '45000';
        END IF;
        IF v_writer IS DISTINCT FROM p_id THEN
            RAISE EXCEPTION '작성자만 상신취소할 수 있습니다.' USING ERRCODE = '45000';
        END IF;
        -- 검토·승인 단계에 서명이 들어갔을 때(= 이미 처리됨) 취소 차단
        IF EXISTS (
            SELECT 1 FROM tbl_document_approval
             WHERE co_cd = p_co_cd
               AND doc_idx = p_doc_idx
               AND role_cd IN ('REVIEW', 'APPROVE')
               AND result_cd <> 'W'
        ) THEN
            RAISE EXCEPTION '검토 또는 승인이 진행된 문서는 상신취소할 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        DELETE FROM tbl_document_approval
         WHERE co_cd = p_co_cd
           AND doc_idx = p_doc_idx;
        UPDATE tbl_document
           SET status = 'WRK',
               write_dt = NULL,
               reject_reason = NULL,
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

        DELETE FROM tbl_document_approval
         WHERE co_cd = p_co_cd
           AND doc_idx = p_doc_idx;

        FOR v_step IN
            SELECT step_no, role_cd, approver_id
              FROM tbl_approval_line_step
             WHERE co_cd = p_co_cd
               AND appr_line_cd = COALESCE(v_line, 'DEFAULT')
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

        UPDATE tbl_document
           SET status = 'REQ',
               write_dt = now(),
               reject_reason = NULL,
               upd_id = p_id,
               upd_dt = now()
         WHERE idx = p_doc_idx
           AND co_cd = p_co_cd;
        RETURN;
    END IF;

    -- 현재 대기 단계 — WRITE는 REQUEST 시 승인되므로 REVIEW/APPROVE만 처리한다
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
               opinion = p_opinion,
               act_dt = now(),
               sign_img = v_sign_img,
               upd_id = p_id,
               upd_dt = now()
         WHERE idx = v_pending.idx
           AND co_cd = p_co_cd;

        UPDATE tbl_document
           SET status = 'RJT',
               reject_reason = p_opinion,
               upd_id = p_id,
               upd_dt = now()
         WHERE idx = p_doc_idx
           AND co_cd = p_co_cd;
        RETURN;
    END IF;

    IF p_action_cd NOT IN ('REVIEW', 'APPROVE') THEN
        RAISE EXCEPTION '지원하지 않는 결재 처리입니다.' USING ERRCODE = '45000';
    END IF;
    IF p_action_cd = 'REVIEW' AND v_pending.role_cd <> 'REVIEW' THEN
        RAISE EXCEPTION '현재 단계는 검토 단계가 아닙니다.' USING ERRCODE = '45000';
    END IF;
    IF p_action_cd = 'APPROVE' AND v_pending.role_cd <> 'APPROVE' THEN
        RAISE EXCEPTION '현재 단계는 승인 단계가 아닙니다.' USING ERRCODE = '45000';
    END IF;

    UPDATE tbl_document_approval
       SET approver_id = p_id,
           approver_nm = v_user_nm,
           result_cd = 'A',
           opinion = NULLIF(p_opinion, ''),
           act_dt = now(),
           sign_img = v_sign_img,
           upd_id = p_id,
           upd_dt = now()
     WHERE idx = v_pending.idx
       AND co_cd = p_co_cd;

    IF p_action_cd = 'REVIEW' THEN
        UPDATE tbl_document
           SET status = 'REV',
               reviewer_id = p_id,
               review_dt = now(),
               upd_id = p_id,
               upd_dt = now()
         WHERE idx = p_doc_idx
           AND co_cd = p_co_cd;
    ELSE
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
    END IF;
END$$;
COMMENT ON PROCEDURE sp_tbl_document_approval_c_000(varchar, bigint, varchar, varchar, varchar) IS '문서 결재 처리 — 상신·상신취소·검토·승인·반려·결재선 스냅샷';

-- ------------------------------------------------------------
-- 4. sp_tbl_ccp_cold_monitor_row_r_000 (39 정본) — 냉장 점검행 조회. sign_path OUT을 sign_yn으로 교체
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_ccp_cold_monitor_row_r_000(varchar, bigint);
CREATE FUNCTION sp_tbl_ccp_cold_monitor_row_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_hdr_idx: 헤더 idx
    p_hdr_idx bigint
)
RETURNS TABLE (
    idx          bigint,
    co_cd        varchar,
    hdr_idx      bigint,
    row_seq      int,
    check_time   varchar,
    judge_cd     varchar,
    judge_mod_yn varchar,
    checker_id   varchar,
    checker_nm   varchar,
    writer_id    varchar,
    writer_nm    varchar,
    sign_yn      varchar
)
LANGUAGE sql STABLE AS $$
    SELECT r.idx, r.co_cd, r.hdr_idx, r.row_seq, r.check_time,
           r.judge_cd, r.judge_mod_yn, r.checker_id, r.checker_nm,
           r.writer_id, r.writer_nm,
           -- 행 서명 보유여부 — 화면은 서명 도장 표시 여부만 필요하다
           (CASE WHEN r.sign_img IS NOT NULL THEN 'Y' ELSE 'N' END)::varchar
      FROM tbl_ccp_cold_monitor_row r
     WHERE r.co_cd = p_co_cd
       AND r.hdr_idx = p_hdr_idx
     ORDER BY r.row_seq;
$$;
COMMENT ON FUNCTION sp_tbl_ccp_cold_monitor_row_r_000(varchar, bigint) IS
  'CCP 냉장보관 점검행 목록 — 작성자·서명 포함';

-- ------------------------------------------------------------
-- 5. sp_tbl_ccp_cold_monitor_c_000 (39 정본) — 냉장 일지 저장. 행 서명을 bytea 스냅샷으로
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_ccp_cold_monitor_c_000(
    p_co_cd       varchar,
    p_doc_idx     bigint,
    p_base_dt     varchar,
    p_ccp_cd      varchar,
    p_mng_user_id varchar,
    p_mng_nm      varchar,
    p_rows_json   jsonb,
    p_id          varchar
)
RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE
    v_doc_idx   bigint;
    v_hdr_idx   bigint;
    v_doc_no    varchar(50);
    v_title     varchar(200);
    v_status    varchar(4);
    v_tmpl_nm   varchar(200);
    v_appr      varchar(20);
    v_retain_m  int;
    v_row       jsonb;
    v_temp      jsonb;
    v_row_idx   bigint;
    v_row_seq   int;
    v_check_tm  varchar(4);
    v_mod_yn    varchar(1);
    v_chk_id    varchar(20);
    v_chk_nm    varchar(50);
    v_wrt_id    varchar(20);
    v_wrt_nm    varchar(50);
    -- 행에 복사할 서명 바이너리 — 검사자(없으면 작성자)의 tbl_user.sign_img 스냅샷
    v_sign      bytea;
    v_man_judge varchar(1);
    v_row_judge varchar(1);
    v_st_cd     varchar(30);
    v_temp_val  numeric(5,1);
    v_cell_j    varchar(1);
    v_min       numeric(5,1);
    v_max       numeric(5,1);
    v_st_ccp    varchar(20);
BEGIN
    IF COALESCE(p_co_cd, '') = '' THEN
        RAISE EXCEPTION '회사코드는 필수입니다.' USING ERRCODE = '45000';
    END IF;
    IF COALESCE(p_base_dt, '') = '' OR length(p_base_dt) <> 8 THEN
        RAISE EXCEPTION '작성일은 YYYYMMDD 8자리로 입력하세요.' USING ERRCODE = '45000';
    END IF;
    IF COALESCE(p_ccp_cd, '') = '' THEN
        RAISE EXCEPTION 'CCP 코드는 필수입니다.' USING ERRCODE = '45000';
    END IF;
    IF p_rows_json IS NULL OR jsonb_typeof(p_rows_json) <> 'array' THEN
        RAISE EXCEPTION '점검 행 자료가 올바르지 않습니다.' USING ERRCODE = '45000';
    END IF;

    SELECT COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm),
           COALESCE(ct.appr_line_cd, 'DEFAULT'),
           COALESCE(ct.retention_month, t.default_retention_month)
      INTO v_tmpl_nm, v_appr, v_retain_m
      FROM tbl_template t
      LEFT JOIN tbl_company_template ct
        ON ct.co_cd = p_co_cd AND ct.tmpl_cd = t.tmpl_cd AND ct.use_yn = 'Y'
     WHERE t.tmpl_cd = 'tmpl_ccp-cold-log' AND t.use_yn = 'Y';

    IF v_tmpl_nm IS NULL THEN
        RAISE EXCEPTION 'CCP 냉장보관 양식이 등록되어 있지 않습니다.' USING ERRCODE = '45000';
    END IF;

    v_title := v_tmpl_nm || ' (' ||
               substr(p_base_dt, 1, 4) || '-' || substr(p_base_dt, 5, 2) || '-' || substr(p_base_dt, 7, 2) || ')';

    IF p_doc_idx IS NULL OR p_doc_idx = 0 THEN
        v_doc_no := sp_tbl_doc_no_gen_c_000(p_co_cd, 'tmpl_ccp-cold-log', p_base_dt);
        INSERT INTO tbl_document(
            co_cd, tmpl_cd, doc_kind, doc_no, base_dt, title, status,
            appr_line_cd, writer_id, write_dt, ver_no,
            retention_until, del_yn, ins_id, ins_dt
        )
        VALUES (
            p_co_cd, 'tmpl_ccp-cold-log', 'html', v_doc_no, p_base_dt, v_title, 'WRK',
            v_appr, p_id, now(), 1,
            to_char(
                (to_date(p_base_dt, 'YYYYMMDD') + (COALESCE(v_retain_m, 24) || ' months')::interval)::date,
                'YYYYMMDD'
            ),
            'N', p_id, now()
        )
        RETURNING idx INTO v_doc_idx;
        INSERT INTO tbl_ccp_cold_monitor(
            co_cd, doc_idx, base_dt, ccp_cd, mng_user_id, mng_nm, ins_id, ins_dt
        )
        VALUES (
            p_co_cd, v_doc_idx, p_base_dt, p_ccp_cd,
            NULLIF(p_mng_user_id, ''), NULLIF(p_mng_nm, ''),
            p_id, now()
        )
        RETURNING idx INTO v_hdr_idx;
    ELSE
        SELECT d.idx, d.status, h.idx
          INTO v_doc_idx, v_status, v_hdr_idx
          FROM tbl_document d
          JOIN tbl_ccp_cold_monitor h ON h.doc_idx = d.idx AND h.co_cd = d.co_cd
         WHERE d.co_cd = p_co_cd
           AND d.idx = p_doc_idx
           AND d.tmpl_cd = 'tmpl_ccp-cold-log'
           AND d.del_yn = 'N';
        IF v_doc_idx IS NULL THEN
            RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        IF v_status IN ('REQ', 'REV', 'APV') THEN
            RAISE EXCEPTION '결재 진행 중이거나 완료된 문서는 수정할 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        UPDATE tbl_document
           SET base_dt = p_base_dt, title = v_title, upd_id = p_id, upd_dt = now()
         WHERE idx = v_doc_idx AND co_cd = p_co_cd;
        UPDATE tbl_ccp_cold_monitor
           SET base_dt = p_base_dt, ccp_cd = p_ccp_cd,
               mng_user_id = NULLIF(p_mng_user_id, ''), mng_nm = NULLIF(p_mng_nm, ''),
               upd_id = p_id, upd_dt = now()
         WHERE idx = v_hdr_idx AND co_cd = p_co_cd;
        DELETE FROM tbl_ccp_cold_monitor_temp t
         USING tbl_ccp_cold_monitor_row r
         WHERE t.row_idx = r.idx AND t.co_cd = r.co_cd
           AND r.hdr_idx = v_hdr_idx AND r.co_cd = p_co_cd;
        DELETE FROM tbl_ccp_cold_monitor_row
         WHERE hdr_idx = v_hdr_idx AND co_cd = p_co_cd;
    END IF;

    FOR v_row IN SELECT * FROM jsonb_array_elements(p_rows_json)
    LOOP
        v_row_seq   := COALESCE((v_row->>'rowSeq')::int, 0);
        v_check_tm  := COALESCE(v_row->>'checkTime', '');
        v_mod_yn    := COALESCE(NULLIF(v_row->>'judgeModYn', ''), 'N');
        v_chk_id    := NULLIF(v_row->>'checkerId', '');
        v_chk_nm    := NULLIF(v_row->>'checkerNm', '');
        v_wrt_id    := NULLIF(COALESCE(v_row->>'writerId', v_row->>'checkerId'), '');
        v_wrt_nm    := NULLIF(COALESCE(v_row->>'writerNm', v_row->>'checkerNm'), '');
        -- 서명은 FE가 signYn만 보낸다. 실물은 검사자(없으면 작성자) 서명 원본을 지금 값으로 복사한다
        v_sign := NULL;
        IF COALESCE(v_row->>'signYn', 'N') = 'Y' THEN
            SELECT u.sign_img INTO v_sign
              FROM tbl_user u
             WHERE u.co_cd = p_co_cd
               AND u.user_id = COALESCE(v_chk_id, v_wrt_id);
        END IF;
        v_man_judge := NULLIF(v_row->>'judgeCd', '');

        IF v_row_seq <= 0 THEN
            RAISE EXCEPTION '점검 행 순번이 올바르지 않습니다.' USING ERRCODE = '45000';
        END IF;
        IF v_check_tm = '' THEN
            RAISE EXCEPTION '%번째 행의 점검시간이 없습니다.', v_row_seq USING ERRCODE = '45000';
        END IF;

        INSERT INTO tbl_ccp_cold_monitor_row(
            co_cd, hdr_idx, row_seq, check_time, judge_cd, judge_mod_yn,
            checker_id, checker_nm, writer_id, writer_nm, sign_img, ins_id, ins_dt
        )
        VALUES (
            p_co_cd, v_hdr_idx, v_row_seq, v_check_tm, NULL, v_mod_yn,
            v_chk_id, v_chk_nm, v_wrt_id, v_wrt_nm, v_sign, p_id, now()
        )
        RETURNING idx INTO v_row_idx;

        v_row_judge := NULL;
        FOR v_temp IN SELECT * FROM jsonb_array_elements(COALESCE(v_row->'temps', '[]'::jsonb))
        LOOP
            v_st_cd    := COALESCE(v_temp->>'storageCd', '');
            v_temp_val := NULLIF(v_temp->>'tempVal', '')::numeric;
            IF v_st_cd = '' THEN
                RAISE EXCEPTION '%번째 행의 보관고 코드가 없습니다.', v_row_seq USING ERRCODE = '45000';
            END IF;
            SELECT s.temp_min, s.temp_max, s.ccp_cd
              INTO v_min, v_max, v_st_ccp
              FROM tbl_storage s
             WHERE s.co_cd = p_co_cd AND s.storage_cd = v_st_cd AND s.use_yn = 'Y';
            IF NOT FOUND THEN
                RAISE EXCEPTION '사용 중인 보관고가 아닙니다: %', v_st_cd USING ERRCODE = '45000';
            END IF;
            IF v_min IS NULL OR v_max IS NULL THEN
                SELECT l.min_val, l.max_val INTO v_min, v_max
                  FROM tbl_ccp_limit l
                 WHERE l.co_cd = p_co_cd
                   AND l.ccp_cd = COALESCE(v_st_ccp, p_ccp_cd)
                   AND l.use_yn = 'Y';
            END IF;
            IF v_temp_val IS NULL THEN
                v_cell_j := NULL;
            ELSIF v_min IS NOT NULL AND v_temp_val < v_min THEN
                v_cell_j := 'F';
            ELSIF v_max IS NOT NULL AND v_temp_val > v_max THEN
                v_cell_j := 'F';
            ELSE
                v_cell_j := 'P';
            END IF;
            INSERT INTO tbl_ccp_cold_monitor_temp(
                co_cd, row_idx, storage_cd, temp_val, judge_cd, ins_id, ins_dt
            )
            VALUES (p_co_cd, v_row_idx, v_st_cd, v_temp_val, v_cell_j, p_id, now());
            IF v_cell_j = 'F' THEN
                v_row_judge := 'F';
            ELSIF v_cell_j = 'P' AND COALESCE(v_row_judge, '') <> 'F' THEN
                v_row_judge := 'P';
            END IF;
        END LOOP;

        -- 수동변경일 때(= O/X 또는 P/F) JSON judgeCd 우선
        IF v_mod_yn = 'Y' AND v_man_judge IS NOT NULL THEN
            v_row_judge := v_man_judge;
        END IF;

        UPDATE tbl_ccp_cold_monitor_row
           SET judge_cd = v_row_judge
         WHERE idx = v_row_idx AND co_cd = p_co_cd;
    END LOOP;

    RETURN v_doc_idx;
END$$;

-- ------------------------------------------------------------
-- 6. sp_tbl_ccp_generic_monitor_r_000 (43 정본) — 범용 CCP 조회. rows_json signPath를 signYn으로
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_ccp_generic_monitor_r_000(
    p_co_cd varchar,
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

-- ------------------------------------------------------------
-- 7. sp_tbl_ccp_generic_monitor_c_000 (43 정본) — 범용 CCP 저장. 행 서명을 bytea 스냅샷으로
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_ccp_generic_monitor_c_000(
    p_co_cd varchar,
    p_doc_idx bigint,
    p_base_dt varchar,
    p_tmpl_cd varchar,
    p_ccp_cd varchar,
    p_diary_no varchar,
    p_limit_item_kind varchar,
    p_mng_user_id varchar,
    p_mng_nm varchar,
    p_rows jsonb,
    p_id varchar
) RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE
    v_doc_idx bigint;
    v_monitor_idx bigint;
    v_doc_no varchar;
    v_title varchar(300);
    v_row jsonb;
    v_cell jsonb;
    v_row_idx bigint;
BEGIN
    IF jsonb_typeof(p_rows) <> 'array' OR jsonb_array_length(p_rows) = 0 THEN
        RAISE EXCEPTION '점검 행이 없습니다.' USING ERRCODE = '45000';
    END IF;
    SELECT coalesce(nullif(t.tmpl_nm, ''), '공통 CCP 모니터링') INTO v_title
      FROM tbl_template t WHERE t.tmpl_cd = p_tmpl_cd AND t.doc_kind = 'html' AND t.use_yn = 'Y';
    IF v_title IS NULL THEN
        RAISE EXCEPTION '사용할 공통 CCP 양식이 등록되어 있지 않습니다.' USING ERRCODE = '45000';
    END IF;

    IF coalesce(p_doc_idx, 0) <= 0 THEN
        v_doc_no := sp_tbl_doc_no_gen_c_000(p_co_cd, p_tmpl_cd, p_base_dt);
        INSERT INTO tbl_document (
            co_cd, tmpl_cd, doc_kind, doc_no, base_dt, title, status, writer_id, form_src, ins_id
        ) VALUES (
            p_co_cd, p_tmpl_cd, 'html', v_doc_no, p_base_dt, v_title, 'WRK', p_id, 'BASE', p_id
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
          JOIN tbl_document d ON d.idx = m.doc_idx
         WHERE m.co_cd = p_co_cd AND m.doc_idx = p_doc_idx AND d.del_yn = 'N' AND d.status IN ('WRK', 'RJT');
        IF v_monitor_idx IS NULL THEN
            RAISE EXCEPTION '수정할 임시 또는 반려 문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        v_doc_idx := p_doc_idx;
        UPDATE tbl_document SET base_dt = p_base_dt, title = v_title, upd_id = p_id, upd_dt = now()
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
            co_cd, monitor_idx, row_seq, check_time, equip_nm, product_nm,
            judge_cd, judge_mod_yn, checker_id, checker_nm, sign_img, ins_id
        ) VALUES (
            p_co_cd, v_monitor_idx, coalesce(nullif(v_row->>'rowSeq', '')::int, 0), nullif(v_row->>'checkTime', ''),
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
                p_co_cd, v_row_idx, v_cell->>'itemCd', nullif(v_cell->>'numVal', '')::numeric,
                nullif(v_cell->>'txtVal', ''), nullif(v_cell->>'judgeCd', ''), p_id
            );
        END LOOP;
    END LOOP;
    RETURN v_doc_idx;
END;
$$;
