/**
 * HaccpApiApplication — Spring Boot 3.3 진입점.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) com.metis.haccp 하위를 스캔해 Controller·Service·Mapper를 등록하고 내장 Tomcat을 기동한다
 *   2) mes-api와 완전히 독립된 프로세스다 — 포트(기본 8081)·DB(sasshaccp)·패키지가 모두 다르다
 *   3) 업무 로직은 두지 않는다. 기동 실패는 대개 .env 누락(JWT_SECRET·DB_PASSWORD)이 원인이다
 *
 * PIPELINE[HB1] Spring Boot 진입
 * PIPELINE[HB2] 연관 — application.yml
 */
package com.metis.haccp;

// 역할 — @Mapper 인터페이스 자동 스캔
import org.mybatis.spring.annotation.MapperScan;
// 역할 — Spring Boot 실행기
import org.springframework.boot.SpringApplication;
// 역할 — 자동 구성·컴포넌트 스캔 활성화
import org.springframework.boot.autoconfigure.SpringBootApplication;
// 역할 — 작성 과제 생성 정기 작업 활성화
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@MapperScan("com.metis.haccp")
@EnableScheduling
public class HaccpApiApplication {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 애플리케이션 실행 진입점을 제공한다
     *   2) 프로세스 시작 시 자동 구성과 컴포넌트 스캔을 시작한다
     *   3) 성공 시 컨텍스트와 내장 서버를 기동하고, 실패 시 시작 예외를 상위로 전파한다
     */
    public static void main(
            // 애플리케이션 시작 인자 — Spring Boot 실행기에 그대로 전달한다
            String[] args
    ) {
        SpringApplication.run(HaccpApiApplication.class, args);
    }
}
