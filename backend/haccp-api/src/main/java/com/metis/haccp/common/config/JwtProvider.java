/**
 * JwtProvider — JWT(JWS HMAC-SHA512) 발급·파싱.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 로그인 성공 시 LoginUser를 클레임으로 담아 서명하고, 요청마다 JwtFilter가 되돌려 읽는다
 *   2) mes-api와 다른 점 — 현장 키오스크가 없어 계정별 TTL 분기가 없고, 세션 식별자 sid 클레임이 있다
 *   3) 서명키(JWT_SECRET)가 HS512 최소 길이(64바이트)에 미달하면 애플리케이션 시작 시점에 실패한다
 *
 * PIPELINE[HB4] Spring 설정
 * PIPELINE[HB3, HB19, HB20] 연관 모듈
 */
package com.metis.haccp.common.config;

// 역할 — 로그인 사용자 DTO — JWT 클레임 소스·복원 대상
import com.metis.haccp.common.context.LoginUser;
// 역할 — JJWT Claims payload
import io.jsonwebtoken.Claims;
// 역할 — JJWT 빌더·파서
import io.jsonwebtoken.Jwts;
// 역할 — HMAC-SHA512 SecretKey 생성
import io.jsonwebtoken.security.Keys;
// 역할 — @Value 설정 주입
import org.springframework.beans.factory.annotation.Value;
// 역할 — Spring 빈 등록
import org.springframework.stereotype.Component;

// 역할 — HMAC 서명 키 타입
import javax.crypto.SecretKey;
// 역할 — UTF-8 바이트 변환
import java.nio.charset.StandardCharsets;
// 역할 — JWT iat·exp
import java.util.Date;

@Component
public class JwtProvider {

    // HMAC-SHA512 서명 키 — JWT_SECRET 으로 1회 생성해 재사용
    private final SecretKey key;
    // 토큰 만료 밀리초 — 분 단위 설정을 변환해 보관
    private final long expireMs;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) JWT 서명키와 만료시간을 초기화한다
     *   2) Spring이 app.jwt 설정을 주입해 JwtProvider 빈을 생성할 때 호출한다
     *   3) 성공 시 불변 발급 정책을 준비하고, 비밀키가 HS512 기준에 미달하면 시작 예외를 발생시킨다
     */
    public JwtProvider(
            // JWT 비밀키 문자열 — .env JWT_SECRET. HS512라 64바이트 이상이어야 한다
            // 값이 없으면 Spring이 플레이스홀더 해석에 실패해 기동 자체가 중단된다(의도된 동작)
            @Value("${app.jwt.secret}") String secret,
            // 토큰 만료시간(분) — .env JWT_EXPIRE_MINUTES, 기본 480분(8시간 근무 1교대)
            // 프론트는 이 exp를 읽어 만료 전 세션 정리를 수행한다
            @Value("${app.jwt.expire-minutes:480}") long expireMinutes
    ) {
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.expireMs = expireMinutes * 60_000L;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 로그인 사용자 정보를 담은 HS512 서명 JWT를 발급한다
     *   2) AuthService가 아이디·비밀번호 검증을 통과시킨 직후 호출한다
     *   3) 성공 시 서명된 JWS 문자열을 반환하고, 클레임 구성 실패 시 JWT 예외를 전파한다
     */
    public String createToken(
            // 토큰에 담을 로그인 사용자 — sub는 userId, 나머지 업무 정보는 커스텀 클레임
            // coCd를 여기 담아두는 것이 테넌트 격리의 시작점이다(프론트가 회사코드를 보내지 않는 근거)
            LoginUser u
    ) {
        // 발급 시각 — iat 및 exp 계산 기준
        Date now = new Date();
        return Jwts.builder()
                .subject(u.getUserId())              // sub — 전 업체 통틀어 유일한 사용자 ID
                .claim("coCd", u.getCoCd())          // 회사코드(테넌트) — 서버가 강제하는 값
                .claim("coNm", u.getCoNm())          // 회사명 — TopBar 표시용
                .claim("userNm", u.getUserNm())      // 사용자명 — TopBar·결재선 표시용
                .claim("usrgrpCd", u.getUsrgrpCd())  // 권한 그룹 — 메뉴·화면 권한 판정
                .claim("deptCd", u.getDeptCd())      // 부서코드 — 표시용
                .claim("deptNm", u.getDeptNm())      // 부서명 — 표시용
                .claim("sid", u.getSid())            // 세션 식별자 — 로그인 이력·화면조회 로그 연결키
                .issuedAt(now)
                .expiration(new Date(now.getTime() + expireMs))
                .signWith(key, Jwts.SIG.HS512)
                .compact();
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) JWT 서명과 만료를 검증한 뒤 LoginUser를 복원한다
     *   2) JwtFilter가 Authorization 헤더의 Bearer 토큰을 요청 컨텍스트로 바꿀 때 호출한다
     *   3) 성공 시 LoginUser를 반환하고, 위조·만료·형식 오류 시 예외를 던져 필터가 401로 처리한다
     */
    public LoginUser parse(
            // 검증할 JWT 문자열 — "Bearer " 접두사를 제거한 순수 토큰
            // 서명 불일치·만료·형식 오류는 모두 예외로 나가므로 호출부에서 try/catch 해야 한다
            String token
    ) {
        // 서명 검증 실패 시 여기서 예외가 발생한다 — 검증 없이 클레임을 읽는 경로는 두지 않는다
        Claims c = Jwts.parser().verifyWith(key).build().parseSignedClaims(token).getPayload();
        return LoginUser.builder()
                .userId(c.getSubject())
                .coCd(c.get("coCd", String.class))
                .coNm(c.get("coNm", String.class))
                .userNm(c.get("userNm", String.class))
                .usrgrpCd(c.get("usrgrpCd", String.class))
                .deptCd(c.get("deptCd", String.class))
                .deptNm(c.get("deptNm", String.class))
                .sid(c.get("sid", String.class))
                .build();
    }
}
