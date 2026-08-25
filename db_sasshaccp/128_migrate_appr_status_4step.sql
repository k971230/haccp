-- ============================================================
--  128_migrate_appr_status_4step.sql — 결재 4단계 · 결재이력 조회 수정
--
--  파일번호: 128
--  이전번호: 127
--  개발자: 박승우
--  일자: 2026-08-25
--  코멘트:
--    1) 결재선의 꺼 둔 단계(use_yn='N')가 그대로 결재선에 들어가던 것을 막는다
--       기본 결재선의 검토(REVIEW)는 use_yn='N' 인데도 상신 때 삽입돼
--       모든 문서가 「검토요청」에서 멈추고 검토 → 승인 2단을 밟아야 했다
--    2) 결재이력(sign-ok)이 작성자 본인의 미결 문서까지 보여 주던 것을 막는다
--       WRITE 단계는 상신 때 작성자 이름으로 자동 승인(result_cd='A')되므로
--       role_cd 를 REVIEW·APPROVE 로 좁히지 않으면 작성자에게 자기 문서가 결재이력으로 보인다
--    3) 상태 라벨을 업무 용어로 맞춘다 — REQ 「검토요청」 → 「승인요청」
--
--  결과 흐름: 작성중(WRK) → 승인요청(REQ) → 승인완료(APV) · 반려(RJT)
--  검토(REV)는 스키마에 남겨 둔다. 나중에 결재선에서 검토 단계를 켜면 그대로 동작한다.
--
--  실행: psql -f 128_migrate_appr_status_4step.sql (수동·DBeaver)
-- ============================================================

SET search_path TO sasshaccp;

BEGIN;

-- ------------------------------------------------------------
-- 1. 상태 라벨 — 검토요청 → 승인요청
-- ------------------------------------------------------------
UPDATE tbl_code
   SET code_nm = '승인요청', upd_id = 'system', upd_dt = now()
 WHERE main_cd = 'DOC_STATUS'
   AND sub_cd = 'REQ'
   AND code_nm IS DISTINCT FROM '승인요청';

-- ------------------------------------------------------------
-- 2. 결재이력 — 내가 「결재한」 문서만. 작성자 자동승인(WRITE)은 이력이 아니다
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_document_appr_hist_r_000(
    p_co_cd varchar,
    p_user_id varchar,
    p_from_dt varchar,
    p_to_dt varchar,
    p_keyword varchar
)
RETURNS TABLE (
    doc_idx bigint, co_cd varchar, tmpl_cd varchar, tmpl_nm varchar, doc_kind varchar,
    doc_no varchar, base_dt varchar, title varchar, status varchar, appr_line_cd varchar,
    writer_id varchar, writer_nm varchar, write_dt timestamp, ver_no int, retention_until varchar,
    file_cnt int, open_ca_cnt int, my_result_cd varchar, my_act_dt timestamp
)
LANGUAGE sql STABLE AS $$
    SELECT DISTINCT ON (d.idx)
           d.idx, d.co_cd, d.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm, d.tmpl_cd),
           d.doc_kind, d.doc_no, d.base_dt, d.title, d.status, d.appr_line_cd,
           d.writer_id, u.user_nm, d.write_dt, d.ver_no, d.retention_until,
           (SELECT count(*)::int FROM tbl_document_file f WHERE f.co_cd = d.co_cd AND f.doc_idx = d.idx),
           (SELECT count(*)::int FROM tbl_corrective_action ca
             WHERE ca.co_cd = d.co_cd AND ca.src_doc_idx = d.idx AND ca.status <> 'DONE'),
           a.result_cd, a.act_dt
      FROM tbl_document d
      JOIN tbl_document_approval a
        ON a.co_cd = d.co_cd AND a.doc_idx = d.idx
       AND a.approver_id = p_user_id
       AND a.result_cd IN ('A', 'R')
       -- 작성자 단계(WRITE)는 상신 때 자동 승인된다. 이력에 넣으면 작성자가 자기 미결 문서를 본다
       AND a.role_cd IN ('REVIEW', 'APPROVE')
      LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = d.co_cd AND ct.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_user u ON u.co_cd = d.co_cd AND u.user_id = d.writer_id
     WHERE d.co_cd = p_co_cd
       AND d.del_yn = 'N'
       AND (COALESCE(p_from_dt, '') = '' OR d.base_dt >= p_from_dt)
       AND (COALESCE(p_to_dt, '') = '' OR d.base_dt <= p_to_dt)
       AND (
           COALESCE(p_keyword, '') = ''
           OR d.doc_no ILIKE '%' || p_keyword || '%'
           OR COALESCE(d.title, '') ILIKE '%' || p_keyword || '%'
       )
     ORDER BY d.idx, a.act_dt DESC NULLS LAST;
$$;
COMMENT ON FUNCTION sp_tbl_document_appr_hist_r_000(varchar, varchar, varchar, varchar, varchar) IS
  '결재 이력 — 내가 승인·반려한 문서 (작성자 자동승인 제외)';

-- ------------------------------------------------------------
-- 3. 결재 전이 SP — 꺼 둔 결재선 단계를 넣지 않는다
--    본문은 33_migrate_cancel_before_review.sql 정본과 같고 단계 조회에 use_yn 조건만 더했다
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
    v_sign_path varchar(300);
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

    SELECT user_nm, sign_path INTO v_user_nm, v_sign_path
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
               -- 꺼 둔 단계(use_yn='N')는 결재선에 넣지 않는다.
               -- 이 조건이 없어서 기본 결재선의 검토(REVIEW, use_yn='N')가 그대로 들어갔다
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
               sign_path = v_sign_path,
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
           sign_path = v_sign_path,
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
COMMENT ON PROCEDURE sp_tbl_document_approval_c_000(varchar, bigint, varchar, varchar, varchar) IS
  '문서 결재 전이 — REQUEST/CANCEL/REVIEW/APPROVE/REJECT. 꺼 둔 결재선 단계는 제외 (128)';

-- ------------------------------------------------------------
-- 4. 이미 상신된 문서 중 꺼 둔 검토 단계가 박혀 있는 건을 정리한다
--    아직 아무도 검토하지 않은(W) 단계만 지운다 — 처리된 이력은 건드리지 않는다
-- ------------------------------------------------------------
DELETE FROM tbl_document_approval a
 USING tbl_approval_line_step s, tbl_document d
 WHERE d.co_cd = a.co_cd
   AND d.idx = a.doc_idx
   AND s.co_cd = a.co_cd
   AND s.appr_line_cd = COALESCE(d.appr_line_cd, 'DEFAULT')
   AND s.step_no = a.step_no
   AND COALESCE(s.use_yn, 'Y') = 'N'
   AND a.result_cd = 'W';

COMMIT;

-- 확인용
-- SELECT sub_cd, code_nm FROM tbl_code WHERE main_cd = 'DOC_STATUS' ORDER BY sort_no;
-- SELECT appr_line_cd, step_no, role_cd, use_yn FROM tbl_approval_line_step ORDER BY co_cd, step_no;
-- SELECT d.doc_no, d.status, a.step_no, a.role_cd, a.result_cd
--   FROM tbl_document d JOIN tbl_document_approval a ON a.doc_idx = d.idx
--  ORDER BY d.idx DESC, a.step_no;
