-- ============================================================
-- 91 — src-ty 공통코드 문구를 양식구분(시스템/사용자)으로 맞춘다
--
-- 파일번호: 91
-- 이전번호: 90
-- 개발자: 박승우
-- 일자: 2026-08-18
-- 코멘트:
--   1) 불러오기 팝업 양식구분 열·콤보가 공통코드 src-ty 를 쓴다
--   2) 값은 sys/usr 그대로다. 문구만 기본양식/사용자양식 → 시스템/사용자
--   3) 대분류 헤더는 양식구분. 개발 테넌트 0000 포함 전 co_cd 를 갱신한다
--
-- Jenkins는 migrate를 안 돌리므로 적용은 DBeaver/수동
-- ============================================================

SET search_path TO sasshaccp;

UPDATE tbl_code
   SET code_nm = CASE sub_cd
                   WHEN '*'   THEN '양식구분'
                   WHEN 'sys' THEN '시스템'
                   WHEN 'usr' THEN '사용자'
                   ELSE code_nm
                 END,
       upd_id  = 'system',
       upd_dt  = now()
 WHERE main_cd = 'src-ty'
   AND sub_cd IN ('*', 'sys', 'usr');

SELECT co_cd, sub_cd, code_nm
  FROM tbl_code
 WHERE main_cd = 'src-ty'
 ORDER BY co_cd, sort_no, sub_cd;
