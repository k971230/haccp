-- ============================================================
-- 역할 — 스마트 HACCP 기준일지·자사 양식·공통 CCP 모니터링 확장
--
-- 개발자: 박승우
-- 일자: 2026-08-06
-- 코멘트:
--   1) 플랫폼 기본 양식은 읽기 전용으로 두고 업체별 복제 양식만 독립 편집한다
--   2) 한국식품안전관리인증원 기준일지 유형은 플랫폼 마스터와 우리 양식 매핑으로 분리한다
--   3) 냉장·금속 특화 일지는 유지하며 기타 CCP 공정은 공통 헤더·행·셀로 기록한다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. tbl_smart_diary_type — 스마트 HACCP 기준일지 플랫폼 마스터
--    공공 API 원문을 정제해 보관하며 회사가 직접 수정하지 않는다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_smart_diary_type (
    idx                   bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    diary_no              varchar(20)  NOT NULL,
    diary_nm              varchar(200) NOT NULL,
    diary_type            varchar(20)  NOT NULL,
    limit_item_kind       varchar(30)  NULL,
    infra_use_yn          varchar(1)   NOT NULL DEFAULT 'N',
    question_use_yn       varchar(1)   NOT NULL DEFAULT 'N',
    archive_year_cnt      int          NOT NULL DEFAULT 0,
    critical_limit_cn     text         NULL,
    monitoring_cycle_cn   text         NULL,
    monitoring_method_cn  text         NULL,
    improvement_method_cn text         NULL,
    use_yn                varchar(1)   NOT NULL DEFAULT 'Y',
    sort_no               int          NOT NULL DEFAULT 0,
    ins_id                varchar(20)  NULL,
    ins_dt                timestamp    NOT NULL DEFAULT now(),
    upd_id                varchar(20)  NULL,
    upd_dt                timestamp    NULL,
    CONSTRAINT ux_tbl_smart_diary_type_no UNIQUE (diary_no)
);
COMMENT ON TABLE tbl_smart_diary_type IS '스마트 HACCP 기준일지 유형 — 공공 카탈로그 정제본. 플랫폼 소유, 업체 수정 불가';
COMMENT ON COLUMN tbl_smart_diary_type.diary_no IS '공공 기준일지 코드 — W/C/P/L/A 접두의 외부 업무키';
COMMENT ON COLUMN tbl_smart_diary_type.diary_type IS '기준일지 유형 — CCP_DOC, PRE_DOC, LAW_DOC, PRE_AUTO';
COMMENT ON COLUMN tbl_smart_diary_type.limit_item_kind IS '공공 한계항목 종류 — 공통 CCP 컬럼 프리셋 선택 기준';
COMMENT ON COLUMN tbl_smart_diary_type.infra_use_yn IS '설비연동 사용여부 — Y일 때(= 향후 자동 수집 대상)';
COMMENT ON COLUMN tbl_smart_diary_type.question_use_yn IS '점검항목 사용여부 — Y일 때(= 체크항목형 양식 후보)';

-- ------------------------------------------------------------
-- 2. tbl_smart_diary_map — 공공 기준일지와 내부 표준 양식 대응
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_smart_diary_map (
    idx          bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    diary_no     varchar(20) NOT NULL,
    tmpl_cd      varchar(30) NOT NULL,
    match_level  varchar(10) NOT NULL DEFAULT 'NONE',
    impl_status  varchar(20) NOT NULL DEFAULT 'CATALOG',
    preferred_yn varchar(1)  NOT NULL DEFAULT 'N',
    ins_id       varchar(20) NULL,
    ins_dt       timestamp   NOT NULL DEFAULT now(),
    upd_id       varchar(20) NULL,
    upd_dt       timestamp   NULL,
    CONSTRAINT ux_tbl_smart_diary_map UNIQUE (diary_no, tmpl_cd)
);
COMMENT ON TABLE tbl_smart_diary_map IS '스마트 HACCP 기준일지와 SassHaccp 표준 양식 매핑 — 공공 코드와 내부 코드 분리';
COMMENT ON COLUMN tbl_smart_diary_map.match_level IS '대응 수준 — FULL, PARTIAL, NONE';
COMMENT ON COLUMN tbl_smart_diary_map.impl_status IS '구현 상태 — DB_SCREEN, HWP, CATALOG, GENERIC_CCP';
COMMENT ON COLUMN tbl_smart_diary_map.preferred_yn IS '수기/설비 쌍의 대표여부 — 동일 공정 후보 중 기본 선택 행';

-- ------------------------------------------------------------
-- 3. 기본/자사 양식 선택 — 기본 Y, 자사 복제본 N
-- ------------------------------------------------------------
ALTER TABLE tbl_company_template
    ADD COLUMN IF NOT EXISTS base_use_yn varchar(1) NOT NULL DEFAULT 'Y';
ALTER TABLE tbl_company_template
    ADD COLUMN IF NOT EXISTS co_form_idx bigint NULL;
COMMENT ON COLUMN tbl_company_template.base_use_yn IS '기본 양식 사용여부 — Y일 때(= 플랫폼 기본), N일 때(= 활성 자사 양식) 사용';
COMMENT ON COLUMN tbl_company_template.co_form_idx IS '활성 자사 양식 idx — base_use_yn=N일 때 tbl_company_form.idx';

CREATE TABLE IF NOT EXISTS tbl_company_form (
    idx             bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd           varchar(10)  NOT NULL,
    src_tmpl_cd     varchar(30)  NOT NULL,
    form_nm         varchar(200) NOT NULL,
    doc_kind        varchar(10)  NOT NULL,
    scrn_cd         varchar(50)  NULL,
    form_path       varchar(300) NULL,
    ver_no          int          NOT NULL DEFAULT 1,
    form_title      text         NULL,
    limit_rmk       text         NULL,
    cycle_rmk       text         NULL,
    method_rmk      text         NULL,
    improvement_rmk text         NULL,
    use_yn          varchar(1)   NOT NULL DEFAULT 'Y',
    ins_id          varchar(20)  NULL,
    ins_dt          timestamp    NOT NULL DEFAULT now(),
    upd_id          varchar(20)  NULL,
    upd_dt          timestamp    NULL,
    CONSTRAINT ux_tbl_company_form_ver UNIQUE (co_cd, src_tmpl_cd, form_nm, ver_no)
);
COMMENT ON TABLE tbl_company_form IS '자사 양식 헤더 — 플랫폼 기본 양식을 복제한 독립 편집본';
COMMENT ON COLUMN tbl_company_form.src_tmpl_cd IS '복제 원본 기본 양식 코드 — tbl_template.tmpl_cd';
COMMENT ON COLUMN tbl_company_form.form_title IS '자사 문서 제목 스냅샷 — 기본 양식 사용 안 함일 때 DocPaper 제목';
COMMENT ON COLUMN tbl_company_form.improvement_rmk IS '자사 개선조치 기본 문구 — 문서 푸터 입력 힌트';

CREATE TABLE IF NOT EXISTS tbl_company_form_item (
    idx         bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_form_idx bigint       NOT NULL,
    item_cd     varchar(30)  NOT NULL,
    grp_cd      varchar(30)  NULL,
    grp_nm      varchar(100) NULL,
    item_nm     varchar(500) NOT NULL,
    input_type  varchar(20)  NOT NULL DEFAULT 'OX',
    unit_nm     varchar(20)  NULL,
    method_nm   varchar(200) NULL,
    cycle_nm    varchar(100) NULL,
    sort_no     int          NOT NULL DEFAULT 0,
    use_yn      varchar(1)   NOT NULL DEFAULT 'Y',
    ins_id      varchar(20)  NULL,
    ins_dt      timestamp    NOT NULL DEFAULT now(),
    upd_id      varchar(20)  NULL,
    upd_dt      timestamp    NULL,
    CONSTRAINT ux_tbl_company_form_item UNIQUE (co_form_idx, item_cd)
);
COMMENT ON TABLE tbl_company_form_item IS '자사 양식 점검항목 — 기본 항목 복제 후 업체가 추가·삭제·문구수정 가능';
COMMENT ON COLUMN tbl_company_form_item.co_form_idx IS '자사 양식 헤더 대리키 — tbl_company_form.idx';

-- ------------------------------------------------------------
-- 4. 공통 CCP 모니터링 — 냉장·금속 외 다양한 공정을 한 구조로 수용
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_ccp_generic_monitor (
    idx             bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd           varchar(10)  NOT NULL,
    doc_idx         bigint       NOT NULL,
    base_dt         varchar(8)   NOT NULL,
    tmpl_cd         varchar(30)  NOT NULL,
    ccp_cd          varchar(30)  NULL,
    diary_no        varchar(20)  NULL,
    limit_item_kind varchar(30)  NULL,
    mng_user_id     varchar(20)  NULL,
    mng_nm          varchar(50)  NULL,
    form_src        varchar(10)  NOT NULL DEFAULT 'BASE',
    co_form_idx     bigint       NULL,
    ins_id          varchar(20)  NULL,
    ins_dt          timestamp    NOT NULL DEFAULT now(),
    upd_id          varchar(20)  NULL,
    upd_dt          timestamp    NULL,
    CONSTRAINT ux_tbl_ccp_generic_monitor_doc UNIQUE (doc_idx)
);
COMMENT ON TABLE tbl_ccp_generic_monitor IS '공통 CCP 모니터링 헤더 — 가열·세척·소독 등 비특화 공정 기록';
COMMENT ON COLUMN tbl_ccp_generic_monitor.form_src IS '작성 양식 출처 — BASE 또는 CUSTOM. 과거 양식 이력 보존';

CREATE TABLE IF NOT EXISTS tbl_ccp_generic_monitor_row (
    idx          bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd        varchar(10) NOT NULL,
    monitor_idx  bigint      NOT NULL,
    row_seq      int         NOT NULL,
    check_time   varchar(10) NULL,
    judge_cd     varchar(1)  NULL,
    judge_mod_yn varchar(1)  NOT NULL DEFAULT 'N',
    checker_id   varchar(20) NULL,
    checker_nm   varchar(50) NULL,
    ins_id       varchar(20) NULL,
    ins_dt       timestamp   NOT NULL DEFAULT now(),
    upd_id       varchar(20) NULL,
    upd_dt       timestamp   NULL,
    CONSTRAINT ux_tbl_ccp_generic_monitor_row UNIQUE (monitor_idx, row_seq)
);
COMMENT ON TABLE tbl_ccp_generic_monitor_row IS '공통 CCP 점검 행 — 시간별 측정·판정·점검자';

CREATE TABLE IF NOT EXISTS tbl_ccp_generic_monitor_cell (
    idx       bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd     varchar(10)  NOT NULL,
    row_idx   bigint       NOT NULL,
    item_cd   varchar(30)  NOT NULL,
    num_val   numeric(14,3) NULL,
    txt_val   varchar(500) NULL,
    judge_cd  varchar(1)   NULL,
    ins_id    varchar(20)  NULL,
    ins_dt    timestamp    NOT NULL DEFAULT now(),
    upd_id    varchar(20)  NULL,
    upd_dt    timestamp    NULL,
    CONSTRAINT ux_tbl_ccp_generic_monitor_cell UNIQUE (row_idx, item_cd)
);
COMMENT ON TABLE tbl_ccp_generic_monitor_cell IS '공통 CCP 측정 셀 — 수치 또는 텍스트 값과 항목별 판정';
COMMENT ON COLUMN tbl_ccp_generic_monitor_cell.item_cd IS '한계항목 코드 — limit_item_kind 프리셋의 열 식별자';

-- ------------------------------------------------------------
-- 5. 문서 작성 시점 양식 출처 — 기존 문서는 BASE로 해석
-- ------------------------------------------------------------
ALTER TABLE tbl_document
    ADD COLUMN IF NOT EXISTS form_src varchar(10) NOT NULL DEFAULT 'BASE';
ALTER TABLE tbl_document
    ADD COLUMN IF NOT EXISTS co_form_idx bigint NULL;
COMMENT ON COLUMN tbl_document.form_src IS '작성 시점 양식 출처 — BASE 기본양식, CUSTOM 자사양식';
COMMENT ON COLUMN tbl_document.co_form_idx IS '작성 시점 자사 양식 idx — CUSTOM일 때만 값 보관';

-- ------------------------------------------------------------
-- 6. 기준일지 조회 SP — 플랫폼 마스터는 읽기 전용
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_smart_diary_type_r_000(
    -- p_diary_type: CCP_DOC/PRE_DOC/LAW_DOC/PRE_AUTO. 공백이면 전체
    p_diary_type varchar,
    -- p_use_yn: 사용여부. 공백이면 전체
    p_use_yn varchar
) RETURNS TABLE(
    diary_no varchar, diary_nm varchar, diary_type varchar, limit_item_kind varchar,
    infra_use_yn varchar, question_use_yn varchar, archive_year_cnt int,
    critical_limit_cn text, monitoring_cycle_cn text, monitoring_method_cn text,
    improvement_method_cn text, use_yn varchar, sort_no int
)
LANGUAGE sql STABLE AS $$
    SELECT d.diary_no, d.diary_nm, d.diary_type, d.limit_item_kind,
           d.infra_use_yn, d.question_use_yn, d.archive_year_cnt,
           d.critical_limit_cn, d.monitoring_cycle_cn, d.monitoring_method_cn,
           d.improvement_method_cn, d.use_yn, d.sort_no
      FROM tbl_smart_diary_type d
     WHERE d.diary_type LIKE concat('%', coalesce(nullif(p_diary_type, ''), ''), '%')
       AND d.use_yn LIKE concat('%', coalesce(nullif(p_use_yn, ''), ''), '%')
     ORDER BY d.sort_no, d.diary_no;
$$;
COMMENT ON FUNCTION sp_tbl_smart_diary_type_r_000(varchar, varchar) IS '스마트 HACCP 기준일지 유형 조회 — 관리 화면의 플랫폼 읽기 전용 목록';

CREATE OR REPLACE FUNCTION sp_tbl_smart_diary_map_r_000(
    -- p_diary_no: 공공 코드. 공백이면 전체
    p_diary_no varchar,
    -- p_tmpl_cd: 내부 양식 코드. 공백이면 전체
    p_tmpl_cd varchar
) RETURNS TABLE(
    diary_no varchar, tmpl_cd varchar, match_level varchar, impl_status varchar, preferred_yn varchar
)
LANGUAGE sql STABLE AS $$
    SELECT m.diary_no, m.tmpl_cd, m.match_level, m.impl_status, m.preferred_yn
      FROM tbl_smart_diary_map m
     WHERE m.diary_no LIKE concat('%', coalesce(nullif(p_diary_no, ''), ''), '%')
       AND m.tmpl_cd LIKE concat('%', coalesce(nullif(p_tmpl_cd, ''), ''), '%')
     ORDER BY m.diary_no, m.preferred_yn DESC, m.tmpl_cd;
$$;
COMMENT ON FUNCTION sp_tbl_smart_diary_map_r_000(varchar, varchar) IS '스마트 HACCP 기준일지와 내부 표준 양식 매핑 조회';

-- ------------------------------------------------------------
-- 6-1. 점검항목 작성 로더 재정의 — 기본은 플랫폼 원문, 자사는 복제본
--      기존 업체 오버라이드(tbl_company_check_item)는 기본 양식 불변 정책에 따라 작성 화면에 쓰지 않는다
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_check_item_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_tmpl_cd: 내부 표준 양식 코드
    p_tmpl_cd varchar,
    -- p_grp_cd: 항목 그룹 필터. 공백이면 전체
    p_grp_cd varchar
) RETURNS TABLE(
    item_cd varchar, grp_cd varchar, grp_nm varchar, item_nm varchar, input_type varchar,
    unit_nm varchar, method_nm varchar, cycle_nm varchar, sort_no int
)
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_co_form_idx bigint;
BEGIN
    SELECT ct.co_form_idx INTO v_co_form_idx
      FROM tbl_company_template ct
     WHERE ct.co_cd = p_co_cd AND ct.tmpl_cd = p_tmpl_cd AND ct.base_use_yn = 'N';

    IF v_co_form_idx IS NOT NULL THEN
        RETURN QUERY
        SELECT i.item_cd, i.grp_cd, i.grp_nm, i.item_nm, i.input_type,
               i.unit_nm, i.method_nm, i.cycle_nm, i.sort_no
          FROM tbl_company_form_item i
          JOIN tbl_company_form f ON f.idx = i.co_form_idx AND f.co_cd = p_co_cd AND f.use_yn = 'Y'
         WHERE i.co_form_idx = v_co_form_idx
           AND i.use_yn = 'Y'
           AND coalesce(i.grp_cd, '') LIKE concat('%', coalesce(p_grp_cd, ''), '%')
         ORDER BY i.sort_no, i.item_cd;
    ELSE
        RETURN QUERY
        SELECT i.item_cd, i.grp_cd, i.grp_nm, i.item_nm, i.input_type,
               i.unit_nm, i.method_nm, i.cycle_nm, i.sort_no
          FROM tbl_check_item i
         WHERE i.tmpl_cd = p_tmpl_cd
           AND i.use_yn = 'Y'
           AND coalesce(i.grp_cd, '') LIKE concat('%', coalesce(p_grp_cd, ''), '%')
         ORDER BY i.sort_no, i.item_cd;
    END IF;
END;
$$;
COMMENT ON FUNCTION sp_tbl_check_item_r_000(varchar, varchar, varchar) IS '점검항목 작성 조회 — 기본 양식은 플랫폼 원문, 기본 미사용이면 활성 자사 복제본';

-- 업체 사용양식 목록 확장 — 기본/자사 선택 상태를 관리 UI·작성 로더에 제공한다
-- 반환 열을 base_use_yn·co_form_idx로 확장하므로 기존 OUT row type을 먼저 제거한다
DROP FUNCTION IF EXISTS sp_tbl_company_template_r_000(varchar, varchar, varchar);
CREATE OR REPLACE FUNCTION sp_tbl_company_template_r_000(
    p_co_cd varchar,
    p_category_cd varchar,
    p_use_yn varchar
) RETURNS TABLE(
    idx bigint, tmpl_cd varchar, tmpl_nm varchar, mng_no varchar, doc_kind varchar, category_cd varchar,
    scrn_cd varchar, cycle_cd varchar, retention_month int, appr_line_cd varchar, appr_line_nm varchar,
    use_yn varchar, sort_no int, base_use_yn varchar, co_form_idx bigint
)
LANGUAGE sql STABLE AS $$
    SELECT ct.idx, t.tmpl_cd, coalesce(ct.tmpl_nm_ovr, t.tmpl_nm),
           t.mng_no, t.doc_kind, t.category_cd, t.scrn_cd,
           coalesce(ct.cycle_cd, t.default_cycle_cd), coalesce(ct.retention_month, t.default_retention_month),
           ct.appr_line_cd, al.appr_line_nm, coalesce(ct.use_yn, 'N'), t.sort_no,
           coalesce(ct.base_use_yn, 'Y'), ct.co_form_idx
      FROM tbl_template t
      LEFT JOIN tbl_company_template ct ON ct.co_cd = p_co_cd AND ct.tmpl_cd = t.tmpl_cd
      LEFT JOIN tbl_approval_line al ON al.co_cd = p_co_cd AND al.appr_line_cd = ct.appr_line_cd
     WHERE t.use_yn = 'Y' AND t.impl_yn = 'Y'
       AND t.category_cd LIKE concat('%', coalesce(p_category_cd, ''), '%')
       AND coalesce(ct.use_yn, 'N') LIKE concat('%', coalesce(p_use_yn, ''), '%')
     ORDER BY t.sort_no;
$$;
COMMENT ON FUNCTION sp_tbl_company_template_r_000(varchar, varchar, varchar) IS '업체 사용양식 조회 — 활성 기본/자사 양식 출처를 함께 반환';

-- ------------------------------------------------------------
-- 7. 자사 양식 복제·조회·활성화 SP
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_company_form_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_src_tmpl_cd: 원본 표준 양식 코드. 공백이면 전체
    p_src_tmpl_cd varchar
) RETURNS TABLE(
    idx bigint, src_tmpl_cd varchar, form_nm varchar, doc_kind varchar, scrn_cd varchar,
    form_path varchar, ver_no int, form_title text, limit_rmk text, cycle_rmk text,
    method_rmk text, improvement_rmk text, use_yn varchar, active_yn varchar
)
LANGUAGE sql STABLE AS $$
    SELECT f.idx, f.src_tmpl_cd, f.form_nm, f.doc_kind, f.scrn_cd,
           f.form_path, f.ver_no, f.form_title, f.limit_rmk, f.cycle_rmk,
           f.method_rmk, f.improvement_rmk, f.use_yn,
           CASE WHEN ct.base_use_yn = 'N' AND ct.co_form_idx = f.idx THEN 'Y' ELSE 'N' END
      FROM tbl_company_form f
      LEFT JOIN tbl_company_template ct
        ON ct.co_cd = f.co_cd AND ct.tmpl_cd = f.src_tmpl_cd
     WHERE f.co_cd = p_co_cd
       AND f.src_tmpl_cd LIKE concat('%', coalesce(nullif(p_src_tmpl_cd, ''), ''), '%')
     ORDER BY f.src_tmpl_cd, f.use_yn DESC, f.ver_no DESC, f.idx DESC;
$$;
COMMENT ON FUNCTION sp_tbl_company_form_r_000(varchar, varchar) IS '자사 양식 목록 — 선택 표준양식에서 파생된 복제본과 작성 활성 여부';

CREATE OR REPLACE FUNCTION sp_tbl_company_form_item_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_co_form_idx: 자사 양식 idx
    p_co_form_idx bigint
) RETURNS TABLE(
    idx bigint, co_form_idx bigint, item_cd varchar, grp_cd varchar, grp_nm varchar,
    item_nm varchar, input_type varchar, unit_nm varchar, method_nm varchar, cycle_nm varchar,
    sort_no int, use_yn varchar
)
LANGUAGE sql STABLE AS $$
    SELECT i.idx, i.co_form_idx, i.item_cd, i.grp_cd, i.grp_nm,
           i.item_nm, i.input_type, i.unit_nm, i.method_nm, i.cycle_nm,
           i.sort_no, i.use_yn
      FROM tbl_company_form_item i
      JOIN tbl_company_form f ON f.idx = i.co_form_idx AND f.co_cd = p_co_cd
     WHERE i.co_form_idx = p_co_form_idx
     ORDER BY i.sort_no, i.item_cd;
$$;
COMMENT ON FUNCTION sp_tbl_company_form_item_r_000(varchar, bigint) IS '자사 양식 점검항목 조회 — 표준 오버라이드가 아닌 독립 복제본';

CREATE OR REPLACE PROCEDURE sp_tbl_company_form_clone_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_src_tmpl_cd: 복제할 플랫폼 표준 양식 코드
    p_src_tmpl_cd varchar,
    -- p_form_nm: 자사 양식명. 공백이면 표준명 + 자사 양식
    p_form_nm varchar,
    -- p_id: JWT 작업자 ID
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_template tbl_template%ROWTYPE;
    v_form_idx bigint;
    v_ver_no int;
    v_form_nm varchar(200);
BEGIN
    SELECT * INTO v_template FROM tbl_template WHERE tmpl_cd = p_src_tmpl_cd AND use_yn = 'Y';
    IF NOT FOUND THEN
        RAISE EXCEPTION '복제할 기본 양식을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    SELECT coalesce(max(ver_no), 0) + 1 INTO v_ver_no
      FROM tbl_company_form WHERE co_cd = p_co_cd AND src_tmpl_cd = p_src_tmpl_cd;
    v_form_nm := coalesce(nullif(trim(p_form_nm), ''), v_template.tmpl_nm || ' 자사 양식');

    INSERT INTO tbl_company_form (
        co_cd, src_tmpl_cd, form_nm, doc_kind, scrn_cd, form_path, ver_no, use_yn, ins_id
    ) VALUES (
        p_co_cd, p_src_tmpl_cd, v_form_nm, v_template.doc_kind, v_template.scrn_cd,
        v_template.form_path, v_ver_no, 'Y', p_id
    ) RETURNING idx INTO v_form_idx;

    INSERT INTO tbl_company_form_item (
        co_form_idx, item_cd, grp_cd, grp_nm, item_nm, input_type, unit_nm, method_nm, cycle_nm,
        sort_no, use_yn, ins_id
    )
    SELECT v_form_idx, i.item_cd, i.grp_cd, i.grp_nm, i.item_nm, i.input_type, i.unit_nm,
           i.method_nm, i.cycle_nm, i.sort_no, i.use_yn, p_id
      FROM tbl_check_item i
     WHERE i.tmpl_cd = p_src_tmpl_cd
     ORDER BY i.sort_no, i.item_cd;
END;
$$;
COMMENT ON PROCEDURE sp_tbl_company_form_clone_c_000(varchar, varchar, varchar, varchar) IS '기본 양식→자사 양식 복제 — 자사 양식 추가 버튼 전용';

CREATE OR REPLACE PROCEDURE sp_tbl_company_form_item_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_co_form_idx: 자사 양식 idx
    p_co_form_idx bigint,
    -- p_payload: 항목 행 JSON. idx가 없으면 신규, 있으면 해당 자사 양식 행 수정
    p_payload jsonb,
    -- p_id: JWT 작업자 ID
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_idx bigint := nullif(p_payload->>'idx', '')::bigint;
    v_item_cd varchar := nullif(trim(p_payload->>'itemCd'), '');
BEGIN
    IF NOT EXISTS (SELECT 1 FROM tbl_company_form WHERE idx = p_co_form_idx AND co_cd = p_co_cd) THEN
        RAISE EXCEPTION '자사 양식 정보를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF coalesce(v_item_cd, '') = '' THEN
        RAISE EXCEPTION '점검항목 코드를 입력하세요.' USING ERRCODE = '45000';
    END IF;

    IF v_idx IS NULL THEN
        INSERT INTO tbl_company_form_item (
            co_form_idx, item_cd, grp_cd, grp_nm, item_nm, input_type, unit_nm, method_nm, cycle_nm,
            sort_no, use_yn, ins_id
        ) VALUES (
            p_co_form_idx, v_item_cd, nullif(p_payload->>'grpCd', ''), nullif(p_payload->>'grpNm', ''),
            coalesce(nullif(p_payload->>'itemNm', ''), v_item_cd), coalesce(nullif(p_payload->>'inputType', ''), 'OX'),
            nullif(p_payload->>'unitNm', ''), nullif(p_payload->>'methodNm', ''), nullif(p_payload->>'cycleNm', ''),
            coalesce(nullif(p_payload->>'sortNo', '')::int, 0), coalesce(nullif(p_payload->>'useYn', ''), 'Y'), p_id
        );
    ELSE
        UPDATE tbl_company_form_item
           SET item_cd = v_item_cd, grp_cd = nullif(p_payload->>'grpCd', ''), grp_nm = nullif(p_payload->>'grpNm', ''),
               item_nm = coalesce(nullif(p_payload->>'itemNm', ''), v_item_cd),
               input_type = coalesce(nullif(p_payload->>'inputType', ''), 'OX'),
               unit_nm = nullif(p_payload->>'unitNm', ''), method_nm = nullif(p_payload->>'methodNm', ''),
               cycle_nm = nullif(p_payload->>'cycleNm', ''), sort_no = coalesce(nullif(p_payload->>'sortNo', '')::int, 0),
               use_yn = coalesce(nullif(p_payload->>'useYn', ''), 'Y'), upd_id = p_id, upd_dt = now()
         WHERE idx = v_idx AND co_form_idx = p_co_form_idx;
        IF NOT FOUND THEN
            RAISE EXCEPTION '수정할 자사 점검항목을 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
    END IF;
END;
$$;
COMMENT ON PROCEDURE sp_tbl_company_form_item_c_000(varchar, bigint, jsonb, varchar) IS '자사 양식 점검항목 저장 — 기본 양식 행은 수정하지 않는다';

CREATE OR REPLACE PROCEDURE sp_tbl_company_form_activate_u_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_src_tmpl_cd: 원본 표준 양식 코드
    p_src_tmpl_cd varchar,
    -- p_co_form_idx: 활성 자사 양식 idx. NULL이면 기본 양식 사용
    p_co_form_idx bigint,
    -- p_id: JWT 작업자 ID
    p_id varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    IF p_co_form_idx IS NOT NULL
       AND NOT EXISTS (
           SELECT 1 FROM tbl_company_form
            WHERE idx = p_co_form_idx AND co_cd = p_co_cd AND src_tmpl_cd = p_src_tmpl_cd AND use_yn = 'Y'
       ) THEN
        RAISE EXCEPTION '작성에 사용할 자사 양식을 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;

    INSERT INTO tbl_company_template (co_cd, tmpl_cd, base_use_yn, co_form_idx, use_yn, ins_id)
    VALUES (p_co_cd, p_src_tmpl_cd, CASE WHEN p_co_form_idx IS NULL THEN 'Y' ELSE 'N' END, p_co_form_idx, 'Y', p_id)
    ON CONFLICT (co_cd, tmpl_cd) DO UPDATE
       SET base_use_yn = EXCLUDED.base_use_yn, co_form_idx = EXCLUDED.co_form_idx, upd_id = p_id, upd_dt = now();
END;
$$;
COMMENT ON PROCEDURE sp_tbl_company_form_activate_u_000(varchar, varchar, bigint, varchar) IS '작성 양식 전환 — NULL이면 기본, 자사 idx이면 해당 복제본';

-- ------------------------------------------------------------
-- 8. 공통 CCP 저장 — 행과 EAV 셀을 한 문서 트랜잭션으로 교체
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_ccp_generic_monitor_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd varchar,
    -- p_doc_idx: 기존 문서 idx. null/0이면 신규 문서
    p_doc_idx bigint,
    -- p_base_dt: 기준일 YYYYMMDD
    p_base_dt varchar,
    -- p_tmpl_cd: 내부 공통 CCP 템플릿 코드
    p_tmpl_cd varchar,
    -- p_ccp_cd: 회사 CCP 코드. 미지정이면 공백
    p_ccp_cd varchar,
    -- p_diary_no: 스마트 HACCP 기준일지 코드
    p_diary_no varchar,
    -- p_limit_item_kind: 컬럼 프리셋 코드
    p_limit_item_kind varchar,
    -- p_mng_user_id: 담당자 ID
    p_mng_user_id varchar,
    -- p_mng_nm: 담당자명
    p_mng_nm varchar,
    -- p_rows: [{rowSeq,checkTime,judgeCd,checkerId,checkerNm,cells:[{itemCd,numVal,txtVal,judgeCd}]}]
    p_rows jsonb,
    -- p_id: JWT 작업자 ID
    p_id varchar
) RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE
    v_doc_idx bigint;
    v_monitor_idx bigint;
    v_doc_no varchar;
    v_title varchar(300);
    v_row jsonb;
    v_cell jsonb;
    v_row_idx bigint;
BEGIN
    IF jsonb_typeof(p_rows) <> 'array' OR jsonb_array_length(p_rows) = 0 THEN
        RAISE EXCEPTION '점검 행이 없습니다.' USING ERRCODE = '45000';
    END IF;
    SELECT coalesce(nullif(t.tmpl_nm, ''), '공통 CCP 모니터링') INTO v_title
      FROM tbl_template t WHERE t.tmpl_cd = p_tmpl_cd AND t.doc_kind = 'html' AND t.use_yn = 'Y';
    IF v_title IS NULL THEN
        RAISE EXCEPTION '사용할 공통 CCP 양식이 등록되어 있지 않습니다.' USING ERRCODE = '45000';
    END IF;

    IF coalesce(p_doc_idx, 0) <= 0 THEN
        v_doc_no := sp_tbl_doc_no_gen_c_000(p_co_cd, p_tmpl_cd, p_base_dt);
        INSERT INTO tbl_document (
            co_cd, tmpl_cd, doc_kind, doc_no, base_dt, title, status, writer_id, form_src, ins_id
        ) VALUES (
            p_co_cd, p_tmpl_cd, 'DB', v_doc_no, p_base_dt, v_title, 'WRK', p_id, 'BASE', p_id
        ) RETURNING idx INTO v_doc_idx;
        INSERT INTO tbl_ccp_generic_monitor (
            co_cd, doc_idx, base_dt, tmpl_cd, ccp_cd, diary_no, limit_item_kind, mng_user_id, mng_nm, ins_id
        ) VALUES (
            p_co_cd, v_doc_idx, p_base_dt, p_tmpl_cd, nullif(p_ccp_cd, ''), nullif(p_diary_no, ''),
            nullif(p_limit_item_kind, ''), nullif(p_mng_user_id, ''), nullif(p_mng_nm, ''), p_id
        ) RETURNING idx INTO v_monitor_idx;
    ELSE
        SELECT m.idx INTO v_monitor_idx
          FROM tbl_ccp_generic_monitor m
          JOIN tbl_document d ON d.idx = m.doc_idx
         WHERE m.co_cd = p_co_cd AND m.doc_idx = p_doc_idx AND d.del_yn = 'N' AND d.status IN ('WRK', 'RJT');
        IF v_monitor_idx IS NULL THEN
            RAISE EXCEPTION '수정할 임시 또는 반려 문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
        END IF;
        v_doc_idx := p_doc_idx;
        UPDATE tbl_document SET base_dt = p_base_dt, title = v_title, upd_id = p_id, upd_dt = now()
         WHERE idx = v_doc_idx AND co_cd = p_co_cd;
        UPDATE tbl_ccp_generic_monitor
           SET base_dt = p_base_dt, tmpl_cd = p_tmpl_cd, ccp_cd = nullif(p_ccp_cd, ''),
               diary_no = nullif(p_diary_no, ''), limit_item_kind = nullif(p_limit_item_kind, ''),
               mng_user_id = nullif(p_mng_user_id, ''), mng_nm = nullif(p_mng_nm, ''), upd_id = p_id, upd_dt = now()
         WHERE idx = v_monitor_idx AND co_cd = p_co_cd;
        DELETE FROM tbl_ccp_generic_monitor_cell c
         USING tbl_ccp_generic_monitor_row r
         WHERE c.row_idx = r.idx AND r.monitor_idx = v_monitor_idx AND r.co_cd = p_co_cd;
        DELETE FROM tbl_ccp_generic_monitor_row WHERE monitor_idx = v_monitor_idx AND co_cd = p_co_cd;
    END IF;

    FOR v_row IN SELECT value FROM jsonb_array_elements(p_rows)
    LOOP
        INSERT INTO tbl_ccp_generic_monitor_row (
            co_cd, monitor_idx, row_seq, check_time, judge_cd, judge_mod_yn, checker_id, checker_nm, ins_id
        ) VALUES (
            p_co_cd, v_monitor_idx, coalesce(nullif(v_row->>'rowSeq', '')::int, 0), nullif(v_row->>'checkTime', ''),
            nullif(v_row->>'judgeCd', ''), coalesce(nullif(v_row->>'judgeModYn', ''), 'N'),
            nullif(v_row->>'checkerId', ''), nullif(v_row->>'checkerNm', ''), p_id
        ) RETURNING idx INTO v_row_idx;
        FOR v_cell IN SELECT value FROM jsonb_array_elements(coalesce(v_row->'cells', '[]'::jsonb))
        LOOP
            INSERT INTO tbl_ccp_generic_monitor_cell (
                co_cd, row_idx, item_cd, num_val, txt_val, judge_cd, ins_id
            ) VALUES (
                p_co_cd, v_row_idx, v_cell->>'itemCd', nullif(v_cell->>'numVal', '')::numeric,
                nullif(v_cell->>'txtVal', ''), nullif(v_cell->>'judgeCd', ''), p_id
            );
        END LOOP;
    END LOOP;
    RETURN v_doc_idx;
END;
$$;
COMMENT ON FUNCTION sp_tbl_ccp_generic_monitor_c_000(varchar, bigint, varchar, varchar, varchar, varchar, varchar, varchar, varchar, jsonb, varchar) IS '공통 CCP 모니터링 저장 — 문서·헤더·행·EAV 셀 일괄 저장';

-- ------------------------------------------------------------
-- 9. 공통 CCP 상세·삭제 — Wave 1 잔여
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_ccp_generic_monitor_r_000(
    p_co_cd varchar,
    p_doc_idx bigint
)
RETURNS TABLE (
    doc_idx bigint,
    doc_no varchar,
    status varchar,
    base_dt varchar,
    tmpl_cd varchar,
    ccp_cd varchar,
    diary_no varchar,
    limit_item_kind varchar,
    mng_user_id varchar,
    mng_nm varchar,
    rows_json jsonb
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT d.idx AS doc_idx,
           d.doc_no,
           d.status,
           m.base_dt,
           m.tmpl_cd,
           m.ccp_cd,
           m.diary_no,
           m.limit_item_kind,
           m.mng_user_id,
           m.mng_nm,
           COALESCE((
               SELECT jsonb_agg(
                          jsonb_build_object(
                              'rowSeq', r.row_seq,
                              'checkTime', COALESCE(r.check_time, ''),
                              'judgeCd', r.judge_cd,
                              'judgeModYn', r.judge_mod_yn,
                              'checkerId', COALESCE(r.checker_id, ''),
                              'checkerNm', COALESCE(r.checker_nm, ''),
                              'cells', COALESCE((
                                  SELECT jsonb_agg(
                                             jsonb_build_object(
                                                 'itemCd', c.item_cd,
                                                 'numVal', c.num_val,
                                                 'txtVal', COALESCE(c.txt_val, ''),
                                                 'judgeCd', c.judge_cd
                                             )
                                             ORDER BY c.item_cd
                                         )
                                    FROM tbl_ccp_generic_monitor_cell c
                                   WHERE c.row_idx = r.idx
                                     AND c.co_cd = r.co_cd
                              ), '[]'::jsonb)
                          )
                          ORDER BY r.row_seq
                      )
                 FROM tbl_ccp_generic_monitor_row r
                WHERE r.monitor_idx = m.idx
                  AND r.co_cd = m.co_cd
           ), '[]'::jsonb) AS rows_json
      FROM tbl_document d
      JOIN tbl_ccp_generic_monitor m
        ON m.doc_idx = d.idx
       AND m.co_cd = d.co_cd
     WHERE d.co_cd = p_co_cd
       AND d.idx = p_doc_idx
       AND d.del_yn = 'N';
END;
$$;
COMMENT ON FUNCTION sp_tbl_ccp_generic_monitor_r_000(varchar, bigint) IS '공통 CCP 모니터링 상세 — 헤더와 행·셀 JSON';

CREATE OR REPLACE PROCEDURE sp_tbl_ccp_generic_monitor_d_000(
    p_co_cd varchar,
    p_doc_idx bigint,
    p_id varchar
)
LANGUAGE plpgsql AS $$
DECLARE
    v_status varchar(4);
    v_monitor_idx bigint;
BEGIN
    IF p_doc_idx IS NULL OR p_doc_idx = 0 THEN
        RAISE EXCEPTION '삭제할 문서를 선택하세요.' USING ERRCODE = '45000';
    END IF;
    SELECT d.status, m.idx
      INTO v_status, v_monitor_idx
      FROM tbl_document d
      JOIN tbl_ccp_generic_monitor m ON m.doc_idx = d.idx AND m.co_cd = d.co_cd
     WHERE d.co_cd = p_co_cd
       AND d.idx = p_doc_idx
       AND d.del_yn = 'N';
    IF v_monitor_idx IS NULL THEN
        RAISE EXCEPTION '문서를 찾을 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    IF v_status NOT IN ('WRK', 'RJT') THEN
        RAISE EXCEPTION '결재 진행 중이거나 완료된 문서는 삭제할 수 없습니다.' USING ERRCODE = '45000';
    END IF;
    DELETE FROM tbl_corrective_action WHERE co_cd = p_co_cd AND src_doc_idx = p_doc_idx;
    DELETE FROM tbl_ccp_generic_monitor_cell c
     USING tbl_ccp_generic_monitor_row r
     WHERE c.row_idx = r.idx AND r.monitor_idx = v_monitor_idx AND r.co_cd = p_co_cd;
    DELETE FROM tbl_ccp_generic_monitor_row WHERE monitor_idx = v_monitor_idx AND co_cd = p_co_cd;
    DELETE FROM tbl_ccp_generic_monitor WHERE idx = v_monitor_idx AND co_cd = p_co_cd;
    DELETE FROM tbl_document_approval WHERE doc_idx = p_doc_idx AND co_cd = p_co_cd;
    DELETE FROM tbl_document_file WHERE doc_idx = p_doc_idx AND co_cd = p_co_cd;
    DELETE FROM tbl_document WHERE idx = p_doc_idx AND co_cd = p_co_cd;
END;
$$;
COMMENT ON PROCEDURE sp_tbl_ccp_generic_monitor_d_000(varchar, bigint, varchar) IS '공통 CCP 모니터링 삭제 — 임시·반려만';
