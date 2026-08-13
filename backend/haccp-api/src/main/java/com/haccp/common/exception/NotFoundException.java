/**
 * NotFoundException.java — 대상 자원 부재 예외(런타임).
 *
 * 주요 역할:
 *     1. "요청은 옳지만 대상이 아직 없다"를 400(입력 오류)과 구분한다
 *     2. GlobalExceptionHandler가 404로 변환한다
 *
 * PIPELINE[HB8] 예외 처리
 * PIPELINE[HB6] 연관 모듈
 */
package com.haccp.common.exception;

/**
 * 자원 부재 예외 — BizException을 상속해 기존 업무 오류 흐름(code + 사용자 문구)을 그대로 쓴다.
 *
 * 400과 나누는 기준: 입력값이 틀렸으면 BizException(400), 입력은 맞는데 대상 파일·행이
 * 아직 없으면 NotFoundException(404). 프론트가 "업로드 안내"와 "입력 오류"를 갈라
 * 처리할 수 있어야 하기 때문이다.
 */
public class NotFoundException extends BizException {

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) 사용자에게 보여줄 업무 문구로 404 예외를 만든다
     *   2) 템플릿 원본 미업로드 등 "대상 부재" 지점에서 호출한다
     *   3) code는 NOT_FOUND 고정 — 프론트가 상태코드 대신 코드로도 분기할 수 있다
     */
    public NotFoundException(
            // 사용자에게 그대로 노출할 업무 문구 — 기술 상세(경로·코드)는 담지 않는다
            String message
    ) {
        super("NOT_FOUND", message);
    }
}
