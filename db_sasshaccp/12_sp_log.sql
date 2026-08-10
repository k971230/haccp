-- ============================================================
--  SP 2 — 로그·UV/PV 통계·감사
--
--  개발자: 박승우
--  일자: 2026-08-05
--  코멘트:
--    1) 로그인 로그와 화면 조회 로그는 sid(세션 UUID)로 이어진다 — 로그인 성공 시 발급해 JWT에 싣는다
--    2) 화면 조회 이벤트는 건당 API를 부르지 않는다. FE가 버퍼링 후 배치로 보내고 SP를 행 수만큼 호출한다
--    3) 집계는 tbl_view_log(원시)를 읽어 tbl_view_stat_daily에 업서트한다 — 같은 날짜를 몇 번 돌려도 결과가 같다
--
--  주의: 로그 적재 SP는 실패해도 본 업무를 막지 않아야 한다. 백엔드에서 별도 트랜잭션으로 호출한다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. sp_tbl_login_log_c_000 — 로그인 시도 기록
--    성공·실패·잠금을 모두 남긴다. 존재하지 않는 아이디도 그대로 적재한다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_login_log_c_000(
    -- p_co_cd: 소속 회사코드. 아이디가 없어 회사를 알 수 없으면 NULL
    p_co_cd        varchar,
    -- p_user_id: 시도한 로그인 아이디
    p_user_id      varchar,
    -- p_sid: 세션 UUID. 성공 시에만 값이 있다
    p_sid          varchar,
    -- p_result_cd: S:성공, F:실패, L:잠금
    p_result_cd    varchar,
    -- p_fail_reason: 실패 사유(기술 문구). 서버 분석용이라 사용자에게 노출하지 않는다
    p_fail_reason  varchar,
    -- p_ip_addr: 접속 IP
    p_ip_addr      varchar,
    -- p_user_agent: 브라우저 User-Agent 원문
    p_user_agent   varchar,
    -- p_device_gbn: PC / MOBILE / TABLET
    p_device_gbn   varchar,
    -- p_token_exp_dt: 발급 토큰 만료 예정일시. 실패면 NULL
    p_token_exp_dt timestamp
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO tbl_login_log(co_cd, user_id, sid, login_dt, result_cd, fail_reason,
                              ip_addr, user_agent, device_gbn, token_exp_dt)
    VALUES (NULLIF(p_co_cd, ''), p_user_id, NULLIF(p_sid, ''), now(), p_result_cd,
            NULLIF(p_fail_reason, ''), p_ip_addr, p_user_agent, p_device_gbn, p_token_exp_dt);
END$$;
COMMENT ON PROCEDURE sp_tbl_login_log_c_000(varchar, varchar, varchar, varchar, varchar, varchar, varchar, varchar, timestamp) IS '로그인 시도 기록 — 성공·실패·잠금 전수 적재';

-- ------------------------------------------------------------
-- 2. sp_tbl_login_log_u_000 — 로그아웃 시각 기록
--    같은 sid의 미종료 행 1건에만 기록한다(중복 로그아웃 요청 대비)
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_login_log_u_000(
    -- p_sid: 종료할 세션 UUID — JWT sid 클레임
    p_sid varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE tbl_login_log
       SET logout_dt = now()
     WHERE idx = (SELECT l.idx FROM tbl_login_log l
                   WHERE l.sid = p_sid AND l.logout_dt IS NULL
                   ORDER BY l.login_dt DESC LIMIT 1);
END$$;
COMMENT ON PROCEDURE sp_tbl_login_log_u_000(varchar) IS '로그아웃 시각 기록 — 해당 세션의 미종료 최신 행 1건만 갱신';

-- ------------------------------------------------------------
-- 3. sp_tbl_login_log_r_000 — 로그인 이력 조회
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_login_log_r_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위
    p_co_cd    varchar,
    -- p_from_dt: 조회 시작일 YYYYMMDD
    p_from_dt  varchar,
    -- p_to_dt: 조회 종료일 YYYYMMDD (해당 일자 종료 시각까지 포함)
    p_to_dt    varchar,
    -- p_user_id: 아이디 부분검색어. 공백이면 전체
    p_user_id  varchar,
    -- p_result_cd: 결과 필터 S/F/L. 공백이면 전체
    p_result_cd varchar
)
RETURNS TABLE(
    idx         bigint,
    user_id     varchar,
    user_nm     varchar,
    sid         varchar,
    login_dt    timestamp,
    logout_dt   timestamp,
    result_cd   varchar,
    fail_reason varchar,
    ip_addr     varchar,
    device_gbn  varchar
) LANGUAGE sql AS $$
    SELECT l.idx, l.user_id, u.user_nm, l.sid, l.login_dt, l.logout_dt,
           l.result_cd, l.fail_reason, l.ip_addr, l.device_gbn
      FROM tbl_login_log l
      -- 사용자명: 실패 로그는 아이디가 없을 수 있으므로 LEFT JOIN
      LEFT JOIN tbl_user u ON u.user_id = l.user_id
     WHERE l.co_cd = p_co_cd
       AND l.login_dt >= to_timestamp(p_from_dt, 'YYYYMMDD')
       AND l.login_dt <  to_timestamp(p_to_dt,   'YYYYMMDD') + interval '1 day'
       AND l.user_id   LIKE CONCAT('%', COALESCE(p_user_id,   ''), '%')
       AND l.result_cd LIKE CONCAT('%', COALESCE(p_result_cd, ''), '%')
     ORDER BY l.login_dt DESC;
$$;
COMMENT ON FUNCTION sp_tbl_login_log_r_000(varchar, varchar, varchar, varchar, varchar) IS '로그인 이력 조회 — 기간·아이디·결과 필터';

-- ------------------------------------------------------------
-- 4. sp_tbl_view_log_c_000 — 화면 조회 이벤트 적재 (PV 1건)
--    체류시간은 진입·이탈 시각으로 서버가 계산한다 — 클라이언트 계산값을 믿지 않는다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_view_log_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd      varchar,
    -- p_user_id: JWT 로그인 ID — UV 산출의 distinct 기준
    p_user_id    varchar,
    -- p_sid: JWT 세션 UUID — 세션수 산출 기준
    p_sid        varchar,
    -- p_scrn_cd: 화면코드 — tbl_screen.scrn_cd
    p_scrn_cd    varchar,
    -- p_enter_dt: 화면 진입 일시(탭 활성 전환 시각)
    p_enter_dt   timestamp,
    -- p_leave_dt: 화면 이탈 일시. NULL이면(= 아직 머무는 중) 체류시간도 NULL
    p_leave_dt   timestamp,
    -- p_ref_scrn_cd: 직전 화면코드 — 이동 경로 분석용
    p_ref_scrn_cd varchar,
    -- p_ip_addr: 접속 IP
    p_ip_addr    varchar,
    -- p_user_agent: 브라우저 User-Agent 원문
    p_user_agent varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO tbl_view_log(co_cd, user_id, sid, scrn_cd, enter_dt, leave_dt, stay_sec,
                             ref_scrn_cd, ip_addr, user_agent, ins_dt)
    VALUES (p_co_cd, p_user_id, NULLIF(p_sid, ''), p_scrn_cd, p_enter_dt, p_leave_dt,
            CASE WHEN p_leave_dt IS NULL THEN NULL
                 ELSE GREATEST(0, EXTRACT(EPOCH FROM (p_leave_dt - p_enter_dt))::int) END,
            NULLIF(p_ref_scrn_cd, ''), p_ip_addr, p_user_agent, now());
END$$;
COMMENT ON PROCEDURE sp_tbl_view_log_c_000(varchar, varchar, varchar, varchar, timestamp, timestamp, varchar, varchar, varchar) IS '화면 조회 이벤트 적재 — 체류시간은 서버가 계산';

-- ------------------------------------------------------------
-- 5. sp_tbl_view_stat_daily_c_000 — 화면별 일자 집계 (업서트)
--    일 1회 배치가 전일을 대상으로 호출한다. 같은 일자를 다시 돌려도 결과가 같다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_view_stat_daily_c_000(
    -- p_co_cd: 집계 대상 회사코드. 공백이면(= 전체 업체) 모든 테넌트를 한 번에 집계한다
    p_co_cd  varchar,
    -- p_stat_dt: 집계 일자 YYYYMMDD
    p_stat_dt varchar,
    -- p_id: 배치 실행 주체 — 감사 컬럼에 기록
    p_id     varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO tbl_view_stat_daily(co_cd, stat_dt, scrn_cd, pv_cnt, uv_cnt, sess_cnt,
                                    avg_stay_sec, max_stay_sec, ins_id, ins_dt)
    SELECT v.co_cd,
           p_stat_dt,
           v.scrn_cd,
           COUNT(*),                        -- PV: 이벤트 건수
           COUNT(DISTINCT v.user_id),       -- UV: 서로 다른 사용자 수
           COUNT(DISTINCT v.sid),           -- 세션수: 서로 다른 sid 수
           ROUND(AVG(v.stay_sec)::numeric, 1),
           MAX(v.stay_sec),
           p_id, now()
      FROM tbl_view_log v
     WHERE v.enter_dt >= to_timestamp(p_stat_dt, 'YYYYMMDD')
       AND v.enter_dt <  to_timestamp(p_stat_dt, 'YYYYMMDD') + interval '1 day'
       -- 회사코드가 넘어오면 그 업체만, 공백이면 전 업체를 한 번에
       AND (COALESCE(p_co_cd, '') = '' OR v.co_cd = p_co_cd)
     GROUP BY v.co_cd, v.scrn_cd
    ON CONFLICT (co_cd, stat_dt, scrn_cd) DO UPDATE SET
        pv_cnt       = EXCLUDED.pv_cnt,
        uv_cnt       = EXCLUDED.uv_cnt,
        sess_cnt     = EXCLUDED.sess_cnt,
        avg_stay_sec = EXCLUDED.avg_stay_sec,
        max_stay_sec = EXCLUDED.max_stay_sec,
        upd_id       = p_id,
        upd_dt       = now();
END$$;
COMMENT ON PROCEDURE sp_tbl_view_stat_daily_c_000(varchar, varchar, varchar) IS '화면별 일자 UV/PV 집계 업서트 — 재실행 안전';

-- ------------------------------------------------------------
-- 6. sp_tbl_view_stat_daily_r_000 — 화면 이용 통계 조회
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_view_stat_daily_r_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위
    p_co_cd   varchar,
    -- p_from_dt: 조회 시작일 YYYYMMDD
    p_from_dt varchar,
    -- p_to_dt: 조회 종료일 YYYYMMDD
    p_to_dt   varchar,
    -- p_scrn_cd: 화면코드 필터. 공백이면 전체 화면
    p_scrn_cd varchar
)
RETURNS TABLE(
    stat_dt      varchar,
    scrn_cd      varchar,
    scrn_nm      varchar,
    module_cd    varchar,
    pv_cnt       int,
    uv_cnt       int,
    sess_cnt     int,
    avg_stay_sec numeric,
    max_stay_sec int
) LANGUAGE sql AS $$
    SELECT t.stat_dt, t.scrn_cd, s.scrn_nm, s.module_cd,
           t.pv_cnt, t.uv_cnt, t.sess_cnt, t.avg_stay_sec, t.max_stay_sec
      FROM tbl_view_stat_daily t
      -- 화면명: 마스터에서 삭제된 화면도 통계는 남으므로 LEFT JOIN
      LEFT JOIN tbl_screen s ON s.scrn_cd = t.scrn_cd
     WHERE t.co_cd = p_co_cd
       AND t.stat_dt BETWEEN p_from_dt AND p_to_dt
       AND t.scrn_cd LIKE CONCAT('%', COALESCE(p_scrn_cd, ''), '%')
     ORDER BY t.stat_dt DESC, t.pv_cnt DESC;
$$;
COMMENT ON FUNCTION sp_tbl_view_stat_daily_r_000(varchar, varchar, varchar, varchar) IS '화면 이용 통계 조회 — 일자·화면별 UV/PV/체류';

-- ------------------------------------------------------------
-- 7. sp_tbl_view_log_d_000 — 원시 조회 로그 정리
--    보존기간이 지난 원시 이벤트만 지운다. 집계(tbl_view_stat_daily)는 영구 보존이라 손대지 않는다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_view_log_d_000(
    -- p_co_cd: 정리 대상 회사코드. 공백이면 전 업체
    p_co_cd          varchar,
    -- p_retention_month: 보존 개월수. 이보다 오래된 원시 이벤트를 삭제한다
    p_retention_month int
)
LANGUAGE plpgsql AS $$
BEGIN
    IF COALESCE(p_retention_month, 0) <= 0 THEN
        RAISE EXCEPTION '보존 개월수는 1 이상이어야 합니다.' USING ERRCODE = '45000';
    END IF;

    DELETE FROM tbl_view_log
     WHERE enter_dt < now() - (p_retention_month || ' month')::interval
       AND (COALESCE(p_co_cd, '') = '' OR co_cd = p_co_cd);
END$$;
COMMENT ON PROCEDURE sp_tbl_view_log_d_000(varchar, int) IS '원시 조회 로그 정리 — 집계 테이블은 삭제하지 않는다';

-- ------------------------------------------------------------
-- 8. sp_tbl_audit_log_c_000 — 변경 감사 로그 기록
--    판정 수동변경·결재 반려·업체 전환처럼 사후 추적이 필요한 행위에서 호출한다
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_audit_log_c_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd      varchar,
    -- p_user_id: 행위자 로그인 ID
    p_user_id    varchar,
    -- p_tbl_nm: 대상 테이블명 (tbl_ 접두 포함)
    p_tbl_nm     varchar,
    -- p_tgt_idx: 대상 행의 idx
    p_tgt_idx    bigint,
    -- p_action_cd: I/U/D/APV/RJT/JUDGE_MOD/CO_SWITCH
    p_action_cd  varchar,
    -- p_before_json: 변경 전 값 JSON 문자열. 등록(I)이면 NULL
    p_before_json text,
    -- p_after_json: 변경 후 값 JSON 문자열. 삭제(D)면 NULL
    p_after_json text,
    -- p_reason: 사유 — 판정 수동변경·반려 시 필수
    p_reason     varchar,
    -- p_ip_addr: 행위자 IP
    p_ip_addr    varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO tbl_audit_log(co_cd, user_id, tbl_nm, tgt_idx, action_cd,
                              before_json, after_json, reason, ip_addr, ins_dt)
    VALUES (p_co_cd, p_user_id, p_tbl_nm, p_tgt_idx, p_action_cd,
            NULLIF(p_before_json, '')::jsonb, NULLIF(p_after_json, '')::jsonb,
            NULLIF(p_reason, ''), p_ip_addr, now());
END$$;
COMMENT ON PROCEDURE sp_tbl_audit_log_c_000(varchar, varchar, varchar, bigint, varchar, text, text, varchar, varchar) IS '변경 감사 로그 기록 — HACCP 기록의 사후 수정 추적';

-- ------------------------------------------------------------
-- 9. sp_tbl_audit_log_r_000 — 변경 감사 로그 조회
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_tbl_audit_log_r_000(
    -- p_co_cd: JWT 회사코드
    p_co_cd     varchar,
    -- p_from_dt: 조회 시작일 YYYYMMDD
    p_from_dt   varchar,
    -- p_to_dt: 조회 종료일 YYYYMMDD
    p_to_dt     varchar,
    -- p_tbl_nm: 대상 테이블명 부분검색어. 공백이면 전체
    p_tbl_nm    varchar,
    -- p_user_id: 행위자 부분검색어. 공백이면 전체
    p_user_id   varchar,
    -- p_action_cd: 행위 필터. 공백이면 전체
    p_action_cd varchar
)
RETURNS TABLE(
    idx         bigint,
    user_id     varchar,
    user_nm     varchar,
    tbl_nm      varchar,
    tgt_idx     bigint,
    action_cd   varchar,
    before_json jsonb,
    after_json  jsonb,
    reason      varchar,
    ip_addr     varchar,
    ins_dt      timestamp
) LANGUAGE sql AS $$
    SELECT a.idx, a.user_id, u.user_nm, a.tbl_nm, a.tgt_idx, a.action_cd,
           a.before_json, a.after_json, a.reason, a.ip_addr, a.ins_dt
      FROM tbl_audit_log a
      LEFT JOIN tbl_user u ON u.user_id = a.user_id
     WHERE a.co_cd = p_co_cd
       AND a.ins_dt >= to_timestamp(p_from_dt, 'YYYYMMDD')
       AND a.ins_dt <  to_timestamp(p_to_dt,   'YYYYMMDD') + interval '1 day'
       AND a.tbl_nm    LIKE CONCAT('%', COALESCE(p_tbl_nm,    ''), '%')
       AND a.user_id   LIKE CONCAT('%', COALESCE(p_user_id,   ''), '%')
       AND a.action_cd LIKE CONCAT('%', COALESCE(p_action_cd, ''), '%')
     ORDER BY a.ins_dt DESC;
$$;
COMMENT ON FUNCTION sp_tbl_audit_log_r_000(varchar, varchar, varchar, varchar, varchar, varchar) IS '변경 감사 로그 조회 — 기간·테이블·행위자·행위 필터';
