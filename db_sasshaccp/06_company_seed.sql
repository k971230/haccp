-- ============================================================
--  06_company_seed.sql — 신규 업체 개설 시드
--
--  개발자: 박승우
--  일자: 2026-08-26
--  코멘트:
--    1) 업체 하나를 「로그인해서 문서를 쓸 수 있는 상태」까지 만든다
--    2) 메뉴·권한·부서·관리자·결재선·문서번호규칙을 한 번에 깐다.
--       03(공통코드)·05(양식)는 따로 돌린다 — 이 파일은 그 둘을 대신하지 않는다
--    3) 재실행 안전 — 이미 있는 것은 건드리지 않는다(업체가 고친 값을 덮지 않는다)
--
--  왜 0000 을 베끼는가
--    메뉴 43줄·화면권한 84줄을 여기 손으로 적으면 화면이 하나 늘 때마다 두 곳을 고쳐야 한다.
--    0000(플랫폼 표준)을 원본으로 복제하면 02_seed.sql 한 곳만 정본이 된다.
--
--  적용
--    psql -v co_cd=0001 -v co_nm='업체명' -v admin_id='admin0001' -f 06_company_seed.sql
--
--    전체 순서:
--      00_ddl → 01_sp → 02_seed → 03_code_seed(-v co_cd) → 05_form_seed(-v co_cd) → 06_company_seed(-v co_cd)
--
--  초기 비밀번호
--    아래 :admin_pw 는 BCrypt 해시다. 기본값은 '1234' 의 해시이며 첫 로그인 후 반드시 바꾼다.
--    운영에서는 -v admin_pw='$2a$10$...' 로 다른 해시를 넘긴다.
-- ============================================================

SET search_path TO sasshaccp;

\if :{?co_cd}
\else
\echo '!! co_cd 를 주어야 한다 — psql -v co_cd=0001 -f 06_company_seed.sql'
\quit
\endif

\if :{?co_nm}
\else
\set co_nm '신규업체'
\endif

\if :{?admin_id}
\else
\set admin_id 'admin'
\endif

-- '1234' 의 BCrypt 해시 — 첫 로그인 후 변경 전제
\if :{?admin_pw}
\else
\set admin_pw '$2a$10$omCFk.XMhqOp5dAmMQ7Me.Rp9c0f87cCPZS3IRg1avF5PVWRzjw4O'
\endif

\if :{?src_co}
\else
\set src_co '0000'
\endif

-- 원본과 같은 코드로 돌리면 자기 자신을 베끼게 된다 — 시작 전에 막는다.
-- (psql 은 $$ ... $$ 안에서는 변수를 치환하지 않아 DO 블록으로는 검사할 수 없다)
SELECT :'co_cd' = :'src_co' AS same_co \gset
\if :same_co
\echo '!! 원본 회사코드와 같다 — 다른 co_cd 로 돌린다'
\quit
\endif

BEGIN;

-- ------------------------------------------------------------
-- 1. 회사
-- ------------------------------------------------------------
INSERT INTO tbl_company (co_cd, co_nm, co_gbn, retention_month, use_yn, ins_id, ins_dt)
SELECT :'co_cd', :'co_nm', '1', 24, 'Y', 'system', now()
 WHERE NOT EXISTS (SELECT 1 FROM tbl_company WHERE co_cd = :'co_cd');

-- ------------------------------------------------------------
-- 2. 권한그룹 — ADMIN(전권) · USER(작성) · VIEWER(조회)
--    이름·설명은 원본에서 가져온다. 세 그룹의 뜻은 플랫폼 공통이다
-- ------------------------------------------------------------
INSERT INTO tbl_role (co_cd, usrgrp_cd, usrgrp_nm, desc_rmk, use_yn, ins_id, ins_dt)
SELECT :'co_cd', s.usrgrp_cd, s.usrgrp_nm, s.desc_rmk, 'Y', 'system', now()
  FROM tbl_role s
 WHERE s.co_cd = :'src_co'
   AND NOT EXISTS (
       SELECT 1 FROM tbl_role o WHERE o.co_cd = :'co_cd' AND o.usrgrp_cd = s.usrgrp_cd
   );

-- ------------------------------------------------------------
-- 3. 메뉴 — 대·중분류 노드까지 통째로. tbl_menu 는 업체별이다
-- ------------------------------------------------------------
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT :'co_cd', s.menu_cd, s.menu_nm, s.h_menu_cd, s.scrn_cd, s.sort_no, s.use_yn, 'system', now()
  FROM tbl_menu s
 WHERE s.co_cd = :'src_co'
   AND NOT EXISTS (
       SELECT 1 FROM tbl_menu o WHERE o.co_cd = :'co_cd' AND o.menu_cd = s.menu_cd
   );

-- ------------------------------------------------------------
-- 4. 화면 권한 — 그룹 × 화면. 여기가 비면 로그인해도 아무 화면이 안 열린다
-- ------------------------------------------------------------
INSERT INTO tbl_role_screen (co_cd, usrgrp_cd, scrn_cd,
                             read_yn, write_yn, modify_yn, delete_yn, print_yn, ins_id, ins_dt)
SELECT :'co_cd', s.usrgrp_cd, s.scrn_cd,
       s.read_yn, s.write_yn, s.modify_yn, s.delete_yn, s.print_yn, 'system', now()
  FROM tbl_role_screen s
 WHERE s.co_cd = :'src_co'
   AND NOT EXISTS (
       SELECT 1 FROM tbl_role_screen o
        WHERE o.co_cd = :'co_cd' AND o.usrgrp_cd = s.usrgrp_cd AND o.scrn_cd = s.scrn_cd
   );

-- ------------------------------------------------------------
-- 5. 부서 — 최소 한 개. 사용자에게 부서가 필수라 없으면 계정을 못 만든다
-- ------------------------------------------------------------
INSERT INTO tbl_dept (co_cd, dept_cd, dept_nm, sort_no, use_yn, ins_id, ins_dt)
SELECT :'co_cd', 'HQ', '본사', 10, 'Y', 'system', now()
 WHERE NOT EXISTS (SELECT 1 FROM tbl_dept WHERE co_cd = :'co_cd' AND dept_cd = 'HQ');

-- ------------------------------------------------------------
-- 6. 초기 관리자 — user_id 는 전역 UNIQUE 다. 업체마다 다른 ID 를 준다
-- ------------------------------------------------------------
INSERT INTO tbl_user (user_id, co_cd, user_nm, user_pw, usrgrp_cd, dept_cd,
                      login_fail_cnt, lock_yn, use_yn, pw_upd_dt, ins_id, ins_dt)
SELECT :'admin_id', :'co_cd', '시스템관리자', :'admin_pw', 'ADMIN', 'HQ',
       0, 'N', 'Y', now(), 'system', now()
 WHERE NOT EXISTS (SELECT 1 FROM tbl_user WHERE user_id = :'admin_id');

-- ------------------------------------------------------------
-- 7. 결재선 — 기본선 하나. 검토(REVIEW)는 꺼 둔다
--    켜 두면 전송한 문서가 검토 단계에서 멈춘 채 승인으로 못 넘어간다
-- ------------------------------------------------------------
INSERT INTO tbl_approval_line (co_cd, appr_line_cd, appr_line_nm, use_yn, ins_id, ins_dt)
SELECT :'co_cd', 'DEFAULT', '기본 결재선', 'Y', 'system', now()
 WHERE NOT EXISTS (
     SELECT 1 FROM tbl_approval_line WHERE co_cd = :'co_cd' AND appr_line_cd = 'DEFAULT'
 );

INSERT INTO tbl_approval_line_step (co_cd, appr_line_cd, step_no, role_cd, approver_id, use_yn, ins_id, ins_dt)
SELECT :'co_cd', 'DEFAULT', v.step_no, v.role_cd, :'admin_id', v.use_yn, 'system', now()
  FROM (VALUES (1, 'WRITE', 'Y'), (2, 'REVIEW', 'N'), (3, 'APPROVE', 'Y'))
       AS v(step_no, role_cd, use_yn)
 WHERE NOT EXISTS (
     SELECT 1 FROM tbl_approval_line_step o
      WHERE o.co_cd = :'co_cd' AND o.appr_line_cd = 'DEFAULT' AND o.step_no = v.step_no
 );

-- ------------------------------------------------------------
-- 8. 사용 양식 — 시스템 제공(sys)만 준다.
--    05_form_seed 는 HTML 표준 지면 항목만 깐다. 실제로 쓸 양식(HWP 38종·HTML 자사본)은
--    여기서 원본 업체의 sys 목록을 그대로 물려준다.
--    usr(그 업체가 직접 만든 양식)은 남의 것이라 복제하지 않는다.
-- ------------------------------------------------------------
INSERT INTO tbl_company_template (co_cd, tmpl_cd, sys_yn, use_yn, base_use_yn,
                                  retention_month, form_path, ins_id, ins_dt)
SELECT :'co_cd', s.tmpl_cd, s.sys_yn, s.use_yn, s.base_use_yn,
       s.retention_month, s.form_path, 'system', now()
  FROM tbl_company_template s
 WHERE s.co_cd = :'src_co'
   AND COALESCE(s.sys_yn, 'sys') NOT IN ('N', 'n', 'usr')
   AND NOT EXISTS (
       SELECT 1 FROM tbl_company_template o
        WHERE o.co_cd = :'co_cd' AND o.tmpl_cd = s.tmpl_cd
   );

-- ------------------------------------------------------------
-- 9. 문서번호 채번 규칙 — 업체가 쓰는 양식마다 하나. 없으면 문서를 만들 때 번호가 안 붙는다
-- ------------------------------------------------------------
INSERT INTO tbl_doc_no_rule (co_cd, tmpl_cd, prefix, date_fmt, seq_len, reset_cycle, last_seq, ins_id, ins_dt)
SELECT :'co_cd', ct.tmpl_cd, ct.tmpl_cd, 'YYYYMMDD', 3, 'D', 0, 'system', now()
  FROM tbl_company_template ct
 WHERE ct.co_cd = :'co_cd'
   AND NOT EXISTS (
       SELECT 1 FROM tbl_doc_no_rule r WHERE r.co_cd = :'co_cd' AND r.tmpl_cd = ct.tmpl_cd
   );

COMMIT;

-- ------------------------------------------------------------
-- 확인 — 0 이 있으면 그 단계가 안 깔린 것이다
-- ------------------------------------------------------------
SELECT :'co_cd'                                                           AS 회사,
       (SELECT count(*) FROM tbl_menu         WHERE co_cd = :'co_cd')     AS 메뉴,
       (SELECT count(*) FROM tbl_role         WHERE co_cd = :'co_cd')     AS 권한그룹,
       (SELECT count(*) FROM tbl_role_screen  WHERE co_cd = :'co_cd')     AS 화면권한,
       (SELECT count(*) FROM tbl_dept         WHERE co_cd = :'co_cd')     AS 부서,
       (SELECT count(*) FROM tbl_user         WHERE co_cd = :'co_cd')     AS 사용자,
       (SELECT count(*) FROM tbl_approval_line_step WHERE co_cd = :'co_cd') AS 결재단계,
       (SELECT count(*) FROM tbl_code         WHERE co_cd = :'co_cd')     AS 공통코드,
       (SELECT count(*) FROM tbl_company_template WHERE co_cd = :'co_cd') AS 사용양식,
       (SELECT count(*) FROM tbl_doc_no_rule  WHERE co_cd = :'co_cd')     AS 문서번호규칙,
         -- 0 이 정상이다. HTML 작성을 쓰려면 아래 「다음 단계」를 해야 한다
         (SELECT count(*) FROM tbl_tml_ccp_htg_ver WHERE co_cd = :'co_cd')  AS HTML지면버전;

-- ============================================================
--  다음 단계 — 이걸 안 하면 HTML 작성 화면이 빈 목록으로 뜬다
--
--  위 HTML지면버전 이 0 이면 아직 쓸 HTML 양식이 없다는 뜻이다.
--  개설한 업체의 관리자로 로그인해 양식 원본 5화면에서 「행추가」를 누른다.
--  행추가는 신규 등록이 아니라 **표준 복사**다 — 표준 지면을 그 업체 것으로 떠 온다.
--
--    문서 > HTML·양식 원본 > 일반위생·공정점검 양식관리      행추가 후 저장
--                          > CCP 검증점검표 양식관리         행추가 후 저장
--                          > CCP 포장공정 일지관리           행추가 후 저장
--                          > CCP 가열공정 일지관리           행추가 후 저장
--                          > CCP 금속검출공정 일지관리        행추가 후 저장
--
--  다섯 화면 모두 해야 작성 화면 5개가 다 열린다. HWP 작성은 이 단계가 필요 없다.
-- ============================================================
