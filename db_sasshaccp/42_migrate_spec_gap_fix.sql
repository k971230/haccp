-- ============================================================
-- 42 — 명세 갭 보완 (일일위생 grp_nm · 시설점검 주1회)
--
-- 개발자: 박승우
-- 일자: 2026-08-07
-- 코멘트:
--   1) 일일위생 항목에 구분 문구(grp_nm) 스냅샷 컬럼을 추가한다
--   2) tmpl_prp-facility-check 기본 주기를 주1회(W / 주1회)로 맞춘다
--   3) 기존 문서 행의 grp_nm은 표준 항목에서 한 번 채운다
-- ============================================================

SET search_path TO sasshaccp;

-- 일일위생 구분 문구 스냅샷
ALTER TABLE tbl_daily_hygiene_item
    ADD COLUMN IF NOT EXISTS grp_nm varchar(100) NULL;
COMMENT ON COLUMN tbl_daily_hygiene_item.grp_nm IS '구분 문구 스냅샷 — FE에서 편집 가능. 비어 있으면 grp_cd/표준 grp_nm 표시';

-- 기존 행 보정 — 표준 점검항목 grp_nm으로 채움
UPDATE tbl_daily_hygiene_item i
   SET grp_nm = ci.grp_nm
  FROM tbl_check_item ci
 WHERE ci.tmpl_cd = 'tmpl_prp-hygiene-daily'
   AND ci.item_cd = i.item_cd
   AND (i.grp_nm IS NULL OR i.grp_nm = '');

-- tmpl_prp-facility-check 템플릿 기본 주기 — 주1회
UPDATE tbl_template
   SET default_cycle_cd = 'W',
       upd_id = 'system',
       upd_dt = now()
 WHERE tmpl_cd = 'tmpl_prp-facility-check'
   AND coalesce(default_cycle_cd, '') <> 'W';

UPDATE tbl_company_template
   SET cycle_cd = 'W',
       upd_id = 'system',
       upd_dt = now()
 WHERE tmpl_cd = 'tmpl_prp-facility-check'
   AND coalesce(cycle_cd, '') <> 'W';

-- 표준 점검항목 주기 문구
UPDATE tbl_check_item
   SET cycle_nm = '주1회',
       upd_id = 'system',
       upd_dt = now()
 WHERE tmpl_cd = 'tmpl_prp-facility-check'
   AND coalesce(cycle_nm, '') <> '주1회';
