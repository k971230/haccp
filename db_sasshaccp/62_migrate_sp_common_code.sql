-- ============================================================
--  migrate 62 — 공통코드 관리 화면 전용 SP 신설
--
--  개발자: 박승우
--  일자: 2026-08-12
--  코멘트:
--    1) sp_tbl_system_c_000/_d_000 허브를 걷어내고 화면(common-code-management) 이름의 SP로 분리한다
--    2) 조회 R은 p_co_cd를 필수 등가 조건으로 두고, 그 뒤 페이지 헤더 파라미터만 LIKE로 건다
--    3) 삭제 D는 삭제 전에 참조(시스템 코드 여부)를 다시 확인하고 위반이면 45000으로 올린다
--    4) 이 파일은 생성 전용이다 — 레거시 sp_tbl_code_* DROP은 68에서 따로 수행한다
--
--  적용 순서: 62~67 생성 → BE/FE 교체 → 회귀 통과 → 68 DROP
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. sp_tbl_common_code_r_000 — 대분류 목록 (좌측 그리드)
--    tbl_code에서 sub_cd='*' 행만 대분류로 취급한다
--    플랫폼 표준(0000)과 업체 코드를 합치되 같은 main_cd가 양쪽에 있으면 업체 행만 남긴다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_common_code_r_000(varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_common_code_r_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위. 필수 등가 조건
    p_co_cd   varchar,
    -- p_main_cd: 페이지 헤더 대분류코드 검색어. 공백이면(= 조건 없음) 전체
    p_main_cd varchar,
    -- p_code_nm: 페이지 헤더 대분류명 검색어. 공백이면 전체
    p_code_nm varchar
)
RETURNS TABLE(
    idx     bigint,
    co_cd   varchar,
    main_cd varchar,
    sub_cd  varchar,
    code_nm varchar,
    sort_no int,
    sys_yn  varchar,
    use_yn  varchar
) LANGUAGE sql AS $$
    SELECT c.idx, c.co_cd, c.main_cd, c.sub_cd, c.code_nm, c.sort_no, c.sys_yn, c.use_yn
      FROM tbl_code c
     -- 테넌트 + 플랫폼 표준 두 범위만 읽는다
     WHERE c.co_cd IN (p_co_cd, '0000')
       AND c.sub_cd = '*'
       -- 헤더 파라미터 — 부분 일치, 공백이면 전체
       AND c.main_cd LIKE CONCAT('%', COALESCE(p_main_cd, ''), '%')
       AND c.code_nm LIKE CONCAT('%', COALESCE(p_code_nm, ''), '%')
       -- 표준·업체에 같은 대분류가 있으면 업체 행만 남긴다
       AND NOT (c.co_cd = '0000' AND EXISTS (
                SELECT 1 FROM tbl_code o
                 WHERE o.co_cd = p_co_cd AND o.main_cd = c.main_cd AND o.sub_cd = '*'))
     ORDER BY c.main_cd, c.sort_no;
$$;
COMMENT ON FUNCTION sp_tbl_common_code_r_000(varchar, varchar, varchar) IS
  '공통코드 대분류 목록 — sub_cd=*, 플랫폼(0000)+업체 병합, 헤더 대분류코드·명 LIKE';

-- ------------------------------------------------------------
-- 2. sp_tbl_common_code_r_001 — 세부코드 목록
--    공통코드 관리 화면의 시스템·사용자 그리드와, 전 화면 콤보(CodeMapper.selectCodes)가 함께 쓴다
--    p_main_cd는 정확 일치다 — 콤보는 대분류를 정확히 넘기고, 부분 일치면 다른 그룹이 섞인다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_common_code_r_001(varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_common_code_r_001(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위. 필수 등가 조건
    p_co_cd   varchar,
    -- p_main_cd: 대분류코드. 공백이면(= 전체 그룹) 모든 세부코드
    p_main_cd varchar,
    -- p_sys_yn: 시스템/사용자 구분. Y·sys=시스템, N·usr=사용자, 공백이면 둘 다
    p_sys_yn  varchar,
    -- p_use_yn: 사용여부 필터. 공백이면 Y·N 모두 (콤보는 'Y'로 호출)
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
       -- 대분류 헤더 — 값이 있으면 정확 일치
       AND (COALESCE(p_main_cd, '') = '' OR c.main_cd = p_main_cd)
       -- 대분류 헤더 행(sub_cd='*')은 세부 목록에서 제외
       AND c.sub_cd <> '*'
       AND c.use_yn LIKE CONCAT('%', COALESCE(p_use_yn, ''), '%')
       -- sys_yn은 과거 데이터가 Y/N과 sys/usr 두 표기를 함께 쓰므로 양쪽을 모두 허용한다
       AND (
            COALESCE(p_sys_yn, '') = ''
            OR (p_sys_yn IN ('Y', 'sys') AND c.sys_yn IN ('Y', 'sys'))
            OR (p_sys_yn IN ('N', 'usr') AND c.sys_yn IN ('N', 'usr'))
           )
       -- 표준·업체 중복이면 업체 행만 남긴다
       AND NOT (c.co_cd = '0000' AND EXISTS (
                SELECT 1 FROM tbl_code o
                 WHERE o.co_cd = p_co_cd AND o.main_cd = c.main_cd AND o.sub_cd = c.sub_cd))
     ORDER BY c.main_cd, c.sort_no, c.sub_cd;
$$;
COMMENT ON FUNCTION sp_tbl_common_code_r_001(varchar, varchar, varchar, varchar) IS
  '공통코드 세부 목록 — 관리화면 시스템/사용자 그리드 + 전 화면 콤보 공용. main_cd 정확 일치';

-- ------------------------------------------------------------
-- 3. sp_tbl_common_code_c_000 — 세부코드 저장 (등록/수정)
--    플랫폼 표준(sys_yn=Y)은 코드명·사용여부만 바꿀 수 있고, 0000 행이면 업체 행으로 복제해 덮어쓴다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_common_code_c_000(
    -- p_co_cd: JWT 회사코드 — 저장은 항상 업체 코드로만 이뤄진다
    p_co_cd   varchar,
    -- p_idx: 수정 대상 대리키. 신규면 NULL
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
    -- p_id: JWT 작업자 ID — 감사 컬럼
    p_id      varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    -- 수정 대상의 시스템코드 여부
    v_sys_yn varchar(10);
    -- 수정 대상이 속한 회사코드 — 0000이면 업체 오버라이드 경로
    v_co     varchar(10);
    -- 중복 검사 건수
    v_cnt    int;
    -- Y/sys 표기를 하나로 묶은 시스템코드 판정
    v_is_sys boolean;
BEGIN
    IF p_co_cd = '0000' THEN
        RAISE EXCEPTION '플랫폼 표준코드 회사로는 저장할 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    -- 코드명이 비면(= 화면이 값을 빠뜨림) 기존 이름을 공백으로 덮어쓰게 되므로 막는다
    IF COALESCE(trim(p_code_nm), '') = '' THEN
        RAISE EXCEPTION '코드명은 필수입니다.' USING ERRCODE = '45000';
    END IF;

    -- p_idx가 NULL일 때(= 신규 행) 업무키 중복부터 막는다
    IF p_idx IS NULL THEN
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

    -- 수정 대상 확인 — 업체 행이 있으면 업체 행을 우선한다
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
            -- 플랫폼 표준을 업체 행으로 복제 — 이후 이 업체는 자기 문구를 쓴다
            INSERT INTO tbl_code(co_cd, main_cd, sub_cd, code_nm, sort_no, ref1, ref2, sys_yn, use_yn, ins_id, ins_dt)
            SELECT p_co_cd, c.main_cd, c.sub_cd, COALESCE(NULLIF(p_code_nm, ''), c.code_nm),
                   c.sort_no, c.ref1, c.ref2, c.sys_yn,
                   COALESCE(NULLIF(p_use_yn, ''), c.use_yn), p_id, now()
              FROM tbl_code c WHERE c.idx = p_idx
            ON CONFLICT (co_cd, main_cd, sub_cd) DO UPDATE SET
                code_nm = EXCLUDED.code_nm, use_yn = EXCLUDED.use_yn, upd_id = p_id, upd_dt = now();
        ELSE
            -- 이미 업체가 가진 시스템코드 — 코드명·사용여부만 허용
            UPDATE tbl_code
               SET code_nm = COALESCE(NULLIF(p_code_nm, ''), code_nm),
                   use_yn  = COALESCE(NULLIF(p_use_yn, ''), use_yn),
                   upd_id  = p_id, upd_dt = now()
             WHERE co_cd = p_co_cd AND idx = p_idx;
        END IF;
        RETURN;
    END IF;

    -- 사용자 코드인데 다른 회사 행이면(= 테넌트 위반) 없는 것으로 처리한다
    IF v_co <> p_co_cd THEN
        RAISE EXCEPTION '수정할 코드를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    UPDATE tbl_code
       SET code_nm = p_code_nm,
           sort_no = COALESCE(p_sort_no, sort_no),
           ref1    = p_ref1,
           ref2    = p_ref2,
           use_yn  = COALESCE(NULLIF(p_use_yn, ''), use_yn),
           upd_id  = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND idx = p_idx;
END$$;
COMMENT ON PROCEDURE sp_tbl_common_code_c_000(varchar, bigint, varchar, varchar, varchar, int, varchar, varchar, varchar, varchar) IS
  '공통코드 저장 — 신규는 업무키 중복 검사, 시스템코드는 코드명·사용여부만(0000은 업체 복제)';

-- ------------------------------------------------------------
-- 4. sp_tbl_common_code_delete_blocker_r_000 — 삭제 참조 검증
--    FE validate-delete와 BE delete 직전 Double Check가 같은 함수를 쓴다
--    공통코드는 하위 테이블 FK가 없으므로 시스템코드 여부만 차단 사유가 된다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_common_code_delete_blocker_r_000(varchar, bigint[]);
CREATE FUNCTION sp_tbl_common_code_delete_blocker_r_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위
    p_co_cd varchar,
    -- p_idxs: 삭제 대상 대리키 배열. UI 단건이어도 배열로 받는다
    p_idxs  bigint[]
)
RETURNS TABLE(ref_key varchar, target varchar) LANGUAGE sql AS $$
    SELECT c.sub_cd::varchar AS ref_key,
           '시스템 코드'::varchar AS target
      FROM tbl_code c
     WHERE c.co_cd = p_co_cd
       AND c.idx = ANY(p_idxs)
       AND c.sys_yn IN ('Y', 'y', 'sys')
     LIMIT 1;
$$;
COMMENT ON FUNCTION sp_tbl_common_code_delete_blocker_r_000(varchar, bigint[]) IS
  '공통코드 삭제 차단 — 시스템코드는 삭제 불가. 위반 첫 건만 반환';

-- ------------------------------------------------------------
-- 5. sp_tbl_common_code_d_000 — 세부코드 삭제
--    blocker와 같은 조건을 삭제 직전에 한 번 더 본다 (Double Check의 DB 측 마지막 관문)
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_common_code_d_000(
    -- p_co_cd: JWT 회사코드 — 다른 업체 코드를 지우지 못하게 하는 안전장치
    p_co_cd varchar,
    -- p_idx: 삭제 대상 tbl_code.idx
    p_idx   bigint
)
LANGUAGE plpgsql AS $$
DECLARE
    -- 삭제 대상의 시스템코드 여부. NULL이면 대상 없음
    v_sys_yn varchar(10);
BEGIN
    SELECT sys_yn INTO v_sys_yn FROM tbl_code WHERE co_cd = p_co_cd AND idx = p_idx;
    IF v_sys_yn IS NULL THEN
        RAISE EXCEPTION '삭제할 코드를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF v_sys_yn IN ('Y', 'y', 'sys') THEN
        RAISE EXCEPTION '시스템 코드는 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    DELETE FROM tbl_code WHERE co_cd = p_co_cd AND idx = p_idx;
END$$;
COMMENT ON PROCEDURE sp_tbl_common_code_d_000(varchar, bigint) IS
  '공통코드 삭제 — 미존재·시스템코드 차단 후 삭제';
