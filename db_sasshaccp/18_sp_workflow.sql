-- ============================================================
--  SP 7 — 결재선·업체 양식·작성주기 관리
--
--  개발자: 박승우
--  일자: 2026-08-06
--  코멘트:
--    1) 역할 기반 관리 화면이 tbl_approval_line, tbl_company_template, tbl_schedule_rule을 안전하게 관리한다
--    2) 표준 양식·점검항목은 수정하지 않고 업체별 오버라이드만 저장해 자유 양식 빌더를 만들지 않는다
--    3) 모든 수정·삭제는 p_co_cd 조건과 업무 참조 검사를 저장프로시저에서 함께 수행한다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. sp_tbl_approval_line_r_000 — 결재선과 단계 목록
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
                'idx', s.idx, 'stepNo', s.step_no, 'roleCd', s.role_cd,
                'approverId', s.approver_id, 'deptCd', s.dept_cd, 'posCd', s.pos_cd
            ) ORDER BY s.step_no)
              FROM tbl_approval_line_step s
             WHERE s.co_cd = l.co_cd AND s.appr_line_cd = l.appr_line_cd
        ), '[]'::jsonb)
    )
      FROM tbl_approval_line l
     WHERE l.co_cd = p_co_cd
     ORDER BY l.appr_line_cd;
$$;
COMMENT ON FUNCTION sp_tbl_approval_line_r_000(varchar) IS '결재선·단계 조회 — 결재선 관리 화면의 편집 원천';

-- ------------------------------------------------------------
-- 2. sp_tbl_approval_line_c_000 — 결재선 헤더·단계 저장
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_approval_line_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_payload: apprLineCd·apprLineNm·useYn·steps를 담은 JSON
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
        IF v_step_no IS NULL OR v_step_no < 1
           OR COALESCE(v_step ->> 'roleCd', '') NOT IN ('WRITE', 'REVIEW', 'APPROVE') THEN
            RAISE EXCEPTION '결재 단계 순번 또는 역할이 올바르지 않습니다.' USING ERRCODE = '45000';
        END IF;
        INSERT INTO tbl_approval_line_step(
            co_cd, appr_line_cd, step_no, role_cd, approver_id, dept_cd, pos_cd, ins_id, ins_dt
        ) VALUES (
            p_co_cd, v_cd, v_step_no, v_step ->> 'roleCd',
            NULLIF(v_step ->> 'approverId', ''), NULLIF(v_step ->> 'deptCd', ''),
            NULLIF(v_step ->> 'posCd', ''), p_id, now()
        );
    END LOOP;
END$$;
COMMENT ON PROCEDURE sp_tbl_approval_line_c_000(varchar, jsonb, varchar) IS '결재선 저장 — 헤더와 단계 전체를 같은 트랜잭션에서 교체';

-- ------------------------------------------------------------
-- 3. sp_tbl_approval_line_d_000 — 미참조 결재선 삭제
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_approval_line_d_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_appr_line_cd: 삭제할 결재선 코드
    p_appr_line_cd varchar,
    -- p_id: JWT 작업자 ID — 감사 호환용
    p_id varchar
)
LANGUAGE plpgsql AS $$
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
COMMENT ON PROCEDURE sp_tbl_approval_line_d_000(varchar, varchar, varchar) IS '결재선 삭제 — 양식·문서 참조가 없을 때만 단계와 함께 제거';

-- ------------------------------------------------------------
-- 4. sp_tbl_company_check_item_manage_r_000 — 숨김 항목 포함 관리 목록
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_company_check_item_manage_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_tmpl_cd: 양식 코드
    p_tmpl_cd varchar
)
RETURNS TABLE(
    tmpl_cd varchar, item_cd varchar, grp_nm varchar, item_nm varchar,
    item_nm_ovr varchar, sort_no int, use_yn varchar
)
LANGUAGE sql STABLE AS $$
    SELECT * FROM (
        SELECT ci.tmpl_cd, ci.item_cd, ci.grp_nm, ci.item_nm, cci.item_nm_ovr,
               COALESCE(cci.sort_no, ci.sort_no) AS sort_no, COALESCE(cci.use_yn, 'Y') AS use_yn
          FROM tbl_check_item ci
          LEFT JOIN tbl_company_check_item cci
                 ON cci.co_cd = p_co_cd AND cci.tmpl_cd = ci.tmpl_cd AND cci.item_cd = ci.item_cd
         WHERE ci.tmpl_cd = p_tmpl_cd
        UNION ALL
        SELECT cci.tmpl_cd, cci.item_cd, NULL::varchar, COALESCE(cci.item_nm_ovr, cci.item_cd),
               cci.item_nm_ovr, COALESCE(cci.sort_no, 0), COALESCE(cci.use_yn, 'Y')
          FROM tbl_company_check_item cci
         WHERE cci.co_cd = p_co_cd
           AND cci.tmpl_cd = p_tmpl_cd
           AND cci.item_cd LIKE 'CUST%'
           AND NOT EXISTS (
               SELECT 1 FROM tbl_check_item s
                WHERE s.tmpl_cd = cci.tmpl_cd AND s.item_cd = cci.item_cd
           )
    ) q
    ORDER BY q.sort_no, q.item_cd;
$$;
COMMENT ON FUNCTION sp_tbl_company_check_item_manage_r_000(varchar, varchar) IS
'업체 점검항목 관리 조회 — 표준+숨김+회사 CUST 전용';

-- ------------------------------------------------------------
-- 5. sp_tbl_schedule_rule_r_000 / c_000 / d_000 — 작성주기
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_schedule_rule_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar
)
RETURNS TABLE(
    idx bigint, tmpl_cd varchar, tmpl_nm varchar, rule_seq int, cycle_cd varchar,
    week_days varchar, month_day int, month_no int, due_time varchar,
    dept_cd varchar, user_id varchar, use_yn varchar
)
LANGUAGE sql STABLE AS $$
    SELECT r.idx, r.tmpl_cd, COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm), r.rule_seq, r.cycle_cd,
           r.week_days, r.month_day, r.month_no, r.due_time, r.dept_cd, r.user_id, r.use_yn
      FROM tbl_schedule_rule r
      JOIN tbl_template t ON t.tmpl_cd = r.tmpl_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = r.co_cd AND ct.tmpl_cd = r.tmpl_cd
     WHERE r.co_cd = p_co_cd
     ORDER BY r.tmpl_cd, r.rule_seq;
$$;
COMMENT ON FUNCTION sp_tbl_schedule_rule_r_000(varchar) IS '작성주기 목록 — 오늘 할 일 생성 규칙 전체 조회';

CREATE OR REPLACE PROCEDURE sp_tbl_schedule_rule_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_payload: 작성주기 행 JSON
    p_payload jsonb,
    -- p_id: JWT 작업자 ID
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_idx bigint := NULLIF(p_payload ->> 'idx', '')::bigint;
    v_tmpl_cd varchar(20) := trim(COALESCE(p_payload ->> 'tmplCd', ''));
    v_cycle_cd varchar(1) := trim(COALESCE(p_payload ->> 'cycleCd', ''));
    v_seq int;
BEGIN
    IF v_tmpl_cd = '' OR v_cycle_cd NOT IN ('D', 'W', 'M', 'Y', 'E') THEN
        RAISE EXCEPTION '양식과 작성주기를 확인하세요.' USING ERRCODE = '45000';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM tbl_company_template WHERE co_cd = p_co_cd AND tmpl_cd = v_tmpl_cd AND use_yn = 'Y'
    ) THEN
        RAISE EXCEPTION '사용 중인 업체 양식만 작성주기를 설정할 수 있습니다.' USING ERRCODE = '45000';
    END IF;
    IF v_idx IS NULL THEN
        SELECT COALESCE(MAX(rule_seq), 0) + 1 INTO v_seq
          FROM tbl_schedule_rule WHERE co_cd = p_co_cd AND tmpl_cd = v_tmpl_cd;
        INSERT INTO tbl_schedule_rule(
            co_cd, tmpl_cd, rule_seq, cycle_cd, week_days, month_day, month_no, due_time,
            dept_cd, user_id, use_yn, ins_id, ins_dt
        ) VALUES (
            p_co_cd, v_tmpl_cd, v_seq, v_cycle_cd, NULLIF(p_payload ->> 'weekDays', ''),
            NULLIF(p_payload ->> 'monthDay', '')::int, NULLIF(p_payload ->> 'monthNo', '')::int,
            COALESCE(NULLIF(p_payload ->> 'dueTime', ''), '1800'), NULLIF(p_payload ->> 'deptCd', ''),
            NULLIF(p_payload ->> 'userId', ''), COALESCE(NULLIF(p_payload ->> 'useYn', ''), 'Y'), p_id, now()
        );
    ELSE
        UPDATE tbl_schedule_rule SET
            cycle_cd = v_cycle_cd, week_days = NULLIF(p_payload ->> 'weekDays', ''),
            month_day = NULLIF(p_payload ->> 'monthDay', '')::int, month_no = NULLIF(p_payload ->> 'monthNo', '')::int,
            due_time = COALESCE(NULLIF(p_payload ->> 'dueTime', ''), '1800'), dept_cd = NULLIF(p_payload ->> 'deptCd', ''),
            user_id = NULLIF(p_payload ->> 'userId', ''), use_yn = COALESCE(NULLIF(p_payload ->> 'useYn', ''), 'Y'),
            upd_id = p_id, upd_dt = now()
         WHERE idx = v_idx AND co_cd = p_co_cd;
        IF NOT FOUND THEN RAISE EXCEPTION '작성주기 규칙을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    END IF;
END$$;
COMMENT ON PROCEDURE sp_tbl_schedule_rule_c_000(varchar, jsonb, varchar) IS '작성주기 저장 — 업체 사용 양식과 주기 코드 검증';

CREATE OR REPLACE PROCEDURE sp_tbl_schedule_rule_d_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_idx: 삭제할 작성주기 대리키
    p_idx bigint,
    -- p_id: JWT 작업자 ID — 감사 호환용
    p_id varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM tbl_schedule_rule WHERE idx = p_idx AND co_cd = p_co_cd;
    IF NOT FOUND THEN RAISE EXCEPTION '작성주기 규칙을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
END$$;
COMMENT ON PROCEDURE sp_tbl_schedule_rule_d_000(varchar, bigint, varchar) IS '작성주기 삭제 — 테넌트 범위 대리키 한 건 제거';
