-- ============================================================
--  SP 6 — HACCP 기준정보 마스터
--
--  개발자: 박승우
--  일자: 2026-08-06
--  코멘트:
--    1) 제품·원부재료 등 9개 기준정보와 CCP 한계기준을 허용 목록으로만 관리한다
--    2) 모든 CUD는 회사코드 조건을 포함해 다른 테넌트의 idx를 갱신·삭제하지 않는다
--    3) 삭제는 참조 검사와 삭제 SP 양쪽에서 다시 확인해 화면 검증 뒤의 경합도 차단한다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. sp_tbl_master_r_000 — 기준정보 목록
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_master_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_master_type: 허용 기준정보 종류
    p_master_type varchar,
    -- p_use_yn: 사용여부 필터. 공백이면 전체
    p_use_yn varchar
)
RETURNS SETOF jsonb
LANGUAGE plpgsql STABLE AS $$
BEGIN
    CASE p_master_type
        WHEN 'product' THEN RETURN QUERY SELECT to_jsonb(t) FROM tbl_product t WHERE t.co_cd = p_co_cd AND (COALESCE(p_use_yn, '') = '' OR t.use_yn = p_use_yn) ORDER BY t.product_cd;
        WHEN 'material' THEN RETURN QUERY SELECT to_jsonb(t) FROM tbl_material t WHERE t.co_cd = p_co_cd AND (COALESCE(p_use_yn, '') = '' OR t.use_yn = p_use_yn) ORDER BY t.material_cd;
        WHEN 'partner' THEN RETURN QUERY SELECT to_jsonb(t) FROM tbl_partner t WHERE t.co_cd = p_co_cd AND (COALESCE(p_use_yn, '') = '' OR t.use_yn = p_use_yn) ORDER BY t.partner_cd;
        WHEN 'storage' THEN RETURN QUERY SELECT to_jsonb(t) FROM tbl_storage t WHERE t.co_cd = p_co_cd AND (COALESCE(p_use_yn, '') = '' OR t.use_yn = p_use_yn) ORDER BY t.sort_no, t.storage_cd;
        WHEN 'equipment' THEN RETURN QUERY SELECT to_jsonb(t) FROM tbl_equipment t WHERE t.co_cd = p_co_cd AND (COALESCE(p_use_yn, '') = '' OR t.use_yn = p_use_yn) ORDER BY t.equip_cd;
        WHEN 'measuring-device' THEN RETURN QUERY SELECT to_jsonb(t) FROM tbl_measuring_device t WHERE t.co_cd = p_co_cd AND (COALESCE(p_use_yn, '') = '' OR t.use_yn = p_use_yn) ORDER BY t.sort_no, t.device_cd;
        WHEN 'pest-device' THEN RETURN QUERY SELECT to_jsonb(t) FROM tbl_pest_device t WHERE t.co_cd = p_co_cd AND (COALESCE(p_use_yn, '') = '' OR t.use_yn = p_use_yn) ORDER BY t.sort_no, t.pest_cd;
        WHEN 'vehicle' THEN RETURN QUERY SELECT to_jsonb(t) FROM tbl_vehicle t WHERE t.co_cd = p_co_cd AND (COALESCE(p_use_yn, '') = '' OR t.use_yn = p_use_yn) ORDER BY t.vehicle_cd;
        WHEN 'work-area' THEN RETURN QUERY SELECT to_jsonb(t) FROM tbl_work_area t WHERE t.co_cd = p_co_cd AND (COALESCE(p_use_yn, '') = '' OR t.use_yn = p_use_yn) ORDER BY t.sort_no, t.area_cd;
        WHEN 'ccp-limit' THEN RETURN QUERY SELECT to_jsonb(t) FROM tbl_ccp_limit t WHERE t.co_cd = p_co_cd AND (COALESCE(p_use_yn, '') = '' OR t.use_yn = p_use_yn) ORDER BY t.ccp_cd;
        ELSE RAISE EXCEPTION '지원하지 않는 기준정보입니다.' USING ERRCODE = '45000';
    END CASE;
END$$;
COMMENT ON FUNCTION sp_tbl_master_r_000(varchar, varchar, varchar) IS '기준정보 목록 — 허용된 마스터만 JSON 행으로 조회';

-- ------------------------------------------------------------
-- 2. sp_tbl_master_c_000 — 기준정보 저장
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_master_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_master_type: 허용 기준정보 종류
    p_master_type varchar,
    -- p_payload: camelCase JSON 행. idx가 없으면 신규, 있으면 같은 회사 행 수정
    p_payload jsonb,
    -- p_id: JWT 작업자 ID
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
            IF v_idx IS NULL THEN INSERT INTO tbl_partner(co_cd,partner_cd,partner_nm,partner_gbn,biz_no,ceo_nm,tel_no,fax_no,mng_nm,mobile,email,zip_no,addr_h,addr_d,haccp_yn,use_yn,ins_id) VALUES(p_co_cd,p_payload->>'partnerCd',p_payload->>'partnerNm',p_payload->>'partnerGbn',NULLIF(p_payload->>'bizNo',''),NULLIF(p_payload->>'ceoNm',''),NULLIF(p_payload->>'telNo',''),NULLIF(p_payload->>'faxNo',''),NULLIF(p_payload->>'mngNm',''),NULLIF(p_payload->>'mobile',''),NULLIF(p_payload->>'email',''),NULLIF(p_payload->>'zipNo',''),NULLIF(p_payload->>'addrH',''),NULLIF(p_payload->>'addrD',''),COALESCE(NULLIF(p_payload->>'haccpYn',''),'N'),COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),p_id);
            ELSE UPDATE tbl_partner SET partner_cd=p_payload->>'partnerCd',partner_nm=p_payload->>'partnerNm',partner_gbn=p_payload->>'partnerGbn',biz_no=NULLIF(p_payload->>'bizNo',''),ceo_nm=NULLIF(p_payload->>'ceoNm',''),tel_no=NULLIF(p_payload->>'telNo',''),fax_no=NULLIF(p_payload->>'faxNo',''),mng_nm=NULLIF(p_payload->>'mngNm',''),mobile=NULLIF(p_payload->>'mobile',''),email=NULLIF(p_payload->>'email',''),zip_no=NULLIF(p_payload->>'zipNo',''),addr_h=NULLIF(p_payload->>'addrH',''),addr_d=NULLIF(p_payload->>'addrD',''),haccp_yn=COALESCE(NULLIF(p_payload->>'haccpYn',''),'N'),use_yn=COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),upd_id=p_id,upd_dt=now() WHERE idx=v_idx AND co_cd=p_co_cd; END IF;
        WHEN 'storage' THEN
            IF COALESCE(p_payload->>'storageCd', '') = '' OR COALESCE(p_payload->>'storageNm', '') = '' OR COALESCE(p_payload->>'storageType', '') = '' THEN RAISE EXCEPTION '보관고 코드·명칭·유형은 필수입니다.' USING ERRCODE = '45000'; END IF;
            IF v_idx IS NULL THEN INSERT INTO tbl_storage(co_cd,storage_cd,storage_nm,storage_type,ccp_cd,temp_min,temp_max,sensor_yn,place_nm,sort_no,use_yn,ins_id) VALUES(p_co_cd,p_payload->>'storageCd',p_payload->>'storageNm',p_payload->>'storageType',NULLIF(p_payload->>'ccpCd',''),NULLIF(p_payload->>'tempMin','')::numeric,NULLIF(p_payload->>'tempMax','')::numeric,COALESCE(NULLIF(p_payload->>'sensorYn',''),'N'),NULLIF(p_payload->>'placeNm',''),COALESCE(NULLIF(p_payload->>'sortNo','')::int,0),COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),p_id);
            ELSE UPDATE tbl_storage SET storage_cd=p_payload->>'storageCd',storage_nm=p_payload->>'storageNm',storage_type=p_payload->>'storageType',ccp_cd=NULLIF(p_payload->>'ccpCd',''),temp_min=NULLIF(p_payload->>'tempMin','')::numeric,temp_max=NULLIF(p_payload->>'tempMax','')::numeric,sensor_yn=COALESCE(NULLIF(p_payload->>'sensorYn',''),'N'),place_nm=NULLIF(p_payload->>'placeNm',''),sort_no=COALESCE(NULLIF(p_payload->>'sortNo','')::int,0),use_yn=COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),upd_id=p_id,upd_dt=now() WHERE idx=v_idx AND co_cd=p_co_cd; END IF;
        WHEN 'equipment' THEN
            IF COALESCE(p_payload->>'equipCd', '') = '' OR COALESCE(p_payload->>'equipNm', '') = '' THEN RAISE EXCEPTION '설비 코드와 설비명은 필수입니다.' USING ERRCODE = '45000'; END IF;
            IF v_idx IS NULL THEN INSERT INTO tbl_equipment(co_cd,equip_cd,equip_nm,model_nm,spec_nm,maker_nm,made_country,buy_dt,use_range,place_nm,photo_path,use_method,use_yn,ins_id) VALUES(p_co_cd,p_payload->>'equipCd',p_payload->>'equipNm',NULLIF(p_payload->>'modelNm',''),NULLIF(p_payload->>'specNm',''),NULLIF(p_payload->>'makerNm',''),NULLIF(p_payload->>'madeCountry',''),NULLIF(p_payload->>'buyDt',''),NULLIF(p_payload->>'useRange',''),NULLIF(p_payload->>'placeNm',''),NULLIF(p_payload->>'photoPath',''),NULLIF(p_payload->>'useMethod',''),COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),p_id);
            ELSE UPDATE tbl_equipment SET equip_cd=p_payload->>'equipCd',equip_nm=p_payload->>'equipNm',model_nm=NULLIF(p_payload->>'modelNm',''),spec_nm=NULLIF(p_payload->>'specNm',''),maker_nm=NULLIF(p_payload->>'makerNm',''),made_country=NULLIF(p_payload->>'madeCountry',''),buy_dt=NULLIF(p_payload->>'buyDt',''),use_range=NULLIF(p_payload->>'useRange',''),place_nm=NULLIF(p_payload->>'placeNm',''),photo_path=NULLIF(p_payload->>'photoPath',''),use_method=NULLIF(p_payload->>'useMethod',''),use_yn=COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),upd_id=p_id,upd_dt=now() WHERE idx=v_idx AND co_cd=p_co_cd; END IF;
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
            IF v_idx IS NULL THEN INSERT INTO tbl_ccp_limit(co_cd,ccp_cd,ccp_nm,proc_nm,limit_type,min_val,max_val,unit_nm,fe_size,sts_size,cycle_min,form_title,cycle_rmk,limit_rmk,method_rmk,use_yn,ins_id) VALUES(p_co_cd,p_payload->>'ccpCd',p_payload->>'ccpNm',NULLIF(p_payload->>'procNm',''),p_payload->>'limitType',NULLIF(p_payload->>'minVal','')::numeric,NULLIF(p_payload->>'maxVal','')::numeric,NULLIF(p_payload->>'unitNm',''),NULLIF(p_payload->>'feSize','')::numeric,NULLIF(p_payload->>'stsSize','')::numeric,NULLIF(p_payload->>'cycleMin','')::int,NULLIF(p_payload->>'formTitle',''),NULLIF(p_payload->>'cycleRmk',''),NULLIF(p_payload->>'limitRmk',''),NULLIF(p_payload->>'methodRmk',''),COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),p_id);
            ELSE UPDATE tbl_ccp_limit SET ccp_cd=p_payload->>'ccpCd',ccp_nm=p_payload->>'ccpNm',proc_nm=NULLIF(p_payload->>'procNm',''),limit_type=p_payload->>'limitType',min_val=NULLIF(p_payload->>'minVal','')::numeric,max_val=NULLIF(p_payload->>'maxVal','')::numeric,unit_nm=NULLIF(p_payload->>'unitNm',''),fe_size=NULLIF(p_payload->>'feSize','')::numeric,sts_size=NULLIF(p_payload->>'stsSize','')::numeric,cycle_min=NULLIF(p_payload->>'cycleMin','')::int,form_title=NULLIF(p_payload->>'formTitle',''),cycle_rmk=NULLIF(p_payload->>'cycleRmk',''),limit_rmk=NULLIF(p_payload->>'limitRmk',''),method_rmk=NULLIF(p_payload->>'methodRmk',''),use_yn=COALESCE(NULLIF(p_payload->>'useYn',''),'Y'),upd_id=p_id,upd_dt=now() WHERE idx=v_idx AND co_cd=p_co_cd; END IF;
        ELSE RAISE EXCEPTION '지원하지 않는 기준정보입니다.' USING ERRCODE = '45000';
    END CASE;
    IF v_idx IS NOT NULL AND NOT FOUND THEN RAISE EXCEPTION '수정할 기준정보를 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
END$$;
COMMENT ON PROCEDURE sp_tbl_master_c_000(varchar, varchar, jsonb, varchar) IS '기준정보 저장 — 신규·수정, JWT 회사코드와 작업자만 사용';

-- ------------------------------------------------------------
-- 3. sp_tbl_master_delete_blocker_r_000 — 삭제 참조 검사
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_master_delete_blocker_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_master_type: 검사할 기준정보 종류
    p_master_type varchar,
    -- p_idxs: 삭제 대상 idx 배열
    p_idxs bigint[]
)
RETURNS TABLE(ref_key varchar, target varchar)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    CASE p_master_type
        WHEN 'product' THEN RETURN QUERY SELECT p.product_cd, 'CCP 금속검출 기록' FROM tbl_product p JOIN tbl_ccp_metal_sens_row r ON r.co_cd=p.co_cd AND r.product_cd=p.product_cd WHERE p.co_cd=p_co_cd AND p.idx=ANY(p_idxs) UNION ALL SELECT p.product_cd, '재고 거래' FROM tbl_product p JOIN tbl_inv_txn r ON r.co_cd=p.co_cd AND r.product_cd=p.product_cd WHERE p.co_cd=p_co_cd AND p.idx=ANY(p_idxs);
        WHEN 'material' THEN RETURN QUERY SELECT m.material_cd, '재고 거래' FROM tbl_material m JOIN tbl_inv_txn r ON r.co_cd=m.co_cd AND r.material_cd=m.material_cd WHERE m.co_cd=p_co_cd AND m.idx=ANY(p_idxs) UNION ALL SELECT m.material_cd, '입고검사 기록' FROM tbl_material m JOIN tbl_recv_inspect r ON r.co_cd=m.co_cd AND r.material_cd=m.material_cd WHERE m.co_cd=p_co_cd AND m.idx=ANY(p_idxs);
        WHEN 'partner' THEN RETURN QUERY SELECT p.partner_cd, '원부재료 공급처' FROM tbl_partner p JOIN tbl_material m ON m.co_cd=p.co_cd AND m.partner_cd=p.partner_cd WHERE p.co_cd=p_co_cd AND p.idx=ANY(p_idxs) UNION ALL SELECT p.partner_cd, '입고검사 기록' FROM tbl_partner p JOIN tbl_recv_inspect r ON r.co_cd=p.co_cd AND r.partner_cd=p.partner_cd WHERE p.co_cd=p_co_cd AND p.idx=ANY(p_idxs);
        WHEN 'storage' THEN RETURN QUERY SELECT s.storage_cd, 'CCP 냉장보관 기록' FROM tbl_storage s JOIN tbl_ccp_cold_monitor_temp t ON t.co_cd=s.co_cd AND t.storage_cd=s.storage_cd WHERE s.co_cd=p_co_cd AND s.idx=ANY(p_idxs) UNION ALL SELECT s.storage_cd, '재고 거래' FROM tbl_storage s JOIN tbl_inv_txn r ON r.co_cd=s.co_cd AND r.storage_cd=s.storage_cd WHERE s.co_cd=p_co_cd AND s.idx=ANY(p_idxs);
        WHEN 'measuring-device' THEN RETURN QUERY SELECT d.device_cd, '검·교정 기록' FROM tbl_measuring_device d JOIN tbl_calib_target_row r ON r.co_cd=d.co_cd AND r.device_cd=d.device_cd WHERE d.co_cd=p_co_cd AND d.idx=ANY(p_idxs);
        WHEN 'pest-device' THEN RETURN QUERY SELECT d.pest_cd, '방충방서 점검 기록' FROM tbl_pest_device d JOIN tbl_pest_check_row r ON r.co_cd=d.co_cd AND r.pest_cd=d.pest_cd WHERE d.co_cd=p_co_cd AND d.idx=ANY(p_idxs);
        WHEN 'vehicle' THEN RETURN QUERY SELECT v.vehicle_cd, '입고검사 기록' FROM tbl_vehicle v JOIN tbl_recv_inspect r ON r.co_cd=v.co_cd AND r.vehicle_cd=v.vehicle_cd WHERE v.co_cd=p_co_cd AND v.idx=ANY(p_idxs);
        WHEN 'work-area' THEN RETURN QUERY SELECT a.area_cd, '작업장 위생 기록' FROM tbl_work_area a JOIN tbl_area_hygiene r ON r.co_cd=a.co_cd AND r.area_cd=a.area_cd WHERE a.co_cd=p_co_cd AND a.idx=ANY(p_idxs);
        WHEN 'ccp-limit' THEN RETURN QUERY SELECT l.ccp_cd, '보관고 한계기준' FROM tbl_ccp_limit l JOIN tbl_storage s ON s.co_cd=l.co_cd AND s.ccp_cd=l.ccp_cd WHERE l.co_cd=p_co_cd AND l.idx=ANY(p_idxs);
        WHEN 'equipment' THEN RETURN;
        ELSE RAISE EXCEPTION '지원하지 않는 기준정보입니다.' USING ERRCODE = '45000';
    END CASE;
END$$;
COMMENT ON FUNCTION sp_tbl_master_delete_blocker_r_000(varchar, varchar, bigint[]) IS '기준정보 삭제 참조 검사 — 대상 idx 배열 중 첫 참조 행을 API가 선택';

-- ------------------------------------------------------------
-- 4. sp_tbl_master_d_000 — 기준정보 삭제
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_master_d_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_master_type: 삭제할 기준정보 종류
    p_master_type varchar,
    -- p_idx: 삭제 대상 대리키
    p_idx bigint,
    -- p_id: JWT 작업자 ID. 감사 확장용으로 받는다
    p_id varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    IF p_idx IS NULL OR p_idx <= 0 THEN RAISE EXCEPTION '삭제할 기준정보를 선택하세요.' USING ERRCODE = '45000'; END IF;
    IF EXISTS (SELECT 1 FROM sp_tbl_master_delete_blocker_r_000(p_co_cd, p_master_type, ARRAY[p_idx])) THEN RAISE EXCEPTION '참조 중인 기준정보는 삭제할 수 없습니다.' USING ERRCODE = '45000'; END IF;
    CASE p_master_type
        WHEN 'product' THEN DELETE FROM tbl_product WHERE idx=p_idx AND co_cd=p_co_cd;
        WHEN 'material' THEN DELETE FROM tbl_material WHERE idx=p_idx AND co_cd=p_co_cd;
        WHEN 'partner' THEN DELETE FROM tbl_partner WHERE idx=p_idx AND co_cd=p_co_cd;
        WHEN 'storage' THEN DELETE FROM tbl_storage WHERE idx=p_idx AND co_cd=p_co_cd;
        WHEN 'equipment' THEN DELETE FROM tbl_equipment WHERE idx=p_idx AND co_cd=p_co_cd;
        WHEN 'measuring-device' THEN DELETE FROM tbl_measuring_device WHERE idx=p_idx AND co_cd=p_co_cd;
        WHEN 'pest-device' THEN DELETE FROM tbl_pest_device WHERE idx=p_idx AND co_cd=p_co_cd;
        WHEN 'vehicle' THEN DELETE FROM tbl_vehicle WHERE idx=p_idx AND co_cd=p_co_cd;
        WHEN 'work-area' THEN DELETE FROM tbl_work_area WHERE idx=p_idx AND co_cd=p_co_cd;
        WHEN 'ccp-limit' THEN DELETE FROM tbl_ccp_limit WHERE idx=p_idx AND co_cd=p_co_cd;
        ELSE RAISE EXCEPTION '지원하지 않는 기준정보입니다.' USING ERRCODE = '45000';
    END CASE;
    IF NOT FOUND THEN RAISE EXCEPTION '삭제할 기준정보를 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
END$$;
COMMENT ON PROCEDURE sp_tbl_master_d_000(varchar, varchar, bigint, varchar) IS '기준정보 삭제 — 참조 재검사 후 회사 범위 물리 삭제';
