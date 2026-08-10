-- ============================================================
-- 마이그레이션 — 일지설정·문서흐름 재설계 (Wave 1~4 DB)
--
-- 개발자: 박승우
-- 일자: 2026-08-06
-- 코멘트:
--   1) 메뉴 재배치(문서결재/일지설정/이탈/감사)·법적·교육·성적서 leaf 흡수
--   2) DOC_STATUS TMP→WRK, 결재함·결재이력 SP, 양식 export 이력·sys_yn
--   3) 기존 테넌트 메뉴·권한을 중복 없이 맞춘다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 문서 상태 WRK 도입 · TMP 폐기
-- ------------------------------------------------------------
INSERT INTO tbl_code (co_cd, main_cd, sub_cd, code_nm, sort_no, ref1, sys_yn, ins_id) VALUES
    ('0000', 'DOC_STATUS', 'WRK', '작성중', 1, NULL, 'Y', 'system')
ON CONFLICT (co_cd, main_cd, sub_cd) DO UPDATE SET
    code_nm = '작성중',
    sort_no = 1,
    upd_id = 'system',
    upd_dt = now();

UPDATE tbl_code
   SET use_yn = 'N',
       code_nm = '임시저장(폐기)',
       upd_id = 'system',
       upd_dt = now()
 WHERE co_cd = '0000' AND main_cd = 'DOC_STATUS' AND sub_cd = 'TMP';

UPDATE tbl_document SET status = 'WRK', upd_id = 'system', upd_dt = now()
 WHERE status = 'TMP' AND del_yn = 'N';

-- HWP 저장·삭제·결재 REQUEST/CANCEL 의 TMP 를 WRK 로 교체 (본문 SP는 15_sp_doc.sql 정본 동기화)

-- ------------------------------------------------------------
-- 2. 회사 양식 sys_yn · 내보내기 이력
-- ------------------------------------------------------------
ALTER TABLE tbl_company_template
    ADD COLUMN IF NOT EXISTS sys_yn varchar(1) NOT NULL DEFAULT 'Y';
COMMENT ON COLUMN tbl_company_template.sys_yn IS '시스템(서버) 배포분 Y — Y면 삭제 불가. 회사 전용·이력복원분만 N';

UPDATE tbl_company_template SET sys_yn = 'Y' WHERE sys_yn IS NULL OR sys_yn = '';

CREATE TABLE IF NOT EXISTS tbl_template_export_hist (
    idx        bigserial PRIMARY KEY,
    co_cd      varchar(10)  NOT NULL,
    pack_nm    varchar(200) NOT NULL,
    doc_kind   varchar(10)  NOT NULL,
    payload    jsonb        NOT NULL,
    file_ref   varchar(500) NULL,
    remk       varchar(500) NULL,
    ins_id     varchar(20)  NOT NULL,
    ins_dt     timestamp    NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_tbl_template_export_hist_co
    ON tbl_template_export_hist (co_cd, doc_kind, ins_dt DESC);
COMMENT ON TABLE tbl_template_export_hist IS '양식 설정 내보내기 이력 — 불러오기 팝업 소스';

-- ------------------------------------------------------------
-- 3. 화면 마스터 — 신규·모듈 이동·흡수 leaf 비활성
-- ------------------------------------------------------------
INSERT INTO tbl_screen (scrn_cd, scrn_nm, module_cd, tmpl_cd, sort_no, use_yn, ins_id) VALUES
    ('approval-history', '결재 이력', 'DOC', NULL, 635, 'Y', 'system'),
    ('legal-document-upload', '법적서류 업로드', 'DOC', NULL, 615, 'Y', 'system'),
    ('hwp-template-management', 'HWP 양식 파일 관리', 'SET', NULL, 1315, 'Y', 'system')
ON CONFLICT (scrn_cd) DO UPDATE SET
    scrn_nm = EXCLUDED.scrn_nm,
    module_cd = EXCLUDED.module_cd,
    sort_no = EXCLUDED.sort_no,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- DB 양식설정 화면명 정리
UPDATE tbl_screen
   SET scrn_nm = 'DB 양식·점검항목 설정',
       module_cd = 'SET',
       sort_no = 1310,
       upd_id = 'system',
       upd_dt = now()
 WHERE scrn_cd = 'template-check-item-management';

UPDATE tbl_screen
   SET scrn_nm = '스마트일지·문서코드 매핑',
       module_cd = 'SET',
       sort_no = 1350,
       upd_id = 'system',
       upd_dt = now()
 WHERE scrn_cd = 'smart-diary-type-management';

-- 이탈·감사 모듈 분리
UPDATE tbl_screen
   SET module_cd = 'CA', sort_no = 1410, upd_id = 'system', upd_dt = now()
 WHERE scrn_cd = 'corrective-action-management';
UPDATE tbl_screen
   SET module_cd = 'AUD', sort_no = 1510, upd_id = 'system', upd_dt = now()
 WHERE scrn_cd = 'audit-export';

-- 교육·성적서·법적 HWP leaf 메뉴 비활성 (문서작성·법적업로드·템플릿으로 흡수)
UPDATE tbl_screen
   SET use_yn = 'N', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd IN (
    'law-health-cert', 'law-material-ledger', 'law-building-ledger', 'law-production-ledger',
    'law-business-license', 'law-self-quality-test', 'law-completion-cert',
    'edu-annual-plan', 'edu-training-log',
    'test-product-report', 'test-surface-report'
 );

-- HWP 템플릿 scrn_cd → 문서작성으로 통일 (교육·성적서·검증 HWP만)
-- DB형 VERIFY_PLAN(연간 검증계획)은 category VER이어도 annual-verification-plan 유지
UPDATE tbl_template
   SET scrn_cd = 'hwp-document-editor',
       upd_id = 'system',
       upd_dt = now()
 WHERE tmpl_cd IN ('EDU_PLAN', 'EDU_LOG', 'PROD_TEST', 'SURFACE_TEST')
    OR (category_cd IN ('EDU', 'VER') AND doc_kind = 'HWP');

-- 과거 migrate가 DB형 VERIFY_PLAN 화면코드를 덮었을 때 복구
UPDATE tbl_template
   SET scrn_cd = 'annual-verification-plan',
       upd_id = 'system',
       upd_dt = now()
 WHERE tmpl_cd = 'VERIFY_PLAN'
   AND doc_kind = 'DB';

UPDATE tbl_template
   SET scrn_cd = 'legal-document-upload',
       upd_id = 'system',
       upd_dt = now()
 WHERE category_cd = 'LAW';

-- ------------------------------------------------------------
-- 4. 메뉴 부모·leaf 재배치
-- ------------------------------------------------------------
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, v.menu_cd, v.menu_nm, NULL, NULL, v.sort_no, 'Y', 'system', now()
  FROM tbl_company c
 CROSS JOIN (VALUES
    ('MDOC', '문서·결재', 600),
    ('MSET', '일지설정', 1300),
    ('MCA',  '이탈·개선조치', 1400),
    ('MAUD', '감사자료', 1500)
 ) AS v(menu_cd, menu_nm, sort_no)
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm,
    sort_no = EXCLUDED.sort_no,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- 구 대메뉴 숨김
UPDATE tbl_menu
   SET use_yn = 'N', upd_id = 'system', upd_dt = now()
 WHERE menu_cd IN ('MLAW', 'MEDU', 'MTST');

-- 흡수 leaf 메뉴 숨김
UPDATE tbl_menu
   SET use_yn = 'N', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd IN (
    'law-health-cert', 'law-material-ledger', 'law-building-ledger', 'law-production-ledger',
    'law-business-license', 'law-self-quality-test', 'law-completion-cert',
    'edu-annual-plan', 'edu-training-log',
    'test-product-report', 'test-surface-report'
 );

-- 문서·결재 leaf
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, s.scrn_cd, s.scrn_nm, 'MDOC', s.scrn_cd, s.sort_no, 'Y', 'system', now()
  FROM tbl_company c
 CROSS JOIN tbl_screen s
 WHERE s.scrn_cd IN (
    'hwp-document-editor', 'legal-document-upload',
    'document-inbox', 'approval-inbox', 'approval-history'
 )
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm,
    h_menu_cd = 'MDOC',
    scrn_cd = EXCLUDED.scrn_cd,
    sort_no = EXCLUDED.sort_no,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- 일지설정 leaf
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, s.scrn_cd, s.scrn_nm, 'MSET', s.scrn_cd, s.sort_no, 'Y', 'system', now()
  FROM tbl_company c
 CROSS JOIN tbl_screen s
 WHERE s.scrn_cd IN (
    'template-check-item-management', 'hwp-template-management',
    'ccp-limit-management', 'approval-line-management',
    'schedule-cycle-management', 'smart-diary-type-management'
 )
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm,
    h_menu_cd = 'MSET',
    scrn_cd = EXCLUDED.scrn_cd,
    sort_no = EXCLUDED.sort_no,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- 이탈·감사 leaf
INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, s.scrn_cd, s.scrn_nm,
       CASE s.module_cd WHEN 'CA' THEN 'MCA' ELSE 'MAUD' END,
       s.scrn_cd, s.sort_no, 'Y', 'system', now()
  FROM tbl_company c
 CROSS JOIN tbl_screen s
 WHERE s.scrn_cd IN ('corrective-action-management', 'audit-export')
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm,
    h_menu_cd = EXCLUDED.h_menu_cd,
    sort_no = EXCLUDED.sort_no,
    use_yn = 'Y',
    upd_id = 'system',
    upd_dt = now();

-- 관리자 권한
INSERT INTO tbl_role_screen (
    co_cd, usrgrp_cd, scrn_cd, read_yn, write_yn, modify_yn, delete_yn, print_yn, ins_id, ins_dt
)
SELECT g.co_cd, g.usrgrp_cd, s.scrn_cd, 'Y', 'Y', 'Y', 'Y', 'Y', 'system', now()
  FROM tbl_role g
 CROSS JOIN tbl_screen s
 WHERE g.usrgrp_cd = 'ADMIN'
   AND s.scrn_cd IN (
    'approval-history', 'legal-document-upload', 'hwp-template-management',
    'hwp-document-editor', 'document-inbox', 'approval-inbox',
    'template-check-item-management', 'smart-diary-type-management',
    'corrective-action-management', 'audit-export'
 )
ON CONFLICT (co_cd, usrgrp_cd, scrn_cd) DO NOTHING;

-- ------------------------------------------------------------
-- 5. 결재함 — 내 차례 대기 문서
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_document_appr_inbox_r_000(
    p_co_cd varchar,
    p_user_id varchar,
    p_from_dt varchar,
    p_to_dt varchar,
    p_keyword varchar
)
RETURNS TABLE (
    doc_idx bigint, co_cd varchar, tmpl_cd varchar, tmpl_nm varchar, doc_kind varchar,
    doc_no varchar, base_dt varchar, title varchar, status varchar, appr_line_cd varchar,
    writer_id varchar, writer_nm varchar, write_dt timestamp, ver_no int, retention_until varchar,
    file_cnt int, open_ca_cnt int
)
LANGUAGE sql STABLE AS $$
    SELECT d.idx, d.co_cd, d.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm, d.tmpl_cd),
           d.doc_kind, d.doc_no, d.base_dt, d.title, d.status, d.appr_line_cd,
           d.writer_id, u.user_nm, d.write_dt, d.ver_no, d.retention_until,
           (SELECT count(*)::int FROM tbl_document_file f WHERE f.co_cd = d.co_cd AND f.doc_idx = d.idx),
           (SELECT count(*)::int FROM tbl_corrective_action ca
             WHERE ca.co_cd = d.co_cd AND ca.src_doc_idx = d.idx AND ca.status <> 'DONE')
      FROM tbl_document d
      JOIN tbl_document_approval a
        ON a.co_cd = d.co_cd AND a.doc_idx = d.idx
       AND a.result_cd = 'W'
       AND a.approver_id = p_user_id
       AND a.role_cd IN ('REVIEW', 'APPROVE')
      LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = d.co_cd AND ct.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_user u ON u.co_cd = d.co_cd AND u.user_id = d.writer_id
     WHERE d.co_cd = p_co_cd
       AND d.del_yn = 'N'
       AND d.status IN ('REQ', 'REV')
       AND (COALESCE(p_from_dt, '') = '' OR d.base_dt >= p_from_dt)
       AND (COALESCE(p_to_dt, '') = '' OR d.base_dt <= p_to_dt)
       AND (
           COALESCE(p_keyword, '') = ''
           OR d.doc_no ILIKE '%' || p_keyword || '%'
           OR COALESCE(d.title, '') ILIKE '%' || p_keyword || '%'
       )
     ORDER BY d.base_dt DESC, d.idx DESC;
$$;
COMMENT ON FUNCTION sp_tbl_document_appr_inbox_r_000(varchar, varchar, varchar, varchar, varchar) IS
  '결재함 — 내 차례(대기) 문서만';

-- ------------------------------------------------------------
-- 6. 결재 이력 — 내가 처리한 문서
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_document_appr_hist_r_000(
    p_co_cd varchar,
    p_user_id varchar,
    p_from_dt varchar,
    p_to_dt varchar,
    p_keyword varchar
)
RETURNS TABLE (
    doc_idx bigint, co_cd varchar, tmpl_cd varchar, tmpl_nm varchar, doc_kind varchar,
    doc_no varchar, base_dt varchar, title varchar, status varchar, appr_line_cd varchar,
    writer_id varchar, writer_nm varchar, write_dt timestamp, ver_no int, retention_until varchar,
    file_cnt int, open_ca_cnt int, my_result_cd varchar, my_act_dt timestamp
)
LANGUAGE sql STABLE AS $$
    SELECT DISTINCT ON (d.idx)
           d.idx, d.co_cd, d.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm, d.tmpl_cd),
           d.doc_kind, d.doc_no, d.base_dt, d.title, d.status, d.appr_line_cd,
           d.writer_id, u.user_nm, d.write_dt, d.ver_no, d.retention_until,
           (SELECT count(*)::int FROM tbl_document_file f WHERE f.co_cd = d.co_cd AND f.doc_idx = d.idx),
           (SELECT count(*)::int FROM tbl_corrective_action ca
             WHERE ca.co_cd = d.co_cd AND ca.src_doc_idx = d.idx AND ca.status <> 'DONE'),
           a.result_cd, a.act_dt
      FROM tbl_document d
      JOIN tbl_document_approval a
        ON a.co_cd = d.co_cd AND a.doc_idx = d.idx
       AND a.approver_id = p_user_id
       AND a.result_cd IN ('A', 'R')
      LEFT JOIN tbl_template t ON t.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd = d.co_cd AND ct.tmpl_cd = d.tmpl_cd
      LEFT JOIN tbl_user u ON u.co_cd = d.co_cd AND u.user_id = d.writer_id
     WHERE d.co_cd = p_co_cd
       AND d.del_yn = 'N'
       AND (COALESCE(p_from_dt, '') = '' OR d.base_dt >= p_from_dt)
       AND (COALESCE(p_to_dt, '') = '' OR d.base_dt <= p_to_dt)
       AND (
           COALESCE(p_keyword, '') = ''
           OR d.doc_no ILIKE '%' || p_keyword || '%'
           OR COALESCE(d.title, '') ILIKE '%' || p_keyword || '%'
       )
     ORDER BY d.idx, a.act_dt DESC NULLS LAST;
$$;
COMMENT ON FUNCTION sp_tbl_document_appr_hist_r_000(varchar, varchar, varchar, varchar, varchar) IS
  '결재 이력 — 내가 승인·반려한 문서';

-- ------------------------------------------------------------
-- 7. 문서함 목록 — 작성자 ILIKE 유지 + 법적서류 제외 옵션은 앱에서 tmpl category 필터
--    (기존 sp_tbl_document_r_000 는 30_migrate 정본 유지)
-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- 8. 양식 export 이력 SP
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_template_export_hist_r_000(
    p_co_cd varchar,
    p_doc_kind varchar
)
RETURNS TABLE (
    idx bigint, pack_nm varchar, doc_kind varchar, remk varchar, ins_id varchar, ins_dt timestamp
)
LANGUAGE sql STABLE AS $$
    SELECT h.idx, h.pack_nm, h.doc_kind, h.remk, h.ins_id, h.ins_dt
      FROM tbl_template_export_hist h
     WHERE h.co_cd = p_co_cd
       AND (COALESCE(p_doc_kind, '') = '' OR h.doc_kind = p_doc_kind)
     ORDER BY h.ins_dt DESC, h.idx DESC;
$$;

CREATE OR REPLACE FUNCTION sp_tbl_template_export_hist_r_001(
    p_co_cd varchar,
    p_idx bigint
)
RETURNS TABLE (idx bigint, pack_nm varchar, doc_kind varchar, payload jsonb, file_ref varchar, remk varchar)
LANGUAGE sql STABLE AS $$
    SELECT h.idx, h.pack_nm, h.doc_kind, h.payload, h.file_ref, h.remk
      FROM tbl_template_export_hist h
     WHERE h.co_cd = p_co_cd AND h.idx = p_idx;
$$;

CREATE OR REPLACE FUNCTION sp_tbl_template_export_hist_c_000(
    p_co_cd varchar,
    p_pack_nm varchar,
    p_doc_kind varchar,
    p_payload jsonb,
    p_file_ref varchar,
    p_remk varchar,
    p_id varchar
) RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE v_idx bigint;
BEGIN
    INSERT INTO tbl_template_export_hist(co_cd, pack_nm, doc_kind, payload, file_ref, remk, ins_id)
    VALUES (p_co_cd, p_pack_nm, p_doc_kind, COALESCE(p_payload, '{}'::jsonb),
            NULLIF(p_file_ref, ''), NULLIF(p_remk, ''), p_id)
    RETURNING idx INTO v_idx;
    RETURN v_idx;
END$$;

-- ------------------------------------------------------------
-- 9. 스마트일지 매핑 저장
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_smart_diary_map_c_000(
    p_co_cd varchar,
    p_diary_no varchar,
    p_tmpl_cd varchar,
    p_match_level varchar,
    p_impl_status varchar,
    p_preferred_yn varchar,
    p_id varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    IF COALESCE(trim(p_diary_no), '') = '' OR COALESCE(trim(p_tmpl_cd), '') = '' THEN
        RAISE EXCEPTION '일지번호와 문서코드(tmpl_cd)를 입력하세요.' USING ERRCODE = '45000';
    END IF;
    INSERT INTO tbl_smart_diary_map(diary_no, tmpl_cd, match_level, impl_status, preferred_yn, ins_id, ins_dt)
    VALUES (p_diary_no, p_tmpl_cd,
            COALESCE(NULLIF(p_match_level, ''), 'MAPPED'),
            COALESCE(NULLIF(p_impl_status, ''), 'CATALOG'),
            COALESCE(NULLIF(p_preferred_yn, ''), 'Y'),
            p_id, now())
    ON CONFLICT (diary_no, tmpl_cd) DO UPDATE SET
        match_level = EXCLUDED.match_level,
        impl_status = EXCLUDED.impl_status,
        preferred_yn = EXCLUDED.preferred_yn,
        upd_id = p_id,
        upd_dt = now();
END$$;

CREATE OR REPLACE PROCEDURE sp_tbl_smart_diary_map_d_000(
    p_co_cd varchar,
    p_diary_no varchar,
    p_tmpl_cd varchar,
    p_id varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM tbl_smart_diary_map WHERE diary_no = p_diary_no AND tmpl_cd = p_tmpl_cd;
END$$;

-- ------------------------------------------------------------
-- 10. 감사자료 — 법적서류(LAW) 제외
-- ------------------------------------------------------------
-- 22 에서 만든 RETURNS TABLE 컬럼 수와 달라 CREATE OR REPLACE 가 거부된다.
-- OUT 시그니처가 바뀌는 경우에만 DROP 이 필요하므로 여기서 먼저 지운다
DROP FUNCTION IF EXISTS sp_tbl_audit_export_r_000(varchar, varchar, varchar, varchar);

CREATE OR REPLACE FUNCTION sp_tbl_audit_export_r_000(
    p_co_cd varchar, p_from_dt varchar, p_to_dt varchar, p_status varchar
)
RETURNS TABLE(
    doc_idx bigint, doc_no varchar, tmpl_nm varchar, base_dt varchar, status varchar,
    writer_id varchar, approve_dt timestamp, file_cnt int, relation_cnt int, open_ca_cnt int,
    doc_kind varchar, tmpl_cd varchar, category_cd varchar
)
LANGUAGE sql STABLE AS $$
    SELECT d.idx, d.doc_no, COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm, d.tmpl_cd), d.base_dt, d.status,
           d.writer_id, d.approve_dt,
           (SELECT count(*)::int FROM tbl_document_file f WHERE f.co_cd=d.co_cd AND f.doc_idx=d.idx),
           (SELECT count(*)::int FROM tbl_document_relation r
             WHERE r.co_cd=d.co_cd AND (r.src_doc_idx=d.idx OR r.tgt_doc_idx=d.idx)),
           (SELECT count(*)::int FROM tbl_corrective_action ca
             WHERE ca.co_cd=d.co_cd AND ca.src_doc_idx=d.idx AND ca.status <> 'DONE'),
           d.doc_kind, d.tmpl_cd, t.category_cd
      FROM tbl_document d
      LEFT JOIN tbl_template t ON t.tmpl_cd=d.tmpl_cd
      LEFT JOIN tbl_company_template ct ON ct.co_cd=d.co_cd AND ct.tmpl_cd=d.tmpl_cd
     WHERE d.co_cd=p_co_cd AND d.del_yn='N'
       AND COALESCE(t.category_cd, '') <> 'LAW'
       AND (COALESCE(p_from_dt,'')='' OR d.base_dt >= p_from_dt)
       AND (COALESCE(p_to_dt,'')='' OR d.base_dt <= p_to_dt)
       AND (COALESCE(p_status,'')='' OR d.status=p_status)
     ORDER BY d.base_dt, d.doc_no;
$$;
