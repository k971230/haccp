-- ============================================================
-- 96 — 문서주기 비정기(E) · 좌측 목록에서 미사용 양식 숨김
--
-- 파일번호: 96
-- 이전번호: 95
-- 개발자: 박승우
-- 일자: 2026-08-19
-- 코멘트:
--   1) CYCLE_CD E 표시를 비정기로 바꾸고, 저장 SP가 E를 받도록 연다(예정일은 생성기가 0건)
--   2) 문서주기 좌측은 html_sys_001~010·012 · hwp_sys_001~027 · hwp_usr_% 만 보여 준다
--   3) 사용양식 목록 SP는 95와 같다 — 운영 함수가 옛 정의면 여기서 다시 맞춘다
--   4) 운영 DB(이미 94/95)에는 이 파일만 추가로 돌린다. 85는 재실행하지 않는다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 공통코드 — E = 비정기. 매일~매년 문구도 화면 콤보와 같게 맞춘다
-- ------------------------------------------------------------
INSERT INTO tbl_code (co_cd, main_cd, sub_cd, code_nm, sort_no, sys_yn, ins_id)
SELECT c.co_cd, 'CYCLE_CD', v.sub_cd, v.code_nm, v.sort_no, 'Y', 'system'
  FROM (SELECT DISTINCT co_cd FROM tbl_code WHERE main_cd = 'CYCLE_CD') c
 CROSS JOIN (VALUES
    ('D', '매일',   1),
    ('W', '매주',   2),
    ('M', '매월',   3),
    ('Q', '분기',   4),
    ('H', '반기',   5),
    ('Y', '매년',   6),
    ('E', '비정기', 7)
 ) AS v(sub_cd, code_nm, sort_no)
ON CONFLICT (co_cd, main_cd, sub_cd) DO UPDATE SET
    code_nm = EXCLUDED.code_nm,
    sort_no = EXCLUDED.sort_no,
    use_yn  = 'Y',
    upd_id  = 'system',
    upd_dt  = now();

-- ------------------------------------------------------------
-- 2. 문서주기 좌측 목록 — 보건증 HTML·028+ 는 등록 대상이 아니라 숨긴다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_schedule_cycle_management_form_r_000(varchar, varchar, varchar);
DROP FUNCTION IF EXISTS sp_schedule_cycle_management_form_r_000(varchar, varchar, varchar, varchar);

CREATE FUNCTION sp_schedule_cycle_management_form_r_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위. 필수 등가 조건
    p_co_cd   varchar,
    -- p_tmpl_cd: 헤더 양식코드 검색어. 공백이면 전체
    p_tmpl_cd varchar,
    -- p_tmpl_nm: 헤더 양식명 검색어. 공백이면 전체
    p_tmpl_nm varchar,
    -- p_use_yn: 사용여부 Y/N. 공백이면 전체
    p_use_yn  varchar
)
RETURNS TABLE(
    tmpl_cd  varchar,
    tmpl_nm  varchar,
    -- 구분 — sys:시스템양식, usr:자사양식
    sys_yn   varchar,
    doc_kind varchar,
    -- 등록된 주기 코드 — 미등록이면 NULL
    cycle_cd varchar,
    -- 주기 등록 여부 Y/N — 삭제 버튼 활성 판정
    rule_yn  varchar,
    -- 양식 사용여부 Y/N — 화면 검색·목록 열
    use_yn   varchar
) LANGUAGE sql STABLE AS $$
    SELECT ct.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm),
           lower(CASE WHEN COALESCE(ct.sys_yn, 'sys') IN ('N', 'n', 'usr') THEN 'usr' ELSE 'sys' END),
           t.doc_kind,
           r.cycle_cd,
           CASE WHEN r.idx IS NULL THEN 'N' ELSE 'Y' END,
           upper(COALESCE(ct.use_yn, 'N'))
      FROM tbl_company_template ct
      JOIN tbl_template t ON t.tmpl_cd = ct.tmpl_cd
      -- 양식당 주기 1건이므로 LEFT JOIN 이 행을 늘리지 않는다
      LEFT JOIN tbl_schedule_rule r ON r.co_cd = ct.co_cd AND r.tmpl_cd = ct.tmpl_cd
     WHERE ct.co_cd = p_co_cd
       -- 주기 화면: HTML 001~010 + 사용양식 HWP 001~027 + 사용자추가. 011·028+ 제외
       AND (
            ct.tmpl_cd ~ '^html_sys_0(0[1-9]|10|12)$'
         OR ct.tmpl_cd ~ '^hwp_sys_0(0[1-9]|1[0-9]|2[0-7])$'
         OR ct.tmpl_cd LIKE 'hwp_usr_%'
       )
       -- 사용여부 공백일 때(= 전체) 필터 생략, Y/N 이면 등가
       AND (
            COALESCE(NULLIF(btrim(p_use_yn), ''), '') = ''
            OR upper(COALESCE(ct.use_yn, 'N')) = upper(btrim(p_use_yn))
           )
       AND ct.tmpl_cd LIKE CONCAT('%', COALESCE(p_tmpl_cd, ''), '%')
       AND COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm) LIKE CONCAT('%', COALESCE(p_tmpl_nm, ''), '%')
     ORDER BY t.sort_no, ct.tmpl_cd;
$$;

COMMENT ON FUNCTION sp_schedule_cycle_management_form_r_000(varchar, varchar, varchar, varchar) IS
  '문서주기관리 좌측 — html_sys_001~010·012 · hwp_sys_001~027 · hwp_usr_*. html_sys_011·028+ 숨김';

-- ------------------------------------------------------------
-- 3. 사용양식 목록 — 95와 동일 필터를 다시 심는다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_hwp_template_management_r_000(varchar, varchar, varchar);
CREATE FUNCTION sp_hwp_template_management_r_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위. 필수 등가 조건
    p_co_cd   varchar,
    -- p_tmpl_cd: 헤더 양식코드 검색어. 공백이면 전체
    p_tmpl_cd varchar,
    -- p_tmpl_nm: 헤더 양식명 검색어. 공백이면 전체
    p_tmpl_nm varchar
)
RETURNS TABLE(
    tmpl_cd          varchar,
    tmpl_nm          varchar,
    sys_yn           varchar,
    doc_kind         varchar,
    category_cd      varchar,
    mng_no           varchar,
    form_path        varchar,
    form_file_nm     varchar,
    use_yn           varchar,
    default_file_idx bigint,
    current_file_idx bigint,
    file_hist_cnt    int
) LANGUAGE sql STABLE AS $$
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
      JOIN tbl_template t ON t.tmpl_cd = ct.tmpl_cd
     WHERE ct.co_cd = p_co_cd
       AND (
            ct.tmpl_cd ~ '^hwp_sys_0(0[1-9]|1[0-9]|2[0-7])$'
         OR ct.tmpl_cd LIKE 'hwp_usr_%'
       )
       AND ct.tmpl_cd LIKE CONCAT('%', COALESCE(p_tmpl_cd, ''), '%')
       AND COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm) LIKE CONCAT('%', COALESCE(p_tmpl_nm, ''), '%')
     ORDER BY t.sort_no, ct.tmpl_cd;
$$;
COMMENT ON FUNCTION sp_hwp_template_management_r_000(varchar, varchar, varchar) IS
  '사용양식 목록 — hwp_sys_001~027 시스템제공 + hwp_usr_* 사용자추가. html_sys·028+ 숨김';

-- ------------------------------------------------------------
-- 4. 문서주기 저장 — E(비정기) 허용. 예정일 0건은 Java 생성기 몫
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_schedule_cycle_management_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_payload: 화면 폼 1건 {tmplCd, baseDt, cycleCd, nonworkRule, dueTime, deptCd, userId, useYn, details[]}
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
END$$;
COMMENT ON PROCEDURE sp_schedule_cycle_management_c_000(varchar, jsonb, varchar) IS
  '문서주기 저장 — 양식당 1건 업서트 + 반복 상세 전량 교체. D/W/M/Q/H/Y/E 허용';

-- ------------------------------------------------------------
-- 5. 레거시 작성주기 저장 — 같은 컬럼이라 E를 같이 연다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_schedule_rule_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_payload: 구 작성주기 그리드 1행 {idx, tmplCd, cycleCd, baseDt, dueTime, deptCd, userId, useYn}
    p_payload jsonb,
    -- p_id: JWT 작업자 ID
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_idx bigint := NULLIF(p_payload ->> 'idx', '')::bigint;
    v_tmpl_cd varchar(40) := trim(COALESCE(p_payload ->> 'tmplCd', ''));
    v_cycle_cd varchar(1) := upper(trim(COALESCE(p_payload ->> 'cycleCd', '')));
    v_base varchar(8) := regexp_replace(COALESCE(p_payload ->> 'baseDt', ''), '[^0-9]', '', 'g');
    v_due varchar(4) := regexp_replace(COALESCE(p_payload ->> 'dueTime', ''), '[^0-9]', '', 'g');
    v_month_day int;
    v_use varchar(1);
BEGIN
    IF v_tmpl_cd = '' OR v_cycle_cd NOT IN ('D', 'W', 'M', 'Q', 'H', 'Y', 'E') THEN
        RAISE EXCEPTION '양식과 작성주기(매일/매주/매월/분기/반기/매년/비정기)를 확인하세요.' USING ERRCODE = '45000';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM tbl_company_template WHERE co_cd = p_co_cd AND tmpl_cd = v_tmpl_cd AND upper(use_yn) = 'Y'
    ) THEN
        RAISE EXCEPTION '사용 중인 업체 양식만 작성주기를 설정할 수 있습니다.' USING ERRCODE = '45000';
    END IF;
    IF length(v_base) = 8 THEN
        v_month_day := substring(v_base, 7, 2)::int;
    ELSE
        v_base := NULL;
        v_month_day := NULLIF(p_payload ->> 'monthDay', '')::int;
    END IF;
    IF length(v_due) = 3 THEN v_due := lpad(v_due, 4, '0'); END IF;
    IF v_due = '' THEN v_due := '1800'; END IF;
    v_use := CASE lower(COALESCE(NULLIF(p_payload ->> 'useYn', ''), 'y')) WHEN 'n' THEN 'N' ELSE 'Y' END;

    -- 양식당 1건 제약이라 idx 유무와 무관하게 업서트한다
    INSERT INTO tbl_schedule_rule(
        co_cd, tmpl_cd, rule_seq, cycle_cd, week_days, month_day, month_no, due_time,
        dept_cd, user_id, use_yn, base_dt, ins_id, ins_dt
    ) VALUES (
        p_co_cd, v_tmpl_cd, 1, v_cycle_cd, NULL, v_month_day, NULL, v_due,
        NULLIF(p_payload ->> 'deptCd', ''),
        -- 담당자는 ID 만 저장한다 — 이름을 넣으면 배정·알림 조인이 어긋난다
        NULLIF(p_payload ->> 'userId', ''),
        v_use, v_base, p_id, now()
    )
    ON CONFLICT (co_cd, tmpl_cd) DO UPDATE SET
        cycle_cd  = EXCLUDED.cycle_cd,
        month_day = EXCLUDED.month_day,
        due_time  = EXCLUDED.due_time,
        dept_cd   = EXCLUDED.dept_cd,
        user_id   = EXCLUDED.user_id,
        use_yn    = EXCLUDED.use_yn,
        base_dt   = EXCLUDED.base_dt,
        upd_id    = p_id, upd_dt = now();
    -- v_idx 는 구 화면 호환 인자라 사용하지 않는다(양식코드가 곧 키다)
    PERFORM v_idx;
END$$;
COMMENT ON PROCEDURE sp_tbl_schedule_rule_c_000(varchar, jsonb, varchar) IS
  '구 작성주기 저장 — 양식당 1건 업서트, 담당자는 ID 저장, 주기 Q·H·E 허용';
