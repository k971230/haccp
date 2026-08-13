-- ============================================================
--  migrate 79 — 화면 이용 통계 전 일자 재집계 (ip_cnt 0 해소)
--
--  개발자: 박승우
--  일자: 2026-08-12
--  코멘트:
--    1) 화면 이용 통계의 ip_cnt가 전 행 0이었던 원인은 58_migrate_log_mgmt.sql이
--       ip_cnt 컬럼을 DEFAULT 0으로 뒤늦게 추가했고, 그 이전에 집계된 행이 다시 집계되지 않았기 때문이다
--       (원시 로그 tbl_view_log.ip_addr는 정상 적재되고 있다. 집계 SP 본문도 정상이다)
--    2) 일 배치(ViewStatDailyJob)는 전일·당일만 돌리므로 과거 일자는 스스로 복구되지 않는다
--       그래서 원시 로그에 존재하는 모든 일자를 한 번 순회해 다시 집계한다
--    3) 집계 SP는 ON CONFLICT DO UPDATE 업서트라서 몇 번 실행해도 결과가 같다
--       미집계 일자도 이때 함께 채워진다
-- ============================================================

SET search_path TO sasshaccp;

-- ------------------------------------------------------------
-- 1. 원시 로그에 있는 모든 일자를 재집계
--    p_co_cd를 공백으로 넘겨 전 업체를 한 번에 처리한다
-- ------------------------------------------------------------
DO $$
DECLARE
    v_day record;
    v_cnt int := 0;
BEGIN
    FOR v_day IN
        SELECT DISTINCT to_char(v.enter_dt, 'YYYYMMDD') AS stat_dt
          FROM tbl_view_log v
         ORDER BY 1
    LOOP
        CALL sp_tbl_view_stat_daily_c_000('', v_day.stat_dt, 'system');
        v_cnt := v_cnt + 1;
    END LOOP;
    RAISE NOTICE '화면 이용 통계 재집계 완료 — 대상 일자 %일', v_cnt;
END$$;

-- ------------------------------------------------------------
-- 2. 검증 — 일자별 PV·IP 합계. ip_cnt가 0이 아니어야 정상이다
-- ------------------------------------------------------------
SELECT stat_dt,
       count(*)      AS scrn_cnt,
       sum(pv_cnt)   AS pv_sum,
       sum(uv_cnt)   AS uv_sum,
       sum(ip_cnt)   AS ip_sum
  FROM tbl_view_stat_daily
 GROUP BY stat_dt
 ORDER BY stat_dt;
