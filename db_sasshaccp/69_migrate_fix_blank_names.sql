-- ------------------------------------------------------------
-- 69_migrate_fix_blank_names.sql
-- 역할 — 저장 SP가 필수명을 빈 문자열로 덮어써 생긴 공백 데이터를 정본 값으로 되돌린다
--        (원인 차단은 62~66 저장 SP의 필수명 가드에서 처리)
-- 대상 — tbl_user.admin(user_nm·usrgrp_cd) / tbl_role.ADMIN(usrgrp_nm) / tbl_menu.today-tasks(menu_nm·scrn_cd)
-- 재실행 — 공백인 행만 갱신하므로 몇 번 실행해도 결과가 같다
-- 개발자: 박승우
-- 일자: 2026-08-12
-- ------------------------------------------------------------
SET search_path TO sasshaccp;

-- 관리자 계정 — usrgrp_cd가 비면 tbl_role_screen 조인이 끊겨 좌측 메뉴가 통째로 사라진다
UPDATE tbl_user
   SET user_nm   = CASE WHEN COALESCE(trim(user_nm), '')   = '' THEN '시스템관리자' ELSE user_nm   END,
       usrgrp_cd = CASE WHEN COALESCE(trim(usrgrp_cd), '') = '' THEN 'ADMIN'        ELSE usrgrp_cd END,
       upd_id = 'system', upd_dt = now()
 WHERE user_id = 'admin'
   AND (COALESCE(trim(user_nm), '') = '' OR COALESCE(trim(usrgrp_cd), '') = '');

-- 권한그룹명 — 13_sp_platform.sql 최초 시드 값과 동일하게 복원
UPDATE tbl_role
   SET usrgrp_nm = 'HACCP 관리자', upd_id = 'system', upd_dt = now()
 WHERE usrgrp_cd = 'ADMIN' AND COALESCE(trim(usrgrp_nm), '') = '';

-- 오늘 할 일 메뉴 — 52_migrate_menu_tier3_kebab.sql 시드 값과 동일하게 복원
UPDATE tbl_menu
   SET menu_nm = '오늘 할 일',
       scrn_cd = COALESCE(NULLIF(trim(scrn_cd), ''), 'today-tasks'),
       upd_id = 'system', upd_dt = now()
 WHERE menu_cd = 'today-tasks' AND COALESCE(trim(menu_nm), '') = '';
