-- ============================================================
-- 57 — 시스템 삭제 blocker varchar 캐스트 + 메뉴 use_yn=N 하위 전파
--
-- 개발자: 박승우
-- 일자: 2026-08-12
-- 코멘트:
--   1) delete_blocker RETURN QUERY text/varchar 불일치(42804)를 고친다
--   2) 메뉴 저장 시 use_yn=N이면 자손 메뉴 전체를 N으로 맞춘다
--   3) 정본 21_sp_system.sql 과 동기화한다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 삭제 참조 차단 — column2 리터럴 ::varchar
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_system_delete_blocker_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_type: 관리 유형
    p_type varchar,
    -- p_idxs: 삭제 대상 대리키 배열
    p_idxs bigint[]
) RETURNS TABLE(ref_key varchar, target varchar) LANGUAGE plpgsql AS $$
BEGIN
    IF p_type = 'department-management' THEN
        -- ::varchar — 리터럴 text와 RETURNS varchar 불일치(42804) 방지
        RETURN QUERY SELECT d.dept_cd::varchar, '하위 부서 또는 사용자'::varchar
          FROM tbl_dept d WHERE d.co_cd = p_co_cd AND d.idx = ANY(p_idxs)
           AND (EXISTS (SELECT 1 FROM tbl_dept c WHERE c.co_cd = p_co_cd AND c.h_dept_cd = d.dept_cd)
             OR EXISTS (SELECT 1 FROM tbl_user u WHERE u.co_cd = p_co_cd AND u.dept_cd = d.dept_cd));
    ELSIF p_type = 'role-management' THEN
        RETURN QUERY SELECT r.usrgrp_cd::varchar, '사용자'::varchar
          FROM tbl_role r WHERE r.co_cd = p_co_cd AND r.idx = ANY(p_idxs)
           AND EXISTS (SELECT 1 FROM tbl_user u WHERE u.co_cd = p_co_cd AND u.usrgrp_cd = r.usrgrp_cd);
    ELSIF p_type = 'menu-management' THEN
        RETURN QUERY SELECT m.menu_cd::varchar, '하위 메뉴'::varchar
          FROM tbl_menu m WHERE m.co_cd = p_co_cd AND m.idx = ANY(p_idxs)
           AND EXISTS (SELECT 1 FROM tbl_menu c WHERE c.co_cd = p_co_cd AND c.h_menu_cd = m.menu_cd);
    END IF;
END$$;
COMMENT ON FUNCTION sp_tbl_system_delete_blocker_r_000(varchar, varchar, bigint[]) IS
  '시스템 관리 삭제 참조 차단 — 부서·권한·메뉴의 종속 행을 배열 단일 조회';

-- ------------------------------------------------------------
-- 2. 메뉴 저장 — use_yn=N 시 하위 전체 N
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_menu_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_idx: 수정 대상 대리키. 신규면 NULL
    p_idx bigint,
    -- p_menu_cd: 업체 내 유일 메뉴코드
    p_menu_cd varchar,
    -- p_menu_nm: 메뉴 표시명
    p_menu_nm varchar,
    -- p_h_menu_cd: 상위 메뉴코드. 공백이면 루트
    p_h_menu_cd varchar,
    -- p_scrn_cd: 화면 leaf 코드. 공백이면 분류 노드
    p_scrn_cd varchar,
    -- p_sort_no: 같은 상위 메뉴 내 표시 순서
    p_sort_no int,
    -- p_use_yn: 사용여부
    p_use_yn varchar,
    -- p_id: JWT 작업자 ID
    p_id varchar
) LANGUAGE plpgsql AS $$
DECLARE
    -- 저장 후 자손 전파용 메뉴코드
    v_menu_cd varchar;
    -- 정규화한 사용여부
    v_use_yn  varchar;
BEGIN
    v_use_yn := upper(coalesce(nullif(trim(p_use_yn), ''), 'Y'));
    IF v_use_yn NOT IN ('Y', 'N') THEN v_use_yn := 'Y'; END IF;

    IF p_idx IS NULL THEN
        INSERT INTO tbl_menu(co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
        VALUES (p_co_cd, p_menu_cd, p_menu_nm, nullif(p_h_menu_cd, ''), nullif(p_scrn_cd, ''),
                coalesce(p_sort_no, 0), v_use_yn, p_id, now());
        v_menu_cd := p_menu_cd;
    ELSE
        UPDATE tbl_menu
           SET menu_nm = p_menu_nm, h_menu_cd = nullif(p_h_menu_cd, ''), scrn_cd = nullif(p_scrn_cd, ''),
               sort_no = coalesce(p_sort_no, sort_no), use_yn = v_use_yn,
               upd_id = p_id, upd_dt = now()
         WHERE co_cd = p_co_cd AND idx = p_idx
        RETURNING menu_cd INTO v_menu_cd;
        IF NOT FOUND THEN RAISE EXCEPTION '수정할 메뉴를 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    END IF;

    -- 사용여부 N일 때(= 메뉴관리에서 미사용) 모든 자손도 N — Y로 올릴 때는 하위 자동 변경 없음
    IF v_use_yn = 'N' AND coalesce(v_menu_cd, '') <> '' THEN
        WITH RECURSIVE descendants AS (
            SELECT m.menu_cd
              FROM tbl_menu m
             WHERE m.co_cd = p_co_cd
               AND m.h_menu_cd = v_menu_cd
            UNION ALL
            SELECT c.menu_cd
              FROM tbl_menu c
              JOIN descendants d ON c.co_cd = p_co_cd AND c.h_menu_cd = d.menu_cd
        )
        UPDATE tbl_menu t
           SET use_yn = 'N',
               upd_id = p_id,
               upd_dt = now()
          FROM descendants d
         WHERE t.co_cd = p_co_cd
           AND t.menu_cd = d.menu_cd
           AND t.use_yn IS DISTINCT FROM 'N';
    END IF;
END$$;
COMMENT ON PROCEDURE sp_tbl_menu_c_000(varchar, bigint, varchar, varchar, varchar, varchar, int, varchar, varchar) IS
  '관리자 메뉴 저장 — use_yn=N이면 하위 메뉴 전체 N 전파. 메뉴코드는 수정하지 않는다';
