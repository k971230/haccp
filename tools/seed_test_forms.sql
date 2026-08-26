-- ============================================================
--  시험용 DB 를 「양식을 이미 복사해 둔 업체」 상태로 만든다. 로컬 전용.
--
--  개발자: 박승우
--  일자: 2026-08-26
--  코멘트:
--    1) 시드 6본은 표준 지면(tbl_check_item)만 깐다 — 회사 지면 버전(tbl_*_ver)은 안 만든다
--    2) 그래서 갓 시드한 DB 는 작성 화면에 고를 양식이 없다. E2E 는 있다고 보고 돈다
--    3) 화면에서 「행추가(표준 복사)」를 누르는 것과 같은 SP 를 부른다 — 경로를 따로 만들지 않는다
--
--  운영에서는 사람이 양식 원본 5화면에서 눌러 만든다. 이 파일은 그걸 시험용으로 대신할 뿐이다.
-- ============================================================
SET search_path TO sasshaccp;

DO $$
DECLARE
    v_made varchar;
BEGIN
    -- 일반위생·공정점검
    IF NOT EXISTS (SELECT 1 FROM tbl_html_hyg_prc_ver WHERE co_cd = '0000') THEN
        v_made := sp_tbl_html_hyg_prc_ver_copy_c_000('0000', 'html_hyg_prc_000', 0, NULL, '표준 복사', 'system');
        RAISE NOTICE 'hyg  -> %', v_made;
    END IF;

    -- CCP 검증점검표
    IF NOT EXISTS (SELECT 1 FROM tbl_tml_ccp_chk_ver WHERE co_cd = '0000') THEN
        v_made := sp_tbl_tml_ccp_chk_ver_copy_c_000('0000', 'tml_ccp_chk_000', 0, NULL, '표준 복사', 'system');
        RAISE NOTICE 'chk  -> %', v_made;
    END IF;

    -- CCP 포장공정
    IF NOT EXISTS (SELECT 1 FROM tbl_tml_ccp_pkg_ver WHERE co_cd = '0000') THEN
        v_made := sp_tbl_tml_ccp_pkg_ver_copy_c_000('0000', 'tml_ccp_pkg_000', 0, NULL, '표준 복사', 'system');
        RAISE NOTICE 'pkg  -> %', v_made;
    END IF;

    -- CCP 가열공정
    IF NOT EXISTS (SELECT 1 FROM tbl_tml_ccp_htg_ver WHERE co_cd = '0000') THEN
        v_made := sp_tbl_tml_ccp_htg_ver_copy_c_000('0000', 'tml_ccp_htg_000', 0, NULL, '표준 복사', 'system');
        RAISE NOTICE 'htg  -> %', v_made;
    END IF;

    -- CCP 금속검출공정
    IF NOT EXISTS (SELECT 1 FROM tbl_tml_ccp_mtl_ver WHERE co_cd = '0000') THEN
        v_made := sp_tbl_tml_ccp_mtl_ver_copy_c_000('0000', 'tml_ccp_mtl_000', 0, NULL, '표준 복사', 'system');
        RAISE NOTICE 'mtl  -> %', v_made;
    END IF;
END $$;

SELECT (SELECT count(*) FROM tbl_html_hyg_prc_ver WHERE co_cd='0000') AS hyg,
       (SELECT count(*) FROM tbl_tml_ccp_chk_ver  WHERE co_cd='0000') AS chk,
       (SELECT count(*) FROM tbl_tml_ccp_pkg_ver  WHERE co_cd='0000') AS pkg,
       (SELECT count(*) FROM tbl_tml_ccp_htg_ver  WHERE co_cd='0000') AS htg,
       (SELECT count(*) FROM tbl_tml_ccp_mtl_ver  WHERE co_cd='0000') AS mtl;
