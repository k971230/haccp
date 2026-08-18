-- ============================================================
-- 92 — sys-yn 공통코드 문구를 시스템제공/사용자추가로 맞춘다
--
-- 파일번호: 92
-- 이전번호: 91
-- 개발자: 박승우
-- 일자: 2026-08-18
-- 코멘트:
--   1) 사용양식·문서주기 왼쪽 목록 구분 열이 공통코드 sys-yn 을 쓴다
--   2) 값은 sys/usr 그대로다. 문구만 시스템/사용자 → 시스템제공/사용자추가
--   3) 대분류 헤더는 구분(열 헤더와 맞춤). 불러오기 팝업 src-ty 와 섞지 않는다
--
-- Jenkins는 migrate를 안 돌리므로 적용은 DBeaver/수동
-- ============================================================

SET search_path TO sasshaccp;

UPDATE tbl_code
   SET code_nm = CASE sub_cd
                   WHEN '*'   THEN '구분'
                   WHEN 'sys' THEN '시스템제공'
                   WHEN 'usr' THEN '사용자추가'
                   ELSE code_nm
                 END,
       upd_id  = 'system',
       upd_dt  = now()
 WHERE main_cd = 'sys-yn'
   AND sub_cd IN ('*', 'sys', 'usr');

SELECT co_cd, sub_cd, code_nm
  FROM tbl_code
 WHERE main_cd = 'sys-yn'
 ORDER BY co_cd, sort_no, sub_cd;
