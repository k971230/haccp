-- ============================================================
-- 120 — 대/중/소 menu_cd 를 URL 슬러그와 1:1 로 맞춘다
--
-- 파일번호: 120
-- 이전번호: 119
-- 개발자: 박승우
-- 일자: 2026-08-21
-- 코멘트:
--   1) URL SCREEN_PATH 칸이 정본이다. 대 docs/flow/bas/sys, 중 hwp/ccp/code 등, 소 leaf = scrn_cd
--   2) UNIQUE (co_cd, menu_cd) 때문에 두 대분류를 동시에 docs 로 UPDATE 하지 않는다
--      한쪽을 개명하고 자식을 재부모한 뒤 빈 행을 지운다. FK 는 없다 (h_menu_cd varchar)
--   3) 118·119 미적용 DB 도 구 이름(form/auth/log/doc)을 받아 한 방으로 덮는다
--      tbl_role_screen 은 scrn_cd 기준이라 권한 행은 그대로다
--
-- Jenkins는 migrate를 안 돌린다. DBeaver/수동. 이력 52·99·118·119 는 고치지 않는다
-- ============================================================

SET search_path TO sasshaccp;

BEGIN;

-- 구 코드 → 신 슬러그. 대상이 이미 있으면 자식만 옮기고 구 폴더 행을 지운다
CREATE OR REPLACE PROCEDURE sp_tmp_rename_menu(
    -- p_old: 구 menu_cd
    p_old varchar,
    -- p_new: URL 슬러그
    p_new varchar,
    -- p_nm: 표시명을 덮을 때 값. NULL 이면 이름 유지
    p_nm varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    -- 이미 신 코드가 있는 테넌트는 표시명만 맞춘다
    IF p_nm IS NOT NULL THEN
        UPDATE tbl_menu
           SET menu_nm = p_nm, upd_id = 'system', upd_dt = now()
         WHERE menu_cd = p_new
           AND menu_nm IS DISTINCT FROM p_nm;
    END IF;

    -- 신 코드가 없는 테넌트만 부모 행을 개명한다
    UPDATE tbl_menu o
       SET menu_cd = p_new,
           menu_nm = COALESCE(p_nm, o.menu_nm),
           upd_id = 'system',
           upd_dt = now()
     WHERE o.menu_cd = p_old
       AND NOT EXISTS (
           SELECT 1 FROM tbl_menu n
            WHERE n.co_cd = o.co_cd
              AND n.menu_cd = p_new
       );

    -- 자식 h_menu_cd 를 신 코드로 옮긴다
    UPDATE tbl_menu
       SET h_menu_cd = p_new, upd_id = 'system', upd_dt = now()
     WHERE h_menu_cd = p_old;

    -- 개명에 실패한 구 폴더 행(화면 없는 분류)만 제거한다
    DELETE FROM tbl_menu
     WHERE menu_cd = p_old
       AND COALESCE(scrn_cd, '') = '';
END;
$$;

-- 1) 대분류 — write+master 를 docs 로 합친 뒤 flow/bas/sys
CALL sp_tmp_rename_menu('menu-doc-write',  'docs', '문서');
CALL sp_tmp_rename_menu('menu-doc-master', 'docs', '문서');
CALL sp_tmp_rename_menu('menu-doc-flow',   'flow', NULL);
CALL sp_tmp_rename_menu('menu-base',       'bas',  NULL);
CALL sp_tmp_rename_menu('menu-sys',        'sys',  NULL);

-- 2) 중분류 — 부모 menu_cd 개명 후 절차가 자식 h_menu_cd 를 따라간다
CALL sp_tmp_rename_menu('menu-write-ccp',     'ccp',         NULL);
CALL sp_tmp_rename_menu('menu-write-prp',     'prp',         NULL);
CALL sp_tmp_rename_menu('menu-write-logis',   'logis',       NULL);
CALL sp_tmp_rename_menu('menu-write-admin',   'admin',       NULL);
CALL sp_tmp_rename_menu('menu-flow-appr',     'appr',        NULL);
CALL sp_tmp_rename_menu('menu-flow-box',      'box',         NULL);
CALL sp_tmp_rename_menu('menu-flow-ca',       'ca',          NULL);
CALL sp_tmp_rename_menu('menu-master-doc',    'sch',         NULL);
CALL sp_tmp_rename_menu('menu-master-sch',    'sch',         NULL);
CALL sp_tmp_rename_menu('menu-master-form',   'hwp',         NULL);
CALL sp_tmp_rename_menu('menu-master-hwp',    'hwp',         NULL);
CALL sp_tmp_rename_menu('menu-master-html',   'html',        NULL);
CALL sp_tmp_rename_menu('menu-base-master',   'master',      NULL);
CALL sp_tmp_rename_menu('menu-sys-auth',      'code',        NULL);
CALL sp_tmp_rename_menu('menu-sys-code',      'code',        NULL);
CALL sp_tmp_rename_menu('menu-sys-log',       'logs',        NULL);
CALL sp_tmp_rename_menu('menu-sys-logs',      'logs',        NULL);
-- 숨김 결재선 중분류 — flow 의 appr 과 겹치지 않게 appr-hidden
CALL sp_tmp_rename_menu('menu-master-appr',   'appr-hidden', NULL);

-- 3) 구 점검항목 중분류 — URL 이 /docs/prp/ 인 설비·방충 leaf 만 prp 로 붙인다
UPDATE tbl_menu
   SET h_menu_cd = 'prp', upd_id = 'system', upd_dt = now()
 WHERE h_menu_cd = 'menu-master-item'
    OR (scrn_cd IN ('equipment-management', 'pest-device-management')
        AND COALESCE(h_menu_cd, '') IN ('menu-master-item', 'item'));

DELETE FROM tbl_menu
 WHERE menu_cd = 'menu-master-item'
   AND COALESCE(scrn_cd, '') = '';

-- 숨김 중분류 부모는 문서 대분류
UPDATE tbl_menu
   SET h_menu_cd = 'docs', use_yn = 'N', upd_id = 'system', upd_dt = now()
 WHERE menu_cd = 'appr-hidden';

-- 4) 소 leaf — menu-{scrn_cd} → scrn_cd. 이미 슬러그 행이 있으면 접두 행만 지운다
DELETE FROM tbl_menu a
      USING tbl_menu b
 WHERE a.co_cd = b.co_cd
   AND a.scrn_cd IS NOT NULL
   AND a.menu_cd = 'menu-' || a.scrn_cd
   AND b.menu_cd = a.scrn_cd;

UPDATE tbl_menu
   SET menu_cd = scrn_cd, upd_id = 'system', upd_dt = now()
 WHERE scrn_cd IS NOT NULL
   AND menu_cd = 'menu-' || scrn_cd;

DROP PROCEDURE sp_tmp_rename_menu(varchar, varchar, varchar);

-- 5) sort 인코딩 SP — 13·21 과 동일. 118·119 정의를 슬러그로 교체한다
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
        ('docs', 2000), ('flow', 3000), ('bas', 5000), ('sys', 6000),
        ('ccp', 2100), ('prp', 2200), ('logis', 2300), ('admin', 2400),
        ('sch', 2500), ('hwp', 2600), ('html', 2700), ('appr-hidden', 2800),
        ('appr', 3100), ('box', 3200), ('ca', 3300),
        ('master', 5100),
        ('code', 6100), ('logs', 6200)
      ) AS v(menu_cd, sn)
     WHERE m.menu_cd = v.menu_cd
       AND m.use_yn = 'Y'
       AND (p_co_cd IS NULL OR m.co_cd = p_co_cd);

    -- sys/code leaf: 공통코드 → 메뉴 → 권한그룹 → 부서 → 사용자 → 결재선
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
       AND m.h_menu_cd = 'code'
       AND m.use_yn = 'Y'
       AND (p_co_cd IS NULL OR m.co_cd = p_co_cd);

    WITH mid AS (
        SELECT * FROM (VALUES
            ('ccp', 2, 1), ('prp', 2, 2),
            ('logis', 2, 3), ('admin', 2, 4),
            ('sch', 2, 5), ('hwp', 2, 6), ('html', 2, 7), ('appr-hidden', 2, 8),
            ('appr', 3, 1), ('box', 3, 2), ('ca', 3, 3),
            ('master', 5, 1),
            ('code', 6, 1), ('logs', 6, 2)
        ) AS t(mid_cd, dae_no, jung_no)
    ),
    ranked AS (
        SELECT m.co_cd, m.menu_cd,
               (mid.dae_no * 1000 + mid.jung_no * 100
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

CALL sp_tbl_menu_sort_encode_u_000(NULL);

COMMIT;
