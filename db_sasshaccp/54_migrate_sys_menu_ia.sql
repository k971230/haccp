-- ============================================================
-- 54 — 시스템 메뉴 IA: company 숨김, user/dept → menu-sys-auth
--
-- 개발자: 박승우
-- 일자: 2026-08-12
-- 코멘트:
--   1) company-management 화면·메뉴를 숨긴다 (온보딩 외 사용자 메뉴 아님)
--   2) 사용자·부서 leaf를 기초정보에서 시스템(menu-sys-auth)으로 옮긴다
--   3) sort_no 인코딩을 재적용한다
-- ============================================================

SET search_path TO sasshaccp;

-- 회사정보 화면·메뉴 숨김
UPDATE tbl_screen
   SET use_yn = 'N', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd = 'company-management';

UPDATE tbl_menu
   SET use_yn = 'N', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd = 'company-management'
    OR menu_cd IN ('menu-company-management', 'company-management');

-- 사용자·부서 → 시스템 권한·메뉴·코드 중분류
UPDATE tbl_menu
   SET h_menu_cd = 'menu-sys-auth',
       upd_id = 'system',
       upd_dt = now()
 WHERE use_yn = 'Y'
   AND (
     scrn_cd IN ('user-management', 'department-management')
     OR menu_cd IN ('menu-user-management', 'menu-department-management')
   );

-- 중분류 표시명 — 사용자·부서 포함
UPDATE tbl_menu
   SET menu_nm = '권한·사용자·코드',
       upd_id = 'system',
       upd_dt = now()
 WHERE menu_cd = 'menu-sys-auth'
   AND use_yn = 'Y';

CALL sp_tbl_menu_sort_encode_u_000(NULL);

-- 공통코드: 대분류 헤더 조회
CREATE OR REPLACE FUNCTION sp_tbl_code_group_r_000(
    p_co_cd varchar
)
RETURNS TABLE(
    idx     bigint,
    co_cd   varchar,
    main_cd varchar,
    sub_cd  varchar,
    code_nm varchar,
    sort_no int,
    sys_yn  varchar,
    use_yn  varchar
) LANGUAGE sql AS $$
    SELECT c.idx, c.co_cd, c.main_cd, c.sub_cd, c.code_nm, c.sort_no, c.sys_yn, c.use_yn
      FROM tbl_code c
     WHERE c.co_cd IN (p_co_cd, '0000')
       AND c.sub_cd = '*'
       AND NOT (c.co_cd = '0000' AND EXISTS (
                SELECT 1 FROM tbl_code o
                 WHERE o.co_cd = p_co_cd AND o.main_cd = c.main_cd AND o.sub_cd = '*'))
     ORDER BY c.main_cd, c.sort_no;
$$;
COMMENT ON FUNCTION sp_tbl_code_group_r_000(varchar) IS '공통코드 대분류(sub_cd=*) 목록 — 플랫폼+업체 병합';

-- 공통코드: 세부 (exact main + sys 필터)
CREATE OR REPLACE FUNCTION sp_tbl_code_detail_r_000(
    p_co_cd   varchar,
    p_main_cd varchar,
    p_sys_yn  varchar
)
RETURNS TABLE(
    idx     bigint,
    co_cd   varchar,
    main_cd varchar,
    sub_cd  varchar,
    code_nm varchar,
    sort_no int,
    ref1    varchar,
    ref2    varchar,
    sys_yn  varchar,
    use_yn  varchar
) LANGUAGE sql AS $$
    SELECT c.idx, c.co_cd, c.main_cd, c.sub_cd, c.code_nm, c.sort_no, c.ref1, c.ref2, c.sys_yn, c.use_yn
      FROM tbl_code c
     WHERE c.co_cd IN (p_co_cd, '0000')
       AND c.main_cd = p_main_cd
       AND c.sub_cd <> '*'
       AND (
            COALESCE(p_sys_yn, '') = ''
            OR c.sys_yn IN (p_sys_yn, CASE WHEN p_sys_yn = 'Y' THEN 'sys' WHEN p_sys_yn = 'N' THEN 'usr' ELSE p_sys_yn END)
            OR (p_sys_yn IN ('Y', 'sys') AND c.sys_yn IN ('Y', 'sys'))
            OR (p_sys_yn IN ('N', 'usr') AND c.sys_yn IN ('N', 'usr'))
           )
       AND NOT (c.co_cd = '0000' AND EXISTS (
                SELECT 1 FROM tbl_code o
                 WHERE o.co_cd = p_co_cd AND o.main_cd = c.main_cd AND o.sub_cd = c.sub_cd))
     ORDER BY c.sort_no, c.sub_cd;
$$;
COMMENT ON FUNCTION sp_tbl_code_detail_r_000(varchar, varchar, varchar) IS '공통코드 세부 — main_cd 일치, sys_yn(Y/sys·N/usr) 필터';

-- 공통코드 저장 — 시스템 코드는 코드명·사용여부만 허용 (0000이면 업체 오버라이드)
CREATE OR REPLACE PROCEDURE sp_tbl_code_c_000(
    p_co_cd   varchar,
    p_idx     bigint,
    p_main_cd varchar,
    p_sub_cd  varchar,
    p_code_nm varchar,
    p_sort_no int,
    p_ref1    varchar,
    p_ref2    varchar,
    p_use_yn  varchar,
    p_id      varchar,
    p_type    varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_sys_yn varchar(10);
    v_co     varchar(10);
    v_main   varchar(40);
    v_sub    varchar(40);
    v_cnt    int;
    v_is_sys boolean;
BEGIN
    IF p_co_cd = '0000' THEN
        RAISE EXCEPTION '플랫폼 표준코드 회사로는 저장할 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    IF p_type = 'C' THEN
        SELECT COUNT(*) INTO v_cnt FROM tbl_code
         WHERE co_cd = p_co_cd AND main_cd = p_main_cd AND sub_cd = p_sub_cd;
        IF v_cnt > 0 THEN
            RAISE EXCEPTION '이미 등록된 코드입니다: % / %', p_main_cd, p_sub_cd USING ERRCODE = '45000';
        END IF;
        INSERT INTO tbl_code(co_cd, main_cd, sub_cd, code_nm, sort_no, ref1, ref2, sys_yn, use_yn, ins_id, ins_dt)
        VALUES (p_co_cd, p_main_cd, p_sub_cd, p_code_nm, COALESCE(p_sort_no, 0),
                p_ref1, p_ref2, 'N', COALESCE(NULLIF(p_use_yn, ''), 'Y'), p_id, now());
        RETURN;
    END IF;

    -- 수정: 업체 행 우선, 없으면 플랫폼(0000) 행
    SELECT sys_yn, co_cd, main_cd, sub_cd
      INTO v_sys_yn, v_co, v_main, v_sub
      FROM tbl_code
     WHERE idx = p_idx
       AND co_cd IN (p_co_cd, '0000')
     ORDER BY CASE WHEN co_cd = p_co_cd THEN 0 ELSE 1 END
     LIMIT 1;

    IF v_sys_yn IS NULL THEN
        RAISE EXCEPTION '수정할 코드를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    v_is_sys := v_sys_yn IN ('Y', 'y', 'sys');

    IF v_is_sys THEN
        -- 시스템: 코드명·사용여부만. 0000이면 업체 오버라이드 INSERT/UPDATE
        IF v_co = '0000' THEN
            INSERT INTO tbl_code(co_cd, main_cd, sub_cd, code_nm, sort_no, ref1, ref2, sys_yn, use_yn, ins_id, ins_dt)
            SELECT p_co_cd, c.main_cd, c.sub_cd, COALESCE(NULLIF(p_code_nm, ''), c.code_nm),
                   c.sort_no, c.ref1, c.ref2, c.sys_yn,
                   COALESCE(NULLIF(p_use_yn, ''), c.use_yn), p_id, now()
              FROM tbl_code c WHERE c.idx = p_idx
            ON CONFLICT (co_cd, main_cd, sub_cd) DO UPDATE SET
                code_nm = EXCLUDED.code_nm,
                use_yn  = EXCLUDED.use_yn,
                upd_id  = p_id,
                upd_dt  = now();
        ELSE
            UPDATE tbl_code
               SET code_nm = COALESCE(NULLIF(p_code_nm, ''), code_nm),
                   use_yn  = COALESCE(NULLIF(p_use_yn, ''), use_yn),
                   upd_id  = p_id,
                   upd_dt  = now()
             WHERE co_cd = p_co_cd AND idx = p_idx;
        END IF;
        RETURN;
    END IF;

    -- 사용자 코드: 업체 행만 전체 필드 수정
    IF v_co <> p_co_cd THEN
        RAISE EXCEPTION '수정할 코드를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    UPDATE tbl_code
       SET code_nm = p_code_nm,
           sort_no = COALESCE(p_sort_no, sort_no),
           ref1    = p_ref1,
           ref2    = p_ref2,
           use_yn  = COALESCE(NULLIF(p_use_yn, ''), use_yn),
           upd_id  = p_id,
           upd_dt  = now()
     WHERE co_cd = p_co_cd AND idx = p_idx;
END$$;
COMMENT ON PROCEDURE sp_tbl_code_c_000(varchar, bigint, varchar, varchar, varchar, int, varchar, varchar, varchar, varchar, varchar) IS
  '공통코드 저장 — 사용자 CRUD, 시스템은 코드명·사용여부만(0000은 업체 오버라이드)';
