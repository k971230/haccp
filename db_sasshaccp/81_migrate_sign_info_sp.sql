-- ============================================================
-- 81_migrate_sign_info_sp.sql
--   서명 메타데이터 조회 SP 신규 — 바이너리를 읽지 않고 보유여부·파일명만 본다
--
-- 개발자: 박승우
-- 일자: 2026-08-12
-- 코멘트:
--   1) 서명 "있는지"만 알고 싶은 경로(CCP 행 서명, 서명 삭제 전 검사)가 16KB 바이너리를 통째로
--      내려받던 것을 없앤다. 실물은 미리보기·클립보드 복사처럼 이미지가 실제로 필요할 때만 읽는다
--   2) sign_img IS NOT NULL은 TOAST 본문을 펼치지 않으므로 큰 이미지가 늘어도 비용이 변하지 않는다
--   3) 재실행 안전 — DROP IF EXISTS 후 CREATE
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- sp_user_management_sign_info_r_000 — 서명 보유여부·파일명·MIME
--   sign_r_000과 대상은 같지만 bytea를 SELECT 목록에 넣지 않는다
--   타 테넌트·없는 아이디면 0행 — 백엔드가 미등록과 같은 문구로 처리한다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_user_management_sign_info_r_000(varchar, varchar);
CREATE FUNCTION sp_user_management_sign_info_r_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위
    p_co_cd   varchar,
    -- p_user_id: 서명 보유여부를 볼 대상 로그인 아이디 (정확 일치)
    p_user_id varchar
)
RETURNS TABLE(
    sign_yn   varchar,
    sign_nm   varchar,
    sign_mime varchar
) LANGUAGE sql AS $$
    SELECT
           -- 보유여부 — NULL 검사만 하므로 바이너리 본문을 읽지 않는다
           (CASE WHEN u.sign_img IS NOT NULL THEN 'Y' ELSE 'N' END)::varchar,
           -- 파일명 — 미등록이면 빈 문자열. 화면은 이 값으로도 유무를 판단할 수 있다
           (CASE WHEN u.sign_img IS NOT NULL THEN COALESCE(u.sign_nm, 'sign.png') ELSE '' END)::varchar,
           -- MIME — 미등록이면 빈 문자열, 구 데이터로 비어 있으면 PNG로 본다
           (CASE WHEN u.sign_img IS NOT NULL THEN COALESCE(u.sign_mime, 'image/png') ELSE '' END)::varchar
      FROM tbl_user u
     WHERE u.co_cd = p_co_cd
       AND u.user_id = p_user_id;
$$;
COMMENT ON FUNCTION sp_user_management_sign_info_r_000(varchar, varchar) IS
  '사용자 서명 메타데이터 — 보유여부·파일명·MIME만. 바이너리를 읽지 않는다';
