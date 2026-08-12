-- ============================================================
-- 59_migrate_system_d_found.sql
-- sp_tbl_system_d_000 — CALL 이후 FOUND 오판으로 삭제가 실패하던 문제 수정
--
-- 개발자: 박승우
-- 일자: 2026-08-12
-- 코멘트:
--   1) nested CALL 뒤 호출자 FOUND는 하위 DELETE를 반영하지 않는다
--   2) user/dept/code는 하위 SP가 미존재를 RAISE하므로 CALL만 수행한다
--   3) company/role/menu는 직접 UPDATE/DELETE 직후에만 NOT FOUND를 검사한다
-- ============================================================
SET search_path TO sasshaccp, public;

CREATE OR REPLACE PROCEDURE sp_tbl_system_d_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_type: 관리 유형
    p_type varchar,
    -- p_idx: 삭제 대상 대리키
    p_idx bigint,
    -- p_id: JWT 작업자 ID
    p_id varchar
) LANGUAGE plpgsql AS $$
BEGIN
    IF p_type = 'company-management' THEN
        UPDATE tbl_company SET use_yn = 'N', upd_id = p_id, upd_dt = now()
         WHERE co_cd = p_co_cd AND idx = p_idx;
        IF NOT FOUND THEN
            RAISE EXCEPTION '삭제할 시스템 관리 행을 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
    ELSIF p_type = 'user-management' THEN
        -- 미존재는 sp_tbl_user_d_000이 RAISE — CALL 후 FOUND 검사 금지
        CALL sp_tbl_user_d_000(p_co_cd, p_idx);
    ELSIF p_type = 'department-management' THEN
        CALL sp_tbl_dept_d_000(p_co_cd, p_idx);
    ELSIF p_type = 'role-management' THEN
        DELETE FROM tbl_role WHERE co_cd = p_co_cd AND idx = p_idx;
        IF NOT FOUND THEN
            RAISE EXCEPTION '삭제할 시스템 관리 행을 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
    ELSIF p_type = 'menu-management' THEN
        DELETE FROM tbl_menu WHERE co_cd = p_co_cd AND idx = p_idx;
        IF NOT FOUND THEN
            RAISE EXCEPTION '삭제할 시스템 관리 행을 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
    ELSIF p_type = 'common-code-management' THEN
        CALL sp_tbl_code_d_000(p_co_cd, p_idx);
    ELSE
        RAISE EXCEPTION '지원하지 않는 시스템 관리 삭제 유형입니다.' USING ERRCODE = '45000';
    END IF;
END$$;
COMMENT ON PROCEDURE sp_tbl_system_d_000(varchar, varchar, bigint, varchar) IS
    '시스템 관리 삭제 — 회사는 비활성화, CALL 분기는 하위 SP가 미존재 검사';
