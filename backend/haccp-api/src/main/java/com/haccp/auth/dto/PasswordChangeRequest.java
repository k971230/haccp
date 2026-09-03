/**
 * PasswordChangeRequest — 본인 비밀번호 변경 요청.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 현재·새 비밀번호만 받는다. 확인 일치는 프론트에서 먼저 본다
 *   2) userId·coCd는 본문에 두지 않는다 — JWT에서만 읽는다
 *   3) 평문은 로그에 남기지 않는다
 *
 * PIPELINE[HB213] auth DTO
 */
package com.haccp.auth.dto;

// 역할 — 빈 문자열 차단. 1자리도 허용한다
import jakarta.validation.constraints.NotEmpty;
// 역할 — 접근자
import lombok.Getter;
import lombok.Setter;

/** 비밀번호 변경 — { currentPassword, newPassword } */
@Getter
@Setter
public class PasswordChangeRequest {

    /** 현재 비밀번호 — 서버에서만 BCrypt 비교한다 */
    @NotEmpty(message = "현재 비밀번호를 입력해 주세요.")
    private String currentPassword;

    /** 새 비밀번호 — 빈칸만 아니면 된다. 현재와 같은지는 서비스가 본다 */
    @NotEmpty(message = "새 비밀번호를 입력해 주세요.")
    private String newPassword;
}
