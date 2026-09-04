-- 10_hwp_send_guard.sql — 본문 없는 HWP 문서의 상신을 막는다
--
-- 개발자: 박승우
-- 일자: 2026-09-04
-- 코멘트:
--   1) 빈 DB 는 00_ddl + 01_sp 로 이미 고쳐진 상태가 깔린다. 이 본은 라이브·시험 전용이다
--   2) 적용 대상: sasshaccp(라이브) · sasshaccp_test(시험)
--   3) 데이터를 안 건드린다. 프로시저 재정의만이라 되돌림이 깨끗하다
--
-- 되돌리기: 01_sp.sql 의 이전 판본으로 같은 프로시저만 CREATE OR REPLACE
--
-- 적용 전에 먼저 세어 둔다 — 이 문서들은 가드 뒤로 전송이 막힌다.
-- 작성자에게 「편집기에서 열고 저장한 뒤 전송」을 알려야 한다.
--
--   SELECT d.co_cd, d.doc_no, d.writer_id
--     FROM tbl_document d
--    WHERE d.doc_kind = 'HWP' AND d.status = 'WRK' AND d.del_yn = 'N'
--      AND NOT EXISTS (SELECT 1 FROM tbl_document_file f
--                       WHERE f.co_cd = d.co_cd AND f.doc_idx = d.idx
--                         AND upper(f.file_kind) = 'HWP_SRC');

SET search_path TO sasshaccp;

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
               opinion = p_opinion,
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
           opinion = NULLIF(p_opinion, ''),
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
