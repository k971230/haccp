-- ============================================================
--  DDL 5 — 업무 테이블 (1) 중요관리점·검증  [DB형 4종]
--
--  개발자: 박승우
--  일자: 2026-08-05
--  코멘트:
--    1) 2-1 CCP 냉장보관, 2-2 CCP 금속검출, 3 CCP 검증점검표, 4 연간 검증계획서
--    2) 헤더 1행이 tbl_document.idx(doc_idx)와 1:1로 물린다 — 결재·보존·검색은 문서 허브가 담당
--    3) 이탈내용/개선조치 푸터는 각 테이블에 컬럼을 두지 않고 tbl_corrective_action으로 통일
--
--  가변 열 처리: 보관고 대수가 업체마다 달라 A4 표의 보관고1~5 열을 컬럼으로 두지 않는다.
--                tbl_ccp_cold_monitor_temp 로 세로 정규화하고 화면이 tbl_storage 행 수만큼 열을 그린다.
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1-1. tbl_ccp_cold_monitor — CCP-1B·3B 냉장보관 모니터링 일지 (헤더)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_ccp_cold_monitor (
    idx         bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd       varchar(10) NOT NULL,
    doc_idx     bigint      NOT NULL,
    base_dt     varchar(8)  NOT NULL,
    ccp_cd      varchar(20) NOT NULL,
    mng_user_id varchar(20) NULL,
    mng_nm      varchar(50) NULL,
    ins_id      varchar(20) NULL,
    ins_dt      timestamp   NULL DEFAULT now(),
    upd_id      varchar(20) NULL,
    upd_dt      timestamp   NULL,
    CONSTRAINT ux_tbl_ccp_cold_monitor UNIQUE (doc_idx)
);
COMMENT ON TABLE  tbl_ccp_cold_monitor             IS 'CCP 냉장보관 모니터링 일지 헤더 — 표준기준서 관리번호 2-1';
COMMENT ON COLUMN tbl_ccp_cold_monitor.idx         IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_ccp_cold_monitor.co_cd       IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_ccp_cold_monitor.doc_idx     IS '문서 idx — tbl_document.idx와 1:1';
COMMENT ON COLUMN tbl_ccp_cold_monitor.base_dt     IS '작성일 YYYYMMDD';
COMMENT ON COLUMN tbl_ccp_cold_monitor.ccp_cd      IS '적용 CCP 코드 — tbl_ccp_limit.ccp_cd. 자동판정 기준의 출처';
COMMENT ON COLUMN tbl_ccp_cold_monitor.mng_user_id IS '담당자 로그인 ID';
COMMENT ON COLUMN tbl_ccp_cold_monitor.mng_nm      IS '담당자명 — 작성 시점 스냅샷';
COMMENT ON COLUMN tbl_ccp_cold_monitor.ins_id      IS '최초입력자 ID';
COMMENT ON COLUMN tbl_ccp_cold_monitor.ins_dt      IS '최초입력일시';
COMMENT ON COLUMN tbl_ccp_cold_monitor.upd_id      IS '최종수정자 ID';
COMMENT ON COLUMN tbl_ccp_cold_monitor.upd_dt      IS '최종수정일시';

-- ------------------------------------------------------------
-- 1-2. tbl_ccp_cold_monitor_row — 점검시간별 행
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_ccp_cold_monitor_row (
    idx         bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd       varchar(10) NOT NULL,
    hdr_idx     bigint      NOT NULL,
    row_seq     int         NOT NULL,
    check_time  varchar(4)  NOT NULL,
    judge_cd    varchar(1)  NULL,
    judge_mod_yn varchar(1) NOT NULL DEFAULT 'N',
    checker_id  varchar(20) NULL,
    checker_nm  varchar(50) NULL,
    ins_id      varchar(20) NULL,
    ins_dt      timestamp   NULL DEFAULT now(),
    upd_id      varchar(20) NULL,
    upd_dt      timestamp   NULL,
    CONSTRAINT ux_tbl_ccp_cold_monitor_row UNIQUE (hdr_idx, row_seq)
);
COMMENT ON TABLE  tbl_ccp_cold_monitor_row              IS 'CCP 냉장보관 점검시간별 행 — A4 표의 가로 1줄';
COMMENT ON COLUMN tbl_ccp_cold_monitor_row.idx          IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_ccp_cold_monitor_row.co_cd        IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_ccp_cold_monitor_row.hdr_idx      IS '헤더 idx — tbl_ccp_cold_monitor.idx';
COMMENT ON COLUMN tbl_ccp_cold_monitor_row.row_seq      IS '행 순번 — 1부터. A4 표의 위에서 아래 순서';
COMMENT ON COLUMN tbl_ccp_cold_monitor_row.check_time   IS '점검시간 HHMM — 작업 시작, 2시간 간격, 작업 종료';
COMMENT ON COLUMN tbl_ccp_cold_monitor_row.judge_cd     IS '행 판정 — P:적합, F:부적합. 보관고 온도 중 하나라도 이탈이면 F로 확정';
COMMENT ON COLUMN tbl_ccp_cold_monitor_row.judge_mod_yn IS '판정 수동변경 여부 Y/N — Y일 때(= 사용자가 자동판정을 바꿈) 사유가 tbl_audit_log에 남는다';
COMMENT ON COLUMN tbl_ccp_cold_monitor_row.checker_id   IS '점검자 로그인 ID';
COMMENT ON COLUMN tbl_ccp_cold_monitor_row.checker_nm   IS '점검자명 — 서명란 표기용 스냅샷';
COMMENT ON COLUMN tbl_ccp_cold_monitor_row.ins_id       IS '최초입력자 ID';
COMMENT ON COLUMN tbl_ccp_cold_monitor_row.ins_dt       IS '최초입력일시';
COMMENT ON COLUMN tbl_ccp_cold_monitor_row.upd_id       IS '최종수정자 ID';
COMMENT ON COLUMN tbl_ccp_cold_monitor_row.upd_dt       IS '최종수정일시';

-- ------------------------------------------------------------
-- 1-3. tbl_ccp_cold_monitor_temp — 보관고별 온도 (세로 정규화)
--      보관고 대수가 업체마다 달라 컬럼이 아니라 행으로 관리한다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_ccp_cold_monitor_temp (
    idx        bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd      varchar(10)  NOT NULL,
    row_idx    bigint       NOT NULL,
    storage_cd varchar(30)  NOT NULL,
    temp_val   numeric(5,1) NULL,
    judge_cd   varchar(1)   NULL,
    ins_id     varchar(20)  NULL,
    ins_dt     timestamp    NULL DEFAULT now(),
    upd_id     varchar(20)  NULL,
    upd_dt     timestamp    NULL,
    CONSTRAINT ux_tbl_ccp_cold_monitor_temp UNIQUE (row_idx, storage_cd)
);
COMMENT ON TABLE  tbl_ccp_cold_monitor_temp            IS 'CCP 냉장보관 보관고별 온도 — A4 표의 보관고1~5 열을 세로 정규화한 결과';
COMMENT ON COLUMN tbl_ccp_cold_monitor_temp.idx        IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_ccp_cold_monitor_temp.co_cd      IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_ccp_cold_monitor_temp.row_idx    IS '점검행 idx — tbl_ccp_cold_monitor_row.idx';
COMMENT ON COLUMN tbl_ccp_cold_monitor_temp.storage_cd IS '보관고 코드 — tbl_storage.storage_cd. 화면 열 머리글의 근거';
COMMENT ON COLUMN tbl_ccp_cold_monitor_temp.temp_val   IS '측정 온도(섭씨) — 소수 1자리';
COMMENT ON COLUMN tbl_ccp_cold_monitor_temp.judge_cd   IS '셀 판정 — P:적합, F:부적합. 저장 SP가 tbl_ccp_limit 범위와 비교해 확정';
COMMENT ON COLUMN tbl_ccp_cold_monitor_temp.ins_id     IS '최초입력자 ID';
COMMENT ON COLUMN tbl_ccp_cold_monitor_temp.ins_dt     IS '최초입력일시';
COMMENT ON COLUMN tbl_ccp_cold_monitor_temp.upd_id     IS '최종수정자 ID';
COMMENT ON COLUMN tbl_ccp_cold_monitor_temp.upd_dt     IS '최종수정일시';

-- ------------------------------------------------------------
-- 2-1. tbl_ccp_metal_monitor — CCP-2P 금속검출 모니터링 일지 (헤더)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_ccp_metal_monitor (
    idx         bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd       varchar(10)  NOT NULL,
    doc_idx     bigint       NOT NULL,
    base_dt     varchar(8)   NOT NULL,
    ccp_cd      varchar(20)  NOT NULL,
    fe_size     numeric(4,1) NULL,
    sts_size    numeric(4,1) NULL,
    mng_user_id varchar(20)  NULL,
    mng_nm      varchar(50)  NULL,
    ins_id      varchar(20)  NULL,
    ins_dt      timestamp    NULL DEFAULT now(),
    upd_id      varchar(20)  NULL,
    upd_dt      timestamp    NULL,
    CONSTRAINT ux_tbl_ccp_metal_monitor UNIQUE (doc_idx)
);
COMMENT ON TABLE  tbl_ccp_metal_monitor             IS 'CCP 금속검출 모니터링 일지 헤더 — 표준기준서 관리번호 2-2';
COMMENT ON COLUMN tbl_ccp_metal_monitor.idx         IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_ccp_metal_monitor.co_cd       IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_ccp_metal_monitor.doc_idx     IS '문서 idx — tbl_document.idx와 1:1';
COMMENT ON COLUMN tbl_ccp_metal_monitor.base_dt     IS '작성일 YYYYMMDD';
COMMENT ON COLUMN tbl_ccp_metal_monitor.ccp_cd      IS '적용 CCP 코드 — tbl_ccp_limit.ccp_cd';
COMMENT ON COLUMN tbl_ccp_metal_monitor.fe_size     IS 'Fe 시편 규격(mm) — 작성 시점 한계기준 스냅샷. A4 한계기준란에 출력';
COMMENT ON COLUMN tbl_ccp_metal_monitor.sts_size    IS 'STS 시편 규격(mm) — 작성 시점 한계기준 스냅샷';
COMMENT ON COLUMN tbl_ccp_metal_monitor.mng_user_id IS '담당자 로그인 ID';
COMMENT ON COLUMN tbl_ccp_metal_monitor.mng_nm      IS '담당자명 — 작성 시점 스냅샷';
COMMENT ON COLUMN tbl_ccp_metal_monitor.ins_id      IS '최초입력자 ID';
COMMENT ON COLUMN tbl_ccp_metal_monitor.ins_dt      IS '최초입력일시';
COMMENT ON COLUMN tbl_ccp_metal_monitor.upd_id      IS '최종수정자 ID';
COMMENT ON COLUMN tbl_ccp_metal_monitor.upd_dt      IS '최종수정일시';

-- ------------------------------------------------------------
-- 2-2. tbl_ccp_metal_sens_row — 금속검출기 감도 모니터링 행
--      판정 표기: 검출 O, 불검출 X. 5개 시험이 모두 검출(O)이어야 적합
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_ccp_metal_sens_row (
    idx          bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd        varchar(10)  NOT NULL,
    hdr_idx      bigint       NOT NULL,
    row_seq      int          NOT NULL,
    phase_cd     varchar(10)  NOT NULL,
    product_cd   varchar(30)  NULL,
    product_nm   varchar(200) NULL,
    check_time   varchar(4)   NULL,
    fe_only_cd   varchar(1)   NULL,
    sts_only_cd  varchar(1)   NULL,
    prod_only_cd varchar(1)   NULL,
    fe_prod_cd   varchar(1)   NULL,
    sts_prod_cd  varchar(1)   NULL,
    judge_cd     varchar(1)   NULL,
    judge_mod_yn varchar(1)   NOT NULL DEFAULT 'N',
    checker_id   varchar(20)  NULL,
    checker_nm   varchar(50)  NULL,
    ins_id       varchar(20)  NULL,
    ins_dt       timestamp    NULL DEFAULT now(),
    upd_id       varchar(20)  NULL,
    upd_dt       timestamp    NULL,
    CONSTRAINT ux_tbl_ccp_metal_sens_row UNIQUE (hdr_idx, row_seq)
);
COMMENT ON TABLE  tbl_ccp_metal_sens_row              IS '금속검출기 감도 모니터링 행 — 시편 통과 시험 결과';
COMMENT ON COLUMN tbl_ccp_metal_sens_row.idx          IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_ccp_metal_sens_row.co_cd        IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_ccp_metal_sens_row.hdr_idx      IS '헤더 idx — tbl_ccp_metal_monitor.idx';
COMMENT ON COLUMN tbl_ccp_metal_sens_row.row_seq      IS '행 순번';
COMMENT ON COLUMN tbl_ccp_metal_sens_row.phase_cd     IS '점검 시점 — BEFORE:작업 전, DURING:작업 중, AFTER:작업 후';
COMMENT ON COLUMN tbl_ccp_metal_sens_row.product_cd   IS '제품코드 — tbl_product.product_cd';
COMMENT ON COLUMN tbl_ccp_metal_sens_row.product_nm   IS '품명 — 작성 시점 스냅샷';
COMMENT ON COLUMN tbl_ccp_metal_sens_row.check_time   IS '점검시간 HHMM';
COMMENT ON COLUMN tbl_ccp_metal_sens_row.fe_only_cd   IS 'Fe 시편만 통과 결과 — O:검출, X:불검출';
COMMENT ON COLUMN tbl_ccp_metal_sens_row.sts_only_cd  IS 'STS 시편만 통과 결과 — O:검출, X:불검출';
COMMENT ON COLUMN tbl_ccp_metal_sens_row.prod_only_cd IS '제품만 통과 결과 — O:검출, X:불검출. 정상이면 X(미검출)여야 한다';
COMMENT ON COLUMN tbl_ccp_metal_sens_row.fe_prod_cd   IS 'Fe 시편 + 제품 통과 결과 — O:검출, X:불검출';
COMMENT ON COLUMN tbl_ccp_metal_sens_row.sts_prod_cd  IS 'STS 시편 + 제품 통과 결과 — O:검출, X:불검출';
COMMENT ON COLUMN tbl_ccp_metal_sens_row.judge_cd     IS '행 판정 — P:적합, F:부적합. 시편 시험 4종이 모두 검출(O)이면 적합';
COMMENT ON COLUMN tbl_ccp_metal_sens_row.judge_mod_yn IS '판정 수동변경 여부 Y/N';
COMMENT ON COLUMN tbl_ccp_metal_sens_row.checker_id   IS '점검자 로그인 ID';
COMMENT ON COLUMN tbl_ccp_metal_sens_row.checker_nm   IS '점검자명 — 서명란 표기용 스냅샷';
COMMENT ON COLUMN tbl_ccp_metal_sens_row.ins_id       IS '최초입력자 ID';
COMMENT ON COLUMN tbl_ccp_metal_sens_row.ins_dt       IS '최초입력일시';
COMMENT ON COLUMN tbl_ccp_metal_sens_row.upd_id       IS '최종수정자 ID';
COMMENT ON COLUMN tbl_ccp_metal_sens_row.upd_dt       IS '최종수정일시';

-- ------------------------------------------------------------
-- 2-3. tbl_ccp_metal_pass_row — 금속검출기 제품 통과 실적
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_ccp_metal_pass_row (
    idx        bigint         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd      varchar(10)    NOT NULL,
    hdr_idx    bigint         NOT NULL,
    row_seq    int            NOT NULL,
    product_cd varchar(30)    NULL,
    product_nm varchar(200)   NULL,
    pass_qty   numeric(15,3)  NULL,
    detect_qty numeric(15,3)  NULL,
    unit_nm    varchar(20)    NULL,
    remark     varchar(500)   NULL,
    ins_id     varchar(20)    NULL,
    ins_dt     timestamp      NULL DEFAULT now(),
    upd_id     varchar(20)    NULL,
    upd_dt     timestamp      NULL,
    CONSTRAINT ux_tbl_ccp_metal_pass_row UNIQUE (hdr_idx, row_seq)
);
COMMENT ON TABLE  tbl_ccp_metal_pass_row            IS '금속검출기 제품 통과 실적 — 통과량·검출량 기록';
COMMENT ON COLUMN tbl_ccp_metal_pass_row.idx        IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_ccp_metal_pass_row.co_cd      IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_ccp_metal_pass_row.hdr_idx    IS '헤더 idx — tbl_ccp_metal_monitor.idx';
COMMENT ON COLUMN tbl_ccp_metal_pass_row.row_seq    IS '행 순번';
COMMENT ON COLUMN tbl_ccp_metal_pass_row.product_cd IS '제품코드 — tbl_product.product_cd';
COMMENT ON COLUMN tbl_ccp_metal_pass_row.product_nm IS '품명 — 작성 시점 스냅샷';
COMMENT ON COLUMN tbl_ccp_metal_pass_row.pass_qty   IS '통과량 — 금속검출기를 통과한 제품 수량';
COMMENT ON COLUMN tbl_ccp_metal_pass_row.detect_qty IS '검출량 — 금속이 검출되어 배출된 수량. 0보다 클 때(= 이탈 발생) 개선조치 필수';
COMMENT ON COLUMN tbl_ccp_metal_pass_row.unit_nm    IS '단위';
COMMENT ON COLUMN tbl_ccp_metal_pass_row.remark     IS '특이사항';
COMMENT ON COLUMN tbl_ccp_metal_pass_row.ins_id     IS '최초입력자 ID';
COMMENT ON COLUMN tbl_ccp_metal_pass_row.ins_dt     IS '최초입력일시';
COMMENT ON COLUMN tbl_ccp_metal_pass_row.upd_id     IS '최종수정자 ID';
COMMENT ON COLUMN tbl_ccp_metal_pass_row.upd_dt     IS '최종수정일시';

-- ------------------------------------------------------------
-- 3-1. tbl_ccp_verify_check — 중요관리점(CCP) 검증점검표 (헤더)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_ccp_verify_check (
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
    CONSTRAINT ux_tbl_ccp_verify_check UNIQUE (doc_idx)
);
COMMENT ON TABLE  tbl_ccp_verify_check            IS 'CCP 검증점검표 헤더 — 표준기준서 관리번호 3. 월 1회 작성';
COMMENT ON COLUMN tbl_ccp_verify_check.idx        IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_ccp_verify_check.co_cd      IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_ccp_verify_check.doc_idx    IS '문서 idx — tbl_document.idx와 1:1';
COMMENT ON COLUMN tbl_ccp_verify_check.base_dt    IS '점검일자 YYYYMMDD';
COMMENT ON COLUMN tbl_ccp_verify_check.checker_id IS '점검자 로그인 ID';
COMMENT ON COLUMN tbl_ccp_verify_check.checker_nm IS '점검자명 — 작성 시점 스냅샷';
COMMENT ON COLUMN tbl_ccp_verify_check.ins_id     IS '최초입력자 ID';
COMMENT ON COLUMN tbl_ccp_verify_check.ins_dt     IS '최초입력일시';
COMMENT ON COLUMN tbl_ccp_verify_check.upd_id     IS '최종수정자 ID';
COMMENT ON COLUMN tbl_ccp_verify_check.upd_dt     IS '최종수정일시';

-- ------------------------------------------------------------
-- 3-2. tbl_ccp_verify_item — 검증 항목별 결과
--      모니터링 일지 확인 항목은 ref_* 컬럼으로 CCP 일지 건수를 자동 조회해 채운다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_ccp_verify_item (
    idx          bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd        varchar(10)  NOT NULL,
    hdr_idx      bigint       NOT NULL,
    row_seq      int          NOT NULL,
    proc_cd      varchar(20)  NULL,
    proc_nm      varchar(100) NULL,
    item_cd      varchar(20)  NULL,
    verify_desc  varchar(500) NOT NULL,
    answer_cd    varchar(1)   NULL,
    record_desc  varchar(500) NULL,
    ref_tmpl_cd  varchar(20)  NULL,
    ref_from_dt  varchar(8)   NULL,
    ref_to_dt    varchar(8)   NULL,
    ref_total_cnt int         NULL,
    ref_ok_cnt   int          NULL,
    ref_ng_cnt   int          NULL,
    ins_id       varchar(20)  NULL,
    ins_dt       timestamp    NULL DEFAULT now(),
    upd_id       varchar(20)  NULL,
    upd_dt       timestamp    NULL,
    CONSTRAINT ux_tbl_ccp_verify_item UNIQUE (hdr_idx, row_seq)
);
COMMENT ON TABLE  tbl_ccp_verify_item               IS 'CCP 검증 항목별 결과 — 예/아니오 응답과 근거 기록. 일지 건수는 자동 집계';
COMMENT ON COLUMN tbl_ccp_verify_item.idx           IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_ccp_verify_item.co_cd         IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_ccp_verify_item.hdr_idx       IS '헤더 idx — tbl_ccp_verify_check.idx';
COMMENT ON COLUMN tbl_ccp_verify_item.row_seq       IS '행 순번';
COMMENT ON COLUMN tbl_ccp_verify_item.proc_cd       IS '공정 코드 — 원료육 냉장보관, 금속검출, 완제품 냉장보관';
COMMENT ON COLUMN tbl_ccp_verify_item.proc_nm       IS '공정명 — A4 표 좌측 병합 셀';
COMMENT ON COLUMN tbl_ccp_verify_item.item_cd       IS '항목코드 — tbl_check_item.item_cd';
COMMENT ON COLUMN tbl_ccp_verify_item.verify_desc   IS '검증 내용 — 표준기준서 질문 문구';
COMMENT ON COLUMN tbl_ccp_verify_item.answer_cd     IS '응답 — Y:예, N:아니오. N일 때(= 미준수) 개선조치 필수';
COMMENT ON COLUMN tbl_ccp_verify_item.record_desc   IS '기록 내용 — 확인 근거 서술. 자동 집계 항목은 SP가 문구를 생성해 채운다';
COMMENT ON COLUMN tbl_ccp_verify_item.ref_tmpl_cd   IS '자동 집계 대상 템플릿 코드 — CCP_COLD, CCP_METAL 등. NULL이면(= 수동 입력 항목)';
COMMENT ON COLUMN tbl_ccp_verify_item.ref_from_dt   IS '집계 시작일 YYYYMMDD';
COMMENT ON COLUMN tbl_ccp_verify_item.ref_to_dt     IS '집계 종료일 YYYYMMDD';
COMMENT ON COLUMN tbl_ccp_verify_item.ref_total_cnt IS '집계 결과 총 작성 건수';
COMMENT ON COLUMN tbl_ccp_verify_item.ref_ok_cnt    IS '집계 결과 정상 건수';
COMMENT ON COLUMN tbl_ccp_verify_item.ref_ng_cnt    IS '집계 결과 이탈 건수';
COMMENT ON COLUMN tbl_ccp_verify_item.ins_id        IS '최초입력자 ID';
COMMENT ON COLUMN tbl_ccp_verify_item.ins_dt        IS '최초입력일시';
COMMENT ON COLUMN tbl_ccp_verify_item.upd_id        IS '최종수정자 ID';
COMMENT ON COLUMN tbl_ccp_verify_item.upd_dt        IS '최종수정일시';

-- ------------------------------------------------------------
-- 4-1. tbl_verify_plan — 연간 검증계획서 (헤더)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_verify_plan (
    idx        bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd      varchar(10) NOT NULL,
    doc_idx    bigint      NOT NULL,
    plan_year  varchar(4)  NOT NULL,
    dept_cd    varchar(20) NULL,
    checker_id varchar(20) NULL,
    confirm_id varchar(20) NULL,
    ins_id     varchar(20) NULL,
    ins_dt     timestamp   NULL DEFAULT now(),
    upd_id     varchar(20) NULL,
    upd_dt     timestamp   NULL,
    CONSTRAINT ux_tbl_verify_plan UNIQUE (doc_idx)
);
COMMENT ON TABLE  tbl_verify_plan            IS '연간 검증계획서 헤더 — 표준기준서 관리번호 4. 연 1회 작성';
COMMENT ON COLUMN tbl_verify_plan.idx        IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_verify_plan.co_cd      IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_verify_plan.doc_idx    IS '문서 idx — tbl_document.idx와 1:1';
COMMENT ON COLUMN tbl_verify_plan.plan_year  IS '계획연도 YYYY';
COMMENT ON COLUMN tbl_verify_plan.dept_cd    IS '작성 부서코드';
COMMENT ON COLUMN tbl_verify_plan.checker_id IS '점검자 로그인 ID';
COMMENT ON COLUMN tbl_verify_plan.confirm_id IS '확인자 로그인 ID';
COMMENT ON COLUMN tbl_verify_plan.ins_id     IS '최초입력자 ID';
COMMENT ON COLUMN tbl_verify_plan.ins_dt     IS '최초입력일시';
COMMENT ON COLUMN tbl_verify_plan.upd_id     IS '최종수정자 ID';
COMMENT ON COLUMN tbl_verify_plan.upd_dt     IS '최종수정일시';

-- ------------------------------------------------------------
-- 4-2. tbl_verify_plan_item — 검증 대상 항목
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_verify_plan_item (
    idx           bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd         varchar(10)  NOT NULL,
    hdr_idx       bigint       NOT NULL,
    row_seq       int          NOT NULL,
    verify_target varchar(300) NOT NULL,
    verify_method varchar(200) NULL,
    ref_tmpl_cd   varchar(20)  NULL,
    ins_id        varchar(20)  NULL,
    ins_dt        timestamp    NULL DEFAULT now(),
    upd_id        varchar(20)  NULL,
    upd_dt        timestamp    NULL,
    CONSTRAINT ux_tbl_verify_plan_item UNIQUE (hdr_idx, row_seq)
);
COMMENT ON TABLE  tbl_verify_plan_item               IS '연간 검증계획 대상 항목 — 원본 양식은 검증대상·검증방법·1~12월 3영역뿐이다';
COMMENT ON COLUMN tbl_verify_plan_item.idx           IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_verify_plan_item.co_cd         IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_verify_plan_item.hdr_idx       IS '헤더 idx — tbl_verify_plan.idx';
COMMENT ON COLUMN tbl_verify_plan_item.row_seq       IS '행 순번';
COMMENT ON COLUMN tbl_verify_plan_item.verify_target IS '검증대상 — CCP 모니터링 기록, 선행요건 점검표 등';
COMMENT ON COLUMN tbl_verify_plan_item.verify_method IS '검증방법 — 기록확인, 현장확인, 시험검사';
COMMENT ON COLUMN tbl_verify_plan_item.ref_tmpl_cd   IS '연결 템플릿 코드 — 값이 있을 때(= 실적 자동 판정 가능) 해당 양식 승인 문서로 done_yn을 채운다';
COMMENT ON COLUMN tbl_verify_plan_item.ins_id        IS '최초입력자 ID';
COMMENT ON COLUMN tbl_verify_plan_item.ins_dt        IS '최초입력일시';
COMMENT ON COLUMN tbl_verify_plan_item.upd_id        IS '최종수정자 ID';
COMMENT ON COLUMN tbl_verify_plan_item.upd_dt        IS '최종수정일시';

-- ------------------------------------------------------------
-- 4-3. tbl_verify_plan_month — 항목별 월 계획·실적
--      A4 표의 1월~12월 열 12개를 세로 정규화. 실적(done_yn)으로 완료 여부를 대시보드에 표시
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_verify_plan_month (
    idx          bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd        varchar(10) NOT NULL,
    item_idx     bigint      NOT NULL,
    month_no     int         NOT NULL,
    plan_yn      varchar(1)  NOT NULL DEFAULT 'N',
    done_yn      varchar(1)  NOT NULL DEFAULT 'N',
    done_doc_idx bigint      NULL,
    done_dt      varchar(8)  NULL,
    ins_id       varchar(20) NULL,
    ins_dt       timestamp   NULL DEFAULT now(),
    upd_id       varchar(20) NULL,
    upd_dt       timestamp   NULL,
    CONSTRAINT ux_tbl_verify_plan_month UNIQUE (item_idx, month_no)
);
COMMENT ON TABLE  tbl_verify_plan_month              IS '검증계획 월별 계획·실적 — A4 표의 1월~12월 열을 세로 정규화';
COMMENT ON COLUMN tbl_verify_plan_month.idx          IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_verify_plan_month.co_cd        IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_verify_plan_month.item_idx     IS '검증항목 idx — tbl_verify_plan_item.idx';
COMMENT ON COLUMN tbl_verify_plan_month.month_no     IS '월 1~12';
COMMENT ON COLUMN tbl_verify_plan_month.plan_yn      IS '계획여부 Y/N — Y일 때(= 해당 월 계획 있음) A4 표에 표시';
COMMENT ON COLUMN tbl_verify_plan_month.done_yn      IS '실적여부 Y/N — 검증 점검표 작성·승인 시 Y로 갱신';
COMMENT ON COLUMN tbl_verify_plan_month.done_doc_idx IS '실적 문서 idx — 실제 작성된 검증 점검표 tbl_document.idx';
COMMENT ON COLUMN tbl_verify_plan_month.done_dt      IS '실적 완료일 YYYYMMDD';
COMMENT ON COLUMN tbl_verify_plan_month.ins_id       IS '최초입력자 ID';
COMMENT ON COLUMN tbl_verify_plan_month.ins_dt       IS '최초입력일시';
COMMENT ON COLUMN tbl_verify_plan_month.upd_id       IS '최종수정자 ID';
COMMENT ON COLUMN tbl_verify_plan_month.upd_dt       IS '최종수정일시';
