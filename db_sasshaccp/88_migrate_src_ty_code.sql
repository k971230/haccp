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
--   3) 콤보는 co_cd 완전 고유(0000 병합 없음)라 0000만 넣으면 업체의 콤보가 비다.
--      82와 같이 전 업체로 미보유분을 복제한다. 재실행 안전
--
-- 선행: 70(표준코드 업체 복제) · sp_tbl_company_code_copy_c_000
-- Jenkins는 migrate를 안 돌리므로 적용은 DBeaver/수동
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 플랫폼 원본 — 불러오기 팝업 구분(기본양식/사용자양식)
--    sys_yn=Y 시스템코드. 업체는 코드명만 바꿀 수 있다
-- ------------------------------------------------------------
INSERT INTO tbl_code (co_cd, main_cd, sub_cd, code_nm, sort_no, ref1, sys_yn, use_yn, ins_id) VALUES
  ('0000', 'src-ty', '*',   '양식출처',   0, NULL, 'Y', 'Y', 'system'),
  ('0000', 'src-ty', 'sys', '기본양식',   1, NULL, 'Y', 'Y', 'system'),
  ('0000', 'src-ty', 'usr', '사용자양식', 2, NULL, 'Y', 'Y', 'system')
ON CONFLICT (co_cd, main_cd, sub_cd) DO UPDATE SET
  code_nm = EXCLUDED.code_nm,
  sort_no = EXCLUDED.sort_no,
  use_yn  = 'Y',
  upd_id  = 'system',
  upd_dt  = now();

-- ------------------------------------------------------------
-- 2. 사용 중인 전 업체로 미보유분 복제 — 0000은 원본이라 대상에서 뺀다
--    이미 가진 (main_cd, sub_cd)는 건드리지 않는다
-- ------------------------------------------------------------
DO $$
DECLARE
    v_co record;
BEGIN
    FOR v_co IN
        SELECT co_cd FROM tbl_company WHERE co_cd <> '0000' ORDER BY co_cd
    LOOP
        CALL sp_tbl_company_code_copy_c_000(v_co.co_cd, 'system');
        RAISE NOTICE 'src-ty 복제 완료 — co_cd=%', v_co.co_cd;
    END LOOP;
END$$;

-- ------------------------------------------------------------
-- 3. 검증 — 업체마다 헤더(*) 포함 3건이어야 콤보가 채워진다
-- ------------------------------------------------------------
SELECT co_cd, count(*) AS src_ty_cnt
  FROM tbl_code
 WHERE main_cd = 'src-ty'
 GROUP BY co_cd
 ORDER BY co_cd;
