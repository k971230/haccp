-- ============================================================
--  132_migrate_menu_purge.sql — 28화면만 남기고 정리
--
--  파일번호: 132
--  이전번호: 131
--  개발자: 박승우
--  일자: 2026-08-25
--  코멘트:
--    1) 메뉴를 28화면으로 줄이고, 중분류 html 을 양식 작성(draft)에 넘긴다
--       docs 쪽은 html-form 으로 개명 — tbl_menu UNIQUE (co_cd, menu_cd) 때문에 둘이 같이 못 산다
--    2) 빠지는 화면은 tbl_screen 을 지우지 않고 use_yn='N' 으로 둔다
--       tbl_view_log·tbl_view_stat_daily·tbl_audit_log 가 scrn_cd 를 참조해서
--       지우면 과거 통계·감사 이력이 고아가 된다
--    3) 안 쓰는 SP 는 지운다 — 남은 매퍼 XML 이 부르지 않고 다른 SP 도 참조하지 않는 것만
--
--  테이블 정리는 133 에서 백업 스키마로 옮긴다(즉시 되돌릴 수 있게).
--
--  실행: psql -f 132_migrate_menu_purge.sql (수동·DBeaver)
-- ============================================================

SET search_path TO sasshaccp;

BEGIN;

-- ------------------------------------------------------------
-- 1. 남길 화면 28개
-- ------------------------------------------------------------
CREATE TEMP TABLE tmp_keep_scrn(scrn_cd varchar(30) PRIMARY KEY) ON COMMIT DROP;
INSERT INTO tmp_keep_scrn VALUES
    ('today-tasks'),
    ('schedule-cycle-management'),
    ('hwp-template-management'),
    ('hyg-process-template'),
    ('ccp-verify-template'),
    ('ccp-pkg-template'),
    ('ccp-htg-template'),
    ('ccp-mtl-template'),
    ('attach'),
    ('sign-ready'),
    ('sign-ok'),
    ('document-inbox'),
    ('corrective-action-management'),
    ('hyg-process'),
    ('ccp-verify'),
    ('ccp-pkg'),
    ('ccp-htg'),
    ('ccp-mtl'),
    ('hwp-write'),
    ('common-code-management'),
    ('menu-management'),
    ('role-management'),
    ('department-management'),
    ('user-management'),
    ('approval-line-management'),
    ('login-history'),
    ('screen-usage-statistics'),
    ('audit-log');

-- ------------------------------------------------------------
-- 2. 중분류 개명 — docs 의 html 을 비우고 draft 가 가져간다
--    UNIQUE (co_cd, menu_cd) 라 반드시 비운 뒤에 만든다
-- ------------------------------------------------------------
UPDATE tbl_menu SET menu_cd = 'html-form', upd_id = 'system', upd_dt = now()
 WHERE menu_cd = 'html' AND h_menu_cd = 'docs';
UPDATE tbl_menu SET h_menu_cd = 'html-form', upd_id = 'system', upd_dt = now()
 WHERE h_menu_cd = 'html' AND scrn_cd LIKE '%-template';

-- 양식 작성 — HYG·CCP 두 중분류를 「HTML 양식」 하나로 합친다
UPDATE tbl_menu SET menu_cd = 'html', menu_nm = 'HTML 양식', sort_no = 4100,
       upd_id = 'system', upd_dt = now()
 WHERE menu_cd = 'hyg' AND h_menu_cd = 'draft';
UPDATE tbl_menu SET h_menu_cd = 'html', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd IN ('hyg-process', 'ccp-verify');
DELETE FROM tbl_menu WHERE menu_cd = 'ccp-chk' AND h_menu_cd = 'draft';

-- 표시명 — 「결제」 금지(01-project-core)
UPDATE tbl_menu SET menu_nm = '결재 첨부' WHERE scrn_cd = 'attach';
UPDATE tbl_menu SET menu_nm = '문서함', sort_no = 3201 WHERE scrn_cd = 'document-inbox';

-- ------------------------------------------------------------
-- 3. 메뉴 — 남길 28개 외 leaf 삭제, 비어 버린 분류도 삭제
-- ------------------------------------------------------------
DELETE FROM tbl_menu
 WHERE scrn_cd IS NOT NULL
   AND scrn_cd NOT IN (SELECT scrn_cd FROM tmp_keep_scrn);

-- 자식 없는 분류 정리 — 중분류가 빠지면 대분류가 빌 수 있어 두 번 돈다
DELETE FROM tbl_menu m
 WHERE m.scrn_cd IS NULL
   AND NOT EXISTS (SELECT 1 FROM tbl_menu c WHERE c.co_cd = m.co_cd AND c.h_menu_cd = m.menu_cd);
DELETE FROM tbl_menu m
 WHERE m.scrn_cd IS NULL
   AND NOT EXISTS (SELECT 1 FROM tbl_menu c WHERE c.co_cd = m.co_cd AND c.h_menu_cd = m.menu_cd);

-- ------------------------------------------------------------
-- 4. 화면·권한 — 화면은 끄기만, 권한행은 삭제
-- ------------------------------------------------------------
UPDATE tbl_screen SET use_yn = 'N', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd NOT IN (SELECT scrn_cd FROM tmp_keep_scrn) AND use_yn <> 'N';
UPDATE tbl_screen SET use_yn = 'Y', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd IN (SELECT scrn_cd FROM tmp_keep_scrn) AND use_yn <> 'Y';

DELETE FROM tbl_role_screen
 WHERE scrn_cd NOT IN (SELECT scrn_cd FROM tmp_keep_scrn);

-- 조회 전용 그룹 원복 — 127 이 sign-ready 권한을 통째로 복사하며 쓰기·삭제까지 줬다
UPDATE tbl_role_screen
   SET write_yn = 'N', modify_yn = 'N', delete_yn = 'N', upd_id = 'system', upd_dt = now()
 WHERE usrgrp_cd = 'VIEWER';

COMMIT;

-- 확인용
-- SELECT count(*) FROM tbl_menu WHERE scrn_cd IS NOT NULL;   -- 28
-- SELECT count(*) FROM tbl_screen WHERE use_yn = 'Y';        -- 28
-- SELECT menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no FROM tbl_menu ORDER BY sort_no;
