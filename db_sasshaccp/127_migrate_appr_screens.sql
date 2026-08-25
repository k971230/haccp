-- ============================================================
--  127_migrate_appr_screens.sql — 결재 3화면 (첨부·대기·완료)
--
--  파일번호: 127
--  이전번호: 126
--  개발자: 박승우
--  일자: 2026-08-25
--  코멘트:
--    1) 레거시 화면코드 개명 — approval-inbox → sign-ready · approval-history → sign-ok
--       화면·권한·메뉴·구코드 매핑을 같이 옮긴다. FK 가 없어 UPDATE 로 끝난다
--    2) 신규 화면 attach(결재 첨부) 등록 + tbl_document.remark(비고) 컬럼 1개 추가
--    3) 결재취소(UNDO) 전용 SP 신설 — 기존 전이 SP(sp_tbl_document_approval_c_000)는 손대지 않는다
--
--  첨부 잠금 기준(REQ·REV·APV 차단)은 그대로 둔다. 상신 뒤 기록물이 바뀌면
--  결재자가 본 것과 최종본이 달라져 감사에서 문제가 된다. 비고만 APV 직전까지 연다.
--
--  ※ 신규 회사 초기화 SP(sp_tbl_company_init_c_000)의 leaf 메뉴 표도 같이 고쳤다.
--    안 고치면 이 마이그레이션 뒤에 만든 회사가 구 화면코드 메뉴를 다시 받는다.
--    정본은 13_sp_platform.sql — **이 파일과 함께 13 을 다시 적용한다**.
--    실행: psql -f 13_sp_platform.sql ; psql -f 127_migrate_appr_screens.sql
--  (수동·DBeaver. Jenkins 는 마이그레이션을 돌리지 않는다)
-- ============================================================

SET search_path TO sasshaccp;

BEGIN;

-- ------------------------------------------------------------
-- 1. 화면코드 개명 — 구 approval-* 를 sign-* 로
--    tbl_screen.scrn_cd 는 UNIQUE 이고 FK 가 없다. 대상 코드가 이미 있으면 건너뛴다
-- ------------------------------------------------------------
UPDATE tbl_screen
   SET scrn_cd = 'sign-ready', scrn_nm = '결재 대기', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd = 'approval-inbox'
   AND NOT EXISTS (SELECT 1 FROM tbl_screen s WHERE s.scrn_cd = 'sign-ready');

UPDATE tbl_screen
   SET scrn_cd = 'sign-ok', scrn_nm = '결재 완료', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd = 'approval-history'
   AND NOT EXISTS (SELECT 1 FROM tbl_screen s WHERE s.scrn_cd = 'sign-ok');

-- 권한 행 — 사용자가 갖고 있던 읽기·쓰기 설정을 그대로 옮긴다
UPDATE tbl_role_screen
   SET scrn_cd = 'sign-ready', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd = 'approval-inbox'
   AND NOT EXISTS (
       SELECT 1 FROM tbl_role_screen r
        WHERE r.co_cd = tbl_role_screen.co_cd
          AND r.usrgrp_cd = tbl_role_screen.usrgrp_cd
          AND r.scrn_cd = 'sign-ready'
   );
UPDATE tbl_role_screen
   SET scrn_cd = 'sign-ok', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd = 'approval-history'
   AND NOT EXISTS (
       SELECT 1 FROM tbl_role_screen r
        WHERE r.co_cd = tbl_role_screen.co_cd
          AND r.usrgrp_cd = tbl_role_screen.usrgrp_cd
          AND r.scrn_cd = 'sign-ok'
   );
-- 개명에 실패한 중복 행(양쪽이 이미 있던 테넌트)만 정리한다
DELETE FROM tbl_role_screen WHERE scrn_cd IN ('approval-inbox', 'approval-history');

-- 메뉴 — leaf menu_cd 는 scrn_cd 와 같다 (URL = DB = 폴더 규칙)
UPDATE tbl_menu
   SET menu_cd = 'sign-ready', scrn_cd = 'sign-ready', menu_nm = '결재 대기',
       upd_id = 'system', upd_dt = now()
 WHERE scrn_cd = 'approval-inbox'
   AND NOT EXISTS (
       SELECT 1 FROM tbl_menu m WHERE m.co_cd = tbl_menu.co_cd AND m.menu_cd = 'sign-ready'
   );
UPDATE tbl_menu
   SET menu_cd = 'sign-ok', scrn_cd = 'sign-ok', menu_nm = '결재 완료',
       upd_id = 'system', upd_dt = now()
 WHERE scrn_cd = 'approval-history'
   AND NOT EXISTS (
       SELECT 1 FROM tbl_menu m WHERE m.co_cd = tbl_menu.co_cd AND m.menu_cd = 'sign-ok'
   );
DELETE FROM tbl_menu WHERE scrn_cd IN ('approval-inbox', 'approval-history');

-- 구 C# 화면코드(frmDOC0300)는 17 이 TEMP 표로만 쓰고 끝냈다 — 영속 매핑 표가 없어 옮길 대상이 없다

-- ------------------------------------------------------------
-- 2. 신규 화면 attach — 결재 첨부 (/flow/appr/attach)
-- ------------------------------------------------------------
INSERT INTO tbl_screen (scrn_cd, scrn_nm, module_cd, tmpl_cd, sort_no, use_yn, ins_id, ins_dt)
VALUES ('attach', '결재 첨부', 'DOC', NULL, 205, 'Y', 'system', now())
ON CONFLICT ON CONSTRAINT ux_tbl_screen_scrn_cd DO UPDATE
   SET scrn_nm = EXCLUDED.scrn_nm, use_yn = 'Y', upd_id = 'system', upd_dt = now();

-- 권한 — 결재 대기와 같은 그룹에 읽기·쓰기·수정·삭제를 준다(본인 문서 첨부 관리)
INSERT INTO tbl_role_screen (co_cd, usrgrp_cd, scrn_cd, read_yn, write_yn, modify_yn, delete_yn, print_yn, ins_id, ins_dt)
SELECT DISTINCT r.co_cd, r.usrgrp_cd, 'attach', 'Y', 'Y', 'Y', 'Y', 'Y', 'system', now()
  FROM tbl_role_screen r
 WHERE r.scrn_cd = 'sign-ready'
ON CONFLICT ON CONSTRAINT ux_tbl_role_screen DO NOTHING;

-- 메뉴 leaf — 중분류는 결재 대기와 같은 부모(menu-flow-appr)를 쓴다
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
-- 테넌트당 1행만 만든다 — ON CONFLICT DO UPDATE 는 같은 키를 두 번 건드리면 실패한다
SELECT m.co_cd, 'attach', '결재 첨부', min(m.h_menu_cd), 'attach', 205, 'Y', 'system', now()
  FROM tbl_menu m
 WHERE m.scrn_cd = 'sign-ready'
 GROUP BY m.co_cd
ON CONFLICT ON CONSTRAINT ux_tbl_menu_co_menu DO UPDATE
   SET menu_nm = EXCLUDED.menu_nm, scrn_cd = 'attach', use_yn = 'Y',
       upd_id = 'system', upd_dt = now();

-- ------------------------------------------------------------
-- 3. 비고 컬럼 — 문서 단위 메모. 결재 의견(opinion)과 다른 축이다
-- ------------------------------------------------------------
ALTER TABLE tbl_document ADD COLUMN IF NOT EXISTS remark varchar(500) NULL;
COMMENT ON COLUMN tbl_document.remark IS
    '비고 — 상신자가 결재자에게 남기는 문서 단위 메모. 결재완료(APV) 전까지만 수정 가능';

-- ------------------------------------------------------------
-- 4. 결재 행위 공통코드 — 결재취소 추가
-- ------------------------------------------------------------
INSERT INTO tbl_code (co_cd, main_cd, sub_cd, code_nm, sort_no, ref1, use_yn, ins_id)
VALUES ('0000', 'APPR_ACTION', 'UNDO', '결재취소', 6, NULL, 'Y', 'system')
ON CONFLICT ON CONSTRAINT ux_tbl_code DO UPDATE
   SET code_nm = EXCLUDED.code_nm, use_yn = 'Y', upd_id = 'system', upd_dt = now();

-- ------------------------------------------------------------
-- 5. 문서 헤더 단건 — 비고를 응답에 싣는다 (반환 타입이 바뀌어 DROP 후 재생성)
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_document_r_001(varchar, bigint);

CREATE FUNCTION sp_tbl_document_r_001(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_doc_idx: 문서 idx
    p_doc_idx bigint
)
RETURNS TABLE (
    doc_idx bigint,
    co_cd varchar,
    tmpl_cd varchar,
    tmpl_nm varchar,
    doc_kind varchar,
    doc_no varchar,
    base_dt varchar,
    base_dt_to varchar,
    title varchar,
    status varchar,
    appr_line_cd varchar,
    writer_id varchar,
    writer_nm varchar,
    write_dt timestamp,
    reviewer_id varchar,
    reviewer_nm varchar,
    review_dt timestamp,
    approver_id varchar,
    approver_nm varchar,
    approve_dt timestamp,
    reject_reason varchar,
    ver_no int,
    retention_until varchar,
    remark varchar
)
LANGUAGE sql STABLE AS $$
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
           d.reviewer_id,
           ru.user_nm AS reviewer_nm,
           d.review_dt,
           d.approver_id,
           au.user_nm AS approver_nm,
           d.approve_dt,
           d.reject_reason,
           d.ver_no,
           d.retention_until,
           d.remark
      FROM tbl_document d
      LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_company_template ct
        ON ct.co_cd = d.co_cd AND ct.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_user wu ON wu.co_cd = d.co_cd AND wu.user_id = d.writer_id
      LEFT JOIN tbl_user ru ON ru.co_cd = d.co_cd AND ru.user_id = d.reviewer_id
      LEFT JOIN tbl_user au ON au.co_cd = d.co_cd AND au.user_id = d.approver_id
     WHERE d.co_cd = p_co_cd
       AND d.idx = p_doc_idx
       AND d.del_yn = 'N';
$$;
COMMENT ON FUNCTION sp_tbl_document_r_001(varchar, bigint) IS '문서 공통 헤더 단건 — 문서함 상세·결재 패널·결재 첨부';

-- ------------------------------------------------------------
-- 6. 비고 저장 — 작성자 본인만, 결재완료 전까지
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_document_u_001(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_doc_idx: 문서 idx
    p_doc_idx bigint,
    -- p_remark: 비고 본문. 공백이면 지운다
    p_remark varchar,
    -- p_id: 현재 로그인 사용자 ID
    p_id varchar
)
LANGUAGE plpgsql AS $$
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
COMMENT ON PROCEDURE sp_tbl_document_u_001(varchar, bigint, varchar, varchar) IS
    '문서 비고 저장 — 결재 첨부 화면. 작성자 본인·결재완료 전까지';

-- ------------------------------------------------------------
-- 7. 첨부 등록 — 사용자 첨부 5개 상한 추가 (잠금 조건은 기존 그대로)
--    HWP_SRC(본문)·PDF(완료본)는 시스템이 만드는 파일이라 세지 않는다
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_document_file_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_doc_idx: 파일을 붙일 문서 idx
    p_doc_idx bigint,
    -- p_file_kind: HWP_SRC/PDF/ATTACH/PHOTO
    p_file_kind varchar,
    -- p_file_nm: 사용자에게 보여줄 원본 파일명
    p_file_nm varchar,
    -- p_file_path: 서버 저장 상대 경로
    p_file_path varchar,
    -- p_file_size: 파일 크기 byte
    p_file_size bigint,
    -- p_mime_type: MIME 타입
    p_mime_type varchar,
    -- p_id: 업로더 로그인 ID
    p_id varchar
)
RETURNS bigint
LANGUAGE plpgsql AS $$
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
    -- 결재 진행·완료일 때(= 기록 잠금) 첨부 교체 차단
    IF v_status IN ('REQ', 'REV', 'APV') THEN
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
COMMENT ON FUNCTION sp_tbl_document_file_c_000(varchar, bigint, varchar, varchar, varchar, bigint, varchar, varchar) IS
    '문서 파일 메타 등록 — 물리 저장 완료 후 호출. 사용자 첨부는 문서당 5개';

-- ------------------------------------------------------------
-- 8. 결재취소 — 본인이 처리한 마지막 단계를 되돌린다
--    전이 SP(sp_tbl_document_approval_c_000)는 손대지 않는다. 되돌리기는 검증 규칙이 다르다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_document_approval_u_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_doc_idx: 대상 문서 idx
    p_doc_idx bigint,
    -- p_id: 현재 로그인 사용자 ID — 본인이 찍은 결재만 되돌린다
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_status varchar(3);
    v_line varchar(20);
    v_ver int;
    v_step record;
    v_reviewed boolean;
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

    -- 본인이 처리한 검토·승인 단계 중 가장 마지막 한 건
    SELECT * INTO v_step
      FROM tbl_document_approval
     WHERE co_cd = p_co_cd
       AND doc_idx = p_doc_idx
       AND role_cd IN ('REVIEW', 'APPROVE')
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
           sign_path = NULL,
           upd_id = p_id,
           upd_dt = now()
     WHERE a.idx = v_step.idx
       AND a.co_cd = p_co_cd;

    -- 되돌린 뒤 검토 단계가 아직 승인 상태로 남아 있는지 — 문서 상태를 여기서 정한다
    SELECT EXISTS (
        SELECT 1 FROM tbl_document_approval
         WHERE co_cd = p_co_cd
           AND doc_idx = p_doc_idx
           AND role_cd = 'REVIEW'
           AND result_cd = 'A'
    ) INTO v_reviewed;

    IF v_step.role_cd = 'APPROVE' THEN
        -- 승인을 되돌린다 — 검토가 남아 있으면 검토완료, 아니면 검토요청으로
        UPDATE tbl_document
           SET status = CASE WHEN v_reviewed THEN 'REV' ELSE 'REQ' END,
               approver_id = NULL,
               approve_dt = NULL,
               reject_reason = NULL,
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
    ELSE
        -- 검토를 되돌린다 — 상신 직후 상태로
        UPDATE tbl_document
           SET status = 'REQ',
               reviewer_id = NULL,
               review_dt = NULL,
               reject_reason = NULL,
               upd_id = p_id,
               upd_dt = now()
         WHERE idx = p_doc_idx
           AND co_cd = p_co_cd;
    END IF;
END$$;
COMMENT ON PROCEDURE sp_tbl_document_approval_u_000(varchar, bigint, varchar) IS
    '결재취소 — 본인이 처리한 마지막 단계를 되돌린다. 다음 결재자가 처리했으면 차단';

-- ------------------------------------------------------------
-- 9. 메뉴 정렬 코드 재계산 — 125 와 같은 마무리
-- ------------------------------------------------------------
CALL sp_tbl_menu_sort_encode_u_000(NULL);

COMMIT;

-- 확인용
-- SELECT scrn_cd, scrn_nm, use_yn FROM tbl_screen WHERE scrn_cd IN ('attach','sign-ready','sign-ok');
-- SELECT co_cd, menu_cd, h_menu_cd, scrn_cd, sort_no FROM tbl_menu WHERE scrn_cd IN ('attach','sign-ready','sign-ok') ORDER BY co_cd, sort_no;
-- SELECT co_cd, usrgrp_cd, scrn_cd, read_yn, write_yn FROM tbl_role_screen WHERE scrn_cd IN ('attach','sign-ready','sign-ok');
-- SELECT column_name FROM information_schema.columns WHERE table_name = 'tbl_document' AND column_name = 'remark';
