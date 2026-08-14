/**
 * DocumentAlarmScheduler — 문서 작성 마감 임박 알림 정기 실행기.
 *
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) 설정 cron마다 마감 임박 예정일(alarm_dt 도달)을 찾아 tbl_notification에 적재한다
 *   2) 주기 계산은 하지 않는다 — 예정일·알림시각은 DocCycleService·SP가 이미 확정해 둔다
 *   3) Spring Boot 자동 빈 taskScheduler와 겹치지 않도록 Scheduler 접미사를 쓴다
 *
 * PIPELINE[HB99] 문서 마감 알림 스케줄러
 * PIPELINE[HB94, HB98] 연관 모듈
 */
package com.haccp.hwp.doccycle;

// 역할 — 생성자 주입·Spring 스케줄 실행
import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** 문서 마감 알림 Job — ViewStatDailyJob과 동일 스케줄 패턴 */
@Component
@RequiredArgsConstructor
public class DocumentAlarmScheduler {

    // 마감 임박 알림 적재 서비스 — 발송 플래그 갱신까지 SP가 처리한다
    private final DocCycleService service;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 알림 주기마다 마감 임박 예정일의 담당자에게 알림을 남긴다
     *   2) cron·timezone은 application.yml env로만 받는다 (기본 10분 간격)
     *   3) 이미 보낸 예정일은 alarm_send_yn='Y'라 중복 알림이 생기지 않는다
     */
    @Scheduled(
            cron = "${app.schedule.alarm-cron:0 */10 * * * *}",
            zone = "${app.timezone:Asia/Seoul}"
    )
    public void sendDocumentAlarms() {
        service.sendTaskAlarms();
    }
}
