-- ============================================================
--  DDL 3 — 문서관리 허브 (18 테이블)
--
--  개발자: 박승우
--  일자: 2026-08-05
--  코멘트:
--    1) DB형 15종과 rhwp 문서형 16종이 tbl_document 한 곳으로 모이는 공통 관리정보 계층
--    2) 문서 본문 데이터의 DB화는 선택이지만 문서 관리정보(업체·종류·번호·작성자·결재·경로·보존)는 전 문서 필수
--    3) 자유 양식 빌더를 만들지 않는 대신 tbl_company_check_item으로 항목 표시·숨김·문구만 업체가 조정한다
--
--  전역 테이블(co_cd 없음): tbl_template, tbl_check_item — 플랫폼이 배포하는 표준 카탈로그
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. tbl_company_setting — 업체별 일반 설정 (key-value)
--    판정에 직접 쓰이지 않는 값만 담는다. 한계기준은 tbl_ccp_limit로 분리
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_company_setting (
    idx         bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd       varchar(10)  NOT NULL,
    setting_key varchar(50)  NOT NULL,
    setting_val varchar(500) NULL,
    desc_rmk    varchar(300) NULL,
    ins_id      varchar(20)  NULL,
    ins_dt      timestamp    NULL DEFAULT now(),
    upd_id      varchar(20)  NULL,
    upd_dt      timestamp    NULL,
    CONSTRAINT ux_tbl_company_setting UNIQUE (co_cd, setting_key)
);
COMMENT ON TABLE  tbl_company_setting             IS '업체별 일반 설정 — key-value. 화면 표시옵션·로그 보존월수 등';
COMMENT ON COLUMN tbl_company_setting.idx         IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_company_setting.co_cd       IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_company_setting.setting_key IS '설정 키 — VIEWLOG_RETENTION_MONTH, WORK_START_TIME 등';
COMMENT ON COLUMN tbl_company_setting.setting_val IS '설정 값 — 문자열로 보관하고 사용처에서 형변환';
COMMENT ON COLUMN tbl_company_setting.desc_rmk    IS '설명';
COMMENT ON COLUMN tbl_company_setting.ins_id      IS '최초입력자 ID';
COMMENT ON COLUMN tbl_company_setting.ins_dt      IS '최초입력일시';
COMMENT ON COLUMN tbl_company_setting.upd_id      IS '최종수정자 ID';
COMMENT ON COLUMN tbl_company_setting.upd_dt      IS '최종수정일시';

-- ------------------------------------------------------------
-- 2. tbl_ccp_limit — CCP 한계기준
--    자동판정의 유일한 기준값 원천. 저장 SP가 이 값을 읽어 적합/부적합을 확정한다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_ccp_limit (
    idx        bigint        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd      varchar(10)   NOT NULL,
    ccp_cd     varchar(20)   NOT NULL,
    ccp_nm     varchar(100)  NOT NULL,
    proc_nm    varchar(100)  NULL,
    limit_type varchar(20)   NOT NULL,
    min_val    numeric(10,2) NULL,
    max_val    numeric(10,2) NULL,
    unit_nm    varchar(20)   NULL,
    fe_size    numeric(4,1)  NULL,
    sts_size   numeric(4,1)  NULL,
    cycle_min  int           NULL,
    form_title text          NULL,
    cycle_rmk  text          NULL,
    limit_rmk  text          NULL,
    method_rmk text          NULL,
    use_yn     varchar(1)    NOT NULL DEFAULT 'Y',
    ins_id     varchar(20)   NULL,
    ins_dt     timestamp     NULL DEFAULT now(),
    upd_id     varchar(20)   NULL,
    upd_dt     timestamp     NULL,
    CONSTRAINT ux_tbl_ccp_limit UNIQUE (co_cd, ccp_cd)
);
COMMENT ON TABLE  tbl_ccp_limit            IS 'CCP 한계기준 — 업체별 판정 기준값. 저장 SP 자동판정의 유일한 원천';
COMMENT ON COLUMN tbl_ccp_limit.idx        IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_ccp_limit.co_cd      IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_ccp_limit.ccp_cd     IS 'CCP 코드 — CCP-1B(원료육 냉장), CCP-2P(금속검출), CCP-3B(완제품 냉장)';
COMMENT ON COLUMN tbl_ccp_limit.ccp_nm     IS 'CCP 명칭';
COMMENT ON COLUMN tbl_ccp_limit.proc_nm    IS '해당 공정명 — 검증점검표 공정 구분에 사용';
COMMENT ON COLUMN tbl_ccp_limit.limit_type IS '기준유형 — TEMP_RANGE(범위), TEMP_MAX(이하), TEMP_MIN(이상), METAL(금속검출)';
COMMENT ON COLUMN tbl_ccp_limit.min_val    IS '하한값 — TEMP_RANGE일 때(= 범위 판정) 필수. 냉장 -2';
COMMENT ON COLUMN tbl_ccp_limit.max_val    IS '상한값 — TEMP_RANGE/TEMP_MAX일 때 필수. 냉장 5, 냉동 -18';
COMMENT ON COLUMN tbl_ccp_limit.unit_nm    IS '단위 — 섭씨온도 등 화면 표기용';
COMMENT ON COLUMN tbl_ccp_limit.fe_size    IS 'Fe 시편 규격(mm) — METAL일 때만 사용';
COMMENT ON COLUMN tbl_ccp_limit.sts_size   IS 'STS 시편 규격(mm) — METAL일 때만 사용';
COMMENT ON COLUMN tbl_ccp_limit.cycle_min  IS '모니터링 주기(분) — 작업 중 2시간마다면 120';
COMMENT ON COLUMN tbl_ccp_limit.form_title IS '일지 상단 제목 — CCP 콤보 변경 시 DocPaper 제목에 표시';
COMMENT ON COLUMN tbl_ccp_limit.cycle_rmk  IS '주기 서술 문구 — A4 문서 상단 주기란에 그대로 출력';
COMMENT ON COLUMN tbl_ccp_limit.limit_rmk  IS '한계기준 서술 문구 — A4 문서 상단 한계기준란에 그대로 출력';
COMMENT ON COLUMN tbl_ccp_limit.method_rmk IS '모니터링 방법 서술 문구 — A4 문서 상단 방법란에 그대로 출력';
COMMENT ON COLUMN tbl_ccp_limit.use_yn     IS '사용여부 Y/N';
COMMENT ON COLUMN tbl_ccp_limit.ins_id     IS '최초입력자 ID';
COMMENT ON COLUMN tbl_ccp_limit.ins_dt     IS '최초입력일시';
COMMENT ON COLUMN tbl_ccp_limit.upd_id     IS '최종수정자 ID';
COMMENT ON COLUMN tbl_ccp_limit.upd_dt     IS '최종수정일시';

-- ------------------------------------------------------------
-- 3. tbl_approval_line — 결재선 헤더
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_approval_line (
    idx          bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd        varchar(10)  NOT NULL,
    appr_line_cd varchar(20)  NOT NULL,
    appr_line_nm varchar(100) NOT NULL,
    use_yn       varchar(1)   NOT NULL DEFAULT 'Y',
    ins_id       varchar(20)  NULL,
    ins_dt       timestamp    NULL DEFAULT now(),
    upd_id       varchar(20)  NULL,
    upd_dt       timestamp    NULL,
    CONSTRAINT ux_tbl_approval_line UNIQUE (co_cd, appr_line_cd)
);
COMMENT ON TABLE  tbl_approval_line              IS '결재선 헤더 — 업체별 결재 경로 정의. 템플릿별로 다른 결재선 지정 가능';
COMMENT ON COLUMN tbl_approval_line.idx          IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_approval_line.co_cd        IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_approval_line.appr_line_cd IS '결재선 코드 — 업체 내 유일';
COMMENT ON COLUMN tbl_approval_line.appr_line_nm IS '결재선명 — 일반 점검표 결재선 등';
COMMENT ON COLUMN tbl_approval_line.use_yn       IS '사용여부 Y/N';
COMMENT ON COLUMN tbl_approval_line.ins_id       IS '최초입력자 ID';
COMMENT ON COLUMN tbl_approval_line.ins_dt       IS '최초입력일시';
COMMENT ON COLUMN tbl_approval_line.upd_id       IS '최종수정자 ID';
COMMENT ON COLUMN tbl_approval_line.upd_dt       IS '최종수정일시';

-- ------------------------------------------------------------
-- 4. tbl_approval_line_step — 결재선 단계
--    표준기준서 결재란이 작성자 → 검토자 → 승인자 3단이므로 기본 3행
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_approval_line_step (
    idx          bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd        varchar(10) NOT NULL,
    appr_line_cd varchar(20) NOT NULL,
    step_no      int         NOT NULL,
    role_cd      varchar(20) NOT NULL,
    approver_id  varchar(20) NULL,
    dept_cd      varchar(20) NULL,
    pos_cd       varchar(20) NULL,
    ins_id       varchar(20) NULL,
    ins_dt       timestamp   NULL DEFAULT now(),
    upd_id       varchar(20) NULL,
    upd_dt       timestamp   NULL,
    CONSTRAINT ux_tbl_approval_line_step UNIQUE (co_cd, appr_line_cd, step_no)
);
COMMENT ON TABLE  tbl_approval_line_step              IS '결재선 단계 — 작성자·검토자·승인자 순번 정의';
COMMENT ON COLUMN tbl_approval_line_step.idx          IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_approval_line_step.co_cd        IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_approval_line_step.appr_line_cd IS '결재선 코드 — tbl_approval_line.appr_line_cd';
COMMENT ON COLUMN tbl_approval_line_step.step_no      IS '단계 순번 — 1부터. 낮은 번호부터 순차 결재';
COMMENT ON COLUMN tbl_approval_line_step.role_cd      IS '역할 — WRITE:작성자, REVIEW:검토자, APPROVE:승인자';
COMMENT ON COLUMN tbl_approval_line_step.approver_id  IS '결재자 로그인 ID — NULL이면(= 직위 기준 지정) dept_cd·pos_cd로 대상자를 찾는다';
COMMENT ON COLUMN tbl_approval_line_step.dept_cd      IS '결재 부서코드 — approver_id 미지정 시 사용';
COMMENT ON COLUMN tbl_approval_line_step.pos_cd       IS '결재 직위코드 — approver_id 미지정 시 사용';
COMMENT ON COLUMN tbl_approval_line_step.ins_id       IS '최초입력자 ID';
COMMENT ON COLUMN tbl_approval_line_step.ins_dt       IS '최초입력일시';
COMMENT ON COLUMN tbl_approval_line_step.upd_id       IS '최종수정자 ID';
COMMENT ON COLUMN tbl_approval_line_step.upd_dt       IS '최종수정일시';

-- ------------------------------------------------------------
-- 5. tbl_template — 표준 템플릿 카탈로그 (플랫폼 전역, co_cd 없음)
--    해썹일지 31 템플릿 + 표준기준서 추가 12종 메타를 모두 등록한다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_template (
    idx                    bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tmpl_cd                varchar(20)  NOT NULL,
    tmpl_nm                varchar(200) NOT NULL,
    mng_no                 varchar(20)  NULL,
    doc_kind               varchar(3)   NOT NULL,
    category_cd            varchar(20)  NULL,
    scrn_cd                varchar(30)  NULL,
    form_path              varchar(300) NULL,
    default_cycle_cd       varchar(10)  NULL,
    default_retention_month int         NOT NULL DEFAULT 24,
    ver_no                 int          NOT NULL DEFAULT 1,
    impl_yn                varchar(1)   NOT NULL DEFAULT 'N',
    sort_no                int          NOT NULL DEFAULT 0,
    use_yn                 varchar(1)   NOT NULL DEFAULT 'Y',
    ins_id                 varchar(20)  NULL,
    ins_dt                 timestamp    NULL DEFAULT now(),
    upd_id                 varchar(20)  NULL,
    upd_dt                 timestamp    NULL,
    CONSTRAINT ux_tbl_template UNIQUE (tmpl_cd)
);
COMMENT ON TABLE  tbl_template                         IS '표준 템플릿 카탈로그 — 플랫폼이 배포하는 31종 + 추가 12종 메타. 업체는 복사해서 쓴다';
COMMENT ON COLUMN tbl_template.idx                     IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_template.tmpl_cd                 IS '템플릿 코드 — CCP_COLD, CCP_METAL, DAILY_HYG 등';
COMMENT ON COLUMN tbl_template.tmpl_nm                 IS '표준 문서명 — CCP 냉장보관 모니터링 일지 등(회사별 CCP 코드는 포함하지 않음)';
COMMENT ON COLUMN tbl_template.mng_no                  IS '표준기준서 관리번호 — HA-HYG-01, HA-CCP-06-01 등';
COMMENT ON COLUMN tbl_template.doc_kind                IS '문서 유형 — DB:전용 HTML 화면 + DB 저장, HWP:rhwp 문서작성형';
COMMENT ON COLUMN tbl_template.category_cd             IS '분류 — CCP, HYG, FAC, INV, VER, EDU, DOC';
COMMENT ON COLUMN tbl_template.scrn_cd                 IS '연결 화면코드 — doc_kind=DB일 때(= 전용 화면 보유) tbl_screen.scrn_cd';
COMMENT ON COLUMN tbl_template.form_path               IS '표준 원본 HWP 양식의 APP_FILE_ROOT 기준 상대 경로 — DB형은 참조본, HWP형은 rhwp 편집 시작 원본';
COMMENT ON COLUMN tbl_template.default_cycle_cd        IS '기본 작성주기 — D:일, W:주, M:월, Y:년, E:수시(이벤트)';
COMMENT ON COLUMN tbl_template.default_retention_month IS '기본 보존 개월수 — HACCP 기준 최소 24';
COMMENT ON COLUMN tbl_template.ver_no                  IS '템플릿 버전 — 표의 전체 구조 변경 시 증가';
COMMENT ON COLUMN tbl_template.impl_yn                 IS '구현여부 Y/N — N일 때(= 카탈로그 등록만, 화면 미개발) 업체 배포 대상에서 제외';
COMMENT ON COLUMN tbl_template.sort_no                 IS '정렬순서 — 표준기준서 관리번호 순';
COMMENT ON COLUMN tbl_template.use_yn                  IS '사용여부 Y/N';
COMMENT ON COLUMN tbl_template.ins_id                  IS '최초입력자 ID';
COMMENT ON COLUMN tbl_template.ins_dt                  IS '최초입력일시';
COMMENT ON COLUMN tbl_template.upd_id                  IS '최종수정자 ID';
COMMENT ON COLUMN tbl_template.upd_dt                  IS '최종수정일시';

-- ------------------------------------------------------------
-- 6. tbl_company_template — 업체 사용양식
--    신규 업체 등록 시 tbl_template(impl_yn=Y)을 복사해 생성한다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_company_template (
    idx              bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd            varchar(10)  NOT NULL,
    tmpl_cd          varchar(20)  NOT NULL,
    tmpl_nm_ovr      varchar(200) NULL,
    appr_line_cd     varchar(20)  NULL,
    cycle_cd         varchar(10)  NULL,
    retention_month  int          NULL,
    use_yn           varchar(1)   NOT NULL DEFAULT 'Y',
    ins_id           varchar(20)  NULL,
    ins_dt           timestamp    NULL DEFAULT now(),
    upd_id           varchar(20)  NULL,
    upd_dt           timestamp    NULL,
    CONSTRAINT ux_tbl_company_template UNIQUE (co_cd, tmpl_cd)
);
COMMENT ON TABLE  tbl_company_template                 IS '업체 사용양식 — 표준 템플릿을 업체가 복사·조정한 결과';
COMMENT ON COLUMN tbl_company_template.idx             IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_company_template.co_cd           IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_company_template.tmpl_cd         IS '템플릿 코드 — tbl_template.tmpl_cd';
COMMENT ON COLUMN tbl_company_template.tmpl_nm_ovr     IS '문서명 오버라이드 — NULL이면(= 미지정) tbl_template.tmpl_nm 사용';
COMMENT ON COLUMN tbl_company_template.appr_line_cd    IS '적용 결재선 코드 — tbl_approval_line.appr_line_cd';
COMMENT ON COLUMN tbl_company_template.cycle_cd        IS '작성주기 오버라이드 — NULL이면 표준 주기 사용';
COMMENT ON COLUMN tbl_company_template.retention_month IS '보존 개월수 오버라이드 — NULL이면 표준값 사용';
COMMENT ON COLUMN tbl_company_template.use_yn          IS '사용여부 Y/N — N일 때(= 우리 업체 미해당 양식) 메뉴·일정에서 제외';
COMMENT ON COLUMN tbl_company_template.ins_id          IS '최초입력자 ID';
COMMENT ON COLUMN tbl_company_template.ins_dt          IS '최초입력일시';
COMMENT ON COLUMN tbl_company_template.upd_id          IS '최종수정자 ID';
COMMENT ON COLUMN tbl_company_template.upd_dt          IS '최종수정일시';

-- ------------------------------------------------------------
-- 7. tbl_check_item — 템플릿별 표준 점검항목 (플랫폼 전역, co_cd 없음)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_check_item (
    idx        bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tmpl_cd    varchar(20)  NOT NULL,
    item_cd    varchar(20)  NOT NULL,
    grp_cd     varchar(20)  NULL,
    grp_nm     varchar(100) NULL,
    item_nm    varchar(500) NOT NULL,
    input_type varchar(10)  NOT NULL DEFAULT 'OX',
    unit_nm    varchar(20)  NULL,
    method_nm  varchar(100) NULL,
    cycle_nm   varchar(50)  NULL,
    sort_no    int          NOT NULL DEFAULT 0,
    use_yn     varchar(1)   NOT NULL DEFAULT 'Y',
    ins_id     varchar(20)  NULL,
    ins_dt     timestamp    NULL DEFAULT now(),
    upd_id     varchar(20)  NULL,
    upd_dt     timestamp    NULL,
    CONSTRAINT ux_tbl_check_item UNIQUE (tmpl_cd, item_cd)
);
COMMENT ON TABLE  tbl_check_item            IS '템플릿별 표준 점검항목 — 일일위생 15항목, 용수관리 11항목 등 표준기준서 문구 그대로';
COMMENT ON COLUMN tbl_check_item.idx        IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_check_item.tmpl_cd    IS '템플릿 코드 — tbl_template.tmpl_cd';
COMMENT ON COLUMN tbl_check_item.item_cd    IS '항목코드 — 템플릿 내 유일';
COMMENT ON COLUMN tbl_check_item.grp_cd     IS '항목 구분코드 — BEFORE(작업 전), DURING(작업 중), AFTER(작업 후), TANK(저장탱크) 등';
COMMENT ON COLUMN tbl_check_item.grp_nm     IS '항목 구분명 — A4 표 좌측 병합 셀에 출력';
COMMENT ON COLUMN tbl_check_item.item_nm    IS '점검항목 문구 — 표준기준서 원문';
COMMENT ON COLUMN tbl_check_item.input_type IS '입력유형 — OX(양호/불량), YN(예/아니오), JUDGE(적합/부적합), NUM(수치), TEXT(서술), TIME(시각)';
COMMENT ON COLUMN tbl_check_item.unit_nm    IS '단위 — input_type=NUM일 때 표기';
COMMENT ON COLUMN tbl_check_item.method_nm  IS '점검방법 — 육안 등. 시설·설비 점검표처럼 표에 방법 열이 있는 양식에서만 사용';
COMMENT ON COLUMN tbl_check_item.cycle_nm   IS '점검주기 — 1회/일 등. 방법 열과 함께 출력';
COMMENT ON COLUMN tbl_check_item.sort_no    IS '정렬순서';
COMMENT ON COLUMN tbl_check_item.use_yn     IS '사용여부 Y/N';
COMMENT ON COLUMN tbl_check_item.ins_id     IS '최초입력자 ID';
COMMENT ON COLUMN tbl_check_item.ins_dt     IS '최초입력일시';
COMMENT ON COLUMN tbl_check_item.upd_id     IS '최종수정자 ID';
COMMENT ON COLUMN tbl_check_item.upd_dt     IS '최종수정일시';

-- ------------------------------------------------------------
-- 8. tbl_company_check_item — 업체별 점검항목 조정
--    자유 양식 빌더를 만들지 않는 대신 이 테이블로 표시·숨김·문구·순서만 바꾼다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_company_check_item (
    idx         bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd       varchar(10)  NOT NULL,
    tmpl_cd     varchar(20)  NOT NULL,
    item_cd     varchar(20)  NOT NULL,
    item_nm_ovr varchar(500) NULL,
    sort_no     int          NULL,
    use_yn      varchar(1)   NOT NULL DEFAULT 'Y',
    ins_id      varchar(20)  NULL,
    ins_dt      timestamp    NULL DEFAULT now(),
    upd_id      varchar(20)  NULL,
    upd_dt      timestamp    NULL,
    CONSTRAINT ux_tbl_company_check_item UNIQUE (co_cd, tmpl_cd, item_cd)
);
COMMENT ON TABLE  tbl_company_check_item             IS '업체별 점검항목 조정 — 표시·숨김·문구·순서만 허용. 표 구조 변경은 플랫폼 신규 버전으로';
COMMENT ON COLUMN tbl_company_check_item.idx         IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_company_check_item.co_cd       IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_company_check_item.tmpl_cd     IS '템플릿 코드 — tbl_template.tmpl_cd';
COMMENT ON COLUMN tbl_company_check_item.item_cd     IS '항목코드 — tbl_check_item.item_cd';
COMMENT ON COLUMN tbl_company_check_item.item_nm_ovr IS '항목문구 오버라이드 — NULL이면(= 미수정) 표준 문구 사용';
COMMENT ON COLUMN tbl_company_check_item.sort_no     IS '정렬순서 오버라이드 — NULL이면 표준 순서 사용';
COMMENT ON COLUMN tbl_company_check_item.use_yn      IS '사용여부 Y/N — N일 때(= 우리 업체 미해당 항목) 점검표에서 행 숨김';
COMMENT ON COLUMN tbl_company_check_item.ins_id      IS '최초입력자 ID';
COMMENT ON COLUMN tbl_company_check_item.ins_dt      IS '최초입력일시';
COMMENT ON COLUMN tbl_company_check_item.upd_id      IS '최종수정자 ID';
COMMENT ON COLUMN tbl_company_check_item.upd_dt      IS '최종수정일시';

-- ------------------------------------------------------------
-- 9. tbl_doc_no_rule — 문서번호 채번 규칙
--    last_seq 갱신은 pg_advisory_xact_lock으로 동시성을 보호한다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_doc_no_rule (
    idx            bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd          varchar(10) NOT NULL,
    tmpl_cd        varchar(20) NOT NULL,
    prefix         varchar(20) NULL,
    date_fmt       varchar(10) NULL DEFAULT 'YYYYMMDD',
    seq_len        int         NOT NULL DEFAULT 3,
    reset_cycle    varchar(1)  NOT NULL DEFAULT 'Y',
    last_reset_key varchar(10) NULL,
    last_seq       int         NOT NULL DEFAULT 0,
    ins_id         varchar(20) NULL,
    ins_dt         timestamp   NULL DEFAULT now(),
    upd_id         varchar(20) NULL,
    upd_dt         timestamp   NULL,
    CONSTRAINT ux_tbl_doc_no_rule UNIQUE (co_cd, tmpl_cd)
);
COMMENT ON TABLE  tbl_doc_no_rule                IS '문서번호 채번 규칙 — 사용자에게 보이는 업무번호(doc_no) 생성. idx와 별개';
COMMENT ON COLUMN tbl_doc_no_rule.idx            IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_doc_no_rule.co_cd          IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_doc_no_rule.tmpl_cd        IS '템플릿 코드 — tbl_template.tmpl_cd';
COMMENT ON COLUMN tbl_doc_no_rule.prefix         IS '문서번호 접두 — CCP-B 등';
COMMENT ON COLUMN tbl_doc_no_rule.date_fmt       IS '일자 형식 — YYYYMMDD / YYYYMM / YYYY. 공백이면 일자 미포함';
COMMENT ON COLUMN tbl_doc_no_rule.seq_len        IS '일련번호 자릿수 — 3이면 001부터';
COMMENT ON COLUMN tbl_doc_no_rule.reset_cycle    IS '일련번호 리셋 주기 — D:일, M:월, Y:년, N:리셋 없음';
COMMENT ON COLUMN tbl_doc_no_rule.last_reset_key IS '마지막 리셋 기준키 — reset_cycle에 맞춘 일자 문자열. 값이 바뀌면 last_seq를 0으로 되돌린다';
COMMENT ON COLUMN tbl_doc_no_rule.last_seq       IS '마지막 채번 일련번호';
COMMENT ON COLUMN tbl_doc_no_rule.ins_id         IS '최초입력자 ID';
COMMENT ON COLUMN tbl_doc_no_rule.ins_dt         IS '최초입력일시';
COMMENT ON COLUMN tbl_doc_no_rule.upd_id         IS '최종수정자 ID';
COMMENT ON COLUMN tbl_doc_no_rule.upd_dt         IS '최종수정일시';

-- ------------------------------------------------------------
-- 10. tbl_document — 문서 공통 관리정보 (DB형·문서형 통합)
--     DB형 15종의 헤더 테이블과 rhwp 문서형이 모두 이 테이블의 idx를 doc_idx로 참조한다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_document (
    idx             bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd           varchar(10)  NOT NULL,
    tmpl_cd         varchar(20)  NOT NULL,
    doc_kind        varchar(3)   NOT NULL,
    doc_no          varchar(50)  NOT NULL,
    base_dt         varchar(8)   NOT NULL,
    base_dt_to      varchar(8)   NULL,
    title           varchar(300) NULL,
    status          varchar(3)   NOT NULL DEFAULT 'WRK',
    appr_line_cd    varchar(20)  NULL,
    writer_id       varchar(20)  NULL,
    write_dt        timestamp    NULL,
    reviewer_id     varchar(20)  NULL,
    review_dt       timestamp    NULL,
    approver_id     varchar(20)  NULL,
    approve_dt      timestamp    NULL,
    reject_reason   varchar(500) NULL,
    ver_no          int          NOT NULL DEFAULT 1,
    retention_until varchar(8)   NULL,
    del_yn          varchar(1)   NOT NULL DEFAULT 'N',
    ins_id          varchar(20)  NULL,
    ins_dt          timestamp    NULL DEFAULT now(),
    upd_id          varchar(20)  NULL,
    upd_dt          timestamp    NULL,
    CONSTRAINT ux_tbl_document_doc_no UNIQUE (co_cd, doc_no)
);
COMMENT ON TABLE  tbl_document                 IS '문서 공통 관리정보 — 모든 문서 1행. 사용자는 목록에서 DB형·문서형을 구분하지 않는다';
COMMENT ON COLUMN tbl_document.idx             IS 'PK 자동 채번 대리키 — 업무 테이블이 doc_idx로 참조';
COMMENT ON COLUMN tbl_document.co_cd           IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_document.tmpl_cd         IS '템플릿 코드 — tbl_template.tmpl_cd';
COMMENT ON COLUMN tbl_document.doc_kind        IS '문서 유형 — DB:전용 화면, HWP:rhwp 문서작성형';
COMMENT ON COLUMN tbl_document.doc_no          IS '문서번호 — tbl_doc_no_rule로 채번한 사용자 표기용 번호';
COMMENT ON COLUMN tbl_document.base_dt         IS '기준일자 YYYYMMDD — 작성일 또는 점검일. 일정·검색의 기준';
COMMENT ON COLUMN tbl_document.base_dt_to      IS '기준종료일자 YYYYMMDD — 용수관리처럼 기간 단위 문서일 때만 사용';
COMMENT ON COLUMN tbl_document.title           IS '문서 제목 — 미입력 시 템플릿명 + 기준일자로 자동 생성';
COMMENT ON COLUMN tbl_document.status          IS '문서상태 — WRK:작성중, REQ:검토요청, REV:검토완료, APV:승인완료, RJT:반려';
COMMENT ON COLUMN tbl_document.appr_line_cd    IS '적용 결재선 — 작성 시점의 tbl_company_template.appr_line_cd 스냅샷';
COMMENT ON COLUMN tbl_document.writer_id       IS '작성자 로그인 ID';
COMMENT ON COLUMN tbl_document.write_dt        IS '작성(상신) 일시';
COMMENT ON COLUMN tbl_document.reviewer_id     IS '검토자 로그인 ID';
COMMENT ON COLUMN tbl_document.review_dt       IS '검토 일시';
COMMENT ON COLUMN tbl_document.approver_id     IS '승인자 로그인 ID';
COMMENT ON COLUMN tbl_document.approve_dt      IS '승인 일시';
COMMENT ON COLUMN tbl_document.reject_reason   IS '반려 사유 — status=RJT일 때 필수';
COMMENT ON COLUMN tbl_document.ver_no          IS '현재 버전 — 승인 후 수정 시 증가하고 직전 내용은 tbl_document_version에 스냅샷';
COMMENT ON COLUMN tbl_document.retention_until IS '보존 만료일 YYYYMMDD — base_dt + 보존 개월수. 경과 전 삭제 차단';
COMMENT ON COLUMN tbl_document.del_yn          IS '삭제여부 Y/N — 물리 삭제 대신 논리 삭제. 승인 문서는 Y로도 바꿀 수 없다';
COMMENT ON COLUMN tbl_document.ins_id          IS '최초입력자 ID';
COMMENT ON COLUMN tbl_document.ins_dt          IS '최초입력일시';
COMMENT ON COLUMN tbl_document.upd_id          IS '최종수정자 ID';
COMMENT ON COLUMN tbl_document.upd_dt          IS '최종수정일시';

-- ------------------------------------------------------------
-- 11. tbl_document_approval — 문서 결재 이력
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_document_approval (
    idx          bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd        varchar(10)  NOT NULL,
    doc_idx      bigint       NOT NULL,
    step_no      int          NOT NULL,
    role_cd      varchar(20)  NOT NULL,
    approver_id  varchar(20)  NULL,
    approver_nm  varchar(50)  NULL,
    result_cd    varchar(1)   NOT NULL DEFAULT 'W',
    opinion      varchar(500) NULL,
    act_dt       timestamp    NULL,
    sign_path    varchar(300) NULL,
    ins_id       varchar(20)  NULL,
    ins_dt       timestamp    NULL DEFAULT now(),
    upd_id       varchar(20)  NULL,
    upd_dt       timestamp    NULL,
    CONSTRAINT ux_tbl_document_approval UNIQUE (doc_idx, step_no)
);
COMMENT ON TABLE  tbl_document_approval             IS '문서 결재 이력 — A4 결재란 3칸의 실제 데이터 원천';
COMMENT ON COLUMN tbl_document_approval.idx         IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_document_approval.co_cd       IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_document_approval.doc_idx     IS '문서 idx — tbl_document.idx';
COMMENT ON COLUMN tbl_document_approval.step_no     IS '단계 순번 — 결재선 step_no 스냅샷';
COMMENT ON COLUMN tbl_document_approval.role_cd     IS '역할 — WRITE:작성자, REVIEW:검토자, APPROVE:승인자';
COMMENT ON COLUMN tbl_document_approval.approver_id IS '결재자 로그인 ID';
COMMENT ON COLUMN tbl_document_approval.approver_nm IS '결재자명 — 결재 시점 스냅샷. 이후 사용자명이 바뀌어도 문서는 당시 이름을 유지';
COMMENT ON COLUMN tbl_document_approval.result_cd   IS '결재 결과 — W:대기, A:승인, R:반려';
COMMENT ON COLUMN tbl_document_approval.opinion     IS '결재 의견 — 반려(R)일 때 필수';
COMMENT ON COLUMN tbl_document_approval.act_dt      IS '결재 처리 일시';
COMMENT ON COLUMN tbl_document_approval.sign_path   IS '서명 이미지 경로 — 결재 시점 tbl_user.sign_path 스냅샷';
COMMENT ON COLUMN tbl_document_approval.ins_id      IS '최초입력자 ID';
COMMENT ON COLUMN tbl_document_approval.ins_dt      IS '최초입력일시';
COMMENT ON COLUMN tbl_document_approval.upd_id      IS '최종수정자 ID';
COMMENT ON COLUMN tbl_document_approval.upd_dt      IS '최종수정일시';

-- ------------------------------------------------------------
-- 12. tbl_document_file — 문서 첨부·원본·PDF
--     DB에 바이너리를 넣지 않고 경로만 보관한다(사진 다량)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_document_file (
    idx       bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd     varchar(10)  NOT NULL,
    doc_idx   bigint       NOT NULL,
    file_kind varchar(10)  NOT NULL,
    file_nm   varchar(300) NOT NULL,
    file_path varchar(500) NOT NULL,
    file_size bigint       NULL,
    mime_type varchar(100) NULL,
    sort_no   int          NOT NULL DEFAULT 0,
    ins_id    varchar(20)  NULL,
    ins_dt    timestamp    NULL DEFAULT now()
);
COMMENT ON TABLE  tbl_document_file           IS '문서 첨부·원본·PDF — 경로만 저장. 실제 파일은 업체별 볼륨 경로에 보관';
COMMENT ON COLUMN tbl_document_file.idx       IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_document_file.co_cd     IS '회사코드 — 테넌트 키. 파일 저장 경로의 첫 세그먼트이기도 하다';
COMMENT ON COLUMN tbl_document_file.doc_idx   IS '문서 idx — tbl_document.idx';
COMMENT ON COLUMN tbl_document_file.file_kind IS '파일 종류 — HWP_SRC:한글 원본, PDF:완료본, ATTACH:일반첨부, PHOTO:사진';
COMMENT ON COLUMN tbl_document_file.file_nm   IS '원본 파일명 — 사용자가 올린 그대로. 다운로드 시 이 이름으로 내려준다';
COMMENT ON COLUMN tbl_document_file.file_path IS '저장 경로 — {root}/{co_cd}/{yyyy}/{mm}/{idx}_{원본명}';
COMMENT ON COLUMN tbl_document_file.file_size IS '파일 크기(byte)';
COMMENT ON COLUMN tbl_document_file.mime_type IS 'MIME 타입';
COMMENT ON COLUMN tbl_document_file.sort_no   IS '정렬순서 — 사진 첨부 표시 순서';
COMMENT ON COLUMN tbl_document_file.ins_id    IS '업로더 로그인 ID';
COMMENT ON COLUMN tbl_document_file.ins_dt    IS '업로드 일시';

-- ------------------------------------------------------------
-- 13. tbl_document_relation — 문서 간 연결
--     검증계획 → 점검표 → 결과보고서 → 개선조치, 교육계획 → 교육일지 등
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_document_relation (
    idx         bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd       varchar(10) NOT NULL,
    src_doc_idx bigint      NOT NULL,
    rel_type    varchar(20) NOT NULL,
    tgt_doc_idx bigint      NOT NULL,
    ins_id      varchar(20) NULL,
    ins_dt      timestamp   NULL DEFAULT now(),
    CONSTRAINT ux_tbl_document_relation UNIQUE (src_doc_idx, rel_type, tgt_doc_idx)
);
COMMENT ON TABLE  tbl_document_relation             IS '문서 간 연결 — 관련 문서 바로가기와 감사자료 묶음 출력의 근거';
COMMENT ON COLUMN tbl_document_relation.idx         IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_document_relation.co_cd       IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_document_relation.src_doc_idx IS '출발 문서 idx — tbl_document.idx';
COMMENT ON COLUMN tbl_document_relation.rel_type    IS '관계 유형 — PLAN_CHECK(계획-점검), CHECK_RESULT(점검-결과), RESULT_CA(결과-개선조치), EDU_PLAN_LOG(교육계획-교육일지), CALIB_TARGET_LOG(검교정대상-일지)';
COMMENT ON COLUMN tbl_document_relation.tgt_doc_idx IS '도착 문서 idx — tbl_document.idx';
COMMENT ON COLUMN tbl_document_relation.ins_id      IS '최초입력자 ID';
COMMENT ON COLUMN tbl_document_relation.ins_dt      IS '최초입력일시';

-- ------------------------------------------------------------
-- 14. tbl_document_version — 문서 버전 스냅샷
--     승인 완료 후 수정할 때 직전 상태를 통째로 남긴다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_document_version (
    idx           bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd         varchar(10)  NOT NULL,
    doc_idx       bigint       NOT NULL,
    ver_no        int          NOT NULL,
    snap_json     jsonb        NULL,
    file_path     varchar(500) NULL,
    change_reason varchar(500) NULL,
    ins_id        varchar(20)  NULL,
    ins_dt        timestamp    NULL DEFAULT now(),
    CONSTRAINT ux_tbl_document_version UNIQUE (doc_idx, ver_no)
);
COMMENT ON TABLE  tbl_document_version               IS '문서 버전 스냅샷 — 승인 후 수정 시 직전 상태 보존. 감사 대응 필수';
COMMENT ON COLUMN tbl_document_version.idx           IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_document_version.co_cd         IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_document_version.doc_idx       IS '문서 idx — tbl_document.idx';
COMMENT ON COLUMN tbl_document_version.ver_no        IS '스냅샷 버전 — 이 행이 보존하는 직전 버전 번호';
COMMENT ON COLUMN tbl_document_version.snap_json     IS '본문 스냅샷 JSON — DB형일 때(= 헤더+상세 전체 직렬화)';
COMMENT ON COLUMN tbl_document_version.file_path     IS '원본 파일 스냅샷 경로 — 문서형일 때(= HWPX/PDF 사본)';
COMMENT ON COLUMN tbl_document_version.change_reason IS '변경 사유 — 승인 문서 수정 시 필수 입력';
COMMENT ON COLUMN tbl_document_version.ins_id        IS '최초입력자 ID';
COMMENT ON COLUMN tbl_document_version.ins_dt        IS '최초입력일시';

-- ------------------------------------------------------------
-- 15. tbl_schedule_rule — 작성주기 규칙
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_schedule_rule (
    idx       bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd     varchar(10) NOT NULL,
    tmpl_cd   varchar(20) NOT NULL,
    rule_seq  int         NOT NULL DEFAULT 1,
    cycle_cd  varchar(1)  NOT NULL,
    week_days varchar(20) NULL,
    month_day int         NULL,
    month_no  int         NULL,
    due_time  varchar(4)  NULL DEFAULT '1800',
    dept_cd   varchar(20) NULL,
    user_id   varchar(20) NULL,
    use_yn    varchar(1)  NOT NULL DEFAULT 'Y',
    ins_id    varchar(20) NULL,
    ins_dt    timestamp   NULL DEFAULT now(),
    upd_id    varchar(20) NULL,
    upd_dt    timestamp   NULL,
    CONSTRAINT ux_tbl_schedule_rule UNIQUE (co_cd, tmpl_cd, rule_seq)
);
COMMENT ON TABLE  tbl_schedule_rule           IS '작성주기 규칙 — 오늘 할 일 생성 배치의 입력. 템플릿별 여러 규칙 허용';
COMMENT ON COLUMN tbl_schedule_rule.idx       IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_schedule_rule.co_cd     IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_schedule_rule.tmpl_cd   IS '템플릿 코드 — tbl_template.tmpl_cd';
COMMENT ON COLUMN tbl_schedule_rule.rule_seq  IS '규칙 순번 — 한 템플릿에 주기가 여럿일 때 구분';
COMMENT ON COLUMN tbl_schedule_rule.cycle_cd  IS '주기 — D:일, W:주, M:월, Y:년, E:수시(이벤트 발생 시)';
COMMENT ON COLUMN tbl_schedule_rule.week_days IS '요일 — cycle_cd=W일 때. 1(월)~7(일) 쉼표 구분';
COMMENT ON COLUMN tbl_schedule_rule.month_day IS '기준일 — cycle_cd=M/Y일 때 해당 월의 일자';
COMMENT ON COLUMN tbl_schedule_rule.month_no  IS '기준월 — cycle_cd=Y일 때 1~12';
COMMENT ON COLUMN tbl_schedule_rule.due_time  IS '마감시각 HHMM — 경과 시 지연(LATE) 처리';
COMMENT ON COLUMN tbl_schedule_rule.dept_cd   IS '담당 부서코드 — 오늘 할 일 배정 대상';
COMMENT ON COLUMN tbl_schedule_rule.user_id   IS '담당자 로그인 ID — 지정 시 개인에게 직접 배정';
COMMENT ON COLUMN tbl_schedule_rule.use_yn    IS '사용여부 Y/N';
COMMENT ON COLUMN tbl_schedule_rule.ins_id    IS '최초입력자 ID';
COMMENT ON COLUMN tbl_schedule_rule.ins_dt    IS '최초입력일시';
COMMENT ON COLUMN tbl_schedule_rule.upd_id    IS '최종수정자 ID';
COMMENT ON COLUMN tbl_schedule_rule.upd_dt    IS '최종수정일시';

-- ------------------------------------------------------------
-- 16. tbl_schedule_task — 생성된 작성 과제 (오늘 할 일)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_schedule_task (
    idx      bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd    varchar(10) NOT NULL,
    tmpl_cd  varchar(20) NOT NULL,
    base_dt  varchar(8)  NOT NULL,
    due_dt   varchar(8)  NOT NULL,
    due_time varchar(4)  NULL,
    status   varchar(4)  NOT NULL DEFAULT 'TODO',
    doc_idx  bigint      NULL,
    dept_cd  varchar(20) NULL,
    user_id  varchar(20) NULL,
    ins_id   varchar(20) NULL,
    ins_dt   timestamp   NULL DEFAULT now(),
    upd_id   varchar(20) NULL,
    upd_dt   timestamp   NULL,
    CONSTRAINT ux_tbl_schedule_task UNIQUE (co_cd, tmpl_cd, base_dt)
);
COMMENT ON TABLE  tbl_schedule_task          IS '작성 과제 — 일 1회 배치 생성 + 로그인 시 온디맨드 보정. 오늘 할 일·누락 알림의 원천';
COMMENT ON COLUMN tbl_schedule_task.idx      IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_schedule_task.co_cd    IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_schedule_task.tmpl_cd  IS '템플릿 코드 — tbl_template.tmpl_cd';
COMMENT ON COLUMN tbl_schedule_task.base_dt  IS '기준일자 YYYYMMDD — 작성해야 하는 대상 일자';
COMMENT ON COLUMN tbl_schedule_task.due_dt   IS '마감일자 YYYYMMDD';
COMMENT ON COLUMN tbl_schedule_task.due_time IS '마감시각 HHMM';
COMMENT ON COLUMN tbl_schedule_task.status   IS '상태 — TODO:미작성, ING:작성중, APV:승인완료, LATE:기한경과';
COMMENT ON COLUMN tbl_schedule_task.doc_idx  IS '연결 문서 idx — 작성 시작 시 tbl_document.idx로 채워진다';
COMMENT ON COLUMN tbl_schedule_task.dept_cd  IS '담당 부서코드';
COMMENT ON COLUMN tbl_schedule_task.user_id  IS '담당자 로그인 ID';
COMMENT ON COLUMN tbl_schedule_task.ins_id   IS '최초입력자 ID — 배치 실행 주체';
COMMENT ON COLUMN tbl_schedule_task.ins_dt   IS '최초입력일시';
COMMENT ON COLUMN tbl_schedule_task.upd_id   IS '최종수정자 ID';
COMMENT ON COLUMN tbl_schedule_task.upd_dt   IS '최종수정일시';

-- ------------------------------------------------------------
-- 17. tbl_corrective_action — 이탈·개선조치
--     전 점검표의 이탈내용/개선조치 푸터를 이 한 테이블로 통일한다.
--     각 업무 테이블에 이탈 컬럼을 중복으로 두지 않는다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_corrective_action (
    idx             bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd           varchar(10)  NOT NULL,
    ca_no           varchar(50)  NOT NULL,
    src_tmpl_cd     varchar(20)  NULL,
    src_doc_idx     bigint       NULL,
    src_row_idx     bigint       NULL,
    occur_dt        varchar(8)   NOT NULL,
    occur_place     varchar(200) NULL,
    deviation_desc  text         NOT NULL,
    action_desc     text         NULL,
    action_user_id  varchar(20)  NULL,
    action_user_nm  varchar(50)  NULL,
    action_dt       varchar(8)   NULL,
    confirm_user_id varchar(20)  NULL,
    confirm_user_nm varchar(50)  NULL,
    confirm_dt      varchar(8)   NULL,
    due_dt          varchar(8)   NULL,
    status          varchar(4)   NOT NULL DEFAULT 'OPEN',
    ins_id          varchar(20)  NULL,
    ins_dt          timestamp    NULL DEFAULT now(),
    upd_id          varchar(20)  NULL,
    upd_dt          timestamp    NULL,
    CONSTRAINT ux_tbl_corrective_action UNIQUE (co_cd, ca_no)
);
COMMENT ON TABLE  tbl_corrective_action                 IS '이탈·개선조치 — 전 점검표 공통. 미완료 건은 대시보드에 노출되고 결재 상신을 막는다';
COMMENT ON COLUMN tbl_corrective_action.idx             IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_corrective_action.co_cd           IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_corrective_action.ca_no           IS '개선조치 번호 — 업체 내 유일';
COMMENT ON COLUMN tbl_corrective_action.src_tmpl_cd     IS '발생 출처 템플릿 코드 — 어느 점검표에서 나왔는지';
COMMENT ON COLUMN tbl_corrective_action.src_doc_idx     IS '발생 출처 문서 idx — tbl_document.idx';
COMMENT ON COLUMN tbl_corrective_action.src_row_idx     IS '발생 출처 상세행 idx — 어느 행의 부적합인지 특정';
COMMENT ON COLUMN tbl_corrective_action.occur_dt        IS '발생일자 YYYYMMDD';
COMMENT ON COLUMN tbl_corrective_action.occur_place     IS '발생장소 — 작업장·보관고·설비명';
COMMENT ON COLUMN tbl_corrective_action.deviation_desc  IS '이탈내용 — 기준을 벗어난 사실 서술';
COMMENT ON COLUMN tbl_corrective_action.action_desc     IS '개선조치 및 결과 — 조치 내용과 결과 서술';
COMMENT ON COLUMN tbl_corrective_action.action_user_id  IS '조치자 로그인 ID';
COMMENT ON COLUMN tbl_corrective_action.action_user_nm  IS '조치자 표시명 — A4 푸터 서명란 자유입력';
COMMENT ON COLUMN tbl_corrective_action.action_dt       IS '조치일자 YYYYMMDD';
COMMENT ON COLUMN tbl_corrective_action.confirm_user_id IS '확인자 로그인 ID — A4 조치자 확인란';
COMMENT ON COLUMN tbl_corrective_action.confirm_user_nm IS '확인자 표시명 — A4 푸터 확인란 자유입력';
COMMENT ON COLUMN tbl_corrective_action.confirm_dt      IS '확인일자 YYYYMMDD';
COMMENT ON COLUMN tbl_corrective_action.due_dt          IS '조치 기한 YYYYMMDD — 경과 시 알림';
COMMENT ON COLUMN tbl_corrective_action.status          IS '상태 — OPEN:미조치, ING:조치중, DONE:완료';
COMMENT ON COLUMN tbl_corrective_action.ins_id          IS '최초입력자 ID';
COMMENT ON COLUMN tbl_corrective_action.ins_dt          IS '최초입력일시';
COMMENT ON COLUMN tbl_corrective_action.upd_id          IS '최종수정자 ID';
COMMENT ON COLUMN tbl_corrective_action.upd_dt          IS '최종수정일시';

-- ------------------------------------------------------------
-- 18. tbl_notification — 알림함
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_notification (
    idx           bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd         varchar(10)  NOT NULL,
    noti_type_cd  varchar(30)  NOT NULL,
    user_id       varchar(20)  NOT NULL,
    title         varchar(200) NOT NULL,
    content       varchar(500) NULL,
    link_scrn_cd  varchar(30)  NULL,
    link_doc_idx  bigint       NULL,
    read_yn       varchar(1)   NOT NULL DEFAULT 'N',
    read_dt       timestamp    NULL,
    ins_dt        timestamp    NOT NULL DEFAULT now()
);
COMMENT ON TABLE  tbl_notification              IS '알림함 — 수신 여부는 tbl_user_noti_pref를 따르고, 발송된 알림만 이 테이블에 쌓인다';
COMMENT ON COLUMN tbl_notification.idx          IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_notification.co_cd        IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_notification.noti_type_cd IS '알림 유형 — tbl_user_noti_pref.noti_type_cd와 동일 체계';
COMMENT ON COLUMN tbl_notification.user_id      IS '수신자 로그인 ID';
COMMENT ON COLUMN tbl_notification.title        IS '알림 제목';
COMMENT ON COLUMN tbl_notification.content      IS '알림 본문';
COMMENT ON COLUMN tbl_notification.link_scrn_cd IS '바로가기 화면코드 — 클릭 시 열 탭';
COMMENT ON COLUMN tbl_notification.link_doc_idx IS '바로가기 문서 idx — tbl_document.idx';
COMMENT ON COLUMN tbl_notification.read_yn      IS '읽음여부 Y/N';
COMMENT ON COLUMN tbl_notification.read_dt      IS '읽은 일시';
COMMENT ON COLUMN tbl_notification.ins_dt       IS '발송 일시';
