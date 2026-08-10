-- ============================================================
-- 45 — 설비·방충 이력 통합·양식 삭제·export hist·메뉴 정리
--
-- 개발자: 박승우
-- 일자: 2026-08-10
-- 코멘트:
--   1) equipment-management / pest-device-management 메뉴를 이력 화면으로 통합한다
--   2) 방충 설비 이력 테이블·SP를 설비 이력과 동일 패턴으로 추가한다
--   3) 회사 양식(sys_yn=N) 삭제 SP·목록 sys_yn 노출·export hist SP를 보강한다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 메뉴 — 설비마스터·방충마스터 숨김, 방충 이력 화면 등록
-- ------------------------------------------------------------
INSERT INTO tbl_screen (scrn_cd, scrn_nm, module_cd, tmpl_cd, sort_no, use_yn, ins_id) VALUES
    ('pest-device-history', '방충설비 이력', 'BAS', NULL, 860, 'Y', 'system')
ON CONFLICT (scrn_cd) DO UPDATE SET
    scrn_nm = EXCLUDED.scrn_nm, use_yn = 'Y', upd_id = 'system', upd_dt = now();

UPDATE tbl_screen SET use_yn = 'N', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd IN ('equipment-management', 'pest-device-management');

UPDATE tbl_menu SET use_yn = 'N', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd IN ('equipment-management', 'pest-device-management');

-- 기존 방충 마스터 메뉴를 이력 화면으로 치환(있으면 있으면면 신규 삽입)
UPDATE tbl_menu m
   SET scrn_cd = 'pest-device-history',
       menu_nm = '방충설비 이력',
       use_yn = 'Y',
       upd_id = 'system',
       upd_dt = now()
 WHERE m.scrn_cd = 'pest-device-management'
    OR m.menu_cd IN (
        SELECT menu_cd FROM tbl_menu x
         WHERE x.scrn_cd = 'pest-device-management'
    );

INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, 'MPSTHIST', '방충설비 이력', 'MFRM', 'pest-device-history', 860, 'Y', 'system', now()
  FROM tbl_company c
 WHERE NOT EXISTS (
    SELECT 1 FROM tbl_menu m WHERE m.co_cd = c.co_cd AND m.scrn_cd = 'pest-device-history'
 )
ON CONFLICT (co_cd, menu_cd) DO NOTHING;

INSERT INTO tbl_role_screen (
    co_cd, usrgrp_cd, scrn_cd, read_yn, write_yn, modify_yn, delete_yn, print_yn, ins_id, ins_dt
)
SELECT g.co_cd, g.usrgrp_cd, 'pest-device-history', 'Y', 'Y', 'Y', 'Y', 'Y', 'system', now()
  FROM tbl_role g
 WHERE g.usrgrp_cd = 'ADMIN'
ON CONFLICT (co_cd, usrgrp_cd, scrn_cd) DO NOTHING;

-- ------------------------------------------------------------
-- 2. 방충 설비 이력 테이블
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_pest_device_hist (
    idx         bigserial PRIMARY KEY,
    co_cd       varchar(20)  NOT NULL,
    pest_idx    bigint       NOT NULL,
    hist_dt     varchar(8)   NOT NULL,
    fault_rmk   text         NULL,
    action_rmk  text         NULL,
    remark      text         NULL,
    ins_id      varchar(50)  NOT NULL,
    ins_dt      timestamptz  NOT NULL DEFAULT now(),
    upd_id      varchar(50)  NULL,
    upd_dt      timestamptz  NULL
);
CREATE INDEX IF NOT EXISTS ix_tbl_pest_device_hist_pest
    ON tbl_pest_device_hist (co_cd, pest_idx, hist_dt DESC);

COMMENT ON TABLE tbl_pest_device_hist IS '방충설비(포충등·트랩) 고장·조치 이력';

CREATE OR REPLACE FUNCTION sp_tbl_pest_device_hist_r_000(
    p_co_cd varchar,
    p_pest_idx bigint
)
RETURNS SETOF jsonb
LANGUAGE sql STABLE AS $$
    SELECT jsonb_build_object(
             'idx', h.idx,
             'pestIdx', h.pest_idx,
             'histDt', h.hist_dt,
             'faultRmk', h.fault_rmk,
             'actionRmk', h.action_rmk,
             'remark', h.remark
           )
      FROM tbl_pest_device_hist h
     WHERE h.co_cd = p_co_cd
       AND h.pest_idx = p_pest_idx
     ORDER BY h.hist_dt DESC, h.idx DESC;
$$;

CREATE OR REPLACE PROCEDURE sp_tbl_pest_device_hist_c_000(
    p_co_cd varchar,
    p_payload jsonb,
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_idx bigint := NULLIF(p_payload->>'idx','')::bigint;
    v_pest bigint := NULLIF(p_payload->>'pestIdx','')::bigint;
BEGIN
    IF COALESCE(p_co_cd,'')='' OR COALESCE(p_id,'')='' THEN
        RAISE EXCEPTION '로그인 정보가 올바르지 않습니다.' USING ERRCODE='45000';
    END IF;
    IF v_pest IS NULL OR COALESCE(p_payload->>'histDt','')='' THEN
        RAISE EXCEPTION '방충설비와 이력일은 필수입니다.' USING ERRCODE='45000';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM tbl_pest_device WHERE idx=v_pest AND co_cd=p_co_cd) THEN
        RAISE EXCEPTION '방충설비를 찾을 수 없습니다.' USING ERRCODE='45000';
    END IF;
    IF v_idx IS NULL THEN
        INSERT INTO tbl_pest_device_hist(co_cd, pest_idx, hist_dt, fault_rmk, action_rmk, remark, ins_id)
        VALUES (
            p_co_cd, v_pest, p_payload->>'histDt',
            NULLIF(p_payload->>'faultRmk',''),
            NULLIF(p_payload->>'actionRmk',''),
            NULLIF(p_payload->>'remark',''),
            p_id
        );
    ELSE
        UPDATE tbl_pest_device_hist SET
            hist_dt = p_payload->>'histDt',
            fault_rmk = NULLIF(p_payload->>'faultRmk',''),
            action_rmk = NULLIF(p_payload->>'actionRmk',''),
            remark = NULLIF(p_payload->>'remark',''),
            upd_id = p_id,
            upd_dt = now()
         WHERE idx = v_idx AND co_cd = p_co_cd AND pest_idx = v_pest;
        IF NOT FOUND THEN
            RAISE EXCEPTION '수정할 이력을 찾을 수 없습니다.' USING ERRCODE='45000';
        END IF;
    END IF;
END$$;

CREATE OR REPLACE PROCEDURE sp_tbl_pest_device_hist_d_000(
    p_co_cd varchar,
    p_idx bigint,
    p_id varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    IF p_idx IS NULL OR p_idx <= 0 THEN
        RAISE EXCEPTION '삭제할 이력을 선택하세요.' USING ERRCODE='45000';
    END IF;
    DELETE FROM tbl_pest_device_hist WHERE idx = p_idx AND co_cd = p_co_cd;
    IF NOT FOUND THEN
        RAISE EXCEPTION '삭제할 이력을 찾을 수 없습니다.' USING ERRCODE='45000';
    END IF;
END$$;

CREATE OR REPLACE FUNCTION sp_tbl_pest_device_hist_delete_blocker_r_000(
    p_co_cd varchar,
    p_keys jsonb
)
RETURNS TABLE(idx bigint, label varchar, target varchar)
LANGUAGE sql STABLE AS $$
    SELECT NULL::bigint, NULL::varchar, NULL::varchar WHERE false;
$$;

-- ------------------------------------------------------------
-- 3. 회사 양식 삭제 (sys_yn=N 만) + 목록 sys_yn
-- ------------------------------------------------------------
ALTER TABLE tbl_company_template
    ADD COLUMN IF NOT EXISTS sys_yn varchar(1) NOT NULL DEFAULT 'Y';

-- RETURNS 컬럼 추가이므로 DROP 후 재생성
DROP FUNCTION IF EXISTS sp_tbl_document_template_r_000(varchar);
CREATE FUNCTION sp_tbl_document_template_r_000(
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
           t.form_path,
           regexp_replace(t.form_path, '^.*/', ''),
           COALESCE(ct.sys_yn, 'Y')
      FROM tbl_template t
      JOIN tbl_company_template ct
        ON ct.co_cd = p_co_cd
       AND ct.tmpl_cd = t.tmpl_cd
     WHERE t.impl_yn = 'Y'
       AND t.use_yn = 'Y'
       AND ct.use_yn = 'Y'
       AND t.form_path IS NOT NULL
     ORDER BY t.sort_no, t.tmpl_cd;
$$;

CREATE OR REPLACE FUNCTION sp_tbl_company_template_delete_blocker_r_000(
    p_co_cd varchar,
    p_keys jsonb
)
RETURNS TABLE(tmpl_cd varchar, label varchar, target varchar)
LANGUAGE sql STABLE AS $$
    SELECT k.tmpl_cd,
           k.tmpl_cd::varchar AS label,
           '문서'::varchar AS target
      FROM jsonb_to_recordset(p_keys) AS k(tmpl_cd varchar)
      JOIN tbl_document d
        ON d.co_cd = p_co_cd
       AND d.tmpl_cd = k.tmpl_cd
       AND COALESCE(d.del_yn, 'N') = 'N'
     GROUP BY k.tmpl_cd;
$$;

CREATE OR REPLACE PROCEDURE sp_tbl_company_template_d_000(
    p_co_cd varchar,
    p_tmpl_cd varchar,
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_sys varchar(1);
BEGIN
    IF COALESCE(p_co_cd,'')='' OR COALESCE(p_tmpl_cd,'')='' THEN
        RAISE EXCEPTION '삭제할 양식을 선택하세요.' USING ERRCODE='45000';
    END IF;
    SELECT sys_yn INTO v_sys
      FROM tbl_company_template
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    IF NOT FOUND THEN
        RAISE EXCEPTION '삭제할 양식을 찾을 수 없습니다.' USING ERRCODE='45000';
    END IF;
    IF COALESCE(v_sys, 'Y') = 'Y' THEN
        RAISE EXCEPTION '시스템 배포 양식은 삭제할 수 없습니다.' USING ERRCODE='45000';
    END IF;
    DELETE FROM tbl_company_template WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
END$$;

-- ------------------------------------------------------------
-- 4. 양식 export 이력 — 31 스키마·시그니처 정본 재적용
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_template_export_hist (
    idx        bigserial PRIMARY KEY,
    co_cd      varchar(20)  NOT NULL,
    pack_nm    varchar(200) NOT NULL,
    doc_kind   varchar(10)  NOT NULL,
    payload    jsonb        NOT NULL DEFAULT '{}'::jsonb,
    file_ref   varchar(500) NULL,
    remk       text         NULL,
    ins_id     varchar(50)  NOT NULL,
    ins_dt     timestamp    NOT NULL DEFAULT now()
);

DROP FUNCTION IF EXISTS sp_tbl_template_export_hist_r_000(varchar, varchar);
DROP FUNCTION IF EXISTS sp_tbl_template_export_hist_r_001(varchar, bigint);
DROP FUNCTION IF EXISTS sp_tbl_template_export_hist_c_000(varchar, varchar, varchar, jsonb, varchar, varchar, varchar);

CREATE FUNCTION sp_tbl_template_export_hist_r_000(
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

CREATE FUNCTION sp_tbl_template_export_hist_r_001(
    p_co_cd varchar,
    p_idx bigint
)
RETURNS TABLE (idx bigint, pack_nm varchar, doc_kind varchar, payload jsonb, file_ref varchar, remk varchar)
LANGUAGE sql STABLE AS $$
    SELECT h.idx, h.pack_nm, h.doc_kind, h.payload, h.file_ref, h.remk
      FROM tbl_template_export_hist h
     WHERE h.co_cd = p_co_cd AND h.idx = p_idx;
$$;

CREATE FUNCTION sp_tbl_template_export_hist_c_000(
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
