-- ============================================================
-- 108 — 공정점검 HTML 자사 양식 html_hyg_NNN · 문서주기 노출
--
-- 파일번호: 108
-- 이전번호: 107
-- 개발자: 박승우
-- 일자: 2026-08-20
-- 코멘트:
--   1) 기준관리 저장은 같은 html_sys_001 버전+1이 아니라 html_hyg_001부터 채번한다
--   2) 표준 예시는 화면 코드 html_hyg_000. 시드 항목은 계속 html_sys_001
--   3) 복사 시 사용양식·기본 주기(D)를 넣어 문서주기 좌측에 바로 보이게 한다
--
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 목록 — 가상 html_hyg_000 + 이 회사 html_hyg_001+
--    p_tmpl_cd는 호환용. 목록은 시드 html_sys_001 버전 행을 숨긴다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_html_form_ver_r_000(varchar, varchar);
DROP FUNCTION IF EXISTS sp_tbl_html_form_ver_r_000(varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_html_form_ver_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_tmpl_cd: 호환 인자. 목록 범위는 html_hyg_* 고정이라 쓰지 않는다
    p_tmpl_cd varchar,
    -- p_ver_cd: 양식코드 부분검색. 빈값이면 전체
    p_ver_cd  varchar DEFAULT NULL,
    -- p_ver_nm: 양식명 부분검색. 빈값이면 전체
    p_ver_nm  varchar DEFAULT NULL
)
RETURNS TABLE(
    idx       bigint,
    tmpl_cd   varchar,
    ver_no    int,
    ver_cd    varchar,
    ver_nm    varchar,
    sys_yn    varchar,
    apply_yn  varchar,
    locked_yn varchar,
    ins_nm    varchar,
    ins_dt    varchar
) LANGUAGE sql STABLE AS $$
    SELECT x.idx, x.tmpl_cd, x.ver_no, x.ver_cd, x.ver_nm, x.sys_yn, x.apply_yn, x.locked_yn, x.ins_nm, x.ins_dt
      FROM (
            SELECT NULL::bigint AS idx,
                   'html_hyg_000'::varchar AS tmpl_cd,
                   0 AS ver_no,
                   'html_hyg_000'::varchar AS ver_cd,
                   '표준'::varchar AS ver_nm,
                   'sys'::varchar AS sys_yn,
                   'N'::varchar AS apply_yn,
                   'Y'::varchar AS locked_yn,
                   ''::varchar AS ins_nm,
                   ''::varchar AS ins_dt
            UNION ALL
            SELECT v.idx,
                   v.tmpl_cd,
                   v.ver_no,
                   COALESCE(NULLIF(btrim(v.ver_cd), ''), v.tmpl_cd),
                   COALESCE(ct.tmpl_nm_ovr, v.ver_nm),
                   'usr'::varchar,
                   v.apply_yn,
                   'N'::varchar,
                   COALESCE(u.user_nm, v.ins_id, '')::varchar,
                   COALESCE(to_char(v.ins_dt, 'YYYY-MM-DD'), '')::varchar
              FROM tbl_html_form_ver v
              JOIN tbl_company_template ct
                ON ct.co_cd = v.co_cd AND ct.tmpl_cd = v.tmpl_cd
              LEFT JOIN tbl_user u ON u.co_cd = v.co_cd AND u.user_id = v.ins_id
             WHERE v.co_cd = p_co_cd
               AND v.use_yn = 'Y'
               AND v.tmpl_cd ~ '^html_hyg_[0-9]{3}$'
               AND v.tmpl_cd <> 'html_hyg_000'
           ) x
     WHERE (COALESCE(btrim(p_ver_cd), '') = '' OR x.tmpl_cd ILIKE '%' || btrim(p_ver_cd) || '%')
       AND (COALESCE(btrim(p_ver_nm), '') = '' OR x.ver_nm ILIKE '%' || btrim(p_ver_nm) || '%')
     ORDER BY x.tmpl_cd;
$$;
COMMENT ON FUNCTION sp_tbl_html_form_ver_r_000(varchar, varchar, varchar, varchar) IS
  'HTML양식 원본 목록 — 예시 html_hyg_000 + 자사 html_hyg_001+. html_sys_001 버전 행 숨김';

-- ------------------------------------------------------------
-- 2. 항목 — 000/시드는 tbl_check_item(html_sys_001), 자사는 스냅샷
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_html_form_ver_item_r_000(varchar, varchar, int);
CREATE FUNCTION sp_tbl_html_form_ver_item_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_tmpl_cd: html_hyg_000 또는 html_hyg_NNN. 옛 html_sys_001도 표준으로 본다
    p_tmpl_cd varchar,
    -- p_ver_no: 표준은 0. 자사는 1
    p_ver_no  int
)
RETURNS TABLE(
    item_cd    varchar,
    sort_no    int,
    cycle_nm   varchar,
    grp_nm     varchar,
    item_nm    text,
    input_type varchar,
    unit_nm    varchar
) LANGUAGE plpgsql STABLE AS $$
BEGIN
    -- 예시·시드·빈 코드일 때(= 표준 항목). 자사 html_hyg_001+ 는 스냅샷만
    IF COALESCE(p_tmpl_cd, '') IN ('html_hyg_000', 'html_sys_001', '') THEN
        RETURN QUERY
        SELECT c.item_cd, c.sort_no, c.cycle_nm, c.grp_nm, c.item_nm, c.input_type, c.unit_nm
          FROM tbl_check_item c
         WHERE c.tmpl_cd = 'html_sys_001' AND c.use_yn = 'Y'
         ORDER BY c.sort_no, c.item_cd;
        RETURN;
    END IF;
    RETURN QUERY
    SELECT i.item_cd, i.sort_no, i.cycle_nm, i.grp_nm, i.item_nm, i.input_type, i.unit_nm
      FROM tbl_html_form_ver_item i
     WHERE i.co_cd = p_co_cd AND i.tmpl_cd = p_tmpl_cd AND i.ver_no = p_ver_no
     ORDER BY i.sort_no, i.item_cd;
END$$;
COMMENT ON FUNCTION sp_tbl_html_form_ver_item_r_000(varchar, varchar, int) IS
  'HTML양식 항목 — html_hyg_000·html_sys_001은 시드, 그 외는 회사 스냅샷';

-- ------------------------------------------------------------
-- 3. 복사 — html_hyg_NNN 채번 + 카탈로그 + 사용양식 + 기본 주기 D
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_tbl_html_form_ver_copy_c_000(varchar, varchar, int, varchar, varchar);
DROP PROCEDURE IF EXISTS sp_tbl_html_form_ver_copy_c_000(varchar, varchar, int, varchar, varchar, varchar);
DROP FUNCTION IF EXISTS sp_tbl_html_form_ver_copy_c_000(varchar, varchar, int, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_html_form_ver_copy_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd      varchar,
    -- p_tmpl_cd: 호환 인자. 원본은 항상 html_sys_001 시드
    p_tmpl_cd    varchar,
    -- p_src_ver_no: 호환 인자. 행추가는 표준만
    p_src_ver_no int,
    -- p_ver_cd: 호환 인자. 번호는 SP가 전역 MAX로 확정
    p_ver_cd     varchar,
    -- p_ver_nm: 양식명 — 일간·주간 등. 문서주기 좌측 표시명
    p_ver_nm     varchar,
    -- p_id: 작업자
    p_id         varchar
)
RETURNS varchar
LANGUAGE plpgsql AS $$
DECLARE
    v_nm   varchar;
    v_n    int;
    v_cd   varchar;
    v_src  tbl_template%ROWTYPE;
    v_try  int := 0;
BEGIN
    IF COALESCE(p_co_cd, '') = '' THEN
        RAISE EXCEPTION '회사코드는 필수입니다.' USING ERRCODE = '45000';
    END IF;
    v_nm := btrim(COALESCE(p_ver_nm, ''));
    -- 양식명 공백일 때(= 필수)
    IF v_nm = '' THEN
        RAISE EXCEPTION '양식명은 필수입니다.' USING ERRCODE = '45000';
    END IF;

    SELECT * INTO v_src FROM tbl_template WHERE tmpl_cd = 'html_sys_001';
    IF NOT FOUND THEN
        RAISE EXCEPTION '표준 양식을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    SELECT COALESCE(MAX(substring(t.tmpl_cd from 10)::int), 0) INTO v_n
      FROM tbl_template t
     WHERE t.tmpl_cd ~ '^html_hyg_[0-9]{3}$'
       AND t.tmpl_cd <> 'html_hyg_000';

    LOOP
        v_try := v_try + 1;
        v_n := v_n + 1;
        -- 999 초과일 때(= 채번 한도)
        IF v_n > 999 OR v_try > 50 THEN
            RAISE EXCEPTION '양식코드를 더 부여할 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        v_cd := 'html_hyg_' || lpad(v_n::text, 3, '0');
        -- 000은 예시 예약
        IF v_cd = 'html_hyg_000' THEN
            CONTINUE;
        END IF;
        EXIT WHEN NOT EXISTS (SELECT 1 FROM tbl_template WHERE tmpl_cd = v_cd);
    END LOOP;

    INSERT INTO tbl_template (
        co_cd, tmpl_cd, tmpl_nm, mng_no, doc_kind, category_cd, scrn_cd,
        default_cycle_cd, default_retention_month, impl_yn, sort_no, use_yn, ins_id, ins_dt
    ) VALUES (
        p_co_cd, v_cd, v_nm, v_src.mng_no, 'html', v_src.category_cd, 'hygiene-process-check',
        'D', COALESCE(v_src.default_retention_month, 24), 'Y',
        COALESCE(v_src.sort_no, 101) + v_n, 'Y', p_id, now()
    );

    INSERT INTO tbl_company_template (
        co_cd, tmpl_cd, tmpl_nm_ovr, cycle_cd, retention_month, use_yn, sys_yn, ins_id, ins_dt
    ) VALUES (
        p_co_cd, v_cd, v_nm, 'D', COALESCE(v_src.default_retention_month, 24), 'Y', 'usr', p_id, now()
    );

    INSERT INTO tbl_html_form_ver (
        co_cd, tmpl_cd, ver_no, ver_cd, ver_nm, apply_yn, use_yn, ins_id, ins_dt
    ) VALUES (
        p_co_cd, v_cd, 1, v_cd, v_nm, 'N', 'Y', p_id, now()
    );

    INSERT INTO tbl_html_form_ver_item (
        co_cd, tmpl_cd, ver_no, item_cd, sort_no, cycle_nm, grp_nm, item_nm, input_type, unit_nm, ins_id
    )
    SELECT p_co_cd, v_cd, 1, c.item_cd, c.sort_no, c.cycle_nm, c.grp_nm, c.item_nm, c.input_type, c.unit_nm, p_id
      FROM tbl_check_item c
     WHERE c.tmpl_cd = 'html_sys_001' AND c.use_yn = 'Y';

    INSERT INTO tbl_schedule_rule (
        co_cd, tmpl_cd, rule_seq, cycle_cd, nonwork_rule, due_time, use_yn, ins_id, ins_dt
    ) VALUES (
        p_co_cd, v_cd, 1, 'D', 'keep', '1800', 'Y', p_id, now()
    )
    ON CONFLICT (co_cd, tmpl_cd) DO NOTHING;

    RETURN v_cd;
END$$;
COMMENT ON FUNCTION sp_tbl_html_form_ver_copy_c_000(varchar, varchar, int, varchar, varchar, varchar) IS
  'HTML 자사 양식 생성 — html_hyg_NNN 채번, 사용양식 usr, 기본 주기 D. 양식명 반환 코드';

-- ------------------------------------------------------------
-- 4. 양식명 — 버전·카탈로그·사용양식 동기. 예시는 거부
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_tbl_html_form_ver_nm_u_000(varchar, varchar, int, varchar, varchar);
CREATE PROCEDURE sp_tbl_html_form_ver_nm_u_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_tmpl_cd: 자사 양식코드 html_hyg_NNN
    p_tmpl_cd varchar,
    -- p_ver_no: 회사 순번. 0 이하면 표준
    p_ver_no  int,
    -- p_ver_nm: 바꿀 양식명
    p_ver_nm  varchar,
    -- p_id: 수정자
    p_id      varchar
)
LANGUAGE plpgsql AS $$
DECLARE v_nm varchar;
BEGIN
    -- 예시이거나 순번 0일 때(= 표준)
    IF COALESCE(p_tmpl_cd, '') IN ('html_hyg_000', 'html_sys_001') OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 양식명은 수정할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    v_nm := btrim(COALESCE(p_ver_nm, ''));
    IF v_nm = '' THEN
        RAISE EXCEPTION '양식명은 필수입니다.' USING ERRCODE = '45000';
    END IF;
    UPDATE tbl_html_form_ver
       SET ver_nm = v_nm, upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd
       AND ver_no = p_ver_no AND use_yn = 'Y';
    IF NOT FOUND THEN
        RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    UPDATE tbl_template
       SET tmpl_nm = v_nm, upd_id = p_id, upd_dt = now()
     WHERE tmpl_cd = p_tmpl_cd AND co_cd = p_co_cd;
    UPDATE tbl_company_template
       SET tmpl_nm_ovr = v_nm, upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
END$$;

-- ------------------------------------------------------------
-- 5. 삭제 차단 — 예시·없는 행·작성 문서·예정 과제. 주기 행만으로는 막지 않는다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_html_form_ver_delete_blocker_r_000(varchar, varchar, int);
CREATE FUNCTION sp_tbl_html_form_ver_delete_blocker_r_000(
    p_co_cd   varchar,
    p_tmpl_cd varchar,
    p_ver_no  int
)
RETURNS TABLE(ref_key varchar, target varchar) LANGUAGE plpgsql STABLE AS $$
DECLARE v_nm varchar; v_use varchar; v_key varchar;
BEGIN
    v_key := COALESCE(NULLIF(btrim(p_tmpl_cd), ''), COALESCE(p_ver_no::varchar, ''));
    -- 예시·시드일 때(= 표준 잠금)
    IF COALESCE(p_tmpl_cd, '') IN ('html_hyg_000', 'html_sys_001') OR COALESCE(p_ver_no, 0) <= 0 THEN
        RETURN QUERY SELECT '표준'::varchar, '시스템 표준 항목'::varchar;
        RETURN;
    END IF;
    SELECT ver_nm, use_yn INTO v_nm, v_use
      FROM tbl_html_form_ver
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
    IF v_nm IS NULL OR v_use = 'N' THEN
        RETURN QUERY SELECT v_key, '없는 양식'::varchar;
        RETURN;
    END IF;
    IF EXISTS (
        SELECT 1 FROM tbl_document d
         WHERE d.co_cd = p_co_cd AND d.tmpl_cd = p_tmpl_cd AND d.del_yn = 'N'
    ) THEN
        RETURN QUERY SELECT COALESCE(v_nm, v_key), '작성 문서'::varchar;
        RETURN;
    END IF;
    IF EXISTS (
        SELECT 1 FROM tbl_schedule_task t
         WHERE t.co_cd = p_co_cd AND t.tmpl_cd = p_tmpl_cd
    ) THEN
        RETURN QUERY SELECT COALESCE(v_nm, v_key), '오늘 할 일'::varchar;
    END IF;
END$$;

-- ------------------------------------------------------------
-- 6. 삭제 — 주기·사용양식 정리 + 버전 소프트 삭제
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_tbl_html_form_ver_d_000(varchar, varchar, int, varchar);
CREATE PROCEDURE sp_tbl_html_form_ver_d_000(
    p_co_cd   varchar,
    p_tmpl_cd varchar,
    p_ver_no  int,
    p_id      varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    -- 예시일 때(= 표준)
    IF COALESCE(p_tmpl_cd, '') IN ('html_hyg_000', 'html_sys_001') OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 양식은 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM tbl_html_form_ver
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y'
    ) THEN
        RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    DELETE FROM tbl_schedule_rule_detail WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    DELETE FROM tbl_schedule_rule WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    DELETE FROM tbl_company_template WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    UPDATE tbl_html_form_ver
       SET use_yn = 'N', apply_yn = 'N', upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
END$$;

-- ------------------------------------------------------------
-- 7. 문서주기 좌측 — html_sys_001·html_hyg_000 제외, html_hyg_001+ 포함
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_schedule_cycle_management_form_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_tmpl_cd: 양식코드 검색. 공백이면 전체
    p_tmpl_cd varchar,
    -- p_tmpl_nm: 양식명 검색. 공백이면 전체
    p_tmpl_nm varchar,
    -- p_use_yn: 사용여부. 공백이면 전체
    p_use_yn  varchar
)
RETURNS TABLE(
    tmpl_cd  varchar,
    tmpl_nm  varchar,
    sys_yn   varchar,
    doc_kind varchar,
    cycle_cd varchar,
    rule_yn  varchar,
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
      LEFT JOIN tbl_schedule_rule r ON r.co_cd = ct.co_cd AND r.tmpl_cd = ct.tmpl_cd
     WHERE ct.co_cd = p_co_cd
       AND (
            ct.tmpl_cd ~ '^html_sys_0(0[2-9]|10|12)$'
         OR (ct.tmpl_cd ~ '^html_hyg_[0-9]{3}$' AND ct.tmpl_cd <> 'html_hyg_000')
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
  '문서주기관리 좌측 — html_sys_002~010·012 · html_hyg_001+ · hwp_sys_001~027 · hwp_usr_*. html_sys_001·html_hyg_000 숨김';
