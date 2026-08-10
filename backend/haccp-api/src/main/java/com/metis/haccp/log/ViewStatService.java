/**
 * ViewStatService — 화면 이용 UV/PV 일자 집계 업무 서비스.
 *
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) tbl_view_log 원시를 sp_tbl_view_stat_daily_c_000으로 일자 집계한다
 *   2) ViewStatDailyJob이 cron으로 호출하며, 통계 화면은 집계 테이블만 조회한다
 *   3) 전일(확정)·당일(진행분)을 같이 돌려 당일 통계도 다음 배치까지 비지 않게 한다
 *
 * PIPELINE[HB47] 화면 이용 통계 집계
 * PIPELINE[HB43, HB44, HB45, HB46] 연관 모듈
 */
package com.metis.haccp.log;

// 역할 — 생성자 주입·서비스 등록
import lombok.RequiredArgsConstructor;
// 역할 — 배치·서비스 로그
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
// 역할 — 타임존 설정값
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

// 역할 — 집계 일자 계산
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;

/** 화면별 일자 UV/PV 집계 — 전 테넌트 일괄 */
@Service
@RequiredArgsConstructor
public class ViewStatService {

    private static final Logger log = LoggerFactory.getLogger(ViewStatService.class);

    // 집계 일자 YYYYMMDD — SP p_stat_dt와 동일 포맷
    private static final DateTimeFormatter YMD = DateTimeFormatter.ofPattern("yyyyMMdd");
    // 배치 감사 주체 — JWT 없는 스케줄 실행이므로 고정 system
    private static final String BATCH_USER_ID = "system";
    // 전 테넌트 집계 — SP는 공백 co_cd일 때(= 전체 업체) 한 번에 처리한다
    private static final String ALL_COMPANIES = "";

    // 원시→일자 집계 SP 호출
    private final LogMapper mapper;

    // 집계 기준 타임존 — application.yml app.timezone (기본 Asia/Seoul)
    @Value("${app.timezone:Asia/Seoul}")
    private String timezone;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) 전일·당일 두 일자를 전 업체로 집계한다
     *   2) ViewStatDailyJob cron·기동 보강에서 호출한다
     *   3) 일자별 예외는 삼키고 다음 일자를 계속한다 — 한 일자 실패로 배치 전체가 죽지 않게
     */
    public void aggregateYesterdayAndToday() {
        ZoneId zone = ZoneId.of(timezone);
        LocalDate today = LocalDate.now(zone);
        // 전일: 하루가 끝난 확정분 — SP 설계상 주 대상
        aggregateDateQuiet(today.minusDays(1));
        // 당일: 오늘 들어온 원시분 — 통계 화면이 당일에도 건수를 보이게 한다
        aggregateDateQuiet(today);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) 지정 일자 한 건을 전 업체로 집계한다
     *   2) 배치·수동 보강에서 동일 경로를 쓴다
     *   3) 성공 시 해당 일자 집계가 업서트된다. 실패 시 예외를 그대로 던진다
     */
    public void aggregateDate(
            // 집계 대상 달력일 — app.timezone 기준 LocalDate
            LocalDate statDate
    ) {
        if (statDate == null) {
            throw new IllegalArgumentException("집계 일자가 없습니다.");
        }
        // statDt: SP가 enter_dt 구간 필터에 쓰는 YYYYMMDD
        String statDt = statDate.format(YMD);
        mapper.aggregateViewStatDaily(ALL_COMPANIES, statDt, BATCH_USER_ID);
        log.info("view stat daily aggregated (statDt={})", statDt);
    }

    /** 일자 1건 집계 — 실패해도 형제만 남기고 다음 일자로 진행한다 */
    private void aggregateDateQuiet(LocalDate statDate) {
        try {
            aggregateDate(statDate);
        } catch (Exception e) {
            log.error("view stat daily aggregate failed (statDt={})",
                    statDate == null ? "" : statDate.format(YMD), e);
        }
    }
}
