/**
 * LoginResponse.java — 로그인 응답 DTO.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 토큰·사용자정보·화면권한을 한 번에 돌려준다 — 로그인 직후 추가 왕복을 없애기 위함
 *   2) 프론트 authStore가 이 응답 전체를 세션에 보관하고, 메뉴는 별도 API로 조회한다
 *   3) 비밀번호 해시·실패횟수 같은 내부 값은 담지 않는다
 *
 * PIPELINE[HB26] auth DTO
 */
package com.metis.haccp.auth.dto;

// 역할 — 로그인 사용자 DTO — 응답에 포함되는 공개 정보
import com.metis.haccp.common.context.LoginUser;
// 역할 — @AllArgsConstructor 생성자
import lombok.AllArgsConstructor;
// 역할 — @Getter 접근자
import lombok.Getter;

// 역할 — 화면권한 목록
import java.util.List;

/** 로그인 응답 — { token, user, screens } */
@Getter
@AllArgsConstructor
public class LoginResponse {

    /** JWS 문자열 — 프론트가 Authorization: Bearer 헤더에 실어 보낸다 */
    private final String token;
    /** 로그인 사용자 — 회사·부서·권한그룹·세션 식별자 포함 */
    private final LoginUser user;
    /**
     * 화면 권한 목록 — 관리자(usrgrpCd=ADMIN)는 전권이므로 빈 목록을 보낸다.
     * 프론트는 빈 목록 + isAdmin 조합을 전권으로 해석한다.
     */
    private final List<ScreenAuthRow> screens;
}
