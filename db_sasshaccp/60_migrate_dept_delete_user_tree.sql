-- ============================================================
-- 60_migrate_dept_delete_user_tree.sql
-- 부서 삭제 — 사용자 사용중·하위부서(사용자 사용중 포함) 차단 강화
--
-- 개발자: 박승우
-- 일자: 2026-08-12
-- 코멘트:
--   1) tbl_user.dept_cd에 직접 묶인 부서는 삭제 불가
--   2) 하위 트리에 사용자가 있는 상위 부서도 삭제 불가
--   3) 직속 하위 부서가 있어도 삭제 불가 (기존) — blocker·삭제 SP 이중 검사
-- ============================================================
SET search_path TO sasshaccp, public;

-- ------------------------------------------------------------
-- 1) 삭제 전 참조 차단 — 부서: 사용자 > 하위트리 사용자 > 하위 부서
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_system_delete_blocker_r_000(
    p_co_cd varchar,
    p_type varchar,
    p_idxs bigint[]
) RETURNS TABLE(ref_key varchar, target varchar) LANGUAGE plpgsql AS $$
BEGIN
    IF p_type = 'department-management' THEN
        RETURN QUERY
        SELECT d.dept_cd::varchar AS ref_key,
               CASE
                   -- 이 부서를 쓰는 사용자
                   WHEN EXISTS (
                       SELECT 1 FROM tbl_user u
                        WHERE u.co_cd = p_co_cd AND u.dept_cd = d.dept_cd
                   ) THEN '사용자'::varchar
                   -- 하위 부서(재귀) 중 사용자에 묶인 부서가 있으면 상위도 삭제 불가
                   WHEN EXISTS (
                       WITH RECURSIVE sub AS (
                           SELECT c.dept_cd
                             FROM tbl_dept c
                            WHERE c.co_cd = p_co_cd
                              AND c.h_dept_cd = d.dept_cd
                           UNION ALL
                           SELECT c2.dept_cd
                             FROM tbl_dept c2
                             INNER JOIN sub s ON s.dept_cd = c2.h_dept_cd
                            WHERE c2.co_cd = p_co_cd
                       )
                       SELECT 1
                         FROM sub s
                         INNER JOIN tbl_user u
                                 ON u.co_cd = p_co_cd
                                AND u.dept_cd = s.dept_cd
                   ) THEN '하위 부서 사용자'::varchar
                   -- 직속·존재 하위 부서
                   WHEN EXISTS (
                       SELECT 1 FROM tbl_dept c
                        WHERE c.co_cd = p_co_cd AND c.h_dept_cd = d.dept_cd
                   ) THEN '하위 부서'::varchar
               END AS target
          FROM tbl_dept d
         WHERE d.co_cd = p_co_cd
           AND d.idx = ANY(p_idxs)
           AND (
                EXISTS (SELECT 1 FROM tbl_user u WHERE u.co_cd = p_co_cd AND u.dept_cd = d.dept_cd)
             OR EXISTS (
                    WITH RECURSIVE sub AS (
                        SELECT c.dept_cd
                          FROM tbl_dept c
                         WHERE c.co_cd = p_co_cd AND c.h_dept_cd = d.dept_cd
                        UNION ALL
                        SELECT c2.dept_cd
                          FROM tbl_dept c2
                          INNER JOIN sub s ON s.dept_cd = c2.h_dept_cd
                         WHERE c2.co_cd = p_co_cd
                    )
                    SELECT 1 FROM sub s
                    INNER JOIN tbl_user u ON u.co_cd = p_co_cd AND u.dept_cd = s.dept_cd
                )
             OR EXISTS (SELECT 1 FROM tbl_dept c WHERE c.co_cd = p_co_cd AND c.h_dept_cd = d.dept_cd)
           );
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
    '시스템 관리 삭제 참조 차단 — 부서는 사용자·하위트리 사용자·하위부서';

-- ------------------------------------------------------------
-- 2) 부서 삭제 SP — Double Check (사용자·하위트리 사용자·직속 하위)
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_dept_d_000(
    p_co_cd varchar,
    p_idx   bigint
)
LANGUAGE plpgsql AS $$
DECLARE
    v_dept_cd varchar(20);
    v_cnt     int;
BEGIN
    SELECT dept_cd INTO v_dept_cd FROM tbl_dept WHERE co_cd = p_co_cd AND idx = p_idx;
    IF v_dept_cd IS NULL THEN
        RAISE EXCEPTION '삭제할 부서를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    -- 사용자관리에서 이 부서 사용 중
    SELECT COUNT(*) INTO v_cnt
      FROM tbl_user u
     WHERE u.co_cd = p_co_cd AND u.dept_cd = v_dept_cd;
    IF v_cnt > 0 THEN
        RAISE EXCEPTION '사용자가 사용 중인 부서는 삭제할 수 없습니다: %', v_dept_cd USING ERRCODE = '45000';
    END IF;

    -- 하위 부서 트리에 사용자가 있으면 상위도 삭제 불가
    WITH RECURSIVE sub AS (
        SELECT c.dept_cd
          FROM tbl_dept c
         WHERE c.co_cd = p_co_cd AND c.h_dept_cd = v_dept_cd
        UNION ALL
        SELECT c2.dept_cd
          FROM tbl_dept c2
          INNER JOIN sub s ON s.dept_cd = c2.h_dept_cd
         WHERE c2.co_cd = p_co_cd
    )
    SELECT COUNT(*) INTO v_cnt
      FROM sub s
      INNER JOIN tbl_user u ON u.co_cd = p_co_cd AND u.dept_cd = s.dept_cd;
    IF v_cnt > 0 THEN
        RAISE EXCEPTION '하위 부서에 사용자가 있어 삭제할 수 없습니다: %', v_dept_cd USING ERRCODE = '45000';
    END IF;

    -- 직속 하위 부서
    SELECT COUNT(*) INTO v_cnt FROM tbl_dept WHERE co_cd = p_co_cd AND h_dept_cd = v_dept_cd;
    IF v_cnt > 0 THEN
        RAISE EXCEPTION '하위 부서가 있어 삭제할 수 없습니다: %', v_dept_cd USING ERRCODE = '45000';
    END IF;

    DELETE FROM tbl_dept WHERE co_cd = p_co_cd AND idx = p_idx;
END$$;
COMMENT ON PROCEDURE sp_tbl_dept_d_000(varchar, bigint) IS
    '부서 삭제 — 사용자·하위트리 사용자·하위 부서 존재 시 차단';
