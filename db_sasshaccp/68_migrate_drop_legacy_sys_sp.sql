-- ============================================================
--  migrate 68 — 레거시 시스템 관리 SP 폐기 (맨 마지막에 실행)
--
--  개발자: 박승우
--  일자: 2026-08-12
--  코멘트:
--    1) 62~67의 화면명 SP로 백엔드·프론트를 모두 교체하고 회귀까지 통과한 뒤에만 실행한다
--       먼저 실행하면 사이드바(menu)·전역 콤보(code)·로그인 버튼 권한(role_screen)이 즉시 마비된다
--    2) 이 파일을 실행하지 않는 것만으로 구 SP 경로 롤백이 성립한다 — 62~67은 구 SP를 건드리지 않는다
--    3) 여기서 지우는 것은 "화면이 부르던 SP"뿐이다. 적재·배치·온보딩 SP는 화면 SP가 아니므로 남긴다
--       유지: sp_tbl_user_login_r_000/_u_000 · sp_tbl_login_log_c_000/_u_000 · sp_tbl_audit_log_c_000
--             sp_tbl_view_log_c_000/_d_000 · sp_tbl_view_stat_daily_c_000 · sp_tbl_grid_pref_*
--             sp_tbl_menu_sort_encode_u_000 · sp_tbl_company_r_000/_u_000
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 시스템 관리 허브 — 화면별 SP로 분해되어 호출부가 사라졌다
--    system_c_000이 CALL하던 sp_tbl_company_u_000은 온보딩이 계속 쓰므로 남긴다
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_tbl_system_c_000(varchar, varchar, jsonb, varchar);
DROP PROCEDURE IF EXISTS sp_tbl_system_d_000(varchar, varchar, bigint, varchar);
DROP FUNCTION  IF EXISTS sp_tbl_system_delete_blocker_r_000(varchar, varchar, bigint[]);

-- ------------------------------------------------------------
-- 2. 사용자 — sp_tbl_user_mgmt_* 로 교체
-- ------------------------------------------------------------
DROP FUNCTION  IF EXISTS sp_tbl_user_r_000(varchar, varchar, varchar, varchar, varchar);
DROP PROCEDURE IF EXISTS sp_tbl_user_c_000(varchar, bigint, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar);
DROP PROCEDURE IF EXISTS sp_tbl_user_d_000(varchar, bigint);

-- ------------------------------------------------------------
-- 3. 부서 — sp_tbl_dept_mgmt_* 로 교체
-- ------------------------------------------------------------
DROP FUNCTION  IF EXISTS sp_tbl_dept_r_000(varchar, varchar, varchar);
DROP PROCEDURE IF EXISTS sp_tbl_dept_c_000(varchar, bigint, varchar, varchar, varchar, int, varchar, varchar, varchar);
DROP PROCEDURE IF EXISTS sp_tbl_dept_d_000(varchar, bigint);

-- ------------------------------------------------------------
-- 4. 권한그룹·화면권한 — sp_tbl_role_mgmt_* / _screen_* 로 교체
--    role_screen_r_000은 로그인 직후 버튼 권한도 쓰던 공유 SP다. AuthMapper 교체 확인 후 실행할 것
-- ------------------------------------------------------------
DROP FUNCTION  IF EXISTS sp_tbl_role_r_000(varchar, varchar);
DROP PROCEDURE IF EXISTS sp_tbl_role_c_000(varchar, bigint, varchar, varchar, varchar, varchar, varchar);
DROP FUNCTION  IF EXISTS sp_tbl_role_screen_r_000(varchar, varchar);
DROP PROCEDURE IF EXISTS sp_tbl_role_screen_c_000(varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar);

-- ------------------------------------------------------------
-- 5. 메뉴 — sp_tbl_menu_mgmt_* (관리화면) / sp_tbl_menu_nav_r_000 (사이드바) 로 분리 교체
--    menu_r_000은 사이드바 공유 SP다. MenuMapper 교체 확인 후 실행할 것
-- ------------------------------------------------------------
DROP FUNCTION  IF EXISTS sp_tbl_menu_r_000(varchar, varchar);
DROP FUNCTION  IF EXISTS sp_tbl_menu_admin_r_000(varchar);
DROP PROCEDURE IF EXISTS sp_tbl_menu_c_000(varchar, bigint, varchar, varchar, varchar, varchar, int, varchar, varchar);

-- ------------------------------------------------------------
-- 6. 공통코드 — sp_tbl_common_code_* 로 교체
--    code_r_000은 전 화면 콤보 공유 SP다. CodeMapper 교체 확인 후 실행할 것
-- ------------------------------------------------------------
DROP FUNCTION  IF EXISTS sp_tbl_code_r_000(varchar, varchar, varchar);
DROP PROCEDURE IF EXISTS sp_tbl_code_c_000(varchar, bigint, varchar, varchar, varchar, int, varchar, varchar, varchar, varchar, varchar);
DROP PROCEDURE IF EXISTS sp_tbl_code_d_000(varchar, bigint);
DROP FUNCTION  IF EXISTS sp_tbl_code_group_r_000(varchar);
DROP FUNCTION  IF EXISTS sp_tbl_code_detail_r_000(varchar, varchar, varchar);

-- ------------------------------------------------------------
-- 7. 로그 3화면 조회 — sp_tbl_login_history_r_000 · _audit_history_r_000 · _screen_usage_r_000 로 교체
--    같은 이름의 _c_000(적재)·_u_000은 화면 SP가 아니므로 남긴다
-- ------------------------------------------------------------
DROP FUNCTION  IF EXISTS sp_tbl_login_log_r_000(varchar, varchar, varchar, varchar, varchar);
DROP FUNCTION  IF EXISTS sp_tbl_audit_log_r_000(varchar, varchar, varchar, varchar, varchar, varchar);
DROP FUNCTION  IF EXISTS sp_tbl_view_stat_daily_r_000(varchar, varchar, varchar, varchar);
