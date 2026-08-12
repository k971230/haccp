-- ============================================================
--  SP 1 — 인증·사용자·조직·권한·공통코드
--
--  개발자: 박승우
--  일자: 2026-08-05
--  코멘트:
--    1) 조회는 FUNCTION(RETURNS TABLE), 저장·삭제는 PROCEDURE로 만든다
--       MyBatis는 조회를 SELECT * FROM sp_...(...), 저장을 CALL sp_...(...)로 호출한다
--    2) idx가 단일 PK라 테넌트 경계는 SP가 지킨다 — 모든 문장에 co_cd = p_co_cd 조건을 반드시 넣는다
--       (조건을 빠뜨리면 다른 업체 데이터가 열린다. 리뷰 시 최우선 확인 항목)
--    3) 업무 오류는 RAISE EXCEPTION ... USING ERRCODE='45000' — 백엔드가 사용자 문구로 변환한다
--
--  명명: sp_tbl_{테이블}_{r:조회|c:저장|u:수정|d:삭제}_{일련번호}
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. sp_tbl_user_login_r_000 — 로그인 인증용 사용자 조회
--    user_id가 전역 UNIQUE라 회사코드를 받지 않는다. 아이디 하나로 소속 회사가 결정된다
--    반환 0행이면(= 존재하지 않는 아이디) 백엔드가 비밀번호 불일치와 같은 문구로 응답한다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_user_login_r_000(varchar);
CREATE FUNCTION sp_tbl_user_login_r_000(
    -- p_user_id: 로그인 화면에서 입력한 아이디 (대소문자 구분)
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
      -- 회사: 서비스 기간 만료·비활성 업체를 로그인 단계에서 걸러내기 위해 함께 읽는다
      LEFT JOIN tbl_company c ON c.co_cd = u.co_cd
      -- 권한그룹명: 로그인 응답과 화면 우측 상단 표기에 사용
      LEFT JOIN tbl_role    r ON r.co_cd = u.co_cd AND r.usrgrp_cd = u.usrgrp_cd
      -- 부서명: 문서 작성자란 기본값
      LEFT JOIN tbl_dept    d ON d.co_cd = u.co_cd AND d.dept_cd   = u.dept_cd
     WHERE u.user_id = p_user_id;
$$;
COMMENT ON FUNCTION sp_tbl_user_login_r_000(varchar) IS '로그인 인증용 사용자 조회 — user_id 전역 UNIQUE 전제. 회사·권한그룹·부서를 한 번에 반환';

-- ------------------------------------------------------------
-- 2. sp_tbl_user_login_u_000 — 로그인 결과 반영
--    성공: 실패횟수 0 초기화 + 최종 로그인 일시 갱신
--    실패: 실패횟수 +1, 임계 도달 시 계정 잠금
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_user_login_u_000(
    -- p_user_id: 로그인 시도 아이디
    p_user_id  varchar,
    -- p_result_cd: S일 때(= 인증 성공) 초기화, 그 외(= 실패)면 실패횟수 증가
    p_result_cd varchar,
    -- p_max_fail: 계정 잠금 임계 실패횟수. 0 이하이면(= 잠금 미사용) 잠그지 않는다
    p_max_fail  int
)
LANGUAGE plpgsql AS $$
BEGIN
    IF p_result_cd = 'S' THEN
        UPDATE tbl_user
           SET login_fail_cnt = 0,
               last_login_dt  = now()
         WHERE user_id = p_user_id;
    ELSE
        UPDATE tbl_user
           SET login_fail_cnt = login_fail_cnt + 1,
               -- 임계 도달 시 즉시 잠금. 해제는 관리자가 사용자 관리 화면에서 처리한다
               lock_yn = CASE WHEN p_max_fail > 0 AND login_fail_cnt + 1 >= p_max_fail
                              THEN 'Y' ELSE lock_yn END
         WHERE user_id = p_user_id;
    END IF;
END$$;
COMMENT ON PROCEDURE sp_tbl_user_login_u_000(varchar, varchar, int) IS '로그인 결과 반영 — 성공 시 실패횟수 초기화, 실패 시 증가 및 임계 초과 잠금';

-- ------------------------------------------------------------
-- 3. sp_tbl_user_r_000 — 사용자 목록 조회
--    비밀번호 해시는 반환하지 않는다(로그인 SP 전용)
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_user_r_000(varchar, varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_user_r_000(
    -- p_co_cd: JWT LoginUser 회사코드 — 테넌트 범위. 필수
    p_co_cd   varchar,
    -- p_user_id: 아이디 부분검색어. NULL이나 공백이면(= 조건 없음) 전체
    p_user_id varchar,
    -- p_user_nm: 이름 부분검색어
    p_user_nm varchar,
    -- p_dept_cd: 부서 필터. 공백이면 전체 부서
    p_dept_cd varchar,
    -- p_use_yn: 사용여부 필터. 공백이면 Y·N 모두
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

-- ------------------------------------------------------------
-- 4. sp_tbl_user_c_000 — 사용자 저장 (등록/수정)
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_tbl_user_c_000(varchar, bigint, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar);
CREATE PROCEDURE sp_tbl_user_c_000(
    -- p_co_cd: JWT 회사코드 — 등록 시 소속 회사, 수정 시 테넌트 검증 조건
    p_co_cd     varchar,
    -- p_idx: 대상 행 PK. p_type='C'일 때(= 신규 등록) 무시된다
    p_idx       bigint,
    -- p_user_id: 로그인 아이디. 전 업체 통틀어 중복 불가
    p_user_id   varchar,
    -- p_emp_cd: 사번. 업체 내 중복 불가, 미입력 허용
    p_emp_cd    varchar,
    -- p_user_nm: 사용자명
    p_user_nm   varchar,
    -- p_user_pw: 비밀번호 해시. 수정 시 NULL이면(= 변경 안 함) 기존 값을 유지한다
    p_user_pw   varchar,
    -- p_usrgrp_cd: 권한그룹코드 — tbl_role.usrgrp_cd
    p_usrgrp_cd varchar,
    -- p_dept_cd: 부서코드
    p_dept_cd   varchar,
    -- p_email: 알림 발송 주소
    p_email     varchar,
    -- p_mobile: 휴대전화번호
    p_mobile    varchar,
    -- p_sign_path: 서명 이미지 경로
    p_sign_path varchar,
    -- p_lock_yn: 계정 잠금여부. N으로 저장하면 실패횟수도 함께 초기화된다
    p_lock_yn   varchar,
    -- p_use_yn: 사용여부
    p_use_yn    varchar,
    -- p_id: 작업자 로그인 ID — 감사 컬럼에 기록
    p_id        varchar,
    -- p_type: C:등록, U:수정
    p_type      varchar
)
LANGUAGE plpgsql AS $$
DECLARE v_cnt int;
BEGIN
    IF p_type = 'C' THEN
        -- 아이디 전역 중복 검사 — UNIQUE 제약에 걸리기 전에 업무 문구로 막는다
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
               -- 비밀번호는 값이 있을 때만 교체. 함께 변경일시를 갱신한다
               user_pw   = COALESCE(NULLIF(p_user_pw, ''), user_pw),
               pw_upd_dt = CASE WHEN NULLIF(p_user_pw, '') IS NOT NULL THEN now() ELSE pw_upd_dt END,
               usrgrp_cd = p_usrgrp_cd,
               dept_cd   = NULLIF(p_dept_cd, ''),
               email     = p_email,
               mobile    = p_mobile,
               sign_path = COALESCE(NULLIF(p_sign_path, ''), sign_path),
               lock_yn   = COALESCE(NULLIF(p_lock_yn, ''), lock_yn),
               -- 잠금을 푸는 저장이면 실패횟수도 함께 0으로 되돌린다
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

-- ------------------------------------------------------------
-- 5. sp_tbl_user_d_000 — 사용자 삭제
--    참조 차단 검증(assertDeletable)은 백엔드가 선행 수행한다. 여기서는 테넌트 경계만 지킨다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_user_d_000(
    -- p_co_cd: JWT 회사코드 — 다른 업체 사용자를 지우지 못하게 하는 안전장치
    p_co_cd varchar,
    -- p_idx: 삭제 대상 tbl_user.idx
    p_idx   bigint
)
LANGUAGE plpgsql AS $$
DECLARE v_user_id varchar(20);
BEGIN
    SELECT user_id INTO v_user_id FROM tbl_user WHERE co_cd = p_co_cd AND idx = p_idx;
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION '삭제할 사용자를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    -- 사용자에 종속된 개인 설정은 함께 정리한다(문서·기록은 이력이라 남긴다)
    DELETE FROM tbl_user_noti_pref WHERE co_cd = p_co_cd AND user_id = v_user_id;
    DELETE FROM tbl_grid_pref      WHERE co_cd = p_co_cd AND user_id = v_user_id;
    DELETE FROM tbl_user           WHERE co_cd = p_co_cd AND idx = p_idx;
END$$;
COMMENT ON PROCEDURE sp_tbl_user_d_000(varchar, bigint) IS '사용자 삭제 — 개인 설정(알림·그리드)까지 정리. 작성 문서는 이력이라 보존';

-- ------------------------------------------------------------
-- 6. sp_tbl_dept_r_000 — 부서 조회 (트리 정렬 · 상위부서명)
-- ------------------------------------------------------------
-- RETURNS 시그니처 변경 시 DROP 후 재생성 (CREATE OR REPLACE만으로는 OUT 변경 불가)
DROP FUNCTION IF EXISTS sp_tbl_dept_r_000(varchar, varchar, varchar);

CREATE OR REPLACE FUNCTION sp_tbl_dept_r_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위
    p_co_cd  varchar,
    -- p_dept_nm: 부서명 부분검색어
    p_dept_nm varchar,
    -- p_use_yn: 사용여부 필터. 공백이면 전체
    p_use_yn varchar
)
RETURNS TABLE(
    idx       bigint,
    co_cd     varchar,
    dept_cd   varchar,
    dept_nm   varchar,
    h_dept_cd varchar,
    -- 상위부서명 — self LEFT JOIN (그리드 표시용, 코드는 h_dept_cd)
    h_dept_nm varchar,
    sort_no   int,
    use_yn    varchar
) LANGUAGE sql AS $$
    SELECT d.idx, d.co_cd, d.dept_cd, d.dept_nm, d.h_dept_cd,
           p.dept_nm AS h_dept_nm,
           d.sort_no, d.use_yn
      FROM tbl_dept d
      -- 상위부서 — 없으면 h_dept_nm null
      LEFT JOIN tbl_dept p
        ON p.co_cd = d.co_cd
       AND p.dept_cd = d.h_dept_cd
     WHERE d.co_cd = p_co_cd
       AND d.dept_nm LIKE CONCAT('%', COALESCE(p_dept_nm, ''), '%')
       AND d.use_yn  LIKE CONCAT('%', COALESCE(p_use_yn,  ''), '%')
     -- 최상위(상위코드 없음)를 먼저, 그다음 정렬순서·코드 순 — FE 트리 구성 순서와 동일
     ORDER BY CASE WHEN COALESCE(d.h_dept_cd, '') = '' THEN 0 ELSE 1 END, d.sort_no, d.dept_cd;
$$;
COMMENT ON FUNCTION sp_tbl_dept_r_000(varchar, varchar, varchar) IS '부서 조회 — 상위부서명(self JOIN)·트리 정렬';

-- ------------------------------------------------------------
-- 7. sp_tbl_dept_c_000 — 부서 저장 (등록/수정)
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_dept_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd    varchar,
    -- p_idx: 대상 PK. 등록(C)일 때 무시
    p_idx      bigint,
    -- p_dept_cd: 부서코드 — 업체 내 유일
    p_dept_cd  varchar,
    -- p_dept_nm: 부서명
    p_dept_nm  varchar,
    -- p_h_dept_cd: 상위 부서코드. 공백이면 최상위
    p_h_dept_cd varchar,
    -- p_sort_no: 같은 상위 안에서의 표시 순서
    p_sort_no  int,
    -- p_use_yn: 사용여부
    p_use_yn   varchar,
    -- p_id: 작업자 로그인 ID
    p_id       varchar,
    -- p_type: C:등록, U:수정
    p_type     varchar
)
LANGUAGE plpgsql AS $$
DECLARE v_cnt int;
BEGIN
    IF p_type = 'C' THEN
        SELECT COUNT(*) INTO v_cnt FROM tbl_dept WHERE co_cd = p_co_cd AND dept_cd = p_dept_cd;
        IF v_cnt > 0 THEN
            RAISE EXCEPTION '이미 등록된 부서코드입니다: %', p_dept_cd USING ERRCODE = '45000';
        END IF;

        INSERT INTO tbl_dept(co_cd, dept_cd, dept_nm, h_dept_cd, sort_no, use_yn, ins_id, ins_dt)
        VALUES (p_co_cd, p_dept_cd, p_dept_nm, NULLIF(p_h_dept_cd, ''),
                COALESCE(p_sort_no, 0), COALESCE(NULLIF(p_use_yn, ''), 'Y'), p_id, now());
    ELSE
        -- 자기 자신을 상위로 지정하면 트리가 끊긴다
        IF p_h_dept_cd = p_dept_cd THEN
            RAISE EXCEPTION '자기 자신을 상위 부서로 지정할 수 없습니다.' USING ERRCODE = '45000';
        END IF;

        UPDATE tbl_dept
           SET dept_nm   = p_dept_nm,
               h_dept_cd = NULLIF(p_h_dept_cd, ''),
               sort_no   = COALESCE(p_sort_no, sort_no),
               use_yn    = COALESCE(NULLIF(p_use_yn, ''), use_yn),
               upd_id    = p_id,
               upd_dt    = now()
         WHERE co_cd = p_co_cd AND idx = p_idx;

        IF NOT FOUND THEN
            RAISE EXCEPTION '수정할 부서를 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
    END IF;
END$$;
COMMENT ON PROCEDURE sp_tbl_dept_c_000(varchar, bigint, varchar, varchar, varchar, int, varchar, varchar, varchar) IS '부서 저장 — C:등록(코드 중복 검사), U:수정(자기참조 방지)';

-- ------------------------------------------------------------
-- 8. sp_tbl_dept_d_000 — 부서 삭제
--    사용자 직접 사용·하위트리 사용자·직속 하위 부서가 있으면 차단한다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_dept_d_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_idx: 삭제 대상 tbl_dept.idx
    p_idx   bigint
)
LANGUAGE plpgsql AS $$
DECLARE v_dept_cd varchar(20); v_cnt int;
BEGIN
    SELECT dept_cd INTO v_dept_cd FROM tbl_dept WHERE co_cd = p_co_cd AND idx = p_idx;
    IF v_dept_cd IS NULL THEN
        RAISE EXCEPTION '삭제할 부서를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    -- 사용자관리에서 이 부서 사용 중
    SELECT COUNT(*) INTO v_cnt
      FROM tbl_user u
     WHERE u.co_cd = p_co_cd AND u.dept_cd = v_dept_cd;
    IF v_cnt > 0 THEN
        RAISE EXCEPTION '사용자가 사용 중인 부서는 삭제할 수 없습니다: %', v_dept_cd USING ERRCODE = '45000';
    END IF;

    -- 하위 부서 트리에 사용자가 있으면 상위도 삭제 불가
    WITH RECURSIVE sub AS (
        SELECT c.dept_cd
          FROM tbl_dept c
         WHERE c.co_cd = p_co_cd AND c.h_dept_cd = v_dept_cd
        UNION ALL
        SELECT c2.dept_cd
          FROM tbl_dept c2
          INNER JOIN sub s ON s.dept_cd = c2.h_dept_cd
         WHERE c2.co_cd = p_co_cd
    )
    SELECT COUNT(*) INTO v_cnt
      FROM sub s
      INNER JOIN tbl_user u ON u.co_cd = p_co_cd AND u.dept_cd = s.dept_cd;
    IF v_cnt > 0 THEN
        RAISE EXCEPTION '하위 부서에 사용자가 있어 삭제할 수 없습니다: %', v_dept_cd USING ERRCODE = '45000';
    END IF;

    -- 직속 하위 부서가 남아 있으면 트리가 끊기므로 막는다
    SELECT COUNT(*) INTO v_cnt FROM tbl_dept WHERE co_cd = p_co_cd AND h_dept_cd = v_dept_cd;
    IF v_cnt > 0 THEN
        RAISE EXCEPTION '하위 부서가 있어 삭제할 수 없습니다: %', v_dept_cd USING ERRCODE = '45000';
    END IF;

    DELETE FROM tbl_dept WHERE co_cd = p_co_cd AND idx = p_idx;
END$$;
COMMENT ON PROCEDURE sp_tbl_dept_d_000(varchar, bigint) IS
    '부서 삭제 — 사용자·하위트리 사용자·하위 부서 존재 시 차단';

-- ------------------------------------------------------------
-- 9. sp_tbl_menu_r_000 — 권한 반영 메뉴 트리 조회
--    로그인 직후 1회 호출한다. 조회권한(read_yn)이 없는 화면은 아예 내려보내지 않는다
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_menu_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd    varchar,
    -- p_usrgrp_cd: JWT 권한그룹코드 — 화면 권한 결합 기준
    p_usrgrp_cd varchar
)
RETURNS TABLE(
    idx       bigint,
    menu_cd   varchar,
    menu_nm   varchar,
    h_menu_cd varchar,
    scrn_cd   varchar,
    module_cd varchar,
    sort_no   int,
    read_yn   varchar,
    write_yn  varchar,
    modify_yn varchar,
    delete_yn varchar,
    print_yn  varchar
) LANGUAGE sql AS $$
    SELECT m.idx, m.menu_cd, m.menu_nm, m.h_menu_cd, m.scrn_cd, s.module_cd, m.sort_no,
           COALESCE(rs.read_yn,   'N'),
           COALESCE(rs.write_yn,  'N'),
           COALESCE(rs.modify_yn, 'N'),
           COALESCE(rs.delete_yn, 'N'),
           COALESCE(rs.print_yn,  'N')
      FROM tbl_menu m
      LEFT JOIN tbl_screen s ON s.scrn_cd = m.scrn_cd
      -- 권한: 등록된 행이 없으면 접근 불가로 본다(기본 거부)
      LEFT JOIN tbl_role_screen rs
             ON rs.co_cd = m.co_cd AND rs.usrgrp_cd = p_usrgrp_cd AND rs.scrn_cd = m.scrn_cd
     WHERE m.co_cd  = p_co_cd
       AND m.use_yn = 'Y'
       -- 화면이 붙지 않은 분류 노드(scrn_cd IS NULL)는 항상 통과, leaf는 조회권한이 있을 때만
       AND (m.scrn_cd IS NULL OR COALESCE(rs.read_yn, 'N') = 'Y')
     -- 대·중·소 인코딩 sort_no 순 (1001 → 2101 → …)
     ORDER BY m.sort_no, m.menu_cd;
$$;
COMMENT ON FUNCTION sp_tbl_menu_r_000(varchar, varchar) IS '권한 반영 메뉴 트리 — sort_no(대중소 인코딩) 순, 조회권한 없는 화면 제외';

-- ------------------------------------------------------------
-- 10. sp_tbl_role_screen_r_000 — 권한그룹별 화면 권한 조회
--     권한 관리 화면이 전체 화면 목록에 현재 설정을 붙여 보여줄 때 쓴다
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_role_screen_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd     varchar,
    -- p_usrgrp_cd: 조회할 권한그룹코드
    p_usrgrp_cd varchar
)
RETURNS TABLE(
    idx       bigint,
    scrn_cd   varchar,
    scrn_nm   varchar,
    module_cd varchar,
    read_yn   varchar,
    write_yn  varchar,
    modify_yn varchar,
    delete_yn varchar,
    print_yn  varchar,
    sort_no   int
) LANGUAGE sql AS $$
    -- 화면 마스터를 기준(FROM)으로 잡아야 미설정 화면도 N으로 표시된다
    SELECT rs.idx, s.scrn_cd, s.scrn_nm, s.module_cd,
           COALESCE(rs.read_yn,   'N'),
           COALESCE(rs.write_yn,  'N'),
           COALESCE(rs.modify_yn, 'N'),
           COALESCE(rs.delete_yn, 'N'),
           COALESCE(rs.print_yn,  'N'),
           s.sort_no
      FROM tbl_screen s
      LEFT JOIN tbl_role_screen rs
             ON rs.co_cd = p_co_cd AND rs.usrgrp_cd = p_usrgrp_cd AND rs.scrn_cd = s.scrn_cd
     WHERE s.use_yn = 'Y'
     ORDER BY s.sort_no, s.scrn_cd;
$$;
COMMENT ON FUNCTION sp_tbl_role_screen_r_000(varchar, varchar) IS '권한그룹별 화면 권한 조회 — 미설정 화면도 N으로 채워 전체 목록 반환';

-- ------------------------------------------------------------
-- 11. sp_tbl_role_screen_c_000 — 화면 권한 1건 저장 (업서트)
--     권한 관리 화면은 변경된 행만 모아 이 SP를 반복 호출한다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_role_screen_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd     varchar,
    -- p_usrgrp_cd: 권한그룹코드
    p_usrgrp_cd varchar,
    -- p_scrn_cd: 화면코드
    p_scrn_cd   varchar,
    -- p_read_yn: 조회 권한 Y/N — N이면 메뉴 자체가 숨겨진다
    p_read_yn   varchar,
    -- p_write_yn: 등록 권한 Y/N
    p_write_yn  varchar,
    -- p_modify_yn: 수정 권한 Y/N
    p_modify_yn varchar,
    -- p_delete_yn: 삭제 권한 Y/N
    p_delete_yn varchar,
    -- p_print_yn: 출력 권한 Y/N
    p_print_yn  varchar,
    -- p_id: 작업자 로그인 ID
    p_id        varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO tbl_role_screen(co_cd, usrgrp_cd, scrn_cd, read_yn, write_yn, modify_yn, delete_yn, print_yn, ins_id, ins_dt)
    VALUES (p_co_cd, p_usrgrp_cd, p_scrn_cd,
            COALESCE(NULLIF(p_read_yn,   ''), 'N'),
            COALESCE(NULLIF(p_write_yn,  ''), 'N'),
            COALESCE(NULLIF(p_modify_yn, ''), 'N'),
            COALESCE(NULLIF(p_delete_yn, ''), 'N'),
            COALESCE(NULLIF(p_print_yn,  ''), 'N'),
            p_id, now())
    ON CONFLICT (co_cd, usrgrp_cd, scrn_cd) DO UPDATE SET
        read_yn   = EXCLUDED.read_yn,
        write_yn  = EXCLUDED.write_yn,
        modify_yn = EXCLUDED.modify_yn,
        delete_yn = EXCLUDED.delete_yn,
        print_yn  = EXCLUDED.print_yn,
        upd_id    = p_id,
        upd_dt    = now();
END$$;
COMMENT ON PROCEDURE sp_tbl_role_screen_c_000(varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar) IS '화면 권한 업서트 — 변경 행 단위 반복 호출용';

-- ------------------------------------------------------------
-- 12. sp_tbl_code_r_000 — 공통코드 조회
--     플랫폼 표준코드(0000)와 업체 코드를 합쳐 반환하되, 같은 코드면 업체 값이 이긴다
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_code_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_main_cd: 대분류 코드. 공백이면(= 전체 그룹) 모든 코드
    p_main_cd varchar,
    -- p_use_yn: 사용여부 필터. 공백이면 전체
    p_use_yn  varchar
)
RETURNS TABLE(
    idx     bigint,
    co_cd   varchar,
    main_cd varchar,
    sub_cd  varchar,
    code_nm varchar,
    sort_no int,
    ref1    varchar,
    ref2    varchar,
    sys_yn  varchar,
    use_yn  varchar
) LANGUAGE sql AS $$
    SELECT c.idx, c.co_cd, c.main_cd, c.sub_cd, c.code_nm, c.sort_no, c.ref1, c.ref2, c.sys_yn, c.use_yn
      FROM tbl_code c
     WHERE c.co_cd IN (p_co_cd, '0000')
       AND c.main_cd LIKE CONCAT('%', COALESCE(p_main_cd, ''), '%')
       AND c.use_yn  LIKE CONCAT('%', COALESCE(p_use_yn,  ''), '%')
       AND c.sub_cd <> '*'
       -- 같은 (대분류, 세부코드)가 양쪽에 있으면 업체 코드만 남긴다
       AND NOT (c.co_cd = '0000' AND EXISTS (
                SELECT 1 FROM tbl_code o
                 WHERE o.co_cd = p_co_cd AND o.main_cd = c.main_cd AND o.sub_cd = c.sub_cd))
     ORDER BY c.main_cd, c.sort_no, c.sub_cd;
$$;
COMMENT ON FUNCTION sp_tbl_code_r_000(varchar, varchar, varchar) IS '공통코드 조회 — 플랫폼 표준(0000) + 업체 코드 병합, 중복 시 업체 값 우선';

-- ------------------------------------------------------------
-- 13. sp_tbl_code_c_000 — 공통코드 저장 (등록/수정)
--     플랫폼 표준코드(sys_yn=Y)는 업체가 고칠 수 없다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_code_c_000(
    -- p_co_cd: JWT 회사코드 — 항상 업체 코드로만 저장된다(0000 저장 불가)
    p_co_cd   varchar,
    -- p_idx: 대상 PK. 등록(C)일 때 무시
    p_idx     bigint,
    -- p_main_cd: 대분류 코드
    p_main_cd varchar,
    -- p_sub_cd: 세부 코드
    p_sub_cd  varchar,
    -- p_code_nm: 코드명
    p_code_nm varchar,
    -- p_sort_no: 정렬순서
    p_sort_no int,
    -- p_ref1: 참조값1
    p_ref1    varchar,
    -- p_ref2: 참조값2
    p_ref2    varchar,
    -- p_use_yn: 사용여부
    p_use_yn  varchar,
    -- p_id: 작업자 로그인 ID
    p_id      varchar,
    -- p_type: C:등록, U:수정
    p_type    varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_sys_yn varchar(10);
    v_co     varchar(10);
    v_cnt    int;
    v_is_sys boolean;
BEGIN
    IF p_co_cd = '0000' THEN
        RAISE EXCEPTION '플랫폼 표준코드 회사로는 저장할 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    IF p_type = 'C' THEN
        SELECT COUNT(*) INTO v_cnt FROM tbl_code
         WHERE co_cd = p_co_cd AND main_cd = p_main_cd AND sub_cd = p_sub_cd;
        IF v_cnt > 0 THEN
            RAISE EXCEPTION '이미 등록된 코드입니다: % / %', p_main_cd, p_sub_cd USING ERRCODE = '45000';
        END IF;
        INSERT INTO tbl_code(co_cd, main_cd, sub_cd, code_nm, sort_no, ref1, ref2, sys_yn, use_yn, ins_id, ins_dt)
        VALUES (p_co_cd, p_main_cd, p_sub_cd, p_code_nm, COALESCE(p_sort_no, 0),
                p_ref1, p_ref2, 'N', COALESCE(NULLIF(p_use_yn, ''), 'Y'), p_id, now());
        RETURN;
    END IF;

    SELECT sys_yn, co_cd INTO v_sys_yn, v_co
      FROM tbl_code
     WHERE idx = p_idx AND co_cd IN (p_co_cd, '0000')
     ORDER BY CASE WHEN co_cd = p_co_cd THEN 0 ELSE 1 END
     LIMIT 1;
    IF v_sys_yn IS NULL THEN
        RAISE EXCEPTION '수정할 코드를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    v_is_sys := v_sys_yn IN ('Y', 'y', 'sys');

    IF v_is_sys THEN
        IF v_co = '0000' THEN
            INSERT INTO tbl_code(co_cd, main_cd, sub_cd, code_nm, sort_no, ref1, ref2, sys_yn, use_yn, ins_id, ins_dt)
            SELECT p_co_cd, c.main_cd, c.sub_cd, COALESCE(NULLIF(p_code_nm, ''), c.code_nm),
                   c.sort_no, c.ref1, c.ref2, c.sys_yn,
                   COALESCE(NULLIF(p_use_yn, ''), c.use_yn), p_id, now()
              FROM tbl_code c WHERE c.idx = p_idx
            ON CONFLICT (co_cd, main_cd, sub_cd) DO UPDATE SET
                code_nm = EXCLUDED.code_nm, use_yn = EXCLUDED.use_yn, upd_id = p_id, upd_dt = now();
        ELSE
            UPDATE tbl_code
               SET code_nm = COALESCE(NULLIF(p_code_nm, ''), code_nm),
                   use_yn  = COALESCE(NULLIF(p_use_yn, ''), use_yn),
                   upd_id  = p_id, upd_dt = now()
             WHERE co_cd = p_co_cd AND idx = p_idx;
        END IF;
        RETURN;
    END IF;

    IF v_co <> p_co_cd THEN
        RAISE EXCEPTION '수정할 코드를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    UPDATE tbl_code
       SET code_nm = p_code_nm, sort_no = COALESCE(p_sort_no, sort_no),
           ref1 = p_ref1, ref2 = p_ref2,
           use_yn = COALESCE(NULLIF(p_use_yn, ''), use_yn),
           upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND idx = p_idx;
END$$;
COMMENT ON PROCEDURE sp_tbl_code_c_000(varchar, bigint, varchar, varchar, varchar, int, varchar, varchar, varchar, varchar, varchar) IS
  '공통코드 저장 — 사용자 CRUD, 시스템은 코드명·사용여부만(0000은 업체 오버라이드)';

-- ------------------------------------------------------------
-- 14. sp_tbl_code_d_000 — 공통코드 삭제
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_code_d_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_idx: 삭제 대상 tbl_code.idx
    p_idx   bigint
)
LANGUAGE plpgsql AS $$
DECLARE v_sys_yn varchar(1);
BEGIN
    SELECT sys_yn INTO v_sys_yn FROM tbl_code WHERE co_cd = p_co_cd AND idx = p_idx;
    IF v_sys_yn IS NULL THEN
        RAISE EXCEPTION '삭제할 코드를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF v_sys_yn = 'Y' THEN
        RAISE EXCEPTION '시스템 코드는 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    DELETE FROM tbl_code WHERE co_cd = p_co_cd AND idx = p_idx;
END$$;
COMMENT ON PROCEDURE sp_tbl_code_d_000(varchar, bigint) IS '공통코드 삭제 — 시스템 코드 차단';

-- ------------------------------------------------------------
-- 15. sp_tbl_grid_pref_r_000 — 사용자 그리드 열 설정 조회
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_grid_pref_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd  varchar,
    -- p_user_id: JWT 로그인 ID
    p_user_id varchar,
    -- p_scrn_cd: 화면코드. 공백이면(= 전체 화면) 사용자 설정 전부
    p_scrn_cd varchar
)
RETURNS TABLE(
    idx       bigint,
    scrn_cd   varchar,
    grid_id   varchar,
    pref_json text
) LANGUAGE sql AS $$
    SELECT g.idx, g.scrn_cd, g.grid_id, g.pref_json
      FROM tbl_grid_pref g
     WHERE g.co_cd = p_co_cd
       AND g.user_id = p_user_id
       AND g.scrn_cd LIKE CONCAT('%', COALESCE(p_scrn_cd, ''), '%')
     ORDER BY g.scrn_cd, g.grid_id;
$$;
COMMENT ON FUNCTION sp_tbl_grid_pref_r_000(varchar, varchar, varchar) IS '사용자 그리드 열 설정 조회 — 화면 진입 시 1회';

-- ------------------------------------------------------------
-- 16. sp_tbl_grid_pref_c_000 — 그리드 열 설정 업서트
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_grid_pref_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd    varchar,
    -- p_user_id: JWT 로그인 ID
    p_user_id  varchar,
    -- p_scrn_cd: 화면코드
    p_scrn_cd  varchar,
    -- p_grid_id: 그리드 식별자 — MesEditableGrid persistId
    p_grid_id  varchar,
    -- p_pref_json: 열 설정 JSON 문자열. 공백이면(= 초기화 요청) 행을 삭제한다
    p_pref_json text
)
LANGUAGE plpgsql AS $$
BEGIN
    IF COALESCE(p_pref_json, '') = '' THEN
        DELETE FROM tbl_grid_pref
         WHERE co_cd = p_co_cd AND user_id = p_user_id AND scrn_cd = p_scrn_cd AND grid_id = p_grid_id;
        RETURN;
    END IF;

    INSERT INTO tbl_grid_pref(co_cd, user_id, scrn_cd, grid_id, pref_json, ins_id, ins_dt)
    VALUES (p_co_cd, p_user_id, p_scrn_cd, p_grid_id, p_pref_json, p_user_id, now())
    ON CONFLICT (user_id, scrn_cd, grid_id) DO UPDATE SET
        pref_json = EXCLUDED.pref_json,
        upd_id    = p_user_id,
        upd_dt    = now();
END$$;
COMMENT ON PROCEDURE sp_tbl_grid_pref_c_000(varchar, varchar, varchar, varchar, text) IS '그리드 열 설정 업서트 — 빈 JSON이면 초기화(행 삭제)';

-- ------------------------------------------------------------
-- 17. sp_tbl_company_r_000 — 회사정보 조회
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_company_r_000(
    -- p_co_cd: JWT 회사코드. 플랫폼 관리자는 다른 업체 코드를 넘길 수 있다
    p_co_cd varchar
)
RETURNS SETOF tbl_company LANGUAGE sql AS $$
    SELECT * FROM tbl_company WHERE co_cd = p_co_cd;
$$;
COMMENT ON FUNCTION sp_tbl_company_r_000(varchar) IS '회사정보 조회 — A4 문서 헤더·로고·보존기간의 원천';

-- ------------------------------------------------------------
-- 18. sp_tbl_company_u_000 — 회사정보 수정
--     회사 등록(신규 테넌트 생성)은 sp_tbl_company_init_c_000이 담당한다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_company_u_000(
    -- p_co_cd: 수정 대상 회사코드
    p_co_cd           varchar,
    -- p_co_nm: 회사명 — 전 문서 헤더에 출력
    p_co_nm           varchar,
    -- p_co_nm_en: 회사명(영문)
    p_co_nm_en        varchar,
    -- p_biz_no: 사업자등록번호
    p_biz_no          varchar,
    -- p_co_no: 법인등록번호
    p_co_no           varchar,
    -- p_co_gbn: 법인구분 1:법인, 2:개인
    p_co_gbn          varchar,
    -- p_ceo_nm: 대표자명
    p_ceo_nm          varchar,
    -- p_tel_no: 대표 전화번호
    p_tel_no          varchar,
    -- p_fax_no: 팩스번호
    p_fax_no          varchar,
    -- p_zip_no: 우편번호
    p_zip_no          varchar,
    -- p_addr_h: 주소
    p_addr_h          varchar,
    -- p_addr_d: 상세주소
    p_addr_d          varchar,
    -- p_open_dt: 개업일 YYYYMMDD
    p_open_dt         varchar,
    -- p_haccp_type: HACCP 업종유형
    p_haccp_type      varchar,
    -- p_lic_no: 영업허가(신고)번호
    p_lic_no          varchar,
    -- p_logo_path: 로고 파일 경로
    p_logo_path       varchar,
    -- p_retention_month: 기본 문서 보존 개월수. 24 미만은 법정 기준 미달이라 막는다
    p_retention_month int,
    -- p_id: 작업자 로그인 ID
    p_id              varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    IF COALESCE(p_retention_month, 24) < 24 THEN
        RAISE EXCEPTION '문서 보존기간은 24개월 이상이어야 합니다.' USING ERRCODE = '45000';
    END IF;

    UPDATE tbl_company
       SET co_nm           = p_co_nm,
           co_nm_en        = p_co_nm_en,
           biz_no          = p_biz_no,
           co_no           = p_co_no,
           co_gbn          = p_co_gbn,
           ceo_nm          = p_ceo_nm,
           tel_no          = p_tel_no,
           fax_no          = p_fax_no,
           zip_no          = p_zip_no,
           addr_h          = p_addr_h,
           addr_d          = p_addr_d,
           open_dt         = p_open_dt,
           haccp_type      = p_haccp_type,
           lic_no          = p_lic_no,
           logo_path       = p_logo_path,
           retention_month = COALESCE(p_retention_month, retention_month),
           upd_id          = p_id,
           upd_dt          = now()
     WHERE co_cd = p_co_cd;

    IF NOT FOUND THEN
        RAISE EXCEPTION '수정할 회사정보를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
END$$;
COMMENT ON PROCEDURE sp_tbl_company_u_000(varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, int, varchar) IS '회사정보 수정 — 보존기간 24개월 미만 차단';
