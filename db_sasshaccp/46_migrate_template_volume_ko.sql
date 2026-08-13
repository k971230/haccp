-- ============================================================
-- 46 — 템플릿 볼륨 한글명·자사 form_path·메뉴권한·설비 COALESCE
--
-- 개발자: 박승우
-- 일자: 2026-08-10
-- 코멘트:
--   1) form_path를 매니페스트 한글 파일명으로 맞춘다 (번호 접두 제거본)
--   2) 회사 양식별 form_path·sys_yn=N 생성 SP를 추가한다
--   3) equipment/pest 메뉴·권한 리맵과 설비 photo_path COALESCE를 반영한다
--   4) 바이너리는 APP_FILE_ROOT 볼륨 — DB에는 경로만 (별도 파일서버는 후속)
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 표준 form_path → HaccpTemplates/{tmpl_cd}/{한글파일명} (83 재편 규칙과 동일)
-- ------------------------------------------------------------
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_admin-handover-doc/업무_인수인계서.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_admin-handover-doc';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_ccp-cold-log/중요관리점[CCP]_점검표_냉장보관.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_ccp-cold-log';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_ccp-metal-log/중요관리점[CCP]_점검표_금속검출.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_ccp-metal-log';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_ccp-verify-check/중요관리점_검증점검표.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_ccp-verify-check';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_prp-verify-plan/연간_검증계획서.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_prp-verify-plan';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_prp-verify-check/검증_점검표.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_prp-verify-check';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_prp-verify-report/검증결과_보고서.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_prp-verify-report';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_prp-verify-action/검증_개선조치_결과보고서.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_prp-verify-action';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_admin-edu-plan/연간_교육_훈련_계획서.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_admin-edu-plan';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_admin-edu-log/교육일지.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_admin-edu-log';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_prp-hygiene-daily/일일_위생_점검일지.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_prp-hygiene-daily';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_prp-hygiene-personal/개인_위생관리_점검표.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_prp-hygiene-personal';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_prp-hygiene-area/작업장_위생관리_점검표.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_prp-hygiene-area';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_prp-pest-check/방충_방서_점검표.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_prp-pest-check';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_prp-facility-check/시설_설비_처리도구_점검표.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_prp-facility-check';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_prp-calib-target/검_교정_대상.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_prp-calib-target';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_prp-calib-temp/자체_검_교정_일지_1.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_prp-calib-temp';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_prp-calib-weight/자체_검_교정_일지_2.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_prp-calib-weight';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_prp-calib-scale/자체_검_교정_일지_3.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_prp-calib-scale';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_prp-equip-card/시설_설비_이력카드.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_prp-equip-card';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_prp-waste-check/폐기물_처리_점검표.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_prp-waste-check';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_logis-inventory-check/입출고_및_재고_점검표.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_logis-inventory-check';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_logis-receive-inspect/입고검사_일지.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_logis-receive-inspect';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_prp-test-product/제품검사_성적서.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_prp-test-product';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_prp-test-surface/표면오염도_검사_성적서.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_prp-test-surface';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_admin-bad-product/부적합제품_관리_점검표.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_admin-bad-product';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_prp-water-check/용수관리_점검표.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_prp-water-check';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_admin-claim-log/클레임_관리_일지.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_admin-claim-log';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_ccp-process-check/공정관리_점검표.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_ccp-process-check';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_logis-vehicle-log/차량운행일지.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_logis-vehicle-log';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_admin-visitor-log/외부인출입기록부.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_admin-visitor-log';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_prp-visual-inspect/원료부자재육안검사기준.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_prp-visual-inspect';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_logis-submat-receive/부자재입고검수점검표.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_logis-submat-receive';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_prp-calib-ext/외부 검교정기록부.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_prp-calib-ext';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_logis-shipment-log/제품출고관리일지.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_logis-shipment-log';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_admin-recall-report/회수결과보고서.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_admin-recall-report';
UPDATE tbl_template SET form_path = 'HaccpTemplates/tmpl_admin-eval-check/실시상황평가표.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'tmpl_admin-eval-check';
UPDATE tbl_template SET form_path = 'HaccpTemplates/INV/입출고_및_재고_점검표.hwp', upd_id = 'system', upd_dt = now() WHERE tmpl_cd = 'INV';

-- ------------------------------------------------------------
-- 2. 회사 양식 원본 경로 (자사 업로드)
-- ------------------------------------------------------------
ALTER TABLE tbl_company_template
    ADD COLUMN IF NOT EXISTS form_path varchar(300) NULL;
COMMENT ON COLUMN tbl_company_template.form_path IS
    '회사 전용 HWP 원본 상대경로 — NULL이면 tbl_template.form_path. 자사 업로드 시 CustomTemplates/{co_cd}/{tmpl_cd}/{한글명}';

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
           COALESCE(NULLIF(ct.form_path, ''), t.form_path),
           regexp_replace(COALESCE(NULLIF(ct.form_path, ''), t.form_path), '^.*/', ''),
           COALESCE(ct.sys_yn, 'Y')
      FROM tbl_template t
      JOIN tbl_company_template ct
        ON ct.co_cd = p_co_cd
       AND ct.tmpl_cd = t.tmpl_cd
     WHERE t.impl_yn = 'Y'
       AND t.use_yn = 'Y'
       AND ct.use_yn = 'Y'
       AND COALESCE(NULLIF(ct.form_path, ''), t.form_path) IS NOT NULL
     ORDER BY t.sort_no, t.tmpl_cd;
$$;

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
           regexp_replace(COALESCE(NULLIF(ct.form_path, ''), t.form_path), '^.*/', ''),
           COALESCE(ct.sys_yn, 'Y')
      FROM tbl_template t
      JOIN tbl_company_template ct
        ON ct.co_cd = p_co_cd
       AND ct.tmpl_cd = t.tmpl_cd
     WHERE t.tmpl_cd = p_tmpl_cd
       AND t.impl_yn = 'Y'
       AND t.use_yn = 'Y'
       AND ct.use_yn = 'Y'
       AND COALESCE(NULLIF(ct.form_path, ''), t.form_path) IS NOT NULL;
$$;

CREATE OR REPLACE PROCEDURE sp_tbl_company_template_custom_c_000(
    p_co_cd varchar,
    p_tmpl_cd varchar,
    p_tmpl_nm_ovr varchar,
    p_form_path varchar,
    p_id varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    IF COALESCE(p_co_cd,'')='' OR COALESCE(p_tmpl_cd,'')='' OR COALESCE(p_form_path,'')='' OR COALESCE(p_id,'')='' THEN
        RAISE EXCEPTION '자사 양식 정보가 올바르지 않습니다.' USING ERRCODE='45000';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM tbl_template t WHERE t.tmpl_cd = p_tmpl_cd AND t.use_yn = 'Y') THEN
        RAISE EXCEPTION '기준 양식 코드를 찾을 수 없습니다.' USING ERRCODE='45000';
    END IF;
    INSERT INTO tbl_company_template (
        co_cd, tmpl_cd, tmpl_nm_ovr, form_path, use_yn, sys_yn, ins_id, ins_dt
    ) VALUES (
        p_co_cd, p_tmpl_cd, NULLIF(p_tmpl_nm_ovr,''), p_form_path, 'Y', 'N', p_id, now()
    )
    ON CONFLICT (co_cd, tmpl_cd) DO UPDATE SET
        tmpl_nm_ovr = COALESCE(EXCLUDED.tmpl_nm_ovr, tbl_company_template.tmpl_nm_ovr),
        form_path = EXCLUDED.form_path,
        use_yn = 'Y',
        sys_yn = 'usr',
        upd_id = p_id,
        upd_dt = now();
END$$;

COMMENT ON PROCEDURE sp_tbl_company_template_custom_c_000 IS
    '자사 HWP 원본 등록 — form_path에 _template/{co_cd}/한글명을 저장하고 sys_yn=N';

-- ------------------------------------------------------------
-- 3. 메뉴·권한 — equipment/pest → history
-- ------------------------------------------------------------
UPDATE tbl_menu m
   SET scrn_cd = 'equipment-history',
       menu_nm = CASE WHEN m.menu_nm LIKE '%설비%' THEN '설비 이력' ELSE m.menu_nm END,
       use_yn = 'Y',
       upd_id = 'system',
       upd_dt = now()
 WHERE m.scrn_cd = 'equipment-management';

INSERT INTO tbl_role_screen (
    co_cd, usrgrp_cd, scrn_cd, read_yn, write_yn, modify_yn, delete_yn, print_yn, ins_id, ins_dt
)
SELECT r.co_cd, r.usrgrp_cd, 'equipment-history',
       COALESCE(r.read_yn,'Y'), COALESCE(r.write_yn,'Y'), COALESCE(r.modify_yn,'Y'),
       COALESCE(r.delete_yn,'Y'), COALESCE(r.print_yn,'Y'), 'system', now()
  FROM tbl_role_screen r
 WHERE r.scrn_cd = 'equipment-management'
ON CONFLICT (co_cd, usrgrp_cd, scrn_cd) DO UPDATE SET
    read_yn = GREATEST(tbl_role_screen.read_yn, EXCLUDED.read_yn),
    write_yn = GREATEST(tbl_role_screen.write_yn, EXCLUDED.write_yn),
    modify_yn = GREATEST(tbl_role_screen.modify_yn, EXCLUDED.modify_yn),
    delete_yn = GREATEST(tbl_role_screen.delete_yn, EXCLUDED.delete_yn),
    print_yn = GREATEST(tbl_role_screen.print_yn, EXCLUDED.print_yn),
    upd_id = 'system',
    upd_dt = now();

INSERT INTO tbl_role_screen (
    co_cd, usrgrp_cd, scrn_cd, read_yn, write_yn, modify_yn, delete_yn, print_yn, ins_id, ins_dt
)
SELECT r.co_cd, r.usrgrp_cd, 'pest-device-history',
       COALESCE(r.read_yn,'Y'), COALESCE(r.write_yn,'Y'), COALESCE(r.modify_yn,'Y'),
       COALESCE(r.delete_yn,'Y'), COALESCE(r.print_yn,'Y'), 'system', now()
  FROM tbl_role_screen r
 WHERE r.scrn_cd = 'pest-device-management'
ON CONFLICT (co_cd, usrgrp_cd, scrn_cd) DO UPDATE SET
    read_yn = GREATEST(tbl_role_screen.read_yn, EXCLUDED.read_yn),
    write_yn = GREATEST(tbl_role_screen.write_yn, EXCLUDED.write_yn),
    modify_yn = GREATEST(tbl_role_screen.modify_yn, EXCLUDED.modify_yn),
    delete_yn = GREATEST(tbl_role_screen.delete_yn, EXCLUDED.delete_yn),
    print_yn = GREATEST(tbl_role_screen.print_yn, EXCLUDED.print_yn),
    upd_id = 'system',
    upd_dt = now();

-- ------------------------------------------------------------
-- 4. 설비 저장 — photo_path COALESCE
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_master_c_000(
    p_co_cd varchar,
    p_master_type varchar,
    p_payload jsonb,
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_idx bigint := NULLIF(p_payload->>'idx', '')::bigint;
BEGIN
    IF COALESCE(p_co_cd, '') = '' OR COALESCE(p_id, '') = '' THEN RAISE EXCEPTION '로그인 정보가 올바르지 않습니다.' USING ERRCODE = '45000'; END IF;
    IF p_payload IS NULL OR jsonb_typeof(p_payload) <> 'object' THEN RAISE EXCEPTION '저장할 기준정보 행이 올바르지 않습니다.' USING ERRCODE = '45000'; END IF;

    CASE p_master_type
        WHEN 'product' THEN
            IF COALESCE(p_payload->>'productCd', '') = '' OR COALESCE(p_payload->>'productNm', '') = '' THEN RAISE EXCEPTION '제품코드와 제품명은 필수입니다.' USING ERRCODE = '45000'; END IF;
            IF v_idx IS NULL THEN INSERT INTO tbl_product(co_cd,product_cd,product_nm,spec_nm,unit_nm,pkg_type,storage_type,shelf_life_day,report_no,haccp_yn,use_yn,ins_id) VALUES(p_co_cd,p_payload->>'productCd',p_payload->>'productNm',NULLIF(p_payload->>'specNm',''),NULLIF(p_payload->>'unitNm',''),NULLIF(p_payload->>'pkgType',''),NULLIF(p_payload->>'storageType',''),NULLIF(p_payload->>'shelfLifeDay','')::int,NULLIF(p_payload->>'reportNo',''),COALESCE(NULLIF(p_payload->>'haccpYn',''),'Y'),COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),p_id);
            ELSE UPDATE tbl_product SET product_cd=p_payload->>'productCd',product_nm=p_payload->>'productNm',spec_nm=NULLIF(p_payload->>'specNm',''),unit_nm=NULLIF(p_payload->>'unitNm',''),pkg_type=NULLIF(p_payload->>'pkgType',''),storage_type=NULLIF(p_payload->>'storageType',''),shelf_life_day=NULLIF(p_payload->>'shelfLifeDay','')::int,report_no=NULLIF(p_payload->>'reportNo',''),haccp_yn=COALESCE(NULLIF(p_payload->>'haccpYn',''),'Y'),use_yn=COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),upd_id=p_id,upd_dt=now() WHERE idx=v_idx AND co_cd=p_co_cd; END IF;
        WHEN 'material' THEN
            IF COALESCE(p_payload->>'materialCd', '') = '' OR COALESCE(p_payload->>'materialNm', '') = '' OR COALESCE(p_payload->>'materialGbn', '') = '' THEN RAISE EXCEPTION '원부재료 코드·명칭·구분은 필수입니다.' USING ERRCODE = '45000'; END IF;
            IF v_idx IS NULL THEN INSERT INTO tbl_material(co_cd,material_cd,material_nm,material_gbn,spec_nm,unit_nm,storage_type,partner_cd,shelf_life_day,haccp_yn,insp_std,use_yn,ins_id) VALUES(p_co_cd,p_payload->>'materialCd',p_payload->>'materialNm',p_payload->>'materialGbn',NULLIF(p_payload->>'specNm',''),NULLIF(p_payload->>'unitNm',''),NULLIF(p_payload->>'storageType',''),NULLIF(p_payload->>'partnerCd',''),NULLIF(p_payload->>'shelfLifeDay','')::int,COALESCE(NULLIF(p_payload->>'haccpYn',''),'N'),NULLIF(p_payload->>'inspStd',''),COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),p_id);
            ELSE UPDATE tbl_material SET material_cd=p_payload->>'materialCd',material_nm=p_payload->>'materialNm',material_gbn=p_payload->>'materialGbn',spec_nm=NULLIF(p_payload->>'specNm',''),unit_nm=NULLIF(p_payload->>'unitNm',''),storage_type=NULLIF(p_payload->>'storageType',''),partner_cd=NULLIF(p_payload->>'partnerCd',''),shelf_life_day=NULLIF(p_payload->>'shelfLifeDay','')::int,haccp_yn=COALESCE(NULLIF(p_payload->>'haccpYn',''),'N'),insp_std=NULLIF(p_payload->>'inspStd',''),use_yn=COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),upd_id=p_id,upd_dt=now() WHERE idx=v_idx AND co_cd=p_co_cd; END IF;
        WHEN 'partner' THEN
            IF COALESCE(p_payload->>'partnerCd', '') = '' OR COALESCE(p_payload->>'partnerNm', '') = '' OR COALESCE(p_payload->>'partnerGbn', '') = '' THEN RAISE EXCEPTION '거래처 코드·명칭·구분은 필수입니다.' USING ERRCODE = '45000'; END IF;
            IF v_idx IS NULL THEN INSERT INTO tbl_partner(co_cd,partner_cd,partner_nm,partner_gbn,biz_no,ceo_nm,tel_no,fax_no,mng_nm,mobile,email,zip_no,addr_h,addr_d,haccp_yn,coop_list_yn,use_yn,ins_id) VALUES(p_co_cd,p_payload->>'partnerCd',p_payload->>'partnerNm',p_payload->>'partnerGbn',NULLIF(p_payload->>'bizNo',''),NULLIF(p_payload->>'ceoNm',''),NULLIF(p_payload->>'telNo',''),NULLIF(p_payload->>'faxNo',''),NULLIF(p_payload->>'mngNm',''),NULLIF(p_payload->>'mobile',''),NULLIF(p_payload->>'email',''),NULLIF(p_payload->>'zipNo',''),NULLIF(p_payload->>'addrH',''),NULLIF(p_payload->>'addrD',''),COALESCE(NULLIF(p_payload->>'haccpYn',''),'N'),COALESCE(NULLIF(p_payload->>'coopListYn',''),'N'),COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),p_id);
            ELSE UPDATE tbl_partner SET partner_cd=p_payload->>'partnerCd',partner_nm=p_payload->>'partnerNm',partner_gbn=p_payload->>'partnerGbn',biz_no=NULLIF(p_payload->>'bizNo',''),ceo_nm=NULLIF(p_payload->>'ceoNm',''),tel_no=NULLIF(p_payload->>'telNo',''),fax_no=NULLIF(p_payload->>'faxNo',''),mng_nm=NULLIF(p_payload->>'mngNm',''),mobile=NULLIF(p_payload->>'mobile',''),email=NULLIF(p_payload->>'email',''),zip_no=NULLIF(p_payload->>'zipNo',''),addr_h=NULLIF(p_payload->>'addrH',''),addr_d=NULLIF(p_payload->>'addrD',''),haccp_yn=COALESCE(NULLIF(p_payload->>'haccpYn',''),'N'),coop_list_yn=COALESCE(NULLIF(p_payload->>'coopListYn',''),'N'),use_yn=COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),upd_id=p_id,upd_dt=now() WHERE idx=v_idx AND co_cd=p_co_cd; END IF;
        WHEN 'storage' THEN
            IF COALESCE(p_payload->>'storageCd', '') = '' OR COALESCE(p_payload->>'storageNm', '') = '' OR COALESCE(p_payload->>'storageType', '') = '' THEN RAISE EXCEPTION '보관고 코드·명칭·유형은 필수입니다.' USING ERRCODE = '45000'; END IF;
            IF v_idx IS NULL THEN INSERT INTO tbl_storage(co_cd,storage_cd,storage_nm,storage_type,ccp_cd,temp_min,temp_max,sensor_yn,place_nm,sort_no,use_yn,ins_id) VALUES(p_co_cd,p_payload->>'storageCd',p_payload->>'storageNm',p_payload->>'storageType',NULLIF(p_payload->>'ccpCd',''),NULLIF(p_payload->>'tempMin','')::numeric,NULLIF(p_payload->>'tempMax','')::numeric,COALESCE(NULLIF(p_payload->>'sensorYn',''),'N'),NULLIF(p_payload->>'placeNm',''),COALESCE(NULLIF(p_payload->>'sortNo','')::int,0),COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),p_id);
            ELSE UPDATE tbl_storage SET storage_cd=p_payload->>'storageCd',storage_nm=p_payload->>'storageNm',storage_type=p_payload->>'storageType',ccp_cd=NULLIF(p_payload->>'ccpCd',''),temp_min=NULLIF(p_payload->>'tempMin','')::numeric,temp_max=NULLIF(p_payload->>'tempMax','')::numeric,sensor_yn=COALESCE(NULLIF(p_payload->>'sensorYn',''),'N'),place_nm=NULLIF(p_payload->>'placeNm',''),sort_no=COALESCE(NULLIF(p_payload->>'sortNo','')::int,0),use_yn=COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),upd_id=p_id,upd_dt=now() WHERE idx=v_idx AND co_cd=p_co_cd; END IF;
        WHEN 'equipment' THEN
            IF COALESCE(p_payload->>'equipCd', '') = '' OR COALESCE(p_payload->>'equipNm', '') = '' THEN RAISE EXCEPTION '설비 코드와 설비명은 필수입니다.' USING ERRCODE = '45000'; END IF;
            IF v_idx IS NULL THEN INSERT INTO tbl_equipment(co_cd,equip_cd,equip_nm,equip_kind,purpose_nm,model_nm,spec_nm,maker_nm,made_country,buy_dt,install_dt,use_range,place_nm,photo_path,as_mng_nm,use_method,use_yn,ins_id) VALUES(p_co_cd,p_payload->>'equipCd',p_payload->>'equipNm',NULLIF(p_payload->>'equipKind',''),NULLIF(p_payload->>'purposeNm',''),NULLIF(p_payload->>'modelNm',''),NULLIF(p_payload->>'specNm',''),NULLIF(p_payload->>'makerNm',''),NULLIF(p_payload->>'madeCountry',''),NULLIF(p_payload->>'buyDt',''),NULLIF(p_payload->>'installDt',''),NULLIF(p_payload->>'useRange',''),NULLIF(p_payload->>'placeNm',''),NULLIF(p_payload->>'photoPath',''),NULLIF(p_payload->>'asMngNm',''),NULLIF(p_payload->>'useMethod',''),COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),p_id);
            ELSE UPDATE tbl_equipment SET equip_cd=p_payload->>'equipCd',equip_nm=p_payload->>'equipNm',equip_kind=NULLIF(p_payload->>'equipKind',''),purpose_nm=NULLIF(p_payload->>'purposeNm',''),model_nm=NULLIF(p_payload->>'modelNm',''),spec_nm=NULLIF(p_payload->>'specNm',''),maker_nm=NULLIF(p_payload->>'makerNm',''),made_country=NULLIF(p_payload->>'madeCountry',''),buy_dt=NULLIF(p_payload->>'buyDt',''),install_dt=NULLIF(p_payload->>'installDt',''),use_range=NULLIF(p_payload->>'useRange',''),place_nm=NULLIF(p_payload->>'placeNm',''),photo_path=COALESCE(NULLIF(p_payload->>'photoPath',''), photo_path),as_mng_nm=NULLIF(p_payload->>'asMngNm',''),use_method=NULLIF(p_payload->>'useMethod',''),use_yn=COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),upd_id=p_id,upd_dt=now() WHERE idx=v_idx AND co_cd=p_co_cd; END IF;
        WHEN 'measuring-device' THEN
            IF COALESCE(p_payload->>'deviceCd', '') = '' OR COALESCE(p_payload->>'deviceNm', '') = '' OR COALESCE(p_payload->>'deviceType', '') = '' THEN RAISE EXCEPTION '계측기 코드·명칭·유형은 필수입니다.' USING ERRCODE = '45000'; END IF;
            IF v_idx IS NULL THEN INSERT INTO tbl_measuring_device(co_cd,device_cd,device_nm,device_type,model_nm,maker_nm,spec_nm,tolerance_val,tolerance_unit,calib_cycle_month,place_nm,sort_no,use_yn,ins_id) VALUES(p_co_cd,p_payload->>'deviceCd',p_payload->>'deviceNm',p_payload->>'deviceType',NULLIF(p_payload->>'modelNm',''),NULLIF(p_payload->>'makerNm',''),NULLIF(p_payload->>'specNm',''),NULLIF(p_payload->>'toleranceVal','')::numeric,NULLIF(p_payload->>'toleranceUnit',''),COALESCE(NULLIF(p_payload->>'calibCycleMonth','')::int,12),NULLIF(p_payload->>'placeNm',''),COALESCE(NULLIF(p_payload->>'sortNo','')::int,0),COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),p_id);
            ELSE UPDATE tbl_measuring_device SET device_cd=p_payload->>'deviceCd',device_nm=p_payload->>'deviceNm',device_type=p_payload->>'deviceType',model_nm=NULLIF(p_payload->>'modelNm',''),maker_nm=NULLIF(p_payload->>'makerNm',''),spec_nm=NULLIF(p_payload->>'specNm',''),tolerance_val=NULLIF(p_payload->>'toleranceVal','')::numeric,tolerance_unit=NULLIF(p_payload->>'toleranceUnit',''),calib_cycle_month=COALESCE(NULLIF(p_payload->>'calibCycleMonth','')::int,12),place_nm=NULLIF(p_payload->>'placeNm',''),sort_no=COALESCE(NULLIF(p_payload->>'sortNo','')::int,0),use_yn=COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),upd_id=p_id,upd_dt=now() WHERE idx=v_idx AND co_cd=p_co_cd; END IF;
        WHEN 'pest-device' THEN
            IF COALESCE(p_payload->>'pestCd', '') = '' OR COALESCE(p_payload->>'pestNm', '') = '' OR COALESCE(p_payload->>'pestType', '') = '' THEN RAISE EXCEPTION '방충방서 설비 코드·명칭·유형은 필수입니다.' USING ERRCODE = '45000'; END IF;
            IF v_idx IS NULL THEN INSERT INTO tbl_pest_device(co_cd,pest_cd,pest_nm,pest_type,place_nm,sort_no,use_yn,ins_id) VALUES(p_co_cd,p_payload->>'pestCd',p_payload->>'pestNm',p_payload->>'pestType',NULLIF(p_payload->>'placeNm',''),COALESCE(NULLIF(p_payload->>'sortNo','')::int,0),COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),p_id);
            ELSE UPDATE tbl_pest_device SET pest_cd=p_payload->>'pestCd',pest_nm=p_payload->>'pestNm',pest_type=p_payload->>'pestType',place_nm=NULLIF(p_payload->>'placeNm',''),sort_no=COALESCE(NULLIF(p_payload->>'sortNo','')::int,0),use_yn=COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),upd_id=p_id,upd_dt=now() WHERE idx=v_idx AND co_cd=p_co_cd; END IF;
        WHEN 'vehicle' THEN
            IF COALESCE(p_payload->>'vehicleCd', '') = '' OR COALESCE(p_payload->>'carNo', '') = '' THEN RAISE EXCEPTION '차량 코드와 차량번호는 필수입니다.' USING ERRCODE = '45000'; END IF;
            IF v_idx IS NULL THEN INSERT INTO tbl_vehicle(co_cd,vehicle_cd,car_no,car_type,owner_nm,driver_nm,cooler_yn,temp_recorder_yn,use_yn,ins_id) VALUES(p_co_cd,p_payload->>'vehicleCd',p_payload->>'carNo',NULLIF(p_payload->>'carType',''),NULLIF(p_payload->>'ownerNm',''),NULLIF(p_payload->>'driverNm',''),COALESCE(NULLIF(p_payload->>'coolerYn',''),'Y'),COALESCE(NULLIF(p_payload->>'tempRecorderYn',''),'Y'),COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),p_id);
            ELSE UPDATE tbl_vehicle SET vehicle_cd=p_payload->>'vehicleCd',car_no=p_payload->>'carNo',car_type=NULLIF(p_payload->>'carType',''),owner_nm=NULLIF(p_payload->>'ownerNm',''),driver_nm=NULLIF(p_payload->>'driverNm',''),cooler_yn=COALESCE(NULLIF(p_payload->>'coolerYn',''),'Y'),temp_recorder_yn=COALESCE(NULLIF(p_payload->>'tempRecorderYn',''),'Y'),use_yn=COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),upd_id=p_id,upd_dt=now() WHERE idx=v_idx AND co_cd=p_co_cd; END IF;
        WHEN 'work-area' THEN
            IF COALESCE(p_payload->>'areaCd', '') = '' OR COALESCE(p_payload->>'areaNm', '') = '' THEN RAISE EXCEPTION '작업구역 코드와 명칭은 필수입니다.' USING ERRCODE = '45000'; END IF;
            IF v_idx IS NULL THEN INSERT INTO tbl_work_area(co_cd,area_cd,area_nm,area_gbn,lux_std,temp_std_min,temp_std_max,humid_std_min,humid_std_max,sort_no,use_yn,ins_id) VALUES(p_co_cd,p_payload->>'areaCd',p_payload->>'areaNm',NULLIF(p_payload->>'areaGbn',''),NULLIF(p_payload->>'luxStd','')::int,NULLIF(p_payload->>'tempStdMin','')::numeric,NULLIF(p_payload->>'tempStdMax','')::numeric,NULLIF(p_payload->>'humidStdMin','')::numeric,NULLIF(p_payload->>'humidStdMax','')::numeric,COALESCE(NULLIF(p_payload->>'sortNo','')::int,0),COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),p_id);
            ELSE UPDATE tbl_work_area SET area_cd=p_payload->>'areaCd',area_nm=p_payload->>'areaNm',area_gbn=NULLIF(p_payload->>'areaGbn',''),lux_std=NULLIF(p_payload->>'luxStd','')::int,temp_std_min=NULLIF(p_payload->>'tempStdMin','')::numeric,temp_std_max=NULLIF(p_payload->>'tempStdMax','')::numeric,humid_std_min=NULLIF(p_payload->>'humidStdMin','')::numeric,humid_std_max=NULLIF(p_payload->>'humidStdMax','')::numeric,sort_no=COALESCE(NULLIF(p_payload->>'sortNo','')::int,0),use_yn=COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),upd_id=p_id,upd_dt=now() WHERE idx=v_idx AND co_cd=p_co_cd; END IF;
        WHEN 'ccp-limit' THEN
            IF COALESCE(p_payload->>'ccpCd', '') = '' OR COALESCE(p_payload->>'ccpNm', '') = '' OR COALESCE(p_payload->>'limitType', '') = '' THEN RAISE EXCEPTION 'CCP 코드·명칭·기준유형은 필수입니다.' USING ERRCODE = '45000'; END IF;
            IF v_idx IS NULL THEN INSERT INTO tbl_ccp_limit(co_cd,ccp_cd,ccp_nm,proc_nm,limit_type,min_val,max_val,unit_nm,fe_size,sts_size,cycle_min,form_title,cycle_rmk,limit_rmk,method_rmk,improve_rmk,use_yn,ins_id) VALUES(p_co_cd,p_payload->>'ccpCd',p_payload->>'ccpNm',NULLIF(p_payload->>'procNm',''),p_payload->>'limitType',NULLIF(p_payload->>'minVal','')::numeric,NULLIF(p_payload->>'maxVal','')::numeric,NULLIF(p_payload->>'unitNm',''),NULLIF(p_payload->>'feSize','')::numeric,NULLIF(p_payload->>'stsSize','')::numeric,NULLIF(p_payload->>'cycleMin','')::int,NULLIF(p_payload->>'formTitle',''),NULLIF(p_payload->>'cycleRmk',''),NULLIF(p_payload->>'limitRmk',''),NULLIF(p_payload->>'methodRmk',''),NULLIF(p_payload->>'improveRmk',''),COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),p_id);
            ELSE UPDATE tbl_ccp_limit SET ccp_cd=p_payload->>'ccpCd',ccp_nm=p_payload->>'ccpNm',proc_nm=NULLIF(p_payload->>'procNm',''),limit_type=p_payload->>'limitType',min_val=NULLIF(p_payload->>'minVal','')::numeric,max_val=NULLIF(p_payload->>'maxVal','')::numeric,unit_nm=NULLIF(p_payload->>'unitNm',''),fe_size=NULLIF(p_payload->>'feSize','')::numeric,sts_size=NULLIF(p_payload->>'stsSize','')::numeric,cycle_min=NULLIF(p_payload->>'cycleMin','')::int,form_title=NULLIF(p_payload->>'formTitle',''),cycle_rmk=NULLIF(p_payload->>'cycleRmk',''),limit_rmk=NULLIF(p_payload->>'limitRmk',''),method_rmk=NULLIF(p_payload->>'methodRmk',''),improve_rmk=NULLIF(p_payload->>'improveRmk',''),use_yn=COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),upd_id=p_id,upd_dt=now() WHERE idx=v_idx AND co_cd=p_co_cd; END IF;
        ELSE RAISE EXCEPTION '지원하지 않는 기준정보입니다.' USING ERRCODE = '45000';
    END CASE;
    IF v_idx IS NOT NULL AND NOT FOUND THEN RAISE EXCEPTION '수정할 기준정보를 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
END$$;
