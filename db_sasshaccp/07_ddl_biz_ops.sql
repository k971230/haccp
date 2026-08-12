-- ============================================================
--  DDL 7 — 업무 테이블 (3) 시설·재고·공정  [DB형 6종]
--
--  개발자: 박승우
--  일자: 2026-08-05
--  코멘트:
--    1) 10 시설·설비·처리도구 점검표, 11 검·교정 대상 점검표, 12 폐기물 처리 점검표,
--       13 입·출고 및 재고 점검표, 14 입고검사 일지, 15 공정관리 점검표
--    2) 입·출고는 문서(월 단위 결재본)와 거래내역을 분리한다 — 내역은 입고검사·폐기 등에서 자동 생성
--    3) 재고는 실물 재고관리(MES)가 아니라 HACCP 기록용 수불 이력이다.
--       단가·금액·창고 로케이션·안전재고 같은 회계/물류 컬럼은 두지 않는다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 10-1. tbl_facility_check — 시설·설비·처리도구 점검표 (헤더)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_facility_check (
    idx        bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd      varchar(10) NOT NULL,
    doc_idx    bigint      NOT NULL,
    base_dt    varchar(8)  NOT NULL,
    checker_id varchar(20) NULL,
    checker_nm varchar(50) NULL,
    ins_id     varchar(20) NULL,
    ins_dt     timestamp   NULL DEFAULT now(),
    upd_id     varchar(20) NULL,
    upd_dt     timestamp   NULL,
    CONSTRAINT ux_tbl_facility_check UNIQUE (doc_idx)
);
COMMENT ON TABLE  tbl_facility_check            IS '시설·설비·처리도구 점검표 헤더 — 표준기준서 관리번호 10';
COMMENT ON COLUMN tbl_facility_check.idx        IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_facility_check.co_cd      IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_facility_check.doc_idx    IS '문서 idx — tbl_document.idx와 1:1';
COMMENT ON COLUMN tbl_facility_check.base_dt    IS '점검일자 YYYYMMDD';
COMMENT ON COLUMN tbl_facility_check.checker_id IS '점검자 로그인 ID';
COMMENT ON COLUMN tbl_facility_check.checker_nm IS '점검자명 — 작성 시점 스냅샷';
COMMENT ON COLUMN tbl_facility_check.ins_id     IS '최초입력자 ID';
COMMENT ON COLUMN tbl_facility_check.ins_dt     IS '최초입력일시';
COMMENT ON COLUMN tbl_facility_check.upd_id     IS '최종수정자 ID';
COMMENT ON COLUMN tbl_facility_check.upd_dt     IS '최종수정일시';

-- ------------------------------------------------------------
-- 10-2. tbl_facility_check_item — 관리항목별 점검 결과
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_facility_check_item (
    idx         bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd       varchar(10)  NOT NULL,
    hdr_idx     bigint       NOT NULL,
    row_seq     int          NOT NULL,
    grp_nm      varchar(100) NULL,
    item_cd     varchar(20)  NULL,
    item_nm     varchar(500) NULL,
    method_nm   varchar(200) NULL,
    cycle_nm    varchar(50)  NULL,
    mng_nm      varchar(50)  NULL,
    judge_cd    varchar(1)   NULL,
    action_desc varchar(500) NULL,
    ins_id      varchar(20)  NULL,
    ins_dt      timestamp    NULL DEFAULT now(),
    upd_id      varchar(20)  NULL,
    upd_dt      timestamp    NULL,
    CONSTRAINT ux_tbl_facility_check_item UNIQUE (hdr_idx, row_seq)
);
COMMENT ON TABLE  tbl_facility_check_item             IS '시설·설비 관리항목별 점검 결과 — 점검방법·주기·담당자를 문서에 함께 남긴다';
COMMENT ON COLUMN tbl_facility_check_item.idx         IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_facility_check_item.co_cd       IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_facility_check_item.hdr_idx     IS '헤더 idx — tbl_facility_check.idx';
COMMENT ON COLUMN tbl_facility_check_item.row_seq     IS '행 순번';
COMMENT ON COLUMN tbl_facility_check_item.grp_nm      IS '관리항목 — 건물 외부, 작업장 내부, 처리도구 등 A4 좌측 병합 셀';
COMMENT ON COLUMN tbl_facility_check_item.item_cd     IS '항목코드 — tbl_check_item.item_cd';
COMMENT ON COLUMN tbl_facility_check_item.item_nm     IS '점검사항 문구 스냅샷';
COMMENT ON COLUMN tbl_facility_check_item.method_nm   IS '점검방법 — 육안점검 등';
COMMENT ON COLUMN tbl_facility_check_item.cycle_nm    IS '점검주기 — 1회/일, 1회/월 등';
COMMENT ON COLUMN tbl_facility_check_item.mng_nm      IS '담당자명';
COMMENT ON COLUMN tbl_facility_check_item.judge_cd    IS '판정 — O:양호, X:불량';
COMMENT ON COLUMN tbl_facility_check_item.action_desc IS '조치사항 — 불량(X)일 때 필수';
COMMENT ON COLUMN tbl_facility_check_item.ins_id      IS '최초입력자 ID';
COMMENT ON COLUMN tbl_facility_check_item.ins_dt      IS '최초입력일시';
COMMENT ON COLUMN tbl_facility_check_item.upd_id      IS '최종수정자 ID';
COMMENT ON COLUMN tbl_facility_check_item.upd_dt      IS '최종수정일시';

-- ------------------------------------------------------------
-- 11-1. tbl_calib_target — 검·교정 대상 점검표 (헤더)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_calib_target (
    idx        bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd      varchar(10) NOT NULL,
    doc_idx    bigint      NOT NULL,
    base_year  varchar(4)  NOT NULL,
    base_dt    varchar(8)  NULL,
    checker_id varchar(20) NULL,
    checker_nm varchar(50) NULL,
    ins_id     varchar(20) NULL,
    ins_dt     timestamp   NULL DEFAULT now(),
    upd_id     varchar(20) NULL,
    upd_dt     timestamp   NULL,
    CONSTRAINT ux_tbl_calib_target UNIQUE (doc_idx)
);
COMMENT ON TABLE  tbl_calib_target            IS '검·교정 대상 점검표 헤더 — 표준기준서 관리번호 11. 연 1회 작성';
COMMENT ON COLUMN tbl_calib_target.idx        IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_calib_target.co_cd      IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_calib_target.doc_idx    IS '문서 idx — tbl_document.idx와 1:1';
COMMENT ON COLUMN tbl_calib_target.base_year  IS '대상연도 YYYY';
COMMENT ON COLUMN tbl_calib_target.base_dt    IS '작성일자 YYYYMMDD';
COMMENT ON COLUMN tbl_calib_target.checker_id IS '작성자 로그인 ID';
COMMENT ON COLUMN tbl_calib_target.checker_nm IS '작성자명 — 작성 시점 스냅샷';
COMMENT ON COLUMN tbl_calib_target.ins_id     IS '최초입력자 ID';
COMMENT ON COLUMN tbl_calib_target.ins_dt     IS '최초입력일시';
COMMENT ON COLUMN tbl_calib_target.upd_id     IS '최종수정자 ID';
COMMENT ON COLUMN tbl_calib_target.upd_dt     IS '최종수정일시';

-- ------------------------------------------------------------
-- 11-2. tbl_calib_target_row — 계측기별 검·교정 계획·실적
--       차기 예정일이 도래하면 알림을 보내고, 자체 검교정 일지(rhwp)와 문서 연결을 만든다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_calib_target_row (
    idx               bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd             varchar(10)  NOT NULL,
    hdr_idx           bigint       NOT NULL,
    row_seq           int          NOT NULL,
    device_cd         varchar(30)  NOT NULL,
    device_nm         varchar(200) NULL,
    official_calib_dt varchar(8)   NULL,
    self_calib_dt     varchar(8)   NULL,
    next_calib_dt     varchar(8)   NULL,
    done_doc_idx      bigint       NULL,
    remark            varchar(500) NULL,
    ins_id            varchar(20)  NULL,
    ins_dt            timestamp    NULL DEFAULT now(),
    upd_id            varchar(20)  NULL,
    upd_dt            timestamp    NULL,
    CONSTRAINT ux_tbl_calib_target_row UNIQUE (hdr_idx, row_seq)
);
COMMENT ON TABLE  tbl_calib_target_row                   IS '계측기별 검·교정 계획·실적 — 행은 tbl_measuring_device 등록 대수만큼 자동 생성';
COMMENT ON COLUMN tbl_calib_target_row.idx               IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_calib_target_row.co_cd             IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_calib_target_row.hdr_idx           IS '헤더 idx — tbl_calib_target.idx';
COMMENT ON COLUMN tbl_calib_target_row.row_seq           IS '행 순번';
COMMENT ON COLUMN tbl_calib_target_row.device_cd         IS '계측기 코드 — tbl_measuring_device.device_cd';
COMMENT ON COLUMN tbl_calib_target_row.device_nm         IS '계측기명 스냅샷 — 저울 1, 온도계(표준) 등';
COMMENT ON COLUMN tbl_calib_target_row.official_calib_dt IS '공인기관 검·교정 일자 YYYYMMDD';
COMMENT ON COLUMN tbl_calib_target_row.self_calib_dt     IS '자체 검·교정 일자 YYYYMMDD';
COMMENT ON COLUMN tbl_calib_target_row.next_calib_dt     IS '차기 검·교정 예정일자 YYYYMMDD — 직전 교정일 + calib_cycle_month. 도래 시 알림';
COMMENT ON COLUMN tbl_calib_target_row.done_doc_idx      IS '실적 문서 idx — 자체 검·교정 일지 tbl_document.idx. 문서 연결로 근거를 남긴다';
COMMENT ON COLUMN tbl_calib_target_row.remark            IS '비고';
COMMENT ON COLUMN tbl_calib_target_row.ins_id        IS '최초입력자 ID';
COMMENT ON COLUMN tbl_calib_target_row.ins_dt        IS '최초입력일시';
COMMENT ON COLUMN tbl_calib_target_row.upd_id        IS '최종수정자 ID';
COMMENT ON COLUMN tbl_calib_target_row.upd_dt        IS '최종수정일시';

-- ------------------------------------------------------------
-- 12-1. tbl_waste_check — 폐기물 처리 점검표 (헤더)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_waste_check (
    idx        bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd      varchar(10) NOT NULL,
    doc_idx    bigint      NOT NULL,
    base_dt    varchar(8)  NOT NULL,
    base_dt_to varchar(8)  NULL,
    ins_id     varchar(20) NULL,
    ins_dt     timestamp   NULL DEFAULT now(),
    upd_id     varchar(20) NULL,
    upd_dt     timestamp   NULL,
    CONSTRAINT ux_tbl_waste_check UNIQUE (doc_idx)
);
COMMENT ON TABLE  tbl_waste_check            IS '폐기물 처리 점검표 헤더 — 표준기준서 관리번호 12. 부적합품 폐기 기록';
COMMENT ON COLUMN tbl_waste_check.idx        IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_waste_check.co_cd      IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_waste_check.doc_idx    IS '문서 idx — tbl_document.idx와 1:1';
COMMENT ON COLUMN tbl_waste_check.base_dt    IS '기준일자 YYYYMMDD — 기간 문서일 때 시작일';
COMMENT ON COLUMN tbl_waste_check.base_dt_to IS '기간 종료일 YYYYMMDD';
COMMENT ON COLUMN tbl_waste_check.ins_id     IS '최초입력자 ID';
COMMENT ON COLUMN tbl_waste_check.ins_dt     IS '최초입력일시';
COMMENT ON COLUMN tbl_waste_check.upd_id     IS '최종수정자 ID';
COMMENT ON COLUMN tbl_waste_check.upd_dt     IS '최종수정일시';

-- ------------------------------------------------------------
-- 12-2. tbl_waste_check_row — 폐기 처리 내역
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_waste_check_row (
    idx         bigint        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd       varchar(10)   NOT NULL,
    hdr_idx     bigint        NOT NULL,
    row_seq     int           NOT NULL,
    proc_dt     varchar(8)    NOT NULL,
    waste_gbn   varchar(10)   NULL,
    item_nm     varchar(200)  NULL,
    make_dt     varchar(8)    NULL,
    expire_dt   varchar(8)    NULL,
    weight_kg   numeric(12,2) NULL,
    bad_desc    varchar(500)  NULL,
    proc_desc   varchar(500)  NULL,
    partner_cd  varchar(30)   NULL,
    partner_nm  varchar(200)  NULL,
    mng_user_id varchar(20)   NULL,
    mng_nm      varchar(50)   NULL,
    ins_id      varchar(20)   NULL,
    ins_dt      timestamp     NULL DEFAULT now(),
    upd_id      varchar(20)   NULL,
    upd_dt      timestamp     NULL,
    CONSTRAINT ux_tbl_waste_check_row UNIQUE (hdr_idx, row_seq)
);
COMMENT ON TABLE  tbl_waste_check_row             IS '폐기 처리 내역 — 폐기 확정 시 tbl_inv_txn 출고 내역을 자동 생성한다';
COMMENT ON COLUMN tbl_waste_check_row.idx         IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_waste_check_row.co_cd       IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_waste_check_row.hdr_idx     IS '헤더 idx — tbl_waste_check.idx';
COMMENT ON COLUMN tbl_waste_check_row.row_seq     IS '행 순번';
COMMENT ON COLUMN tbl_waste_check_row.proc_dt     IS '처리일자 YYYYMMDD';
COMMENT ON COLUMN tbl_waste_check_row.waste_gbn   IS '구분 — BAD:부적합품, tmpl_prp-waste-check:일반 폐기물, EXPIRE:기한경과';
COMMENT ON COLUMN tbl_waste_check_row.item_nm     IS '품명';
COMMENT ON COLUMN tbl_waste_check_row.make_dt     IS '제조일자 YYYYMMDD';
COMMENT ON COLUMN tbl_waste_check_row.expire_dt   IS '소비기한 YYYYMMDD';
COMMENT ON COLUMN tbl_waste_check_row.weight_kg   IS '중량(kg)';
COMMENT ON COLUMN tbl_waste_check_row.bad_desc    IS '부적합 내용';
COMMENT ON COLUMN tbl_waste_check_row.proc_desc   IS '처리 방법 — 소각·매립·위탁 등';
COMMENT ON COLUMN tbl_waste_check_row.partner_cd  IS '수거업체 코드 — tbl_partner.partner_cd (partner_gbn=WASTE)';
COMMENT ON COLUMN tbl_waste_check_row.partner_nm  IS '수거업체명 스냅샷';
COMMENT ON COLUMN tbl_waste_check_row.mng_user_id IS '담당자 로그인 ID';
COMMENT ON COLUMN tbl_waste_check_row.mng_nm      IS '담당자명 스냅샷';
COMMENT ON COLUMN tbl_waste_check_row.ins_id      IS '최초입력자 ID';
COMMENT ON COLUMN tbl_waste_check_row.ins_dt      IS '최초입력일시';
COMMENT ON COLUMN tbl_waste_check_row.upd_id      IS '최종수정자 ID';
COMMENT ON COLUMN tbl_waste_check_row.upd_dt      IS '최종수정일시';

-- ------------------------------------------------------------
-- 13-1. tbl_inv_check — 입·출고 및 재고 점검표 (헤더, 월 단위 결재본)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_inv_check (
    idx      bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd    varchar(10) NOT NULL,
    doc_idx  bigint      NOT NULL,
    base_ym  varchar(6)  NOT NULL,
    ins_id   varchar(20) NULL,
    ins_dt   timestamp   NULL DEFAULT now(),
    upd_id   varchar(20) NULL,
    upd_dt   timestamp   NULL,
    CONSTRAINT ux_tbl_inv_check UNIQUE (doc_idx)
);
COMMENT ON TABLE  tbl_inv_check          IS '입·출고 및 재고 점검표 헤더 — 표준기준서 관리번호 13. 월 단위 결재본';
COMMENT ON COLUMN tbl_inv_check.idx      IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_inv_check.co_cd    IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_inv_check.doc_idx  IS '문서 idx — tbl_document.idx와 1:1';
COMMENT ON COLUMN tbl_inv_check.base_ym  IS '기준 연월 YYYYMM — 이 달의 tbl_inv_txn 내역을 문서로 확정';
COMMENT ON COLUMN tbl_inv_check.ins_id   IS '최초입력자 ID';
COMMENT ON COLUMN tbl_inv_check.ins_dt   IS '최초입력일시';
COMMENT ON COLUMN tbl_inv_check.upd_id   IS '최종수정자 ID';
COMMENT ON COLUMN tbl_inv_check.upd_dt   IS '최종수정일시';

-- ------------------------------------------------------------
-- 13-2. tbl_inv_txn — 입·출고 수불 이력
--       입고검사 승인·폐기 확정 시 자동 생성된다(src_tmpl_cd·src_doc_idx로 출처 추적).
--       단가·금액·창고 로케이션 등 회계/물류 컬럼은 두지 않는다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_inv_txn (
    idx         bigint        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd       varchar(10)   NOT NULL,
    txn_dt      varchar(8)    NOT NULL,
    txn_gbn     varchar(3)    NOT NULL,
    item_gbn    varchar(10)   NOT NULL,
    material_cd varchar(30)   NULL,
    product_cd  varchar(30)   NULL,
    item_nm     varchar(200)  NOT NULL,
    partner_cd  varchar(30)   NULL,
    partner_nm  varchar(200)  NULL,
    qty         numeric(15,3) NOT NULL DEFAULT 0,
    unit_nm     varchar(20)   NULL,
    lot_no      varchar(50)   NULL,
    make_dt     varchar(8)    NULL,
    expire_dt   varchar(8)    NULL,
    storage_cd  varchar(30)   NULL,
    src_tmpl_cd varchar(40)   NULL,
    src_doc_idx bigint        NULL,
    remark      varchar(500)  NULL,
    ins_id      varchar(20)   NULL,
    ins_dt      timestamp     NULL DEFAULT now(),
    upd_id      varchar(20)   NULL,
    upd_dt      timestamp     NULL
);
COMMENT ON TABLE  tbl_inv_txn             IS '입·출고 수불 이력 — HACCP 기록용. 실물 재고관리(MES)가 아니므로 단가·금액을 다루지 않는다';
COMMENT ON COLUMN tbl_inv_txn.idx         IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_inv_txn.co_cd       IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_inv_txn.txn_dt      IS '거래일자 YYYYMMDD';
COMMENT ON COLUMN tbl_inv_txn.txn_gbn     IS '구분 — IN:입고, OUT:출고';
COMMENT ON COLUMN tbl_inv_txn.item_gbn    IS '품목구분 — MEAT:원료육, SUB:부재료, PACK:포장재, PROD:완제품';
COMMENT ON COLUMN tbl_inv_txn.material_cd IS '원부재료 코드 — tbl_material.material_cd. 완제품일 때 NULL';
COMMENT ON COLUMN tbl_inv_txn.product_cd  IS '제품코드 — tbl_product.product_cd. 원부재료일 때 NULL';
COMMENT ON COLUMN tbl_inv_txn.item_nm     IS '품명 스냅샷 — 마스터가 바뀌어도 당시 명칭 유지';
COMMENT ON COLUMN tbl_inv_txn.partner_cd  IS '거래처 코드 — tbl_partner.partner_cd';
COMMENT ON COLUMN tbl_inv_txn.partner_nm  IS '거래처명 스냅샷';
COMMENT ON COLUMN tbl_inv_txn.qty         IS '수량 — 부호 없이 양수. 방향은 txn_gbn으로 판단';
COMMENT ON COLUMN tbl_inv_txn.unit_nm     IS '단위';
COMMENT ON COLUMN tbl_inv_txn.lot_no      IS '로트번호 — 회수 시 추적 단위';
COMMENT ON COLUMN tbl_inv_txn.make_dt     IS '제조일자 YYYYMMDD';
COMMENT ON COLUMN tbl_inv_txn.expire_dt   IS '소비기한 YYYYMMDD — 경과 임박 시 알림';
COMMENT ON COLUMN tbl_inv_txn.storage_cd  IS '보관고 코드 — tbl_storage.storage_cd';
COMMENT ON COLUMN tbl_inv_txn.src_tmpl_cd IS '출처 템플릿 코드 — tmpl_logis-receive-inspect(입고검사), WASTE(폐기) 등. NULL이면(= 직접 입력)';
COMMENT ON COLUMN tbl_inv_txn.src_doc_idx IS '출처 문서 idx — tbl_document.idx. 자동 생성 내역의 원본 추적';
COMMENT ON COLUMN tbl_inv_txn.remark      IS '비고';
COMMENT ON COLUMN tbl_inv_txn.ins_id      IS '최초입력자 ID';
COMMENT ON COLUMN tbl_inv_txn.ins_dt      IS '최초입력일시';
COMMENT ON COLUMN tbl_inv_txn.upd_id      IS '최종수정자 ID';
COMMENT ON COLUMN tbl_inv_txn.upd_dt      IS '최종수정일시';

-- ------------------------------------------------------------
-- 14-1. tbl_recv_inspect — 입고검사 일지 (헤더)
--       원료육/부재료 구분에 따라 화면에서 보여줄 검사항목 세트가 달라진다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_recv_inspect (
    idx           bigint        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd         varchar(10)   NOT NULL,
    doc_idx       bigint        NOT NULL,
    base_dt       varchar(8)    NOT NULL,
    recv_gbn      varchar(10)   NOT NULL,
    recv_time     varchar(4)    NULL,
    partner_cd    varchar(30)   NULL,
    partner_nm    varchar(200)  NULL,
    material_cd   varchar(30)   NULL,
    item_nm       varchar(200)  NULL,
    recv_qty      numeric(15,3) NULL,
    unit_nm       varchar(20)   NULL,
    lot_no        varchar(50)   NULL,
    make_dt       varchar(8)    NULL,
    expire_dt     varchar(8)    NULL,
    core_temp     numeric(5,1)  NULL,
    car_temp      numeric(5,1)  NULL,
    vehicle_cd    varchar(30)   NULL,
    car_no        varchar(20)   NULL,
    haccp_apply_cd varchar(1)   NULL,
    judge_cd      varchar(1)    NULL,
    judge_mod_yn  varchar(1)    NOT NULL DEFAULT 'N',
    checker_id    varchar(20)   NULL,
    checker_nm    varchar(50)   NULL,
    ins_id        varchar(20)   NULL,
    ins_dt        timestamp     NULL DEFAULT now(),
    upd_id        varchar(20)   NULL,
    upd_dt        timestamp     NULL,
    CONSTRAINT ux_tbl_recv_inspect UNIQUE (doc_idx)
);
COMMENT ON TABLE  tbl_recv_inspect                IS '입고검사 일지 헤더 — 표준기준서 관리번호 14. 승인 시 tbl_inv_txn 입고 내역 자동 생성';
COMMENT ON COLUMN tbl_recv_inspect.idx            IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_recv_inspect.co_cd          IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_recv_inspect.doc_idx        IS '문서 idx — tbl_document.idx와 1:1';
COMMENT ON COLUMN tbl_recv_inspect.base_dt        IS '입고일자 YYYYMMDD';
COMMENT ON COLUMN tbl_recv_inspect.recv_gbn       IS '입고구분 — MEAT:원료육, SUB:부재료, PACK:포장재. 검사항목 세트를 결정';
COMMENT ON COLUMN tbl_recv_inspect.recv_time      IS '입고시각 HHMM';
COMMENT ON COLUMN tbl_recv_inspect.partner_cd     IS '반입처 코드 — tbl_partner.partner_cd';
COMMENT ON COLUMN tbl_recv_inspect.partner_nm     IS '반입처명 스냅샷';
COMMENT ON COLUMN tbl_recv_inspect.material_cd    IS '원부재료 코드 — tbl_material.material_cd';
COMMENT ON COLUMN tbl_recv_inspect.item_nm        IS '품명 스냅샷';
COMMENT ON COLUMN tbl_recv_inspect.recv_qty       IS '입고 수량';
COMMENT ON COLUMN tbl_recv_inspect.unit_nm        IS '단위';
COMMENT ON COLUMN tbl_recv_inspect.lot_no         IS '로트번호';
COMMENT ON COLUMN tbl_recv_inspect.make_dt        IS '제조(도축)일자 YYYYMMDD';
COMMENT ON COLUMN tbl_recv_inspect.expire_dt      IS '소비기한 YYYYMMDD';
COMMENT ON COLUMN tbl_recv_inspect.core_temp      IS '품온(심부온도, 섭씨) — 냉장 원료육 기준 초과 시 부적합';
COMMENT ON COLUMN tbl_recv_inspect.car_temp       IS '운반차량 적재함 온도(섭씨)';
COMMENT ON COLUMN tbl_recv_inspect.vehicle_cd     IS '차량 코드 — tbl_vehicle.vehicle_cd. 자사 차량일 때만';
COMMENT ON COLUMN tbl_recv_inspect.car_no         IS '차량번호 — 타사 차량은 직접 입력';
COMMENT ON COLUMN tbl_recv_inspect.haccp_apply_cd IS '공급처 HACCP 적용 확인 — Y:적용, N:미적용';
COMMENT ON COLUMN tbl_recv_inspect.judge_cd       IS '종합 판정 — P:적합, F:부적합. 품온·검사항목을 종합해 SP가 확정';
COMMENT ON COLUMN tbl_recv_inspect.judge_mod_yn   IS '판정 수동변경 여부 Y/N';
COMMENT ON COLUMN tbl_recv_inspect.checker_id     IS '검사자 로그인 ID';
COMMENT ON COLUMN tbl_recv_inspect.checker_nm     IS '검사자명 — 작성 시점 스냅샷';
COMMENT ON COLUMN tbl_recv_inspect.ins_id         IS '최초입력자 ID';
COMMENT ON COLUMN tbl_recv_inspect.ins_dt         IS '최초입력일시';
COMMENT ON COLUMN tbl_recv_inspect.upd_id         IS '최종수정자 ID';
COMMENT ON COLUMN tbl_recv_inspect.upd_dt         IS '최종수정일시';

-- ------------------------------------------------------------
-- 14-2. tbl_recv_inspect_item — 입고검사 항목별 결과
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_recv_inspect_item (
    idx       bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd     varchar(10)  NOT NULL,
    hdr_idx   bigint       NOT NULL,
    row_seq   int          NOT NULL,
    grp_cd    varchar(20)  NOT NULL,
    item_cd   varchar(20)  NOT NULL,
    item_nm   varchar(500) NULL,
    judge_cd  varchar(1)   NULL,
    eval_desc varchar(500) NULL,
    ins_id    varchar(20)  NULL,
    ins_dt    timestamp    NULL DEFAULT now(),
    upd_id    varchar(20)  NULL,
    upd_dt    timestamp    NULL,
    CONSTRAINT ux_tbl_recv_inspect_item UNIQUE (hdr_idx, row_seq)
);
COMMENT ON TABLE  tbl_recv_inspect_item           IS '입고검사 항목별 결과 — 관능·차량·서류·HACCP 확인을 한 표로 관리';
COMMENT ON COLUMN tbl_recv_inspect_item.idx       IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_recv_inspect_item.co_cd     IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_recv_inspect_item.hdr_idx   IS '헤더 idx — tbl_recv_inspect.idx';
COMMENT ON COLUMN tbl_recv_inspect_item.row_seq   IS '행 순번';
COMMENT ON COLUMN tbl_recv_inspect_item.grp_cd    IS '항목 구분 — tmpl_admin-eval-check:관능검사, CAR:운반차량, DOC:구비서류, HACCP:HACCP 확인';
COMMENT ON COLUMN tbl_recv_inspect_item.item_cd   IS '항목코드 — tbl_check_item.item_cd';
COMMENT ON COLUMN tbl_recv_inspect_item.item_nm   IS '항목 문구 스냅샷';
COMMENT ON COLUMN tbl_recv_inspect_item.judge_cd  IS '판정 — P:적합, F:부적합. 하나라도 F면 헤더 종합판정이 F';
COMMENT ON COLUMN tbl_recv_inspect_item.eval_desc IS '평가 내용 — 색택·냄새·이물 등 관찰 결과';
COMMENT ON COLUMN tbl_recv_inspect_item.ins_id    IS '최초입력자 ID';
COMMENT ON COLUMN tbl_recv_inspect_item.ins_dt    IS '최초입력일시';
COMMENT ON COLUMN tbl_recv_inspect_item.upd_id    IS '최종수정자 ID';
COMMENT ON COLUMN tbl_recv_inspect_item.upd_dt    IS '최종수정일시';

-- ------------------------------------------------------------
-- 15-1. tbl_process_check — 공정관리 점검표 (헤더)
--       한 문서가 기간(주로 1개월)을 담고 일자·오전오후 단위로 점검한다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_process_check (
    idx        bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd      varchar(10) NOT NULL,
    doc_idx    bigint      NOT NULL,
    base_dt    varchar(8)  NOT NULL,
    base_dt_to varchar(8)  NULL,
    cycle_nm   varchar(50) NULL,
    ins_id     varchar(20) NULL,
    ins_dt     timestamp   NULL DEFAULT now(),
    upd_id     varchar(20) NULL,
    upd_dt     timestamp   NULL,
    CONSTRAINT ux_tbl_process_check UNIQUE (doc_idx)
);
COMMENT ON TABLE  tbl_process_check            IS '공정관리 점검표 헤더 — 표준기준서 관리번호 15. 해동부터 출고까지 공정별 위생 점검';
COMMENT ON COLUMN tbl_process_check.idx        IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_process_check.co_cd      IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_process_check.doc_idx    IS '문서 idx — tbl_document.idx와 1:1';
COMMENT ON COLUMN tbl_process_check.base_dt    IS '기간 시작일 YYYYMMDD';
COMMENT ON COLUMN tbl_process_check.base_dt_to IS '기간 종료일 YYYYMMDD';
COMMENT ON COLUMN tbl_process_check.cycle_nm   IS '점검주기 표기 문구 — 2회/일 등';
COMMENT ON COLUMN tbl_process_check.ins_id     IS '최초입력자 ID';
COMMENT ON COLUMN tbl_process_check.ins_dt     IS '최초입력일시';
COMMENT ON COLUMN tbl_process_check.upd_id     IS '최종수정자 ID';
COMMENT ON COLUMN tbl_process_check.upd_dt     IS '최종수정일시';

-- ------------------------------------------------------------
-- 15-2. tbl_process_check_item — 공정별 점검항목 (행)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_process_check_item (
    idx     bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd   varchar(10)  NOT NULL,
    hdr_idx bigint       NOT NULL,
    row_seq int          NOT NULL,
    proc_cd varchar(20)  NULL,
    proc_nm varchar(100) NULL,
    item_cd varchar(20)  NOT NULL,
    item_nm varchar(500) NULL,
    ins_id  varchar(20)  NULL,
    ins_dt  timestamp    NULL DEFAULT now(),
    upd_id  varchar(20)  NULL,
    upd_dt  timestamp    NULL,
    CONSTRAINT ux_tbl_process_check_item UNIQUE (hdr_idx, row_seq)
);
COMMENT ON TABLE  tbl_process_check_item         IS '공정별 점검항목 — 해동·개포·정형·내포장·금속검출·외포장·출고 구분';
COMMENT ON COLUMN tbl_process_check_item.idx     IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_process_check_item.co_cd   IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_process_check_item.hdr_idx IS '헤더 idx — tbl_process_check.idx';
COMMENT ON COLUMN tbl_process_check_item.row_seq IS '행 순번';
COMMENT ON COLUMN tbl_process_check_item.proc_cd IS '공정 코드 — THAW:해동, UNPACK:개포, TRIM:정형, INPACK:내포장, METAL:금속검출, OUTPACK:외포장, SHIP:출고';
COMMENT ON COLUMN tbl_process_check_item.proc_nm IS '공정명 — A4 표 좌측 병합 셀';
COMMENT ON COLUMN tbl_process_check_item.item_cd IS '항목코드 — tbl_check_item.item_cd';
COMMENT ON COLUMN tbl_process_check_item.item_nm IS '항목 문구 스냅샷';
COMMENT ON COLUMN tbl_process_check_item.ins_id  IS '최초입력자 ID';
COMMENT ON COLUMN tbl_process_check_item.ins_dt  IS '최초입력일시';
COMMENT ON COLUMN tbl_process_check_item.upd_id  IS '최종수정자 ID';
COMMENT ON COLUMN tbl_process_check_item.upd_dt  IS '최종수정일시';

-- ------------------------------------------------------------
-- 15-3. tbl_process_check_result — 일자·오전오후별 판정 (세로 정규화)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_process_check_result (
    idx      bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd    varchar(10) NOT NULL,
    item_idx bigint      NOT NULL,
    check_dt varchar(8)  NOT NULL,
    ampm_cd  varchar(2)  NOT NULL DEFAULT 'AM',
    judge_cd varchar(1)  NULL,
    ins_id   varchar(20) NULL,
    ins_dt   timestamp   NULL DEFAULT now(),
    upd_id   varchar(20) NULL,
    upd_dt   timestamp   NULL,
    CONSTRAINT ux_tbl_process_check_result UNIQUE (item_idx, check_dt, ampm_cd)
);
COMMENT ON TABLE  tbl_process_check_result          IS '공정관리 일자별 판정 — A4 표의 날짜 열을 세로 정규화. 하루 2회 점검을 오전·오후로 구분';
COMMENT ON COLUMN tbl_process_check_result.idx      IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_process_check_result.co_cd    IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_process_check_result.item_idx IS '점검항목 idx — tbl_process_check_item.idx';
COMMENT ON COLUMN tbl_process_check_result.check_dt IS '점검일자 YYYYMMDD';
COMMENT ON COLUMN tbl_process_check_result.ampm_cd  IS '점검 시간대 — AM:오전, PM:오후';
COMMENT ON COLUMN tbl_process_check_result.judge_cd IS '판정 — O:양호, X:불량';
COMMENT ON COLUMN tbl_process_check_result.ins_id   IS '최초입력자 ID';
COMMENT ON COLUMN tbl_process_check_result.ins_dt   IS '최초입력일시';
COMMENT ON COLUMN tbl_process_check_result.upd_id   IS '최종수정자 ID';
COMMENT ON COLUMN tbl_process_check_result.upd_dt   IS '최종수정일시';

-- ------------------------------------------------------------
-- 15-4. tbl_process_check_signer — 일자별 점검자·검토자
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_process_check_signer (
    idx         bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd       varchar(10) NOT NULL,
    hdr_idx     bigint      NOT NULL,
    check_dt    varchar(8)  NOT NULL,
    checker_id  varchar(20) NULL,
    checker_nm  varchar(50) NULL,
    reviewer_id varchar(20) NULL,
    reviewer_nm varchar(50) NULL,
    ins_id      varchar(20) NULL,
    ins_dt      timestamp   NULL DEFAULT now(),
    upd_id      varchar(20) NULL,
    upd_dt      timestamp   NULL,
    CONSTRAINT ux_tbl_process_check_signer UNIQUE (hdr_idx, check_dt)
);
COMMENT ON TABLE  tbl_process_check_signer             IS '공정관리 일자별 점검자·검토자 — A4 표 하단 서명 행';
COMMENT ON COLUMN tbl_process_check_signer.idx         IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_process_check_signer.co_cd       IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_process_check_signer.hdr_idx     IS '헤더 idx — tbl_process_check.idx';
COMMENT ON COLUMN tbl_process_check_signer.check_dt    IS '점검일자 YYYYMMDD';
COMMENT ON COLUMN tbl_process_check_signer.checker_id  IS '점검자 로그인 ID';
COMMENT ON COLUMN tbl_process_check_signer.checker_nm  IS '점검자명 — 서명란 표기용 스냅샷';
COMMENT ON COLUMN tbl_process_check_signer.reviewer_id IS '검토자 로그인 ID';
COMMENT ON COLUMN tbl_process_check_signer.reviewer_nm IS '검토자명 — 서명란 표기용 스냅샷';
COMMENT ON COLUMN tbl_process_check_signer.ins_id      IS '최초입력자 ID';
COMMENT ON COLUMN tbl_process_check_signer.ins_dt      IS '최초입력일시';
COMMENT ON COLUMN tbl_process_check_signer.upd_id      IS '최종수정자 ID';
COMMENT ON COLUMN tbl_process_check_signer.upd_dt      IS '최종수정일시';
