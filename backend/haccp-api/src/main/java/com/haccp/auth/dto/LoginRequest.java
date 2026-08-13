/**
 * LoginRequest.java — 로그인 요청 DTO.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 로그인 화면이 보내는 아이디·비밀번호만 받는다. 회사코드는 받지 않는다
 *   2) mes-api와 다른 점 — tbl_user.user_id가 전 업체 통틀어 유일해서 아이디만으로 회사가 결정된다
 *      (프론트가 회사코드를 보낼 수 있으면 타사 계정을 겨냥한 시도가 가능해지므로 필드 자체를 두지 않는다)
 *   3) 공백 검증은 @NotBlank가 담당하고, 실제 자격 검증은 AuthService가 한다
 *
 * PIPELINE[HB23] auth DTO
 */
package com.haccp.auth.dto;

// 역할 — 공백 입력 차단
import jakarta.validation.constraints.NotBlank;
// 역할 — @Getter/@Setter 접근자 (Jackson 역직렬화 대상)
import lombok.Getter;
import lombok.Setter;

/** 로그인 요청 — { userId, password } */
@Getter
@Setter
public class LoginRequest {

    /** 로그인 아이디 — 전 업체 통틀어 유일. 이 값으로 소속 회사(co_cd)가 결정된다 */
    @NotBlank(message = "아이디를 입력해 주세요.")
    private String userId;

    /** 평문 비밀번호 — 서버에서만 BCrypt 해시와 비교하고 로그에 남기지 않는다 */
    @NotBlank(message = "비밀번호를 입력해 주세요.")
    private String password;
}
