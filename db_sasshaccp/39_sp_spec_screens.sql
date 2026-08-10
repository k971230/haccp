-- ============================================================
-- 39 — 건강진단·설비이력 SP + 방충 yn·마스터 컬럼 보강 + Wave1 CCP UI SP
--
-- 개발자: 박승우
-- 일자: 2026-08-07
-- 코멘트:
--   1) HA-HYG-02 건강진단 그리드 CRUD
--   2) HA-FAC-08 설비 이력 디테일 CRUD
--   3) 마스터 partner/equipment/ccp-limit 및 CCP cold/metal/generic 컬럼 라운드트립
-- ============================================================

SET search_path TO sasshaccp;

-- RETURNS 시그니처 변경 대비 — cold 목록 FN 선 DROP (본문 하단 재정의)
DROP FUNCTION IF EXISTS sp_tbl_ccp_cold_monitor_r_000(varchar, varchar, varchar, varchar, varchar, varchar);

-- ------------------------------------------------------------
-- 건강진단
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_health_cert_r_000(
    p_co_cd varchar,
    p_person_nm varchar,
    p_use_yn varchar
)
RETURNS SETOF jsonb
LANGUAGE sql STABLE AS $$
    SELECT to_jsonb(t) - 'ins_id' - 'ins_dt' - 'upd_id' - 'upd_dt'
      || jsonb_build_object(
           'personNm', t.person_nm,
           'examDt', t.exam_dt,
           'expireDt', t.expire_dt,
           'filePath', t.file_path,
           'fileNm', t.file_nm,
           'useYn', t.use_yn
         )
      FROM tbl_health_cert t
     WHERE t.co_cd = p_co_cd
       AND (COALESCE(p_person_nm,'') = '' OR t.person_nm LIKE '%'||p_person_nm||'%')
       AND (COALESCE(p_use_yn,'') = '' OR t.use_yn = p_use_yn)
     ORDER BY t.expire_dt NULLS LAST, t.person_nm;
$$;

CREATE OR REPLACE PROCEDURE sp_tbl_health_cert_c_000(
    p_co_cd varchar,
    p_payload jsonb,
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_idx bigint := NULLIF(p_payload->>'idx','')::bigint;
BEGIN
    IF COALESCE(p_co_cd,'')='' OR COALESCE(p_id,'')='' THEN
        RAISE EXCEPTION '로그인 정보가 올바르지 않습니다.' USING ERRCODE='45000';
    END IF;
    IF COALESCE(p_payload->>'personNm','')='' OR COALESCE(p_payload->>'examDt','')='' THEN
        RAISE EXCEPTION '성명과 검진일은 필수입니다.' USING ERRCODE='45000';
    END IF;
    IF v_idx IS NULL THEN
        INSERT INTO tbl_health_cert(co_cd, person_nm, exam_dt, expire_dt, remark, file_path, file_nm, use_yn, ins_id)
        VALUES (
            p_co_cd,
            p_payload->>'personNm',
            p_payload->>'examDt',
            NULLIF(p_payload->>'expireDt',''),
            NULLIF(p_payload->>'remark',''),
            NULLIF(p_payload->>'filePath',''),
            NULLIF(p_payload->>'fileNm',''),
            COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),
            p_id
        );
    ELSE
        UPDATE tbl_health_cert SET
            person_nm = p_payload->>'personNm',
            exam_dt   = p_payload->>'examDt',
            expire_dt = NULLIF(p_payload->>'expireDt',''),
            remark    = NULLIF(p_payload->>'remark',''),
            file_path = COALESCE(NULLIF(p_payload->>'filePath',''), file_path),
            file_nm   = COALESCE(NULLIF(p_payload->>'fileNm',''), file_nm),
            use_yn    = COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),
            upd_id    = p_id,
            upd_dt    = now()
         WHERE idx = v_idx AND co_cd = p_co_cd;
        IF NOT FOUND THEN
            RAISE EXCEPTION '수정할 건강진단 기록을 찾을 수 없습니다.' USING ERRCODE='45000';
        END IF;
    END IF;
END$$;

CREATE OR REPLACE PROCEDURE sp_tbl_health_cert_d_000(
    p_co_cd varchar,
    p_idx bigint,
    p_id varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    IF p_idx IS NULL OR p_idx <= 0 THEN
        RAISE EXCEPTION '삭제할 항목을 선택하세요.' USING ERRCODE='45000';
    END IF;
    DELETE FROM tbl_health_cert WHERE idx = p_idx AND co_cd = p_co_cd;
    IF NOT FOUND THEN
        RAISE EXCEPTION '삭제할 건강진단 기록을 찾을 수 없습니다.' USING ERRCODE='45000';
    END IF;
END$$;

-- ------------------------------------------------------------
-- 설비 이력
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_equipment_hist_r_000(
    p_co_cd varchar,
    p_equip_idx bigint
)
RETURNS SETOF jsonb
LANGUAGE sql STABLE AS $$
    SELECT jsonb_build_object(
             'idx', h.idx,
             'equipIdx', h.equip_idx,
             'histDt', h.hist_dt,
             'faultRmk', h.fault_rmk,
             'actionRmk', h.action_rmk,
             'docIdx', h.doc_idx,
             'remark', h.remark
           )
      FROM tbl_equipment_hist h
     WHERE h.co_cd = p_co_cd
       AND h.equip_idx = p_equip_idx
     ORDER BY h.hist_dt DESC, h.idx DESC;
$$;

CREATE OR REPLACE PROCEDURE sp_tbl_equipment_hist_c_000(
    p_co_cd varchar,
    p_payload jsonb,
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_idx bigint := NULLIF(p_payload->>'idx','')::bigint;
    v_equip bigint := NULLIF(p_payload->>'equipIdx','')::bigint;
BEGIN
    IF COALESCE(p_co_cd,'')='' OR COALESCE(p_id,'')='' THEN
        RAISE EXCEPTION '로그인 정보가 올바르지 않습니다.' USING ERRCODE='45000';
    END IF;
    IF v_equip IS NULL OR COALESCE(p_payload->>'histDt','')='' THEN
        RAISE EXCEPTION '설비와 이력일은 필수입니다.' USING ERRCODE='45000';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM tbl_equipment WHERE idx=v_equip AND co_cd=p_co_cd) THEN
        RAISE EXCEPTION '설비를 찾을 수 없습니다.' USING ERRCODE='45000';
    END IF;
    IF v_idx IS NULL THEN
        INSERT INTO tbl_equipment_hist(co_cd, equip_idx, hist_dt, fault_rmk, action_rmk, doc_idx, remark, ins_id)
        VALUES (
            p_co_cd, v_equip, p_payload->>'histDt',
            NULLIF(p_payload->>'faultRmk',''),
            NULLIF(p_payload->>'actionRmk',''),
            NULLIF(p_payload->>'docIdx','')::bigint,
            NULLIF(p_payload->>'remark',''),
            p_id
        );
    ELSE
        UPDATE tbl_equipment_hist SET
            hist_dt = p_payload->>'histDt',
            fault_rmk = NULLIF(p_payload->>'faultRmk',''),
            action_rmk = NULLIF(p_payload->>'actionRmk',''),
            doc_idx = NULLIF(p_payload->>'docIdx','')::bigint,
            remark = NULLIF(p_payload->>'remark',''),
            upd_id = p_id,
            upd_dt = now()
         WHERE idx = v_idx AND co_cd = p_co_cd AND equip_idx = v_equip;
        IF NOT FOUND THEN
            RAISE EXCEPTION '수정할 이력을 찾을 수 없습니다.' USING ERRCODE='45000';
        END IF;
    END IF;
END$$;

CREATE OR REPLACE PROCEDURE sp_tbl_equipment_hist_d_000(
    p_co_cd varchar,
    p_idx bigint,
    p_id varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    IF p_idx IS NULL OR p_idx <= 0 THEN
        RAISE EXCEPTION '삭제할 이력을 선택하세요.' USING ERRCODE='45000';
    END IF;
    DELETE FROM tbl_equipment_hist WHERE idx = p_idx AND co_cd = p_co_cd;
    IF NOT FOUND THEN
        RAISE EXCEPTION '삭제할 이력을 찾을 수 없습니다.' USING ERRCODE='45000';
    END IF;
END$$;

-- ------------------------------------------------------------
-- 마스터 저장 — partner coop_list_yn / equipment 확장 / ccp improve_rmk
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
            -- photo_path: 빈값이면 기존 경로 유지 (부분 저장·사진 미전송 시 NULL 덮어쓰기 방지)
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

-- ============================================================
-- Wave1 CCP UI 컬럼 라운드트립 — cold writer/sign, metal place_nm, generic equip/product
--
-- 개발자: 박승우
-- 일자: 2026-08-07
-- 코멘트:
--   1) 38 DDL 보강 컬럼을 조회·저장 SP에 연결한다
--   2) 시그니처가 바뀌는 조회는 DROP 후 재생성한다
--   3) 검증 monitor_chk_rmk는 BE UPDATE로 저장하므로 여기 포함하지 않는다
-- ============================================================

-- ------------------------------------------------------------
-- 냉장 점검행 조회 — writer_id/nm · sign_path
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_ccp_cold_monitor_row_r_000(varchar, bigint);
CREATE FUNCTION sp_tbl_ccp_cold_monitor_row_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_hdr_idx: 헤더 idx
    p_hdr_idx bigint
)
RETURNS TABLE (
    idx          bigint,
    co_cd        varchar,
    hdr_idx      bigint,
    row_seq      int,
    check_time   varchar,
    judge_cd     varchar,
    judge_mod_yn varchar,
    checker_id   varchar,
    checker_nm   varchar,
    writer_id    varchar,
    writer_nm    varchar,
    sign_path    varchar
)
LANGUAGE sql STABLE AS $$
    SELECT r.idx, r.co_cd, r.hdr_idx, r.row_seq, r.check_time,
           r.judge_cd, r.judge_mod_yn, r.checker_id, r.checker_nm,
           r.writer_id, r.writer_nm, r.sign_path
      FROM tbl_ccp_cold_monitor_row r
     WHERE r.co_cd = p_co_cd
       AND r.hdr_idx = p_hdr_idx
     ORDER BY r.row_seq;
$$;
COMMENT ON FUNCTION sp_tbl_ccp_cold_monitor_row_r_000(varchar, bigint) IS
  'CCP 냉장보관 점검행 목록 — 작성자·서명 포함';

-- 냉장 목록 부적합 — 자동 F · 수동 X 모두 집계
CREATE OR REPLACE FUNCTION sp_tbl_ccp_cold_monitor_r_000(
    p_co_cd   varchar,
    p_from_dt varchar,
    p_to_dt   varchar,
    p_ccp_cd  varchar,
    p_doc_no  varchar,
    p_writer  varchar
)
RETURNS TABLE (
    doc_idx     bigint,
    hdr_idx     bigint,
    co_cd       varchar,
    doc_no      varchar,
    base_dt     varchar,
    ccp_cd      varchar,
    title       varchar,
    status      varchar,
    mng_user_id varchar,
    mng_nm      varchar,
    writer_id   varchar,
    write_dt    timestamp,
    row_cnt     int,
    ng_cnt      int
)
LANGUAGE sql STABLE AS $$
    SELECT d.idx, h.idx, d.co_cd, d.doc_no, h.base_dt, h.ccp_cd, d.title, d.status,
           h.mng_user_id, h.mng_nm, d.writer_id, d.write_dt,
           (SELECT COUNT(*)::int FROM tbl_ccp_cold_monitor_row r
             WHERE r.hdr_idx = h.idx AND r.co_cd = h.co_cd),
           (SELECT COUNT(*)::int FROM tbl_ccp_cold_monitor_row r
             WHERE r.hdr_idx = h.idx AND r.co_cd = h.co_cd AND r.judge_cd IN ('F', 'X'))
      FROM tbl_ccp_cold_monitor h
      JOIN tbl_document d ON d.idx = h.doc_idx AND d.co_cd = h.co_cd
      LEFT JOIN tbl_user u ON u.co_cd = d.co_cd AND u.user_id = d.writer_id
     WHERE h.co_cd = p_co_cd
       AND d.del_yn = 'N'
       AND d.tmpl_cd = 'CCP_COLD'
       AND (COALESCE(p_from_dt, '') = '' OR h.base_dt >= p_from_dt)
       AND (COALESCE(p_to_dt, '') = '' OR h.base_dt <= p_to_dt)
       AND (COALESCE(p_ccp_cd, '') = '' OR h.ccp_cd = p_ccp_cd)
       AND (COALESCE(p_doc_no, '') = '' OR d.doc_no ILIKE '%' || p_doc_no || '%')
       AND (
           COALESCE(p_writer, '') = ''
           OR d.writer_id ILIKE '%' || p_writer || '%'
           OR COALESCE(u.user_nm, '') ILIKE '%' || p_writer || '%'
       )
     ORDER BY h.base_dt DESC, d.doc_no DESC;
$$;

-- 냉장 저장 — 행 INSERT에 writer/sign 반영 (본문만 교체, 시그니처 동일)
CREATE OR REPLACE FUNCTION sp_tbl_ccp_cold_monitor_c_000(
    p_co_cd       varchar,
    p_doc_idx     bigint,
    p_base_dt     varchar,
    p_ccp_cd      varchar,
    p_mng_user_id varchar,
    p_mng_nm      varchar,
    p_rows_json   jsonb,
    p_id          varchar
)
RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE
    v_doc_idx   bigint;
    v_hdr_idx   bigint;
    v_doc_no    varchar(50);
    v_title     varchar(200);
    v_status    varchar(4);
    v_tmpl_nm   varchar(200);
    v_appr      varchar(20);
    v_retain_m  int;
    v_row       jsonb;
    v_temp      jsonb;
    v_row_idx   bigint;
    v_row_seq   int;
    v_check_tm  varchar(4);
    v_mod_yn    varchar(1);
    v_chk_id    varchar(20);
    v_chk_nm    varchar(50);
    v_wrt_id    varchar(20);
    v_wrt_nm    varchar(50);
    v_sign      varchar(300);
    v_man_judge varchar(1);
    v_row_judge varchar(1);
    v_st_cd     varchar(30);
    v_temp_val  numeric(5,1);
    v_cell_j    varchar(1);
    v_min       numeric(5,1);
    v_max       numeric(5,1);
    v_st_ccp    varchar(20);
BEGIN
    IF COALESCE(p_co_cd, '') = '' THEN
        RAISE EXCEPTION '회사코드는 필수입니다.' USING ERRCODE = '45000';
    END IF;
    IF COALESCE(p_base_dt, '') = '' OR length(p_base_dt) <> 8 THEN
        RAISE EXCEPTION '작성일은 YYYYMMDD 8자리로 입력하세요.' USING ERRCODE = '45000';
    END IF;
    IF COALESCE(p_ccp_cd, '') = '' THEN
        RAISE EXCEPTION 'CCP 코드는 필수입니다.' USING ERRCODE = '45000';
    END IF;
    IF p_rows_json IS NULL OR jsonb_typeof(p_rows_json) <> 'array' THEN
        RAISE EXCEPTION '점검 행 자료가 올바르지 않습니다.' USING ERRCODE = '45000';
    END IF;

    SELECT COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm),
           COALESCE(ct.appr_line_cd, 'DEFAULT'),
           COALESCE(ct.retention_month, t.default_retention_month)
      INTO v_tmpl_nm, v_appr, v_retain_m
      FROM tbl_template t
      LEFT JOIN tbl_company_template ct
        ON ct.co_cd = p_co_cd AND ct.tmpl_cd = t.tmpl_cd AND ct.use_yn = 'Y'
     WHERE t.tmpl_cd = 'CCP_COLD' AND t.use_yn = 'Y';

    IF v_tmpl_nm IS NULL THEN
        RAISE EXCEPTION 'CCP 냉장보관 양식이 등록되어 있지 않습니다.' USING ERRCODE = '45000';
    END IF;

    v_title := v_tmpl_nm || ' (' ||
               substr(p_base_dt, 1, 4) || '-' || substr(p_base_dt, 5, 2) || '-' || substr(p_base_dt, 7, 2) || ')';

    IF p_doc_idx IS NULL OR p_doc_idx = 0 THEN
        v_doc_no := sp_tbl_doc_no_gen_c_000(p_co_cd, 'CCP_COLD', p_base_dt);
        INSERT INTO tbl_document(
            co_cd, tmpl_cd, doc_kind, doc_no, base_dt, title, status,
            appr_line_cd, writer_id, write_dt, ver_no,
            retention_until, del_yn, ins_id, ins_dt
        )
        VALUES (
            p_co_cd, 'CCP_COLD', 'DB', v_doc_no, p_base_dt, v_title, 'WRK',
            v_appr, p_id, now(), 1,
            to_char(
                (to_date(p_base_dt, 'YYYYMMDD') + (COALESCE(v_retain_m, 24) || ' months')::interval)::date,
                'YYYYMMDD'
            ),
            'N', p_id, now()
        )
        RETURNING idx INTO v_doc_idx;
        INSERT INTO tbl_ccp_cold_monitor(
            co_cd, doc_idx, base_dt, ccp_cd, mng_user_id, mng_nm, ins_id, ins_dt
        )
        VALUES (
            p_co_cd, v_doc_idx, p_base_dt, p_ccp_cd,
            NULLIF(p_mng_user_id, ''), NULLIF(p_mng_nm, ''),
            p_id, now()
        )
        RETURNING idx INTO v_hdr_idx;
    ELSE
        SELECT d.idx, d.status, h.idx
          INTO v_doc_idx, v_status, v_hdr_idx
          FROM tbl_document d
          JOIN tbl_ccp_cold_monitor h ON h.doc_idx = d.idx AND h.co_cd = d.co_cd
         WHERE d.co_cd = p_co_cd
           AND d.idx = p_doc_idx
           AND d.tmpl_cd = 'CCP_COLD'
           AND d.del_yn = 'N';
        IF v_doc_idx IS NULL THEN
            RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        IF v_status IN ('REQ', 'REV', 'APV') THEN
            RAISE EXCEPTION '결재 진행 중이거나 완료된 문서는 수정할 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        UPDATE tbl_document
           SET base_dt = p_base_dt, title = v_title, upd_id = p_id, upd_dt = now()
         WHERE idx = v_doc_idx AND co_cd = p_co_cd;
        UPDATE tbl_ccp_cold_monitor
           SET base_dt = p_base_dt, ccp_cd = p_ccp_cd,
               mng_user_id = NULLIF(p_mng_user_id, ''), mng_nm = NULLIF(p_mng_nm, ''),
               upd_id = p_id, upd_dt = now()
         WHERE idx = v_hdr_idx AND co_cd = p_co_cd;
        DELETE FROM tbl_ccp_cold_monitor_temp t
         USING tbl_ccp_cold_monitor_row r
         WHERE t.row_idx = r.idx AND t.co_cd = r.co_cd
           AND r.hdr_idx = v_hdr_idx AND r.co_cd = p_co_cd;
        DELETE FROM tbl_ccp_cold_monitor_row
         WHERE hdr_idx = v_hdr_idx AND co_cd = p_co_cd;
    END IF;

    FOR v_row IN SELECT * FROM jsonb_array_elements(p_rows_json)
    LOOP
        v_row_seq   := COALESCE((v_row->>'rowSeq')::int, 0);
        v_check_tm  := COALESCE(v_row->>'checkTime', '');
        v_mod_yn    := COALESCE(NULLIF(v_row->>'judgeModYn', ''), 'N');
        v_chk_id    := NULLIF(v_row->>'checkerId', '');
        v_chk_nm    := NULLIF(v_row->>'checkerNm', '');
        v_wrt_id    := NULLIF(COALESCE(v_row->>'writerId', v_row->>'checkerId'), '');
        v_wrt_nm    := NULLIF(COALESCE(v_row->>'writerNm', v_row->>'checkerNm'), '');
        v_sign      := NULLIF(v_row->>'signPath', '');
        v_man_judge := NULLIF(v_row->>'judgeCd', '');

        IF v_row_seq <= 0 THEN
            RAISE EXCEPTION '점검 행 순번이 올바르지 않습니다.' USING ERRCODE = '45000';
        END IF;
        IF v_check_tm = '' THEN
            RAISE EXCEPTION '%번째 행의 점검시간이 없습니다.', v_row_seq USING ERRCODE = '45000';
        END IF;

        INSERT INTO tbl_ccp_cold_monitor_row(
            co_cd, hdr_idx, row_seq, check_time, judge_cd, judge_mod_yn,
            checker_id, checker_nm, writer_id, writer_nm, sign_path, ins_id, ins_dt
        )
        VALUES (
            p_co_cd, v_hdr_idx, v_row_seq, v_check_tm, NULL, v_mod_yn,
            v_chk_id, v_chk_nm, v_wrt_id, v_wrt_nm, v_sign, p_id, now()
        )
        RETURNING idx INTO v_row_idx;

        v_row_judge := NULL;
        FOR v_temp IN SELECT * FROM jsonb_array_elements(COALESCE(v_row->'temps', '[]'::jsonb))
        LOOP
            v_st_cd    := COALESCE(v_temp->>'storageCd', '');
            v_temp_val := NULLIF(v_temp->>'tempVal', '')::numeric;
            IF v_st_cd = '' THEN
                RAISE EXCEPTION '%번째 행의 보관고 코드가 없습니다.', v_row_seq USING ERRCODE = '45000';
            END IF;
            SELECT s.temp_min, s.temp_max, s.ccp_cd
              INTO v_min, v_max, v_st_ccp
              FROM tbl_storage s
             WHERE s.co_cd = p_co_cd AND s.storage_cd = v_st_cd AND s.use_yn = 'Y';
            IF NOT FOUND THEN
                RAISE EXCEPTION '사용 중인 보관고가 아닙니다: %', v_st_cd USING ERRCODE = '45000';
            END IF;
            IF v_min IS NULL OR v_max IS NULL THEN
                SELECT l.min_val, l.max_val INTO v_min, v_max
                  FROM tbl_ccp_limit l
                 WHERE l.co_cd = p_co_cd
                   AND l.ccp_cd = COALESCE(v_st_ccp, p_ccp_cd)
                   AND l.use_yn = 'Y';
            END IF;
            IF v_temp_val IS NULL THEN
                v_cell_j := NULL;
            ELSIF v_min IS NOT NULL AND v_temp_val < v_min THEN
                v_cell_j := 'F';
            ELSIF v_max IS NOT NULL AND v_temp_val > v_max THEN
                v_cell_j := 'F';
            ELSE
                v_cell_j := 'P';
            END IF;
            INSERT INTO tbl_ccp_cold_monitor_temp(
                co_cd, row_idx, storage_cd, temp_val, judge_cd, ins_id, ins_dt
            )
            VALUES (p_co_cd, v_row_idx, v_st_cd, v_temp_val, v_cell_j, p_id, now());
            IF v_cell_j = 'F' THEN
                v_row_judge := 'F';
            ELSIF v_cell_j = 'P' AND COALESCE(v_row_judge, '') <> 'F' THEN
                v_row_judge := 'P';
            END IF;
        END LOOP;

        -- 수동변경일 때(= O/X 또는 P/F) JSON judgeCd 우선
        IF v_mod_yn = 'Y' AND v_man_judge IS NOT NULL THEN
            v_row_judge := v_man_judge;
        END IF;

        UPDATE tbl_ccp_cold_monitor_row
           SET judge_cd = v_row_judge
         WHERE idx = v_row_idx AND co_cd = p_co_cd;
    END LOOP;

    RETURN v_doc_idx;
END$$;

-- ------------------------------------------------------------
-- 금속 감도행 — place_nm
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_ccp_metal_monitor_r_002(varchar, bigint);
CREATE FUNCTION sp_tbl_ccp_metal_monitor_r_002(
    p_co_cd   varchar,
    p_hdr_idx bigint
)
RETURNS TABLE (
    idx bigint, row_seq int, phase_cd varchar, product_cd varchar, product_nm varchar,
    place_nm varchar, check_time varchar, fe_only_cd varchar, sts_only_cd varchar, prod_only_cd varchar,
    fe_prod_cd varchar, sts_prod_cd varchar, judge_cd varchar, checker_id varchar, checker_nm varchar
)
LANGUAGE sql STABLE AS $$
    SELECT idx, row_seq, phase_cd, product_cd, product_nm, place_nm, check_time, fe_only_cd, sts_only_cd,
           prod_only_cd, fe_prod_cd, sts_prod_cd, judge_cd, checker_id, checker_nm
      FROM tbl_ccp_metal_sens_row
     WHERE co_cd = p_co_cd AND hdr_idx = p_hdr_idx ORDER BY row_seq;
$$;

CREATE OR REPLACE FUNCTION sp_tbl_ccp_metal_monitor_c_000(
    p_co_cd varchar, p_doc_idx bigint, p_base_dt varchar, p_ccp_cd varchar,
    p_fe_size numeric, p_sts_size numeric, p_mng_user_id varchar, p_mng_nm varchar,
    p_sens_rows_json jsonb,
    p_pass_rows_json jsonb,
    p_id varchar
)
RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE v_doc_idx bigint; v_hdr_idx bigint; v_status varchar(4); v_name varchar; v_appr varchar; v_retain int; r jsonb; v_judge varchar(1);
BEGIN
    IF COALESCE(p_base_dt, '') = '' OR length(p_base_dt) <> 8 THEN RAISE EXCEPTION '작성일은 YYYYMMDD 8자리로 입력하세요.' USING ERRCODE = '45000'; END IF;
    IF p_sens_rows_json IS NULL OR jsonb_typeof(p_sens_rows_json) <> 'array' THEN RAISE EXCEPTION '감도 점검 행 자료가 올바르지 않습니다.' USING ERRCODE = '45000'; END IF;
    SELECT COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm), COALESCE(ct.appr_line_cd, 'DEFAULT'), COALESCE(ct.retention_month, t.default_retention_month)
      INTO v_name, v_appr, v_retain FROM tbl_template t LEFT JOIN tbl_company_template ct ON ct.co_cd=p_co_cd AND ct.tmpl_cd=t.tmpl_cd AND ct.use_yn='Y'
     WHERE t.tmpl_cd='CCP_METAL' AND t.use_yn='Y';
    IF v_name IS NULL THEN RAISE EXCEPTION 'CCP 금속검출 양식이 등록되어 있지 않습니다.' USING ERRCODE = '45000'; END IF;
    IF p_doc_idx IS NULL OR p_doc_idx = 0 THEN
        INSERT INTO tbl_document(co_cd,tmpl_cd,doc_kind,doc_no,base_dt,title,status,appr_line_cd,writer_id,write_dt,ver_no,retention_until,del_yn,ins_id)
        VALUES(p_co_cd,'CCP_METAL','DB',sp_tbl_doc_no_gen_c_000(p_co_cd,'CCP_METAL',p_base_dt),p_base_dt,v_name || ' (' || p_base_dt || ')','WRK',v_appr,p_id,now(),1,to_char((to_date(p_base_dt,'YYYYMMDD')+(COALESCE(v_retain,24)||' months')::interval)::date,'YYYYMMDD'),'N',p_id) RETURNING idx INTO v_doc_idx;
        INSERT INTO tbl_ccp_metal_monitor(co_cd,doc_idx,base_dt,ccp_cd,fe_size,sts_size,mng_user_id,mng_nm,ins_id) VALUES(p_co_cd,v_doc_idx,p_base_dt,p_ccp_cd,p_fe_size,p_sts_size,NULLIF(p_mng_user_id,''),NULLIF(p_mng_nm,''),p_id) RETURNING idx INTO v_hdr_idx;
    ELSE
        SELECT d.idx,d.status,h.idx INTO v_doc_idx,v_status,v_hdr_idx FROM tbl_document d JOIN tbl_ccp_metal_monitor h ON h.doc_idx=d.idx AND h.co_cd=d.co_cd WHERE d.co_cd=p_co_cd AND d.idx=p_doc_idx AND d.tmpl_cd='CCP_METAL' AND d.del_yn='N';
        IF v_doc_idx IS NULL THEN RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE='45000'; END IF;
        IF v_status IN ('REQ','REV','APV') THEN RAISE EXCEPTION '결재 진행 중이거나 완료된 문서는 수정할 수 없습니다.' USING ERRCODE='45000'; END IF;
        UPDATE tbl_document SET base_dt=p_base_dt,title=v_name || ' (' || p_base_dt || ')',upd_id=p_id,upd_dt=now() WHERE idx=v_doc_idx AND co_cd=p_co_cd;
        UPDATE tbl_ccp_metal_monitor SET base_dt=p_base_dt,ccp_cd=p_ccp_cd,fe_size=p_fe_size,sts_size=p_sts_size,mng_user_id=NULLIF(p_mng_user_id,''),mng_nm=NULLIF(p_mng_nm,''),upd_id=p_id,upd_dt=now() WHERE idx=v_hdr_idx AND co_cd=p_co_cd;
        DELETE FROM tbl_ccp_metal_sens_row WHERE co_cd=p_co_cd AND hdr_idx=v_hdr_idx;
        DELETE FROM tbl_ccp_metal_pass_row WHERE co_cd=p_co_cd AND hdr_idx=v_hdr_idx;
    END IF;
    FOR r IN SELECT * FROM jsonb_array_elements(p_sens_rows_json) LOOP
        IF COALESCE((r->>'rowSeq')::int,0) <= 0 THEN RAISE EXCEPTION '감도 점검 행 순번이 올바르지 않습니다.' USING ERRCODE='45000'; END IF;
        v_judge := CASE WHEN r->>'feOnlyCd'='O' AND r->>'stsOnlyCd'='O' AND r->>'prodOnlyCd'='X' AND r->>'feProdCd'='O' AND r->>'stsProdCd'='O' THEN 'P' ELSE 'F' END;
        INSERT INTO tbl_ccp_metal_sens_row(co_cd,hdr_idx,row_seq,phase_cd,product_cd,product_nm,place_nm,check_time,fe_only_cd,sts_only_cd,prod_only_cd,fe_prod_cd,sts_prod_cd,judge_cd,judge_mod_yn,checker_id,checker_nm,ins_id)
        VALUES(p_co_cd,v_hdr_idx,(r->>'rowSeq')::int,COALESCE(NULLIF(r->>'phaseCd',''),'DURING'),NULLIF(r->>'productCd',''),NULLIF(r->>'productNm',''),NULLIF(r->>'placeNm',''),NULLIF(r->>'checkTime',''),NULLIF(r->>'feOnlyCd',''),NULLIF(r->>'stsOnlyCd',''),NULLIF(r->>'prodOnlyCd',''),NULLIF(r->>'feProdCd',''),NULLIF(r->>'stsProdCd',''),CASE WHEN r->>'judgeModYn'='Y' AND NULLIF(r->>'judgeCd','') IS NOT NULL THEN r->>'judgeCd' ELSE v_judge END,COALESCE(NULLIF(r->>'judgeModYn',''),'N'),NULLIF(r->>'checkerId',''),NULLIF(r->>'checkerNm',''),p_id);
    END LOOP;
    FOR r IN SELECT * FROM jsonb_array_elements(COALESCE(p_pass_rows_json,'[]'::jsonb)) LOOP
        INSERT INTO tbl_ccp_metal_pass_row(co_cd,hdr_idx,row_seq,product_cd,product_nm,pass_qty,detect_qty,unit_nm,remark,ins_id)
        VALUES(p_co_cd,v_hdr_idx,COALESCE((r->>'rowSeq')::int,0),NULLIF(r->>'productCd',''),NULLIF(r->>'productNm',''),NULLIF(r->>'passQty','')::numeric,NULLIF(r->>'detectQty','')::numeric,NULLIF(r->>'unitNm',''),NULLIF(r->>'remark',''),p_id);
    END LOOP;
    RETURN v_doc_idx;
END$$;

-- ------------------------------------------------------------
-- 공통 CCP — equip_nm · product_nm
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_ccp_generic_monitor_r_000(
    p_co_cd varchar,
    p_doc_idx bigint
)
RETURNS TABLE (
    doc_idx bigint,
    doc_no varchar,
    status varchar,
    base_dt varchar,
    tmpl_cd varchar,
    ccp_cd varchar,
    diary_no varchar,
    limit_item_kind varchar,
    mng_user_id varchar,
    mng_nm varchar,
    rows_json jsonb
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT d.idx AS doc_idx,
           d.doc_no,
           d.status,
           m.base_dt,
           m.tmpl_cd,
           m.ccp_cd,
           m.diary_no,
           m.limit_item_kind,
           m.mng_user_id,
           m.mng_nm,
           COALESCE((
               SELECT jsonb_agg(
                          jsonb_build_object(
                              'rowSeq', r.row_seq,
                              'checkTime', COALESCE(r.check_time, ''),
                              'equipNm', COALESCE(r.equip_nm, ''),
                              'productNm', COALESCE(r.product_nm, ''),
                              'judgeCd', r.judge_cd,
                              'judgeModYn', r.judge_mod_yn,
                              'checkerId', COALESCE(r.checker_id, ''),
                              'checkerNm', COALESCE(r.checker_nm, ''),
                              'signPath', COALESCE(r.sign_path, ''),
                              'cells', COALESCE((
                                  SELECT jsonb_agg(
                                             jsonb_build_object(
                                                 'itemCd', c.item_cd,
                                                 'numVal', c.num_val,
                                                 'txtVal', COALESCE(c.txt_val, ''),
                                                 'judgeCd', c.judge_cd
                                             )
                                             ORDER BY c.item_cd
                                         )
                                    FROM tbl_ccp_generic_monitor_cell c
                                   WHERE c.row_idx = r.idx
                                     AND c.co_cd = r.co_cd
                              ), '[]'::jsonb)
                          )
                          ORDER BY r.row_seq
                      )
                 FROM tbl_ccp_generic_monitor_row r
                WHERE r.monitor_idx = m.idx
                  AND r.co_cd = m.co_cd
           ), '[]'::jsonb) AS rows_json
      FROM tbl_document d
      JOIN tbl_ccp_generic_monitor m
        ON m.doc_idx = d.idx
       AND m.co_cd = d.co_cd
     WHERE d.co_cd = p_co_cd
       AND d.idx = p_doc_idx
       AND d.del_yn = 'N';
END;
$$;

CREATE OR REPLACE FUNCTION sp_tbl_ccp_generic_monitor_c_000(
    p_co_cd varchar,
    p_doc_idx bigint,
    p_base_dt varchar,
    p_tmpl_cd varchar,
    p_ccp_cd varchar,
    p_diary_no varchar,
    p_limit_item_kind varchar,
    p_mng_user_id varchar,
    p_mng_nm varchar,
    p_rows jsonb,
    p_id varchar
) RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE
    v_doc_idx bigint;
    v_monitor_idx bigint;
    v_doc_no varchar;
    v_title varchar(300);
    v_row jsonb;
    v_cell jsonb;
    v_row_idx bigint;
BEGIN
    IF jsonb_typeof(p_rows) <> 'array' OR jsonb_array_length(p_rows) = 0 THEN
        RAISE EXCEPTION '점검 행이 없습니다.' USING ERRCODE = '45000';
    END IF;
    SELECT coalesce(nullif(t.tmpl_nm, ''), '공통 CCP 모니터링') INTO v_title
      FROM tbl_template t WHERE t.tmpl_cd = p_tmpl_cd AND t.doc_kind = 'DB' AND t.use_yn = 'Y';
    IF v_title IS NULL THEN
        RAISE EXCEPTION '사용할 공통 CCP 양식이 등록되어 있지 않습니다.' USING ERRCODE = '45000';
    END IF;

    IF coalesce(p_doc_idx, 0) <= 0 THEN
        v_doc_no := sp_tbl_doc_no_gen_c_000(p_co_cd, p_tmpl_cd, p_base_dt);
        INSERT INTO tbl_document (
            co_cd, tmpl_cd, doc_kind, doc_no, base_dt, title, status, writer_id, form_src, ins_id
        ) VALUES (
            p_co_cd, p_tmpl_cd, 'DB', v_doc_no, p_base_dt, v_title, 'WRK', p_id, 'BASE', p_id
        ) RETURNING idx INTO v_doc_idx;
        INSERT INTO tbl_ccp_generic_monitor (
            co_cd, doc_idx, base_dt, tmpl_cd, ccp_cd, diary_no, limit_item_kind, mng_user_id, mng_nm, ins_id
        ) VALUES (
            p_co_cd, v_doc_idx, p_base_dt, p_tmpl_cd, nullif(p_ccp_cd, ''), nullif(p_diary_no, ''),
            nullif(p_limit_item_kind, ''), nullif(p_mng_user_id, ''), nullif(p_mng_nm, ''), p_id
        ) RETURNING idx INTO v_monitor_idx;
    ELSE
        SELECT m.idx INTO v_monitor_idx
          FROM tbl_ccp_generic_monitor m
          JOIN tbl_document d ON d.idx = m.doc_idx
         WHERE m.co_cd = p_co_cd AND m.doc_idx = p_doc_idx AND d.del_yn = 'N' AND d.status IN ('WRK', 'RJT');
        IF v_monitor_idx IS NULL THEN
            RAISE EXCEPTION '수정할 임시 또는 반려 문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        v_doc_idx := p_doc_idx;
        UPDATE tbl_document SET base_dt = p_base_dt, title = v_title, upd_id = p_id, upd_dt = now()
         WHERE idx = v_doc_idx AND co_cd = p_co_cd;
        UPDATE tbl_ccp_generic_monitor
           SET base_dt = p_base_dt, tmpl_cd = p_tmpl_cd, ccp_cd = nullif(p_ccp_cd, ''),
               diary_no = nullif(p_diary_no, ''), limit_item_kind = nullif(p_limit_item_kind, ''),
               mng_user_id = nullif(p_mng_user_id, ''), mng_nm = nullif(p_mng_nm, ''), upd_id = p_id, upd_dt = now()
         WHERE idx = v_monitor_idx AND co_cd = p_co_cd;
        DELETE FROM tbl_ccp_generic_monitor_cell c
         USING tbl_ccp_generic_monitor_row r
         WHERE c.row_idx = r.idx AND r.monitor_idx = v_monitor_idx AND r.co_cd = p_co_cd;
        DELETE FROM tbl_ccp_generic_monitor_row WHERE monitor_idx = v_monitor_idx AND co_cd = p_co_cd;
    END IF;

    FOR v_row IN SELECT value FROM jsonb_array_elements(p_rows)
    LOOP
        INSERT INTO tbl_ccp_generic_monitor_row (
            co_cd, monitor_idx, row_seq, check_time, equip_nm, product_nm,
            judge_cd, judge_mod_yn, checker_id, checker_nm, sign_path, ins_id
        ) VALUES (
            p_co_cd, v_monitor_idx, coalesce(nullif(v_row->>'rowSeq', '')::int, 0), nullif(v_row->>'checkTime', ''),
            nullif(v_row->>'equipNm', ''), nullif(v_row->>'productNm', ''),
            nullif(v_row->>'judgeCd', ''), coalesce(nullif(v_row->>'judgeModYn', ''), 'N'),
            nullif(v_row->>'checkerId', ''), nullif(v_row->>'checkerNm', ''),
            nullif(v_row->>'signPath', ''), p_id
        ) RETURNING idx INTO v_row_idx;
        FOR v_cell IN SELECT value FROM jsonb_array_elements(coalesce(v_row->'cells', '[]'::jsonb))
        LOOP
            INSERT INTO tbl_ccp_generic_monitor_cell (
                co_cd, row_idx, item_cd, num_val, txt_val, judge_cd, ins_id
            ) VALUES (
                p_co_cd, v_row_idx, v_cell->>'itemCd', nullif(v_cell->>'numVal', '')::numeric,
                nullif(v_cell->>'txtVal', ''), nullif(v_cell->>'judgeCd', ''), p_id
            );
        END LOOP;
    END LOOP;
    RETURN v_doc_idx;
END;
$$;
