/**
 * SecurityHeadersFilter — 모든 응답에 브라우저 안전 헤더를 붙인다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-27
 * 코멘트:
 *   1) 파일을 되돌려 주는 곳이 넷이다 (문서첨부·양식·서명·감사PDF).
 *      네 군데에 따로 붙이면 다섯 번째가 생겼을 때 빠진다 — 한 곳에서 건다
 *   2) nosniff 가 없으면 브라우저가 내용을 보고 타입을 추측한다.
 *      octet-stream 으로 내려도 HTML 로 읽어 실행할 수 있다
 *   3) 인증 전후를 가리지 않으므로 JwtFilter 보다 앞에 둔다
 *
 * PIPELINE[HB13] 공통 설정
 */
package com.haccp.common.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class SecurityHeadersFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain chain
    ) throws ServletException, IOException {
        // 내려보낸 Content-Type 을 브라우저가 다시 추측하지 못하게 한다
        response.setHeader("X-Content-Type-Options", "nosniff");
        // 외부로 나가는 요청에 우리 화면 경로가 실려 나가지 않게 한다
        response.setHeader("Referrer-Policy", "same-origin");
        chain.doFilter(request, response);
    }
}
