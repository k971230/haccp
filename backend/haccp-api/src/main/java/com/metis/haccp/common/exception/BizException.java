/**
 * BizException.java — 업무 예외(런타임).
 *
 * 주요 역할:
 *     1. code + message로 업무 오류 표현
 *     2. GlobalExceptionHandler가 400으로 변환
 *
 * PIPELINE[HB8] 예외 처리
 * PIPELINE[HB6] 연관 모듈
 */
package com.metis.haccp.common.exception;

// 역할 — @Getter — code 접근자
import lombok.Getter;

/** 업무 예외 — WinForms MessageBox(경고) 대응. */
@Getter
public class BizException extends RuntimeException {
    // 오류 코드(기본 BIZ_ERROR)
    private final String code;

    /**
     * 개발자: 박승우
     * 일자: 2026-07-10
     * 코멘트:
     *   1) BizException 메서드가 담당하는 입력 검증과 업무 처리를 수행한다.
     *   2) 호출 계약에 따라 파라미터를 전달받아 기존 처리 순서를 그대로 실행한다.
     *   3) 성공 시 선언된 반환값을 제공하고, 실패 시 기존 예외를 호출부로 전파한다.
     */
    public BizException(
            // 검증 실패 시 사용자에게 전달할 업무 문구
            // 호출부의 null·빈값 허용 여부와 변환 규칙은 메서드 본문의 기존 계약을 따른다
            String message
    ) {
        // code=BIZ_ERROR로 위임
        this(
                "BIZ_ERROR",
                message
        );
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-07-10
     * 코멘트:
     *   1) BizException 메서드가 담당하는 입력 검증과 업무 처리를 수행한다.
     *   2) 호출 계약에 따라 파라미터를 전달받아 기존 처리 순서를 그대로 실행한다.
     *   3) 성공 시 선언된 반환값을 제공하고, 실패 시 기존 예외를 호출부로 전파한다.
     */
    public BizException(
            // 응답 또는 업무 오류 코드 — 프론트 분기 식별자
            // 호출부의 null·빈값 허용 여부와 변환 규칙은 메서드 본문의 기존 계약을 따른다
            String code,
            // 검증 실패 시 사용자에게 전달할 업무 문구
            // 호출부의 null·빈값 허용 여부와 변환 규칙은 메서드 본문의 기존 계약을 따른다
            String message
    ) {
        // RuntimeException message 설정
        super(
                message
        );
        // 오류 코드 보관
        this.code = code;
    }
}
