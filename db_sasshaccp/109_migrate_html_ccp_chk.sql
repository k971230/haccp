-- ============================================================
-- 109 — CCP 검증점검 HTML 자사 양식 tml_ccp_chk_NNN · 문서주기 노출
--
-- 파일번호: 109
-- 이전번호: 108
-- 개발자: 박승우
-- 일자: 2026-08-20
-- 코멘트:
--   1) 기준관리 저장은 html_sys_006 버전+1이 아니라 tml_ccp_chk_001부터 채번한다
--   2) 표준 예시는 tml_ccp_chk_000 (12 radio + 관찰·인터뷰 text 6). html_sys_006 항목은 그대로
--   3) 목록·복사 SP는 p_tmpl_cd로 공정점검/CCP 가족을 가른다. 빈 코드는 공정점검
--
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 시드 항목 — tml_ccp_chk_000. html_sys_006(12 YN)은 작성 화면용으로 유지
-- ------------------------------------------------------------
INSERT INTO tbl_check_item (
    tmpl_cd, item_cd, grp_cd, grp_nm, item_nm, input_type, unit_nm, cycle_nm, sort_no, ins_id
) VALUES
    ('tml_ccp_chk_000', 'V11', 'raw-cold',  '원료육 냉장보관',
     '종사자가 주기적으로 냉장보관고 온도를 확인하고, 그 내용을 기록하고 있습니까?',
     'radio', NULL, '월간', 1, 'system'),
    ('tml_ccp_chk_000', 'V12', 'raw-cold',  '원료육 냉장보관',
     '종사자가 원료육 냉장보관 공정 모니터링 방법을 정확히 알고 있습니까?',
     'radio', NULL, '월간', 2, 'system'),
    ('tml_ccp_chk_000', 'V13', 'raw-cold',  '원료육 냉장보관',
     '종사자가 한계기준 이탈 시 실시해야 하는 개선조치 방법을 알고 있으며, 이탈 및 개선조치 내용이 기록되고 있습니까?',
     'radio', NULL, '월간', 3, 'system'),
    ('tml_ccp_chk_000', 'V14', 'raw-cold',  '원료육 냉장보관',
     '온도측정장치는 주기적으로 검·교정이 이루어지고 있습니까?',
     'radio', NULL, '월간', 4, 'system'),
    ('tml_ccp_chk_000', 'V15', 'raw-cold',  '원료육 냉장보관',
     '모니터링 행동 관찰 :      월       일        시',
     'text', NULL, '월간', 5, 'system'),
    ('tml_ccp_chk_000', 'V16', 'raw-cold',  '원료육 냉장보관',
     '모니터링 담당자 인터뷰 :      월        일       시',
     'text', NULL, '월간', 6, 'system'),
    ('tml_ccp_chk_000', 'V21', 'metal',     '금속검출',
     '종사자가 주기적으로 시편을 통해 금속검출기의 감도 이상 유무를 확인하고 있습니까?',
     'radio', NULL, '월간', 7, 'system'),
    ('tml_ccp_chk_000', 'V22', 'metal',     '금속검출',
     '종사자가 금속검출 공정 모니터링 방법을 정확히 알고 있습니까?',
     'radio', NULL, '월간', 8, 'system'),
    ('tml_ccp_chk_000', 'V23', 'metal',     '금속검출',
     '종사자가 한계기준 이탈 시 실시해야 하는 개선조치 방법을 알고 있으며, 이탈 및 개선조치 내용이 기록되고 있습니까?',
     'radio', NULL, '월간', 9, 'system'),
    ('tml_ccp_chk_000', 'V24', 'metal',     '금속검출',
     '금속검출기는 연 1회 검·교정(또는 정기점검)이 이루어지고 있습니까?',
     'radio', NULL, '월간', 10, 'system'),
    ('tml_ccp_chk_000', 'V25', 'metal',     '금속검출',
     '모니터링 행동 관찰 :      월       일        시',
     'text', NULL, '월간', 11, 'system'),
    ('tml_ccp_chk_000', 'V26', 'metal',     '금속검출',
     '모니터링 담당자 인터뷰 :      월        일       시',
     'text', NULL, '월간', 12, 'system'),
    ('tml_ccp_chk_000', 'V31', 'prod-cold', '완제품 냉장보관',
     '종사자가 주기적으로 냉장보관고 온도를 확인하고, 그 내용을 기록하고 있습니까?',
     'radio', NULL, '월간', 13, 'system'),
    ('tml_ccp_chk_000', 'V32', 'prod-cold', '완제품 냉장보관',
     '종사자가 완제품 냉장보관 공정 모니터링 방법을 정확히 알고 있습니까?',
     'radio', NULL, '월간', 14, 'system'),
    ('tml_ccp_chk_000', 'V33', 'prod-cold', '완제품 냉장보관',
     '종사자가 한계기준 이탈 시 실시해야 하는 개선조치 방법을 알고 있으며, 이탈 및 개선조치 내용이 기록되고 있습니까?',
     'radio', NULL, '월간', 15, 'system'),
    ('tml_ccp_chk_000', 'V34', 'prod-cold', '완제품 냉장보관',
     '온도측정장치는 주기적으로 검·교정이 이루어지고 있습니까?',
     'radio', NULL, '월간', 16, 'system'),
    ('tml_ccp_chk_000', 'V35', 'prod-cold', '완제품 냉장보관',
     '모니터링 행동 관찰 :      월       일        시',
     'text', NULL, '월간', 17, 'system'),
    ('tml_ccp_chk_000', 'V36', 'prod-cold', '완제품 냉장보관',
     '모니터링 담당자 인터뷰 :      월        일       시',
     'text', NULL, '월간', 18, 'system')
ON CONFLICT (tmpl_cd, item_cd) DO UPDATE SET
    grp_cd = EXCLUDED.grp_cd, grp_nm = EXCLUDED.grp_nm, item_nm = EXCLUDED.item_nm,
    input_type = EXCLUDED.input_type, unit_nm = EXCLUDED.unit_nm, cycle_nm = EXCLUDED.cycle_nm,
    sort_no = EXCLUDED.sort_no, use_yn = 'Y', upd_id = 'system', upd_dt = now();

-- ------------------------------------------------------------
-- 2. 화면·권한·메뉴 — HTML양식 원본 밑, 공정점검 다음
-- ------------------------------------------------------------
INSERT INTO tbl_screen (scrn_cd, scrn_nm, module_cd, tmpl_cd, sort_no, ins_id) VALUES
    ('ccp-verify-template', '중요관리점(CCP) 검증점검표', 'SET', 'html_sys_006', 1312, 'system')
ON CONFLICT (scrn_cd) DO UPDATE SET
    scrn_nm = EXCLUDED.scrn_nm, module_cd = EXCLUDED.module_cd, tmpl_cd = EXCLUDED.tmpl_cd,
    sort_no = EXCLUDED.sort_no, upd_id = 'system', upd_dt = now();

INSERT INTO tbl_role_screen (co_cd, usrgrp_cd, scrn_cd, read_yn, write_yn, modify_yn, delete_yn, print_yn, ins_id, ins_dt)
SELECT r.co_cd, r.usrgrp_cd, 'ccp-verify-template',
       'Y', 'Y', 'Y',
       CASE WHEN r.usrgrp_cd = 'ADMIN' THEN 'Y' ELSE 'N' END,
       'Y', 'system', now()
  FROM tbl_role r
ON CONFLICT (co_cd, usrgrp_cd, scrn_cd) DO NOTHING;

INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, 'menu-ccp-verify-template', COALESCE(s.scrn_nm, 'ccp-verify-template'),
       'menu-master-html', 'ccp-verify-template',
       COALESCE((
           SELECT MAX(m.sort_no) + 1 FROM tbl_menu m
            WHERE m.co_cd = c.co_cd AND m.h_menu_cd = 'menu-master-html'
       ), 4252),
       'Y', 'system', now()
  FROM (SELECT co_cd FROM tbl_company UNION SELECT DISTINCT co_cd FROM tbl_menu) c
  JOIN tbl_screen s ON s.scrn_cd = 'ccp-verify-template'
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm, h_menu_cd = EXCLUDED.h_menu_cd, scrn_cd = EXCLUDED.scrn_cd,
    sort_no = EXCLUDED.sort_no, use_yn = 'Y', upd_id = 'system', upd_dt = now();

-- ------------------------------------------------------------
-- 3. 목록 — p_tmpl_cd로 가족 분기. 빈 코드·공정점검은 html_hyg, CCP는 tml_ccp_chk
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_html_form_ver_r_000(varchar, varchar);
DROP FUNCTION IF EXISTS sp_tbl_html_form_ver_r_000(varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_html_form_ver_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_tmpl_cd: 가족. tml_ccp_chk*·html_sys_006 이면 CCP, 그 외는 공정점검
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
             WHERE COALESCE(btrim(p_tmpl_cd), '') NOT LIKE 'tml_ccp_chk%'
               AND COALESCE(btrim(p_tmpl_cd), '') <> 'html_sys_006'
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
               AND COALESCE(btrim(p_tmpl_cd), '') NOT LIKE 'tml_ccp_chk%'
               AND COALESCE(btrim(p_tmpl_cd), '') <> 'html_sys_006'
            UNION ALL
            SELECT NULL::bigint AS idx,
                   'tml_ccp_chk_000'::varchar AS tmpl_cd,
                   0 AS ver_no,
                   'tml_ccp_chk_000'::varchar AS ver_cd,
                   '표준'::varchar AS ver_nm,
                   'sys'::varchar AS sys_yn,
                   'N'::varchar AS apply_yn,
                   'Y'::varchar AS locked_yn,
                   ''::varchar AS ins_nm,
                   ''::varchar AS ins_dt
             WHERE COALESCE(btrim(p_tmpl_cd), '') LIKE 'tml_ccp_chk%'
                OR COALESCE(btrim(p_tmpl_cd), '') = 'html_sys_006'
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
               AND v.tmpl_cd ~ '^tml_ccp_chk_[0-9]{3}$'
               AND v.tmpl_cd <> 'tml_ccp_chk_000'
               AND (
                    COALESCE(btrim(p_tmpl_cd), '') LIKE 'tml_ccp_chk%'
                    OR COALESCE(btrim(p_tmpl_cd), '') = 'html_sys_006'
                   )
           ) x
     WHERE (COALESCE(btrim(p_ver_cd), '') = '' OR x.tmpl_cd ILIKE '%' || btrim(p_ver_cd) || '%')
       AND (COALESCE(btrim(p_ver_nm), '') = '' OR x.ver_nm ILIKE '%' || btrim(p_ver_nm) || '%')
     ORDER BY x.tmpl_cd;
$$;
COMMENT ON FUNCTION sp_tbl_html_form_ver_r_000(varchar, varchar, varchar, varchar) IS
  'HTML양식 원본 목록 — 공정점검 html_hyg_000+001 / CCP tml_ccp_chk_000+001. p_tmpl_cd로 가족 분기';

-- ------------------------------------------------------------
-- 4. 항목 — 예시·시드는 tbl_check_item, 자사는 스냅샷
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_html_form_ver_item_r_000(varchar, varchar, int);
CREATE FUNCTION sp_tbl_html_form_ver_item_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_tmpl_cd: 예시·시드 또는 자사 코드
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
    -- 공정점검 예시·시드·빈 코드일 때(= html_sys_001 시드)
    IF COALESCE(p_tmpl_cd, '') IN ('html_hyg_000', 'html_sys_001', '') THEN
        RETURN QUERY
        SELECT c.item_cd, c.sort_no, c.cycle_nm, c.grp_nm, c.item_nm, c.input_type, c.unit_nm
          FROM tbl_check_item c
         WHERE c.tmpl_cd = 'html_sys_001' AND c.use_yn = 'Y'
         ORDER BY c.sort_no, c.item_cd;
        RETURN;
    END IF;
    -- CCP 예시·카탈로그 시드일 때(= tml_ccp_chk_000 18항목). html_sys_006 12항목은 건드리지 않는다
    IF COALESCE(p_tmpl_cd, '') IN ('tml_ccp_chk_000', 'html_sys_006') THEN
        RETURN QUERY
        SELECT c.item_cd, c.sort_no, c.cycle_nm, c.grp_nm, c.item_nm, c.input_type, c.unit_nm
          FROM tbl_check_item c
         WHERE c.tmpl_cd = 'tml_ccp_chk_000' AND c.use_yn = 'Y'
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
  'HTML양식 항목 — html_hyg_000=html_sys_001, tml_ccp_chk_000=18항목 시드, 그 외는 회사 스냅샷';

-- ------------------------------------------------------------
-- 5. 복사 — 가족별 채번 + 카탈로그 + 사용양식 + 기본 주기
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_html_form_ver_copy_c_000(varchar, varchar, int, varchar, varchar);
DROP FUNCTION IF EXISTS sp_tbl_html_form_ver_copy_c_000(varchar, varchar, int, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_html_form_ver_copy_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd      varchar,
    -- p_tmpl_cd: 가족. tml_ccp_chk*·html_sys_006 이면 CCP
    p_tmpl_cd    varchar,
    -- p_src_ver_no: 호환 인자. 행추가는 표준만
    p_src_ver_no int,
    -- p_ver_cd: 호환 인자. 번호는 SP가 전역 MAX로 확정
    p_ver_cd     varchar,
    -- p_ver_nm: 양식명 — 문서주기 좌측 표시명
    p_ver_nm     varchar,
    -- p_id: 작업자
    p_id         varchar
)
RETURNS varchar
LANGUAGE plpgsql AS $$
DECLARE
    v_nm    varchar;
    v_n     int;
    v_cd    varchar;
    v_src   tbl_template%ROWTYPE;
    v_try   int := 0;
    v_ccp   boolean;
    v_pfx   varchar;
    v_std   varchar;
    v_seed  varchar;
    v_cat   varchar;
    v_scrn  varchar;
    v_cycle varchar;
BEGIN
    IF COALESCE(p_co_cd, '') = '' THEN
        RAISE EXCEPTION '회사코드는 필수입니다.' USING ERRCODE = '45000';
    END IF;
    v_nm := btrim(COALESCE(p_ver_nm, ''));
    -- 양식명 공백일 때(= 필수)
    IF v_nm = '' THEN
        RAISE EXCEPTION '양식명은 필수입니다.' USING ERRCODE = '45000';
    END IF;

    v_ccp := COALESCE(p_tmpl_cd, '') LIKE 'tml_ccp_chk%'
          OR COALESCE(p_tmpl_cd, '') = 'html_sys_006';
    -- CCP 가족일 때(= tml_ccp_chk). 아니면 공정점검 html_hyg
    IF v_ccp THEN
        v_pfx := 'tml_ccp_chk_';
        v_std := 'tml_ccp_chk_000';
        v_seed := 'tml_ccp_chk_000';
        v_cat := 'html_sys_006';
        v_scrn := 'ccp-verification-check';
    ELSE
        v_pfx := 'html_hyg_';
        v_std := 'html_hyg_000';
        v_seed := 'html_sys_001';
        v_cat := 'html_sys_001';
        v_scrn := 'hygiene-process-check';
    END IF;

    SELECT * INTO v_src FROM tbl_template WHERE tmpl_cd = v_cat;
    IF NOT FOUND THEN
        RAISE EXCEPTION '표준 양식을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    v_cycle := COALESCE(NULLIF(btrim(v_src.default_cycle_cd), ''), CASE WHEN v_ccp THEN 'M' ELSE 'D' END);

    SELECT COALESCE(MAX(substring(t.tmpl_cd from '[0-9]{3}$')::int), 0) INTO v_n
      FROM tbl_template t
     WHERE t.tmpl_cd ~ ('^' || v_pfx || '[0-9]{3}$')
       AND t.tmpl_cd <> v_std;

    LOOP
        v_try := v_try + 1;
        v_n := v_n + 1;
        -- 999 초과일 때(= 채번 한도)
        IF v_n > 999 OR v_try > 50 THEN
            RAISE EXCEPTION '양식코드를 더 부여할 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        v_cd := v_pfx || lpad(v_n::text, 3, '0');
        -- 000은 예시 예약
        IF v_cd = v_std THEN
            CONTINUE;
        END IF;
        EXIT WHEN NOT EXISTS (SELECT 1 FROM tbl_template WHERE tmpl_cd = v_cd);
    END LOOP;

    INSERT INTO tbl_template (
        co_cd, tmpl_cd, tmpl_nm, mng_no, doc_kind, category_cd, scrn_cd,
        default_cycle_cd, default_retention_month, impl_yn, sort_no, use_yn, ins_id, ins_dt
    ) VALUES (
        p_co_cd, v_cd, v_nm, v_src.mng_no, 'html', v_src.category_cd, v_scrn,
        v_cycle, COALESCE(v_src.default_retention_month, 24), 'Y',
        COALESCE(v_src.sort_no, 101) + v_n, 'Y', p_id, now()
    );

    INSERT INTO tbl_company_template (
        co_cd, tmpl_cd, tmpl_nm_ovr, cycle_cd, retention_month, use_yn, sys_yn, ins_id, ins_dt
    ) VALUES (
        p_co_cd, v_cd, v_nm, v_cycle, COALESCE(v_src.default_retention_month, 24), 'Y', 'usr', p_id, now()
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
     WHERE c.tmpl_cd = v_seed AND c.use_yn = 'Y';

    INSERT INTO tbl_schedule_rule (
        co_cd, tmpl_cd, rule_seq, cycle_cd, nonwork_rule, due_time, use_yn, ins_id, ins_dt
    ) VALUES (
        p_co_cd, v_cd, 1, v_cycle, 'keep', '1800', 'Y', p_id, now()
    )
    ON CONFLICT (co_cd, tmpl_cd) DO NOTHING;

    RETURN v_cd;
END$$;
COMMENT ON FUNCTION sp_tbl_html_form_ver_copy_c_000(varchar, varchar, int, varchar, varchar, varchar) IS
  'HTML 자사 양식 생성 — html_hyg_NNN 또는 tml_ccp_chk_NNN. 사용양식 usr, 기본 주기는 카탈로그';

-- ------------------------------------------------------------
-- 6. 양식명 — 버전·카탈로그·사용양식 동기. 예시는 거부
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_tbl_html_form_ver_nm_u_000(varchar, varchar, int, varchar, varchar);
CREATE PROCEDURE sp_tbl_html_form_ver_nm_u_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_tmpl_cd: 자사 양식코드
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
    IF COALESCE(p_tmpl_cd, '') IN ('html_hyg_000', 'html_sys_001', 'tml_ccp_chk_000', 'html_sys_006')
       OR COALESCE(p_ver_no, 0) <= 0 THEN
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
-- 7. 삭제 차단 — 예시·없는 행·작성 문서·예정 과제. 주기 행만으로는 막지 않는다
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
    IF COALESCE(p_tmpl_cd, '') IN ('html_hyg_000', 'html_sys_001', 'tml_ccp_chk_000', 'html_sys_006')
       OR COALESCE(p_ver_no, 0) <= 0 THEN
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
-- 8. 삭제 — 주기·사용양식 정리 + 버전 소프트 삭제
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
    IF COALESCE(p_tmpl_cd, '') IN ('html_hyg_000', 'html_sys_001', 'tml_ccp_chk_000', 'html_sys_006')
       OR COALESCE(p_ver_no, 0) <= 0 THEN
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
-- 9. 문서주기 좌측 — html_sys_001·006·hyg_000·ccp_000 숨김, 자사 001+ 포함
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
            ct.tmpl_cd ~ '^html_sys_0(0[2-57-9]|10|12)$'
         OR (ct.tmpl_cd ~ '^html_hyg_[0-9]{3}$' AND ct.tmpl_cd <> 'html_hyg_000')
         OR (ct.tmpl_cd ~ '^tml_ccp_chk_[0-9]{3}$' AND ct.tmpl_cd <> 'tml_ccp_chk_000')
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
  '문서주기관리 좌측 — html_sys_002~005·007~010·012 · html_hyg_001+ · tml_ccp_chk_001+ · hwp_sys_001~027 · hwp_usr_*. html_sys_001·006·예시 000 숨김';
