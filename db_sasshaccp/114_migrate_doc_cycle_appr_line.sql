-- ============================================================
-- 114 — 문서주기관리 결재선 (tbl_company_template.appr_line_cd)
--
-- 파일번호: 114
-- 이전번호: 113
-- 개발자: 박승우
-- 일자: 2026-08-20
-- 코멘트:
--   1) 좌측 목록·우측 단건에 결재선 코드·이름을 내린다. 저장은 사용양식 appr_line_cd
--   2) 주기는 계속 tbl_schedule_rule. 결재선은 양식에 붙고 상신 시 그대로 쓴다
--   3) 빈 코드는 NULL. 값이 있으면 자사 사용중 결재선만 받는다
--
-- Jenkins는 migrate를 안 돌린다. 운영은 DBeaver/수동. 85 재실행 금지
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 좌측 양식 목록 — 113 필터 유지 + 결재선
--    RETURNS TABLE 변경이라 CREATE OR REPLACE 불가. DROP 후 CREATE
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_schedule_cycle_management_form_r_000(varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_schedule_cycle_management_form_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_tmpl_cd: 양식코드 부분검색. 빈값이면 전체
    p_tmpl_cd varchar,
    -- p_tmpl_nm: 양식명 부분검색. 빈값이면 전체
    p_tmpl_nm varchar,
    -- p_use_yn: 사용여부 Y/N. 빈값이면 전체
    p_use_yn varchar
)
RETURNS TABLE(
    tmpl_cd varchar,
    tmpl_nm varchar,
    sys_yn varchar,
    doc_kind varchar,
    cycle_cd varchar,
    rule_yn varchar,
    use_yn varchar,
    -- 사용양식에 붙은 결재선 — 주기 없어도 우측 폼이 채울 수 있게 목록에도 내린다
    appr_line_cd varchar,
    appr_line_nm varchar
) LANGUAGE sql STABLE AS $$
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
      JOIN tbl_template t ON t.tmpl_cd = ct.tmpl_cd
      LEFT JOIN tbl_schedule_rule r ON r.co_cd = ct.co_cd AND r.tmpl_cd = ct.tmpl_cd
      LEFT JOIN tbl_approval_line al ON al.co_cd = ct.co_cd AND al.appr_line_cd = ct.appr_line_cd
     WHERE ct.co_cd = p_co_cd
       AND (
            ct.tmpl_cd ~ '^html_sys_0(0[2-57-9]|10|12)$'
         OR (ct.tmpl_cd ~ '^html_hyg_prc_[0-9]{3}$' AND ct.tmpl_cd <> 'html_hyg_prc_000')
         OR (ct.tmpl_cd ~ '^tml_ccp_chk_[0-9]{3}$' AND ct.tmpl_cd <> 'tml_ccp_chk_000')
         OR (ct.tmpl_cd ~ '^tml_ccp_pkg_[0-9]{3}$' AND ct.tmpl_cd <> 'tml_ccp_pkg_000')
         OR (ct.tmpl_cd ~ '^tml_ccp_htg_[0-9]{3}$' AND ct.tmpl_cd <> 'tml_ccp_htg_000')
         OR (ct.tmpl_cd ~ '^tml_ccp_mtl_[0-9]{3}$' AND ct.tmpl_cd <> 'tml_ccp_mtl_000')
         OR ct.tmpl_cd ~ '^hwp_sys_0(0[1-9]|1[0-9]|2[0-7])$'
         OR ct.tmpl_cd LIKE 'hwp_usr_%'
       )
       AND (
            COALESCE(NULLIF(btrim(p_use_yn), ''), '') = ''
            OR upper(COALESCE(ct.use_yn, 'N')) = upper(btrim(p_use_yn))
           )
       AND ct.tmpl_cd LIKE CONCAT('%', COALESCE(p_tmpl_cd, ''), '%')
       AND COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm) LIKE CONCAT('%', COALESCE(p_tmpl_nm, ''), '%')
     ORDER BY t.sort_no, ct.tmpl_cd;
$$;
COMMENT ON FUNCTION sp_schedule_cycle_management_form_r_000(varchar, varchar, varchar, varchar) IS
  '문서주기관리 좌측 — 113 필터 + 결재선. 예시 000 숨김';

-- ------------------------------------------------------------
-- 2. 주기 단건 — 결재선은 사용양식 조인. 주기 없으면 빈 목록(삭제 판정 유지)
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_schedule_cycle_management_r_000(varchar, varchar);
CREATE FUNCTION sp_schedule_cycle_management_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_tmpl_cd: 좌측에서 선택한 양식코드
    p_tmpl_cd varchar
)
RETURNS TABLE(
    tmpl_cd      varchar,
    tmpl_nm      varchar,
    -- 관리 시작일 yyyyMMdd
    base_dt      varchar,
    cycle_cd     varchar,
    nonwork_rule varchar,
    -- 마감시각 HHMM
    due_time     varchar,
    dept_cd      varchar,
    -- 부서명 — 표시 전용. 저장은 dept_cd 로만 한다
    dept_nm      varchar,
    user_id      varchar,
    -- 담당자명 — 표시 전용. 저장은 user_id 로만 한다
    user_nm      varchar,
    use_yn       varchar,
    -- 사용양식 결재선 — 표시는 이름, 저장은 코드
    appr_line_cd varchar,
    appr_line_nm varchar,
    -- 반복 상세 [{detailTy, val1, val2}] — 없으면 빈 배열
    details      jsonb
) LANGUAGE sql STABLE AS $$
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
      JOIN tbl_template t ON t.tmpl_cd = r.tmpl_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = r.co_cd AND ct.tmpl_cd = r.tmpl_cd
      LEFT JOIN tbl_approval_line al ON al.co_cd = r.co_cd AND al.appr_line_cd = ct.appr_line_cd
      LEFT JOIN tbl_dept d ON d.co_cd = r.co_cd AND d.dept_cd = r.dept_cd
      LEFT JOIN tbl_user u ON u.co_cd = r.co_cd AND u.user_id = r.user_id
     WHERE r.co_cd = p_co_cd AND r.tmpl_cd = p_tmpl_cd;
$$;
COMMENT ON FUNCTION sp_schedule_cycle_management_r_000(varchar, varchar) IS
  '문서주기 단건 — 주기·담당 + 사용양식 결재선 + 반복 상세 jsonb';

-- ------------------------------------------------------------
-- 3. 주기 저장 — 96 E 허용 유지 + 사용양식 결재선 갱신
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_schedule_cycle_management_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_payload: {tmplCd, baseDt, cycleCd, nonworkRule, dueTime, deptCd, userId, useYn, apprLineCd, details[]}
    p_payload jsonb,
    -- p_id: JWT 작업자 ID — 감사 컬럼
    p_id      varchar
)
LANGUAGE plpgsql AS $$
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
COMMENT ON PROCEDURE sp_schedule_cycle_management_c_000(varchar, jsonb, varchar) IS
  '문서주기 저장 — 양식당 1건 업서트 + 반복 상세 전량 교체 + 사용양식 결재선. D/W/M/Q/H/Y/E 허용';
