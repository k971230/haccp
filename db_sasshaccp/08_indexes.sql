-- ============================================================
--  DDL 8 — 인덱스
--
--  개발자: 박승우
--  일자: 2026-08-05
--  코멘트:
--    1) UNIQUE 제약(ux_*)이 이미 인덱스를 만들므로 여기서는 중복 생성하지 않는다
--    2) 만드는 기준은 세 가지뿐이다 — 테넌트+일자 검색, 부모 idx 조인(FK 없음), 상태별 대시보드 조회
--    3) 조기 최적화 금지 — 실제 느린 쿼리가 확인되면 그때 추가한다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 인증·플랫폼
-- ------------------------------------------------------------
-- 사용자 목록 조회 — 회사별 전체 사용자
CREATE INDEX IF NOT EXISTS ix_tbl_user_co        ON tbl_user (co_cd, use_yn);
-- 메뉴 트리 로딩 — 회사별 전체 메뉴를 한 번에 읽는다
CREATE INDEX IF NOT EXISTS ix_tbl_menu_co        ON tbl_menu (co_cd, use_yn, sort_no);
-- 권한 조회 — 로그인 직후 권한그룹의 화면 권한 전체를 읽는다
CREATE INDEX IF NOT EXISTS ix_tbl_role_screen_grp ON tbl_role_screen (co_cd, usrgrp_cd);
-- 공통코드 조회 — 대분류 단위로 세부코드를 읽는다
CREATE INDEX IF NOT EXISTS ix_tbl_code_main      ON tbl_code (co_cd, main_cd, use_yn, sort_no);

-- ------------------------------------------------------------
-- 로그·통계
-- ------------------------------------------------------------
-- 로그인 이력 조회 — 사용자별 최근 순
CREATE INDEX IF NOT EXISTS ix_tbl_login_log_user ON tbl_login_log (user_id, login_dt DESC);
-- 로그인 이력 조회 — 회사별 기간 조회
CREATE INDEX IF NOT EXISTS ix_tbl_login_log_co   ON tbl_login_log (co_cd, login_dt DESC);
-- UV/PV 일 집계 배치 — 전일 원시 이벤트를 회사·화면·일자로 훑는다
CREATE INDEX IF NOT EXISTS ix_tbl_view_log_agg   ON tbl_view_log (co_cd, enter_dt, scrn_cd);
-- 세션 추적 — 특정 세션의 화면 이동 경로 재구성
CREATE INDEX IF NOT EXISTS ix_tbl_view_log_sid   ON tbl_view_log (sid, enter_dt);
-- 통계 화면 — 회사·기간 범위 조회
CREATE INDEX IF NOT EXISTS ix_tbl_view_stat_dt   ON tbl_view_stat_daily (co_cd, stat_dt DESC);
-- 감사 로그 조회 — 특정 행의 변경 이력 추적
CREATE INDEX IF NOT EXISTS ix_tbl_audit_log_tgt  ON tbl_audit_log (co_cd, tbl_nm, tgt_idx, ins_dt DESC);

-- ------------------------------------------------------------
-- 문서 허브
-- ------------------------------------------------------------
-- 문서 목록 조회 — 회사·템플릿·기준일자 (가장 빈번한 조회 패턴)
CREATE INDEX IF NOT EXISTS ix_tbl_document_search ON tbl_document (co_cd, tmpl_cd, base_dt DESC);
-- 결재 대기함 — 회사·상태별
CREATE INDEX IF NOT EXISTS ix_tbl_document_status ON tbl_document (co_cd, status, base_dt DESC);
-- 내 문서함 — 작성자별
CREATE INDEX IF NOT EXISTS ix_tbl_document_writer ON tbl_document (co_cd, writer_id, base_dt DESC);
-- 보존기간 만료 배치 — 만료일 경과 문서 탐색
CREATE INDEX IF NOT EXISTS ix_tbl_document_retain ON tbl_document (co_cd, retention_until);
-- 결재 이력 조회 — 문서 단위
CREATE INDEX IF NOT EXISTS ix_tbl_document_approval_doc ON tbl_document_approval (doc_idx, step_no);
-- 내 결재 대기 목록 — 결재자·결과별
CREATE INDEX IF NOT EXISTS ix_tbl_document_approval_usr ON tbl_document_approval (co_cd, approver_id, result_cd);
-- 첨부 조회 — 문서 단위
CREATE INDEX IF NOT EXISTS ix_tbl_document_file_doc     ON tbl_document_file (doc_idx, file_kind);
-- 역방향 관계 조회 — 도착 문서에서 출발 문서를 찾는다
CREATE INDEX IF NOT EXISTS ix_tbl_document_relation_tgt ON tbl_document_relation (tgt_doc_idx, rel_type);
-- 오늘 할 일 — 회사·일자·상태
CREATE INDEX IF NOT EXISTS ix_tbl_schedule_task_due     ON tbl_schedule_task (co_cd, due_dt, status);
-- 내 할 일 — 담당자별
CREATE INDEX IF NOT EXISTS ix_tbl_schedule_task_user    ON tbl_schedule_task (co_cd, user_id, status);
-- 미조치 개선조치 대시보드 — 회사·상태·기한
CREATE INDEX IF NOT EXISTS ix_tbl_corrective_action_st  ON tbl_corrective_action (co_cd, status, due_dt);
-- 출처 문서에서 개선조치 역추적
CREATE INDEX IF NOT EXISTS ix_tbl_corrective_action_src ON tbl_corrective_action (src_doc_idx);
-- 안 읽은 알림 — 수신자별
CREATE INDEX IF NOT EXISTS ix_tbl_notification_user     ON tbl_notification (co_cd, user_id, read_yn, ins_dt DESC);

-- ------------------------------------------------------------
-- 기준정보 — 콤보·피커 조회용 (회사 + 사용여부)
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS ix_tbl_product_co   ON tbl_product   (co_cd, use_yn);
CREATE INDEX IF NOT EXISTS ix_tbl_material_co  ON tbl_material  (co_cd, use_yn, material_gbn);
CREATE INDEX IF NOT EXISTS ix_tbl_partner_co   ON tbl_partner   (co_cd, use_yn, partner_gbn);
CREATE INDEX IF NOT EXISTS ix_tbl_storage_co   ON tbl_storage   (co_cd, use_yn, sort_no);
CREATE INDEX IF NOT EXISTS ix_tbl_equipment_co ON tbl_equipment (co_cd, use_yn);
CREATE INDEX IF NOT EXISTS ix_tbl_measuring_device_co ON tbl_measuring_device (co_cd, use_yn, sort_no);
CREATE INDEX IF NOT EXISTS ix_tbl_pest_device_co      ON tbl_pest_device      (co_cd, use_yn, sort_no);
CREATE INDEX IF NOT EXISTS ix_tbl_vehicle_co          ON tbl_vehicle          (co_cd, use_yn);
CREATE INDEX IF NOT EXISTS ix_tbl_work_area_co        ON tbl_work_area        (co_cd, use_yn, sort_no);
-- 검·교정 도래 알림 배치 — 예정일 경과 계측기 탐색
CREATE INDEX IF NOT EXISTS ix_tbl_calib_target_row_next ON tbl_calib_target_row (co_cd, next_calib_dt);

-- ------------------------------------------------------------
-- 업무 테이블 — 부모 idx 조인 (FK 제약이 없으므로 인덱스는 필수)
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS ix_tbl_ccp_cold_monitor_row_hdr  ON tbl_ccp_cold_monitor_row  (hdr_idx);
CREATE INDEX IF NOT EXISTS ix_tbl_ccp_cold_monitor_temp_row ON tbl_ccp_cold_monitor_temp (row_idx);
CREATE INDEX IF NOT EXISTS ix_tbl_ccp_metal_sens_row_hdr    ON tbl_ccp_metal_sens_row    (hdr_idx);
CREATE INDEX IF NOT EXISTS ix_tbl_ccp_metal_pass_row_hdr    ON tbl_ccp_metal_pass_row    (hdr_idx);
CREATE INDEX IF NOT EXISTS ix_tbl_ccp_verify_item_hdr       ON tbl_ccp_verify_item       (hdr_idx);
CREATE INDEX IF NOT EXISTS ix_tbl_verify_plan_item_hdr      ON tbl_verify_plan_item      (hdr_idx);
CREATE INDEX IF NOT EXISTS ix_tbl_verify_plan_month_item    ON tbl_verify_plan_month     (item_idx);
CREATE INDEX IF NOT EXISTS ix_tbl_daily_hygiene_item_hdr    ON tbl_daily_hygiene_item    (hdr_idx);
CREATE INDEX IF NOT EXISTS ix_tbl_personal_hygiene_row_hdr  ON tbl_personal_hygiene_row  (hdr_idx);
CREATE INDEX IF NOT EXISTS ix_tbl_area_hygiene_item_hdr     ON tbl_area_hygiene_item     (hdr_idx);
CREATE INDEX IF NOT EXISTS ix_tbl_area_hygiene_result_item  ON tbl_area_hygiene_result   (item_idx);
CREATE INDEX IF NOT EXISTS ix_tbl_area_hygiene_signer_hdr   ON tbl_area_hygiene_signer   (hdr_idx);
CREATE INDEX IF NOT EXISTS ix_tbl_pest_check_row_hdr        ON tbl_pest_check_row        (hdr_idx);
CREATE INDEX IF NOT EXISTS ix_tbl_water_check_item_hdr      ON tbl_water_check_item      (hdr_idx);
CREATE INDEX IF NOT EXISTS ix_tbl_water_check_result_item   ON tbl_water_check_result    (item_idx);
CREATE INDEX IF NOT EXISTS ix_tbl_water_check_checker_hdr   ON tbl_water_check_checker   (hdr_idx);
CREATE INDEX IF NOT EXISTS ix_tbl_facility_check_item_hdr   ON tbl_facility_check_item   (hdr_idx);
CREATE INDEX IF NOT EXISTS ix_tbl_calib_target_row_hdr      ON tbl_calib_target_row      (hdr_idx);
CREATE INDEX IF NOT EXISTS ix_tbl_waste_check_row_hdr       ON tbl_waste_check_row       (hdr_idx);
CREATE INDEX IF NOT EXISTS ix_tbl_recv_inspect_item_hdr     ON tbl_recv_inspect_item     (hdr_idx);
CREATE INDEX IF NOT EXISTS ix_tbl_process_check_item_hdr    ON tbl_process_check_item    (hdr_idx);
CREATE INDEX IF NOT EXISTS ix_tbl_process_check_result_item ON tbl_process_check_result  (item_idx);
CREATE INDEX IF NOT EXISTS ix_tbl_process_check_signer_hdr  ON tbl_process_check_signer  (hdr_idx);

-- 수불 이력 조회 — 회사·일자 범위 (월별 재고 점검표의 기본 조회)
CREATE INDEX IF NOT EXISTS ix_tbl_inv_txn_dt   ON tbl_inv_txn (co_cd, txn_dt DESC);
-- 로트 추적 — 회수 시 특정 로트의 입출고 전체 경로
CREATE INDEX IF NOT EXISTS ix_tbl_inv_txn_lot  ON tbl_inv_txn (co_cd, lot_no);
-- 소비기한 임박 알림 배치
CREATE INDEX IF NOT EXISTS ix_tbl_inv_txn_exp  ON tbl_inv_txn (co_cd, expire_dt);
