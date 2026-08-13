-- ============================================================
-- 80_migrate_drop_sp_tbl_sys.sql
--   sys 6도메인 구 SP(sp_tbl_*) 29개 폐기 + 서명 경로 컬럼 4개 폐기
--
-- 개발자: 박승우
-- 일자: 2026-08-12
-- 코멘트:
--   1) 화면명 규약 신규 SP(72~78)로 전량 대체된 구 SP를 지우고, 서명 파일경로 컬럼도 함께 지운다
--   2) 회귀 테스트(8화면 CUD·사이드바·전역 콤보·로그인 권한·서명 업로드/조회/삭제·CCP 행 서명·결재 스냅샷)를
--      전부 통과한 뒤 최후단에서 1회 실행한다. 이 파일 실행 전까지는 sign_path가 남아 있어 롤백이 가능하다
--   3) 재실행 안전 — 모든 문장이 IF EXISTS다. 이미 지워진 대상은 조용히 건너뛴다
--
-- 선행 조건 (반드시 확인)
--   - 72~79 적용 완료
--   - 백엔드 Mapper XML 12개가 신규 SP명을 호출 (grep으로 sp_tbl_{sys} 잔존 0건)
--   - tbl_user.sign_img 이관 완료 (71b) — sign_path만 있고 sign_img가 빈 사용자가 없어야 한다
-- ============================================================

-- ------------------------------------------------------------
-- 0. 안전 가드 — 서명 이관 누락이 있으면 여기서 멈춘다
--    sign_path는 있는데 sign_img가 비었으면 서명 원본이 사라지므로 DROP을 진행하지 않는다
-- ------------------------------------------------------------
DO $$
DECLARE
    -- 이관 누락 사용자 수 — 0이어야 정상
    v_miss int;
BEGIN
    SELECT count(*) INTO v_miss
      FROM tbl_user
     WHERE COALESCE(sign_path, '') <> ''
       AND sign_img IS NULL;
    IF v_miss > 0 THEN
        RAISE EXCEPTION '서명 이관이 끝나지 않았습니다. sign_img가 비어 있는 사용자 %명 — 71b를 먼저 적용하세요.', v_miss
          USING ERRCODE = '45000';
    END IF;
END $$;

-- ------------------------------------------------------------
-- 1. 공통코드 관리 — sp_common_code_management_* 로 대체
-- ------------------------------------------------------------
DROP FUNCTION  IF EXISTS sp_tbl_common_code_r_000(varchar, varchar, varchar);
DROP FUNCTION  IF EXISTS sp_tbl_common_code_r_001(varchar, varchar, varchar, varchar);
DROP PROCEDURE IF EXISTS sp_tbl_common_code_c_000(varchar, bigint, varchar, varchar, varchar, integer, varchar, varchar, varchar, varchar);
DROP PROCEDURE IF EXISTS sp_tbl_common_code_d_000(varchar, bigint);
DROP FUNCTION  IF EXISTS sp_tbl_common_code_delete_blocker_r_000(varchar, bigint[]);

-- ------------------------------------------------------------
-- 2. 메뉴 관리 + 사이드바 — sp_menu_management_* / sp_menu_nav_r_000 로 대체
-- ------------------------------------------------------------
DROP FUNCTION  IF EXISTS sp_tbl_menu_mgmt_r_000(varchar, varchar, varchar, varchar);
DROP PROCEDURE IF EXISTS sp_tbl_menu_mgmt_c_000(varchar, bigint, varchar, varchar, varchar, varchar, integer, varchar, varchar);
DROP PROCEDURE IF EXISTS sp_tbl_menu_mgmt_d_000(varchar, bigint);
DROP FUNCTION  IF EXISTS sp_tbl_menu_mgmt_delete_blocker_r_000(varchar, bigint[]);
DROP FUNCTION  IF EXISTS sp_tbl_menu_nav_r_000(varchar, varchar);

-- ------------------------------------------------------------
-- 3. 권한그룹 관리 + 화면권한 — sp_role_management_* 로 대체
--    화면권한 조회는 로그인 인증 경로도 쓰므로 로그인 회귀 확인 후에만 지운다
-- ------------------------------------------------------------
DROP FUNCTION  IF EXISTS sp_tbl_role_mgmt_r_000(varchar, varchar, varchar, varchar);
DROP PROCEDURE IF EXISTS sp_tbl_role_mgmt_c_000(varchar, bigint, varchar, varchar, varchar, varchar, varchar);
DROP PROCEDURE IF EXISTS sp_tbl_role_mgmt_d_000(varchar, bigint);
DROP FUNCTION  IF EXISTS sp_tbl_role_mgmt_delete_blocker_r_000(varchar, bigint[]);
DROP FUNCTION  IF EXISTS sp_tbl_role_mgmt_screen_r_000(varchar, varchar);
DROP PROCEDURE IF EXISTS sp_tbl_role_mgmt_screen_c_000(varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar);

-- ------------------------------------------------------------
-- 4. 부서 관리 — sp_department_management_* 로 대체
-- ------------------------------------------------------------
DROP FUNCTION  IF EXISTS sp_tbl_dept_mgmt_r_000(varchar, varchar, varchar, varchar);
DROP PROCEDURE IF EXISTS sp_tbl_dept_mgmt_c_000(varchar, bigint, varchar, varchar, varchar, integer, varchar, varchar);
DROP PROCEDURE IF EXISTS sp_tbl_dept_mgmt_d_000(varchar, bigint);
DROP FUNCTION  IF EXISTS sp_tbl_dept_mgmt_delete_blocker_r_000(varchar, bigint[]);

-- ------------------------------------------------------------
-- 5. 사용자 관리 + 서명 — sp_user_management_* 로 대체
--    구 서명 SP는 파일경로(varchar)를 주고받았고 신규는 bytea다
-- ------------------------------------------------------------
DROP FUNCTION  IF EXISTS sp_tbl_user_mgmt_r_000(varchar, varchar, varchar, varchar, varchar);
DROP PROCEDURE IF EXISTS sp_tbl_user_mgmt_c_000(varchar, bigint, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar);
DROP PROCEDURE IF EXISTS sp_tbl_user_mgmt_d_000(varchar, bigint);
DROP FUNCTION  IF EXISTS sp_tbl_user_mgmt_delete_blocker_r_000(varchar, bigint[]);
DROP FUNCTION  IF EXISTS sp_tbl_user_mgmt_sign_r_000(varchar, varchar);
DROP PROCEDURE IF EXISTS sp_tbl_user_mgmt_sign_u_000(varchar, varchar, varchar, varchar);

-- ------------------------------------------------------------
-- 6. 로그 3화면 — sp_login_history_r_000 / sp_audit_log_r_000 / sp_screen_usage_statistics_r_000 로 대체
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_login_history_r_000(varchar, varchar, varchar, varchar, varchar);
DROP FUNCTION IF EXISTS sp_tbl_audit_history_r_000(varchar, varchar, varchar, varchar, varchar, varchar);
DROP FUNCTION IF EXISTS sp_tbl_screen_usage_r_000(varchar, varchar, varchar, varchar);

-- ------------------------------------------------------------
-- 7. 서명 파일경로 컬럼 폐기 — bytea 전환 완료 후 잔재 제거
--    tbl_user는 sign_img로 이관됐고, 결재·CCP 스냅샷은 저장 SP가 bytea로 복사한다
-- ------------------------------------------------------------
ALTER TABLE tbl_user                     DROP COLUMN IF EXISTS sign_path;
ALTER TABLE tbl_document_approval        DROP COLUMN IF EXISTS sign_path;
ALTER TABLE tbl_ccp_cold_monitor_row     DROP COLUMN IF EXISTS sign_path;
ALTER TABLE tbl_ccp_generic_monitor_row  DROP COLUMN IF EXISTS sign_path;

-- ------------------------------------------------------------
-- 8. 결과 확인 — 구 SP 0건, sign_path 컬럼 0건이어야 한다
-- ------------------------------------------------------------
DO $$
DECLARE
    -- 남은 구 sys SP 수
    v_sp int;
    -- 남은 sign_path 컬럼 수
    v_col int;
BEGIN
    SELECT count(*) INTO v_sp
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'sasshaccp'
       AND (p.proname LIKE 'sp_tbl_common_code%'
         OR p.proname LIKE 'sp_tbl_menu_mgmt%'
         OR p.proname = 'sp_tbl_menu_nav_r_000'
         OR p.proname LIKE 'sp_tbl_role_mgmt%'
         OR p.proname LIKE 'sp_tbl_dept_mgmt%'
         OR p.proname LIKE 'sp_tbl_user_mgmt%'
         OR p.proname IN ('sp_tbl_login_history_r_000', 'sp_tbl_audit_history_r_000', 'sp_tbl_screen_usage_r_000'));

    SELECT count(*) INTO v_col
      FROM information_schema.columns
     WHERE table_schema = 'sasshaccp'
       AND column_name = 'sign_path';

    RAISE NOTICE '잔존 구 sys SP=%, 잔존 sign_path 컬럼=%', v_sp, v_col;
    IF v_sp > 0 THEN
        RAISE EXCEPTION '구 sys SP가 %건 남았습니다. 시그니처를 확인해 DROP 문을 보완하세요.', v_sp USING ERRCODE = '45000';
    END IF;
END $$;
