-- ============================================================
--  migrate 63 — 메뉴 관리 화면 전용 SP + 사이드바 네비 SP 신설
--
--  개발자: 박승우
--  일자: 2026-08-12
--  코멘트:
--    1) 메뉴는 두 갈래로 쓰인다 — 관리화면(전체 목록)과 사이드바(권한 필터 트리)
--       쿼리가 서로 다르므로 한 SP로 합치지 않고 _mgmt_ 와 _nav_ 로 나눈다
--    2) 조회 R은 p_co_cd 필수 등가 + 페이지 헤더 파라미터 LIKE
--    3) 삭제 D는 하위 메뉴 존재를 다시 확인하고 위반이면 45000으로 올린다
--    4) 생성 전용 — 레거시 sp_tbl_menu_r_000·_admin_r_000·_c_000 DROP은 68에서 수행
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. sp_tbl_menu_mgmt_r_000 — 관리화면 메뉴 전체 목록
--    로그인 사용자의 조회권한으로 필터하지 않는다(관리자 화면)
--    좌측 트리가 전체 집합을 필요로 하므로 FE는 헤더 파라미터를 공백으로 호출하고 화면에서 다시 거른다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_menu_mgmt_r_000(varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_menu_mgmt_r_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위. 필수 등가 조건
    p_co_cd   varchar,
    -- p_menu_cd: 페이지 헤더 메뉴코드 검색어. 공백이면 전체
    p_menu_cd varchar,
    -- p_menu_nm: 페이지 헤더 메뉴명 검색어. 공백이면 전체
    p_menu_nm varchar,
    -- p_use_yn: 페이지 헤더 사용여부. 공백이면 Y·N 모두
    p_use_yn  varchar
)
RETURNS TABLE(
    idx       bigint,
    menu_cd   varchar,
    menu_nm   varchar,
    h_menu_cd varchar,
    scrn_cd   varchar,
    sort_no   int,
    use_yn    varchar
) LANGUAGE sql AS $$
    SELECT m.idx, m.menu_cd, m.menu_nm, m.h_menu_cd, m.scrn_cd, m.sort_no, m.use_yn
      FROM tbl_menu m
     WHERE m.co_cd = p_co_cd
       AND m.menu_cd LIKE CONCAT('%', COALESCE(p_menu_cd, ''), '%')
       AND m.menu_nm LIKE CONCAT('%', COALESCE(p_menu_nm, ''), '%')
       AND m.use_yn  LIKE CONCAT('%', COALESCE(p_use_yn,  ''), '%')
     -- 대·중·소 인코딩 sort_no 순 (1001 → 2101 → …) — FE 트리 조립 순서와 동일
     ORDER BY m.sort_no, m.menu_cd;
$$;
COMMENT ON FUNCTION sp_tbl_menu_mgmt_r_000(varchar, varchar, varchar, varchar) IS
  '메뉴 관리 목록 — 권한 필터 없음. 헤더 메뉴코드·명·사용여부 LIKE, sort_no 순';

-- ------------------------------------------------------------
-- 2. sp_tbl_menu_nav_r_000 — 사이드바 메뉴 트리 (권한 반영)
--    로그인 직후 1회 호출한다. 조회권한(read_yn)이 없는 화면은 아예 내려보내지 않는다
--    관리화면과 달리 use_yn='Y'만, 그리고 leaf는 권한이 있어야 통과한다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_menu_nav_r_000(varchar, varchar);
CREATE FUNCTION sp_tbl_menu_nav_r_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위. 필수 등가 조건
    p_co_cd     varchar,
    -- p_usrgrp_cd: JWT 권한그룹코드 — tbl_role_screen 결합 기준
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
      -- 화면 마스터 — module_cd 표기용
      LEFT JOIN tbl_screen s ON s.scrn_cd = m.scrn_cd
      -- 권한: 등록된 행이 없으면 접근 불가로 본다(기본 거부)
      LEFT JOIN tbl_role_screen rs
             ON rs.co_cd = m.co_cd AND rs.usrgrp_cd = p_usrgrp_cd AND rs.scrn_cd = m.scrn_cd
     WHERE m.co_cd  = p_co_cd
       AND m.use_yn = 'Y'
       -- 분류 노드(scrn_cd IS NULL)는 항상 통과, leaf는 조회권한이 있을 때만
       AND (m.scrn_cd IS NULL OR COALESCE(rs.read_yn, 'N') = 'Y')
     ORDER BY m.sort_no, m.menu_cd;
$$;
COMMENT ON FUNCTION sp_tbl_menu_nav_r_000(varchar, varchar) IS
  '사이드바 메뉴 트리 — 사용중 메뉴만, leaf는 조회권한 Y일 때만. sort_no 순';

-- ------------------------------------------------------------
-- 3. sp_tbl_menu_mgmt_c_000 — 메뉴 저장
--    메뉴코드·계층·화면코드는 화면에서 편집 불가라 실제로는 메뉴명·사용여부만 바뀐다
--    사용여부를 N으로 내리면 자손 메뉴도 전부 N으로 내려 트리에 고아 노드가 남지 않게 한다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_menu_mgmt_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd    varchar,
    -- p_idx: 수정 대상 대리키. 신규면 NULL (화면은 행추가를 막아 사실상 항상 값이 있다)
    p_idx      bigint,
    -- p_menu_cd: 업체 내 유일 메뉴코드
    p_menu_cd  varchar,
    -- p_menu_nm: 메뉴 표시명
    p_menu_nm  varchar,
    -- p_h_menu_cd: 상위 메뉴코드. 공백이면 루트
    p_h_menu_cd varchar,
    -- p_scrn_cd: 화면 leaf 코드. 공백이면 분류 노드
    p_scrn_cd  varchar,
    -- p_sort_no: 대중소 인코딩 정렬값
    p_sort_no  int,
    -- p_use_yn: 사용여부
    p_use_yn   varchar,
    -- p_id: JWT 작업자 ID — 감사 컬럼
    p_id       varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    -- 저장 후 자손 전파 기준이 되는 메뉴코드
    v_menu_cd varchar;
    -- 대문자로 정규화한 사용여부. Y·N 외 값은 Y로 본다
    v_use_yn  varchar;
BEGIN
    -- 메뉴명이 비면(= 화면이 값을 빠뜨림) 기존 이름을 공백으로 덮어써 사이드바가 비게 되므로 막는다
    IF COALESCE(trim(p_menu_nm), '') = '' THEN
        RAISE EXCEPTION '메뉴명은 필수입니다.' USING ERRCODE = '45000';
    END IF;

    v_use_yn := upper(COALESCE(NULLIF(trim(p_use_yn), ''), 'Y'));
    IF v_use_yn NOT IN ('Y', 'N') THEN v_use_yn := 'Y'; END IF;

    IF p_idx IS NULL THEN
        INSERT INTO tbl_menu(co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
        VALUES (p_co_cd, p_menu_cd, p_menu_nm, NULLIF(p_h_menu_cd, ''), NULLIF(p_scrn_cd, ''),
                COALESCE(p_sort_no, 0), v_use_yn, p_id, now());
        v_menu_cd := p_menu_cd;
    ELSE
        UPDATE tbl_menu
           SET menu_nm   = p_menu_nm,
               h_menu_cd = NULLIF(p_h_menu_cd, ''),
               scrn_cd   = NULLIF(p_scrn_cd, ''),
               sort_no   = COALESCE(p_sort_no, sort_no),
               use_yn    = v_use_yn,
               upd_id    = p_id, upd_dt = now()
         WHERE co_cd = p_co_cd AND idx = p_idx
        RETURNING menu_cd INTO v_menu_cd;
        IF NOT FOUND THEN
            RAISE EXCEPTION '수정할 메뉴를 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
    END IF;

    -- 사용여부 N일 때(= 미사용 전환) 모든 자손도 N — Y로 되돌릴 때는 자동 전파하지 않는다
    IF v_use_yn = 'N' AND COALESCE(v_menu_cd, '') <> '' THEN
        WITH RECURSIVE descendants AS (
            SELECT m.menu_cd
              FROM tbl_menu m
             WHERE m.co_cd = p_co_cd
               AND m.h_menu_cd = v_menu_cd
            UNION ALL
            SELECT c.menu_cd
              FROM tbl_menu c
              JOIN descendants d ON c.co_cd = p_co_cd AND c.h_menu_cd = d.menu_cd
        )
        UPDATE tbl_menu t
           SET use_yn = 'N', upd_id = p_id, upd_dt = now()
          FROM descendants d
         WHERE t.co_cd = p_co_cd
           AND t.menu_cd = d.menu_cd
           AND t.use_yn IS DISTINCT FROM 'N';
    END IF;
END$$;
COMMENT ON PROCEDURE sp_tbl_menu_mgmt_c_000(varchar, bigint, varchar, varchar, varchar, varchar, int, varchar, varchar) IS
  '메뉴 저장 — use_yn=N이면 자손 전체 N 전파. 메뉴코드는 화면에서 수정 불가';

-- ------------------------------------------------------------
-- 4. sp_tbl_menu_mgmt_delete_blocker_r_000 — 삭제 참조 검증
--    하위 메뉴가 남으면 트리가 끊기므로 차단한다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_menu_mgmt_delete_blocker_r_000(varchar, bigint[]);
CREATE FUNCTION sp_tbl_menu_mgmt_delete_blocker_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_idxs: 삭제 대상 대리키 배열
    p_idxs  bigint[]
)
RETURNS TABLE(ref_key varchar, target varchar) LANGUAGE sql AS $$
    SELECT m.menu_cd::varchar AS ref_key,
           '하위 메뉴'::varchar AS target
      FROM tbl_menu m
     WHERE m.co_cd = p_co_cd
       AND m.idx = ANY(p_idxs)
       AND EXISTS (SELECT 1 FROM tbl_menu c
                    WHERE c.co_cd = p_co_cd AND c.h_menu_cd = m.menu_cd)
     LIMIT 1;
$$;
COMMENT ON FUNCTION sp_tbl_menu_mgmt_delete_blocker_r_000(varchar, bigint[]) IS
  '메뉴 삭제 차단 — 하위 메뉴 보유 시 불가. 위반 첫 건만 반환';

-- ------------------------------------------------------------
-- 5. sp_tbl_menu_mgmt_d_000 — 메뉴 삭제
--    blocker와 같은 조건을 삭제 직전에 다시 본다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_menu_mgmt_d_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 안전장치
    p_co_cd varchar,
    -- p_idx: 삭제 대상 tbl_menu.idx
    p_idx   bigint
)
LANGUAGE plpgsql AS $$
DECLARE
    -- 삭제 대상 메뉴코드. NULL이면 대상 없음
    v_menu_cd varchar(50);
    -- 하위 메뉴 건수
    v_cnt     int;
BEGIN
    SELECT menu_cd INTO v_menu_cd FROM tbl_menu WHERE co_cd = p_co_cd AND idx = p_idx;
    IF v_menu_cd IS NULL THEN
        RAISE EXCEPTION '삭제할 메뉴를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    SELECT COUNT(*) INTO v_cnt FROM tbl_menu WHERE co_cd = p_co_cd AND h_menu_cd = v_menu_cd;
    IF v_cnt > 0 THEN
        RAISE EXCEPTION '하위 메뉴가 있어 삭제할 수 없습니다: %', v_menu_cd USING ERRCODE = '45000';
    END IF;

    DELETE FROM tbl_menu WHERE co_cd = p_co_cd AND idx = p_idx;
END$$;
COMMENT ON PROCEDURE sp_tbl_menu_mgmt_d_000(varchar, bigint) IS
  '메뉴 삭제 — 미존재·하위 메뉴 보유 차단 후 삭제';
