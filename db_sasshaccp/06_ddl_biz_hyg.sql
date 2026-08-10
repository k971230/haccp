-- ============================================================
--  DDL 6 — 업무 테이블 (2) 위생관리  [DB형 5종]
--
--  개발자: 박승우
--  일자: 2026-08-05
--  코멘트:
--    1) 5 일일 위생 점검일지, 6 개인 위생관리 점검표, 7 작업장 환경위생 점검표,
--       8 방충·방서 점검표, 9 용수관리 점검표
--    2) 점검항목 문구는 tbl_check_item(표준) + tbl_company_check_item(업체 조정)에서 가져오고
--       기록 테이블에는 판정값과 스냅샷 문구만 남긴다
--    3) 열이 가변인 표(작업장 수·주차 수)는 세로 정규화한다 — 컬럼 추가 없이 업체 차이를 흡수
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 5-1. tbl_daily_hygiene — 일일 위생 점검일지 (헤더)
--      원본 양식은 작업 전(15항목)·작업 중(8항목) 2구간이다. 작업 후 구간은 없다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_daily_hygiene (
    idx         bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd       varchar(10) NOT NULL,
    doc_idx     bigint      NOT NULL,
    base_dt     varchar(8)  NOT NULL,
    before_time varchar(4)  NULL,
    during_time varchar(4)  NULL,
    checker_id  varchar(20) NULL,
    checker_nm  varchar(50) NULL,
    ins_id      varchar(20) NULL,
    ins_dt      timestamp   NULL DEFAULT now(),
    upd_id      varchar(20) NULL,
    upd_dt      timestamp   NULL,
    CONSTRAINT ux_tbl_daily_hygiene UNIQUE (doc_idx)
);
COMMENT ON TABLE  tbl_daily_hygiene             IS '일일 위생 점검일지 헤더 — 표준기준서 관리번호 5. 매일 작성, 담당자 업무 빈도 1위';
COMMENT ON COLUMN tbl_daily_hygiene.idx         IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_daily_hygiene.co_cd       IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_daily_hygiene.doc_idx     IS '문서 idx — tbl_document.idx와 1:1';
COMMENT ON COLUMN tbl_daily_hygiene.base_dt     IS '점검일자 YYYYMMDD';
COMMENT ON COLUMN tbl_daily_hygiene.before_time IS '작업 전 위생상태 점검시각 HHMM — 양식 상단 괄호에 출력';
COMMENT ON COLUMN tbl_daily_hygiene.during_time IS '작업 중 위생상태 점검시각 HHMM';
COMMENT ON COLUMN tbl_daily_hygiene.checker_id  IS '점검자 로그인 ID';
COMMENT ON COLUMN tbl_daily_hygiene.checker_nm  IS '점검자명 — 작성 시점 스냅샷';
COMMENT ON COLUMN tbl_daily_hygiene.ins_id      IS '최초입력자 ID';
COMMENT ON COLUMN tbl_daily_hygiene.ins_dt      IS '최초입력일시';
COMMENT ON COLUMN tbl_daily_hygiene.upd_id      IS '최종수정자 ID';
COMMENT ON COLUMN tbl_daily_hygiene.upd_dt      IS '최종수정일시';

-- ------------------------------------------------------------
-- 5-2. tbl_daily_hygiene_item — 점검항목별 결과
--      온도 기록 항목(작업실 실내온도·냉장실·냉동실)은 num_val/num_val2를 함께 쓴다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_daily_hygiene_item (
    idx       bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd     varchar(10)  NOT NULL,
    hdr_idx   bigint       NOT NULL,
    row_seq   int          NOT NULL,
    grp_cd    varchar(20)  NOT NULL,
    grp_nm    varchar(100) NULL,
    item_cd   varchar(20)  NOT NULL,
    item_nm   varchar(500) NULL,
    judge_cd  varchar(1)   NULL,
    num_val   numeric(7,1) NULL,
    num_val2  numeric(7,1) NULL,
    remark    varchar(500) NULL,
    ins_id    varchar(20)  NULL,
    ins_dt    timestamp    NULL DEFAULT now(),
    upd_id    varchar(20)  NULL,
    upd_dt    timestamp    NULL,
    CONSTRAINT ux_tbl_daily_hygiene_item UNIQUE (hdr_idx, row_seq)
);
COMMENT ON TABLE  tbl_daily_hygiene_item           IS '일일 위생 점검항목별 결과 — 항목 문구는 스냅샷 보관(표준 문구가 바뀌어도 과거 기록 유지)';
COMMENT ON COLUMN tbl_daily_hygiene_item.idx       IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_daily_hygiene_item.co_cd     IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_daily_hygiene_item.hdr_idx   IS '헤더 idx — tbl_daily_hygiene.idx';
COMMENT ON COLUMN tbl_daily_hygiene_item.row_seq   IS '행 순번';
COMMENT ON COLUMN tbl_daily_hygiene_item.grp_cd    IS '구간 구분 — BEFORE:작업 전 위생상태(15항목), DURING:작업 중 위생상태(8항목)';
COMMENT ON COLUMN tbl_daily_hygiene_item.grp_nm    IS '구분 문구 스냅샷 — FE에서 편집 가능. 비어 있으면 표준 grp_nm/grp_cd 표시';
COMMENT ON COLUMN tbl_daily_hygiene_item.item_cd   IS '항목코드 — tbl_check_item.item_cd';
COMMENT ON COLUMN tbl_daily_hygiene_item.item_nm   IS '항목 문구 스냅샷 — 작성 시점의 표시 문구';
COMMENT ON COLUMN tbl_daily_hygiene_item.judge_cd  IS '판정 — O:양호, X:불량. X일 때(= 불량) 개선조치 입력 안내';
COMMENT ON COLUMN tbl_daily_hygiene_item.num_val   IS '수치값1 — 온도 항목일 때 측정 온도. 실내온도·냉장실 온도';
COMMENT ON COLUMN tbl_daily_hygiene_item.num_val2  IS '수치값2 — 한 항목에 값이 둘일 때. 냉동실 온도·습도';
COMMENT ON COLUMN tbl_daily_hygiene_item.remark    IS '비고';
COMMENT ON COLUMN tbl_daily_hygiene_item.ins_id    IS '최초입력자 ID';
COMMENT ON COLUMN tbl_daily_hygiene_item.ins_dt    IS '최초입력일시';
COMMENT ON COLUMN tbl_daily_hygiene_item.upd_id    IS '최종수정자 ID';
COMMENT ON COLUMN tbl_daily_hygiene_item.upd_dt    IS '최종수정일시';

-- ------------------------------------------------------------
-- 6-1. tbl_personal_hygiene — 개인 위생관리 점검표 (헤더)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_personal_hygiene (
    idx        bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd      varchar(10) NOT NULL,
    doc_idx    bigint      NOT NULL,
    base_dt    varchar(8)  NOT NULL,
    checker_id varchar(20) NULL,
    checker_nm varchar(50) NULL,
    ins_id     varchar(20) NULL,
    ins_dt     timestamp   NULL DEFAULT now(),
    upd_id     varchar(20) NULL,
    upd_dt     timestamp   NULL,
    CONSTRAINT ux_tbl_personal_hygiene UNIQUE (doc_idx)
);
COMMENT ON TABLE  tbl_personal_hygiene            IS '개인 위생관리 점검표 헤더 — 표준기준서 관리번호 6. 매일 작성';
COMMENT ON COLUMN tbl_personal_hygiene.idx        IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_personal_hygiene.co_cd      IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_personal_hygiene.doc_idx    IS '문서 idx — tbl_document.idx와 1:1';
COMMENT ON COLUMN tbl_personal_hygiene.base_dt    IS '점검일자 YYYYMMDD';
COMMENT ON COLUMN tbl_personal_hygiene.checker_id IS '점검자 로그인 ID';
COMMENT ON COLUMN tbl_personal_hygiene.checker_nm IS '점검자명 — 작성 시점 스냅샷';
COMMENT ON COLUMN tbl_personal_hygiene.ins_id     IS '최초입력자 ID';
COMMENT ON COLUMN tbl_personal_hygiene.ins_dt     IS '최초입력일시';
COMMENT ON COLUMN tbl_personal_hygiene.upd_id     IS '최종수정자 ID';
COMMENT ON COLUMN tbl_personal_hygiene.upd_dt     IS '최종수정일시';

-- ------------------------------------------------------------
-- 6-2. tbl_personal_hygiene_row — 작업자별 점검 결과
--      점검 항목 6종이 표준양식에 고정이라 컬럼으로 둔다(가변 아님)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_personal_hygiene_row (
    idx             bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd           varchar(10)  NOT NULL,
    hdr_idx         bigint       NOT NULL,
    row_seq         int          NOT NULL,
    worker_user_id  varchar(20)  NULL,
    worker_nm       varchar(50)  NOT NULL,
    health_cd       varchar(1)   NULL,
    cloth_cd        varchar(1)   NULL,
    belongings_cd   varchar(1)   NULL,
    worker_state_cd varchar(1)   NULL,
    anteroom_cd     varchar(1)   NULL,
    handwash_cd     varchar(1)   NULL,
    remark          varchar(500) NULL,
    ins_id          varchar(20)  NULL,
    ins_dt          timestamp    NULL DEFAULT now(),
    upd_id          varchar(20)  NULL,
    upd_dt          timestamp    NULL,
    CONSTRAINT ux_tbl_personal_hygiene_row UNIQUE (hdr_idx, row_seq)
);
COMMENT ON TABLE  tbl_personal_hygiene_row                 IS '작업자별 개인위생 점검 결과 — 어제 명단 복사 후 판정만 입력하는 흐름';
COMMENT ON COLUMN tbl_personal_hygiene_row.idx             IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_personal_hygiene_row.co_cd           IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_personal_hygiene_row.hdr_idx         IS '헤더 idx — tbl_personal_hygiene.idx';
COMMENT ON COLUMN tbl_personal_hygiene_row.row_seq         IS '행 순번';
COMMENT ON COLUMN tbl_personal_hygiene_row.worker_user_id  IS '작업자 로그인 ID — 시스템 사용자가 아닌 작업자는 NULL';
COMMENT ON COLUMN tbl_personal_hygiene_row.worker_nm       IS '작업자명';
COMMENT ON COLUMN tbl_personal_hygiene_row.health_cd       IS '건강상태 판정 — O:양호, X:불량. 설사·발열·화농성 질환 여부';
COMMENT ON COLUMN tbl_personal_hygiene_row.cloth_cd        IS '위생복장 판정 — O:양호, X:불량. 위생복·위생모·마스크·장화';
COMMENT ON COLUMN tbl_personal_hygiene_row.belongings_cd   IS '장신구 판정 — O:양호, X:불량. 반지·시계·목걸이 제거 여부';
COMMENT ON COLUMN tbl_personal_hygiene_row.worker_state_cd IS '작업자 상태 판정 — O:양호, X:불량. 두발·손톱·화장 상태';
COMMENT ON COLUMN tbl_personal_hygiene_row.anteroom_cd     IS '전실 통과 판정 — O:양호, X:불량. 에어샤워·소독발판 이용';
COMMENT ON COLUMN tbl_personal_hygiene_row.handwash_cd     IS '손 세척·소독 판정 — O:양호, X:불량';
COMMENT ON COLUMN tbl_personal_hygiene_row.remark          IS '비고 — 불량 시 조치 내용 요약';
COMMENT ON COLUMN tbl_personal_hygiene_row.ins_id          IS '최초입력자 ID';
COMMENT ON COLUMN tbl_personal_hygiene_row.ins_dt          IS '최초입력일시';
COMMENT ON COLUMN tbl_personal_hygiene_row.upd_id          IS '최종수정자 ID';
COMMENT ON COLUMN tbl_personal_hygiene_row.upd_dt          IS '최종수정일시';

-- ------------------------------------------------------------
-- 7-1. tbl_area_hygiene — 작업장 환경위생관리 점검표 (헤더)
--      원본 양식의 점검결과 열은 작업장이 아니라 날짜 5칸이다.
--      한 문서가 기간을 담고 일자별로 판정한다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_area_hygiene (
    idx        bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd      varchar(10) NOT NULL,
    doc_idx    bigint      NOT NULL,
    base_dt    varchar(8)  NOT NULL,
    base_dt_to varchar(8)  NULL,
    area_cd    varchar(30) NULL,
    checker_id varchar(20) NULL,
    checker_nm varchar(50) NULL,
    ins_id     varchar(20) NULL,
    ins_dt     timestamp   NULL DEFAULT now(),
    upd_id     varchar(20) NULL,
    upd_dt     timestamp   NULL,
    CONSTRAINT ux_tbl_area_hygiene UNIQUE (doc_idx)
);
COMMENT ON TABLE  tbl_area_hygiene            IS '작업장 환경위생관리 점검표 헤더 — 기간 단위 문서. 일자별 판정은 자식 테이블';
COMMENT ON COLUMN tbl_area_hygiene.idx        IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_area_hygiene.co_cd      IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_area_hygiene.doc_idx    IS '문서 idx — tbl_document.idx와 1:1';
COMMENT ON COLUMN tbl_area_hygiene.base_dt    IS '기간 시작일 YYYYMMDD';
COMMENT ON COLUMN tbl_area_hygiene.base_dt_to IS '기간 종료일 YYYYMMDD';
COMMENT ON COLUMN tbl_area_hygiene.area_cd    IS '대상 구역코드 — tbl_work_area.area_cd. 구역을 나눠 작성할 때만 지정하고 NULL이면(= 전체 작업장 1장)';
COMMENT ON COLUMN tbl_area_hygiene.checker_id IS '점검자 로그인 ID';
COMMENT ON COLUMN tbl_area_hygiene.checker_nm IS '점검자명 — 작성 시점 스냅샷';
COMMENT ON COLUMN tbl_area_hygiene.ins_id     IS '최초입력자 ID';
COMMENT ON COLUMN tbl_area_hygiene.ins_dt     IS '최초입력일시';
COMMENT ON COLUMN tbl_area_hygiene.upd_id     IS '최종수정자 ID';
COMMENT ON COLUMN tbl_area_hygiene.upd_dt     IS '최종수정일시';

-- ------------------------------------------------------------
-- 7-2. tbl_area_hygiene_item — 점검항목 (행)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_area_hygiene_item (
    idx     bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd   varchar(10)  NOT NULL,
    hdr_idx bigint       NOT NULL,
    row_seq int          NOT NULL,
    item_cd varchar(20)  NOT NULL,
    item_nm varchar(500) NULL,
    remark  varchar(500) NULL,
    ins_id  varchar(20)  NULL,
    ins_dt  timestamp    NULL DEFAULT now(),
    upd_id  varchar(20)  NULL,
    upd_dt  timestamp    NULL,
    CONSTRAINT ux_tbl_area_hygiene_item UNIQUE (hdr_idx, row_seq)
);
COMMENT ON TABLE  tbl_area_hygiene_item         IS '작업장 환경위생 점검항목 — 바닥·벽면·천정·배수로 등 15항목. 일자별 판정은 자식 테이블';
COMMENT ON COLUMN tbl_area_hygiene_item.idx     IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_area_hygiene_item.co_cd   IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_area_hygiene_item.hdr_idx IS '헤더 idx — tbl_area_hygiene.idx';
COMMENT ON COLUMN tbl_area_hygiene_item.row_seq IS '행 순번';
COMMENT ON COLUMN tbl_area_hygiene_item.item_cd IS '항목코드 — tbl_check_item.item_cd';
COMMENT ON COLUMN tbl_area_hygiene_item.item_nm IS '항목 문구 스냅샷';
COMMENT ON COLUMN tbl_area_hygiene_item.remark  IS '비고';
COMMENT ON COLUMN tbl_area_hygiene_item.ins_id  IS '최초입력자 ID';
COMMENT ON COLUMN tbl_area_hygiene_item.ins_dt  IS '최초입력일시';
COMMENT ON COLUMN tbl_area_hygiene_item.upd_id  IS '최종수정자 ID';
COMMENT ON COLUMN tbl_area_hygiene_item.upd_dt  IS '최종수정일시';

-- ------------------------------------------------------------
-- 7-3. tbl_area_hygiene_result — 일자별 판정 (세로 정규화)
--      원본 양식의 점검결과 날짜 5칸을 행으로 관리한다. 칸 수 제한 없이 확장 가능
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_area_hygiene_result (
    idx      bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd    varchar(10) NOT NULL,
    item_idx bigint      NOT NULL,
    check_dt varchar(8)  NOT NULL,
    judge_cd varchar(1)  NULL,
    ins_id   varchar(20) NULL,
    ins_dt   timestamp   NULL DEFAULT now(),
    upd_id   varchar(20) NULL,
    upd_dt   timestamp   NULL,
    CONSTRAINT ux_tbl_area_hygiene_result UNIQUE (item_idx, check_dt)
);
COMMENT ON TABLE  tbl_area_hygiene_result          IS '작업장 환경위생 일자별 판정 — A4 표의 날짜 열을 세로 정규화';
COMMENT ON COLUMN tbl_area_hygiene_result.idx      IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_area_hygiene_result.co_cd    IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_area_hygiene_result.item_idx IS '점검항목 idx — tbl_area_hygiene_item.idx';
COMMENT ON COLUMN tbl_area_hygiene_result.check_dt IS '점검일자 YYYYMMDD — 화면 열 머리글의 근거';
COMMENT ON COLUMN tbl_area_hygiene_result.judge_cd IS '판정 — O:양호, X:불량';
COMMENT ON COLUMN tbl_area_hygiene_result.ins_id   IS '최초입력자 ID';
COMMENT ON COLUMN tbl_area_hygiene_result.ins_dt   IS '최초입력일시';
COMMENT ON COLUMN tbl_area_hygiene_result.upd_id   IS '최종수정자 ID';
COMMENT ON COLUMN tbl_area_hygiene_result.upd_dt   IS '최종수정일시';

-- ------------------------------------------------------------
-- 7-4. tbl_area_hygiene_signer — 일자별 작성·검토·승인자
--      원본 양식 하단의 작성/검토/승인 3행이 날짜 열마다 반복된다.
--      문서 전체 결재(tbl_document_approval)와는 별개인 현장 서명이다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_area_hygiene_signer (
    idx         bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd       varchar(10) NOT NULL,
    hdr_idx     bigint      NOT NULL,
    check_dt    varchar(8)  NOT NULL,
    writer_nm   varchar(50) NULL,
    reviewer_nm varchar(50) NULL,
    approver_nm varchar(50) NULL,
    ins_id      varchar(20) NULL,
    ins_dt      timestamp   NULL DEFAULT now(),
    upd_id      varchar(20) NULL,
    upd_dt      timestamp   NULL,
    CONSTRAINT ux_tbl_area_hygiene_signer UNIQUE (hdr_idx, check_dt)
);
COMMENT ON TABLE  tbl_area_hygiene_signer             IS '작업장 환경위생 일자별 서명 — 양식 하단 작성/검토/승인 3행';
COMMENT ON COLUMN tbl_area_hygiene_signer.idx         IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_area_hygiene_signer.co_cd       IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_area_hygiene_signer.hdr_idx     IS '헤더 idx — tbl_area_hygiene.idx';
COMMENT ON COLUMN tbl_area_hygiene_signer.check_dt    IS '점검일자 YYYYMMDD';
COMMENT ON COLUMN tbl_area_hygiene_signer.writer_nm   IS '작성자명 — 현장 서명란 표기';
COMMENT ON COLUMN tbl_area_hygiene_signer.reviewer_nm IS '검토자명 — 현장 서명란 표기';
COMMENT ON COLUMN tbl_area_hygiene_signer.approver_nm IS '승인자명 — 현장 서명란 표기';
COMMENT ON COLUMN tbl_area_hygiene_signer.ins_id      IS '최초입력자 ID';
COMMENT ON COLUMN tbl_area_hygiene_signer.ins_dt      IS '최초입력일시';
COMMENT ON COLUMN tbl_area_hygiene_signer.upd_id      IS '최종수정자 ID';
COMMENT ON COLUMN tbl_area_hygiene_signer.upd_dt      IS '최종수정일시';

-- ------------------------------------------------------------
-- 8-1. tbl_pest_check — 방충·방서 점검표 (헤더)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_pest_check (
    idx        bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd      varchar(10) NOT NULL,
    doc_idx    bigint      NOT NULL,
    base_dt    varchar(8)  NOT NULL,
    checker_id varchar(20) NULL,
    checker_nm varchar(50) NULL,
    ins_id     varchar(20) NULL,
    ins_dt     timestamp   NULL DEFAULT now(),
    upd_id     varchar(20) NULL,
    upd_dt     timestamp   NULL,
    CONSTRAINT ux_tbl_pest_check UNIQUE (doc_idx)
);
COMMENT ON TABLE  tbl_pest_check            IS '방충·방서 점검표 헤더 — 원본 양식 13번. 주 1회 작성';
COMMENT ON COLUMN tbl_pest_check.idx        IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_pest_check.co_cd      IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_pest_check.doc_idx    IS '문서 idx — tbl_document.idx와 1:1';
COMMENT ON COLUMN tbl_pest_check.base_dt    IS '작성일 YYYYMMDD';
COMMENT ON COLUMN tbl_pest_check.checker_id IS '작성자 로그인 ID';
COMMENT ON COLUMN tbl_pest_check.checker_nm IS '작성자명 — 작성 시점 스냅샷';
COMMENT ON COLUMN tbl_pest_check.ins_id     IS '최초입력자 ID';
COMMENT ON COLUMN tbl_pest_check.ins_dt     IS '최초입력일시';
COMMENT ON COLUMN tbl_pest_check.upd_id     IS '최종수정자 ID';
COMMENT ON COLUMN tbl_pest_check.upd_dt     IS '최종수정일시';

-- ------------------------------------------------------------
-- 8-2. tbl_pest_check_row — 설비별 포집 수량
--      비래해충·보행해충·쥐 3분류 소계는 화면과 저장 SP가 자동 계산한다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_pest_check_row (
    idx           bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd         varchar(10)  NOT NULL,
    hdr_idx       bigint       NOT NULL,
    row_seq       int          NOT NULL,
    pest_cd       varchar(30)  NOT NULL,
    pest_nm       varchar(100) NULL,
    place_nm      varchar(100) NULL,
    device_ng_cd  varchar(1)   NULL,
    fly_cnt       int          NULL DEFAULT 0,
    moth_cnt      int          NULL DEFAULT 0,
    mosq_cnt      int          NULL DEFAULT 0,
    midge_cnt     int          NULL DEFAULT 0,
    etc_fly_cnt   int          NULL DEFAULT 0,
    fly_sum       int          NULL DEFAULT 0,
    roach_cnt     int          NULL DEFAULT 0,
    spider_cnt    int          NULL DEFAULT 0,
    ant_cnt       int          NULL DEFAULT 0,
    etc_walk_cnt  int          NULL DEFAULT 0,
    walk_sum      int          NULL DEFAULT 0,
    rat_cnt       int          NULL DEFAULT 0,
    etc_rat_cnt   int          NULL DEFAULT 0,
    rat_sum       int          NULL DEFAULT 0,
    remark        varchar(500) NULL,
    ins_id        varchar(20)  NULL,
    ins_dt        timestamp    NULL DEFAULT now(),
    upd_id        varchar(20)  NULL,
    upd_dt        timestamp    NULL,
    CONSTRAINT ux_tbl_pest_check_row UNIQUE (hdr_idx, row_seq)
);
COMMENT ON TABLE  tbl_pest_check_row              IS '방충방서 설비별 포집 수량 — 행은 tbl_pest_device 등록 대수만큼 자동 생성';
COMMENT ON COLUMN tbl_pest_check_row.idx          IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_pest_check_row.co_cd        IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_pest_check_row.hdr_idx      IS '헤더 idx — tbl_pest_check.idx';
COMMENT ON COLUMN tbl_pest_check_row.row_seq      IS '행 순번';
COMMENT ON COLUMN tbl_pest_check_row.pest_cd      IS '설비 코드 — tbl_pest_device.pest_cd';
COMMENT ON COLUMN tbl_pest_check_row.pest_nm      IS '설비명 스냅샷';
COMMENT ON COLUMN tbl_pest_check_row.place_nm     IS '설치 위치 스냅샷';
COMMENT ON COLUMN tbl_pest_check_row.device_ng_cd IS '설비 이상유무 — O:정상, X:이상';
COMMENT ON COLUMN tbl_pest_check_row.fly_cnt      IS '비래해충 파리 포집수';
COMMENT ON COLUMN tbl_pest_check_row.moth_cnt     IS '비래해충 나방 포집수';
COMMENT ON COLUMN tbl_pest_check_row.mosq_cnt     IS '비래해충 모기 포집수';
COMMENT ON COLUMN tbl_pest_check_row.midge_cnt    IS '비래해충 깔따구 포집수';
COMMENT ON COLUMN tbl_pest_check_row.etc_fly_cnt  IS '비래해충 기타 포집수';
COMMENT ON COLUMN tbl_pest_check_row.fly_sum      IS '비래해충 소계 — 파리+나방+모기+깔따구+기타. 저장 SP가 계산';
COMMENT ON COLUMN tbl_pest_check_row.roach_cnt    IS '보행해충 바퀴 포집수';
COMMENT ON COLUMN tbl_pest_check_row.spider_cnt   IS '보행해충 거미 포집수';
COMMENT ON COLUMN tbl_pest_check_row.ant_cnt      IS '보행해충 개미 포집수';
COMMENT ON COLUMN tbl_pest_check_row.etc_walk_cnt IS '보행해충 기타 포집수';
COMMENT ON COLUMN tbl_pest_check_row.walk_sum     IS '보행해충 소계 — 저장 SP가 계산';
COMMENT ON COLUMN tbl_pest_check_row.rat_cnt      IS '쥐 포획수';
COMMENT ON COLUMN tbl_pest_check_row.etc_rat_cnt  IS '쥐 기타(흔적 등) 수';
COMMENT ON COLUMN tbl_pest_check_row.rat_sum      IS '쥐 소계 — 저장 SP가 계산. 0보다 클 때(= 방서 이탈) 개선조치 안내';
COMMENT ON COLUMN tbl_pest_check_row.remark       IS '비고';
COMMENT ON COLUMN tbl_pest_check_row.ins_id       IS '최초입력자 ID';
COMMENT ON COLUMN tbl_pest_check_row.ins_dt       IS '최초입력일시';
COMMENT ON COLUMN tbl_pest_check_row.upd_id       IS '최종수정자 ID';
COMMENT ON COLUMN tbl_pest_check_row.upd_dt       IS '최종수정일시';

-- ------------------------------------------------------------
-- 9-1. tbl_water_check — 용수관리 점검표 (헤더)
--      한 문서가 기간(주로 1개월)을 담고 주차별로 점검한다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_water_check (
    idx        bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd      varchar(10) NOT NULL,
    doc_idx    bigint      NOT NULL,
    base_dt    varchar(8)  NOT NULL,
    base_dt_to varchar(8)  NULL,
    cycle_nm   varchar(50) NULL,
    ins_id     varchar(20) NULL,
    ins_dt     timestamp   NULL DEFAULT now(),
    upd_id     varchar(20) NULL,
    upd_dt     timestamp   NULL,
    CONSTRAINT ux_tbl_water_check UNIQUE (doc_idx)
);
COMMENT ON TABLE  tbl_water_check            IS '용수관리 점검표 헤더 — 표준기준서 관리번호 9. 기간 단위(월) 문서';
COMMENT ON COLUMN tbl_water_check.idx        IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_water_check.co_cd      IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_water_check.doc_idx    IS '문서 idx — tbl_document.idx와 1:1';
COMMENT ON COLUMN tbl_water_check.base_dt    IS '기간 시작일 YYYYMMDD';
COMMENT ON COLUMN tbl_water_check.base_dt_to IS '기간 종료일 YYYYMMDD';
COMMENT ON COLUMN tbl_water_check.cycle_nm   IS '점검주기 표기 문구 — 1회/주 등';
COMMENT ON COLUMN tbl_water_check.ins_id     IS '최초입력자 ID';
COMMENT ON COLUMN tbl_water_check.ins_dt     IS '최초입력일시';
COMMENT ON COLUMN tbl_water_check.upd_id     IS '최종수정자 ID';
COMMENT ON COLUMN tbl_water_check.upd_dt     IS '최종수정일시';

-- ------------------------------------------------------------
-- 9-2. tbl_water_check_item — 점검항목 (행)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_water_check_item (
    idx     bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd   varchar(10)  NOT NULL,
    hdr_idx bigint       NOT NULL,
    row_seq int          NOT NULL,
    grp_cd  varchar(20)  NULL,
    grp_nm  varchar(100) NULL,
    item_cd varchar(20)  NOT NULL,
    item_nm varchar(500) NULL,
    ins_id  varchar(20)  NULL,
    ins_dt  timestamp    NULL DEFAULT now(),
    upd_id  varchar(20)  NULL,
    upd_dt  timestamp    NULL,
    CONSTRAINT ux_tbl_water_check_item UNIQUE (hdr_idx, row_seq)
);
COMMENT ON TABLE  tbl_water_check_item         IS '용수관리 점검항목 — 저장탱크 주변·상부·내부, 배관, 펌프 구분';
COMMENT ON COLUMN tbl_water_check_item.idx     IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_water_check_item.co_cd   IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_water_check_item.hdr_idx IS '헤더 idx — tbl_water_check.idx';
COMMENT ON COLUMN tbl_water_check_item.row_seq IS '행 순번';
COMMENT ON COLUMN tbl_water_check_item.grp_cd  IS '항목 구분코드 — TANK_AROUND:탱크 주변, TANK_TOP:탱크 상부, TANK_IN:탱크 내부, PIPE:배관, PUMP:펌프';
COMMENT ON COLUMN tbl_water_check_item.grp_nm  IS '항목 구분명 — A4 표 좌측 병합 셀';
COMMENT ON COLUMN tbl_water_check_item.item_cd IS '항목코드 — tbl_check_item.item_cd';
COMMENT ON COLUMN tbl_water_check_item.item_nm IS '항목 문구 스냅샷';
COMMENT ON COLUMN tbl_water_check_item.ins_id  IS '최초입력자 ID';
COMMENT ON COLUMN tbl_water_check_item.ins_dt  IS '최초입력일시';
COMMENT ON COLUMN tbl_water_check_item.upd_id  IS '최종수정자 ID';
COMMENT ON COLUMN tbl_water_check_item.upd_dt  IS '최종수정일시';

-- ------------------------------------------------------------
-- 9-3. tbl_water_check_result — 주차별 판정 (세로 정규화)
--      A4 표의 1주~5주 열을 행으로 관리한다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_water_check_result (
    idx      bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd    varchar(10) NOT NULL,
    item_idx bigint      NOT NULL,
    week_no  int         NOT NULL,
    judge_cd varchar(1)  NULL,
    ins_id   varchar(20) NULL,
    ins_dt   timestamp   NULL DEFAULT now(),
    upd_id   varchar(20) NULL,
    upd_dt   timestamp   NULL,
    CONSTRAINT ux_tbl_water_check_result UNIQUE (item_idx, week_no)
);
COMMENT ON TABLE  tbl_water_check_result          IS '용수관리 주차별 판정 — A4 표의 1주~5주 열을 세로 정규화';
COMMENT ON COLUMN tbl_water_check_result.idx      IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_water_check_result.co_cd    IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_water_check_result.item_idx IS '점검항목 idx — tbl_water_check_item.idx';
COMMENT ON COLUMN tbl_water_check_result.week_no  IS '주차 1~5';
COMMENT ON COLUMN tbl_water_check_result.judge_cd IS '판정 — O:양호, X:불량';
COMMENT ON COLUMN tbl_water_check_result.ins_id   IS '최초입력자 ID';
COMMENT ON COLUMN tbl_water_check_result.ins_dt   IS '최초입력일시';
COMMENT ON COLUMN tbl_water_check_result.upd_id   IS '최종수정자 ID';
COMMENT ON COLUMN tbl_water_check_result.upd_dt   IS '최종수정일시';

-- ------------------------------------------------------------
-- 9-4. tbl_water_check_checker — 주차별 점검일자·점검자
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_water_check_checker (
    idx        bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd      varchar(10) NOT NULL,
    hdr_idx    bigint      NOT NULL,
    week_no    int         NOT NULL,
    check_dt   varchar(8)  NULL,
    checker_id varchar(20) NULL,
    checker_nm varchar(50) NULL,
    ins_id     varchar(20) NULL,
    ins_dt     timestamp   NULL DEFAULT now(),
    upd_id     varchar(20) NULL,
    upd_dt     timestamp   NULL,
    CONSTRAINT ux_tbl_water_check_checker UNIQUE (hdr_idx, week_no)
);
COMMENT ON TABLE  tbl_water_check_checker            IS '용수관리 주차별 점검일자·점검자 — A4 표 하단 점검일/점검자 행';
COMMENT ON COLUMN tbl_water_check_checker.idx        IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_water_check_checker.co_cd      IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_water_check_checker.hdr_idx    IS '헤더 idx — tbl_water_check.idx';
COMMENT ON COLUMN tbl_water_check_checker.week_no    IS '주차 1~5';
COMMENT ON COLUMN tbl_water_check_checker.check_dt   IS '실제 점검일자 YYYYMMDD';
COMMENT ON COLUMN tbl_water_check_checker.checker_id IS '점검자 로그인 ID';
COMMENT ON COLUMN tbl_water_check_checker.checker_nm IS '점검자명 — 서명란 표기용 스냅샷';
COMMENT ON COLUMN tbl_water_check_checker.ins_id     IS '최초입력자 ID';
COMMENT ON COLUMN tbl_water_check_checker.ins_dt     IS '최초입력일시';
COMMENT ON COLUMN tbl_water_check_checker.upd_id     IS '최종수정자 ID';
COMMENT ON COLUMN tbl_water_check_checker.upd_dt     IS '최종수정일시';
