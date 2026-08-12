-- ============================================================
-- 53 — 미사용 메뉴 삭제 · sort_no 대·중·소 인코딩(1001~9999)
--
-- 개발자: 박승우
-- 일자: 2026-08-12
-- 코멘트:
--   1) use_yn=N 메뉴 행을 물리 삭제한다
--   2) sort_no = 대(1~9)*1000 + 중(0~9)*100 + 소(0~99) — 오늘할일 1001, 문서작성 2xxx …
--   3) 메뉴 조회 ORDER BY 는 sort_no(인코딩)만 사용한다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 미사용 메뉴 삭제
-- ------------------------------------------------------------
DELETE FROM tbl_menu WHERE use_yn = 'N';

-- ------------------------------------------------------------
-- 2. 정렬 인코딩 프로시저 — 업체 단위 또는 전 업체
--    sort_no = 대*1000 + 중*100 + 소
--    대: 1오늘할일 2문서작성 3문서현황결재 4문서기준관리 5기초정보 6시스템
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_menu_sort_encode_u_000(
    -- p_co_cd: NULL이면 전 업체, 값이면 해당 업체만
    p_co_cd varchar DEFAULT NULL
)
LANGUAGE plpgsql AS $$
BEGIN
    -- 대·중 폴더·오늘할일 고정코드
    UPDATE tbl_menu m
       SET sort_no = v.sn,
           upd_id = 'system',
           upd_dt = now()
      FROM (VALUES
        ('today-tasks',        1001),
        ('menu-doc-write',     2000),
        ('menu-doc-flow',      3000),
        ('menu-doc-master',    4000),
        ('menu-base',          5000),
        ('menu-sys',           6000),
        ('menu-write-ccp',     2100),
        ('menu-write-prp',     2200),
        ('menu-write-logis',   2300),
        ('menu-write-admin',   2400),
        ('menu-flow-appr',     3100),
        ('menu-flow-box',      3200),
        ('menu-flow-ca',       3300),
        ('menu-master-doc',    4100),
        ('menu-master-form',   4200),
        ('menu-master-item',   4300),
        ('menu-master-appr',   4400),
        ('menu-base-master',   5100),
        ('menu-sys-auth',      6100),
        ('menu-sys-log',       6200)
      ) AS v(menu_cd, sn)
     WHERE m.menu_cd = v.menu_cd
       AND m.use_yn = 'Y'
       AND (p_co_cd IS NULL OR m.co_cd = p_co_cd);

    -- 소분류: 중 아래 1~99 — 메뉴명·코드 순으로 채번
    WITH mid AS (
        SELECT * FROM (VALUES
            ('menu-write-ccp',   2, 1),
            ('menu-write-prp',   2, 2),
            ('menu-write-logis', 2, 3),
            ('menu-write-admin', 2, 4),
            ('menu-flow-appr',   3, 1),
            ('menu-flow-box',    3, 2),
            ('menu-flow-ca',     3, 3),
            ('menu-master-doc',  4, 1),
            ('menu-master-form', 4, 2),
            ('menu-master-item', 4, 3),
            ('menu-master-appr', 4, 4),
            ('menu-base-master', 5, 1),
            ('menu-sys-auth',    6, 1),
            ('menu-sys-log',     6, 2)
        ) AS t(mid_cd, dae_no, jung_no)
    ),
    ranked AS (
        SELECT m.co_cd,
               m.menu_cd,
               (mid.dae_no * 1000
                 + mid.jung_no * 100
                 + ROW_NUMBER() OVER (
                       PARTITION BY m.co_cd, m.h_menu_cd
                       ORDER BY m.menu_nm, m.menu_cd
                   ))::int AS sn
          FROM tbl_menu m
          JOIN mid ON mid.mid_cd = m.h_menu_cd
         WHERE m.use_yn = 'Y'
           AND m.scrn_cd IS NOT NULL
           AND (p_co_cd IS NULL OR m.co_cd = p_co_cd)
    )
    UPDATE tbl_menu m
       SET sort_no = r.sn,
           upd_id = 'system',
           upd_dt = now()
      FROM ranked r
     WHERE m.co_cd = r.co_cd
       AND m.menu_cd = r.menu_cd;
END;
$$;
COMMENT ON PROCEDURE sp_tbl_menu_sort_encode_u_000(varchar) IS
  '메뉴 sort_no 인코딩 — 대(1~9)*1000+중(0~9)*100+소(0~99). p_co_cd NULL=전업체';

CALL sp_tbl_menu_sort_encode_u_000(NULL);

-- ------------------------------------------------------------
-- 3. 사이드·관리 메뉴 조회 — sort_no(대중소 인코딩) 순
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_menu_r_000(
    p_co_cd     varchar,
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
      LEFT JOIN tbl_role_screen rs
             ON rs.co_cd = m.co_cd AND rs.usrgrp_cd = p_usrgrp_cd AND rs.scrn_cd = m.scrn_cd
     WHERE m.co_cd  = p_co_cd
       AND m.use_yn = 'Y'
       AND (m.scrn_cd IS NULL OR COALESCE(rs.read_yn, 'N') = 'Y')
     -- 대·중·소 인코딩 sort_no 순 (1001 → 2101 → …)
     ORDER BY m.sort_no, m.menu_cd;
$$;
COMMENT ON FUNCTION sp_tbl_menu_r_000(varchar, varchar) IS '권한 반영 메뉴 트리 — sort_no(대중소 인코딩) 순';

CREATE OR REPLACE FUNCTION sp_tbl_menu_admin_r_000(
    p_co_cd varchar
) RETURNS TABLE(idx bigint, menu_cd varchar, menu_nm varchar, h_menu_cd varchar, scrn_cd varchar, sort_no int, use_yn varchar)
LANGUAGE sql AS $$
    SELECT m.idx, m.menu_cd, m.menu_nm, m.h_menu_cd, m.scrn_cd, m.sort_no, m.use_yn
      FROM tbl_menu m WHERE m.co_cd = p_co_cd
     -- 대·중·소 인코딩 sort_no 순
     ORDER BY m.sort_no, m.menu_cd;
$$;
COMMENT ON FUNCTION sp_tbl_menu_admin_r_000(varchar) IS '관리자용 메뉴 전체 목록 — sort_no(대중소 인코딩) 순';
