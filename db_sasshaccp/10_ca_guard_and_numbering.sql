-- 10_ca_guard_and_numbering.sql — 개선조치 보존·채번·길이·검증 (라이브·시험 전용)
--
-- 개발자: 박승우
-- 일자: 2026-09-04
-- 코멘트:
--   1) 빈 DB 는 00_ddl + 01_sp 로 이미 고쳐진 상태가 깔린다. 이 본은 라이브·시험 전용이다
--   2) 적용 대상: sasshaccp(라이브) · sasshaccp_test(시험)
--   3) **자료를 안 건드린다.** 프로시저 재정의만이라 되돌림이 깨끗하다 —
--      되돌리려면 01_sp.sql 의 이전 판본으로 같은 이름들을 CREATE OR REPLACE 하면 된다
--
-- 앞서 나간 10_hwp_send_guard.sql 을 이 본이 **포함한다.**
-- 아직 안 올렸으면 이 본만 돌리면 되고, 이미 올렸으면 다시 돌려도 같다(CREATE OR REPLACE).
--
-- 담은 것
--   K8    sp_tbl_document_approval_c_000  본문 없는 HWP 문서의 상신 차단
--   K17-b 같은 SP                          opinion 을 left(...,500) 로 자른다
--   K5-b  sp_tbl_doc_corrective_u_000      완료된 개선조치를 원문서 저장이 지우거나 되돌리지 않는다
--   K6    같은 SP · _c_000                 ca_no 를 최대 연번+1 로. _c_000 접두를 발생일로
--   K10   sp_tbl_corrective_action_c_000   action_user_nm 을 실제로 저장한다
--   K16   _d_000 네 본                      문서를 지워도 완료된 개선조치는 남긴다
--   K17-b sp_tbl_audit_log_c_000           reason 을 left(...,500) 로 자른다
--   K21   sp_tbl_ccp_generic_monitor_c_000 일자 8자리 검증 (형제 셋과 같은 기준)
--
-- 적용 전에 세어 둔다 — 이 문서들은 K8 가드 뒤로 전송이 막힌다.
--
--   SELECT d.co_cd, d.doc_no, d.writer_id
--     FROM tbl_document d
--    WHERE d.doc_kind = 'HWP' AND d.status = 'WRK' AND d.del_yn = 'N'
--      AND NOT EXISTS (SELECT 1 FROM tbl_document_file f
--                       WHERE f.co_cd = d.co_cd AND f.doc_idx = d.idx
--                         AND upper(f.file_kind) = 'HWP_SRC');
--
-- 적용 후 확인 — 형식이 어긋난 ca_no 가 있으면 K6 의 정규식이 그 행을 건너뛴다.
-- 0 이 아니면 채번 기준이 그 회사·일자에서 어긋날 수 있으니 눈으로 본다.
--
--   SELECT co_cd, occur_dt, ca_no FROM tbl_corrective_action
--    WHERE ca_no !~ '^CA-[0-9]{8}-[0-9]{3}$';

SET search_path TO sasshaccp;


-- ── sp_tbl_document_approval_c_000
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

-- ── sp_tbl_doc_corrective_u_000
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

-- ── sp_tbl_corrective_action_c_000
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

-- ── sp_ccp_verify_d_000
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

-- ── sp_tbl_ccp_generic_monitor_d_000
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

-- ── sp_tbl_ccp_metal_monitor_d_000
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

-- ── sp_tbl_hyg_process_d_000
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

-- ── sp_tbl_audit_log_c_000
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

-- ── sp_tbl_ccp_generic_monitor_c_000
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
