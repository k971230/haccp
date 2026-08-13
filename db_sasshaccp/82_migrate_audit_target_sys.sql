-- ============================================================
--  migrate 82 — 시스템 관리 5화면을 감사 대상(audit-target)에 등록
--
--  개발자: 박승우
--  일자: 2026-08-13
--  코멘트:
--    1) 지금까지 감사 이력은 문서함·문서 파일만 대상이었다. 공통코드·메뉴·권한·부서·사용자
--       저장/삭제도 tbl_audit_log에 남기기로 하여 대상 코드 6건을 추가한다
--       (권한 화면은 그룹 행 tbl_role, 화면권한 tbl_role_screen 두 대상을 갖는다)
--    2) sub_cd = 대상 테이블명, ref1 = 화면코드다. sp_audit_log_r_000이 sub_cd로 표시명을 붙이고
--       ref1로 좌측 메뉴 트리 선택값을 매칭하므로 tbl_menu.scrn_cd와 철자가 같아야 한다
--    3) 코드는 co_cd 완전 고유 격리라 표준(0000)에 넣은 뒤 전 업체로 복제해야 화면에 보인다
--       복제는 13_sp_platform.sql의 sp_tbl_company_code_copy_c_000 정본을 그대로 쓴다
--    4) 이미 가진 (main_cd, sub_cd)는 건드리지 않는다 — 몇 번 실행해도 결과가 같다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 표준코드(0000)에 감사 대상 6건 추가
--    sys_yn = Y — 업체가 수정·삭제할 수 없는 시스템 코드다
-- ------------------------------------------------------------
INSERT INTO tbl_code (co_cd, main_cd, sub_cd, code_nm, sort_no, ref1, sys_yn, ins_id) VALUES
    ('0000', 'audit-target', 'tbl_code',        '공통코드 관리', 3, 'common-code-management', 'Y', 'system'),
    ('0000', 'audit-target', 'tbl_menu',        '메뉴 관리',     4, 'menu-management',        'Y', 'system'),
    ('0000', 'audit-target', 'tbl_role',        '권한그룹 관리', 5, 'role-management',        'Y', 'system'),
    ('0000', 'audit-target', 'tbl_role_screen', '화면 권한',     6, 'role-management',        'Y', 'system'),
    ('0000', 'audit-target', 'tbl_dept',        '부서 관리',     7, 'department-management',  'Y', 'system'),
    ('0000', 'audit-target', 'tbl_user',        '사용자 관리',   8, 'user-management',        'Y', 'system')
ON CONFLICT (co_cd, main_cd, sub_cd) DO NOTHING;

-- ------------------------------------------------------------
-- 2. 사용 중인 전 업체로 복제 — 0000은 원본이라 대상에서 뺀다
-- ------------------------------------------------------------
DO $$
DECLARE
    v_co record;
BEGIN
    FOR v_co IN
        SELECT co_cd FROM tbl_company WHERE co_cd <> '0000' ORDER BY co_cd
    LOOP
        CALL sp_tbl_company_code_copy_c_000(v_co.co_cd, 'system');
        RAISE NOTICE '감사 대상 코드 복제 완료 — co_cd=%', v_co.co_cd;
    END LOOP;
END$$;

-- ------------------------------------------------------------
-- 3. 검증용 — 업체별 감사 대상 코드. 업체마다 헤더(*) 포함 9건이어야 정상이다
-- ------------------------------------------------------------
SELECT co_cd, count(*) AS target_cnt
  FROM tbl_code
 WHERE main_cd = 'audit-target'
 GROUP BY co_cd
 ORDER BY co_cd;
