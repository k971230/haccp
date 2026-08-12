-- ============================================================
-- 55 — tbl_user.pos_cd 제거 + 사용자 SP 동기화
--
-- 개발자: 박승우
-- 일자: 2026-08-12
-- 코멘트:
--   1) 사용자 직위(pos_cd) 컬럼을 폐기한다 (결재선 단계 pos_cd는 유지)
--   2) 로그인·목록·저장 SP에서 pos_cd를 제거한다
--   3) 신규 사용자 기본 비번은 앱(SystemService)에서 1234 해시
-- ============================================================

SET search_path TO sasshaccp;

ALTER TABLE tbl_user DROP COLUMN IF EXISTS pos_cd;

DROP FUNCTION IF EXISTS sp_tbl_user_login_r_000(varchar);
CREATE FUNCTION sp_tbl_user_login_r_000(
    p_user_id varchar
)
RETURNS TABLE(
    user_idx       bigint,
    user_id        varchar,
    user_nm        varchar,
    user_pw        varchar,
    co_cd          varchar,
    co_nm          varchar,
    usrgrp_cd      varchar,
    usrgrp_nm      varchar,
    dept_cd        varchar,
    dept_nm        varchar,
    email          varchar,
    sign_path      varchar,
    gridsave_yn    varchar,
    login_fail_cnt int,
    lock_yn        varchar,
    user_use_yn    varchar,
    co_use_yn      varchar,
    svc_fn_dt      varchar
) LANGUAGE sql AS $$
    SELECT u.idx, u.user_id, u.user_nm, u.user_pw,
           u.co_cd, c.co_nm,
           u.usrgrp_cd, r.usrgrp_nm,
           u.dept_cd, d.dept_nm,
           u.email, u.sign_path, u.gridsave_yn,
           u.login_fail_cnt, u.lock_yn,
           u.use_yn, COALESCE(c.use_yn, 'N'), c.svc_fn_dt
      FROM tbl_user u
      LEFT JOIN tbl_company c ON c.co_cd = u.co_cd
      LEFT JOIN tbl_role    r ON r.co_cd = u.co_cd AND r.usrgrp_cd = u.usrgrp_cd
      LEFT JOIN tbl_dept    d ON d.co_cd = u.co_cd AND d.dept_cd   = u.dept_cd
     WHERE u.user_id = p_user_id;
$$;
COMMENT ON FUNCTION sp_tbl_user_login_r_000(varchar) IS '로그인 인증용 사용자 조회 — user_id 전역 UNIQUE 전제. 회사·권한그룹·부서를 한 번에 반환';

DROP FUNCTION IF EXISTS sp_tbl_user_r_000(varchar, varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_user_r_000(
    p_co_cd   varchar,
    p_user_id varchar,
    p_user_nm varchar,
    p_dept_cd varchar,
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
    sign_path      varchar,
    gridsave_yn    varchar,
    last_login_dt  timestamp,
    login_fail_cnt int,
    lock_yn        varchar,
    use_yn         varchar
) LANGUAGE sql AS $$
    SELECT u.idx, u.user_id, u.co_cd, u.emp_cd, u.user_nm,
           u.usrgrp_cd, r.usrgrp_nm, u.dept_cd, d.dept_nm,
           u.email, u.mobile, u.sign_path, u.gridsave_yn,
           u.last_login_dt, u.login_fail_cnt, u.lock_yn, u.use_yn
      FROM tbl_user u
      LEFT JOIN tbl_role r ON r.co_cd = u.co_cd AND r.usrgrp_cd = u.usrgrp_cd
      LEFT JOIN tbl_dept d ON d.co_cd = u.co_cd AND d.dept_cd   = u.dept_cd
     WHERE u.co_cd = p_co_cd
       AND u.user_id LIKE CONCAT('%', COALESCE(p_user_id, ''), '%')
       AND u.user_nm LIKE CONCAT('%', COALESCE(p_user_nm, ''), '%')
       AND COALESCE(u.dept_cd, '') LIKE CONCAT('%', COALESCE(p_dept_cd, ''), '%')
       AND u.use_yn  LIKE CONCAT('%', COALESCE(p_use_yn,  ''), '%')
     ORDER BY u.user_id;
$$;
COMMENT ON FUNCTION sp_tbl_user_r_000(varchar, varchar, varchar, varchar, varchar) IS '사용자 목록 조회 — 비밀번호 해시 제외. 테넌트 범위는 p_co_cd로 강제';

DROP PROCEDURE IF EXISTS sp_tbl_user_c_000(varchar, bigint, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar);
CREATE PROCEDURE sp_tbl_user_c_000(
    p_co_cd     varchar,
    p_idx       bigint,
    p_user_id   varchar,
    p_emp_cd    varchar,
    p_user_nm   varchar,
    p_user_pw   varchar,
    p_usrgrp_cd varchar,
    p_dept_cd   varchar,
    p_email     varchar,
    p_mobile    varchar,
    p_sign_path varchar,
    p_lock_yn   varchar,
    p_use_yn    varchar,
    p_id        varchar,
    p_type      varchar
)
LANGUAGE plpgsql AS $$
DECLARE v_cnt int;
BEGIN
    IF p_type = 'C' THEN
        SELECT COUNT(*) INTO v_cnt FROM tbl_user WHERE user_id = p_user_id;
        IF v_cnt > 0 THEN
            RAISE EXCEPTION '이미 사용 중인 아이디입니다: %', p_user_id USING ERRCODE = '45000';
        END IF;

        INSERT INTO tbl_user(user_id, co_cd, emp_cd, user_nm, user_pw, usrgrp_cd, dept_cd,
                             email, mobile, sign_path, lock_yn, use_yn, pw_upd_dt, ins_id, ins_dt)
        VALUES (p_user_id, p_co_cd, NULLIF(p_emp_cd, ''), p_user_nm, p_user_pw, p_usrgrp_cd,
                NULLIF(p_dept_cd, ''), p_email, p_mobile, p_sign_path,
                COALESCE(NULLIF(p_lock_yn, ''), 'N'), COALESCE(NULLIF(p_use_yn, ''), 'Y'),
                now(), p_id, now());
    ELSE
        UPDATE tbl_user
           SET emp_cd    = NULLIF(p_emp_cd, ''),
               user_nm   = p_user_nm,
               user_pw   = COALESCE(NULLIF(p_user_pw, ''), user_pw),
               pw_upd_dt = CASE WHEN NULLIF(p_user_pw, '') IS NOT NULL THEN now() ELSE pw_upd_dt END,
               usrgrp_cd = p_usrgrp_cd,
               dept_cd   = NULLIF(p_dept_cd, ''),
               email     = p_email,
               mobile    = p_mobile,
               sign_path = COALESCE(NULLIF(p_sign_path, ''), sign_path),
               lock_yn   = COALESCE(NULLIF(p_lock_yn, ''), lock_yn),
               login_fail_cnt = CASE WHEN p_lock_yn = 'N' THEN 0 ELSE login_fail_cnt END,
               use_yn    = COALESCE(NULLIF(p_use_yn, ''), use_yn),
               upd_id    = p_id,
               upd_dt    = now()
         WHERE co_cd = p_co_cd AND idx = p_idx;

        IF NOT FOUND THEN
            RAISE EXCEPTION '수정할 사용자를 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
    END IF;
END$$;
COMMENT ON PROCEDURE sp_tbl_user_c_000(varchar, bigint, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar) IS
  '사용자 저장 — C:등록(아이디 전역 중복 검사), U:수정(비밀번호는 값이 있을 때만 교체). pos_cd 제거';

CREATE OR REPLACE PROCEDURE sp_tbl_system_c_000(
    p_co_cd varchar,
    p_type varchar,
    p_payload jsonb,
    p_id varchar
) LANGUAGE plpgsql AS $$
DECLARE v_idx bigint := nullif(p_payload ->> 'idx', '')::bigint;
BEGIN
    IF p_type = 'company-management' THEN
        CALL sp_tbl_company_u_000(p_co_cd, p_payload ->> 'coNm', p_payload ->> 'coNmEn', p_payload ->> 'bizNo',
            p_payload ->> 'coNo', p_payload ->> 'coGbn', p_payload ->> 'ceoNm', p_payload ->> 'telNo',
            p_payload ->> 'faxNo', p_payload ->> 'zipNo', p_payload ->> 'addrH', p_payload ->> 'addrD',
            p_payload ->> 'openDt', p_payload ->> 'haccpType', p_payload ->> 'licNo', p_payload ->> 'logoPath',
            coalesce(nullif(p_payload ->> 'retentionMonth', '')::int, 24), p_id);
    ELSIF p_type = 'user-management' THEN
        CALL sp_tbl_user_c_000(p_co_cd, v_idx, p_payload ->> 'userId', p_payload ->> 'empCd', p_payload ->> 'userNm',
            p_payload ->> 'userPw', p_payload ->> 'usrgrpCd', p_payload ->> 'deptCd',
            p_payload ->> 'email', p_payload ->> 'mobile', p_payload ->> 'signPath', p_payload ->> 'lockYn',
            p_payload ->> 'useYn', p_id, CASE WHEN v_idx IS NULL THEN 'C' ELSE 'U' END);
    ELSIF p_type = 'department-management' THEN
        CALL sp_tbl_dept_c_000(p_co_cd, v_idx, p_payload ->> 'deptCd', p_payload ->> 'deptNm', p_payload ->> 'hDeptCd',
            coalesce(nullif(p_payload ->> 'sortNo', '')::int, 0), p_payload ->> 'useYn', p_id,
            CASE WHEN v_idx IS NULL THEN 'C' ELSE 'U' END);
    ELSIF p_type = 'role-management' THEN
        CALL sp_tbl_role_c_000(p_co_cd, v_idx, p_payload ->> 'usrgrpCd', p_payload ->> 'usrgrpNm',
            p_payload ->> 'descRmk', p_payload ->> 'useYn', p_id);
    ELSIF p_type = 'menu-management' THEN
        CALL sp_tbl_menu_c_000(p_co_cd, v_idx, p_payload ->> 'menuCd', p_payload ->> 'menuNm', p_payload ->> 'hMenuCd',
            p_payload ->> 'scrnCd', coalesce(nullif(p_payload ->> 'sortNo', '')::int, 0), p_payload ->> 'useYn', p_id);
    ELSIF p_type = 'common-code-management' THEN
        CALL sp_tbl_code_c_000(p_co_cd, v_idx, p_payload ->> 'mainCd', p_payload ->> 'subCd', p_payload ->> 'codeNm',
            coalesce(nullif(p_payload ->> 'sortNo', '')::int, 0), p_payload ->> 'ref1', p_payload ->> 'ref2',
            p_payload ->> 'useYn', p_id, CASE WHEN v_idx IS NULL THEN 'C' ELSE 'U' END);
    ELSE
        RAISE EXCEPTION '지원하지 않는 시스템 관리 저장 유형입니다.' USING ERRCODE = '45000';
    END IF;
END$$;
COMMENT ON PROCEDURE sp_tbl_system_c_000(varchar, varchar, jsonb, varchar) IS '시스템 관리 저장 — 허용 유형만 기존 회사·사용자·부서·코드 SP로 고정 연결';
