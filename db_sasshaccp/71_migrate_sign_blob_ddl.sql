-- ============================================================
--  migrate 71 — 서명 이미지 저장 방식을 파일 경로에서 DB BLOB(bytea)로 전환 (DDL)
--
--  개발자: 박승우
--  일자: 2026-08-12
--  코멘트:
--    1) sign_path(varchar) 옆에 sign_img(bytea)를 새로 달기만 한다
--       기존 컬럼은 80(최종 DROP)까지 남겨 회귀 실패 시 되돌릴 수 있게 한다
--    2) 사용자 마스터(tbl_user)가 서명 원본이고, 결재·CCP 행은 그 시점 스냅샷을 복사해 보관한다
--       스냅샷 복사 로직은 78에서 각 저장 SP에 넣는다
--    3) 기존 서명 실물 이관은 71b(생성 파일)에서 base64로 넣는다 — DB가 원격이라 서버 파일 읽기 불가
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 사용자 마스터 — 서명 원본
--    sign_mime: 응답 Content-Type. sign_nm: 다운로드 파일명
-- ------------------------------------------------------------
ALTER TABLE tbl_user
    ADD COLUMN IF NOT EXISTS sign_img  bytea        NULL,
    ADD COLUMN IF NOT EXISTS sign_mime varchar(50)  NULL,
    ADD COLUMN IF NOT EXISTS sign_nm   varchar(255) NULL;
COMMENT ON COLUMN tbl_user.sign_img  IS '서명 이미지 바이너리 — PNG/JPG 원본. 결재·점검자 서명란에 삽입';
COMMENT ON COLUMN tbl_user.sign_mime IS '서명 이미지 MIME — image/png 또는 image/jpeg';
COMMENT ON COLUMN tbl_user.sign_nm   IS '서명 이미지 원본 파일명 — 다운로드 시 Content-Disposition에 사용';

-- ------------------------------------------------------------
-- 2. 결재 이력 — 결재 시점 서명 스냅샷
--    사용자가 나중에 서명을 바꿔도 과거 결재 문서의 서명은 그대로 남아야 한다
-- ------------------------------------------------------------
ALTER TABLE tbl_document_approval
    ADD COLUMN IF NOT EXISTS sign_img bytea NULL;
COMMENT ON COLUMN tbl_document_approval.sign_img IS '서명 이미지 바이너리 — 결재 시점 tbl_user.sign_img 스냅샷';

-- ------------------------------------------------------------
-- 3. CCP 모니터링 행 — 행 서명 스냅샷 (냉장·범용)
-- ------------------------------------------------------------
ALTER TABLE tbl_ccp_cold_monitor_row
    ADD COLUMN IF NOT EXISTS sign_img bytea NULL;
COMMENT ON COLUMN tbl_ccp_cold_monitor_row.sign_img IS '행 서명 이미지 바이너리 — 서명 적용 시점 tbl_user.sign_img 스냅샷';

ALTER TABLE tbl_ccp_generic_monitor_row
    ADD COLUMN IF NOT EXISTS sign_img bytea NULL;
COMMENT ON COLUMN tbl_ccp_generic_monitor_row.sign_img IS '행 서명 이미지 바이너리 — 서명 적용 시점 tbl_user.sign_img 스냅샷';

-- ------------------------------------------------------------
-- 4. 검증 — 컬럼 추가 결과
-- ------------------------------------------------------------
SELECT table_name, column_name, data_type
  FROM information_schema.columns
 WHERE table_schema = 'sasshaccp'
   AND column_name IN ('sign_img', 'sign_mime', 'sign_nm')
 ORDER BY table_name, column_name;
