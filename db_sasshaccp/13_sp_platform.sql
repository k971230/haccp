-- ============================================================
--  SP 3 — 테넌트 온보딩·템플릿·점검항목·문서번호 채번
--
--  개발자: 박승우
--  일자: 2026-08-05
--  코멘트:
--    1) 신규 업체 1곳을 여는 데 필요한 모든 초기 데이터를 sp_tbl_company_init_c_000 하나로 만든다
--       (회사 → 권한그룹 → 화면권한 → 메뉴 → 사용양식 → 결재선 → 문서번호 규칙 → 관리자 계정)
--    2) 점검항목은 표준(tbl_check_item)에 업체 오버라이드(tbl_company_check_item)를 덮어 반환한다
--       업체는 문구·순서·표시여부만 바꾼다. 표 구조 변경은 플랫폼 신규 버전으로만 가능하다
--    3) 문서번호는 사용자에게 보이는 업무번호다. PK(idx)와 목적이 다르다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 0. sp_tbl_menu_sort_encode_u_000 — 메뉴 sort_no 대·중·소 인코딩
--    company_init보다 먼저 정의해야 CALL이 가능하다 (21에도 동일 정의)
-- ------------------------------------------------------------
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

    -- menu-sys-auth leaf: 공통코드 → 메뉴 → 권한그룹 → 부서 → 사용자
    UPDATE tbl_menu m
       SET sort_no = v.ord, upd_id = 'system', upd_dt = now()
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

-- ------------------------------------------------------------
-- 0-1. sp_tbl_company_code_copy_c_000 — 플랫폼 표준코드(0000)를 업체로 복제
--      공통코드 조회 SP가 co_cd = p_co_cd 완전 고유 격리로 바뀌면서
--      0000 상속이 사라졌다. 업체는 표준코드 실물을 자기 co_cd로 갖고 있어야
--      사용여부·판정 등 전 화면 콤보가 채워진다
--      company_init보다 먼저 정의해야 CALL이 가능하다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_company_code_copy_c_000(
    -- p_co_cd: 복제 대상 업체코드 — 0000 자기 자신은 금지
    p_co_cd varchar,
    -- p_id: 작업자 로그인 ID — 복제행 ins_id
    p_id    varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    IF COALESCE(p_co_cd, '') = '' THEN
        RAISE EXCEPTION '회사코드는 필수입니다.' USING ERRCODE = '45000';
    END IF;
    -- 0000으로 호출할 때(= 원본 자기 복제) 무한 중복이 되므로 막는다
    IF p_co_cd = '0000' THEN
        RAISE EXCEPTION '0000은 표준코드 원본이라 복제 대상이 될 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    -- 업체가 이미 가진 (main_cd, sub_cd)는 건드리지 않는다 — 업체가 고친 코드명·순서를 보존한다
    INSERT INTO tbl_code(co_cd, main_cd, sub_cd, code_nm, sort_no, ref1, ref2,
                         sys_yn, use_yn, ins_id, ins_dt)
    SELECT p_co_cd, s.main_cd, s.sub_cd, s.code_nm, s.sort_no, s.ref1, s.ref2,
           s.sys_yn, s.use_yn, p_id, now()
      FROM tbl_code s
     WHERE s.co_cd = '0000'
       AND NOT EXISTS (
               SELECT 1
                 FROM tbl_code o
                WHERE o.co_cd = p_co_cd
                  AND o.main_cd = s.main_cd
                  AND o.sub_cd = s.sub_cd
           );
END$$;
COMMENT ON PROCEDURE sp_tbl_company_code_copy_c_000(varchar, varchar) IS
  '플랫폼 표준코드(co_cd=0000) 미보유분을 업체로 복제 — 재실행 안전. 공통코드 완전 고유 격리 전제';

-- ------------------------------------------------------------
-- 1. sp_tbl_company_init_c_000 — 신규 업체(테넌트) 초기 생성
--    이미 존재하는 회사코드로 다시 호출하면 부족한 데이터만 채운다(재실행 안전)
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_company_init_c_000(
    -- p_co_cd: 신규 회사코드 — 이후 모든 SP의 p_co_cd가 된다
    p_co_cd     varchar,
    -- p_co_nm: 회사명
    p_co_nm     varchar,
    -- p_biz_no: 사업자등록번호
    p_biz_no    varchar,
    -- p_ceo_nm: 대표자명
    p_ceo_nm    varchar,
    -- p_admin_id: 초기 관리자 로그인 아이디 — 전 업체 통틀어 중복 불가
    p_admin_id  varchar,
    -- p_admin_nm: 초기 관리자 이름
    p_admin_nm  varchar,
    -- p_admin_pw: 초기 관리자 비밀번호 해시 (평문 금지)
    p_admin_pw  varchar,
    -- p_id: 작업자 로그인 ID — 플랫폼 관리자
    p_id        varchar
)
LANGUAGE plpgsql AS $$
DECLARE v_cnt int;
BEGIN
    IF COALESCE(p_co_cd, '') = '' OR COALESCE(p_co_nm, '') = '' THEN
        RAISE EXCEPTION '회사코드와 회사명은 필수입니다.' USING ERRCODE = '45000';
    END IF;
    IF p_co_cd = '0000' THEN
        RAISE EXCEPTION '0000은 플랫폼 예약 회사코드입니다.' USING ERRCODE = '45000';
    END IF;

    -- (1) 회사 — 이미 있으면 건너뛴다
    INSERT INTO tbl_company(co_cd, co_nm, biz_no, ceo_nm, use_yn, ins_id, ins_dt)
    VALUES (p_co_cd, p_co_nm, NULLIF(p_biz_no, ''), NULLIF(p_ceo_nm, ''), 'Y', p_id, now())
    ON CONFLICT (co_cd) DO NOTHING;

    -- (2) 기본 권한그룹 2종 — ADMIN(HACCP 관리자), USER(작성 담당자)
    INSERT INTO tbl_role(co_cd, usrgrp_cd, usrgrp_nm, desc_rmk, ins_id, ins_dt)
    VALUES (p_co_cd, 'ADMIN', 'HACCP 관리자', '전 화면 접근 및 기준정보·시스템 설정 권한', p_id, now()),
           (p_co_cd, 'USER',  '작성 담당자',  '기록 작성·조회 권한. 시스템 설정 접근 불가', p_id, now())
    ON CONFLICT (co_cd, usrgrp_cd) DO NOTHING;

    -- (3) 화면 권한
    --     ADMIN: 전 화면 전 권한
    INSERT INTO tbl_role_screen(co_cd, usrgrp_cd, scrn_cd, read_yn, write_yn, modify_yn, delete_yn, print_yn, ins_id, ins_dt)
    SELECT p_co_cd, 'ADMIN', s.scrn_cd, 'Y', 'Y', 'Y', 'Y', 'Y', p_id, now()
      FROM tbl_screen s WHERE s.use_yn = 'Y'
    ON CONFLICT (co_cd, usrgrp_cd, scrn_cd) DO NOTHING;

    --     USER: 시스템(SYS)·기준정보(BAS)를 뺀 화면에 조회·등록·수정·출력. 삭제는 막는다
    INSERT INTO tbl_role_screen(co_cd, usrgrp_cd, scrn_cd, read_yn, write_yn, modify_yn, delete_yn, print_yn, ins_id, ins_dt)
    SELECT p_co_cd, 'USER', s.scrn_cd, 'Y', 'Y', 'Y', 'N', 'Y', p_id, now()
      FROM tbl_screen s WHERE s.use_yn = 'Y' AND s.module_cd NOT IN ('SYS', 'COD', 'FRM')
    ON CONFLICT (co_cd, usrgrp_cd, scrn_cd) DO NOTHING;

    -- (4) 메뉴 — 대·중·소 3단 kebab IA. sort_no는 인코딩(대*1000+중*100+소) — 마지막에 reseq
    INSERT INTO tbl_menu(co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
    VALUES
        (p_co_cd, 'menu-doc-write',  '문서 작성',      NULL, NULL, 2000, 'Y', p_id, now()),
        (p_co_cd, 'menu-doc-flow',   '문서 현황·결재', NULL, NULL, 3000, 'Y', p_id, now()),
        (p_co_cd, 'menu-doc-master', '문서 기준관리',  NULL, NULL, 4000, 'Y', p_id, now()),
        (p_co_cd, 'menu-base',       '기초정보',       NULL, NULL, 5000, 'Y', p_id, now()),
        (p_co_cd, 'menu-sys',        '시스템',         NULL, NULL, 6000, 'Y', p_id, now())
    ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
        menu_nm = EXCLUDED.menu_nm, h_menu_cd = NULL, scrn_cd = NULL,
        use_yn = 'Y', sort_no = EXCLUDED.sort_no, upd_id = p_id, upd_dt = now();

    INSERT INTO tbl_menu(co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
    VALUES (p_co_cd, 'today-tasks', '오늘 할 일', NULL, 'today-tasks', 1001, 'Y', p_id, now())
    ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
        menu_nm = '오늘 할 일', h_menu_cd = NULL, scrn_cd = 'today-tasks',
        sort_no = 1001, use_yn = 'Y', upd_id = p_id, upd_dt = now();

    INSERT INTO tbl_menu(co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
    VALUES
        (p_co_cd, 'menu-write-ccp',   'CCP(공정)',       'menu-doc-write',  NULL, 2100, 'Y', p_id, now()),
        (p_co_cd, 'menu-write-prp',   'PRP(위생·설비)',  'menu-doc-write',  NULL, 2200, 'Y', p_id, now()),
        (p_co_cd, 'menu-write-logis', '물류',            'menu-doc-write',  NULL, 2300, 'Y', p_id, now()),
        (p_co_cd, 'menu-write-admin', '운영·법정',       'menu-doc-write',  NULL, 2400, 'Y', p_id, now()),
        (p_co_cd, 'menu-flow-appr',   '결재',            'menu-doc-flow',   NULL, 3100, 'Y', p_id, now()),
        (p_co_cd, 'menu-flow-box',    '문서함·법적서류', 'menu-doc-flow',   NULL, 3200, 'Y', p_id, now()),
        (p_co_cd, 'menu-flow-ca',     '이탈·개선조치',   'menu-doc-flow',   NULL, 3300, 'Y', p_id, now()),
        (p_co_cd, 'menu-master-doc',  '작성 문서·주기',  'menu-doc-master', NULL, 4100, 'Y', p_id, now()),
        (p_co_cd, 'menu-master-form', 'HWP·양식 원본',   'menu-doc-master', NULL, 4200, 'Y', p_id, now()),
        (p_co_cd, 'menu-master-item', '점검항목/한계',   'menu-doc-master', NULL, 4300, 'Y', p_id, now()),
        (p_co_cd, 'menu-master-appr', '결재선',          'menu-doc-master', NULL, 4400, 'Y', p_id, now()),
        (p_co_cd, 'menu-base-master', '기준정보',        'menu-base',       NULL, 5100, 'Y', p_id, now()),
        (p_co_cd, 'menu-sys-auth',    '권한·사용자·코드', 'menu-sys',        NULL, 6100, 'Y', p_id, now()),
        (p_co_cd, 'menu-sys-log',     '이력·통계',       'menu-sys',        NULL, 6200, 'Y', p_id, now())
    ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
        menu_nm = EXCLUDED.menu_nm, h_menu_cd = EXCLUDED.h_menu_cd, scrn_cd = NULL,
        use_yn = 'Y', sort_no = EXCLUDED.sort_no, upd_id = p_id, upd_dt = now();

    -- 소 leaf — 화면별 중분류 매핑 (menu_cd = menu-{scrn_cd})
    INSERT INTO tbl_menu(co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
    SELECT p_co_cd, 'menu-' || v.scrn_cd, COALESCE(s.scrn_nm, v.scrn_cd),
           v.h_menu_cd, v.scrn_cd, COALESCE(s.sort_no, v.sort_no), 'Y', p_id, now()
      FROM (VALUES
        ('ccp-cold-monitor', 'menu-write-ccp', 105),
        ('ccp-heat-monitor', 'menu-write-ccp', 106),
        ('ccp-sanitize-monitor', 'menu-write-ccp', 107),
        ('ccp-filter-monitor', 'menu-write-ccp', 108),
        ('ccp-metal-monitor', 'menu-write-ccp', 109),
        ('ccp-verification-check', 'menu-write-ccp', 110),
        ('process-hwp', 'menu-write-ccp', 129),
        ('daily-hygiene-check', 'menu-write-prp', 101),
        ('health-cert-record', 'menu-write-prp', 102),
        ('pest-control-check', 'menu-write-prp', 104),
        ('facility-equipment-check', 'menu-write-prp', 112),
        ('equipment-history', 'menu-write-prp', 111),
        ('pest-device-history', 'menu-write-prp', 113),
        ('visual-insp-standard', 'menu-write-prp', 114),
        ('calib-self-hwp', 'menu-write-prp', 116),
        ('calib-ext-hwp', 'menu-write-prp', 117),
        ('waste-hwp', 'menu-write-prp', 119),
        ('personal-hyg-hwp', 'menu-write-prp', 131),
        ('area-hyg-hwp', 'menu-write-prp', 132),
        ('water-hwp', 'menu-write-prp', 133),
        ('verify-plan-hwp', 'menu-write-prp', 134),
        ('verify-check-hwp', 'menu-write-prp', 135),
        ('verify-report-hwp', 'menu-write-prp', 136),
        ('verify-ca-hwp', 'menu-write-prp', 127),
        ('prod-test-hwp', 'menu-write-prp', 137),
        ('surface-test-hwp', 'menu-write-prp', 138),
        ('receiving-insp-hwp', 'menu-write-logis', 114),
        ('submaterial-recv-hwp', 'menu-write-logis', 115),
        ('shipment-log-hwp', 'menu-write-logis', 118),
        ('inventory-hwp', 'menu-write-logis', 120),
        ('vehicle-hwp', 'menu-write-logis', 130),
        ('visitor-log', 'menu-write-admin', 103),
        ('edu-plan-hwp', 'menu-write-admin', 121),
        ('edu-log-hwp', 'menu-write-admin', 122),
        ('bad-product-hwp', 'menu-write-admin', 123),
        ('claim-hwp', 'menu-write-admin', 124),
        ('recall-hwp', 'menu-write-admin', 125),
        ('eval-hwp', 'menu-write-admin', 126),
        ('handover-hwp', 'menu-write-admin', 128),
        ('approval-inbox', 'menu-flow-appr', 210),
        ('approval-history', 'menu-flow-appr', 230),
        ('document-inbox', 'menu-flow-box', 220),
        ('legal-document-upload', 'menu-flow-box', 240),
        ('corrective-action-management', 'menu-flow-ca', 250),
        ('schedule-cycle-management', 'menu-master-doc', 340),
        ('hwp-template-management', 'menu-master-form', 310),
        ('daily-hyg-item-admin', 'menu-master-item', 311),
        ('ccp-cold-limit-admin', 'menu-master-item', 321),
        ('ccp-heat-limit-admin', 'menu-master-item', 322),
        ('ccp-sanitize-limit-admin', 'menu-master-item', 323),
        ('ccp-filter-limit-admin', 'menu-master-item', 324),
        ('ccp-metal-limit-admin', 'menu-master-item', 325),
        ('ccp-verify-standard-admin', 'menu-master-item', 326),
        ('facility-check-item-admin', 'menu-master-item', 331),
        ('ccp-limit-management', 'menu-master-item', 330),
        ('equipment-management', 'menu-master-item', 360),
        ('pest-device-management', 'menu-master-item', 370),
        ('approval-line-management', 'menu-master-appr', 350),
        ('partner-management', 'menu-base-master', 420),
        ('product-management', 'menu-base-master', 430),
        ('material-management', 'menu-base-master', 440),
        ('storage-management', 'menu-base-master', 450),
        ('measuring-device-management', 'menu-base-master', 460),
        ('vehicle-management', 'menu-base-master', 470),
        ('work-area-management', 'menu-base-master', 480),
        ('common-code-management', 'menu-sys-auth', 910),
        ('menu-management', 'menu-sys-auth', 920),
        ('role-management', 'menu-sys-auth', 930),
        ('department-management', 'menu-sys-auth', 940),
        ('user-management', 'menu-sys-auth', 950),
        ('login-history', 'menu-sys-log', 970),
        ('screen-usage-statistics', 'menu-sys-log', 980),
        ('audit-log', 'menu-sys-log', 990)
      ) AS v(scrn_cd, h_menu_cd, sort_no)
      JOIN tbl_screen s ON s.scrn_cd = v.scrn_cd AND s.use_yn = 'Y'
    ON CONFLICT (co_cd, menu_cd) DO NOTHING;

    -- 메뉴 sort_no 대·중·소 인코딩(1001~9999) — sp는 21/53에 정의
    CALL sp_tbl_menu_sort_encode_u_000(p_co_cd);

    -- (5) 사용양식 — 구현된 표준 템플릿(impl_yn=Y)을 시스템양식 예제로 복사한다
    INSERT INTO tbl_company_template(co_cd, tmpl_cd, cycle_cd, retention_month, use_yn, sys_yn, ins_id, ins_dt)
    SELECT p_co_cd, t.tmpl_cd, t.default_cycle_cd, t.default_retention_month, 'Y', 'sys', p_id, now()
      FROM tbl_template t WHERE t.use_yn = 'Y' AND t.impl_yn = 'Y'
    ON CONFLICT (co_cd, tmpl_cd) DO NOTHING;

    -- (6) 기본 결재선 — 작성자 → 검토자 → 승인자 3단. 담당자 지정은 업체가 나중에 채운다
    INSERT INTO tbl_approval_line(co_cd, appr_line_cd, appr_line_nm, ins_id, ins_dt)
    VALUES (p_co_cd, 'DEFAULT', '기본 결재선', p_id, now())
    ON CONFLICT (co_cd, appr_line_cd) DO NOTHING;

    INSERT INTO tbl_approval_line_step(co_cd, appr_line_cd, step_no, role_cd, ins_id, ins_dt)
    VALUES (p_co_cd, 'DEFAULT', 1, 'WRITE',   p_id, now()),
           (p_co_cd, 'DEFAULT', 2, 'REVIEW',  p_id, now()),
           (p_co_cd, 'DEFAULT', 3, 'APPROVE', p_id, now())
    ON CONFLICT (co_cd, appr_line_cd, step_no) DO NOTHING;

    UPDATE tbl_company_template SET appr_line_cd = 'DEFAULT', upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND appr_line_cd IS NULL;

    -- (7) 문서번호 채번 규칙 — 템플릿코드 접두 + 일자 + 3자리, 일 단위 리셋
    INSERT INTO tbl_doc_no_rule(co_cd, tmpl_cd, prefix, date_fmt, seq_len, reset_cycle, ins_id, ins_dt)
    SELECT p_co_cd, t.tmpl_cd, t.tmpl_cd, 'YYYYMMDD', 3, 'D', p_id, now()
      FROM tbl_template t WHERE t.use_yn = 'Y' AND t.impl_yn = 'Y'
    ON CONFLICT (co_cd, tmpl_cd) DO NOTHING;

    -- (8) 초기 관리자 계정 — 아이디가 이미 쓰이고 있으면 업무 오류로 알린다
    IF COALESCE(p_admin_id, '') <> '' THEN
        SELECT COUNT(*) INTO v_cnt FROM tbl_user WHERE user_id = p_admin_id;
        IF v_cnt > 0 THEN
            RAISE EXCEPTION '이미 사용 중인 아이디입니다: %', p_admin_id USING ERRCODE = '45000';
        END IF;

        INSERT INTO tbl_user(user_id, co_cd, user_nm, user_pw, usrgrp_cd, use_yn, pw_upd_dt, ins_id, ins_dt)
        VALUES (p_admin_id, p_co_cd, p_admin_nm, p_admin_pw, 'ADMIN', 'Y', now(), p_id, now());
    END IF;

    -- (9) 기본 CCP 한계기준 — 냉장보관·금속검출. 이미 있으면 건너뛴다(업체가 조정한 값 보호)
    INSERT INTO tbl_ccp_limit(
        co_cd, ccp_cd, ccp_nm, proc_nm, limit_type,
        min_val, max_val, unit_nm, fe_size, sts_size, cycle_min,
        form_title, cycle_rmk, limit_rmk, method_rmk, use_yn, ins_id, ins_dt
    )
    VALUES
        (p_co_cd, 'CCP-1B', '원료육 냉장보관', '원료육 냉장보관', 'TEMP_RANGE',
         -2, 5, '℃', NULL, NULL, 120,
         'CCP 냉장·냉동 보관 모니터링 일지',
         '작업 시작 시, 작업 종료 전, 작업 중 2시간마다(또는 작업 중 0회)',
         '보관온도 : -2 ~ 5℃',
         '냉장보관고 온도표시기의 온도를 확인하고 기록한다.',
         'Y', p_id, now()),
        (p_co_cd, 'CCP-3B', '완제품 냉장·냉동보관', '완제품 냉장·냉동보관', 'TEMP_RANGE',
         -2, 5, '℃', NULL, NULL, 120,
         'CCP 냉장·냉동 보관 모니터링 일지',
         '작업 시작 시, 작업 종료 전, 작업 중 2시간마다(또는 작업 중 0회)',
         '보관온도 : -2 ～ 5℃ (냉장) / -18℃ 이하 (냉동)',
         '모니터링담당자는 냉장·냉동보관고 온도표시장치의 표시된 온도를 확인하고 일지에 기록한다.',
         'Y', p_id, now()),
        (p_co_cd, 'CCP-2P', '금속검출', '금속검출', 'METAL',
         NULL, NULL, 'mm', 1.5, 2.5, NULL,
         'CCP 금속검출 모니터링 일지',
         E'금속검출기 정상작동 여부 확인 : 작업시작 전, 작업 중 0시간마다, 작업 종료 후\n금속검출기에 의한 공정품 확인 : 작업 중 상시',
         'Fe 1.5 ㎜, STS 2.5 ㎜ 이상 불검출',
         E'기기감도 : 모니터링담당자는 기기 중간에 시편을 통과시켜 검출여부를 확인하고 일지에 기록한다.\n제품감도 : 모니터링담당자는 제품 중간에 시편을 넣고 기기에 통과시켜 검출여부를 확인하고 일지에 기록한다.\n통과량 및 검출량 : 모니터링담당자는 통과된 양과 검출된 양을 일지에 기록하고 HACCP팀장에 보고한다.',
         'Y', p_id, now())
    ON CONFLICT (co_cd, ccp_cd) DO NOTHING;

    -- (10) 샘플 보관고 4대(냉장3·냉동1) — CCP 냉장·냉동 보관 일지 열을 바로 그린다. 업체가 기준정보에서 추가·수정
    INSERT INTO tbl_storage(
        co_cd, storage_cd, storage_nm, storage_type, ccp_cd,
        temp_min, temp_max, sort_no, use_yn, ins_id, ins_dt
    )
    VALUES
        (p_co_cd, 'ST01', '원료냉장1',   'COLD',   'CCP-1B', -2, 5, 1, 'Y', p_id, now()),
        (p_co_cd, 'ST02', '원료냉장2',   'COLD',   'CCP-1B', -2, 5, 2, 'Y', p_id, now()),
        (p_co_cd, 'ST03', '완제품냉장1', 'COLD',   'CCP-3B', -2, 5, 3, 'Y', p_id, now()),
        (p_co_cd, 'ST04', '완제품냉동1', 'FROZEN', 'CCP-3B', -23, -18, 4, 'Y', p_id, now())
    ON CONFLICT (co_cd, storage_cd) DO NOTHING;

    -- (11) 표준 공통코드 복제 — 공통코드 조회가 co_cd 완전 고유라서 실물이 없으면 전 화면 콤보가 빈다
    CALL sp_tbl_company_code_copy_c_000(p_co_cd, p_id);
END$$;
COMMENT ON PROCEDURE sp_tbl_company_init_c_000(varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar) IS '신규 업체 초기 생성 — 회사·권한·메뉴·사용양식·결재선·채번규칙·관리자·기본 CCP한계·샘플보관고·표준코드 복제';

-- ------------------------------------------------------------
-- 2. sp_tbl_company_template_r_000 — 업체 사용양식 조회
--    표준 카탈로그에 업체 설정을 덮어 반환한다. 미사용 양식도 함께 내려 화면에서 켜고 끌 수 있게 한다
--    RETURNS TABLE 컬럼 변경 시 CREATE OR REPLACE 불가 — 선 DROP
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_company_template_r_000(varchar, varchar, varchar);
CREATE OR REPLACE FUNCTION sp_tbl_company_template_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd      varchar,
    -- p_category_cd: 분류 필터 CCP/HYG/FAC/INV/VER/EDU/DOC. 공백이면 전체
    p_category_cd varchar,
    -- p_use_yn: 사용여부 필터. 공백이면 전체(미사용 양식 포함)
    p_use_yn     varchar
)
RETURNS TABLE(
    idx             bigint,
    tmpl_cd         varchar,
    tmpl_nm         varchar,
    mng_no          varchar,
    doc_kind        varchar,
    category_cd     varchar,
    scrn_cd         varchar,
    cycle_cd        varchar,
    retention_month int,
    appr_line_cd    varchar,
    appr_line_nm    varchar,
    use_yn          varchar,
    sort_no         int
) LANGUAGE sql AS $$
    SELECT ct.idx,
           t.tmpl_cd,
           -- 문서명: 업체가 바꿨으면 그 값, 아니면 표준명
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm),
           t.mng_no, t.doc_kind, t.category_cd, t.scrn_cd,
           COALESCE(ct.cycle_cd, t.default_cycle_cd),
           COALESCE(ct.retention_month, t.default_retention_month),
           ct.appr_line_cd, al.appr_line_nm,
           COALESCE(ct.use_yn, 'N'),
           t.sort_no
      FROM tbl_template t
      LEFT JOIN tbl_company_template ct ON ct.co_cd = p_co_cd AND ct.tmpl_cd = t.tmpl_cd
      LEFT JOIN tbl_approval_line al    ON al.co_cd = p_co_cd AND al.appr_line_cd = ct.appr_line_cd
     WHERE t.use_yn = 'Y'
       AND t.impl_yn = 'Y'
       AND t.category_cd LIKE CONCAT('%', COALESCE(p_category_cd, ''), '%')
       AND COALESCE(ct.use_yn, 'N') LIKE CONCAT('%', COALESCE(p_use_yn, ''), '%')
     ORDER BY t.sort_no;
$$;
COMMENT ON FUNCTION sp_tbl_company_template_r_000(varchar, varchar, varchar) IS '업체 사용양식 조회 — 표준 카탈로그에 업체 설정을 덮어 반환';

-- ------------------------------------------------------------
-- 3. sp_tbl_company_template_c_000 — 업체 사용양식 설정 저장 (업서트)
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_company_template_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd          varchar,
    -- p_tmpl_cd: 템플릿 코드
    p_tmpl_cd        varchar,
    -- p_tmpl_nm_ovr: 문서명 오버라이드. 공백이면 표준명 사용
    p_tmpl_nm_ovr    varchar,
    -- p_appr_line_cd: 적용 결재선 코드
    p_appr_line_cd   varchar,
    -- p_cycle_cd: 작성주기 오버라이드. 공백이면 표준 주기
    p_cycle_cd       varchar,
    -- p_retention_month: 보존 개월수 오버라이드. 24 미만은 막는다
    p_retention_month int,
    -- p_use_yn: 사용여부 — N이면 메뉴·오늘 할 일에서 제외된다
    p_use_yn         varchar,
    -- p_id: 작업자 로그인 ID
    p_id             varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    IF p_retention_month IS NOT NULL AND p_retention_month < 24 THEN
        RAISE EXCEPTION '문서 보존기간은 24개월 이상이어야 합니다.' USING ERRCODE = '45000';
    END IF;

    INSERT INTO tbl_company_template(co_cd, tmpl_cd, tmpl_nm_ovr, appr_line_cd, cycle_cd, retention_month, use_yn, ins_id, ins_dt)
    VALUES (p_co_cd, p_tmpl_cd, NULLIF(p_tmpl_nm_ovr, ''), NULLIF(p_appr_line_cd, ''),
            NULLIF(p_cycle_cd, ''), p_retention_month, COALESCE(NULLIF(p_use_yn, ''), 'Y'), p_id, now())
    ON CONFLICT (co_cd, tmpl_cd) DO UPDATE SET
        tmpl_nm_ovr     = EXCLUDED.tmpl_nm_ovr,
        appr_line_cd    = EXCLUDED.appr_line_cd,
        cycle_cd        = EXCLUDED.cycle_cd,
        retention_month = EXCLUDED.retention_month,
        use_yn          = EXCLUDED.use_yn,
        upd_id          = p_id,
        upd_dt          = now();
END$$;
COMMENT ON PROCEDURE sp_tbl_company_template_c_000(varchar, varchar, varchar, varchar, varchar, int, varchar, varchar) IS '업체 사용양식 설정 업서트 — 보존기간 24개월 미만 차단';

-- ------------------------------------------------------------
-- 4. sp_tbl_check_item_r_000 — 점검항목 조회 (표준 + 업체 오버라이드)
--    점검표 화면이 빈 행을 그릴 때 호출한다. 업체가 숨긴 항목은 반환하지 않는다
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_check_item_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd  varchar,
    -- p_tmpl_cd: 템플릿 코드 — tmpl_prp-hygiene-daily, WATER 등
    p_tmpl_cd varchar,
    -- p_grp_cd: 항목 구분 필터. 공백이면 전체 구분
    p_grp_cd varchar
)
RETURNS TABLE(
    item_cd    varchar,
    grp_cd     varchar,
    grp_nm     varchar,
    item_nm    varchar,
    input_type varchar,
    unit_nm    varchar,
    method_nm  varchar,
    cycle_nm   varchar,
    sort_no    int
) LANGUAGE sql AS $$
    SELECT * FROM (
        SELECT ci.item_cd, ci.grp_cd, ci.grp_nm,
               -- 문구: 업체 오버라이드가 있으면 그 값, 없으면 표준 문구
               COALESCE(cci.item_nm_ovr, ci.item_nm) AS item_nm,
               ci.input_type, ci.unit_nm, ci.method_nm, ci.cycle_nm,
               COALESCE(cci.sort_no, ci.sort_no) AS sort_no
          FROM tbl_check_item ci
          LEFT JOIN tbl_company_check_item cci
                 ON cci.co_cd = p_co_cd AND cci.tmpl_cd = ci.tmpl_cd AND cci.item_cd = ci.item_cd
         WHERE ci.tmpl_cd = p_tmpl_cd
           AND ci.use_yn = 'Y'
           -- 업체가 끈 항목(use_yn=N)은 제외. 오버라이드 행이 없으면 표준대로 표시한다
           AND COALESCE(cci.use_yn, 'Y') = 'Y'
           AND COALESCE(ci.grp_cd, '') LIKE CONCAT('%', COALESCE(p_grp_cd, ''), '%')
        UNION ALL
        -- 회사 전용 CUST 항목 — 표준 카탈로그에 없고 표시 Y인 행만
        SELECT cci.item_cd, NULL::varchar, NULL::varchar,
               COALESCE(cci.item_nm_ovr, cci.item_cd),
               'OX'::varchar, NULL::varchar, NULL::varchar, NULL::varchar,
               COALESCE(cci.sort_no, 0)
          FROM tbl_company_check_item cci
         WHERE cci.co_cd = p_co_cd
           AND cci.tmpl_cd = p_tmpl_cd
           AND cci.item_cd LIKE 'CUST%'
           AND COALESCE(cci.use_yn, 'Y') = 'Y'
           AND NOT EXISTS (
               SELECT 1 FROM tbl_check_item s
                WHERE s.tmpl_cd = cci.tmpl_cd AND s.item_cd = cci.item_cd
           )
           AND COALESCE('', '') LIKE CONCAT('%', COALESCE(p_grp_cd, ''), '%')
    ) q
    ORDER BY q.sort_no, q.item_cd;
$$;
COMMENT ON FUNCTION sp_tbl_check_item_r_000(varchar, varchar, varchar) IS '점검항목 조회 — 표준+오버라이드+회사 CUST, 숨김 제외';

-- ------------------------------------------------------------
-- 5. sp_tbl_company_check_item_c_000 — 업체 점검항목 조정 저장 (업서트)
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_company_check_item_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd      varchar,
    -- p_tmpl_cd: 템플릿 코드
    p_tmpl_cd    varchar,
    -- p_item_cd: 항목코드 — tbl_check_item.item_cd
    p_item_cd    varchar,
    -- p_item_nm_ovr: 문구 오버라이드. 공백이면 표준 문구로 되돌린다
    p_item_nm_ovr varchar,
    -- p_sort_no: 순서 오버라이드. NULL이면 표준 순서
    p_sort_no    int,
    -- p_use_yn: 표시여부 — N이면 점검표에서 행이 사라진다
    p_use_yn     varchar,
    -- p_id: 작업자 로그인 ID
    p_id         varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_cnt int;
    v_item varchar(20) := trim(COALESCE(p_item_cd, ''));
    v_tmpl varchar(20) := trim(COALESCE(p_tmpl_cd, ''));
BEGIN
    IF v_tmpl = '' OR v_item = '' THEN
        RAISE EXCEPTION '양식과 점검항목 코드를 확인하세요.' USING ERRCODE = '45000';
    END IF;

    SELECT COUNT(*) INTO v_cnt FROM tbl_check_item WHERE tmpl_cd = v_tmpl AND item_cd = v_item;
    IF v_cnt = 0 THEN
        -- 표준에 없을 때(= 회사 전용) CUST 접두만 허용
        IF v_item NOT LIKE 'CUST%' THEN
            RAISE EXCEPTION '표준 점검항목에 없는 코드입니다: % / %', v_tmpl, v_item USING ERRCODE = '45000';
        END IF;
        IF NULLIF(trim(COALESCE(p_item_nm_ovr, '')), '') IS NULL THEN
            RAISE EXCEPTION '업체 전용 점검항목은 문구가 필요합니다.' USING ERRCODE = '45000';
        END IF;
    END IF;

    INSERT INTO tbl_company_check_item(co_cd, tmpl_cd, item_cd, item_nm_ovr, sort_no, use_yn, ins_id, ins_dt)
    VALUES (p_co_cd, v_tmpl, v_item, NULLIF(trim(COALESCE(p_item_nm_ovr, '')), ''), p_sort_no,
            COALESCE(NULLIF(p_use_yn, ''), 'Y'), p_id, now())
    ON CONFLICT (co_cd, tmpl_cd, item_cd) DO UPDATE SET
        item_nm_ovr = EXCLUDED.item_nm_ovr,
        sort_no     = EXCLUDED.sort_no,
        use_yn      = EXCLUDED.use_yn,
        upd_id      = p_id,
        upd_dt      = now();
END$$;
COMMENT ON PROCEDURE sp_tbl_company_check_item_c_000(varchar, varchar, varchar, varchar, int, varchar, varchar) IS
'업체 점검항목 업서트 — 표준 오버라이드 또는 CUST 회사 전용';

-- ------------------------------------------------------------
-- 5b. sp_tbl_company_check_item_d_000 — 회사 전용(CUST*) 삭제
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_company_check_item_d_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_tmpl_cd: 양식 코드
    p_tmpl_cd varchar,
    -- p_item_cd: 회사 전용 항목코드(CUST*)
    p_item_cd varchar,
    -- p_id: 작업자(감사 자리 — DELETE만 수행)
    p_id      varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_item varchar(20) := trim(COALESCE(p_item_cd, ''));
    v_tmpl varchar(20) := trim(COALESCE(p_tmpl_cd, ''));
BEGIN
    IF v_tmpl = '' OR v_item = '' THEN
        RAISE EXCEPTION '삭제할 점검항목을 선택하세요.' USING ERRCODE = '45000';
    END IF;
    IF v_item NOT LIKE 'CUST%' THEN
        RAISE EXCEPTION '표준 점검항목은 삭제할 수 없습니다. 표시를 숨김으로 변경하세요.' USING ERRCODE = '45000';
    END IF;
    DELETE FROM tbl_company_check_item
     WHERE co_cd = p_co_cd AND tmpl_cd = v_tmpl AND item_cd = v_item;
    IF NOT FOUND THEN
        RAISE EXCEPTION '삭제할 점검항목을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
END$$;
COMMENT ON PROCEDURE sp_tbl_company_check_item_d_000(varchar, varchar, varchar, varchar) IS
'업체 전용 점검항목 삭제 — CUST*만 허용';

-- ------------------------------------------------------------
-- 6. sp_tbl_doc_no_gen_c_000 — 문서번호 채번
--    같은 (회사, 템플릿)에 동시 요청이 몰려도 번호가 겹치지 않도록 자문 잠금으로 직렬화한다.
--    잠금은 트랜잭션 종료 시 자동 해제되므로 별도 해제 호출이 필요 없다
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_doc_no_gen_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_tmpl_cd: 템플릿 코드 — 채번 규칙을 찾는 키
    p_tmpl_cd varchar,
    -- p_base_dt: 문서 기준일자 YYYYMMDD — 번호에 들어갈 일자와 리셋 판단의 기준
    p_base_dt varchar
)
RETURNS varchar LANGUAGE plpgsql AS $$
DECLARE
    v_prefix    varchar(20);
    v_date_fmt  varchar(10);
    v_seq_len   int;
    v_reset     varchar(1);
    v_last_key  varchar(10);
    v_last_seq  int;
    v_reset_key varchar(10);
    v_date_part varchar(10);
    v_next_seq  int;
BEGIN
    -- 같은 회사·템플릿 조합끼리만 직렬화한다(전역 잠금이 아니라 조합 단위)
    PERFORM pg_advisory_xact_lock(hashtext(p_co_cd || '|' || p_tmpl_cd));

    SELECT prefix, date_fmt, seq_len, reset_cycle, last_reset_key, last_seq
      INTO v_prefix, v_date_fmt, v_seq_len, v_reset, v_last_key, v_last_seq
      FROM tbl_doc_no_rule
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;

    IF NOT FOUND THEN
        RAISE EXCEPTION '문서번호 채번 규칙이 없습니다: %', p_tmpl_cd USING ERRCODE = '45000';
    END IF;

    -- 리셋 기준키: 주기에 맞춰 일자를 잘라 쓴다. 값이 바뀌면 일련번호를 1부터 다시 센다
    v_reset_key := CASE v_reset
                        WHEN 'D' THEN p_base_dt
                        WHEN 'M' THEN substr(p_base_dt, 1, 6)
                        WHEN 'Y' THEN substr(p_base_dt, 1, 4)
                        ELSE 'ALL' END;

    v_next_seq := CASE WHEN COALESCE(v_last_key, '') = v_reset_key THEN v_last_seq + 1 ELSE 1 END;

    UPDATE tbl_doc_no_rule
       SET last_seq = v_next_seq, last_reset_key = v_reset_key, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;

    -- 일자 구간: date_fmt가 비어 있으면(= 일자 미포함 번호) 생략한다
    v_date_part := CASE COALESCE(v_date_fmt, '')
                        WHEN 'YYYYMMDD' THEN p_base_dt
                        WHEN 'YYYYMM'   THEN substr(p_base_dt, 1, 6)
                        WHEN 'YYYY'     THEN substr(p_base_dt, 1, 4)
                        ELSE '' END;

    RETURN concat_ws('-',
                     NULLIF(COALESCE(v_prefix, ''), ''),
                     NULLIF(v_date_part, ''),
                     lpad(v_next_seq::text, COALESCE(v_seq_len, 3), '0'));
END$$;
COMMENT ON FUNCTION sp_tbl_doc_no_gen_c_000(varchar, varchar, varchar) IS '문서번호 채번 — 회사·템플릿 조합 단위 자문 잠금으로 중복 방지';
