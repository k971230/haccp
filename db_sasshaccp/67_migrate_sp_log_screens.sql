-- ============================================================
--  migrate 67 — 로그 3화면(로그인 이력·감사 이력·화면 이용 통계) 전용 SP 신설
--
--  개발자: 박승우
--  일자: 2026-08-12
--  코멘트:
--    1) 조회 전용이다 — 적재 SP(sp_tbl_login_log_c_000 등)는 화면 SP가 아니므로 그대로 둔다
--    2) 세 화면 모두 기간(YYYYMMDD 문자열)이 필수 헤더다. 종료일은 그날 24시까지 포함한다
--    3) 생성 전용 — 레거시 sp_tbl_login_log_r_000·_audit_log_r_000·_view_stat_daily_r_000 DROP은 68에서 수행
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. sp_tbl_login_history_r_000 — 로그인 이력 조회
--    실패 로그는 존재하지 않는 아이디로도 남으므로 사용자명은 LEFT JOIN이다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_login_history_r_000(varchar, varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_login_history_r_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위. 필수 등가 조건
    p_co_cd     varchar,
    -- p_from_dt: 조회 시작일 YYYYMMDD
    p_from_dt   varchar,
    -- p_to_dt: 조회 종료일 YYYYMMDD — 그날 24시 직전까지 포함
    p_to_dt     varchar,
    -- p_user_id: 아이디 검색어. 공백이면 전체
    p_user_id   varchar,
    -- p_result_cd: 결과 필터 S:성공 F:실패 L:잠금. 공백이면 전체
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
      -- 사용자명 — 없는 아이디로 실패한 로그도 남기려면 LEFT JOIN이어야 한다
      LEFT JOIN tbl_user u ON u.user_id = l.user_id
     WHERE l.co_cd = p_co_cd
       AND l.login_dt >= to_timestamp(p_from_dt, 'YYYYMMDD')
       AND l.login_dt <  to_timestamp(p_to_dt,   'YYYYMMDD') + interval '1 day'
       AND l.user_id   LIKE CONCAT('%', COALESCE(p_user_id,   ''), '%')
       AND l.result_cd LIKE CONCAT('%', COALESCE(p_result_cd, ''), '%')
     ORDER BY l.login_dt DESC;
$$;
COMMENT ON FUNCTION sp_tbl_login_history_r_000(varchar, varchar, varchar, varchar, varchar) IS
  '로그인 이력 조회 — 기간·아이디·결과 필터, 최신순';

-- ------------------------------------------------------------
-- 2. sp_tbl_audit_history_r_000 — 변경 감사 이력 조회
--    메뉴명은 플랫폼 표준코드 audit-target에서 테이블명으로 역매핑한다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_audit_history_r_000(varchar, varchar, varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_audit_history_r_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위. 필수 등가 조건
    p_co_cd     varchar,
    -- p_from_dt: 조회 시작일 YYYYMMDD
    p_from_dt   varchar,
    -- p_to_dt: 조회 종료일 YYYYMMDD — 그날 24시 직전까지 포함
    p_to_dt     varchar,
    -- p_menu_key: 좌측 메뉴 트리 선택값(테이블명·화면코드·메뉴명 중 하나). 공백이면 전체
    p_menu_key  varchar,
    -- p_user_id: 행위자 검색어. 공백이면 전체
    p_user_id   varchar,
    -- p_action_cd: 행위 필터 I/U/D/APV/RJT 등. 공백이면 전체
    p_action_cd varchar
)
RETURNS TABLE(
    idx         bigint,
    user_id     varchar,
    user_nm     varchar,
    menu_nm     varchar,
    tbl_nm      varchar,
    tgt_idx     bigint,
    action_cd   varchar,
    before_json jsonb,
    after_json  jsonb,
    reason      varchar,
    ip_addr     varchar,
    ins_dt      timestamp
) LANGUAGE sql AS $$
    SELECT a.idx,
           a.user_id,
           u.user_nm,
           -- 표준코드에 매핑이 없으면 테이블명을 그대로 보여준다
           COALESCE(c.code_nm, a.tbl_nm) AS menu_nm,
           a.tbl_nm,
           a.tgt_idx,
           a.action_cd,
           a.before_json,
           a.after_json,
           a.reason,
           a.ip_addr,
           a.ins_dt
      FROM tbl_audit_log a
      -- 행위자명 — 삭제된 사용자도 이력은 남으므로 LEFT JOIN
      LEFT JOIN tbl_user u ON u.user_id = a.user_id
      -- audit-target 표준코드 — 테이블명 → 화면/메뉴 표시명
      LEFT JOIN tbl_code c
             ON c.co_cd = '0000'
            AND c.main_cd = 'audit-target'
            AND c.sub_cd = a.tbl_nm
     WHERE a.co_cd = p_co_cd
       AND a.ins_dt >= to_timestamp(p_from_dt, 'YYYYMMDD')
       AND a.ins_dt <  to_timestamp(p_to_dt,   'YYYYMMDD') + interval '1 day'
       -- 트리 선택값은 테이블명·ref1·ref2·표시명 어디에 맞아도 통과시킨다
       AND (
            COALESCE(p_menu_key, '') = ''
            OR a.tbl_nm = p_menu_key
            OR c.ref1   = p_menu_key
            OR c.ref2   = p_menu_key
            OR c.code_nm = p_menu_key
       )
       AND a.user_id   LIKE CONCAT('%', COALESCE(p_user_id,   ''), '%')
       AND a.action_cd LIKE CONCAT('%', COALESCE(p_action_cd, ''), '%')
     ORDER BY a.ins_dt DESC;
$$;
COMMENT ON FUNCTION sp_tbl_audit_history_r_000(varchar, varchar, varchar, varchar, varchar, varchar) IS
  '변경 감사 이력 조회 — 기간·메뉴키·행위자·행위 필터, 최신순';

-- ------------------------------------------------------------
-- 3. sp_tbl_screen_usage_r_000 — 화면 이용 통계 조회
--    원시 로그가 아니라 일자 집계(tbl_view_stat_daily)를 읽는다
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_screen_usage_r_000(varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_screen_usage_r_000(
    -- p_co_cd: JWT 회사코드 — 테넌트 범위. 필수 등가 조건
    p_co_cd   varchar,
    -- p_from_dt: 집계 시작일 YYYYMMDD
    p_from_dt varchar,
    -- p_to_dt: 집계 종료일 YYYYMMDD (stat_dt 문자열 BETWEEN)
    p_to_dt   varchar,
    -- p_scrn_cd: 좌측 메뉴 트리에서 고른 화면코드. 공백이면 전체 화면
    p_scrn_cd varchar
)
RETURNS TABLE(
    stat_dt      varchar,
    scrn_cd      varchar,
    menu_cd      varchar,
    menu_nm      varchar,
    scrn_nm      varchar,
    module_cd    varchar,
    pv_cnt       int,
    uv_cnt       int,
    sess_cnt     int,
    ip_cnt       int,
    avg_stay_sec numeric,
    max_stay_sec int
) LANGUAGE sql AS $$
    SELECT t.stat_dt,
           t.scrn_cd,
           m.menu_cd,
           -- 메뉴 → 화면명 → 화면코드 순으로 표시명을 정한다
           COALESCE(m.menu_nm, s.scrn_nm, t.scrn_cd) AS menu_nm,
           s.scrn_nm,
           s.module_cd,
           t.pv_cnt, t.uv_cnt, t.sess_cnt, t.ip_cnt,
           t.avg_stay_sec, t.max_stay_sec
      FROM tbl_view_stat_daily t
      -- 화면 마스터 — 화면명·모듈 표기
      LEFT JOIN tbl_screen s ON s.scrn_cd = t.scrn_cd
      -- 같은 화면이 여러 메뉴에 붙을 수 있어 정렬 우선 1건만 취한다
      LEFT JOIN LATERAL (
          SELECT mm.menu_cd, mm.menu_nm
            FROM tbl_menu mm
           WHERE mm.scrn_cd = t.scrn_cd
           ORDER BY mm.sort_no NULLS LAST, mm.menu_cd
           LIMIT 1
      ) m ON TRUE
     WHERE t.co_cd = p_co_cd
       AND t.stat_dt BETWEEN p_from_dt AND p_to_dt
       AND (COALESCE(p_scrn_cd, '') = '' OR t.scrn_cd = p_scrn_cd)
     ORDER BY t.stat_dt DESC, t.scrn_cd;
$$;
COMMENT ON FUNCTION sp_tbl_screen_usage_r_000(varchar, varchar, varchar, varchar) IS
  '화면 이용 통계 조회 — 집계일·메뉴·PV/UV/세션/IP, 최신순';
