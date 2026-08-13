-- ============================================================
--  migrate 76 — 사용자 관리 화면 SP를 화면명 규약으로 신규 작성 (v2)
--
--  개발자: 박승우
--  일자: 2026-08-12
--  코멘트:
--    1) 목록에는 비밀번호 해시를 절대 싣지 않는다 — 해시는 로그인 SP만 읽는다
--    2) 서명은 파일 경로(sign_path)에서 DB BLOB(sign_img bytea)로 바뀐다
--       목록은 sign_yn만 파생해 내리고, 실물 바이너리는 sign_r_000 단건 조회로만 나간다
--       저장 c_000에서는 서명 파라미터를 아예 받지 않는다 — 서명 변경 경로는 sign_u_000 하나뿐이다
--    3) 사용자 삭제는 문서·기록 이력을 남기고 개인 설정(알림·그리드)만 정리한다 — 참조 차단 사유는 없다
--    4) 화면 단위 SP는 sp_{화면명}_{r|c|d|u}_{nnn} 규약을 따른다 — sp_tbl_ 접두를 쓰지 않는다
--    5) 생성 전용 — 구 sp_tbl_user_mgmt_* DROP은 80에서 수행
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. sp_user_management_r_000 — 사용자 목록
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_user_management_r_000(varchar, varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_user_management_r_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위. 필수 등가 조건
    p_co_cd   varchar,
    -- p_user_id: 페이지 헤더 아이디 검색어. 공백이면 전체
    p_user_id varchar,
    -- p_user_nm: 페이지 헤더 이름 검색어. 공백이면 전체
    p_user_nm varchar,
    -- p_dept_cd: 좌측 부서 트리 선택값. 공백이면 전체 부서
    p_dept_cd varchar,
    -- p_use_yn: 페이지 헤더 사용여부. 공백이면 Y·N 모두
    p_use_yn  varchar
)
RETURNS TABLE(
    idx            bigint,
    user_id        varchar,
    co_cd          varchar,
    emp_cd         varchar,
    user_nm        varchar,
    usrgrp_cd      varchar,
    usrgrp_nm      varchar,
    dept_cd        varchar,
    dept_nm        varchar,
    email          varchar,
    mobile         varchar,
    sign_yn        varchar,
    gridsave_yn    varchar,
    last_login_dt  timestamp,
    login_fail_cnt int,
    lock_yn        varchar,
    use_yn         varchar
) LANGUAGE sql AS $$
    SELECT u.idx, u.user_id, u.co_cd, u.emp_cd, u.user_nm,
           u.usrgrp_cd, r.usrgrp_nm, u.dept_cd, d.dept_nm,
           u.email, u.mobile,
           -- 서명 보유여부만 내린다 — 16KB급 바이너리를 목록에 실으면 그리드가 무거워진다
           (CASE WHEN u.sign_img IS NOT NULL THEN 'Y' ELSE 'N' END)::varchar,
           u.gridsave_yn,
           u.last_login_dt, u.login_fail_cnt, u.lock_yn, u.use_yn
      FROM tbl_user u
      -- 권한그룹명 — 그리드 표시 전용
      LEFT JOIN tbl_role r ON r.co_cd = u.co_cd AND r.usrgrp_cd = u.usrgrp_cd
      -- 부서명 — 그리드 표시 전용
      LEFT JOIN tbl_dept d ON d.co_cd = u.co_cd AND d.dept_cd   = u.dept_cd
     WHERE u.co_cd = p_co_cd
       AND u.user_id LIKE CONCAT('%', COALESCE(p_user_id, ''), '%')
       AND u.user_nm LIKE CONCAT('%', COALESCE(p_user_nm, ''), '%')
       AND COALESCE(u.dept_cd, '') LIKE CONCAT('%', COALESCE(p_dept_cd, ''), '%')
       AND u.use_yn  LIKE CONCAT('%', COALESCE(p_use_yn,  ''), '%')
     ORDER BY u.user_id;
$$;
COMMENT ON FUNCTION sp_user_management_r_000(varchar, varchar, varchar, varchar, varchar) IS
  '사용자 목록 — 비밀번호 해시 제외, 서명은 보유여부(sign_yn)만. 헤더 아이디·이름·부서·사용여부 LIKE';

-- ------------------------------------------------------------
-- 2. sp_user_management_c_000 — 사용자 저장
--    비밀번호는 BCrypt 해시를 백엔드가 만들어 넘긴다. 여기서 평문을 받지 않는다
--    서명은 받지 않는다 — 서명 변경은 sp_user_management_sign_u_000 한 경로로만 한다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_user_management_c_000(
    -- p_co_cd: JWT 회사코드 — 등록 시 소속, 수정 시 테넌트 검증 조건
    p_co_cd     varchar,
    -- p_idx: 수정 대상 대리키. 신규면 NULL
    p_idx       bigint,
    -- p_user_id: 로그인 아이디. 전 업체 통틀어 중복 불가
    p_user_id   varchar,
    -- p_emp_cd: 사번. 미입력 허용
    p_emp_cd    varchar,
    -- p_user_nm: 사용자명
    p_user_nm   varchar,
    -- p_user_pw: BCrypt 비밀번호 해시. 수정 시 공백이면(= 변경 안 함) 기존 값 유지
    p_user_pw   varchar,
    -- p_usrgrp_cd: 권한그룹코드 — tbl_role.usrgrp_cd
    p_usrgrp_cd varchar,
    -- p_dept_cd: 부서코드 — tbl_dept.dept_cd
    p_dept_cd   varchar,
    -- p_email: 알림 발송 주소
    p_email     varchar,
    -- p_mobile: 휴대전화번호
    p_mobile    varchar,
    -- p_lock_yn: 계정 잠금여부. N으로 저장하면 실패횟수도 함께 0으로 되돌린다
    p_lock_yn   varchar,
    -- p_use_yn: 사용여부
    p_use_yn    varchar,
    -- p_id: JWT 작업자 ID — 감사 컬럼
    p_id        varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    -- 아이디 전역 중복 검사 건수
    v_cnt int;
BEGIN
    -- 사용자명·권한그룹이 비면(= 화면이 값을 빠뜨림) 기존 값을 공백으로 덮어써
    -- 해당 계정의 메뉴 권한이 통째로 사라지므로 저장 자체를 막는다
    IF COALESCE(trim(p_user_nm), '') = '' THEN
        RAISE EXCEPTION '사용자명은 필수입니다.' USING ERRCODE = '45000';
    END IF;
    IF COALESCE(trim(p_usrgrp_cd), '') = '' THEN
        RAISE EXCEPTION '권한그룹은 필수입니다.' USING ERRCODE = '45000';
    END IF;

    IF p_idx IS NULL THEN
        -- UNIQUE 제약에 걸리기 전에 업무 문구로 막는다
        SELECT COUNT(*) INTO v_cnt FROM tbl_user WHERE user_id = p_user_id;
        IF v_cnt > 0 THEN
            RAISE EXCEPTION '이미 사용 중인 아이디입니다: %', p_user_id USING ERRCODE = '45000';
        END IF;

        INSERT INTO tbl_user(user_id, co_cd, emp_cd, user_nm, user_pw, usrgrp_cd, dept_cd,
                             email, mobile, lock_yn, use_yn, pw_upd_dt, ins_id, ins_dt)
        VALUES (p_user_id, p_co_cd, NULLIF(p_emp_cd, ''), p_user_nm, p_user_pw, p_usrgrp_cd,
                NULLIF(p_dept_cd, ''), p_email, p_mobile,
                COALESCE(NULLIF(p_lock_yn, ''), 'N'), COALESCE(NULLIF(p_use_yn, ''), 'Y'),
                now(), p_id, now());
    ELSE
        UPDATE tbl_user
           SET emp_cd    = NULLIF(p_emp_cd, ''),
               user_nm   = p_user_nm,
               -- 비밀번호는 값이 있을 때만 교체하고 변경일시를 함께 갱신한다
               user_pw   = COALESCE(NULLIF(p_user_pw, ''), user_pw),
               pw_upd_dt = CASE WHEN NULLIF(p_user_pw, '') IS NOT NULL THEN now() ELSE pw_upd_dt END,
               usrgrp_cd = p_usrgrp_cd,
               dept_cd   = NULLIF(p_dept_cd, ''),
               email     = p_email,
               mobile    = p_mobile,
               lock_yn   = COALESCE(NULLIF(p_lock_yn, ''), lock_yn),
               -- 잠금을 푸는 저장이면 실패횟수도 0으로 되돌린다
               login_fail_cnt = CASE WHEN p_lock_yn = 'N' THEN 0 ELSE login_fail_cnt END,
               use_yn    = COALESCE(NULLIF(p_use_yn, ''), use_yn),
               upd_id    = p_id, upd_dt = now()
         WHERE co_cd = p_co_cd AND idx = p_idx;
        IF NOT FOUND THEN
            RAISE EXCEPTION '수정할 사용자를 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
    END IF;
END$$;
COMMENT ON PROCEDURE sp_user_management_c_000(varchar, bigint, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar) IS
  '사용자 저장 — 신규는 아이디 전역 중복 검사, 수정은 비밀번호가 있을 때만 교체. 서명은 받지 않음';

-- ------------------------------------------------------------
-- 3. sp_user_management_delete_blocker_r_000 — 삭제 참조 검증
--    사용자가 작성한 문서·기록은 이력이라 남기므로 차단 사유가 아니다
--    화면·서비스가 다른 화면과 같은 Double Check 흐름을 타도록 항상 0행을 반환한다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_user_management_delete_blocker_r_000(varchar, bigint[]);
CREATE FUNCTION sp_user_management_delete_blocker_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_idxs: 삭제 대상 대리키 배열
    p_idxs  bigint[]
)
RETURNS TABLE(ref_key varchar, target varchar) LANGUAGE sql AS $$
    -- 차단 사유 없음 — 시그니처를 맞추기 위해 빈 결과를 반환한다
    SELECT u.user_id::varchar, ''::varchar
      FROM tbl_user u
     WHERE u.co_cd = p_co_cd
       AND u.idx = ANY(p_idxs)
       AND FALSE;
$$;
COMMENT ON FUNCTION sp_user_management_delete_blocker_r_000(varchar, bigint[]) IS
  '사용자 삭제 차단 — 문서는 이력 보존이라 차단 사유 없음(항상 0행)';

-- ------------------------------------------------------------
-- 4. sp_user_management_d_000 — 사용자 삭제
--    개인 설정(알림·그리드)은 함께 지우고, 작성 문서·기록은 이력이라 남긴다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_user_management_d_000(
    -- p_co_cd: JWT 회사코드 — 다른 업체 사용자를 지우지 못하게 하는 안전장치
    p_co_cd varchar,
    -- p_idx: 삭제 대상 tbl_user.idx
    p_idx   bigint
)
LANGUAGE plpgsql AS $$
DECLARE
    -- 삭제 대상 로그인 아이디. NULL이면 대상 없음
    v_user_id varchar(20);
BEGIN
    SELECT user_id INTO v_user_id FROM tbl_user WHERE co_cd = p_co_cd AND idx = p_idx;
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION '삭제할 사용자를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    DELETE FROM tbl_user_noti_pref WHERE co_cd = p_co_cd AND user_id = v_user_id;
    DELETE FROM tbl_grid_pref      WHERE co_cd = p_co_cd AND user_id = v_user_id;
    DELETE FROM tbl_user           WHERE co_cd = p_co_cd AND idx = p_idx;
END$$;
COMMENT ON PROCEDURE sp_user_management_d_000(varchar, bigint) IS
  '사용자 삭제 — 개인 설정까지 정리, 작성 문서는 이력 보존';

-- ------------------------------------------------------------
-- 5. sp_user_management_sign_r_000 — 서명 이미지 바이너리 조회
--    서명 모달 열기와 내 서명 조회가 함께 쓴다. 파일 시스템을 더 이상 읽지 않는다
--    미등록이어도 1행이 나오고 sign_img가 NULL이다 — 백엔드는 NULL을 404로 바꾼다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_user_management_sign_r_000(varchar, varchar);
CREATE FUNCTION sp_user_management_sign_r_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위
    p_co_cd   varchar,
    -- p_user_id: 서명을 볼 대상 로그인 아이디
    p_user_id varchar
)
RETURNS TABLE(
    sign_img  bytea,
    sign_mime varchar,
    sign_nm   varchar
) LANGUAGE sql AS $$
    SELECT u.sign_img,
           -- MIME이 비어 있으면(= 구 데이터) PNG로 본다
           COALESCE(u.sign_mime, 'image/png')::varchar,
           COALESCE(u.sign_nm, 'sign.png')::varchar
      FROM tbl_user u
     WHERE u.co_cd = p_co_cd
       AND u.user_id = p_user_id;
$$;
COMMENT ON FUNCTION sp_user_management_sign_r_000(varchar, varchar) IS
  '사용자 서명 바이너리 조회 — 미등록이면 sign_img NULL 1행';

-- ------------------------------------------------------------
-- 6. sp_user_management_sign_u_000 — 서명 이미지 바이너리 저장·삭제
--    p_sign_img가 NULL일 때(= 서명 삭제) MIME·파일명까지 함께 비운다
--    대상이 없으면 45000으로 올린다 — 백엔드가 업무 문구로 바꿔 내보낸다
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_user_management_sign_u_000(varchar, varchar, varchar, varchar);
CREATE OR REPLACE PROCEDURE sp_user_management_sign_u_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 안전장치
    p_co_cd     varchar,
    -- p_user_id: 대상 로그인 아이디
    p_user_id   varchar,
    -- p_sign_img: 저장할 서명 바이너리. NULL이면 서명을 지운다
    p_sign_img  bytea,
    -- p_sign_mime: 이미지 MIME — image/png 또는 image/jpeg
    p_sign_mime varchar,
    -- p_sign_nm: 원본 파일명 — 다운로드 시 파일명으로 쓴다
    p_sign_nm   varchar,
    -- p_id: JWT 작업자 ID — 감사 컬럼
    p_id        varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE tbl_user
       SET sign_img  = p_sign_img,
           -- 삭제(p_sign_img IS NULL)일 때 부가정보도 같이 비워 잔여값이 남지 않게 한다
           sign_mime = CASE WHEN p_sign_img IS NULL THEN NULL
                            ELSE COALESCE(NULLIF(p_sign_mime, ''), 'image/png') END,
           sign_nm   = CASE WHEN p_sign_img IS NULL THEN NULL
                            ELSE COALESCE(NULLIF(p_sign_nm, ''), 'sign.png') END,
           upd_id    = p_id,
           upd_dt    = now()
     WHERE co_cd = p_co_cd
       AND user_id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION '서명을 저장할 사용자를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
END$$;
COMMENT ON PROCEDURE sp_user_management_sign_u_000(varchar, varchar, bytea, varchar, varchar, varchar) IS
  '사용자 서명 바이너리 저장·삭제 — NULL이면 서명 제거. 대상 없으면 45000';
