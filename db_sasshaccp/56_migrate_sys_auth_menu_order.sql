-- ============================================================
-- 56 — 시스템(menu-sys-auth) leaf 메뉴 표시 순서
--
-- 개발자: 박승우
-- 일자: 2026-08-12
-- 코멘트:
--   1) 공통코드 → 메뉴 → 권한그룹 → 부서 → 사용자 순으로 맞춘다
--   2) sort 인코딩 SP가 seed sort_no 상대순을 보존하도록 수정한다
--   3) 전 업체에 인코딩을 재적용한다
-- ============================================================

SET search_path TO sasshaccp;

-- 소분류 인코딩 시 기존 sort_no 상대순 유지 (메뉴명 가나다 정렬 폐기)
CREATE OR REPLACE PROCEDURE sp_tbl_menu_sort_encode_u_000(
    -- p_co_cd: NULL이면 전 업체, 값이면 해당 업체만
    p_co_cd varchar DEFAULT NULL
)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE tbl_menu m
       SET sort_no = v.sn, upd_id = 'system', upd_dt = now()
      FROM (VALUES
        ('today-tasks', 1001),
        ('menu-doc-write', 2000), ('menu-doc-flow', 3000), ('menu-doc-master', 4000),
        ('menu-base', 5000), ('menu-sys', 6000),
        ('menu-write-ccp', 2100), ('menu-write-prp', 2200),
        ('menu-write-logis', 2300), ('menu-write-admin', 2400),
        ('menu-flow-appr', 3100), ('menu-flow-box', 3200), ('menu-flow-ca', 3300),
        ('menu-master-doc', 4100), ('menu-master-form', 4200),
        ('menu-master-item', 4300), ('menu-master-appr', 4400),
        ('menu-base-master', 5100),
        ('menu-sys-auth', 6100), ('menu-sys-log', 6200)
      ) AS v(menu_cd, sn)
     WHERE m.menu_cd = v.menu_cd
       AND m.use_yn = 'Y'
       AND (p_co_cd IS NULL OR m.co_cd = p_co_cd);

    -- menu-sys-auth leaf 상대 순서 (인코딩 전 seed)
    UPDATE tbl_menu m
       SET sort_no = v.ord,
           upd_id = 'system',
           upd_dt = now()
      FROM (VALUES
        ('common-code-management', 1),
        ('menu-management', 2),
        ('role-management', 3),
        ('department-management', 4),
        ('user-management', 5)
      ) AS v(scrn_cd, ord)
     WHERE m.scrn_cd = v.scrn_cd
       AND m.h_menu_cd = 'menu-sys-auth'
       AND m.use_yn = 'Y'
       AND (p_co_cd IS NULL OR m.co_cd = p_co_cd);

    WITH mid AS (
        SELECT * FROM (VALUES
            ('menu-write-ccp', 2, 1), ('menu-write-prp', 2, 2),
            ('menu-write-logis', 2, 3), ('menu-write-admin', 2, 4),
            ('menu-flow-appr', 3, 1), ('menu-flow-box', 3, 2), ('menu-flow-ca', 3, 3),
            ('menu-master-doc', 4, 1), ('menu-master-form', 4, 2),
            ('menu-master-item', 4, 3), ('menu-master-appr', 4, 4),
            ('menu-base-master', 5, 1),
            ('menu-sys-auth', 6, 1), ('menu-sys-log', 6, 2)
        ) AS t(mid_cd, dae_no, jung_no)
    ),
    ranked AS (
        SELECT m.co_cd, m.menu_cd,
               (mid.dae_no * 1000 + mid.jung_no * 100
                 + ROW_NUMBER() OVER (
                       PARTITION BY m.co_cd, m.h_menu_cd
                       -- seed·사전 지정 sort_no 상대순 유지
                       ORDER BY m.sort_no, m.menu_cd
                   ))::int AS sn
          FROM tbl_menu m
          JOIN mid ON mid.mid_cd = m.h_menu_cd
         WHERE m.use_yn = 'Y'
           AND m.scrn_cd IS NOT NULL
           AND (p_co_cd IS NULL OR m.co_cd = p_co_cd)
    )
    UPDATE tbl_menu m
       SET sort_no = r.sn, upd_id = 'system', upd_dt = now()
      FROM ranked r
     WHERE m.co_cd = r.co_cd AND m.menu_cd = r.menu_cd;
END;
$$;
COMMENT ON PROCEDURE sp_tbl_menu_sort_encode_u_000(varchar) IS
  '메뉴 sort_no 인코딩 — 대(1~9)*1000+중(0~9)*100+소(0~99). leaf는 sort_no 상대순. p_co_cd NULL=전업체';

CALL sp_tbl_menu_sort_encode_u_000(NULL);
