-- ============================================================
--  SP 5 — 문서 허브·결재·첨부·버전
--
--  개발자: 박승우
--  일자: 2026-08-06
--  코멘트:
--    1) DB형·HWP형 양식이 함께 쓰는 문서 목록·결재·파일·버전 처리 절차다
--    2) 모든 조회·변경은 p_co_cd를 선두 인자로 받아 테넌트 경계를 SP에서 고정한다
--    3) 승인 완료 문서는 수정·삭제를 막고, 결재 단계·파일·감사 추적은 문서 idx로 연결한다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. sp_tbl_document_r_000 — 문서함 목록·검색
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_document_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_from_dt: 기준일 시작 YYYYMMDD. 공백이면 하한 없음
    p_from_dt varchar,
    -- p_to_dt: 기준일 종료 YYYYMMDD. 공백이면 상한 없음
    p_to_dt varchar,
    -- p_tmpl_cd: 템플릿 코드 필터. 공백이면 전체
    p_tmpl_cd varchar,
    -- p_status: 문서 상태 필터. 공백이면 전체
    p_status varchar,
    -- p_keyword: 문서번호·제목 부분검색어. 공백이면 전체
    p_keyword varchar,
    -- p_writer_id: 작성자 ID 필터. 공백이면 전체
    p_writer_id varchar
)
RETURNS TABLE (
    doc_idx bigint,
    co_cd varchar,
    tmpl_cd varchar,
    tmpl_nm varchar,
    doc_kind varchar,
    doc_no varchar,
    base_dt varchar,
    title varchar,
    status varchar,
    appr_line_cd varchar,
    writer_id varchar,
    writer_nm varchar,
    write_dt timestamp,
    ver_no int,
    retention_until varchar,
    file_cnt int,
    open_ca_cnt int
)
LANGUAGE sql STABLE AS $$
    SELECT d.idx AS doc_idx,
           d.co_cd,
           d.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm, d.tmpl_cd) AS tmpl_nm,
           d.doc_kind,
           d.doc_no,
           d.base_dt,
           d.title,
           d.status,
           d.appr_line_cd,
           d.writer_id,
           u.user_nm AS writer_nm,
           d.write_dt,
           d.ver_no,
           d.retention_until,
           (SELECT count(*)::int
              FROM tbl_document_file f
             WHERE f.co_cd = d.co_cd AND f.doc_idx = d.idx) AS file_cnt,
           (SELECT count(*)::int
              FROM tbl_corrective_action ca
             WHERE ca.co_cd = d.co_cd
               AND ca.src_doc_idx = d.idx
               AND ca.status <> 'DONE') AS open_ca_cnt
      FROM tbl_document d
      LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_company_template ct
        ON ct.co_cd = d.co_cd AND ct.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_user u ON u.co_cd = d.co_cd AND u.user_id = d.writer_id
     WHERE d.co_cd = p_co_cd
       AND d.del_yn = 'N'
       AND (COALESCE(p_from_dt, '') = '' OR d.base_dt >= p_from_dt)
       AND (COALESCE(p_to_dt, '') = '' OR d.base_dt <= p_to_dt)
       AND (COALESCE(p_tmpl_cd, '') = '' OR d.tmpl_cd = p_tmpl_cd)
       AND (COALESCE(p_status, '') = '' OR d.status = p_status)
       AND (COALESCE(p_writer_id, '') = '' OR d.writer_id = p_writer_id)
       AND (
           COALESCE(p_keyword, '') = ''
           OR d.doc_no ILIKE '%' || p_keyword || '%'
           OR COALESCE(d.title, '') ILIKE '%' || p_keyword || '%'
       )
     ORDER BY d.base_dt DESC, d.idx DESC;
$$;
COMMENT ON FUNCTION sp_tbl_document_r_000(varchar, varchar, varchar, varchar, varchar, varchar, varchar) IS '문서함 목록·검색 — DB형·HWP형 통합';

-- ------------------------------------------------------------
-- 2. sp_tbl_document_r_001 — 문서 공통 헤더 단건
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_document_r_001(
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
    retention_until varchar
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
           d.retention_until
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
COMMENT ON FUNCTION sp_tbl_document_r_001(varchar, bigint) IS '문서 공통 헤더 단건 — 문서함 상세·결재 패널';

-- ------------------------------------------------------------
-- 3. sp_tbl_document_approval_r_000 — 결재 단계 목록
-- ------------------------------------------------------------
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
    sign_path varchar
)
LANGUAGE sql STABLE AS $$
    SELECT a.idx, a.doc_idx, a.step_no, a.role_cd, a.approver_id,
           COALESCE(a.approver_nm, u.user_nm) AS approver_nm,
           a.result_cd, a.opinion, a.act_dt, a.sign_path
      FROM tbl_document_approval a
      LEFT JOIN tbl_user u ON u.co_cd = a.co_cd AND u.user_id = a.approver_id
     WHERE a.co_cd = p_co_cd
       AND a.doc_idx = p_doc_idx
     ORDER BY a.step_no;
$$;
COMMENT ON FUNCTION sp_tbl_document_approval_r_000(varchar, bigint) IS '문서 결재 단계 조회 — 작성·검토·승인 서명란';

-- ------------------------------------------------------------
-- 4. sp_tbl_document_file_r_000 — 문서 첨부 목록
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_document_file_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_doc_idx: 문서 idx
    p_doc_idx bigint
)
RETURNS TABLE (
    idx bigint,
    doc_idx bigint,
    file_kind varchar,
    file_nm varchar,
    file_path varchar,
    file_size bigint,
    mime_type varchar,
    sort_no int,
    ins_id varchar,
    ins_dt timestamp
)
LANGUAGE sql STABLE AS $$
    SELECT f.idx, f.doc_idx, f.file_kind, f.file_nm, f.file_path, f.file_size,
           f.mime_type, f.sort_no, f.ins_id, f.ins_dt
      FROM tbl_document_file f
     WHERE f.co_cd = p_co_cd
       AND f.doc_idx = p_doc_idx
     ORDER BY f.sort_no, f.idx;
$$;
COMMENT ON FUNCTION sp_tbl_document_file_r_000(varchar, bigint) IS '문서 첨부 목록 — HWPX·PDF·사진·일반파일';

-- ------------------------------------------------------------
-- 5. sp_tbl_document_file_r_001 — 파일 단건(다운로드·삭제 물리 경로)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_document_file_r_001(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_file_idx: 파일 idx
    p_file_idx bigint
)
RETURNS TABLE (
    idx bigint,
    doc_idx bigint,
    file_kind varchar,
    file_nm varchar,
    file_path varchar,
    file_size bigint,
    mime_type varchar,
    sort_no int,
    ins_id varchar,
    ins_dt timestamp
)
LANGUAGE sql STABLE AS $$
    SELECT f.idx, f.doc_idx, f.file_kind, f.file_nm, f.file_path, f.file_size,
           f.mime_type, f.sort_no, f.ins_id, f.ins_dt
      FROM tbl_document_file f
      JOIN tbl_document d ON d.idx = f.doc_idx AND d.co_cd = f.co_cd
     WHERE f.co_cd = p_co_cd
       AND f.idx = p_file_idx
       AND d.del_yn = 'N';
$$;
COMMENT ON FUNCTION sp_tbl_document_file_r_001(varchar, bigint) IS '문서 파일 단건 — 다운로드·물리 삭제 전 테넌트 확인';

-- ------------------------------------------------------------
-- 6. sp_tbl_document_version_r_000 — 문서 버전 목록
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_document_version_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_doc_idx: 문서 idx
    p_doc_idx bigint
)
RETURNS TABLE (
    idx bigint,
    doc_idx bigint,
    ver_no int,
    file_path varchar,
    change_reason varchar,
    ins_id varchar,
    ins_dt timestamp
)
LANGUAGE sql STABLE AS $$
    SELECT v.idx, v.doc_idx, v.ver_no, v.file_path, v.change_reason, v.ins_id, v.ins_dt
      FROM tbl_document_version v
     WHERE v.co_cd = p_co_cd
       AND v.doc_idx = p_doc_idx
     ORDER BY v.ver_no DESC;
$$;
COMMENT ON FUNCTION sp_tbl_document_version_r_000(varchar, bigint) IS '문서 버전 목록 — 승인 문서 변경 전 스냅샷';

-- ------------------------------------------------------------
-- 6. sp_tbl_document_file_c_000 — 파일 메타 등록
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
COMMENT ON FUNCTION sp_tbl_document_file_c_000(varchar, bigint, varchar, varchar, varchar, bigint, varchar, varchar) IS '문서 파일 메타 등록 — 물리 저장 완료 후 호출';

-- ------------------------------------------------------------
-- 7. sp_tbl_document_file_d_000 — 파일 메타 삭제
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_document_file_d_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_file_idx: 삭제할 파일 idx
    p_file_idx bigint,
    -- p_id: 작업자 로그인 ID. 감사 연결용
    p_id varchar
)
LANGUAGE plpgsql AS $$
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
    IF v_status IN ('REQ', 'REV', 'APV') THEN
        RAISE EXCEPTION '결재 진행 중이거나 완료된 문서의 파일은 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    DELETE FROM tbl_document_file
     WHERE idx = p_file_idx
       AND co_cd = p_co_cd;
END$$;
COMMENT ON PROCEDURE sp_tbl_document_file_d_000(varchar, bigint, varchar) IS '문서 파일 메타 삭제 — 물리 파일 제거 전 잠금 검사';

-- ------------------------------------------------------------
-- 7-1. sp_tbl_document_file_d_001 — 문서·종류별 파일 메타 일괄 삭제 (HWP_SRC 교체용)
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_document_file_d_001(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_doc_idx: 대상 문서 idx
    p_doc_idx bigint,
    -- p_file_kind: HWP_SRC 등 삭제할 파일 종류
    p_file_kind varchar,
    -- p_id: 작업자 로그인 ID
    p_id varchar
)
LANGUAGE plpgsql AS $$
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
    -- 결재 진행·완료일 때(= 기록 잠금) 첨부 삭제 차단
    IF v_status IN ('REQ', 'REV', 'APV') THEN
        RAISE EXCEPTION '결재 진행 중이거나 완료된 문서의 파일은 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    DELETE FROM tbl_document_file
     WHERE co_cd = p_co_cd
       AND doc_idx = p_doc_idx
       AND upper(file_kind) = upper(trim(p_file_kind));
END$$;
COMMENT ON PROCEDURE sp_tbl_document_file_d_001(varchar, bigint, varchar, varchar) IS '문서·파일종류별 메타 일괄 삭제 — HWP_SRC 덮어쓰기 전 호출';

-- ------------------------------------------------------------
-- 8. sp_tbl_document_d_000 — 문서형(HWP) 임시·반려 문서 삭제
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_document_d_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_doc_idx: 삭제할 문서 idx
    p_doc_idx bigint,
    -- p_id: 작업자 로그인 ID
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_status varchar(3);
    v_kind varchar(3);
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
    -- DB형일 때(= 업무 헤더·상세가 연결됨) 전용 양식 삭제 SP로만 처리한다
    IF v_kind <> 'HWP' THEN
        RAISE EXCEPTION 'DB형 문서는 해당 양식 화면에서 삭제하세요.' USING ERRCODE = '45000';
    END IF;
    -- 임시·반려가 아닐 때(= 결재 흐름 또는 보존 대상) 삭제 차단
    IF v_status NOT IN ('WRK', 'RJT') THEN
        RAISE EXCEPTION '결재 진행 중이거나 완료된 문서는 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    DELETE FROM tbl_document_relation
     WHERE co_cd = p_co_cd
       AND (src_doc_idx = p_doc_idx OR tgt_doc_idx = p_doc_idx);
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
COMMENT ON PROCEDURE sp_tbl_document_d_000(varchar, bigint, varchar) IS '문서형 작성중·반려 문서 삭제 — 첨부·결재·버전·관계 일괄 제거';

-- ------------------------------------------------------------
-- 9. sp_tbl_hwp_document_c_000 — HWP 문서형 공통 헤더 저장
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_hwp_document_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_doc_idx: 기존 문서 idx. NULL/0이면 신규
    p_doc_idx bigint,
    -- p_tmpl_cd: HWP 표준 템플릿 코드
    p_tmpl_cd varchar,
    -- p_base_dt: 기준일 YYYYMMDD
    p_base_dt varchar,
    -- p_base_dt_to: 기간 문서 종료일 YYYYMMDD. 없으면 공백
    p_base_dt_to varchar,
    -- p_title: 사용자 제목. 공백이면 템플릿명+기준일 자동 생성
    p_title varchar,
    -- p_id: JWT 작성자 ID
    p_id varchar
)
RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE
    v_idx bigint;
    v_tmpl_nm varchar(200);
    v_doc_kind varchar(3);
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
       AND t.use_yn = 'Y';

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
               title = COALESCE(NULLIF(trim(p_title), ''), v_tmpl_nm || ' (' || to_char(to_date(p_base_dt, 'YYYYMMDD'), 'YYYY-MM-DD') || ')'),
               upd_id = p_id,
               upd_dt = now()
         WHERE idx = v_idx
           AND co_cd = p_co_cd;
    END IF;

    RETURN v_idx;
END$$;
COMMENT ON FUNCTION sp_tbl_hwp_document_c_000(varchar, bigint, varchar, varchar, varchar, varchar, varchar) IS 'HWP 문서형 공통 헤더 신규·수정 — 문서번호·보존기간 자동 설정';

-- ------------------------------------------------------------
-- 10. sp_tbl_document_approval_c_000 — 상신·검토·승인·반려
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
COMMENT ON PROCEDURE sp_tbl_document_approval_c_000(varchar, bigint, varchar, varchar, varchar) IS '문서 결재 처리 — 상신·상신취소·검토·승인·반려·결재선 스냅샷';

-- 표준양식 목록 — 회사에서 사용으로 설정한 원본만 rhwp 편집기에 노출
CREATE OR REPLACE FUNCTION sp_tbl_document_template_r_000(
    -- p_co_cd: JWT 회사코드 — 회사별 사용 양식만 반환
    p_co_cd varchar
)
RETURNS TABLE(
    tmpl_cd varchar,
    tmpl_nm varchar,
    doc_kind varchar,
    category_cd varchar,
    mng_no varchar,
    form_path varchar,
    form_file_nm varchar
) LANGUAGE sql AS $$
    SELECT t.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm),
           t.doc_kind,
           t.category_cd,
           t.mng_no,
           t.form_path,
           regexp_replace(t.form_path, '^.*/', '')
      FROM tbl_template t
      JOIN tbl_company_template ct
        ON ct.co_cd = p_co_cd
       AND ct.tmpl_cd = t.tmpl_cd
     WHERE t.impl_yn = 'Y'
       AND t.use_yn = 'Y'
       AND ct.use_yn = 'Y'
       AND t.form_path IS NOT NULL
     ORDER BY t.sort_no, t.tmpl_cd;
$$;
COMMENT ON FUNCTION sp_tbl_document_template_r_000(varchar) IS '회사 사용양식 목록 — 표준 HWP 원본의 내부 경로 포함';

-- 표준양식 원본 단건 — 스트림 다운로드 전에 회사 사용여부를 확인
CREATE OR REPLACE FUNCTION sp_tbl_document_template_r_001(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_tmpl_cd: 표준 템플릿 코드
    p_tmpl_cd varchar
)
RETURNS TABLE(
    tmpl_cd varchar,
    tmpl_nm varchar,
    doc_kind varchar,
    form_path varchar,
    form_file_nm varchar
) LANGUAGE sql AS $$
    SELECT t.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm),
           t.doc_kind,
           t.form_path,
           regexp_replace(t.form_path, '^.*/', '')
      FROM tbl_template t
      JOIN tbl_company_template ct
        ON ct.co_cd = p_co_cd
       AND ct.tmpl_cd = t.tmpl_cd
     WHERE t.tmpl_cd = p_tmpl_cd
       AND t.impl_yn = 'Y'
       AND t.use_yn = 'Y'
       AND ct.use_yn = 'Y'
       AND t.form_path IS NOT NULL;
$$;
COMMENT ON FUNCTION sp_tbl_document_template_r_001(varchar, varchar) IS '표준양식 원본 단건 — 회사 사용여부를 확인한 뒤 내부 경로 반환';
