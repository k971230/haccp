-- ============================================================
-- 97 — 결재선 단계 사용여부 · 시스템 메뉴 이동 · 상신 시 미사용 단계 생략
--
-- 파일번호: 97
-- 이전번호: 96
-- 개발자: 박승우
-- 일자: 2026-08-19
-- 코멘트:
--   1) 결재 단계에 use_yn을 둔다. 검토(REVIEW) 기본은 사용안함
--   2) 결재선 관리 메뉴를 문서기준관리에서 시스템(권한·사용자·코드) 아래로 옮긴다
--   3) 상신은 사용(Y) 단계만 스냅샷한다. URL(scrn_cd)은 바꾸지 않는다
--
-- Jenkins는 migrate를 안 돌린다. 운영은 DBeaver/수동. 78 결재 SP는 재실행하지 않는다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 단계 사용여부 — 기본 Y. 기존 검토 행은 사용안함으로 맞춘다
-- ------------------------------------------------------------
ALTER TABLE tbl_approval_line_step
    ADD COLUMN IF NOT EXISTS use_yn varchar(1) NOT NULL DEFAULT 'Y';
COMMENT ON COLUMN tbl_approval_line_step.use_yn IS '단계 사용여부 Y/N — N이면 상신 스냅샷에서 빠진다';

UPDATE tbl_approval_line_step
   SET use_yn = 'N',
       upd_id = COALESCE(upd_id, 'system'),
       upd_dt = now()
 WHERE role_cd = 'REVIEW'
   AND COALESCE(use_yn, 'Y') <> 'N';

-- ------------------------------------------------------------
-- 2. 결재선 조회 — 결재자명·부서명·단계 사용여부
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_approval_line_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar
)
RETURNS TABLE(payload jsonb)
LANGUAGE sql STABLE AS $$
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
COMMENT ON FUNCTION sp_tbl_approval_line_r_000(varchar) IS
  '결재선·단계 조회 — 결재자명·부서명·단계 사용여부 포함';

-- ------------------------------------------------------------
-- 3. 결재선 저장 — 단계 use_yn. 직위코드는 받지 않는다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_approval_line_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_payload: apprLineCd·apprLineNm·useYn·steps[]
    p_payload jsonb,
    -- p_id: JWT 작업자 ID
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_cd varchar(20) := trim(COALESCE(p_payload ->> 'apprLineCd', ''));
    v_nm varchar(100) := trim(COALESCE(p_payload ->> 'apprLineNm', ''));
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
           OR v_role NOT IN ('WRITE', 'REVIEW', 'APPROVE') THEN
            RAISE EXCEPTION '결재 단계 순번 또는 역할이 올바르지 않습니다.' USING ERRCODE = '45000';
        END IF;
        -- 작성·승인은 항상 사용. 검토만 사용안함을 허용한다
        v_use := CASE
            WHEN v_role = 'REVIEW' AND upper(COALESCE(v_step ->> 'useYn', 'N')) = 'N' THEN 'N'
            ELSE 'Y'
        END;
        INSERT INTO tbl_approval_line_step(
            co_cd, appr_line_cd, step_no, role_cd, approver_id, dept_cd, pos_cd, use_yn, ins_id, ins_dt
        ) VALUES (
            p_co_cd, v_cd, v_step_no, v_role,
            NULLIF(v_step ->> 'approverId', ''), NULLIF(v_step ->> 'deptCd', ''),
            NULL, v_use, p_id, now()
        );
    END LOOP;
END$$;
COMMENT ON PROCEDURE sp_tbl_approval_line_c_000(varchar, jsonb, varchar) IS
  '결재선 저장 — 헤더+단계 교체. 검토만 사용안함 가능, 직위코드 미저장';

-- ------------------------------------------------------------
-- 4. 삭제 차단 조회 — sys 매퍼는 SP만 호출한다
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_approval_line_delete_blocker_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_appr_line_cd: 삭제 대상 결재선 코드
    p_appr_line_cd varchar
)
RETURNS TABLE(ref_key varchar, target varchar)
LANGUAGE sql STABLE AS $$
    SELECT p_appr_line_cd, '사용양식 또는 문서'::varchar
     WHERE EXISTS (
        SELECT 1 FROM tbl_company_template
         WHERE co_cd = p_co_cd AND appr_line_cd = p_appr_line_cd
     ) OR EXISTS (
        SELECT 1 FROM tbl_document
         WHERE co_cd = p_co_cd AND appr_line_cd = p_appr_line_cd AND del_yn = 'N'
     );
$$;
COMMENT ON FUNCTION sp_tbl_approval_line_delete_blocker_r_000(varchar, varchar) IS
  '결재선 삭제 차단 — 사용양식·문서 참조 시 1행';

-- ------------------------------------------------------------
-- 5. 상신 스냅샷 — 사용(Y) 단계만 (78 정본 + use_yn 필터)
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
               -- 사용안함(N) 단계는 상신 스냅샷에 넣지 않는다(검토 기본 미사용)
               AND upper(COALESCE(use_yn, 'Y')) = 'Y'
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

-- ------------------------------------------------------------
-- 6. 메뉴 — 결재선을 시스템 권한·사용자·코드 아래로. 빈 중분류는 숨긴다
-- ------------------------------------------------------------
UPDATE tbl_menu m
   SET h_menu_cd = 'menu-sys-auth',
       sort_no = 960,
       upd_id = 'system',
       upd_dt = now()
 WHERE m.scrn_cd = 'approval-line-management'
   AND COALESCE(m.h_menu_cd, '') <> 'menu-sys-auth';

UPDATE tbl_menu m
   SET use_yn = 'N',
       upd_id = 'system',
       upd_dt = now()
 WHERE m.menu_cd = 'menu-master-appr'
   AND NOT EXISTS (
        SELECT 1 FROM tbl_menu c
         WHERE c.co_cd = m.co_cd
           AND c.h_menu_cd = 'menu-master-appr'
           AND c.use_yn = 'Y'
   );

DO $$
DECLARE
    r record;
BEGIN
    FOR r IN SELECT DISTINCT co_cd FROM tbl_menu
    LOOP
        CALL sp_tbl_menu_sort_encode_u_000(r.co_cd);
    END LOOP;
END$$;
