-- ============================================================
--  DDL 4 — 기준정보 (9 테이블)
--
--  개발자: 박승우
--  일자: 2026-08-05
--  코멘트:
--    1) 점검표 화면이 행을 자동 생성하는 원천 — 냉장고 3대·포충등 4대·바퀴트랩 8대 같은
--       업체별 차이를 화면 수정 없이 마스터 행 수로 표현한다
--    2) MES 기준정보(BOM·단가·라인·공정·재고 로케이션)는 이식하지 않는다.
--       가격·수량 단가·거래조건 등 판매/구매 회계 컬럼도 전부 제외
--    3) 마스터 삭제는 점검 기록에서 참조 중이면 차단한다(SP 참조 COUNT + DeleteValidation)
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. tbl_product — 제품
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_product (
    idx            bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd          varchar(10)  NOT NULL,
    product_cd     varchar(30)  NOT NULL,
    product_nm     varchar(200) NOT NULL,
    spec_nm        varchar(100) NULL,
    unit_nm        varchar(20)  NULL,
    pkg_type       varchar(50)  NULL,
    storage_type   varchar(10)  NULL,
    shelf_life_day int          NULL,
    report_no      varchar(50)  NULL,
    haccp_yn       varchar(1)   NOT NULL DEFAULT 'Y',
    use_yn         varchar(1)   NOT NULL DEFAULT 'Y',
    ins_id         varchar(20)  NULL,
    ins_dt         timestamp    NULL DEFAULT now(),
    upd_id         varchar(20)  NULL,
    upd_dt         timestamp    NULL,
    CONSTRAINT ux_tbl_product UNIQUE (co_cd, product_cd)
);
COMMENT ON TABLE  tbl_product                IS '제품 — 금속검출·공정관리·제품검사·회수 문서에서 품명 선택 원천';
COMMENT ON COLUMN tbl_product.idx            IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_product.co_cd          IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_product.product_cd     IS '제품코드 — 업체 내 유일';
COMMENT ON COLUMN tbl_product.product_nm     IS '제품명';
COMMENT ON COLUMN tbl_product.spec_nm        IS '규격';
COMMENT ON COLUMN tbl_product.unit_nm        IS '단위 — kg, box 등';
COMMENT ON COLUMN tbl_product.pkg_type       IS '포장형태 — 진공포장, 랩포장 등';
COMMENT ON COLUMN tbl_product.storage_type   IS '보관유형 — COLD:냉장, FROZEN:냉동, ROOM:상온';
COMMENT ON COLUMN tbl_product.shelf_life_day IS '소비기한 일수 — 제조일 기준';
COMMENT ON COLUMN tbl_product.report_no      IS '품목제조보고번호';
COMMENT ON COLUMN tbl_product.haccp_yn       IS 'HACCP 적용 품목여부 Y/N';
COMMENT ON COLUMN tbl_product.use_yn         IS '사용여부 Y/N';
COMMENT ON COLUMN tbl_product.ins_id         IS '최초입력자 ID';
COMMENT ON COLUMN tbl_product.ins_dt         IS '최초입력일시';
COMMENT ON COLUMN tbl_product.upd_id         IS '최종수정자 ID';
COMMENT ON COLUMN tbl_product.upd_dt         IS '최종수정일시';

-- ------------------------------------------------------------
-- 2. tbl_material — 원·부재료
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_material (
    idx            bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd          varchar(10)  NOT NULL,
    material_cd    varchar(30)  NOT NULL,
    material_nm    varchar(200) NOT NULL,
    material_gbn   varchar(10)  NOT NULL,
    spec_nm        varchar(100) NULL,
    unit_nm        varchar(20)  NULL,
    storage_type   varchar(10)  NULL,
    partner_cd     varchar(30)  NULL,
    shelf_life_day int          NULL,
    haccp_yn       varchar(1)   NOT NULL DEFAULT 'N',
    insp_std       text         NULL,
    use_yn         varchar(1)   NOT NULL DEFAULT 'Y',
    ins_id         varchar(20)  NULL,
    ins_dt         timestamp    NULL DEFAULT now(),
    upd_id         varchar(20)  NULL,
    upd_dt         timestamp    NULL,
    CONSTRAINT ux_tbl_material UNIQUE (co_cd, material_cd)
);
COMMENT ON TABLE  tbl_material                IS '원·부재료 — 입고검사 일지, 입출고 재고 점검표의 품명 선택 원천';
COMMENT ON COLUMN tbl_material.idx            IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_material.co_cd          IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_material.material_cd    IS '원부재료 코드 — 업체 내 유일';
COMMENT ON COLUMN tbl_material.material_nm    IS '원부재료명';
COMMENT ON COLUMN tbl_material.material_gbn   IS '구분 — MEAT:원료육, SUB:부재료, PACK:포장재';
COMMENT ON COLUMN tbl_material.spec_nm        IS '규격';
COMMENT ON COLUMN tbl_material.unit_nm        IS '단위';
COMMENT ON COLUMN tbl_material.storage_type   IS '보관유형 — COLD:냉장, FROZEN:냉동, ROOM:상온';
COMMENT ON COLUMN tbl_material.partner_cd     IS '주 공급처 코드 — tbl_partner.partner_cd. 입고검사 반입처 기본값';
COMMENT ON COLUMN tbl_material.shelf_life_day IS '소비기한 일수';
COMMENT ON COLUMN tbl_material.haccp_yn       IS '공급처 HACCP 적용여부 Y/N — 입고검사 HACCP 적용확인란 기본값';
COMMENT ON COLUMN tbl_material.insp_std       IS '입고검사 기준 — 육안검사 기준 문구. 입고검사 화면 상단에 안내';
COMMENT ON COLUMN tbl_material.use_yn         IS '사용여부 Y/N';
COMMENT ON COLUMN tbl_material.ins_id         IS '최초입력자 ID';
COMMENT ON COLUMN tbl_material.ins_dt         IS '최초입력일시';
COMMENT ON COLUMN tbl_material.upd_id         IS '최종수정자 ID';
COMMENT ON COLUMN tbl_material.upd_dt         IS '최종수정일시';

-- ------------------------------------------------------------
-- 3. tbl_partner — 거래처
--    공급처·판매처·폐기물 수거업체·검사기관을 하나로 관리한다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_partner (
    idx         bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd       varchar(10)  NOT NULL,
    partner_cd  varchar(30)  NOT NULL,
    partner_nm  varchar(200) NOT NULL,
    partner_gbn varchar(10)  NOT NULL,
    biz_no      varchar(20)  NULL,
    ceo_nm      varchar(50)  NULL,
    tel_no      varchar(20)  NULL,
    fax_no      varchar(20)  NULL,
    mng_nm      varchar(50)  NULL,
    mobile      varchar(20)  NULL,
    email       varchar(100) NULL,
    zip_no      varchar(10)  NULL,
    addr_h      varchar(200) NULL,
    addr_d      varchar(200) NULL,
    haccp_yn    varchar(1)   NOT NULL DEFAULT 'N',
    use_yn      varchar(1)   NOT NULL DEFAULT 'Y',
    ins_id      varchar(20)  NULL,
    ins_dt      timestamp    NULL DEFAULT now(),
    upd_id      varchar(20)  NULL,
    upd_dt      timestamp    NULL,
    CONSTRAINT ux_tbl_partner UNIQUE (co_cd, partner_cd)
);
COMMENT ON TABLE  tbl_partner             IS '거래처 — 공급처·판매처·수거업체·검사기관 통합. 회수 시 거래처 연락망으로도 쓴다';
COMMENT ON COLUMN tbl_partner.idx         IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_partner.co_cd       IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_partner.partner_cd  IS '거래처 코드 — 업체 내 유일';
COMMENT ON COLUMN tbl_partner.partner_nm  IS '거래처명';
COMMENT ON COLUMN tbl_partner.partner_gbn IS '구분 — SUPPLY:공급처, SALES:판매처, tmpl_prp-waste-check:폐기물 수거업체, LAB:검사기관';
COMMENT ON COLUMN tbl_partner.biz_no      IS '사업자등록번호';
COMMENT ON COLUMN tbl_partner.ceo_nm      IS '대표자명';
COMMENT ON COLUMN tbl_partner.tel_no      IS '전화번호';
COMMENT ON COLUMN tbl_partner.fax_no      IS '팩스번호 — 회수 통보 시 사용';
COMMENT ON COLUMN tbl_partner.mng_nm      IS '담당자명';
COMMENT ON COLUMN tbl_partner.mobile      IS '담당자 휴대폰';
COMMENT ON COLUMN tbl_partner.email       IS '담당자 이메일';
COMMENT ON COLUMN tbl_partner.zip_no      IS '우편번호';
COMMENT ON COLUMN tbl_partner.addr_h      IS '주소';
COMMENT ON COLUMN tbl_partner.addr_d      IS '상세주소';
COMMENT ON COLUMN tbl_partner.haccp_yn    IS 'HACCP 인증업체 여부 Y/N';
COMMENT ON COLUMN tbl_partner.use_yn      IS '사용여부 Y/N';
COMMENT ON COLUMN tbl_partner.ins_id      IS '최초입력자 ID';
COMMENT ON COLUMN tbl_partner.ins_dt      IS '최초입력일시';
COMMENT ON COLUMN tbl_partner.upd_id      IS '최종수정자 ID';
COMMENT ON COLUMN tbl_partner.upd_dt      IS '최종수정일시';

-- ------------------------------------------------------------
-- 4. tbl_storage — 보관고 (냉장·냉동창고)
--    CCP 냉장보관 모니터링 일지의 보관고 열이 이 마스터 행 수만큼 생성된다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_storage (
    idx          bigint        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd        varchar(10)   NOT NULL,
    storage_cd   varchar(30)   NOT NULL,
    storage_nm   varchar(100)  NOT NULL,
    storage_type varchar(10)   NOT NULL,
    ccp_cd       varchar(20)   NULL,
    temp_min     numeric(5,1)  NULL,
    temp_max     numeric(5,1)  NULL,
    sensor_yn    varchar(1)    NOT NULL DEFAULT 'N',
    place_nm     varchar(100)  NULL,
    sort_no      int           NOT NULL DEFAULT 0,
    use_yn       varchar(1)    NOT NULL DEFAULT 'Y',
    ins_id       varchar(20)   NULL,
    ins_dt       timestamp     NULL DEFAULT now(),
    upd_id       varchar(20)   NULL,
    upd_dt       timestamp     NULL,
    CONSTRAINT ux_tbl_storage UNIQUE (co_cd, storage_cd)
);
COMMENT ON TABLE  tbl_storage              IS '보관고 — 냉장·냉동창고. CCP 냉장보관 일지의 보관고 열을 이 행 수만큼 동적 생성';
COMMENT ON COLUMN tbl_storage.idx          IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_storage.co_cd        IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_storage.storage_cd   IS '보관고 코드 — 업체 내 유일';
COMMENT ON COLUMN tbl_storage.storage_nm   IS '보관고명 — 냉장창고 1, 완제품 냉장고 등. A4 표 열 머리글에 출력';
COMMENT ON COLUMN tbl_storage.storage_type IS '유형 — COLD:냉장, FROZEN:냉동, ROOM:상온';
COMMENT ON COLUMN tbl_storage.ccp_cd       IS '연결 CCP 코드 — tbl_ccp_limit.ccp_cd. 자동판정 기준을 여기서 찾는다';
COMMENT ON COLUMN tbl_storage.temp_min     IS '개별 하한온도 — NULL이면(= 미지정) tbl_ccp_limit 값을 따른다';
COMMENT ON COLUMN tbl_storage.temp_max     IS '개별 상한온도 — NULL이면 tbl_ccp_limit 값을 따른다';
COMMENT ON COLUMN tbl_storage.sensor_yn    IS '자동온도기록장치 설치여부 Y/N — Y일 때(= 야간 자동기록) 근무외 시간 기록 면제';
COMMENT ON COLUMN tbl_storage.place_nm     IS '설치 위치';
COMMENT ON COLUMN tbl_storage.sort_no      IS '정렬순서 — A4 표의 열 순서';
COMMENT ON COLUMN tbl_storage.use_yn       IS '사용여부 Y/N';
COMMENT ON COLUMN tbl_storage.ins_id       IS '최초입력자 ID';
COMMENT ON COLUMN tbl_storage.ins_dt       IS '최초입력일시';
COMMENT ON COLUMN tbl_storage.upd_id       IS '최종수정자 ID';
COMMENT ON COLUMN tbl_storage.upd_dt       IS '최종수정일시';

-- ------------------------------------------------------------
-- 5. tbl_equipment — 시설·설비
--    시설·설비 이력카드(rhwp)의 기본정보를 자동 채우는 원천
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_equipment (
    idx          bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd        varchar(10)  NOT NULL,
    equip_cd     varchar(30)  NOT NULL,
    equip_nm     varchar(200) NOT NULL,
    model_nm     varchar(100) NULL,
    spec_nm      varchar(100) NULL,
    maker_nm     varchar(100) NULL,
    made_country varchar(50)  NULL,
    buy_dt       varchar(8)   NULL,
    use_range    varchar(200) NULL,
    place_nm     varchar(100) NULL,
    photo_path   varchar(300) NULL,
    use_method   text         NULL,
    use_yn       varchar(1)   NOT NULL DEFAULT 'Y',
    ins_id       varchar(20)  NULL,
    ins_dt       timestamp    NULL DEFAULT now(),
    upd_id       varchar(20)  NULL,
    upd_dt       timestamp    NULL,
    CONSTRAINT ux_tbl_equipment UNIQUE (co_cd, equip_cd)
);
COMMENT ON TABLE  tbl_equipment              IS '시설·설비 — 육절기·골절기·금속검출기 등. 이력카드 문서의 기본정보 자동채움 원천';
COMMENT ON COLUMN tbl_equipment.idx          IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_equipment.co_cd        IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_equipment.equip_cd     IS '설비번호 — 업체 내 유일. 이력카드 설비번호란에 출력';
COMMENT ON COLUMN tbl_equipment.equip_nm     IS '설비명';
COMMENT ON COLUMN tbl_equipment.model_nm     IS '모델명';
COMMENT ON COLUMN tbl_equipment.spec_nm      IS '규격';
COMMENT ON COLUMN tbl_equipment.maker_nm     IS '제조사';
COMMENT ON COLUMN tbl_equipment.made_country IS '제조국';
COMMENT ON COLUMN tbl_equipment.buy_dt       IS '구입일자 YYYYMMDD';
COMMENT ON COLUMN tbl_equipment.use_range    IS '사용범위';
COMMENT ON COLUMN tbl_equipment.place_nm     IS '설치 위치';
COMMENT ON COLUMN tbl_equipment.photo_path   IS '설비 사진 경로 — 이력카드 사진란';
COMMENT ON COLUMN tbl_equipment.use_method   IS '사용방법 — 이력카드 사용방법란';
COMMENT ON COLUMN tbl_equipment.use_yn       IS '사용여부 Y/N';
COMMENT ON COLUMN tbl_equipment.ins_id       IS '최초입력자 ID';
COMMENT ON COLUMN tbl_equipment.ins_dt       IS '최초입력일시';
COMMENT ON COLUMN tbl_equipment.upd_id       IS '최종수정자 ID';
COMMENT ON COLUMN tbl_equipment.upd_dt       IS '최종수정일시';

-- ------------------------------------------------------------
-- 6. tbl_measuring_device — 계측기
--    검·교정 대상 점검표와 자체 검·교정 일지의 대상 목록 원천
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_measuring_device (
    idx               bigint        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd             varchar(10)   NOT NULL,
    device_cd         varchar(30)   NOT NULL,
    device_nm         varchar(200)  NOT NULL,
    device_type       varchar(20)   NOT NULL,
    model_nm          varchar(100)  NULL,
    maker_nm          varchar(100)  NULL,
    spec_nm           varchar(100)  NULL,
    tolerance_val     numeric(10,3) NULL,
    tolerance_unit    varchar(20)   NULL,
    calib_cycle_month int           NOT NULL DEFAULT 12,
    place_nm          varchar(100)  NULL,
    sort_no           int           NOT NULL DEFAULT 0,
    use_yn            varchar(1)    NOT NULL DEFAULT 'Y',
    ins_id            varchar(20)   NULL,
    ins_dt            timestamp     NULL DEFAULT now(),
    upd_id            varchar(20)   NULL,
    upd_dt            timestamp     NULL,
    CONSTRAINT ux_tbl_measuring_device UNIQUE (co_cd, device_cd)
);
COMMENT ON TABLE  tbl_measuring_device                   IS '계측기 — 저울·온도계·타이머·조도계·표준기. 검·교정 대상 목록과 차기 예정일 알림의 원천';
COMMENT ON COLUMN tbl_measuring_device.idx               IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_measuring_device.co_cd             IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_measuring_device.device_cd         IS '계측기 코드 — 업체 내 유일';
COMMENT ON COLUMN tbl_measuring_device.device_nm         IS '계측기명 — 저울 1, 온도계(표준) 등';
COMMENT ON COLUMN tbl_measuring_device.device_type       IS '유형 — SCALE:저울, THERMO:온도계, TIMER:타이머, LUX:조도계, RECORDER:자동온도기록장치, STANDARD:표준기';
COMMENT ON COLUMN tbl_measuring_device.model_nm          IS '모델명';
COMMENT ON COLUMN tbl_measuring_device.maker_nm          IS '제조사';
COMMENT ON COLUMN tbl_measuring_device.spec_nm           IS '규격 — 측정 범위·최소눈금';
COMMENT ON COLUMN tbl_measuring_device.tolerance_val     IS '자체 검·교정 허용오차 — 저울 1(%), 온도계 1(도)';
COMMENT ON COLUMN tbl_measuring_device.tolerance_unit    IS '허용오차 단위 — PCT:퍼센트, DEG:섭씨도, SEC:초';
COMMENT ON COLUMN tbl_measuring_device.calib_cycle_month IS '검·교정 주기(개월) — 기본 12(연 1회). 차기 예정일 산출에 사용';
COMMENT ON COLUMN tbl_measuring_device.place_nm          IS '설치 위치';
COMMENT ON COLUMN tbl_measuring_device.sort_no           IS '정렬순서';
COMMENT ON COLUMN tbl_measuring_device.use_yn            IS '사용여부 Y/N';
COMMENT ON COLUMN tbl_measuring_device.ins_id            IS '최초입력자 ID';
COMMENT ON COLUMN tbl_measuring_device.ins_dt            IS '최초입력일시';
COMMENT ON COLUMN tbl_measuring_device.upd_id            IS '최종수정자 ID';
COMMENT ON COLUMN tbl_measuring_device.upd_dt            IS '최종수정일시';

-- ------------------------------------------------------------
-- 7. tbl_pest_device — 포충등·트랩
--    방충·방서 점검표의 행이 이 마스터 행 수만큼 자동 생성된다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_pest_device (
    idx        bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd      varchar(10)  NOT NULL,
    pest_cd    varchar(30)  NOT NULL,
    pest_nm    varchar(100) NOT NULL,
    pest_type  varchar(10)  NOT NULL,
    place_nm   varchar(100) NULL,
    sort_no    int          NOT NULL DEFAULT 0,
    use_yn     varchar(1)   NOT NULL DEFAULT 'Y',
    ins_id     varchar(20)  NULL,
    ins_dt     timestamp    NULL DEFAULT now(),
    upd_id     varchar(20)  NULL,
    upd_dt     timestamp    NULL,
    CONSTRAINT ux_tbl_pest_device UNIQUE (co_cd, pest_cd)
);
COMMENT ON TABLE  tbl_pest_device           IS '포충등·트랩 — 방충방서 점검표 행 자동 생성 원천. 업체별 설치 대수만큼 등록';
COMMENT ON COLUMN tbl_pest_device.idx       IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_pest_device.co_cd     IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_pest_device.pest_cd   IS '설비 코드 — 업체 내 유일';
COMMENT ON COLUMN tbl_pest_device.pest_nm   IS '설비명 — 포충등 1, 바퀴트랩 3 등. A4 표 좌측 열에 출력';
COMMENT ON COLUMN tbl_pest_device.pest_type IS '유형 — LAMP:포충등, ROACH:바퀴트랩, RAT:쥐트랩';
COMMENT ON COLUMN tbl_pest_device.place_nm  IS '설치 위치';
COMMENT ON COLUMN tbl_pest_device.sort_no   IS '정렬순서 — A4 표의 행 순서';
COMMENT ON COLUMN tbl_pest_device.use_yn    IS '사용여부 Y/N';
COMMENT ON COLUMN tbl_pest_device.ins_id    IS '최초입력자 ID';
COMMENT ON COLUMN tbl_pest_device.ins_dt    IS '최초입력일시';
COMMENT ON COLUMN tbl_pest_device.upd_id    IS '최종수정자 ID';
COMMENT ON COLUMN tbl_pest_device.upd_dt    IS '최종수정일시';

-- ------------------------------------------------------------
-- 8. tbl_vehicle — 차량
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_vehicle (
    idx              bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd            varchar(10) NOT NULL,
    vehicle_cd       varchar(30) NOT NULL,
    car_no           varchar(20) NOT NULL,
    car_type         varchar(50) NULL,
    owner_nm         varchar(50) NULL,
    driver_nm        varchar(50) NULL,
    cooler_yn        varchar(1)  NOT NULL DEFAULT 'Y',
    temp_recorder_yn varchar(1)  NOT NULL DEFAULT 'Y',
    use_yn           varchar(1)  NOT NULL DEFAULT 'Y',
    ins_id           varchar(20) NULL,
    ins_dt           timestamp   NULL DEFAULT now(),
    upd_id           varchar(20) NULL,
    upd_dt           timestamp   NULL,
    CONSTRAINT ux_tbl_vehicle UNIQUE (co_cd, vehicle_cd)
);
COMMENT ON TABLE  tbl_vehicle                  IS '차량 — 운반차량. 차량운행일지와 입고검사 차량점검의 선택 원천';
COMMENT ON COLUMN tbl_vehicle.idx              IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_vehicle.co_cd            IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_vehicle.vehicle_cd       IS '차량 코드 — 업체 내 유일';
COMMENT ON COLUMN tbl_vehicle.car_no           IS '차량번호 — 차량운행일지 제목에 출력';
COMMENT ON COLUMN tbl_vehicle.car_type         IS '차종';
COMMENT ON COLUMN tbl_vehicle.owner_nm         IS '소유자 — 자차/지입 구분용';
COMMENT ON COLUMN tbl_vehicle.driver_nm        IS '주 운전자명';
COMMENT ON COLUMN tbl_vehicle.cooler_yn        IS '적재함 냉각기 보유여부 Y/N';
COMMENT ON COLUMN tbl_vehicle.temp_recorder_yn IS '자동온도기록장치 보유여부 Y/N';
COMMENT ON COLUMN tbl_vehicle.use_yn           IS '사용여부 Y/N';
COMMENT ON COLUMN tbl_vehicle.ins_id           IS '최초입력자 ID';
COMMENT ON COLUMN tbl_vehicle.ins_dt           IS '최초입력일시';
COMMENT ON COLUMN tbl_vehicle.upd_id           IS '최종수정자 ID';
COMMENT ON COLUMN tbl_vehicle.upd_dt           IS '최종수정일시';

-- ------------------------------------------------------------
-- 9. tbl_work_area — 작업장·구역
--    작업장 환경위생관리 점검표의 열이 이 마스터 행 수만큼 생성된다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_work_area (
    idx           bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd         varchar(10)  NOT NULL,
    area_cd       varchar(30)  NOT NULL,
    area_nm       varchar(100) NOT NULL,
    area_gbn      varchar(10)  NULL,
    lux_std       int          NULL,
    temp_std_min  numeric(5,1) NULL,
    temp_std_max  numeric(5,1) NULL,
    humid_std_min numeric(5,1) NULL,
    humid_std_max numeric(5,1) NULL,
    sort_no       int          NOT NULL DEFAULT 0,
    use_yn        varchar(1)   NOT NULL DEFAULT 'Y',
    ins_id        varchar(20)  NULL,
    ins_dt        timestamp    NULL DEFAULT now(),
    upd_id        varchar(20)  NULL,
    upd_dt        timestamp    NULL,
    CONSTRAINT ux_tbl_work_area UNIQUE (co_cd, area_cd)
);
COMMENT ON TABLE  tbl_work_area               IS '작업장·구역 — 작업장 환경위생 점검표의 열 자동 생성 및 온습도·조도 기준 원천';
COMMENT ON COLUMN tbl_work_area.idx           IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_work_area.co_cd         IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_work_area.area_cd       IS '구역 코드 — 업체 내 유일';
COMMENT ON COLUMN tbl_work_area.area_nm       IS '구역명 — 작업장1, 내포장실 등. A4 표 열 머리글에 출력';
COMMENT ON COLUMN tbl_work_area.area_gbn      IS '위생구분 — CLEAN:청결구역, SEMI:준청결구역, GENERAL:일반구역';
COMMENT ON COLUMN tbl_work_area.lux_std       IS '조도 기준(LUX) — 검수대 540 등';
COMMENT ON COLUMN tbl_work_area.temp_std_min  IS '실내온도 하한 기준';
COMMENT ON COLUMN tbl_work_area.temp_std_max  IS '실내온도 상한 기준';
COMMENT ON COLUMN tbl_work_area.humid_std_min IS '습도 하한 기준(%)';
COMMENT ON COLUMN tbl_work_area.humid_std_max IS '습도 상한 기준(%)';
COMMENT ON COLUMN tbl_work_area.sort_no       IS '정렬순서 — A4 표의 열 순서';
COMMENT ON COLUMN tbl_work_area.use_yn        IS '사용여부 Y/N';
COMMENT ON COLUMN tbl_work_area.ins_id        IS '최초입력자 ID';
COMMENT ON COLUMN tbl_work_area.ins_dt        IS '최초입력일시';
COMMENT ON COLUMN tbl_work_area.upd_id        IS '최종수정자 ID';
COMMENT ON COLUMN tbl_work_area.upd_dt        IS '최종수정일시';
