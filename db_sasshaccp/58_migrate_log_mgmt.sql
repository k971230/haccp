-- ============================================================
-- 58 — 로그 관리: 공통코드·ip_cnt·조회 SP(메뉴명/필터)
--
-- 파일번호: 58
-- 이전번호: 57
-- 개발자: 박승우
-- 일자: 2026-08-12
-- 코멘트:
--   1) login-result·audit-result·audit-target 공통코드를 시드한다
--   2) tbl_view_stat_daily.ip_cnt와 집계·조회 SP를 맞춘다
--   3) 감사 조회에 menu_nm·메뉴키 필터를 추가한다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 공통코드
-- ------------------------------------------------------------
INSERT INTO tbl_code (co_cd, main_cd, sub_cd, code_nm, sort_no, ref1, ref2, sys_yn, use_yn, ins_id) VALUES
    ('0000', 'login-result', '*', '로그인 결과', 0, NULL, NULL, 'Y', 'Y', 'system'),
    ('0000', 'login-result', 'S', '성공',       1, NULL, NULL, 'Y', 'Y', 'system'),
    ('0000', 'login-result', 'F', '실패',       2, NULL, NULL, 'Y', 'Y', 'system'),
    ('0000', 'login-result', 'L', '잠금',       3, NULL, NULL, 'Y', 'Y', 'system'),
    ('0000', 'audit-result', '*', '감사 행위', 0, NULL, NULL, 'Y', 'Y', 'system'),
    ('0000', 'audit-result', 'I', '등록', 1, NULL, NULL, 'Y', 'Y', 'system'),
    ('0000', 'audit-result', 'U', '수정', 2, NULL, NULL, 'Y', 'Y', 'system'),
    ('0000', 'audit-result', 'D', '삭제', 3, NULL, NULL, 'Y', 'Y', 'system'),
    ('0000', 'audit-result', 'APV', '승인', 4, NULL, NULL, 'Y', 'Y', 'system'),
    ('0000', 'audit-result', 'RJT', '반려', 5, NULL, NULL, 'Y', 'Y', 'system'),
    ('0000', 'audit-result', 'JUDGE_MOD', '판정 수동변경', 6, NULL, NULL, 'Y', 'Y', 'system'),
    ('0000', 'audit-result', 'CO_SWITCH', '업체 전환', 7, NULL, NULL, 'Y', 'Y', 'system'),
    -- audit-target: sub_cd=tbl_nm, code_nm=메뉴명, ref1=scrn_cd
    ('0000', 'audit-target', '*', '감사 대상 메뉴', 0, NULL, NULL, 'Y', 'Y', 'system'),
    ('0000', 'audit-target', 'tbl_document', '문서함', 1, 'document-inbox', NULL, 'Y', 'Y', 'system'),
    ('0000', 'audit-target', 'tbl_document_file', '문서 파일', 2, 'document-inbox', NULL, 'Y', 'Y', 'system')
ON CONFLICT (co_cd, main_cd, sub_cd) DO UPDATE SET
    code_nm = EXCLUDED.code_nm,
    sort_no = EXCLUDED.sort_no,
    ref1    = EXCLUDED.ref1,
    ref2    = EXCLUDED.ref2,
    sys_yn  = EXCLUDED.sys_yn,
    use_yn  = EXCLUDED.use_yn,
    upd_id  = 'system',
    upd_dt  = now();

-- ------------------------------------------------------------
-- 2. tbl_view_stat_daily.ip_cnt
-- ------------------------------------------------------------
ALTER TABLE tbl_view_stat_daily
    ADD COLUMN IF NOT EXISTS ip_cnt int NOT NULL DEFAULT 0;
COMMENT ON COLUMN tbl_view_stat_daily.ip_cnt IS 'IP수 — 해당 일자·화면의 서로 다른 ip_addr 수';

-- ------------------------------------------------------------
-- 3. 집계 SP — ip_cnt
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_tbl_view_stat_daily_c_000(
    p_co_cd  varchar,
    p_stat_dt varchar,
    p_id     varchar
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO tbl_view_stat_daily(co_cd, stat_dt, scrn_cd, pv_cnt, uv_cnt, sess_cnt, ip_cnt,
                                    avg_stay_sec, max_stay_sec, ins_id, ins_dt)
    SELECT v.co_cd,
           p_stat_dt,
           v.scrn_cd,
           COUNT(*),
           COUNT(DISTINCT v.user_id),
           COUNT(DISTINCT v.sid),
           COUNT(DISTINCT NULLIF(TRIM(v.ip_addr), '')),
           ROUND(AVG(v.stay_sec)::numeric, 1),
           MAX(v.stay_sec),
           p_id, now()
      FROM tbl_view_log v
     WHERE v.enter_dt >= to_timestamp(p_stat_dt, 'YYYYMMDD')
       AND v.enter_dt <  to_timestamp(p_stat_dt, 'YYYYMMDD') + interval '1 day'
       AND (COALESCE(p_co_cd, '') = '' OR v.co_cd = p_co_cd)
     GROUP BY v.co_cd, v.scrn_cd
    ON CONFLICT (co_cd, stat_dt, scrn_cd) DO UPDATE SET
        pv_cnt       = EXCLUDED.pv_cnt,
        uv_cnt       = EXCLUDED.uv_cnt,
        sess_cnt     = EXCLUDED.sess_cnt,
        ip_cnt       = EXCLUDED.ip_cnt,
        avg_stay_sec = EXCLUDED.avg_stay_sec,
        max_stay_sec = EXCLUDED.max_stay_sec,
        upd_id       = p_id,
        upd_dt       = now();
END$$;
COMMENT ON PROCEDURE sp_tbl_view_stat_daily_c_000(varchar, varchar, varchar) IS '화면별 일자 UV/PV/IP 집계 업서트 — 재실행 안전';

-- ------------------------------------------------------------
-- 4. 통계 조회 SP — menu_cd/menu_nm/ip_cnt, ORDER BY stat_dt
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_view_stat_daily_r_000(varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_view_stat_daily_r_000(
    p_co_cd   varchar,
    p_from_dt varchar,
    p_to_dt   varchar,
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
           COALESCE(m.menu_nm, s.scrn_nm, t.scrn_cd) AS menu_nm,
           s.scrn_nm,
           s.module_cd,
           t.pv_cnt, t.uv_cnt, t.sess_cnt, t.ip_cnt,
           t.avg_stay_sec, t.max_stay_sec
      FROM tbl_view_stat_daily t
      LEFT JOIN tbl_screen s ON s.scrn_cd = t.scrn_cd
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
COMMENT ON FUNCTION sp_tbl_view_stat_daily_r_000(varchar, varchar, varchar, varchar) IS '화면 이용 통계 조회 — 집계일·메뉴·PV/UV/세션/IP';

-- ------------------------------------------------------------
-- 5. 감사 조회 SP — menu_nm + 메뉴키(scrn_cd/menu_cd/tbl_nm) 필터
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS sp_tbl_audit_log_r_000(varchar, varchar, varchar, varchar, varchar, varchar);
CREATE FUNCTION sp_tbl_audit_log_r_000(
    p_co_cd     varchar,
    p_from_dt   varchar,
    p_to_dt     varchar,
    -- p_menu_key: 메뉴/화면/테이블 키. 공백이면 전체 (구 p_tbl_nm 자리)
    p_menu_key  varchar,
    p_user_id   varchar,
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
      LEFT JOIN tbl_user u ON u.user_id = a.user_id
      LEFT JOIN tbl_code c
             ON c.co_cd = '0000'
            AND c.main_cd = 'audit-target'
            AND c.sub_cd = a.tbl_nm
     WHERE a.co_cd = p_co_cd
       AND a.ins_dt >= to_timestamp(p_from_dt, 'YYYYMMDD')
       AND a.ins_dt <  to_timestamp(p_to_dt,   'YYYYMMDD') + interval '1 day'
       AND (
            COALESCE(p_menu_key, '') = ''
            OR a.tbl_nm = p_menu_key
            OR c.ref1 = p_menu_key
            OR c.ref2 = p_menu_key
            OR c.code_nm = p_menu_key
       )
       AND a.user_id   LIKE CONCAT('%', COALESCE(p_user_id,   ''), '%')
       AND a.action_cd LIKE CONCAT('%', COALESCE(p_action_cd, ''), '%')
     ORDER BY a.ins_dt DESC;
$$;
COMMENT ON FUNCTION sp_tbl_audit_log_r_000(varchar, varchar, varchar, varchar, varchar, varchar) IS '변경 감사 로그 조회 — 기간·메뉴키·행위자·행위 필터';
