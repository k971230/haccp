-- ============================================================
-- 47 — 점검항목 admin CRUD · 범용 메뉴 비활성
--
-- 개발자: 박승우
-- 일자: 2026-08-10
-- 코멘트:
--   1) 회사 전용 점검항목(CUST*) 추가·삭제와 관리/작성 조회 UNION을 보강한다
--   2) template-check-item-management 화면·메뉴를 비활성한다
--   3) 위생·시설 신규 스켈레톤에 CUST 행을 포함한다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 메뉴·화면 — 범용 점검항목관리 비활성 (문서별 admin으로 대체)
-- ------------------------------------------------------------
UPDATE tbl_screen
   SET use_yn = 'N', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd = 'template-check-item-management';

UPDATE tbl_menu
   SET use_yn = 'N', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd = 'template-check-item-management'
    OR menu_cd = 'template-check-item-management';

-- 권한 행도 제거 — 사이드바에 다시 살아나지 않게 한다
DELETE FROM tbl_role_screen
 WHERE scrn_cd = 'template-check-item-management';

-- ------------------------------------------------------------
-- 2. 관리 목록 — 표준 + 회사 CUST*
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_company_check_item_manage_r_000(
    p_co_cd varchar,
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
-- 3. 저장 — 표준 오버라이드 또는 CUST 신규
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_company_check_item_c_000(
    p_co_cd      varchar,
    p_tmpl_cd    varchar,
    p_item_cd    varchar,
    p_item_nm_ovr varchar,
    p_sort_no    int,
    p_use_yn     varchar,
    p_id         varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_cnt int;
    v_item varchar(20) := trim(COALESCE(p_item_cd, ''));
    v_tmpl varchar(20) := trim(COALESCE(p_tmpl_cd, ''));
BEGIN
    IF v_tmpl = '' OR v_item = '' THEN
        RAISE EXCEPTION '양식과 점검항목 코드를 확인하세요.' USING ERRCODE = '45000';
    END IF;

    SELECT COUNT(*) INTO v_cnt
      FROM tbl_check_item
     WHERE tmpl_cd = v_tmpl AND item_cd = v_item;

    IF v_cnt = 0 THEN
        IF v_item NOT LIKE 'CUST%' THEN
            RAISE EXCEPTION '표준 점검항목에 없는 코드입니다: % / %', v_tmpl, v_item USING ERRCODE = '45000';
        END IF;
        IF NULLIF(trim(COALESCE(p_item_nm_ovr, '')), '') IS NULL THEN
            RAISE EXCEPTION '업체 전용 점검항목은 문구가 필요합니다.' USING ERRCODE = '45000';
        END IF;
    END IF;

    INSERT INTO tbl_company_check_item(co_cd, tmpl_cd, item_cd, item_nm_ovr, sort_no, use_yn, ins_id, ins_dt)
    VALUES (p_co_cd, v_tmpl, v_item, NULLIF(trim(COALESCE(p_item_nm_ovr, '')), ''), p_sort_no,
            COALESCE(NULLIF(p_use_yn, ''), 'Y'), p_id, now())
    ON CONFLICT (co_cd, tmpl_cd, item_cd) DO UPDATE SET
        item_nm_ovr = EXCLUDED.item_nm_ovr,
        sort_no     = EXCLUDED.sort_no,
        use_yn      = EXCLUDED.use_yn,
        upd_id      = p_id,
        upd_dt      = now();
END$$;
COMMENT ON PROCEDURE sp_tbl_company_check_item_c_000(varchar, varchar, varchar, varchar, int, varchar, varchar) IS
'업체 점검항목 업서트 — 표준 오버라이드 또는 CUST 회사 전용';

-- ------------------------------------------------------------
-- 4. 삭제 — CUST*만
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_company_check_item_d_000(
    p_co_cd   varchar,
    p_tmpl_cd varchar,
    p_item_cd varchar,
    p_id      varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_item varchar(20) := trim(COALESCE(p_item_cd, ''));
    v_tmpl varchar(20) := trim(COALESCE(p_tmpl_cd, ''));
BEGIN
    IF v_tmpl = '' OR v_item = '' THEN
        RAISE EXCEPTION '삭제할 점검항목을 선택하세요.' USING ERRCODE = '45000';
    END IF;
    IF v_item NOT LIKE 'CUST%' THEN
        RAISE EXCEPTION '표준 점검항목은 삭제할 수 없습니다. 표시를 숨김으로 변경하세요.' USING ERRCODE = '45000';
    END IF;
    DELETE FROM tbl_company_check_item
     WHERE co_cd = p_co_cd AND tmpl_cd = v_tmpl AND item_cd = v_item;
    IF NOT FOUND THEN
        RAISE EXCEPTION '삭제할 점검항목을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
END$$;
COMMENT ON PROCEDURE sp_tbl_company_check_item_d_000(varchar, varchar, varchar, varchar) IS
'업체 전용 점검항목 삭제 — CUST*만 허용';

-- ------------------------------------------------------------
-- 5. 작성용 점검항목 조회 — CUST 포함
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_check_item_r_000(
    p_co_cd   varchar,
    p_tmpl_cd varchar,
    p_grp_cd  varchar
)
RETURNS TABLE(
    item_cd varchar, grp_cd varchar, grp_nm varchar, item_nm varchar,
    input_type varchar, unit_nm varchar, method_nm varchar, cycle_nm varchar, sort_no int
)
LANGUAGE sql STABLE AS $$
    SELECT * FROM (
        SELECT ci.item_cd, ci.grp_cd, ci.grp_nm,
               COALESCE(cci.item_nm_ovr, ci.item_nm) AS item_nm,
               ci.input_type, ci.unit_nm, ci.method_nm, ci.cycle_nm,
               COALESCE(cci.sort_no, ci.sort_no) AS sort_no
          FROM tbl_check_item ci
          LEFT JOIN tbl_company_check_item cci
                 ON cci.co_cd = p_co_cd AND cci.tmpl_cd = ci.tmpl_cd AND cci.item_cd = ci.item_cd
         WHERE ci.tmpl_cd = p_tmpl_cd
           AND ci.use_yn = 'Y'
           AND COALESCE(cci.use_yn, 'Y') = 'Y'
           AND COALESCE(ci.grp_cd, '') LIKE CONCAT('%', COALESCE(p_grp_cd, ''), '%')
        UNION ALL
        SELECT cci.item_cd, NULL::varchar, NULL::varchar,
               COALESCE(cci.item_nm_ovr, cci.item_cd),
               'OX'::varchar, NULL::varchar, NULL::varchar, NULL::varchar,
               COALESCE(cci.sort_no, 0)
          FROM tbl_company_check_item cci
         WHERE cci.co_cd = p_co_cd
           AND cci.tmpl_cd = p_tmpl_cd
           AND cci.item_cd LIKE 'CUST%'
           AND COALESCE(cci.use_yn, 'Y') = 'Y'
           AND NOT EXISTS (
               SELECT 1 FROM tbl_check_item s
                WHERE s.tmpl_cd = cci.tmpl_cd AND s.item_cd = cci.item_cd
           )
           AND COALESCE('', '') LIKE CONCAT('%', COALESCE(p_grp_cd, ''), '%')
    ) q
    ORDER BY q.sort_no, q.item_cd;
$$;
COMMENT ON FUNCTION sp_tbl_check_item_r_000(varchar, varchar, varchar) IS
'점검항목 조회 — 표준+오버라이드+회사 CUST, 숨김 제외';

-- 위생·시설 신규 스켈레톤 CUST UNION은 19_sp_hygiene.sql / 20_sp_biz_ops.sql 본문에 반영됨.
-- 증분 적용 시 본 migrate 전에 19·20을 다시 실행하거나 apply-all을 사용한다.
