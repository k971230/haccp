-- ============================================================
--  133_migrate_table_archive.sql — 안 쓰는 테이블 격리
--
--  파일번호: 133
--  이전번호: 132
--  개발자: 박승우
--  일자: 2026-08-25
--  코멘트:
--    1) 132 에서 SP 를 정리한 뒤, 남은 SP·매퍼 XML 어디서도 참조하지 않는 표만 골랐다
--    2) DROP 하지 않고 백업 스키마로 옮긴다 — sasshaccp 에서는 사라지고 되돌리기는 한 줄이다
--    3) 화면·SP 를 모두 지운 뒤라 이 표들은 읽는 코드가 없다
--
--  되돌리기: ALTER TABLE bak_20260825.<표> SET SCHEMA sasshaccp;
--  최종 삭제: DROP SCHEMA bak_20260825 CASCADE;   (E2E 통과 확인 뒤)
--
--  실행: psql -f 133_migrate_table_archive.sql (수동·DBeaver)
-- ============================================================

SET search_path TO sasshaccp;

BEGIN;

CREATE SCHEMA IF NOT EXISTS bak_20260825;
COMMENT ON SCHEMA bak_20260825 IS '2026-08-25 화면 정리에서 빠진 표 보관 — 확인 뒤 DROP SCHEMA CASCADE';

ALTER TABLE IF EXISTS tbl_area_hygiene_item SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_area_hygiene_result SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_area_hygiene_signer SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_ccp_cold_monitor_row SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_company_check_item SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_company_form SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_company_form_item SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_company_setting SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_daily_hygiene SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_daily_hygiene_item SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_equipment SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_equipment_hist SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_facility_check SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_facility_check_item SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_health_cert SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_inv_check SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_personal_hygiene SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_personal_hygiene_row SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_pest_device_hist SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_process_check SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_process_check_item SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_process_check_result SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_process_check_signer SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_recv_inspect_item SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_smart_diary_map SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_smart_diary_type SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_template_export_hist SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_verify_plan SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_verify_plan_item SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_verify_plan_month SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_waste_check SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_waste_check_row SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_water_check SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_water_check_checker SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_water_check_item SET SCHEMA bak_20260825;
ALTER TABLE IF EXISTS tbl_water_check_result SET SCHEMA bak_20260825;

COMMIT;

-- 확인용
-- SELECT count(*) FROM information_schema.tables WHERE table_schema='sasshaccp' AND table_type='BASE TABLE';
-- SELECT table_name FROM information_schema.tables WHERE table_schema='bak_20260825' ORDER BY 1;
