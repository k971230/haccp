/**
 * WebConfig.java — Spring MVC CORS·화면 권한 인터셉터.
 *
 * 주요 역할:
 *     1. /api/** 경로에 CORS 허용 출처·메서드·헤더 등록
 *     2. JwtFilter 401 응답과 동일한 allowed-origins 설정 공유
 *     3. ScreenAuthInterceptor 를 /api/** 에 등록 — JWT 다음 단계의 화면 권한
 *     4. Tomcat POST·swallow 한도를 커넥터에 직접 넣는다. YAML -1 바인딩만으로는 RST 가 남았다
 *
 * PIPELINE[HB5] Spring 설정
 * PIPELINE[HB3, HB19, HB145] 연관 모듈
 */
package com.haccp.common.config;

// 역할 — 화면 권한 인터셉터
import com.haccp.common.auth.ScreenAuthInterceptor;
// 역할 — @Value 설정 주입
import org.springframework.beans.factory.annotation.Value;
// 역할 — @Bean 등록
import org.springframework.context.annotation.Bean;
// 역할 — @Configuration 등록
import org.springframework.context.annotation.Configuration;
// 역할 — 커스터마이저 순서. Boot 기본값(2MB) 뒤에 덮는다
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
// 역할 — 임베디드 Tomcat 공장
import org.springframework.boot.web.embedded.tomcat.TomcatServletWebServerFactory;
// 역할 — 웹서버 공장 커스터마이저
import org.springframework.boot.web.server.WebServerFactoryCustomizer;
// 역할 — CORS 매핑 API
import org.springframework.web.servlet.config.annotation.CorsRegistry;
// 역할 — 인터셉터 등록
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
// 역할 — WebMvcConfigurer 확장
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/** CORS·화면 권한 — 허용 출처는 환경설정(app.cors.allowed-origins, 콤마 구분)으로 분리. */
@Configuration
public class WebConfig implements WebMvcConfigurer {

    // CORS 허용 출처 배열 — 기본값 localhost:4173 (haccp-web Vite 개발 서버. mes-web 5173과 구분)
    @Value("${app.cors.allowed-origins:http://localhost:4173}")
    private String[] allowedOrigins;

    // 화면 권한 — JwtFilter 가 LoginUser 를 채운 뒤 컨트롤러 앞에서 대조한다
    private final ScreenAuthInterceptor screenAuthInterceptor;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) CORS 설정과 화면 권한 인터셉터를 한 MVC 설정에 둔다
     *   2) Spring 이 빈을 만들 때 인터셉터를 주입한다
     *   3) 인터셉터가 없으면 기동이 실패한다 — 권한 검사를 빼 놓고 올리지 않는다
     */
    public WebConfig(
            // 경로 → tbl_role_screen 대조
            ScreenAuthInterceptor screenAuthInterceptor
    ) {
        this.screenAuthInterceptor = screenAuthInterceptor;
    }
    /**
     * 개발자: 박승우
     * 일자: 2026-07-10
     * 코멘트:
     *   1) API 경로에 적용할 CORS 허용 정책을 등록한다.
     *   2) Spring MVC 초기화 시 환경설정의 허용 출처와 HTTP 메서드를 구성한다.
     *   3) 성공 시 /api 하위 매핑이 등록되고, 잘못된 설정은 애플리케이션 시작 오류로 드러난다.
     */

    @Override
    public void addCorsMappings(
            // Spring CORS 등록 객체 — /api 경로의 허용 정책 구성
            // 호출부의 null·빈값 허용 여부와 변환 규칙은 메서드 본문의 기존 계약을 따른다
            CorsRegistry registry
    ) {
        // /api/** 하위 모든 API 경로에 CORS 정책 적용
        registry.addMapping("/api/**")
                // 허용 출처 — application.yml 또는 .env에서 주입
                .allowedOrigins(allowedOrigins)
                // REST·프리플라이트에 필요한 HTTP 메서드 허용
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                // Authorization 등 모든 요청 헤더 허용
                .allowedHeaders("*")
                // 쿠키·자격증명 미사용(JWT Bearer만 사용)
                .allowCredentials(
                        false
                );
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) 인증된 /api 요청에 화면 권한 인터셉터를 붙인다
     *   2) MVC 초기화 때 한 번 등록한다
     *   3) 로그인(JwtFilter 공개 경로)은 필터에서 이미 빠지므로 여기까지 오지 않는다
     */
    @Override
    public void addInterceptors(
            // Spring 인터셉터 등록 객체
            InterceptorRegistry registry
    ) {
        registry.addInterceptor(screenAuthInterceptor)
                .addPathPatterns("/api/**");
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-15
     * 코멘트:
     *   1) YAML max-swallow-size 만 -1 이면 max-http-form-post-size 기본 2MB 가 남아 RST 가 난다
     *   2) 커넥터에 swallow·POST 한도를 -1 로 직접 넣는다. 실제 용량은 Spring multipart 50·55MB
     *   3) @Order 최후 — Boot 커스터마이저가 2MB 를 다시 씌우지 못하게
     */
    @Bean
    @Order(Ordered.LOWEST_PRECEDENCE)
    WebServerFactoryCustomizer<TomcatServletWebServerFactory> tomcatUploadSize() {
        return factory -> factory.addConnectorCustomizers(connector -> {
            // -1 일 때(= 무제한). Spring multipart 가 먼저 자른다
            connector.setProperty("maxSwallowSize", "-1");
            connector.setMaxPostSize(-1);
        });
    }
}
