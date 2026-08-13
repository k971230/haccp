/**
 * CommonResponse.java — API 공통 응답 래퍼.
 *
 * 주요 역할:
 *     1. { success, code, message, data } 표준 형식
 *     2. ok/fail 정적 팩토리
 *
 * PIPELINE[HB9] common 모듈
 */
package com.haccp.common.response;

// 역할 — @Getter — 필드 접근자
import lombok.Getter;

/** 공통 응답 DTO — { success, code, message, data } */
@Getter
public class CommonResponse<T> {
    // 성공 여부
    private final boolean success;
    // 결과 코드(성공 시 "OK")
    private final String code;
    // 부가 메시지(성공 시 null 가능)
    private final String message;
    // 실제 페이로드(목록·단건·null)
    private final T data;

    // private 생성자 — 정적 팩토리로만 생성
    /**
     * 개발자: 박승우
     * 일자: 2026-07-10
     * 코멘트:
     *   1) CommonResponse 메서드가 담당하는 입력 검증과 업무 처리를 수행한다.
     *   2) 호출 계약에 따라 파라미터를 전달받아 기존 처리 순서를 그대로 실행한다.
     *   3) 성공 시 선언된 반환값을 제공하고, 실패 시 기존 예외를 호출부로 전파한다.
     */
    private CommonResponse(
            // 처리 성공 여부 — 공통 응답 success 필드에 저장
            // 호출부의 null·빈값 허용 여부와 변환 규칙은 메서드 본문의 기존 계약을 따른다
            boolean success,
            // 응답 또는 업무 오류 코드 — 프론트 분기 식별자
            // 호출부의 null·빈값 허용 여부와 변환 규칙은 메서드 본문의 기존 계약을 따른다
            String code,
            // 검증 실패 시 사용자에게 전달할 업무 문구
            // 호출부의 null·빈값 허용 여부와 변환 규칙은 메서드 본문의 기존 계약을 따른다
            String message,
            // 응답 데이터 — 목록·단건·영향 행 수 등 실제 페이로드
            // 호출부의 null·빈값 허용 여부와 변환 규칙은 메서드 본문의 기존 계약을 따른다
            T data
    ) {
        // 필드 초기화
        this.success = success;
        this.code = code;
        this.message = message;
        this.data = data;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-07-10
     * 코멘트:
     *   1) 성공 결과를 공통 API 응답 형식으로 생성한다.
     *   2) 컨트롤러가 조회·저장 결과와 선택 메시지를 반환할 때 호출한다.
     *   3) success=true와 OK 코드를 가진 응답을 반환하며 data는 null도 허용한다.
     */
    public static <T> CommonResponse<T> ok(
            // 응답 데이터 — 목록·단건·영향 행 수 등 실제 페이로드
            // 호출부의 null·빈값 허용 여부와 변환 규칙은 메서드 본문의 기존 계약을 따른다
            T data
    ) {
        // success=true, code=OK, message=null
        return new CommonResponse<>(true, "OK", null, data);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-07-10
     * 코멘트:
     *   1) 성공 결과를 공통 API 응답 형식으로 생성한다.
     *   2) 컨트롤러가 조회·저장 결과와 선택 메시지를 반환할 때 호출한다.
     *   3) success=true와 OK 코드를 가진 응답을 반환하며 data는 null도 허용한다.
     */
    public static <T> CommonResponse<T> ok(
            // 응답 데이터 — 목록·단건·영향 행 수 등 실제 페이로드
            // 호출부의 null·빈값 허용 여부와 변환 규칙은 메서드 본문의 기존 계약을 따른다
            T data,
            // 검증 실패 시 사용자에게 전달할 업무 문구
            // 호출부의 null·빈값 허용 여부와 변환 규칙은 메서드 본문의 기존 계약을 따른다
            String message
    ) {
        // success=true, code=OK, 지정 message
        return new CommonResponse<>(true, "OK", message, data);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-07-10
     * 코멘트:
     *   1) 실패 코드와 사용자 메시지를 공통 API 응답 형식으로 생성한다.
     *   2) 예외 대신 명시적 실패 응답이 필요한 호출부에서 사용한다.
     *   3) success=false와 null data를 가진 응답을 반환한다.
     */
    public static <T> CommonResponse<T> fail(
            // 응답 또는 업무 오류 코드 — 프론트 분기 식별자
            // 호출부의 null·빈값 허용 여부와 변환 규칙은 메서드 본문의 기존 계약을 따른다
            String code,
            // 검증 실패 시 사용자에게 전달할 업무 문구
            // 호출부의 null·빈값 허용 여부와 변환 규칙은 메서드 본문의 기존 계약을 따른다
            String message
    ) {
        // success=false, data=null
        return new CommonResponse<>(false, code, message, null);
    }
}
