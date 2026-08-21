-- ============================================================
-- 104 — HTML 양식 버전명 수정
--
-- 파일번호: 104
-- 이전번호: 103
-- 개발자: 박승우
-- 일자: 2026-08-20
-- 코멘트:
--   1) 사용자 버전(ver_no>0)의 ver_nm만 UPDATE한다
--   2) 표준 가상행(0.1)은 물리 행이 없어 여기서 막는다
--   3) 103 재실행 금지
--
-- ============================================================

SET search_path TO sasshaccp;

DROP PROCEDURE IF EXISTS sp_tbl_html_form_ver_nm_u_000(varchar, varchar, int, varchar, varchar);
CREATE PROCEDURE sp_tbl_html_form_ver_nm_u_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_tmpl_cd: 양식코드
    p_tmpl_cd varchar,
    -- p_ver_no: 회사 버전 순번. 0 이하면 표준이라 거부
    p_ver_no  int,
    -- p_ver_nm: 바꿀 버전명. 공백이면 거부
    p_ver_nm  varchar,
    -- p_id: 수정자
    p_id      varchar
)
LANGUAGE plpgsql AS $$
DECLARE v_nm varchar;
BEGIN
    -- p_ver_no<=0일 때(= 표준 가상행 0.1)
    IF COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 버전명은 수정할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    v_nm := btrim(COALESCE(p_ver_nm, ''));
    -- v_nm 공백일 때(= 이름 필수)
    IF v_nm = '' THEN
        RAISE EXCEPTION '버전명은 필수입니다.' USING ERRCODE = '45000';
    END IF;
    UPDATE tbl_html_form_ver
       SET ver_nm = v_nm, upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd
       AND ver_no = p_ver_no AND use_yn = 'Y';
    -- NOT FOUND일 때(= 없거나 삭제분)
    IF NOT FOUND THEN
        RAISE EXCEPTION '버전을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
END$$;
