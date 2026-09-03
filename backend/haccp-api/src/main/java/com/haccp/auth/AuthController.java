/**
 * AuthController — 로그인·로그아웃·현재 사용자 REST API (/api/v1/auth).
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) POST /login 은 공개(JwtFilter 예외), POST /logout·GET /me 는 Bearer 토큰이 필요하다
 *   2) mes-api와 다른 점 — 회사 콤보(/companies)가 없다. 아이디가 전역 유일해서 회사 선택 단계 자체가 없다
 *   3) 접속 메타(IP·UA·기기)는 컨트롤러에서 뽑아 서비스로 넘긴다 — 서비스가 서블릿 API를 모르게 하기 위함
 *
 * PIPELINE[HB19] REST Controller
 * PIPELINE[HB20, HB4] 연관 모듈
 */
package com.haccp.auth;

// 역할 — 로그인 요청 DTO
import com.haccp.auth.dto.LoginRequest;
// 역할 — 비밀번호 변경 요청
import com.haccp.auth.dto.PasswordChangeRequest;
// 역할 — 로그인 응답 DTO
import com.haccp.auth.dto.LoginResponse;
// 역할 — 로그인 사용자 DTO
import com.haccp.common.context.LoginUser;
// 역할 — 요청 스코프 컨텍스트
import com.haccp.common.context.LoginUserContext;
// 역할 — 접속 메타 추출
import com.haccp.common.context.RequestMeta;
// 역할 — API 공통 응답 래퍼
import com.haccp.common.response.CommonResponse;
// 역할 — 접속 메타 원천
import jakarta.servlet.http.HttpServletRequest;
// 역할 — @NotBlank 등 Bean Validation 실행
import jakarta.validation.Valid;
// 역할 — @RequiredArgsConstructor 생성자 주입
import lombok.RequiredArgsConstructor;
// 역할 — REST 매핑 어노테이션
import org.springframework.web.bind.annotation.*;

/** 로그인 화면 → /api/v1/auth/* */
@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    // 로그인·로그아웃 업무 로직 위임 대상
    private final AuthService authService;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 아이디·비밀번호를 검증해 토큰·사용자정보·화면권한을 반환한다
     *   2) 로그인 화면의 확인 버튼에서 호출한다 (JwtFilter 공개 경로)
     *   3) 성공 시 LoginResponse, 실패 시 BizException이 400 업무 문구로 변환된다
     */
    @PostMapping("/login")
    public CommonResponse<LoginResponse> login(
            // 로그인 요청 본문 — userId는 전역 유일 아이디, password는 평문 입력값
            // @Valid가 두 필드의 공백을 먼저 차단하고, 계정상태·비밀번호 검증은 AuthService가 담당한다
            @Valid @RequestBody LoginRequest req,
            // 현재 HTTP 요청 — IP·User-Agent·기기구분을 뽑아 로그인 이력에 남기기 위해서만 사용한다
            // 인증 판정에는 쓰지 않는다. 값이 부정확해도 로그인 성공·실패 결과는 달라지지 않는다
            HttpServletRequest http
    ) {
        return CommonResponse.ok(authService.login(req, RequestMeta.of(http)));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 현재 세션의 로그아웃 시각을 이력에 기록한다
     *   2) 프론트 로그아웃 버튼에서 세션을 지우기 직전에 호출한다
     *   3) 항상 성공으로 응답한다 — 이력 기록 실패가 로그아웃을 막지 않는다
     */
    @PostMapping("/logout")
    public CommonResponse<Void> logout() {
        // JWT sid 클레임 — JwtFilter가 주입한 컨텍스트에서 읽는다(프론트가 보낸 값을 신뢰하지 않는다)
        authService.logout(LoginUserContext.sid());
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) JWT로 확인된 현재 로그인 사용자 정보를 반환한다
     *   2) 새로고침 후 프론트가 보관한 세션이 아직 유효한지 확인할 때 호출한다
     *   3) 토큰이 유효하면 LoginUser를 반환하고, 만료·위조면 컨트롤러 진입 전에 401로 끝난다
     */
    @GetMapping("/me")
    public CommonResponse<LoginUser> me() {
        return CommonResponse.ok(LoginUserContext.get());
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-03
     * 코멘트:
     *   1) 본인 비밀번호를 변경한다
     *   2) 푸터 키 아이콘 팝업에서 호출한다. JWT 필수
     *   3) 성공 시 본문 없음. 실패는 업무 문구
     */
    @PostMapping("/change-password")
    public CommonResponse<Void> changePassword(
            // 현재·새 비밀번호. userId는 본문에 없다
            @Valid @RequestBody PasswordChangeRequest req
    ) {
        authService.changePassword(req);
        return CommonResponse.ok(null);
    }
}
