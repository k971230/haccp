-- ============================================================
-- 49 — approval-history 메뉴 leaf 활성 보증 (09 G-01)
--
-- 파일번호: 49
-- 개발자: 박승우
-- 일자: 2026-08-10
-- 코멘트:
--   1) approval-history 화면·메뉴·권한을 전 회사에 활성 상태로 맞춘다 — FE·API·SP는 이미 준비됨
--   2) 36(사이드바 IA) 기준값을 정본으로 재적용한다 — module APR / sort 230 / 부모 MAPR
--   3) 재실행 안전 — 전 구문 ON CONFLICT DO UPDATE, 없으면 삽입하고 있으면 활성으로 되돌린다
--
-- 배경:
--   31·36 이 leaf를 삽입했으나 이후 운영 중 use_yn='N' 으로 남은 DB가 있을 수 있어
--   (09 G-01 "DEMO tbl_menu 활성 leaf 없을 수 있음") 상태를 강제로 수렴시킨다.
--   그래서 NOT EXISTS 가 아니라 DO UPDATE 다 — 행이 있어도 숨김이면 복구해야 하기 때문이다.
--
-- sp_tbl_company_init_c_000(13_sp_platform.sql) 은
--   WHERE s.use_yn='Y' AND s.module_cd IN ('WRK','APR','FRM','COD','SYS') 로 메뉴를 시드하므로
--   아래 (1)에서 화면을 APR·use_yn='Y' 로 확정하면 신규 회사는 자동 포함된다 — SP 변경 불필요.
-- ============================================================

SET search_path TO sasshaccp;

BEGIN;

-- ------------------------------------------------------------
-- 1. 화면 마스터 — 36 IA 값으로 활성 확정
-- ------------------------------------------------------------
-- tmpl_cd 는 결재이력이 특정 양식에 매이지 않으므로 NULL 이다
INSERT INTO tbl_screen (scrn_cd, scrn_nm, module_cd, tmpl_cd, sort_no, use_yn, ins_id, ins_dt)
VALUES ('approval-history', '결재·변경이력', 'APR', NULL, 230, 'Y', 'system', now())
ON CONFLICT (scrn_cd) DO UPDATE SET
    scrn_nm   = EXCLUDED.scrn_nm,
    module_cd = 'APR',
    sort_no   = EXCLUDED.sort_no,
    use_yn    = 'Y',
    upd_id    = 'system',
    upd_dt    = now();

-- ------------------------------------------------------------
-- 2. 부모 대메뉴 MAPR 보증 — leaf 만 살아나면 사이드바에 뜨지 않는다
-- ------------------------------------------------------------
-- 36 에서 만든 5대메뉴 중 하나 — 여기서는 숨김 상태만 되돌리고 명칭·정렬은 36 값을 그대로 쓴다
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, 'MAPR', '문서 현황·결재', NULL, NULL, 200, 'Y', 'system', now()
  FROM tbl_company c
 WHERE c.use_yn = 'Y'
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    h_menu_cd = NULL,
    scrn_cd   = NULL,
    use_yn    = 'Y',
    upd_id    = 'system',
    upd_dt    = now();

-- ------------------------------------------------------------
-- 3. 회사별 leaf — MAPR 하위 결재·변경이력
-- ------------------------------------------------------------
-- 활성 회사(use_yn='Y')만 대상 — 해지 업체 메뉴를 되살리지 않는다
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, 'approval-history', '결재·변경이력', 'MAPR', 'approval-history', 230, 'Y', 'system', now()
  FROM tbl_company c
 WHERE c.use_yn = 'Y'
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm   = EXCLUDED.menu_nm,
    h_menu_cd = 'MAPR',
    scrn_cd   = 'approval-history',
    sort_no   = EXCLUDED.sort_no,
    use_yn    = 'Y',
    upd_id    = 'system',
    upd_dt    = now();

-- ------------------------------------------------------------
-- 4. ADMIN 권한 — 조회·출력만
-- ------------------------------------------------------------
-- 결재이력은 조회 전용 화면이라 신규 부여는 read/print 만 Y 다.
-- 이미 행이 있을 때(= 36 에서 전 권한 Y로 부여됨) write/modify/delete 는 건드리지 않는다 —
-- 기존 운영 권한을 이 마이그레이션이 축소하면 안 되기 때문이다.
INSERT INTO tbl_role_screen (
    co_cd, usrgrp_cd, scrn_cd, read_yn, write_yn, modify_yn, delete_yn, print_yn, ins_id, ins_dt
)
SELECT g.co_cd, g.usrgrp_cd, 'approval-history', 'Y', 'N', 'N', 'N', 'Y', 'system', now()
  FROM tbl_role g
 WHERE g.usrgrp_cd = 'ADMIN'
   AND g.use_yn = 'Y'
ON CONFLICT (co_cd, usrgrp_cd, scrn_cd) DO UPDATE SET
    read_yn  = 'Y',
    print_yn = 'Y',
    upd_id   = 'system',
    upd_dt   = now();

COMMIT;

-- ------------------------------------------------------------
-- 검증 쿼리 (적용 후 수동 확인용)
-- ------------------------------------------------------------
-- SELECT scrn_cd, module_cd, sort_no, use_yn FROM tbl_screen  WHERE scrn_cd = 'approval-history';
-- SELECT co_cd, menu_cd, h_menu_cd, use_yn   FROM tbl_menu    WHERE menu_cd = 'approval-history';
-- SELECT co_cd, usrgrp_cd, read_yn, print_yn FROM tbl_role_screen WHERE scrn_cd = 'approval-history';
