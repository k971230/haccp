-- ============================================================
--  migrate 64 — 권한그룹 관리 화면 전용 SP 신설
--
--  개발자: 박승우
--  일자: 2026-08-12
--  코멘트:
--    1) 좌측 권한그룹 마스터와 우측 화면권한 매트릭스를 한 화면이 쓰므로 SP도 같은 접두(_role_mgmt_)로 묶는다
--    2) 화면권한 조회는 로그인 직후 버튼 권한 판정에도 쓰인다 — tbl_screen 기준 LEFT JOIN이라 미설정 화면도 N으로 나온다
--    3) 삭제 D는 사용자가 쓰는 권한그룹을 막고, 통과하면 그룹의 화면권한 행까지 함께 정리한다
--    4) 생성 전용 — 레거시 sp_tbl_role_*·sp_tbl_role_screen_* DROP은 68에서 수행
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. sp_tbl_role_mgmt_r_000 — 권한그룹 목록 (좌측 마스터)
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_role_mgmt_r_000(varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_role_mgmt_r_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위. 필수 등가 조건
    p_co_cd     varchar,
    -- p_usrgrp_cd: 페이지 헤더 권한그룹코드 검색어. 공백이면 전체
    p_usrgrp_cd varchar,
    -- p_usrgrp_nm: 페이지 헤더 권한그룹명 검색어. 공백이면 전체
    p_usrgrp_nm varchar,
    -- p_use_yn: 페이지 헤더 사용여부. 공백이면 Y·N 모두
    p_use_yn    varchar
)
RETURNS TABLE(
    idx       bigint,
    usrgrp_cd varchar,
    usrgrp_nm varchar,
    desc_rmk  varchar,
    use_yn    varchar
) LANGUAGE sql AS $$
    SELECT r.idx, r.usrgrp_cd, r.usrgrp_nm, r.desc_rmk, r.use_yn
      FROM tbl_role r
     WHERE r.co_cd = p_co_cd
       AND r.usrgrp_cd LIKE CONCAT('%', COALESCE(p_usrgrp_cd, ''), '%')
       AND r.usrgrp_nm LIKE CONCAT('%', COALESCE(p_usrgrp_nm, ''), '%')
       AND r.use_yn    LIKE CONCAT('%', COALESCE(p_use_yn,    ''), '%')
     ORDER BY r.usrgrp_cd;
$$;
COMMENT ON FUNCTION sp_tbl_role_mgmt_r_000(varchar, varchar, varchar, varchar) IS
  '권한그룹 목록 — 테넌트 범위 + 헤더 코드·명·사용여부 LIKE';

-- ------------------------------------------------------------
-- 2. sp_tbl_role_mgmt_c_000 — 권한그룹 저장
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_role_mgmt_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd     varchar,
    -- p_idx: 수정 대상 대리키. 신규면 NULL
    p_idx       bigint,
    -- p_usrgrp_cd: 업체 내 유일 권한그룹코드. 수정 시에는 바꾸지 않는다
    p_usrgrp_cd varchar,
    -- p_usrgrp_nm: 화면 표시 권한그룹명
    p_usrgrp_nm varchar,
    -- p_desc_rmk: 권한그룹 설명
    p_desc_rmk  varchar,
    -- p_use_yn: 사용여부
    p_use_yn    varchar,
    -- p_id: JWT 작업자 ID — 감사 컬럼
    p_id        varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    -- 업무키 중복 검사 건수
    v_cnt int;
BEGIN
    -- 권한그룹명이 비면(= 화면이 값을 빠뜨림) 기존 이름을 공백으로 덮어쓰게 되므로 막는다
    IF COALESCE(trim(p_usrgrp_nm), '') = '' THEN
        RAISE EXCEPTION '권한그룹명은 필수입니다.' USING ERRCODE = '45000';
    END IF;

    IF p_idx IS NULL THEN
        SELECT COUNT(*) INTO v_cnt FROM tbl_role WHERE co_cd = p_co_cd AND usrgrp_cd = p_usrgrp_cd;
        IF v_cnt > 0 THEN
            RAISE EXCEPTION '이미 등록된 권한그룹코드입니다: %', p_usrgrp_cd USING ERRCODE = '45000';
        END IF;

        INSERT INTO tbl_role(co_cd, usrgrp_cd, usrgrp_nm, desc_rmk, use_yn, ins_id, ins_dt)
        VALUES (p_co_cd, p_usrgrp_cd, p_usrgrp_nm, NULLIF(p_desc_rmk, ''),
                COALESCE(NULLIF(p_use_yn, ''), 'Y'), p_id, now());
    ELSE
        UPDATE tbl_role
           SET usrgrp_nm = p_usrgrp_nm,
               desc_rmk  = NULLIF(p_desc_rmk, ''),
               use_yn    = COALESCE(NULLIF(p_use_yn, ''), use_yn),
               upd_id    = p_id, upd_dt = now()
         WHERE co_cd = p_co_cd AND idx = p_idx;
        IF NOT FOUND THEN
            RAISE EXCEPTION '수정할 권한그룹을 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
    END IF;
END$$;
COMMENT ON PROCEDURE sp_tbl_role_mgmt_c_000(varchar, bigint, varchar, varchar, varchar, varchar, varchar) IS
  '권한그룹 저장 — 신규는 코드 중복 검사, 수정은 명·설명·사용여부만';

-- ------------------------------------------------------------
-- 3. sp_tbl_role_mgmt_delete_blocker_r_000 — 삭제 참조 검증
--    이 권한그룹을 쓰는 사용자가 있으면 로그인 권한이 사라지므로 차단한다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_role_mgmt_delete_blocker_r_000(varchar, bigint[]);
CREATE FUNCTION sp_tbl_role_mgmt_delete_blocker_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_idxs: 삭제 대상 대리키 배열
    p_idxs  bigint[]
)
RETURNS TABLE(ref_key varchar, target varchar) LANGUAGE sql AS $$
    SELECT r.usrgrp_cd::varchar AS ref_key,
           '사용자'::varchar AS target
      FROM tbl_role r
     WHERE r.co_cd = p_co_cd
       AND r.idx = ANY(p_idxs)
       AND EXISTS (SELECT 1 FROM tbl_user u
                    WHERE u.co_cd = p_co_cd AND u.usrgrp_cd = r.usrgrp_cd)
     LIMIT 1;
$$;
COMMENT ON FUNCTION sp_tbl_role_mgmt_delete_blocker_r_000(varchar, bigint[]) IS
  '권한그룹 삭제 차단 — 사용 중인 사용자 존재 시 불가. 위반 첫 건만 반환';

-- ------------------------------------------------------------
-- 4. sp_tbl_role_mgmt_d_000 — 권한그룹 삭제
--    통과하면 그룹에 딸린 화면권한 행까지 함께 정리한다(남겨도 참조할 주체가 없다)
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_role_mgmt_d_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 안전장치
    p_co_cd varchar,
    -- p_idx: 삭제 대상 tbl_role.idx
    p_idx   bigint
)
LANGUAGE plpgsql AS $$
DECLARE
    -- 삭제 대상 권한그룹코드. NULL이면 대상 없음
    v_usrgrp_cd varchar(20);
    -- 이 그룹을 쓰는 사용자 건수
    v_cnt       int;
BEGIN
    SELECT usrgrp_cd INTO v_usrgrp_cd FROM tbl_role WHERE co_cd = p_co_cd AND idx = p_idx;
    IF v_usrgrp_cd IS NULL THEN
        RAISE EXCEPTION '삭제할 권한그룹을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    SELECT COUNT(*) INTO v_cnt FROM tbl_user WHERE co_cd = p_co_cd AND usrgrp_cd = v_usrgrp_cd;
    IF v_cnt > 0 THEN
        RAISE EXCEPTION '사용자가 사용 중인 권한그룹은 삭제할 수 없습니다: %', v_usrgrp_cd USING ERRCODE = '45000';
    END IF;

    -- 그룹에 종속된 화면권한 설정을 먼저 정리한다
    DELETE FROM tbl_role_screen WHERE co_cd = p_co_cd AND usrgrp_cd = v_usrgrp_cd;
    DELETE FROM tbl_role        WHERE co_cd = p_co_cd AND idx = p_idx;
END$$;
COMMENT ON PROCEDURE sp_tbl_role_mgmt_d_000(varchar, bigint) IS
  '권한그룹 삭제 — 사용자 참조 차단 후 화면권한까지 함께 삭제';

-- ------------------------------------------------------------
-- 5. sp_tbl_role_mgmt_screen_r_000 — 권한그룹별 화면 권한
--    권한관리 화면 우측 매트릭스와 로그인 직후 버튼 권한 판정이 함께 쓴다
--    tbl_screen을 기준으로 잡아야 아직 설정하지 않은 화면도 N으로 표시된다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_role_mgmt_screen_r_000(varchar, varchar);
CREATE FUNCTION sp_tbl_role_mgmt_screen_r_000(
    -- p_co_cd: JWT 회사코드 — 권한 행 결합 범위
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
    SELECT rs.idx, s.scrn_cd, s.scrn_nm, s.module_cd,
           COALESCE(rs.read_yn,   'N'),
           COALESCE(rs.write_yn,  'N'),
           COALESCE(rs.modify_yn, 'N'),
           COALESCE(rs.delete_yn, 'N'),
           COALESCE(rs.print_yn,  'N'),
           s.sort_no
      FROM tbl_screen s
      -- 설정이 없으면 전 권한 N — 기본 거부
      LEFT JOIN tbl_role_screen rs
             ON rs.co_cd = p_co_cd AND rs.usrgrp_cd = p_usrgrp_cd AND rs.scrn_cd = s.scrn_cd
     WHERE s.use_yn = 'Y'
     ORDER BY s.sort_no, s.scrn_cd;
$$;
COMMENT ON FUNCTION sp_tbl_role_mgmt_screen_r_000(varchar, varchar) IS
  '권한그룹별 화면 권한 — 미설정 화면도 N으로 채워 전체 목록 반환';

-- ------------------------------------------------------------
-- 6. sp_tbl_role_mgmt_screen_c_000 — 화면 권한 1건 업서트
--    화면은 변경된 행만 모아 이 SP를 반복 호출한다(트랜잭션은 Spring이 잡는다)
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_role_mgmt_screen_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd     varchar,
    -- p_usrgrp_cd: 권한그룹코드
    p_usrgrp_cd varchar,
    -- p_scrn_cd: 화면코드 — tbl_screen.scrn_cd
    p_scrn_cd   varchar,
    -- p_read_yn: 조회 권한 Y/N — N이면 사이드바에서 메뉴 자체가 사라진다
    p_read_yn   varchar,
    -- p_write_yn: 등록 권한 Y/N
    p_write_yn  varchar,
    -- p_modify_yn: 수정 권한 Y/N
    p_modify_yn varchar,
    -- p_delete_yn: 삭제 권한 Y/N
    p_delete_yn varchar,
    -- p_print_yn: 출력 권한 Y/N
    p_print_yn  varchar,
    -- p_id: JWT 작업자 ID — 감사 컬럼
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
COMMENT ON PROCEDURE sp_tbl_role_mgmt_screen_c_000(varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar) IS
  '화면 권한 업서트 — 변경 행 단위 반복 호출용';
