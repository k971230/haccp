/**
 * ViewStatDailyJob — 화면 이용 UV/PV 일자 집계 정기 실행기.
 *
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) 설정 cron에 따라 전일·당일 tbl_view_stat_daily를 멱등 업서트한다
 *   2) Spring Boot 자동 빈 taskScheduler와 이름이 겹치지 않도록 Job 접미사를 쓴다
 *   3) 원시 수집(ViewLogController)과 분리해 통계 화면은 집계 테이블만 읽게 한다
 *
 * PIPELINE[HB47] 화면 이용 통계 집계
 * PIPELINE[HB43, HB44, HB45, HB46] 연관 모듈
 */
package com.metis.haccp.log;

// 역할 — 생성자 주입·Spring 스케줄 실행
import lombok.RequiredArgsConstructor;
// 역할 — 기동 직후 1회 보강 여부
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** 화면 이용 통계 일집계 Job — DailyTaskGenerationJob과 동일 스케줄 패턴 */
@Component
@RequiredArgsConstructor
public class ViewStatDailyJob {

    // 전일·당일 UV/PV 집계 서비스
    private final ViewStatService service;

    // true일 때(= 로컬 스모크·배포 직후 보강) 기동 완료 시 전일·당일을 1회 집계한다
    @Value("${app.view-stat-daily.run-on-startup:false}")
    private boolean runOnStartup;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) 매일 과제 생성(00:05) 직후 전일 확정·당일 진행분을 집계한다
     *   2) cron·timezone은 application.yml env로만 받는다
     *   3) 성공 여부는 SP 멱등으로 보장하고 예외는 서비스 로그에 남긴다
     */
    @Scheduled(
            cron = "${app.view-stat-daily.cron:0 15 0 * * *}",
            zone = "${app.timezone:Asia/Seoul}"
    )
    public void aggregateViewStats() {
        service.aggregateYesterdayAndToday();
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) run-on-startup=true일 때만 기동 직후 전일·당일을 1회 집계한다
     *   2) 로컬에서 00:15를 기다리지 않고 통계 화면을 검증할 때 켠다
     *   3) 기본 false — 운영은 cron만으로 돌린다
     */
    @EventListener(ApplicationReadyEvent.class)
    public void aggregateOnStartup() {
        // false일 때(= 운영 기본) 기동 시 집계를 건너뛴다
        if (!runOnStartup) {
            return;
        }
        service.aggregateYesterdayAndToday();
    }
}
