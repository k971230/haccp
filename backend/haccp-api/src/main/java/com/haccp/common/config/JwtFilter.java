/**
 * JwtFilter — /api/** Bearer JWT 인증 필터.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 요청당 1회 토큰을 검증하고 LoginUserContext에 주입한 뒤, 종료 시 반드시 제거한다
 *   2) mes-api와 다른 점 — 회사 선택이 없어 공개 경로가 /api/v1/auth/login 하나뿐이다
 *   3) 필터 단계 401은 MVC CORS 적용 전이라 CORS 헤더를 직접 붙인다. 없으면 브라우저가 응답을 읽지 못해
 *      프론트의 401 인터셉터(로그인 화면 이동)가 동작하지 않는다.
 *      코드는 UNAUTHENTICATED(없음)·SESSION_EXPIRED(만료)·UNAUTHORIZED(위조) 로 가른다
 *
 * PIPELINE[HB3] Spring 설정
 * PIPELINE[HB4, HB5, HB11, HB12] 연관 모듈
 */
package com.haccp.common.config;

// 역할 — 로그인 사용자 DTO — JWT 파싱 결과
import com.haccp.common.context.LoginUser;
// 역할 — 요청 스코프 ThreadLocal 컨텍스트
import com.haccp.common.context.LoginUserContext;
// 역할 — 서블릿 필터 체인 인터페이스
import jakarta.servlet.FilterChain;
// 역할 — 서블릿 예외
import jakarta.servlet.ServletException;
// 역할 — HTTP 요청
import jakarta.servlet.http.HttpServletRequest;
// 역할 — HTTP 응답
import jakarta.servlet.http.HttpServletResponse;
// 역할 — @Value 설정 주입
import org.springframework.beans.factory.annotation.Value;
// 역할 — Spring 빈 등록
import org.springframework.stereotype.Component;
// 역할 — 요청당 1회 실행 필터 베이스
import org.springframework.web.filter.OncePerRequestFilter;

// 역할 — IO 예외
import java.io.IOException;
// 역할 — CORS 허용 출처 배열 검색
import java.util.Arrays;

@Component
public class JwtFilter extends OncePerRequestFilter {

    // JWT 서명 검증·Claims 파싱 담당
    private final JwtProvider jwtProvider;

    /** CORS 허용 출처 — WebConfig와 같은 설정을 공유한다(401 응답에도 헤더를 붙이기 위함) */
    @Value("${app.cors.allowed-origins:http://localhost:4173}")
    private String[] allowedOrigins;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) JWT 검증을 담당할 Provider를 주입한다
     *   2) Spring이 JwtFilter 빈을 생성할 때 단일 생성자로 자동 호출한다
     *   3) 성공 시 불변 Provider 참조를 보관하고, 의존성 생성 실패 시 기동을 중단한다
     */
    public JwtFilter(
            // JWT 발급·파싱 컴포넌트 — 이 필터는 parse만 사용한다
            JwtProvider jwtProvider
    ) {
        this.jwtProvider = jwtProvider;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 보호 API 요청의 Bearer JWT를 검증하고 로그인 컨텍스트를 관리한다
     *   2) 요청당 한 번, 공개 경로 판별 → 토큰 파싱 → 체인 실행 순서로 수행한다
     *   3) 성공 시 컨텍스트를 제공하고 finally에서 제거하며, 실패 시 401 JSON으로 종료한다
     */
    @Override
    protected void doFilterInternal(
            // 현재 HTTP 요청 — 경로·메서드·Authorization 헤더 판별에 사용
            HttpServletRequest req,
            // 현재 HTTP 응답 — 인증 실패 시 401 JSON을 직접 기록한다
            HttpServletResponse res,
            // 필터 체인 — 인증 성공 또는 공개 요청을 다음 단계로 넘긴다
            FilterChain chain
    ) throws ServletException, IOException {

        // isPublic이 true일 때(= 로그인·프리플라이트·비 API 요청) 인증을 생략하고 통과시킨다
        if (isPublic(req)) {
            chain.doFilter(req, res);
            return;
        }

        // Authorization 헤더 — "Bearer {토큰}" 형식만 인정한다
        String header = req.getHeader("Authorization");
        // 헤더가 없거나 Bearer 접두사가 아닐 때(= 토큰 미전송) 401로 끊는다
        if (header == null || !header.startsWith("Bearer ")) {
            unauthorized(req, res, "UNAUTHENTICATED", "로그인이 필요합니다.");
            return;
        }

        LoginUser user;
        try {
            // "Bearer " 7자를 제거한 순수 토큰을 검증한다
            user = jwtProvider.parse(header.substring(7));
        } catch (Exception e) {
            // 만료와 위조를 가른다 — 현장은 「세션이 종료되었습니다」와 「다시 로그인」을 다르게 묻는다
            if (e instanceof io.jsonwebtoken.ExpiredJwtException) {
                unauthorized(req, res, "SESSION_EXPIRED", "세션이 종료되었습니다.");
            } else {
                unauthorized(req, res, "UNAUTHORIZED", "인증이 올바르지 않습니다. 다시 로그인하세요.");
            }
            return;
        }

        // 이후 서비스 계층이 LoginUserContext.coCd()로 테넌트를 읽는다
        LoginUserContext.set(user);
        try {
            chain.doFilter(req, res);
        } finally {
            // 스레드 풀 재사용 시 다른 사용자에게 컨텍스트가 새는 것을 막는다 — 예외가 나도 반드시 실행
            LoginUserContext.clear();
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) JWT 인증을 생략할 공개 요청인지 판별한다
     *   2) 필터 진입 직후 프리플라이트·비 API·로그인 경로를 구분할 때 호출한다
     *   3) 공개 요청이면 true, 그 외 모든 /api 요청이면 false를 반환한다
     */
    private boolean isPublic(
            // 판별 대상 요청 — 메서드와 URI만 사용한다
            HttpServletRequest req
    ) {
        // OPTIONS일 때(= CORS 프리플라이트) 토큰 없이 통과시킨다
        if ("OPTIONS".equalsIgnoreCase(req.getMethod())) return true;
        // 요청 경로 — /api 밖(정적 리소스·actuator 헬스)은 인증 대상이 아니다
        String p = req.getRequestURI();
        if (!p.startsWith("/api/")) return true;
        // 로그인만 공개다. mes-api의 /companies(회사 콤보)는 HACCP에 없다 —
        // 사용자 아이디가 전 업체 통틀어 유일해서 로그인 화면에 회사 선택이 없기 때문
        return "/api/v1/auth/login".equals(p);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 인증 실패 요청에 CORS 헤더와 401 JSON을 직접 기록한다
     *   2) MVC 진입 전 단계에서 토큰 누락·만료·형식 오류가 발생했을 때 호출한다
     *   3) 성공 시 브라우저가 읽을 수 있는 오류 응답을 완료하고, 출력 실패 시 IOException을 전파한다
     */
    private void unauthorized(
            // 원 요청 — Origin 헤더를 읽어 허용 출처인지 확인한다
            HttpServletRequest req,
            // 응답 객체 — 상태·헤더·본문을 직접 기록한다
            HttpServletResponse res,
            // 실패 구분 — UNAUTHENTICATED(없음) · SESSION_EXPIRED(만료) · UNAUTHORIZED(위조)
            String code,
            // 사용자에게 보일 업무 문구 — 기술 상세를 담지 않는다
            String msg
    ) throws IOException {
        // 요청 Origin — 허용 목록에 있을 때만 CORS 헤더를 되돌려준다
        String origin = req.getHeader("Origin");
        // 허용 출처일 때(= 우리 프론트에서 온 요청) 브라우저가 401 본문을 읽을 수 있게 헤더를 붙인다
        if (origin != null && Arrays.asList(allowedOrigins).contains(origin)) {
            res.setHeader("Access-Control-Allow-Origin", origin);
            res.setHeader("Vary", "Origin");
        }
        res.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        res.setContentType("application/json;charset=UTF-8");
        // ErrorResponse와 같은 형태의 JSON을 직접 기록한다(MVC 컨버터를 타지 않는 단계이므로)
        res.getWriter().write("{\"success\":false,\"code\":\"" + code + "\",\"message\":\"" + msg + "\"}");
    }
}
