/**
 * ErrorResponse.java — API 오류 응답 DTO.
 *
 * 주요 역할:
 *     1. success=false 고정
 *     2. code·message로 업무 오류 전달
 *
 * PIPELINE[HB10] common 모듈
 */
package com.metis.haccp.common.response;

// 역할 — @AllArgsConstructor — code·message 생성자
import lombok.AllArgsConstructor;
// 역할 — @Getter — 필드 접근자
import lombok.Getter;

/** 오류 응답 — GlobalExceptionHandler가 4xx/5xx 시 반환. */
@Getter
@AllArgsConstructor
public class ErrorResponse {
    // 성공 여부 — 오류 응답은 항상 false
    private final boolean success = false;
    // 오류 코드(BIZ_ERROR, VALIDATION, DB_SIGNAL 등)
    private final String code;
    // 사용자 노출용 업무 메시지
    private final String message;
}
