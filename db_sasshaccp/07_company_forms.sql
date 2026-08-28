-- ============================================================
--  07_company_forms.sql — 업체가 쓸 회사 지면을 표준에서 복사한다
--
--  개발자: 박승우
--  일자: 2026-08-28
--  코멘트:
--    1) 06 까지 돌린 업체는 로그인·메뉴·권한은 되는데 **작성 화면에 고를 양식이 없다**
--    2) 시드는 표준 지면(tbl_check_item)까지만 깐다. 작성 5화면은 회사 지면 버전(tbl_*_ver)을 읽는다
--    3) 재실행 안전 — 이미 만든 업체는 건드리지 않는다(업체가 고친 지면을 덮지 않는다)
--
--  왜 필요한가
--    0001 을 열고 팀원으로 일반위생 작성에 들어가 「행추가」를 눌렀더니
--    양식 선택 팝업이 0건이었다. 이 파일이 없으면 새 업체는 아무것도 못 쓴다.
--    화면에서 사람이 「양식관리 → 행추가(표준 복사)」를 다섯 번 누르는 것과 같은 SP 를 부른다.
--
--  DO 블록을 쓰지 않는다 — psql 은 $$ ... $$ 안에서 변수를 치환하지 않는다.
--  복사 SP 가 FUNCTION 이라 SELECT ... WHERE NOT EXISTS 로 같은 일을 한다.
--
--  적용
--    psql -v co_cd=0001 -f 07_company_forms.sql
--    (apply-all.sh 가 06 다음에 돌린다)
-- ============================================================
SET search_path TO sasshaccp;

\if :{?co_cd}
\else
\echo '!! co_cd 를 주어야 한다 — psql -v co_cd=0001 -f 07_company_forms.sql'
\quit
\endif

-- 일반위생·공정점검
SELECT sp_tbl_html_hyg_prc_ver_copy_c_000(:'co_cd', 'html_hyg_prc_000', 0, NULL, '표준 복사', 'system')
 WHERE NOT EXISTS (SELECT 1 FROM tbl_html_hyg_prc_ver WHERE co_cd = :'co_cd');

-- CCP 검증점검표
SELECT sp_tbl_tml_ccp_chk_ver_copy_c_000(:'co_cd', 'tml_ccp_chk_000', 0, NULL, '표준 복사', 'system')
 WHERE NOT EXISTS (SELECT 1 FROM tbl_tml_ccp_chk_ver WHERE co_cd = :'co_cd');

-- CCP 포장공정
SELECT sp_tbl_tml_ccp_pkg_ver_copy_c_000(:'co_cd', 'tml_ccp_pkg_000', 0, NULL, '표준 복사', 'system')
 WHERE NOT EXISTS (SELECT 1 FROM tbl_tml_ccp_pkg_ver WHERE co_cd = :'co_cd');

-- CCP 가열공정
SELECT sp_tbl_tml_ccp_htg_ver_copy_c_000(:'co_cd', 'tml_ccp_htg_000', 0, NULL, '표준 복사', 'system')
 WHERE NOT EXISTS (SELECT 1 FROM tbl_tml_ccp_htg_ver WHERE co_cd = :'co_cd');

-- CCP 금속검출공정
SELECT sp_tbl_tml_ccp_mtl_ver_copy_c_000(:'co_cd', 'tml_ccp_mtl_000', 0, NULL, '표준 복사', 'system')
 WHERE NOT EXISTS (SELECT 1 FROM tbl_tml_ccp_mtl_ver WHERE co_cd = :'co_cd');

-- 다섯 화면이 모두 1 이어야 작성이 된다
SELECT (SELECT count(*) FROM tbl_html_hyg_prc_ver WHERE co_cd = :'co_cd') AS hyg,
       (SELECT count(*) FROM tbl_tml_ccp_chk_ver  WHERE co_cd = :'co_cd') AS chk,
       (SELECT count(*) FROM tbl_tml_ccp_pkg_ver  WHERE co_cd = :'co_cd') AS pkg,
       (SELECT count(*) FROM tbl_tml_ccp_htg_ver  WHERE co_cd = :'co_cd') AS htg,
       (SELECT count(*) FROM tbl_tml_ccp_mtl_ver  WHERE co_cd = :'co_cd') AS mtl;
