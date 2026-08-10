/**
 * DailyTaskGenerationJob — 작성 과제 생성 정기 실행기.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 설정 cron에 따라 전체 활성 회사의 오늘 과제를 멱등 생성한다
 *   2) Spring Boot 자동 빈 taskScheduler와 이름이 겹치지 않도록 Job 접미사를 쓴다
 *   3) 로그인 시 TaskService 보정도 별도로 수행해 정기 실행 지연을 보완한다
 *
 * PIPELINE[HB96] 워크플로 일정 생성
 * PIPELINE[HB94, HB2] 연관 모듈
 */
package com.metis.haccp.tsk;

// 역할 — 생성자 주입·Spring 스케줄 실행
import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** 작성 과제 일일 생성 Job — Spring Boot TaskScheduler 빈명과 충돌하지 않는다 */
@Component
@RequiredArgsConstructor
public class DailyTaskGenerationJob {
    private final TaskService service;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 매일 업무 시작 전에 작성 과제·지연 알림을 생성한다
     *   2) cron·timezone은 application.yml env로만 받는다
     *   3) 성공 여부는 SP 멱등으로 보장하고 예외는 스케줄러 로그에 남긴다
     */
    @Scheduled(cron = "${app.task-generation.cron:0 5 0 * * *}", zone = "${app.timezone:Asia/Seoul}")
    public void generateDailyTasks() {
        service.generateAllCompanies();
    }
}
