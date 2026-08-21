-- ============================================================
-- 118 — 메뉴 중분류 코드를 URL 슬러그와 맞춤
--
-- 파일번호: 118
-- 이전번호: 117
-- 개발자: 박승우
-- 일자: 2026-08-21
-- 코멘트:
--   1) 중분류 3건만 개명한다. menu-doc-master(대)는 그대로. menu-master-doc(중)만 menu-master-sch
--   2) h_menu_cd 는 varchar 코드라 FK 가 없다. 부모 menu_cd 먼저, 자식 h_menu_cd 나중
--   3) tbl_screen · leaf menu_cd · 화면권한은 건드리지 않는다. URL 정본은 FE tabRoute
--
-- Jenkins는 migrate를 안 돌린다. DBeaver/수동
-- ============================================================

SET search_path TO sasshaccp;

-- 1) 전 테넌트 중분류 menu_cd 개명 — 부모 먼저
-- menu-master-doc(중, 작성 문서·주기) → menu-master-sch. 대분류 menu-doc-master 는 그대로
UPDATE tbl_menu SET menu_cd = 'menu-master-sch', upd_id = 'system', upd_dt = now()
 WHERE menu_cd = 'menu-master-doc';
UPDATE tbl_menu SET menu_cd = 'menu-sys-code', upd_id = 'system', upd_dt = now()
 WHERE menu_cd = 'menu-sys-auth';
UPDATE tbl_menu SET menu_cd = 'menu-sys-logs', upd_id = 'system', upd_dt = now()
 WHERE menu_cd = 'menu-sys-log';

-- 2) leaf 부모 참조만 이동
UPDATE tbl_menu SET h_menu_cd = 'menu-master-sch', upd_id = 'system', upd_dt = now()
 WHERE h_menu_cd = 'menu-master-doc';
UPDATE tbl_menu SET h_menu_cd = 'menu-sys-code', upd_id = 'system', upd_dt = now()
 WHERE h_menu_cd = 'menu-sys-auth';
UPDATE tbl_menu SET h_menu_cd = 'menu-sys-logs', upd_id = 'system', upd_dt = now()
 WHERE h_menu_cd = 'menu-sys-log';

-- 3) sort 인코딩 SP — 13·21 과 동일. 결재선 leaf 6번 추가
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
        ('menu-master-sch', 4100), ('menu-master-form', 4200),
        ('menu-master-html', 4250),
        ('menu-master-item', 4300), ('menu-master-appr', 4400),
        ('menu-base-master', 5100),
        ('menu-sys-code', 6100), ('menu-sys-logs', 6200)
      ) AS v(menu_cd, sn)
     WHERE m.menu_cd = v.menu_cd
       AND m.use_yn = 'Y'
       AND (p_co_cd IS NULL OR m.co_cd = p_co_cd);

    -- menu-sys-code leaf: 공통코드 → 메뉴 → 권한그룹 → 부서 → 사용자 → 결재선
    UPDATE tbl_menu m
       SET sort_no = v.ord, upd_id = 'system', upd_dt = now()
      FROM (VALUES
        ('common-code-management', 1),
        ('menu-management', 2),
        ('role-management', 3),
        ('department-management', 4),
        ('user-management', 5),
        ('approval-line-management', 6)
      ) AS v(scrn_cd, ord)
     WHERE m.scrn_cd = v.scrn_cd
       AND m.h_menu_cd = 'menu-sys-code'
       AND m.use_yn = 'Y'
       AND (p_co_cd IS NULL OR m.co_cd = p_co_cd);

    WITH mid AS (
        SELECT * FROM (VALUES
            ('menu-write-ccp', 2, 1), ('menu-write-prp', 2, 2),
            ('menu-write-logis', 2, 3), ('menu-write-admin', 2, 4),
            ('menu-flow-appr', 3, 1), ('menu-flow-box', 3, 2), ('menu-flow-ca', 3, 3),
            ('menu-master-sch', 4, 1), ('menu-master-form', 4, 2),
            ('menu-master-html', 4, 3),
            ('menu-master-item', 4, 4), ('menu-master-appr', 4, 5),
            ('menu-base-master', 5, 1),
            ('menu-sys-code', 6, 1), ('menu-sys-logs', 6, 2)
        ) AS t(mid_cd, dae_no, jung_no)
    ),
    ranked AS (
        SELECT m.co_cd, m.menu_cd,
               (CASE
                    WHEN mid.mid_cd = 'menu-master-html' THEN 4250
                    ELSE mid.dae_no * 1000 + mid.jung_no * 100
                END
                 + ROW_NUMBER() OVER (
                       PARTITION BY m.co_cd, m.h_menu_cd
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

-- 4) 전 테넌트 재인코딩 — p_co_cd NULL 이면 전 업체
CALL sp_tbl_menu_sort_encode_u_000(NULL);
