-- ============================================================
-- 48 — 법적서류 업로드 유형(LAW) 등록·목록 form_path NULL 허용
--
-- 파일번호: 48
-- 이전번호: 47 (2026-08-10 번호 충돌 정리로 이동 — 09 G-03)
-- 개발자: 박승우
-- 일자: 2026-08-10
-- 코멘트:
--   1) LAW 카테고리는 템플릿 파일 없이도 회사 사용 목록에 노출한다 (legal-types SP 등록)
--   2) 재실행 안전 — DROP FUNCTION IF EXISTS + CREATE / CREATE OR REPLACE PROCEDURE 유지
--   3) 47 (check_item_admin_crud) 다음에 적용된다
--      두 파일은 참조 객체가 겹치지 않는다(= 47은 tbl_check_item 계열, 48은 tbl_template 계열)
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 문서 템플릿 목록 — LAW 는 form_path 없어도 노출
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_document_template_r_000(varchar);
CREATE FUNCTION sp_tbl_document_template_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar
)
RETURNS TABLE(
    tmpl_cd varchar,
    tmpl_nm varchar,
    doc_kind varchar,
    category_cd varchar,
    mng_no varchar,
    form_path varchar,
    form_file_nm varchar,
    sys_yn varchar
) LANGUAGE sql AS $$
    SELECT t.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm),
           t.doc_kind,
           t.category_cd,
           t.mng_no,
           COALESCE(NULLIF(ct.form_path, ''), t.form_path),
           CASE
             WHEN COALESCE(NULLIF(ct.form_path, ''), t.form_path) IS NULL THEN NULL
             ELSE regexp_replace(COALESCE(NULLIF(ct.form_path, ''), t.form_path), '^.*/', '')
           END,
           COALESCE(ct.sys_yn, 'Y')
      FROM tbl_template t
      JOIN tbl_company_template ct
        ON ct.co_cd = p_co_cd
       AND ct.tmpl_cd = t.tmpl_cd
     WHERE t.impl_yn = 'Y'
       AND t.use_yn = 'Y'
       AND ct.use_yn = 'Y'
       AND (
            COALESCE(NULLIF(ct.form_path, ''), t.form_path) IS NOT NULL
            OR t.category_cd = 'LAW'
       )
     ORDER BY t.sort_no, t.tmpl_cd;
$$;
COMMENT ON FUNCTION sp_tbl_document_template_r_000(varchar) IS
    '회사 사용양식 목록 — LAW는 form 없이도 노출, 그 외는 form_path 필수';

-- 단건 조회 — 템플릿 최초 업로드 전(form 없음)에도 메타를 열 수 있게 한다
DROP FUNCTION IF EXISTS sp_tbl_document_template_r_001(varchar, varchar);
CREATE FUNCTION sp_tbl_document_template_r_001(
    p_co_cd varchar,
    p_tmpl_cd varchar
)
RETURNS TABLE(
    tmpl_cd varchar,
    tmpl_nm varchar,
    doc_kind varchar,
    category_cd varchar,
    mng_no varchar,
    form_path varchar,
    form_file_nm varchar,
    sys_yn varchar
) LANGUAGE sql AS $$
    SELECT t.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm),
           t.doc_kind,
           t.category_cd,
           t.mng_no,
           COALESCE(NULLIF(ct.form_path, ''), t.form_path),
           CASE
             WHEN COALESCE(NULLIF(ct.form_path, ''), t.form_path) IS NULL THEN NULL
             ELSE regexp_replace(COALESCE(NULLIF(ct.form_path, ''), t.form_path), '^.*/', '')
           END,
           COALESCE(ct.sys_yn, 'Y')
      FROM tbl_template t
      JOIN tbl_company_template ct
        ON ct.co_cd = p_co_cd
       AND ct.tmpl_cd = t.tmpl_cd
     WHERE t.tmpl_cd = p_tmpl_cd
       AND t.impl_yn = 'Y'
       AND t.use_yn = 'Y'
       AND ct.use_yn = 'Y';
$$;
COMMENT ON FUNCTION sp_tbl_document_template_r_001(varchar, varchar) IS
    '회사 사용양식 단건 — form_path 없어도 메타 반환(법적서류 최초 업로드용)';

-- ------------------------------------------------------------
-- 2. 회사 전용 법적서류 유형 등록
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_legal_type_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_tmpl_cd: 신규 유형 코드 — 전역 카탈로그 유일
    p_tmpl_cd varchar,
    -- p_tmpl_nm: 표시 명칭
    p_tmpl_nm varchar,
    -- p_id: JWT 작업자
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_cd varchar := trim(COALESCE(p_tmpl_cd, ''));
    v_nm varchar := trim(COALESCE(p_tmpl_nm, ''));
    v_sort int;
BEGIN
    IF COALESCE(p_co_cd, '') = '' OR v_cd = '' OR v_nm = '' OR COALESCE(p_id, '') = '' THEN
        RAISE EXCEPTION '법적서류 유형 코드·명칭을 입력하세요.' USING ERRCODE = '45000';
    END IF;
    IF EXISTS (SELECT 1 FROM tbl_template WHERE tmpl_cd = v_cd) THEN
        RAISE EXCEPTION '이미 사용 중인 양식 코드입니다.' USING ERRCODE = '45000';
    END IF;

    SELECT COALESCE(MAX(sort_no), 0) + 1 INTO v_sort
      FROM tbl_template
     WHERE category_cd = 'LAW';

    INSERT INTO tbl_template (
        tmpl_cd, tmpl_nm, mng_no, doc_kind, category_cd, scrn_cd,
        form_path, default_cycle_cd, default_retention_month,
        ver_no, impl_yn, sort_no, use_yn, ins_id, ins_dt
    ) VALUES (
        v_cd, v_nm, NULL, 'HWP', 'LAW', 'legal-document-upload',
        NULL, 'E', 36,
        1, 'Y', v_sort, 'Y', p_id, now()
    );

    INSERT INTO tbl_company_template (
        co_cd, tmpl_cd, tmpl_nm_ovr, form_path, use_yn, sys_yn, ins_id, ins_dt
    ) VALUES (
        p_co_cd, v_cd, v_nm, NULL, 'Y', 'N', p_id, now()
    )
    ON CONFLICT (co_cd, tmpl_cd) DO UPDATE SET
        tmpl_nm_ovr = EXCLUDED.tmpl_nm_ovr,
        use_yn = 'Y',
        sys_yn = 'usr',
        upd_id = p_id,
        upd_dt = now();
END$$;
COMMENT ON PROCEDURE sp_tbl_legal_type_c_000(varchar, varchar, varchar, varchar) IS
    '회사 전용 법적서류 유형 등록 — 카탈로그 LAW + company_template(sys_yn=N)';

-- 회사 양식 form_path 만 갱신 — 법적서류 템플릿 최초 업로드
CREATE OR REPLACE PROCEDURE sp_tbl_company_template_form_u_000(
    p_co_cd varchar,
    p_tmpl_cd varchar,
    p_form_path varchar,
    p_id varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    IF COALESCE(p_co_cd, '') = '' OR COALESCE(p_tmpl_cd, '') = ''
       OR COALESCE(p_form_path, '') = '' OR COALESCE(p_id, '') = '' THEN
        RAISE EXCEPTION '템플릿 경로가 올바르지 않습니다.' USING ERRCODE = '45000';
    END IF;
    UPDATE tbl_company_template
       SET form_path = p_form_path,
           upd_id = p_id,
           upd_dt = now()
     WHERE co_cd = p_co_cd
       AND tmpl_cd = p_tmpl_cd;
    IF NOT FOUND THEN
        RAISE EXCEPTION '사용 가능한 템플릿을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
END$$;
COMMENT ON PROCEDURE sp_tbl_company_template_form_u_000(varchar, varchar, varchar, varchar) IS
    '회사 양식 form_path 갱신 — 법적서류 템플릿 1건 최초·교체 등록';
