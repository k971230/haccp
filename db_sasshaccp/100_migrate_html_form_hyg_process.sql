-- ============================================================
-- 100 — HTML양식 원본 (일반위생·공정점검) · CCP 냉장 html_sys_012
--
-- 파일번호: 100
-- 이전번호: 99
-- 개발자: 박승우
-- 일자: 2026-08-19
-- 코멘트:
--   1) 냉장 CCP 양식코드를 html_sys_001 → html_sys_012 로 옮긴다
--   2) html_sys_001 은 일반위생관리 및 공정점검표. 회사 버전은 tbl_html_form_ver
--   3) 작성은 tbl_hyg_process. JSON 파일·LONGTEXT 스냅샷은 두지 않는다
--   4) Jenkins는 migrate를 안 돌린다. 적용 후 14_sp_ccp.sql 을 CREATE OR REPLACE 로 다시 실행한다
--   5) 버전 SP 정본은 101. 이 파일을 재실행하면 101도 다시 실행한다
--
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 0. 점검항목 문구 개행 — text
-- ------------------------------------------------------------
ALTER TABLE tbl_check_item ALTER COLUMN item_nm TYPE text;

-- ------------------------------------------------------------
-- 1. html_sys_012 카탈로그 — 001이 아직 냉장일 때만 복사
-- ------------------------------------------------------------
INSERT INTO tbl_template (
    tmpl_cd, tmpl_nm, mng_no, doc_kind, category_cd, scrn_cd,
    default_cycle_cd, default_retention_month, impl_yn, sort_no, ins_id
)
SELECT 'html_sys_012', t.tmpl_nm, t.mng_no, t.doc_kind, 'CCP', 'ccp-cold-monitor',
       t.default_cycle_cd, t.default_retention_month, t.impl_yn, 112, 'system'
  FROM tbl_template t
 WHERE t.tmpl_cd = 'html_sys_001'
   AND NOT EXISTS (SELECT 1 FROM tbl_template x WHERE x.tmpl_cd = 'html_sys_012');

INSERT INTO tbl_company_template (
    co_cd, tmpl_cd, tmpl_nm_ovr, appr_line_cd, cycle_cd, retention_month,
    use_yn, sys_yn, ins_id, ins_dt
)
SELECT ct.co_cd, 'html_sys_012', ct.tmpl_nm_ovr, ct.appr_line_cd, ct.cycle_cd, ct.retention_month,
       ct.use_yn, ct.sys_yn, 'system', now()
  FROM tbl_company_template ct
 WHERE ct.tmpl_cd = 'html_sys_001'
ON CONFLICT (co_cd, tmpl_cd) DO NOTHING;

INSERT INTO tbl_doc_no_rule (co_cd, tmpl_cd, prefix, date_fmt, seq_len, reset_cycle, ins_id, ins_dt)
SELECT r.co_cd, 'html_sys_012', 'html_sys_012', r.date_fmt, r.seq_len, r.reset_cycle, 'system', now()
  FROM tbl_doc_no_rule r
 WHERE r.tmpl_cd = 'html_sys_001'
ON CONFLICT (co_cd, tmpl_cd) DO NOTHING;

UPDATE tbl_check_item SET tmpl_cd = 'html_sys_012'
 WHERE tmpl_cd = 'html_sys_001' AND item_cd NOT LIKE 'hp-%'
   AND NOT EXISTS (
        SELECT 1 FROM tbl_check_item x
         WHERE x.tmpl_cd = 'html_sys_012' AND x.item_cd = tbl_check_item.item_cd
   );

UPDATE tbl_company_check_item SET tmpl_cd = 'html_sys_012'
 WHERE tmpl_cd = 'html_sys_001' AND item_cd NOT LIKE 'hp-%'
   AND NOT EXISTS (
        SELECT 1 FROM tbl_company_check_item x
         WHERE x.co_cd = tbl_company_check_item.co_cd
           AND x.tmpl_cd = 'html_sys_012'
           AND x.item_cd = tbl_company_check_item.item_cd
   );

-- 001이 아직 CCP일 때만 문서·일정을 012로 옮긴다.
-- 09 시드가 이미 001=HYG·012=CCP 이면 재실행 시 공정점검 문서를 건드리지 않는다.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM tbl_template
         WHERE tmpl_cd = 'html_sys_001' AND category_cd = 'CCP'
    ) THEN
        UPDATE tbl_document SET tmpl_cd = 'html_sys_012' WHERE tmpl_cd = 'html_sys_001';
        UPDATE tbl_schedule_rule SET tmpl_cd = 'html_sys_012' WHERE tmpl_cd = 'html_sys_001'
          AND NOT EXISTS (
                SELECT 1 FROM tbl_schedule_rule x
                 WHERE x.co_cd = tbl_schedule_rule.co_cd AND x.tmpl_cd = 'html_sys_012'
           );
        DELETE FROM tbl_schedule_rule WHERE tmpl_cd = 'html_sys_001';
        IF to_regclass('sasshaccp.tbl_company_form') IS NOT NULL THEN
            EXECUTE $q$UPDATE tbl_company_form SET src_tmpl_cd = 'html_sys_012' WHERE src_tmpl_cd = 'html_sys_001'$q$;
        END IF;
        IF to_regclass('sasshaccp.tbl_diary_tmpl_map') IS NOT NULL THEN
            EXECUTE $q$UPDATE tbl_diary_tmpl_map SET tmpl_cd = 'html_sys_012' WHERE tmpl_cd = 'html_sys_001'$q$;
        END IF;
        IF to_regclass('sasshaccp.tbl_company_template_file') IS NOT NULL THEN
            EXECUTE $q$UPDATE tbl_company_template_file SET tmpl_cd = 'html_sys_012' WHERE tmpl_cd = 'html_sys_001'$q$;
        END IF;
        IF to_regclass('sasshaccp.tbl_schedule_task') IS NOT NULL THEN
            EXECUTE $q$UPDATE tbl_schedule_task SET tmpl_cd = 'html_sys_012' WHERE tmpl_cd = 'html_sys_001'$q$;
        END IF;
    END IF;
END$$;
UPDATE tbl_screen SET tmpl_cd = 'html_sys_012' WHERE scrn_cd = 'ccp-cold-monitor';

UPDATE tbl_template SET
    tmpl_nm = '일반위생관리 및 공정점검표',
    mng_no = '1',
    category_cd = 'HYG',
    scrn_cd = 'hygiene-process-check',
    default_cycle_cd = 'D',
    sort_no = 101,
    upd_id = 'system',
    upd_dt = now()
 WHERE tmpl_cd = 'html_sys_001';

UPDATE tbl_company_template SET tmpl_nm_ovr = NULL, upd_id = 'system', upd_dt = now()
 WHERE tmpl_cd = 'html_sys_001';

UPDATE tbl_template SET
    tmpl_nm = 'CCP 냉장·냉동 보관 모니터링 일지',
    mng_no = '2-1',
    category_cd = 'CCP',
    scrn_cd = 'ccp-cold-monitor',
    sort_no = 112,
    upd_id = 'system',
    upd_dt = now()
 WHERE tmpl_cd = 'html_sys_012';

-- ------------------------------------------------------------
-- 2. DDL — 버전·작성
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_html_form_ver (
    idx      bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd    varchar(10) NOT NULL,
    tmpl_cd  varchar(40) NOT NULL,
    ver_no   int         NOT NULL,
    ver_nm   varchar(100) NOT NULL,
    apply_yn varchar(1)  NOT NULL DEFAULT 'N',
    use_yn   varchar(1)  NOT NULL DEFAULT 'Y',
    ins_id   varchar(20) NULL,
    ins_dt   timestamp   NULL DEFAULT now(),
    upd_id   varchar(20) NULL,
    upd_dt   timestamp   NULL,
    CONSTRAINT ux_tbl_html_form_ver UNIQUE (co_cd, tmpl_cd, ver_no),
    CONSTRAINT ck_tbl_html_form_ver_no CHECK (ver_no >= 1),
    CONSTRAINT ck_tbl_html_form_ver_apply CHECK (apply_yn IN ('Y', 'N')),
    CONSTRAINT ck_tbl_html_form_ver_use CHECK (use_yn IN ('Y', 'N'))
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_tbl_html_form_ver_apply
    ON tbl_html_form_ver (co_cd, tmpl_cd) WHERE apply_yn = 'Y';

CREATE TABLE IF NOT EXISTS tbl_html_form_ver_item (
    idx        bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd      varchar(10)  NOT NULL,
    tmpl_cd    varchar(40)  NOT NULL,
    ver_no     int          NOT NULL,
    item_cd    varchar(20)  NOT NULL,
    sort_no    int          NOT NULL DEFAULT 0,
    cycle_nm   varchar(50)  NULL,
    grp_nm     varchar(100) NULL,
    item_nm    text         NOT NULL,
    input_type varchar(10)  NOT NULL DEFAULT 'YN',
    unit_nm    varchar(20)  NULL,
    ins_id     varchar(20)  NULL,
    ins_dt     timestamp    NULL DEFAULT now(),
    upd_id     varchar(20)  NULL,
    upd_dt     timestamp    NULL,
    CONSTRAINT ux_tbl_html_form_ver_item UNIQUE (co_cd, tmpl_cd, ver_no, item_cd)
);

CREATE TABLE IF NOT EXISTS tbl_hyg_process (
    idx          bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd        varchar(10) NOT NULL,
    doc_idx      bigint      NOT NULL,
    base_dt      varchar(8)  NOT NULL,
    checker_nm   varchar(50) NULL,
    ver_no       int         NOT NULL DEFAULT 0,
    special_note text        NULL,
    improve_note text        NULL,
    action_nm    text        NULL,
    confirm_nm   text        NULL,
    ins_id       varchar(20) NULL,
    ins_dt       timestamp   NULL DEFAULT now(),
    upd_id       varchar(20) NULL,
    upd_dt       timestamp   NULL,
    CONSTRAINT ux_tbl_hyg_process UNIQUE (doc_idx)
);

CREATE TABLE IF NOT EXISTS tbl_hyg_process_item (
    idx        bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd      varchar(10)  NOT NULL,
    hdr_idx    bigint       NOT NULL,
    sort_no    int          NOT NULL,
    item_cd    varchar(20)  NOT NULL,
    cycle_nm   varchar(50)  NULL,
    grp_nm     varchar(100) NULL,
    item_nm    text         NULL,
    input_type varchar(10)  NOT NULL DEFAULT 'YN',
    unit_nm    varchar(20)  NULL,
    yn         varchar(1)   NULL,
    val_nm     text         NULL,
    ins_id     varchar(20)  NULL,
    ins_dt     timestamp    NULL DEFAULT now(),
    upd_id     varchar(20)  NULL,
    upd_dt     timestamp    NULL,
    CONSTRAINT ux_tbl_hyg_process_item UNIQUE (hdr_idx, sort_no)
);

-- ------------------------------------------------------------
-- 3. 표준 점검항목 · 화면 · 메뉴 · 권한 · 채번
-- ------------------------------------------------------------
INSERT INTO tbl_check_item (tmpl_cd, item_cd, grp_cd, grp_nm, item_nm, input_type, unit_nm, cycle_nm, sort_no, ins_id) VALUES
    ('html_sys_001', 'hp-01', 'personal', '개인위생', '종업원이 청결한 위생복·위생모·위생화 등을 착용하였는가?', 'YN', NULL, '일일(작업전)', 1, 'system'),
    ('html_sys_001', 'hp-02', 'personal', '개인위생', '종업원의 건강상태(피부병·상처 등)는 양호한가?', 'YN', NULL, '일일(작업전)', 2, 'system'),
    ('html_sys_001', 'hp-03', 'personal', '개인위생', '시계·반지 등 장신구를 착용하지 않았는가?', 'YN', NULL, '일일(작업전)', 3, 'system'),
    ('html_sys_001', 'hp-04', 'personal', '개인위생', '손 세척·소독 후 작업에 임하였는가?', 'YN', NULL, '일일(작업전)', 4, 'system'),
    ('html_sys_001', 'hp-05', 'pest', '방충방서', '방충·방서 설비(포충등·트랩·방충망)가 정상 작동하는가?', 'YN', NULL, '일일(작업전)', 5, 'system'),
    ('html_sys_001', 'hp-06', 'pest', '방충방서', '출입문·창호의 밀폐 상태는 양호한가?', 'YN', NULL, '일일(작업전)', 6, 'system'),
    ('html_sys_001', 'hp-07', 'equip', '설비', '작업 설비·도구가 청결하고 정상 작동하는가?', 'YN', NULL, '일일(작업전)', 7, 'system'),
    ('html_sys_001', 'hp-08', 'recv', '입고보관', '원료·부자재의 입고 보관 상태가 적절한가?', 'YN', NULL, '일일(작업전)', 8, 'system'),
    ('html_sys_001', 'hp-09', 'recv', '입고보관', '냉장고 1 온도', 'YN_NUM', '℃', '일일(작업전)', 9, 'system'),
    ('html_sys_001', 'hp-10', 'recv', '입고보관', '냉장고 2 온도', 'YN_NUM', '℃', '일일(작업전)', 10, 'system'),
    ('html_sys_001', 'hp-11', 'recv', '입고보관', '냉동실 온도', 'YN_NUM', '℃', '일일(작업전)', 11, 'system'),
    ('html_sys_001', 'hp-12', 'process', '공정관리', '청결구역과 일반구역이 구분되어 작업하는가?', 'YN', NULL, '일일(작업중)', 12, 'system'),
    ('html_sys_001', 'hp-13', 'process', '공정관리', '식육을 오염되지 않도록 위생적으로 처리·포장하는가?', 'YN', NULL, '일일(작업중)', 13, 'system'),
    ('html_sys_001', 'hp-14', 'process', '공정관리', '작업장 온도', 'YN_NUM', '℃', '일일(작업중)', 14, 'system'),
    ('html_sys_001', 'hp-15', 'process', '공정관리', '내포장실 온도', 'YN_NUM', '℃', '일일(작업중)', 15, 'system'),
    ('html_sys_001', 'hp-16', 'process', '공정관리', '작업 중 흡연·음식물 섭취를 하지 않았는가?', 'YN', NULL, '일일(작업중)', 16, 'system'),
    ('html_sys_001', 'hp-17', 'pest', '방충방서', '작업 종료 후 방충·방서 설비를 점검하였는가?', 'YN', NULL, '일일(작업후)', 17, 'system'),
    ('html_sys_001', 'hp-18', 'clean', '청소소독', '작업장·설비·도구를 세척·소독하였는가?', 'YN', NULL, '일일(작업후)', 18, 'system'),
    ('html_sys_001', 'hp-19', 'equip', '설비', '설비 전원 차단 및 이상 유무를 확인하였는가?', 'YN', NULL, '일일(작업후)', 19, 'system'),
    ('html_sys_001', 'hp-20', 'inspect', '점검', '일일 점검 결과를 기록·보고하였는가?', 'YN', NULL, '일일(작업후)', 20, 'system'),
    ('html_sys_001', 'hp-21', 'store', '보관', '잔여 원료·제품을 지정 장소에 보관하였는가?', 'YN', NULL, '일일(작업후)', 21, 'system'),
    ('html_sys_001', 'hp-22', 'recv-in', '검수', '입고 원료의 온도·포장·표시가 기준에 적합한가?', 'YN', NULL, '입고(입고시)', 22, 'system'),
    ('html_sys_001', 'hp-23', 'recv-in', '검수', '유통기한 경과·이물·변질 여부를 확인하였는가?', 'YN', NULL, '입고(입고시)', 23, 'system'),
    ('html_sys_001', 'hp-24', 'ship', '운송', '출하 차량의 청결·온도 상태가 적절한가?', 'YN', NULL, '운송(출하시)', 24, 'system'),
    ('html_sys_001', 'hp-25', 'ship', '운송', '제품 적재 시 교차오염을 방지하였는가?', 'YN', NULL, '운송(출하시)', 25, 'system')
ON CONFLICT (tmpl_cd, item_cd) DO UPDATE SET
    grp_cd = EXCLUDED.grp_cd, grp_nm = EXCLUDED.grp_nm, item_nm = EXCLUDED.item_nm,
    input_type = EXCLUDED.input_type, unit_nm = EXCLUDED.unit_nm, cycle_nm = EXCLUDED.cycle_nm,
    sort_no = EXCLUDED.sort_no, upd_id = 'system', upd_dt = now();

INSERT INTO tbl_screen (scrn_cd, scrn_nm, module_cd, tmpl_cd, sort_no, ins_id) VALUES
    ('hygiene-process-check', '일반위생관리 및 공정점검표', 'HYG', 'html_sys_001', 211, 'system'),
    ('hyg-process-template', '일반위생·공정점검 양식관리', 'SET', 'html_sys_001', 1311, 'system')
ON CONFLICT (scrn_cd) DO UPDATE SET
    scrn_nm = EXCLUDED.scrn_nm, module_cd = EXCLUDED.module_cd, tmpl_cd = EXCLUDED.tmpl_cd,
    sort_no = EXCLUDED.sort_no, upd_id = 'system', upd_dt = now();

INSERT INTO tbl_role_screen (co_cd, usrgrp_cd, scrn_cd, read_yn, write_yn, modify_yn, delete_yn, print_yn, ins_id, ins_dt)
SELECT r.co_cd, r.usrgrp_cd, s.scrn_cd,
       'Y', 'Y', 'Y',
       CASE WHEN r.usrgrp_cd = 'ADMIN' THEN 'Y' ELSE 'N' END,
       'Y', 'system', now()
  FROM tbl_role r
  CROSS JOIN (VALUES ('hygiene-process-check'), ('hyg-process-template')) AS s(scrn_cd)
ON CONFLICT (co_cd, usrgrp_cd, scrn_cd) DO NOTHING;

INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, 'menu-master-html', 'HTML양식 원본', 'menu-doc-master', NULL, 4250, 'Y', 'system', now()
  FROM (SELECT co_cd FROM tbl_company UNION SELECT DISTINCT co_cd FROM tbl_menu) c
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm, h_menu_cd = EXCLUDED.h_menu_cd, scrn_cd = NULL,
    use_yn = 'Y', sort_no = EXCLUDED.sort_no, upd_id = 'system', upd_dt = now();

INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, 'menu-' || v.scrn_cd, COALESCE(s.scrn_nm, v.scrn_cd),
       v.h_menu_cd, v.scrn_cd, COALESCE(s.sort_no, v.sort_no), 'Y', 'system', now()
  FROM (SELECT co_cd FROM tbl_company UNION SELECT DISTINCT co_cd FROM tbl_menu) c
 CROSS JOIN (VALUES
        ('hyg-process-template', 'menu-master-html', 311),
        ('hygiene-process-check', 'menu-write-prp', 103)
       ) AS v(scrn_cd, h_menu_cd, sort_no)
  JOIN tbl_screen s ON s.scrn_cd = v.scrn_cd
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm, h_menu_cd = EXCLUDED.h_menu_cd, scrn_cd = EXCLUDED.scrn_cd,
    sort_no = EXCLUDED.sort_no, use_yn = 'Y', upd_id = 'system', upd_dt = now();

INSERT INTO tbl_doc_no_rule (co_cd, tmpl_cd, prefix, date_fmt, seq_len, reset_cycle, ins_id, ins_dt)
SELECT c.co_cd, 'html_sys_001', 'html_sys_001', 'YYYYMMDD', 3, 'D', 'system', now()
  FROM tbl_company c
ON CONFLICT (co_cd, tmpl_cd) DO NOTHING;

INSERT INTO tbl_company_template (co_cd, tmpl_cd, cycle_cd, retention_month, use_yn, sys_yn, ins_id, ins_dt)
SELECT c.co_cd, 'html_sys_001', 'D', 24, 'Y', 'sys', 'system', now()
  FROM tbl_company c
ON CONFLICT (co_cd, tmpl_cd) DO NOTHING;

-- ------------------------------------------------------------
-- 4. SP — 버전 목록 (표준 가상행 ver_no=0)
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_html_form_ver_r_000(varchar, varchar);
CREATE FUNCTION sp_tbl_html_form_ver_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd  varchar,
    -- p_tmpl_cd: 양식코드
    p_tmpl_cd varchar
)
RETURNS TABLE(
    ver_no    int,
    ver_nm    varchar,
    sys_yn    varchar,
    apply_yn  varchar,
    locked_yn varchar
) LANGUAGE sql STABLE AS $$
    SELECT 0, '표준'::varchar, 'sys'::varchar,
           CASE WHEN EXISTS (
                SELECT 1 FROM tbl_html_form_ver v
                 WHERE v.co_cd = p_co_cd AND v.tmpl_cd = p_tmpl_cd AND v.apply_yn = 'Y'
           ) THEN 'N' ELSE 'Y' END,
           'Y'::varchar
    UNION ALL
    SELECT v.ver_no, v.ver_nm, 'usr'::varchar, v.apply_yn, 'N'::varchar
      FROM tbl_html_form_ver v
     WHERE v.co_cd = p_co_cd AND v.tmpl_cd = p_tmpl_cd
     ORDER BY 1;
$$;

DROP FUNCTION IF EXISTS sp_tbl_html_form_ver_item_r_000(varchar, varchar, int);
CREATE FUNCTION sp_tbl_html_form_ver_item_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_tmpl_cd: 양식코드
    p_tmpl_cd varchar,
    -- p_ver_no: 0=표준
    p_ver_no  int
)
RETURNS TABLE(
    item_cd    varchar,
    sort_no    int,
    cycle_nm   varchar,
    grp_nm     varchar,
    item_nm    text,
    input_type varchar,
    unit_nm    varchar
) LANGUAGE plpgsql STABLE AS $$
BEGIN
    IF COALESCE(p_ver_no, 0) <= 0 THEN
        RETURN QUERY
        SELECT c.item_cd, c.sort_no, c.cycle_nm, c.grp_nm, c.item_nm, c.input_type, c.unit_nm
          FROM tbl_check_item c
         WHERE c.tmpl_cd = p_tmpl_cd AND c.use_yn = 'Y'
         ORDER BY c.sort_no, c.item_cd;
    ELSE
        RETURN QUERY
        SELECT i.item_cd, i.sort_no, i.cycle_nm, i.grp_nm, i.item_nm, i.input_type, i.unit_nm
          FROM tbl_html_form_ver_item i
         WHERE i.co_cd = p_co_cd AND i.tmpl_cd = p_tmpl_cd AND i.ver_no = p_ver_no
         ORDER BY i.sort_no, i.item_cd;
    END IF;
END$$;

CREATE OR REPLACE PROCEDURE sp_tbl_html_form_ver_copy_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd     varchar,
    -- p_tmpl_cd: 양식코드
    p_tmpl_cd   varchar,
    -- p_src_ver_no: 복사 원본. 0=표준
    p_src_ver_no int,
    -- p_ver_nm: 새 버전명
    p_ver_nm    varchar,
    -- p_id: 작업자
    p_id        varchar
)
LANGUAGE plpgsql AS $$
DECLARE v_no int;
BEGIN
    IF COALESCE(p_co_cd, '') = '' OR COALESCE(p_tmpl_cd, '') = '' THEN
        RAISE EXCEPTION '회사·양식코드는 필수입니다.' USING ERRCODE = '45000';
    END IF;
    IF COALESCE(btrim(p_ver_nm), '') = '' THEN
        RAISE EXCEPTION '버전명을 입력하세요.' USING ERRCODE = '45000';
    END IF;
    SELECT COALESCE(MAX(ver_no), 0) + 1 INTO v_no
      FROM tbl_html_form_ver WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    INSERT INTO tbl_html_form_ver (co_cd, tmpl_cd, ver_no, ver_nm, apply_yn, ins_id, ins_dt)
    VALUES (p_co_cd, p_tmpl_cd, v_no, btrim(p_ver_nm), 'N', p_id, now());
    IF COALESCE(p_src_ver_no, 0) <= 0 THEN
        INSERT INTO tbl_html_form_ver_item (
            co_cd, tmpl_cd, ver_no, item_cd, sort_no, cycle_nm, grp_nm, item_nm, input_type, unit_nm, ins_id
        )
        SELECT p_co_cd, p_tmpl_cd, v_no, c.item_cd, c.sort_no, c.cycle_nm, c.grp_nm, c.item_nm, c.input_type, c.unit_nm, p_id
          FROM tbl_check_item c
         WHERE c.tmpl_cd = p_tmpl_cd AND c.use_yn = 'Y';
    ELSE
        INSERT INTO tbl_html_form_ver_item (
            co_cd, tmpl_cd, ver_no, item_cd, sort_no, cycle_nm, grp_nm, item_nm, input_type, unit_nm, ins_id
        )
        SELECT p_co_cd, p_tmpl_cd, v_no, i.item_cd, i.sort_no, i.cycle_nm, i.grp_nm, i.item_nm, i.input_type, i.unit_nm, p_id
          FROM tbl_html_form_ver_item i
         WHERE i.co_cd = p_co_cd AND i.tmpl_cd = p_tmpl_cd AND i.ver_no = p_src_ver_no;
    END IF;
END$$;

CREATE OR REPLACE PROCEDURE sp_tbl_html_form_ver_item_u_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_tmpl_cd: 양식코드
    p_tmpl_cd varchar,
    -- p_ver_no: 사용자 버전만
    p_ver_no  int,
    -- p_items: 항목 JSON 배열
    p_items   jsonb,
    -- p_id: 작업자
    p_id      varchar
)
LANGUAGE plpgsql AS $$
DECLARE e jsonb; v_cnt int := 0;
BEGIN
    IF COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 항목은 수정할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM tbl_html_form_ver
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no
    ) THEN
        RAISE EXCEPTION '버전을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' THEN
        RAISE EXCEPTION '점검항목 자료가 올바르지 않습니다.' USING ERRCODE = '45000';
    END IF;
    DELETE FROM tbl_html_form_ver_item
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
    FOR e IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_cnt := v_cnt + 1;
        INSERT INTO tbl_html_form_ver_item (
            co_cd, tmpl_cd, ver_no, item_cd, sort_no, cycle_nm, grp_nm, item_nm, input_type, unit_nm, ins_id, upd_id, upd_dt
        ) VALUES (
            p_co_cd, p_tmpl_cd, p_ver_no,
            COALESCE(NULLIF(e->>'itemCd', ''), 'hp-u-' || lpad(v_cnt::text, 3, '0')),
            COALESCE(NULLIF(e->>'sortNo', '')::int, v_cnt),
            NULLIF(e->>'cycleNm', ''),
            NULLIF(e->>'grpNm', ''),
            COALESCE(e->>'itemNm', ''),
            COALESCE(NULLIF(e->>'inputType', ''), 'YN'),
            NULLIF(e->>'unitNm', ''),
            p_id, p_id, now()
        );
    END LOOP;
    UPDATE tbl_html_form_ver SET upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
END$$;

CREATE OR REPLACE PROCEDURE sp_tbl_html_form_ver_apply_u_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd   varchar,
    -- p_tmpl_cd: 양식코드
    p_tmpl_cd varchar,
    -- p_ver_no: 0이면 표준 적용(회사 버전 apply 전부 N)
    p_ver_no  int,
    -- p_id: 작업자
    p_id      varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE tbl_html_form_ver SET apply_yn = 'N', upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    IF COALESCE(p_ver_no, 0) > 0 THEN
        UPDATE tbl_html_form_ver SET apply_yn = 'Y', upd_id = p_id, upd_dt = now()
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
        IF NOT FOUND THEN
            RAISE EXCEPTION '버전을 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
    END IF;
END$$;

DROP FUNCTION IF EXISTS sp_tbl_html_form_ver_delete_blocker_r_000(varchar, varchar, int);
CREATE FUNCTION sp_tbl_html_form_ver_delete_blocker_r_000(
    p_co_cd   varchar,
    p_tmpl_cd varchar,
    p_ver_no  int
)
RETURNS TABLE(ref_key varchar, target varchar) LANGUAGE plpgsql STABLE AS $$
BEGIN
    IF COALESCE(p_ver_no, 0) <= 0 THEN
        RETURN QUERY SELECT '표준'::varchar, '시스템 표준 항목'::varchar;
        RETURN;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM tbl_html_form_ver
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no
    ) THEN
        RETURN QUERY SELECT COALESCE(p_ver_no::varchar, '')::varchar, '없는 버전'::varchar;
    END IF;
END$$;

CREATE OR REPLACE PROCEDURE sp_tbl_html_form_ver_d_000(
    p_co_cd   varchar,
    p_tmpl_cd varchar,
    p_ver_no  int,
    p_id      varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    IF COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 항목은 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    DELETE FROM tbl_html_form_ver_item
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
    DELETE FROM tbl_html_form_ver
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
    IF NOT FOUND THEN
        RAISE EXCEPTION '버전을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
END$$;

-- ------------------------------------------------------------
-- 5. SP — 작성 목록·상세·저장·삭제
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_hyg_process_r_000(varchar, varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_hyg_process_r_000(
    p_co_cd  varchar,
    p_from_dt varchar,
    p_to_dt   varchar,
    p_doc_no  varchar,
    p_writer  varchar
)
RETURNS TABLE(
    doc_idx    bigint,
    hdr_idx    bigint,
    doc_no     varchar,
    base_dt    varchar,
    checker_nm varchar,
    status     varchar,
    row_cnt    int,
    ng_cnt     int
) LANGUAGE sql STABLE AS $$
    SELECT d.idx, h.idx, d.doc_no, d.base_dt, h.checker_nm, d.status,
           (SELECT count(*)::int FROM tbl_hyg_process_item i WHERE i.hdr_idx = h.idx AND i.co_cd = h.co_cd),
           (SELECT count(*)::int FROM tbl_hyg_process_item i WHERE i.hdr_idx = h.idx AND i.co_cd = h.co_cd AND i.yn = 'N')
      FROM tbl_document d
      JOIN tbl_hyg_process h ON h.doc_idx = d.idx AND h.co_cd = d.co_cd
     WHERE d.co_cd = p_co_cd AND d.tmpl_cd = 'html_sys_001' AND d.del_yn = 'N'
       AND (COALESCE(NULLIF(btrim(p_from_dt), ''), '') = '' OR d.base_dt >= btrim(p_from_dt))
       AND (COALESCE(NULLIF(btrim(p_to_dt), ''), '') = '' OR d.base_dt <= btrim(p_to_dt))
       AND d.doc_no LIKE '%' || COALESCE(p_doc_no, '') || '%'
       AND (
            COALESCE(NULLIF(btrim(p_writer), ''), '') = ''
            OR d.writer_id LIKE '%' || btrim(p_writer) || '%'
            OR COALESCE(h.checker_nm, '') LIKE '%' || btrim(p_writer) || '%'
           )
     ORDER BY d.base_dt DESC, d.doc_no DESC;
$$;

DROP FUNCTION IF EXISTS sp_tbl_hyg_process_r_001(varchar, bigint);
CREATE FUNCTION sp_tbl_hyg_process_r_001(
    p_co_cd  varchar,
    p_doc_idx bigint
)
RETURNS jsonb LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_apply int := 0;
    v_out jsonb;
BEGIN
    IF COALESCE(p_doc_idx, 0) > 0 THEN
        SELECT jsonb_build_object(
            'header', jsonb_build_object(
                'docIdx', d.idx,
                'docNo', d.doc_no,
                'status', d.status,
                'baseDt', d.base_dt,
                'checkerNm', h.checker_nm,
                'verNo', h.ver_no,
                'specialNote', h.special_note,
                'improveNote', h.improve_note,
                'actionNm', h.action_nm,
                'confirmNm', h.confirm_nm,
                'writerNm', d.writer_id
            ),
            'items', COALESCE((
                SELECT jsonb_agg(jsonb_build_object(
                    'itemCd', i.item_cd,
                    'sortNo', i.sort_no,
                    'cycleNm', i.cycle_nm,
                    'grpNm', i.grp_nm,
                    'itemNm', i.item_nm,
                    'inputType', i.input_type,
                    'unitNm', i.unit_nm,
                    'yn', i.yn,
                    'valNm', i.val_nm
                ) ORDER BY i.sort_no)
                FROM tbl_hyg_process_item i WHERE i.hdr_idx = h.idx AND i.co_cd = h.co_cd
            ), '[]'::jsonb)
        )
          INTO v_out
          FROM tbl_document d
          JOIN tbl_hyg_process h ON h.doc_idx = d.idx AND h.co_cd = d.co_cd
         WHERE d.co_cd = p_co_cd AND d.idx = p_doc_idx AND d.tmpl_cd = 'html_sys_001' AND d.del_yn = 'N';
        IF v_out IS NULL THEN
            RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        RETURN v_out;
    END IF;

    SELECT ver_no INTO v_apply
      FROM tbl_html_form_ver
     WHERE co_cd = p_co_cd AND tmpl_cd = 'html_sys_001' AND apply_yn = 'Y';
    v_apply := COALESCE(v_apply, 0);

    SELECT jsonb_build_object(
        'header', jsonb_build_object(
            'docIdx', NULL,
            'docNo', '',
            'status', NULL,
            'baseDt', to_char(CURRENT_DATE, 'YYYYMMDD'),
            'checkerNm', '',
            'verNo', v_apply,
            'specialNote', '',
            'improveNote', '',
            'actionNm', '',
            'confirmNm', ''
        ),
        'items', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'itemCd', x.item_cd,
                'sortNo', x.sort_no,
                'cycleNm', x.cycle_nm,
                'grpNm', x.grp_nm,
                'itemNm', x.item_nm,
                'inputType', x.input_type,
                'unitNm', x.unit_nm,
                'yn', '',
                'valNm', ''
            ) ORDER BY x.sort_no)
            FROM (
                SELECT * FROM sp_tbl_html_form_ver_item_r_000(p_co_cd, 'html_sys_001', v_apply)
            ) x
        ), '[]'::jsonb)
    ) INTO v_out;
    RETURN v_out;
END$$;

DROP FUNCTION IF EXISTS sp_tbl_hyg_process_c_000(varchar, bigint, varchar, varchar, jsonb, varchar);
CREATE FUNCTION sp_tbl_hyg_process_c_000(
    p_co_cd      varchar,
    p_doc_idx    bigint,
    p_base_dt    varchar,
    p_checker_nm varchar,
    p_payload    jsonb,
    p_id         varchar
) RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE
    v_doc bigint; v_hdr bigint; v_status varchar; v_no varchar; v_name varchar; v_appr varchar; v_retain int;
    v_ver int; e jsonb; v_seq int := 0;
BEGIN
    IF COALESCE(p_co_cd, '') = '' OR COALESCE(p_base_dt, '') = '' OR length(p_base_dt) <> 8 THEN
        RAISE EXCEPTION '점검일자는 YYYYMMDD 8자리로 입력하세요.' USING ERRCODE = '45000';
    END IF;
    IF p_payload IS NULL OR jsonb_typeof(COALESCE(p_payload->'items', 'null'::jsonb)) <> 'array' THEN
        RAISE EXCEPTION '점검행 자료가 올바르지 않습니다.' USING ERRCODE = '45000';
    END IF;
    SELECT COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm), COALESCE(ct.appr_line_cd, 'DEFAULT'),
           COALESCE(ct.retention_month, t.default_retention_month)
      INTO v_name, v_appr, v_retain
      FROM tbl_template t
      LEFT JOIN tbl_company_template ct ON ct.co_cd = p_co_cd AND ct.tmpl_cd = t.tmpl_cd AND ct.use_yn = 'Y'
     WHERE t.tmpl_cd = 'html_sys_001' AND t.use_yn = 'Y';
    IF v_name IS NULL THEN
        RAISE EXCEPTION '등록되지 않은 양식입니다.' USING ERRCODE = '45000';
    END IF;
    v_ver := COALESCE(NULLIF(p_payload->>'verNo', '')::int, 0);
    IF COALESCE(p_doc_idx, 0) = 0 THEN
        v_no := sp_tbl_doc_no_gen_c_000(p_co_cd, 'html_sys_001', p_base_dt);
        INSERT INTO tbl_document (
            co_cd, tmpl_cd, doc_kind, doc_no, base_dt, title, status, appr_line_cd,
            writer_id, write_dt, ver_no, retention_until, del_yn, ins_id, ins_dt
        ) VALUES (
            p_co_cd, 'html_sys_001', 'html', v_no, p_base_dt,
            v_name || ' (' || substr(p_base_dt, 1, 4) || '-' || substr(p_base_dt, 5, 2) || '-' || substr(p_base_dt, 7, 2) || ')',
            'WRK', v_appr, p_id, now(), 1,
            to_char((to_date(p_base_dt, 'YYYYMMDD') + (COALESCE(v_retain, 24) || ' months')::interval)::date, 'YYYYMMDD'),
            'N', p_id, now()
        ) RETURNING idx INTO v_doc;
        INSERT INTO tbl_hyg_process (
            co_cd, doc_idx, base_dt, checker_nm, ver_no,
            special_note, improve_note, action_nm, confirm_nm, ins_id
        ) VALUES (
            p_co_cd, v_doc, p_base_dt, NULLIF(p_checker_nm, ''), v_ver,
            NULLIF(p_payload->>'specialNote', ''), NULLIF(p_payload->>'improveNote', ''),
            NULLIF(p_payload->>'actionNm', ''), NULLIF(p_payload->>'confirmNm', ''), p_id
        ) RETURNING idx INTO v_hdr;
    ELSE
        SELECT d.idx, d.status, h.idx INTO v_doc, v_status, v_hdr
          FROM tbl_document d
          JOIN tbl_hyg_process h ON h.doc_idx = d.idx AND h.co_cd = d.co_cd
         WHERE d.co_cd = p_co_cd AND d.idx = p_doc_idx AND d.tmpl_cd = 'html_sys_001' AND d.del_yn = 'N';
        IF v_doc IS NULL THEN
            RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        IF v_status NOT IN ('WRK', 'RJT') THEN
            RAISE EXCEPTION '결재 진행 중이거나 완료된 문서는 수정할 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        UPDATE tbl_document SET
            base_dt = p_base_dt,
            title = v_name || ' (' || substr(p_base_dt, 1, 4) || '-' || substr(p_base_dt, 5, 2) || '-' || substr(p_base_dt, 7, 2) || ')',
            upd_id = p_id, upd_dt = now()
         WHERE idx = v_doc AND co_cd = p_co_cd;
        UPDATE tbl_hyg_process SET
            base_dt = p_base_dt, checker_nm = NULLIF(p_checker_nm, ''), ver_no = v_ver,
            special_note = NULLIF(p_payload->>'specialNote', ''),
            improve_note = NULLIF(p_payload->>'improveNote', ''),
            action_nm = NULLIF(p_payload->>'actionNm', ''),
            confirm_nm = NULLIF(p_payload->>'confirmNm', ''),
            upd_id = p_id, upd_dt = now()
         WHERE idx = v_hdr AND co_cd = p_co_cd;
        DELETE FROM tbl_hyg_process_item WHERE hdr_idx = v_hdr AND co_cd = p_co_cd;
    END IF;
    FOR e IN SELECT * FROM jsonb_array_elements(p_payload->'items') LOOP
        v_seq := v_seq + 1;
        INSERT INTO tbl_hyg_process_item (
            co_cd, hdr_idx, sort_no, item_cd, cycle_nm, grp_nm, item_nm, input_type, unit_nm, yn, val_nm, ins_id
        ) VALUES (
            p_co_cd, v_hdr, COALESCE(NULLIF(e->>'sortNo', '')::int, v_seq),
            COALESCE(NULLIF(e->>'itemCd', ''), 'hp-u-' || lpad(v_seq::text, 3, '0')),
            NULLIF(e->>'cycleNm', ''), NULLIF(e->>'grpNm', ''), NULLIF(e->>'itemNm', ''),
            COALESCE(NULLIF(e->>'inputType', ''), 'YN'), NULLIF(e->>'unitNm', ''),
            NULLIF(e->>'yn', ''), NULLIF(e->>'valNm', ''), p_id
        );
    END LOOP;
    RETURN v_doc;
END$$;

CREATE OR REPLACE PROCEDURE sp_tbl_hyg_process_d_000(
    p_co_cd   varchar,
    p_doc_idx bigint,
    p_id      varchar
)
LANGUAGE plpgsql AS $$
DECLARE v_status varchar; v_hdr bigint;
BEGIN
    SELECT d.status, h.idx INTO v_status, v_hdr
      FROM tbl_document d
      JOIN tbl_hyg_process h ON h.doc_idx = d.idx AND h.co_cd = d.co_cd
     WHERE d.co_cd = p_co_cd AND d.idx = p_doc_idx AND d.tmpl_cd = 'html_sys_001' AND d.del_yn = 'N';
    IF v_hdr IS NULL THEN
        RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF v_status NOT IN ('WRK', 'RJT') THEN
        RAISE EXCEPTION '결재 진행 중이거나 완료된 문서는 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    DELETE FROM tbl_corrective_action WHERE co_cd = p_co_cd AND src_doc_idx = p_doc_idx;
    DELETE FROM tbl_hyg_process_item WHERE co_cd = p_co_cd AND hdr_idx = v_hdr;
    DELETE FROM tbl_hyg_process WHERE co_cd = p_co_cd AND idx = v_hdr;
    DELETE FROM tbl_document_approval WHERE co_cd = p_co_cd AND doc_idx = p_doc_idx;
    DELETE FROM tbl_document_file WHERE co_cd = p_co_cd AND doc_idx = p_doc_idx;
    DELETE FROM tbl_document WHERE co_cd = p_co_cd AND idx = p_doc_idx;
END$$;

-- ------------------------------------------------------------
-- 6. 문서주기 좌측 — html_sys_012 포함 (011 숨김)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_schedule_cycle_management_form_r_000(
    p_co_cd   varchar,
    p_tmpl_cd varchar,
    p_tmpl_nm varchar,
    p_use_yn  varchar
)
RETURNS TABLE(
    tmpl_cd  varchar,
    tmpl_nm  varchar,
    sys_yn   varchar,
    doc_kind varchar,
    cycle_cd varchar,
    rule_yn  varchar,
    use_yn   varchar
) LANGUAGE sql STABLE AS $$
    SELECT ct.tmpl_cd,
           COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm),
           lower(CASE WHEN COALESCE(ct.sys_yn, 'sys') IN ('N', 'n', 'usr') THEN 'usr' ELSE 'sys' END),
           t.doc_kind,
           r.cycle_cd,
           CASE WHEN r.idx IS NULL THEN 'N' ELSE 'Y' END,
           upper(COALESCE(ct.use_yn, 'N'))
      FROM tbl_company_template ct
      JOIN tbl_template t ON t.tmpl_cd = ct.tmpl_cd
      LEFT JOIN tbl_schedule_rule r ON r.co_cd = ct.co_cd AND r.tmpl_cd = ct.tmpl_cd
     WHERE ct.co_cd = p_co_cd
       AND (
            ct.tmpl_cd ~ '^html_sys_0(0[1-9]|10|12)$'
         OR ct.tmpl_cd ~ '^hwp_sys_0(0[1-9]|1[0-9]|2[0-7])$'
         OR ct.tmpl_cd LIKE 'hwp_usr_%'
       )
       AND (
            COALESCE(NULLIF(btrim(p_use_yn), ''), '') = ''
            OR upper(COALESCE(ct.use_yn, 'N')) = upper(btrim(p_use_yn))
           )
       AND ct.tmpl_cd LIKE CONCAT('%', COALESCE(p_tmpl_cd, ''), '%')
       AND COALESCE(ct.tmpl_nm_ovr, t.tmpl_nm) LIKE CONCAT('%', COALESCE(p_tmpl_nm, ''), '%')
     ORDER BY t.sort_no, ct.tmpl_cd;
$$;

CALL sp_tbl_menu_sort_encode_u_000(NULL);
