-- ============================================================
-- 38 — 화면 명세 A1~A13 작성용 DDL·양식 전환
--
-- 개발자: 박승우
-- 일자: 2026-08-07
-- 코멘트:
--   1) 건강진단 그리드·설비이력 M-D·방충 체크플래그·협력업체·CCP 개선조치방법을 추가한다
--   2) EQUIP_CARD 는 HWP→DB 작성으로 바꾸고 화면 tmpl를 맞춘다
--   3) 재실행 안전 — IF NOT EXISTS / 컬럼 존재 시 스킵
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 건강진단관리기록부 (인원 그리드)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_health_cert (
    idx           bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd         varchar(10)  NOT NULL,
    person_nm     varchar(50)  NOT NULL,
    exam_dt       varchar(8)   NOT NULL,
    expire_dt     varchar(8)   NULL,
    remark        varchar(500) NULL,
    file_path     varchar(500) NULL,
    file_nm       varchar(200) NULL,
    use_yn        varchar(1)   NOT NULL DEFAULT 'Y',
    ins_id        varchar(20)  NULL,
    ins_dt        timestamp    NULL DEFAULT now(),
    upd_id        varchar(20)  NULL,
    upd_dt        timestamp    NULL
);
CREATE INDEX IF NOT EXISTS ix_tbl_health_cert_co ON tbl_health_cert (co_cd, person_nm);
COMMENT ON TABLE  tbl_health_cert IS '건강진단관리기록부 — 성명·검진일·만료·첨부 (HA-HYG-02)';
COMMENT ON COLUMN tbl_health_cert.person_nm IS '성명';
COMMENT ON COLUMN tbl_health_cert.exam_dt   IS '검진일 YYYYMMDD';
COMMENT ON COLUMN tbl_health_cert.expire_dt IS '갱신만료일 YYYYMMDD';
COMMENT ON COLUMN tbl_health_cert.file_path IS '첨부 상대경로 — APP_FILE_ROOT 기준';

UPDATE tbl_template SET
    doc_kind = 'DB',
    scrn_cd  = 'health-cert-record',
    mng_no   = 'HA-HYG-02',
    upd_id   = 'system',
    upd_dt   = now()
 WHERE tmpl_cd = 'LAW_HEALTH';

UPDATE tbl_screen SET tmpl_cd = 'LAW_HEALTH', module_cd = 'WRK', use_yn = 'Y',
    scrn_nm = '건강진단관리기록부', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd = 'health-cert-record';

-- ------------------------------------------------------------
-- 2. 방충 체크그룹 플래그 (기존 수량 컬럼 유지 + yn 추가)
--    Y=발견/체크, N=미발견, /=관리대상아님
-- ------------------------------------------------------------
ALTER TABLE tbl_pest_check_row ADD COLUMN IF NOT EXISTS fly_yn      varchar(1) NULL;
ALTER TABLE tbl_pest_check_row ADD COLUMN IF NOT EXISTS moth_yn     varchar(1) NULL;
ALTER TABLE tbl_pest_check_row ADD COLUMN IF NOT EXISTS mosq_yn     varchar(1) NULL;
ALTER TABLE tbl_pest_check_row ADD COLUMN IF NOT EXISTS midge_yn    varchar(1) NULL;
ALTER TABLE tbl_pest_check_row ADD COLUMN IF NOT EXISTS etc_fly_yn  varchar(1) NULL;
ALTER TABLE tbl_pest_check_row ADD COLUMN IF NOT EXISTS roach_yn    varchar(1) NULL;
ALTER TABLE tbl_pest_check_row ADD COLUMN IF NOT EXISTS spider_yn   varchar(1) NULL;
ALTER TABLE tbl_pest_check_row ADD COLUMN IF NOT EXISTS ant_yn      varchar(1) NULL;
ALTER TABLE tbl_pest_check_row ADD COLUMN IF NOT EXISTS etc_walk_yn varchar(1) NULL;
ALTER TABLE tbl_pest_check_row ADD COLUMN IF NOT EXISTS rat_yn      varchar(1) NULL;
ALTER TABLE tbl_pest_check_row ADD COLUMN IF NOT EXISTS etc_rat_yn  varchar(1) NULL;

-- 기존 수량 → 플래그 1회 이관 (cnt>0 → Y, 아니면 N)
UPDATE tbl_pest_check_row SET
    fly_yn      = CASE WHEN COALESCE(fly_cnt,0) > 0 THEN 'Y' ELSE COALESCE(fly_yn, 'N') END,
    moth_yn     = CASE WHEN COALESCE(moth_cnt,0) > 0 THEN 'Y' ELSE COALESCE(moth_yn, 'N') END,
    mosq_yn     = CASE WHEN COALESCE(mosq_cnt,0) > 0 THEN 'Y' ELSE COALESCE(mosq_yn, 'N') END,
    midge_yn    = CASE WHEN COALESCE(midge_cnt,0) > 0 THEN 'Y' ELSE COALESCE(midge_yn, 'N') END,
    etc_fly_yn  = CASE WHEN COALESCE(etc_fly_cnt,0) > 0 THEN 'Y' ELSE COALESCE(etc_fly_yn, 'N') END,
    roach_yn    = CASE WHEN COALESCE(roach_cnt,0) > 0 THEN 'Y' ELSE COALESCE(roach_yn, 'N') END,
    spider_yn   = CASE WHEN COALESCE(spider_cnt,0) > 0 THEN 'Y' ELSE COALESCE(spider_yn, 'N') END,
    ant_yn      = CASE WHEN COALESCE(ant_cnt,0) > 0 THEN 'Y' ELSE COALESCE(ant_yn, 'N') END,
    etc_walk_yn = CASE WHEN COALESCE(etc_walk_cnt,0) > 0 THEN 'Y' ELSE COALESCE(etc_walk_yn, 'N') END,
    rat_yn      = CASE WHEN COALESCE(rat_cnt,0) > 0 THEN 'Y' ELSE COALESCE(rat_yn, 'N') END,
    etc_rat_yn  = CASE WHEN COALESCE(etc_rat_cnt,0) > 0 THEN 'Y' ELSE COALESCE(etc_rat_yn, 'N') END
 WHERE fly_yn IS NULL OR moth_yn IS NULL;

-- ------------------------------------------------------------
-- 3. CCP 한계 — 개선조치방법
-- ------------------------------------------------------------
ALTER TABLE tbl_ccp_limit ADD COLUMN IF NOT EXISTS improve_rmk text NULL;
COMMENT ON COLUMN tbl_ccp_limit.improve_rmk IS '개선조치방법 서술 — 기준관리·일지 상단';

-- ------------------------------------------------------------
-- 4. 협력업체 리스트 등록여부
-- ------------------------------------------------------------
ALTER TABLE tbl_partner ADD COLUMN IF NOT EXISTS coop_list_yn varchar(1) NOT NULL DEFAULT 'N';
COMMENT ON COLUMN tbl_partner.coop_list_yn IS '협력업체 리스트 등록여부 Y/N — HA-INV-13';

-- ------------------------------------------------------------
-- 5. 설비 마스터 보강 + 이력 디테일
-- ------------------------------------------------------------
ALTER TABLE tbl_equipment ADD COLUMN IF NOT EXISTS equip_kind varchar(50) NULL;
ALTER TABLE tbl_equipment ADD COLUMN IF NOT EXISTS purpose_nm varchar(200) NULL;
ALTER TABLE tbl_equipment ADD COLUMN IF NOT EXISTS install_dt varchar(8) NULL;
ALTER TABLE tbl_equipment ADD COLUMN IF NOT EXISTS as_mng_nm varchar(50) NULL;
COMMENT ON COLUMN tbl_equipment.equip_kind  IS '설비 종류';
COMMENT ON COLUMN tbl_equipment.purpose_nm  IS '용도';
COMMENT ON COLUMN tbl_equipment.install_dt  IS '설치연월일 YYYYMMDD';
COMMENT ON COLUMN tbl_equipment.as_mng_nm   IS 'A/S 담당자';

CREATE TABLE IF NOT EXISTS tbl_equipment_hist (
    idx            bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd          varchar(10)  NOT NULL,
    equip_idx      bigint       NOT NULL,
    hist_dt        varchar(8)   NOT NULL,
    fault_rmk      text         NULL,
    action_rmk     text         NULL,
    doc_idx        bigint       NULL,
    remark         varchar(500) NULL,
    ins_id         varchar(20)  NULL,
    ins_dt         timestamp    NULL DEFAULT now(),
    upd_id         varchar(20)  NULL,
    upd_dt         timestamp    NULL
);
CREATE INDEX IF NOT EXISTS ix_tbl_equipment_hist_equip ON tbl_equipment_hist (co_cd, equip_idx, hist_dt DESC);
COMMENT ON TABLE  tbl_equipment_hist IS '설비 고장이력·조치 — 설비이력기록부 디테일 (HA-FAC-08)';
COMMENT ON COLUMN tbl_equipment_hist.fault_rmk  IS '고장이력';
COMMENT ON COLUMN tbl_equipment_hist.action_rmk IS '조치·개선이력';
COMMENT ON COLUMN tbl_equipment_hist.doc_idx    IS '결재 연동 문서 idx — tbl_document';

UPDATE tbl_template SET
    doc_kind = 'DB',
    scrn_cd  = 'equipment-history',
    mng_no   = 'HA-FAC-08',
    upd_id   = 'system',
    upd_dt   = now()
 WHERE tmpl_cd = 'EQUIP_CARD';

UPDATE tbl_screen SET tmpl_cd = 'EQUIP_CARD', module_cd = 'WRK', use_yn = 'Y',
    scrn_nm = '설비이력기록부', upd_id = 'system', upd_dt = now()
 WHERE scrn_cd = 'equipment-history';

-- ------------------------------------------------------------
-- 6. 냉장 행 — 수동적부·서명·작성자 (온도 셀과 병행)
-- ------------------------------------------------------------
ALTER TABLE tbl_ccp_cold_monitor_row ADD COLUMN IF NOT EXISTS judge_cd varchar(1) NULL;
ALTER TABLE tbl_ccp_cold_monitor_row ADD COLUMN IF NOT EXISTS sign_path varchar(300) NULL;
ALTER TABLE tbl_ccp_cold_monitor_row ADD COLUMN IF NOT EXISTS writer_id varchar(20) NULL;
ALTER TABLE tbl_ccp_cold_monitor_row ADD COLUMN IF NOT EXISTS writer_nm varchar(50) NULL;
COMMENT ON COLUMN tbl_ccp_cold_monitor_row.judge_cd  IS '수동 적부 — O/X';
COMMENT ON COLUMN tbl_ccp_cold_monitor_row.sign_path IS '행 서명 이미지 경로';
COMMENT ON COLUMN tbl_ccp_cold_monitor_row.writer_id IS '작성자 로그인 ID';
COMMENT ON COLUMN tbl_ccp_cold_monitor_row.writer_nm IS '작성자명';

-- ------------------------------------------------------------
-- 7. 금속검출 — 위치(비고)
-- ------------------------------------------------------------
ALTER TABLE tbl_ccp_metal_sens_row ADD COLUMN IF NOT EXISTS place_nm varchar(100) NULL;
COMMENT ON COLUMN tbl_ccp_metal_sens_row.place_nm IS '위치(비고)';

-- ------------------------------------------------------------
-- 8. CCP검증 — 모니터링 일지 확인 SPAN
-- ------------------------------------------------------------
ALTER TABLE tbl_ccp_verify_check ADD COLUMN IF NOT EXISTS monitor_chk_rmk text NULL;
COMMENT ON COLUMN tbl_ccp_verify_check.monitor_chk_rmk IS '모니터링 일지 확인 — SPAN 입력';

-- ------------------------------------------------------------
-- 9. generic CCP 행 — 설비·품목·서명·상태
-- ------------------------------------------------------------
ALTER TABLE tbl_ccp_generic_monitor_row ADD COLUMN IF NOT EXISTS equip_nm varchar(100) NULL;
ALTER TABLE tbl_ccp_generic_monitor_row ADD COLUMN IF NOT EXISTS product_nm varchar(100) NULL;
ALTER TABLE tbl_ccp_generic_monitor_row ADD COLUMN IF NOT EXISTS phase_cd varchar(20) NULL;
ALTER TABLE tbl_ccp_generic_monitor_row ADD COLUMN IF NOT EXISTS judge_cd varchar(1) NULL;
ALTER TABLE tbl_ccp_generic_monitor_row ADD COLUMN IF NOT EXISTS sign_path varchar(300) NULL;
ALTER TABLE tbl_ccp_generic_monitor_row ADD COLUMN IF NOT EXISTS checker_nm varchar(50) NULL;

-- ------------------------------------------------------------
-- 10. 시설점검 항목 — 위치·이탈시조치 (check_item 확장 대신 업무행)
-- ------------------------------------------------------------
ALTER TABLE tbl_facility_check_item ADD COLUMN IF NOT EXISTS place_nm varchar(100) NULL;
ALTER TABLE tbl_facility_check_item ADD COLUMN IF NOT EXISTS action_rmk varchar(500) NULL;
