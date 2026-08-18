-- ============================================================
-- 88 — 파일 이력 출처 공통코드 src-ty
--
-- 파일번호: 88
-- 이전번호: 87
-- 개발자: 박승우
-- 일자: 2026-08-18
-- 코멘트:
--   1) 사용양식 불러오기 팝업 구분 콤보·그리드 라벨용 플랫폼 코드를 넣는다
--   2) sys-yn(시스템/사용자)과 값은 sys/usr 로 같지만 문구가 다르다 — 기본양식/사용자양식
--   3) 재실행 안전 — ux_tbl_code(co_cd, main_cd, sub_cd) ON CONFLICT
--
-- 선행: 없음 (tbl_code 만)
-- Jenkins는 migrate를 안 돌리므로 적용은 DBeaver/수동
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 플랫폼 표준코드 — 불러오기 팝업 구분(기본양식/사용자양식)
--    sys_yn=Y 시스템코드. 업체는 코드명만 바꿀 수 있다
-- ------------------------------------------------------------
INSERT INTO tbl_code (co_cd, main_cd, sub_cd, code_nm, sort_no, ref1, sys_yn, ins_id) VALUES
  ('0000', 'src-ty', '*',   '양식출처',   0, NULL, 'Y', 'system'),
  ('0000', 'src-ty', 'sys', '기본양식',   1, NULL, 'Y', 'system'),
  ('0000', 'src-ty', 'usr', '사용자양식', 2, NULL, 'Y', 'system')
ON CONFLICT (co_cd, main_cd, sub_cd) DO UPDATE SET
  code_nm = EXCLUDED.code_nm,
  sort_no = EXCLUDED.sort_no,
  use_yn  = 'Y',
  upd_id  = 'system',
  upd_dt  = now();
