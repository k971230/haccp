-- ============================================================
-- 113 — CCP-3P 금속검출 모니터링일지 HTML 양식 원본 tml_ccp_mtl_NNN
--
-- 파일번호: 113
-- 이전번호: 112
-- 개발자: 박승우
-- 일자: 2026-08-20
-- 코멘트:
--   1) 저장은 tbl_tml_ccp_mtl_ver. 예시는 tml_ccp_mtl_000 (한계기준·주기·방법·감도열·개선조치)
--   2) 새 html_sys 카탈로그는 두지 않는다. copy SP가 usr tbl_template 를 직접 INSERT 한다
--   3) 작성 화면은 후속. 기본 주기 D. 문서주기 좌측은 tml_ccp_mtl_001+ 만
--
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. DDL
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_tml_ccp_mtl_ver (
    idx      bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd    varchar(10)  NOT NULL,
    tmpl_cd  varchar(40)  NOT NULL,
    ver_no   int          NOT NULL,
    ver_cd   varchar(20)  NOT NULL,
    ver_nm   varchar(100) NOT NULL,
    apply_yn varchar(1)   NOT NULL DEFAULT 'N',
    use_yn   varchar(1)   NOT NULL DEFAULT 'Y',
    ins_id   varchar(20)  NULL,
    ins_dt   timestamp    NULL DEFAULT now(),
    upd_id   varchar(20)  NULL,
    upd_dt   timestamp    NULL,
    CONSTRAINT ux_tbl_tml_ccp_mtl_ver UNIQUE (co_cd, tmpl_cd, ver_no),
    CONSTRAINT ck_tbl_tml_ccp_mtl_ver_no CHECK (ver_no >= 1),
    CONSTRAINT ck_tbl_tml_ccp_mtl_ver_apply CHECK (apply_yn IN ('Y', 'N')),
    CONSTRAINT ck_tbl_tml_ccp_mtl_ver_use CHECK (use_yn IN ('Y', 'N'))
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_tbl_tml_ccp_mtl_ver_apply
    ON tbl_tml_ccp_mtl_ver (co_cd, tmpl_cd) WHERE apply_yn = 'Y';
CREATE UNIQUE INDEX IF NOT EXISTS ux_tbl_tml_ccp_mtl_ver_cd
    ON tbl_tml_ccp_mtl_ver (co_cd, tmpl_cd, ver_cd) WHERE use_yn = 'Y';
COMMENT ON TABLE tbl_tml_ccp_mtl_ver IS 'CCP-3P 금속검출 모니터링일지 자사 양식 버전 — 예시는 tml_ccp_mtl_000 가상';

CREATE TABLE IF NOT EXISTS tbl_tml_ccp_mtl_ver_item (
    idx        bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd      varchar(10)  NOT NULL,
    tmpl_cd    varchar(40)  NOT NULL,
    ver_no     int          NOT NULL,
    item_cd    varchar(20)  NOT NULL,
    sort_no    int          NOT NULL DEFAULT 0,
    cycle_nm   varchar(50)  NULL,
    grp_nm     varchar(100) NULL,
    item_nm    text         NOT NULL,
    input_type varchar(20)  NOT NULL DEFAULT 'text',
    unit_nm    varchar(20)  NULL,
    ins_id     varchar(20)  NULL,
    ins_dt     timestamp    NULL DEFAULT now(),
    upd_id     varchar(20)  NULL,
    upd_dt     timestamp    NULL,
    CONSTRAINT ux_tbl_tml_ccp_mtl_ver_item UNIQUE (co_cd, tmpl_cd, ver_no, item_cd)
);
COMMENT ON TABLE tbl_tml_ccp_mtl_ver_item IS 'CCP-3P 금속검출 모니터링일지 자사 양식 항목 — 한계기준·주기·방법·감도열 해당없음·개선조치';

-- ------------------------------------------------------------
-- 2. 시드 항목 — tml_ccp_mtl_000. 긴 문구는 item_nm
-- ------------------------------------------------------------
INSERT INTO tbl_check_item (
    tmpl_cd, item_cd, grp_cd, grp_nm, item_nm, input_type, unit_nm, cycle_nm, sort_no, ins_id
) VALUES
    ('tml_ccp_mtl_000', 'limit-metal', 'limit', '한계기준',
     '○ 금속이물(Fe 2.5mmΦ. SUS 4.0mmΦ 이상) 불검출',
     'text', NULL, '금속이물', 1, 'system'),
    ('tml_ccp_mtl_000', 'limit-run', 'limit', '한계기준',
     '금속검출기 정상작동 여부 확인',
     'text', NULL, '정상작동', 2, 'system'),
    ('tml_ccp_mtl_000', 'cycle', 'cycle', '주기',
     $y$금속검출기 정상작동 여부 확인
작업시작 전, 작업 중 2시간마다, 작업 종료 후
금속검출기에 의한 공정품 확인
작업 중 상시$y$,
     'text', NULL, NULL, 3, 'system'),
    ('tml_ccp_mtl_000', 'method', 'method', '방법',
     $m$○ 기기감도 : 모니터링담당자는 기기 중간에 Test piece를 통과시켜 검출여부를 확인하고 일지에 기록한다.
○ 제품감도 : 모니터링담당자는 제품 중간에 Test piece를 넣고 기기에 통과시켜 검출여부를 확인하고 일지에 기록한다.
○ 통과량 및 검출량 : 모니터링담당자는 통과된 양과 검출된 양을 일지에 기록하고 HACCP팀장에 보고한다.
※ 금속검출기는 연1회 이상 정상작동 유무 확인$m$,
     'text', NULL, NULL, 4, 'system'),
    ('tml_ccp_mtl_000', 'hdr-fe', 'hdr', '감도열',
     'Fe만 통과',
     'text', 'N', NULL, 5, 'system'),
    ('tml_ccp_mtl_000', 'hdr-sus', 'hdr', '감도열',
     'SUS만 통과',
     'text', 'N', NULL, 6, 'system'),
    ('tml_ccp_mtl_000', 'hdr-prod', 'hdr', '감도열',
     '제품만 통과',
     'text', 'Y', NULL, 7, 'system'),
    ('tml_ccp_mtl_000', 'hdr-fe-prod', 'hdr', '감도열',
     'Fe+제품 통과',
     'text', 'Y', NULL, 8, 'system'),
    ('tml_ccp_mtl_000', 'hdr-sus-prod', 'hdr', '감도열',
     'SUS+제품 통과',
     'text', 'Y', NULL, 9, 'system'),
    ('tml_ccp_mtl_000', 'corrective', 'ca', '개선조치 방법',
     $c$◌ 금속성 이물 검출 시
 - 모니터링 담당자는 즉시 금속검출기의 작업을 중지하고 공정품을 보류하고 해당(이탈) 제품을 제거한다.
 - 공정품에 혼입된 금속이물을 찾아내고, 그 출처를 조사하여 원인을 제거한다.
 - 금속이물 검출 내역 및 개선조치 사항을 모니터링 일지에 기록
◌ 감도 이상 발생 시
 - 모니터링 담당자는 즉시 금속검출기의 작업을 중지하고 공정품을 보류한다.
 - 감도를 재조정한 후 정상적으로 작동 시 재가동한다.
 - 감도이상 발생 전부터 정상운전 확인시점까지 생산된 제품을 다시 검사한다.
 - 재검사 후 그 내역 또는 개선조치 사항을 모니터링 일지에 기록
◌ 기계적 고장 시
 - 모니터링 담당자는 즉시 금속검출기의 작업을 중지하고 공정품을 보류한다.
 - 수리 후 정상적으로 작동 시 재가동한다.
 - 수리 불가능할 때에는 납품업체에 수리를 의뢰한다.
 ☆ 금속검출기의 고장으로 정상 운전 확인 이후에 생산된 제품과 금속검출기 미 통과제품에 대해서는 전량 검사대기품 표시(냉동보관)를 하여 금속검출기 수리 완료 후 전량 재통과한다.
◌ 공통 : 개선조치 시
 - 문제 발생 시 HACCP팀장에게 보고 후 조치하며, 개선조치 후 모니터링 일지에 기록 후 HACCP팀장에게 승인을 받는다.$c$,
     'text', NULL, NULL, 10, 'system')
ON CONFLICT (tmpl_cd, item_cd) DO UPDATE SET
    grp_cd = EXCLUDED.grp_cd, grp_nm = EXCLUDED.grp_nm, item_nm = EXCLUDED.item_nm,
    input_type = EXCLUDED.input_type, unit_nm = EXCLUDED.unit_nm, cycle_nm = EXCLUDED.cycle_nm,
    sort_no = EXCLUDED.sort_no, use_yn = 'Y', upd_id = 'system', upd_dt = now();

-- ------------------------------------------------------------
-- 3. 화면·권한·메뉴 — HTML양식 원본 밑, 가열일지 다음
-- ------------------------------------------------------------
INSERT INTO tbl_screen (scrn_cd, scrn_nm, module_cd, tmpl_cd, sort_no, ins_id) VALUES
    ('ccp-mtl-template', '중요관리점(CCP-3P) 모니터링일지', 'SET', NULL, 1315, 'system')
ON CONFLICT (scrn_cd) DO UPDATE SET
    scrn_nm = EXCLUDED.scrn_nm, module_cd = EXCLUDED.module_cd, tmpl_cd = EXCLUDED.tmpl_cd,
    sort_no = EXCLUDED.sort_no, upd_id = 'system', upd_dt = now();

INSERT INTO tbl_role_screen (co_cd, usrgrp_cd, scrn_cd, read_yn, write_yn, modify_yn, delete_yn, print_yn, ins_id, ins_dt)
SELECT r.co_cd, r.usrgrp_cd, 'ccp-mtl-template',
       'Y', 'Y', 'Y',
       CASE WHEN r.usrgrp_cd = 'ADMIN' THEN 'Y' ELSE 'N' END,
       'Y', 'system', now()
  FROM tbl_role r
ON CONFLICT (co_cd, usrgrp_cd, scrn_cd) DO NOTHING;

INSERT INTO tbl_menu (co_cd, menu_cd, menu_nm, h_menu_cd, scrn_cd, sort_no, use_yn, ins_id, ins_dt)
SELECT c.co_cd, 'menu-ccp-mtl-template', COALESCE(s.scrn_nm, 'ccp-mtl-template'),
       'menu-master-html', 'ccp-mtl-template',
       COALESCE((
           SELECT MAX(m.sort_no) + 1 FROM tbl_menu m
            WHERE m.co_cd = c.co_cd AND m.h_menu_cd = 'menu-master-html'
       ), 4254),
       'Y', 'system', now()
  FROM (SELECT co_cd FROM tbl_company UNION SELECT DISTINCT co_cd FROM tbl_menu) c
  JOIN tbl_screen s ON s.scrn_cd = 'ccp-mtl-template'
ON CONFLICT (co_cd, menu_cd) DO UPDATE SET
    menu_nm = EXCLUDED.menu_nm, h_menu_cd = EXCLUDED.h_menu_cd, scrn_cd = EXCLUDED.scrn_cd,
    sort_no = EXCLUDED.sort_no, use_yn = 'Y', upd_id = 'system', upd_dt = now();

-- ------------------------------------------------------------
-- 4. SP — tbl_tml_ccp_mtl_ver
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_tml_ccp_mtl_ver_r_000(varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_tml_ccp_mtl_ver_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_tmpl_cd: 호환. 목록은 tml_ccp_mtl 고정
    p_tmpl_cd varchar,
    -- p_ver_cd: 양식코드 부분검색. 빈값이면 전체
    p_ver_cd varchar DEFAULT NULL,
    -- p_ver_nm: 양식명 부분검색. 빈값이면 전체
    p_ver_nm varchar DEFAULT NULL
)
RETURNS TABLE(
    idx bigint, tmpl_cd varchar, ver_no int, ver_cd varchar, ver_nm varchar,
    sys_yn varchar, apply_yn varchar, locked_yn varchar, ins_nm varchar, ins_dt varchar
) LANGUAGE sql STABLE AS $$
    SELECT x.idx, x.tmpl_cd, x.ver_no, x.ver_cd, x.ver_nm, x.sys_yn, x.apply_yn, x.locked_yn, x.ins_nm, x.ins_dt
      FROM (
            SELECT NULL::bigint, 'tml_ccp_mtl_000'::varchar, 0, 'tml_ccp_mtl_000'::varchar,
                   '표준'::varchar, 'sys'::varchar, 'N'::varchar, 'Y'::varchar, ''::varchar, ''::varchar
            UNION ALL
            SELECT v.idx, v.tmpl_cd, v.ver_no,
                   COALESCE(NULLIF(btrim(v.ver_cd), ''), v.tmpl_cd),
                   COALESCE(ct.tmpl_nm_ovr, v.ver_nm),
                   'usr'::varchar, v.apply_yn, 'N'::varchar,
                   COALESCE(u.user_nm, v.ins_id, '')::varchar,
                   COALESCE(to_char(v.ins_dt, 'YYYY-MM-DD'), '')::varchar
              FROM tbl_tml_ccp_mtl_ver v
              JOIN tbl_company_template ct ON ct.co_cd = v.co_cd AND ct.tmpl_cd = v.tmpl_cd
              LEFT JOIN tbl_user u ON u.co_cd = v.co_cd AND u.user_id = v.ins_id
             WHERE v.co_cd = p_co_cd AND v.use_yn = 'Y'
               AND v.tmpl_cd ~ '^tml_ccp_mtl_[0-9]{3}$' AND v.tmpl_cd <> 'tml_ccp_mtl_000'
           ) x(idx, tmpl_cd, ver_no, ver_cd, ver_nm, sys_yn, apply_yn, locked_yn, ins_nm, ins_dt)
     WHERE (COALESCE(btrim(p_ver_cd), '') = '' OR x.tmpl_cd ILIKE '%' || btrim(p_ver_cd) || '%')
       AND (COALESCE(btrim(p_ver_nm), '') = '' OR x.ver_nm ILIKE '%' || btrim(p_ver_nm) || '%')
     ORDER BY x.tmpl_cd;
$$;

DROP FUNCTION IF EXISTS sp_tbl_tml_ccp_mtl_ver_item_r_000(varchar, varchar, int);
CREATE FUNCTION sp_tbl_tml_ccp_mtl_ver_item_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_tmpl_cd: tml_ccp_mtl_000 이면 시드
    p_tmpl_cd varchar,
    -- p_ver_no: 0=표준
    p_ver_no int
)
RETURNS TABLE(
    item_cd varchar, sort_no int, cycle_nm varchar, grp_nm varchar, item_nm text, input_type varchar, unit_nm varchar
) LANGUAGE plpgsql STABLE AS $$
BEGIN
    IF COALESCE(p_tmpl_cd, '') = 'tml_ccp_mtl_000' THEN
        RETURN QUERY
        SELECT c.item_cd, c.sort_no, c.cycle_nm, c.grp_nm, c.item_nm, c.input_type, c.unit_nm
          FROM tbl_check_item c
         WHERE c.tmpl_cd = 'tml_ccp_mtl_000' AND c.use_yn = 'Y'
         ORDER BY c.sort_no, c.item_cd;
        RETURN;
    END IF;
    RETURN QUERY
    SELECT i.item_cd, i.sort_no, i.cycle_nm, i.grp_nm, i.item_nm, i.input_type, i.unit_nm
      FROM tbl_tml_ccp_mtl_ver_item i
     WHERE i.co_cd = p_co_cd AND i.tmpl_cd = p_tmpl_cd AND i.ver_no = p_ver_no
     ORDER BY i.sort_no, i.item_cd;
END$$;

DROP FUNCTION IF EXISTS sp_tbl_tml_ccp_mtl_ver_copy_c_000(varchar, varchar, int, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_tml_ccp_mtl_ver_copy_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_tmpl_cd: 호환. 시드는 tml_ccp_mtl_000 고정
    p_tmpl_cd varchar,
    -- p_src_ver_no: 호환. 행추가는 표준만
    p_src_ver_no int,
    -- p_ver_cd: 호환. 번호는 SP가 채번
    p_ver_cd varchar,
    -- p_ver_nm: 양식명 필수
    p_ver_nm varchar,
    -- p_id: 로그인 사용자
    p_id varchar
)
RETURNS varchar LANGUAGE plpgsql AS $$
DECLARE v_nm varchar; v_n int; v_cd varchar; v_try int := 0;
BEGIN
    IF COALESCE(p_co_cd, '') = '' THEN
        RAISE EXCEPTION '회사코드는 필수입니다.' USING ERRCODE = '45000';
    END IF;
    v_nm := btrim(COALESCE(p_ver_nm, ''));
    IF v_nm = '' THEN RAISE EXCEPTION '양식명은 필수입니다.' USING ERRCODE = '45000'; END IF;
    SELECT COALESCE(MAX(substring(t.tmpl_cd from '[0-9]{3}$')::int), 0) INTO v_n
      FROM tbl_template t
     WHERE t.tmpl_cd ~ '^tml_ccp_mtl_[0-9]{3}$' AND t.tmpl_cd <> 'tml_ccp_mtl_000';
    LOOP
        v_try := v_try + 1; v_n := v_n + 1;
        IF v_n > 999 OR v_try > 50 THEN
            RAISE EXCEPTION '양식코드를 더 부여할 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        v_cd := 'tml_ccp_mtl_' || lpad(v_n::text, 3, '0');
        IF v_cd = 'tml_ccp_mtl_000' THEN CONTINUE; END IF;
        EXIT WHEN NOT EXISTS (SELECT 1 FROM tbl_template WHERE tmpl_cd = v_cd);
    END LOOP;
    -- 카탈로그 html_sys 없이 usr 행. 작성 화면 scrn_cd 는 후속
    INSERT INTO tbl_template (
        co_cd, tmpl_cd, tmpl_nm, mng_no, doc_kind, category_cd, scrn_cd,
        default_cycle_cd, default_retention_month, impl_yn, sort_no, use_yn, ins_id, ins_dt
    ) VALUES (
        p_co_cd, v_cd, v_nm, 'CCP-3P', 'html', 'CCP', 'ccp-mtl-monitor',
        'D', 24, 'Y', 115 + v_n, 'Y', p_id, now()
    );
    INSERT INTO tbl_company_template (
        co_cd, tmpl_cd, tmpl_nm_ovr, cycle_cd, retention_month, use_yn, sys_yn, ins_id, ins_dt
    ) VALUES (
        p_co_cd, v_cd, v_nm, 'D', 24, 'Y', 'usr', p_id, now()
    );
    INSERT INTO tbl_tml_ccp_mtl_ver (co_cd, tmpl_cd, ver_no, ver_cd, ver_nm, apply_yn, use_yn, ins_id, ins_dt)
    VALUES (p_co_cd, v_cd, 1, v_cd, v_nm, 'N', 'Y', p_id, now());
    INSERT INTO tbl_tml_ccp_mtl_ver_item (
        co_cd, tmpl_cd, ver_no, item_cd, sort_no, cycle_nm, grp_nm, item_nm, input_type, unit_nm, ins_id
    )
    SELECT p_co_cd, v_cd, 1, c.item_cd, c.sort_no, c.cycle_nm, c.grp_nm, c.item_nm, c.input_type, c.unit_nm, p_id
      FROM tbl_check_item c WHERE c.tmpl_cd = 'tml_ccp_mtl_000' AND c.use_yn = 'Y';
    INSERT INTO tbl_schedule_rule (co_cd, tmpl_cd, rule_seq, cycle_cd, nonwork_rule, due_time, use_yn, ins_id, ins_dt)
    VALUES (p_co_cd, v_cd, 1, 'D', 'keep', '1800', 'Y', p_id, now())
    ON CONFLICT (co_cd, tmpl_cd) DO NOTHING;
    RETURN v_cd;
END$$;

DROP PROCEDURE IF EXISTS sp_tbl_tml_ccp_mtl_ver_item_u_000(varchar, varchar, int, jsonb, varchar);
CREATE PROCEDURE sp_tbl_tml_ccp_mtl_ver_item_u_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_tmpl_cd: 자사 양식코드. 표준이면 거부
    p_tmpl_cd varchar,
    -- p_ver_no: 회사 순번. 0이면 표준
    p_ver_no int,
    -- p_items: 지면 항목 JSON 배열
    p_items jsonb,
    -- p_id: 로그인 사용자
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE e jsonb; v_cnt int := 0;
BEGIN
    IF COALESCE(p_tmpl_cd, '') = 'tml_ccp_mtl_000' OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 항목은 수정할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM tbl_tml_ccp_mtl_ver
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y'
    ) THEN
        RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' THEN
        RAISE EXCEPTION '점검항목 자료가 올바르지 않습니다.' USING ERRCODE = '45000';
    END IF;
    DELETE FROM tbl_tml_ccp_mtl_ver_item WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
    FOR e IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_cnt := v_cnt + 1;
        INSERT INTO tbl_tml_ccp_mtl_ver_item (
            co_cd, tmpl_cd, ver_no, item_cd, sort_no, cycle_nm, grp_nm, item_nm, input_type, unit_nm, ins_id, upd_id, upd_dt
        ) VALUES (
            p_co_cd, p_tmpl_cd, p_ver_no,
            COALESCE(NULLIF(e->>'itemCd', ''), 'hp-u-' || lpad(v_cnt::text, 3, '0')),
            COALESCE(NULLIF(e->>'sortNo', '')::int, v_cnt),
            NULLIF(e->>'cycleNm', ''), NULLIF(e->>'grpNm', ''), COALESCE(e->>'itemNm', ''),
            COALESCE(NULLIF(e->>'inputType', ''), 'text'), NULLIF(e->>'unitNm', ''),
            p_id, p_id, now()
        );
    END LOOP;
    UPDATE tbl_tml_ccp_mtl_ver SET upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
END$$;

DROP PROCEDURE IF EXISTS sp_tbl_tml_ccp_mtl_ver_nm_u_000(varchar, varchar, int, varchar, varchar);
CREATE PROCEDURE sp_tbl_tml_ccp_mtl_ver_nm_u_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_tmpl_cd: 자사 양식코드
    p_tmpl_cd varchar,
    -- p_ver_no: 회사 순번. 0이면 표준
    p_ver_no int,
    -- p_ver_nm: 바꿀 양식명
    p_ver_nm varchar,
    -- p_id: 로그인 사용자
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE v_nm varchar;
BEGIN
    IF COALESCE(p_tmpl_cd, '') = 'tml_ccp_mtl_000' OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 양식명은 수정할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    v_nm := btrim(COALESCE(p_ver_nm, ''));
    IF v_nm = '' THEN RAISE EXCEPTION '양식명은 필수입니다.' USING ERRCODE = '45000'; END IF;
    UPDATE tbl_tml_ccp_mtl_ver SET ver_nm = v_nm, upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
    IF NOT FOUND THEN RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    UPDATE tbl_template SET tmpl_nm = v_nm, upd_id = p_id, upd_dt = now() WHERE tmpl_cd = p_tmpl_cd AND co_cd = p_co_cd;
    UPDATE tbl_company_template SET tmpl_nm_ovr = v_nm, upd_id = p_id, upd_dt = now() WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
END$$;

DROP FUNCTION IF EXISTS sp_tbl_tml_ccp_mtl_ver_delete_blocker_r_000(varchar, varchar, int);
CREATE FUNCTION sp_tbl_tml_ccp_mtl_ver_delete_blocker_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_tmpl_cd: 삭제 대상 양식코드
    p_tmpl_cd varchar,
    -- p_ver_no: 회사 순번. 0이면 표준
    p_ver_no int
)
RETURNS TABLE(ref_key varchar, target varchar) LANGUAGE plpgsql STABLE AS $$
DECLARE v_nm varchar; v_use varchar; v_key varchar;
BEGIN
    v_key := COALESCE(NULLIF(btrim(p_tmpl_cd), ''), COALESCE(p_ver_no::varchar, ''));
    IF COALESCE(p_tmpl_cd, '') = 'tml_ccp_mtl_000' OR COALESCE(p_ver_no, 0) <= 0 THEN
        RETURN QUERY SELECT '표준'::varchar, '시스템 표준 항목'::varchar; RETURN;
    END IF;
    SELECT ver_nm, use_yn INTO v_nm, v_use FROM tbl_tml_ccp_mtl_ver
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no;
    IF v_nm IS NULL OR v_use = 'N' THEN
        RETURN QUERY SELECT v_key, '없는 양식'::varchar; RETURN;
    END IF;
    IF EXISTS (SELECT 1 FROM tbl_document d WHERE d.co_cd = p_co_cd AND d.tmpl_cd = p_tmpl_cd AND d.del_yn = 'N') THEN
        RETURN QUERY SELECT COALESCE(v_nm, v_key), '작성 문서'::varchar; RETURN;
    END IF;
    IF EXISTS (SELECT 1 FROM tbl_schedule_task t WHERE t.co_cd = p_co_cd AND t.tmpl_cd = p_tmpl_cd) THEN
        RETURN QUERY SELECT COALESCE(v_nm, v_key), '오늘 할 일'::varchar;
    END IF;
END$$;

DROP PROCEDURE IF EXISTS sp_tbl_tml_ccp_mtl_ver_d_000(varchar, varchar, int, varchar);
CREATE PROCEDURE sp_tbl_tml_ccp_mtl_ver_d_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_tmpl_cd: 자사 양식코드
    p_tmpl_cd varchar,
    -- p_ver_no: 회사 순번
    p_ver_no int,
    -- p_id: 로그인 사용자
    p_id varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    IF COALESCE(p_tmpl_cd, '') = 'tml_ccp_mtl_000' OR COALESCE(p_ver_no, 0) <= 0 THEN
        RAISE EXCEPTION '표준 양식은 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM tbl_tml_ccp_mtl_ver
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y'
    ) THEN
        RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    DELETE FROM tbl_schedule_rule_detail WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    DELETE FROM tbl_schedule_rule WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    DELETE FROM tbl_company_template WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd;
    UPDATE tbl_tml_ccp_mtl_ver SET use_yn = 'N', apply_yn = 'N', upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
END$$;

DROP PROCEDURE IF EXISTS sp_tbl_tml_ccp_mtl_ver_apply_u_000(varchar, varchar, int, varchar);
CREATE PROCEDURE sp_tbl_tml_ccp_mtl_ver_apply_u_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_tmpl_cd: 자사 양식코드
    p_tmpl_cd varchar,
    -- p_ver_no: 적용 순번. 0이면 해제만
    p_ver_no int,
    -- p_id: 로그인 사용자
    p_id varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE tbl_tml_ccp_mtl_ver SET apply_yn = 'N', upd_id = p_id, upd_dt = now()
     WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND apply_yn = 'Y';
    IF COALESCE(p_ver_no, 0) > 0 THEN
        UPDATE tbl_tml_ccp_mtl_ver SET apply_yn = 'Y', upd_id = p_id, upd_dt = now()
         WHERE co_cd = p_co_cd AND tmpl_cd = p_tmpl_cd AND ver_no = p_ver_no AND use_yn = 'Y';
        IF NOT FOUND THEN RAISE EXCEPTION '양식을 찾을 수 없습니다.' USING ERRCODE = '45000'; END IF;
    END IF;
END$$;

-- ------------------------------------------------------------
-- 5. 문서주기 — tml_ccp_mtl_001+ 포함. 예시 000 숨김
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_schedule_cycle_management_form_r_000(
    p_co_cd varchar, p_tmpl_cd varchar, p_tmpl_nm varchar, p_use_yn varchar
)
RETURNS TABLE(
    tmpl_cd varchar, tmpl_nm varchar, sys_yn varchar, doc_kind varchar, cycle_cd varchar, rule_yn varchar, use_yn varchar
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
            ct.tmpl_cd ~ '^html_sys_0(0[2-57-9]|10|12)$'
         OR (ct.tmpl_cd ~ '^html_hyg_prc_[0-9]{3}$' AND ct.tmpl_cd <> 'html_hyg_prc_000')
         OR (ct.tmpl_cd ~ '^tml_ccp_chk_[0-9]{3}$' AND ct.tmpl_cd <> 'tml_ccp_chk_000')
         OR (ct.tmpl_cd ~ '^tml_ccp_pkg_[0-9]{3}$' AND ct.tmpl_cd <> 'tml_ccp_pkg_000')
         OR (ct.tmpl_cd ~ '^tml_ccp_htg_[0-9]{3}$' AND ct.tmpl_cd <> 'tml_ccp_htg_000')
         OR (ct.tmpl_cd ~ '^tml_ccp_mtl_[0-9]{3}$' AND ct.tmpl_cd <> 'tml_ccp_mtl_000')
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
COMMENT ON FUNCTION sp_schedule_cycle_management_form_r_000(varchar, varchar, varchar, varchar) IS
  '문서주기관리 좌측 — html_hyg_prc_001+ · tml_ccp_chk_001+ · tml_ccp_pkg_001+ · tml_ccp_htg_001+ · tml_ccp_mtl_001+ · html_sys_002~005·007~010·012 · hwp. 예시 000 숨김';
