-- ============================================================
--  DDL 2 — 로그·통계 (4 테이블)
--
--  개발자: 박승우
--  일자: 2026-08-05
--  코멘트:
--    1) 로그인 로그(성공·실패·잠금 전수)와 화면별 UV/PV 측정을 기반 기능으로 적재
--    2) sid(세션 UUID)가 tbl_login_log와 tbl_view_log를 잇는 조인 키 — JWT sid 클레임에서 발급
--    3) 로그 테이블은 이력이라 UNIQUE 제약이 없고 감사 4종 대신 발생일시 컬럼을 쓴다
--
--  보존 정책: 로그 보존기간과 HACCP 문서 최소 2년 보존은 서로 다른 정책이다.
--             tbl_view_log(raw)만 보존기간 경과분을 정리 배치로 삭제하고
--             tbl_view_stat_daily(집계)와 tbl_audit_log는 삭제하지 않는다.
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. tbl_login_log — 로그인 이력
--    실패(F)·잠금(L)도 남긴다. LoginThrottle 및 tbl_user.login_fail_cnt와 연동
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_login_log (
    idx          bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd        varchar(10)  NULL,
    user_id      varchar(20)  NOT NULL,
    sid          varchar(36)  NULL,
    login_dt     timestamp    NOT NULL DEFAULT now(),
    logout_dt    timestamp    NULL,
    result_cd    varchar(1)   NOT NULL,
    fail_reason  varchar(200) NULL,
    ip_addr      varchar(45)  NULL,
    user_agent   varchar(500) NULL,
    device_gbn   varchar(10)  NULL,
    token_exp_dt timestamp    NULL
);
COMMENT ON TABLE  tbl_login_log              IS '로그인 이력 — 성공·실패·잠금 전수 기록. 감사 대응 및 계정 도용 추적용';
COMMENT ON COLUMN tbl_login_log.idx          IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_login_log.co_cd        IS '회사코드 — 실패 시 아이디가 존재하지 않으면 NULL이 될 수 있다';
COMMENT ON COLUMN tbl_login_log.user_id      IS '시도한 로그인 ID — 존재하지 않는 아이디도 그대로 기록';
COMMENT ON COLUMN tbl_login_log.sid          IS '세션 UUID — 성공 시에만 발급. JWT sid 클레임 및 tbl_view_log.sid와 조인';
COMMENT ON COLUMN tbl_login_log.login_dt     IS '로그인 시도 일시';
COMMENT ON COLUMN tbl_login_log.logout_dt    IS '로그아웃 일시 — 명시적 로그아웃 또는 토큰 만료 시 갱신. NULL이면(= 미종료 세션)';
COMMENT ON COLUMN tbl_login_log.result_cd    IS '결과 — S:성공, F:실패(비밀번호 불일치·미존재·미사용), L:잠금(실패 임계 초과)';
COMMENT ON COLUMN tbl_login_log.fail_reason  IS '실패 사유 — 서버 로그용 기술 문구. 사용자에게는 노출하지 않는다';
COMMENT ON COLUMN tbl_login_log.ip_addr      IS '접속 IP — IPv6 대비 45자';
COMMENT ON COLUMN tbl_login_log.user_agent   IS '브라우저 User-Agent 원문';
COMMENT ON COLUMN tbl_login_log.device_gbn   IS '기기구분 — PC / MOBILE / TABLET';
COMMENT ON COLUMN tbl_login_log.token_exp_dt IS '발급 토큰 만료 예정일시';

-- ------------------------------------------------------------
-- 2. tbl_view_log — 화면 조회 원시 이벤트 (PV 원천)
--    셸이 탭 keep-alive 구조라 라우터 이동이 아니라 활성 탭 전환을 진입/이탈로 본다.
--    FE는 이벤트마다 API를 호출하지 않고 버퍼링 후 배치로 전송한다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_view_log (
    idx          bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd        varchar(10)  NOT NULL,
    user_id      varchar(20)  NOT NULL,
    sid          varchar(36)  NULL,
    scrn_cd      varchar(30)  NOT NULL,
    enter_dt     timestamp    NOT NULL,
    leave_dt     timestamp    NULL,
    stay_sec     int          NULL,
    ref_scrn_cd  varchar(30)  NULL,
    ip_addr      varchar(45)  NULL,
    user_agent   varchar(500) NULL,
    ins_dt       timestamp    NOT NULL DEFAULT now()
);
COMMENT ON TABLE  tbl_view_log             IS '화면 조회 원시 이벤트 — PV 1건 = 1행. 보존기간 경과분은 정리 배치로 삭제';
COMMENT ON COLUMN tbl_view_log.idx         IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_view_log.co_cd       IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_view_log.user_id     IS '로그인 ID — UV 산출의 distinct 기준';
COMMENT ON COLUMN tbl_view_log.sid         IS '세션 UUID — tbl_login_log.sid와 조인. 세션수(sess_cnt) 산출 기준';
COMMENT ON COLUMN tbl_view_log.scrn_cd     IS '화면코드 — tbl_screen.scrn_cd';
COMMENT ON COLUMN tbl_view_log.enter_dt    IS '화면 진입 일시 — 탭이 활성으로 전환된 시각';
COMMENT ON COLUMN tbl_view_log.leave_dt    IS '화면 이탈 일시 — 다른 탭으로 전환·탭 닫기·페이지 종료 시각. NULL이면(= 미종료 이벤트)';
COMMENT ON COLUMN tbl_view_log.stay_sec    IS '체류 시간(초) — leave_dt - enter_dt. 미종료 이벤트는 NULL';
COMMENT ON COLUMN tbl_view_log.ref_scrn_cd IS '직전 화면코드 — 화면 간 이동 경로 분석용';
COMMENT ON COLUMN tbl_view_log.ip_addr     IS '접속 IP';
COMMENT ON COLUMN tbl_view_log.user_agent  IS '브라우저 User-Agent 원문';
COMMENT ON COLUMN tbl_view_log.ins_dt      IS '서버 수집 일시 — 배치 전송이라 enter_dt와 차이가 날 수 있다';

-- ------------------------------------------------------------
-- 3. tbl_view_stat_daily — 화면별 일자 집계 (UV/PV)
--    일 1회 배치가 전일 tbl_view_log를 집계해 upsert한다. 영구 보존
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_view_stat_daily (
    idx          bigint        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd        varchar(10)   NOT NULL,
    stat_dt      varchar(8)    NOT NULL,
    scrn_cd      varchar(30)   NOT NULL,
    pv_cnt       int           NOT NULL DEFAULT 0,
    uv_cnt       int           NOT NULL DEFAULT 0,
    sess_cnt     int           NOT NULL DEFAULT 0,
    ip_cnt       int           NOT NULL DEFAULT 0,
    avg_stay_sec numeric(10,1) NULL,
    max_stay_sec int           NULL,
    ins_id       varchar(20)   NULL,
    ins_dt       timestamp     NULL DEFAULT now(),
    upd_id       varchar(20)   NULL,
    upd_dt       timestamp     NULL,
    CONSTRAINT ux_tbl_view_stat_daily UNIQUE (co_cd, stat_dt, scrn_cd)
);
COMMENT ON TABLE  tbl_view_stat_daily              IS '화면별 일자 집계 — UV/PV/세션수/평균체류. 일 1회 배치 upsert, 영구 보존';
COMMENT ON COLUMN tbl_view_stat_daily.idx          IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_view_stat_daily.co_cd        IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_view_stat_daily.stat_dt      IS '집계일자 YYYYMMDD';
COMMENT ON COLUMN tbl_view_stat_daily.scrn_cd      IS '화면코드 — tbl_screen.scrn_cd';
COMMENT ON COLUMN tbl_view_stat_daily.pv_cnt       IS 'PV — 해당 일자·화면의 조회 이벤트 건수';
COMMENT ON COLUMN tbl_view_stat_daily.uv_cnt       IS 'UV — 해당 일자·화면을 조회한 서로 다른 사용자 수(distinct user_id)';
COMMENT ON COLUMN tbl_view_stat_daily.sess_cnt     IS '세션수 — 서로 다른 sid 수. 같은 사용자가 여러 번 로그인하면 분리 집계';
COMMENT ON COLUMN tbl_view_stat_daily.ip_cnt       IS 'IP수 — 해당 일자·화면의 서로 다른 ip_addr 수';
COMMENT ON COLUMN tbl_view_stat_daily.avg_stay_sec IS '평균 체류시간(초) — stay_sec이 있는 이벤트만 대상';
COMMENT ON COLUMN tbl_view_stat_daily.max_stay_sec IS '최대 체류시간(초)';
COMMENT ON COLUMN tbl_view_stat_daily.ins_id       IS '최초입력자 ID — 배치 실행 주체';
COMMENT ON COLUMN tbl_view_stat_daily.ins_dt       IS '최초입력일시';
COMMENT ON COLUMN tbl_view_stat_daily.upd_id       IS '최종수정자 ID — 재집계 실행 주체';
COMMENT ON COLUMN tbl_view_stat_daily.upd_dt       IS '최종수정일시';

-- ------------------------------------------------------------
-- 4. tbl_audit_log — 변경 감사 로그
--    HACCP 기록의 사후 수정 추적이 목적. 판정 수동 변경·결재 반려·업체 전환을 반드시 남긴다
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_audit_log (
    idx         bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_cd       varchar(10)  NOT NULL,
    user_id     varchar(20)  NOT NULL,
    tbl_nm      varchar(50)  NOT NULL,
    tgt_idx     bigint       NULL,
    action_cd   varchar(20)  NOT NULL,
    before_json jsonb        NULL,
    after_json  jsonb        NULL,
    reason      varchar(500) NULL,
    ip_addr     varchar(45)  NULL,
    ins_dt      timestamp    NOT NULL DEFAULT now()
);
COMMENT ON TABLE  tbl_audit_log             IS '변경 감사 로그 — HACCP 기록의 사후 수정 추적. 삭제하지 않는다';
COMMENT ON COLUMN tbl_audit_log.idx         IS 'PK 자동 채번 대리키';
COMMENT ON COLUMN tbl_audit_log.co_cd       IS '회사코드 — 테넌트 키';
COMMENT ON COLUMN tbl_audit_log.user_id     IS '행위자 로그인 ID';
COMMENT ON COLUMN tbl_audit_log.tbl_nm      IS '대상 테이블명 — tbl_ 접두 포함';
COMMENT ON COLUMN tbl_audit_log.tgt_idx     IS '대상 행의 idx';
COMMENT ON COLUMN tbl_audit_log.action_cd   IS '행위 — I:등록, U:수정, D:삭제, APV:승인, RJT:반려, JUDGE_MOD:판정 수동변경, CO_SWITCH:업체 전환';
COMMENT ON COLUMN tbl_audit_log.before_json IS '변경 전 값 JSON — 등록(I)일 때는 NULL';
COMMENT ON COLUMN tbl_audit_log.after_json  IS '변경 후 값 JSON — 삭제(D)일 때는 NULL';
COMMENT ON COLUMN tbl_audit_log.reason      IS '사유 — 판정 수동변경·결재 반려 시 필수 입력값';
COMMENT ON COLUMN tbl_audit_log.ip_addr     IS '행위자 IP';
COMMENT ON COLUMN tbl_audit_log.ins_dt      IS '기록 일시';
