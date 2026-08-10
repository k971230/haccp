/**
 * SqlUserMessage.java — PostgreSQL JDBC 오류 메시지 사용자 문구 추출.
 *
 * 주요 역할:
 *     1. ERROR: 접두어·Where 절 제거
 *     2. SP RAISE 업무 메시지만 프론트 노출
 *
 * PIPELINE[HB7] 예외 처리
 * PIPELINE[HB6] 연관 모듈
 */
package com.metis.haccp.common.exception;

/** PostgreSQL JDBC SQLException 메시지에서 사용자 노출용 업무 문구만 추출. */
public final class SqlUserMessage {

    // 인스턴스화 금지
    /**
     * 개발자: 박승우
     * 일자: 2026-07-10
     * 코멘트:
     *   1) SqlUserMessage 메서드가 담당하는 입력 검증과 업무 처리를 수행한다.
     *   2) 호출 계약에 따라 파라미터를 전달받아 기존 처리 순서를 그대로 실행한다.
     *   3) 성공 시 선언된 반환값을 제공하고, 실패 시 기존 예외를 호출부로 전파한다.
     */
    private SqlUserMessage() {}

    /**
     * 개발자: 박승우
     * 일자: 2026-07-10
     * 코멘트:
     *   1) PostgreSQL 오류 원문에서 사용자 노출용 업무 문구만 추출한다.
     *   2) SQLSTATE 45000 업무신호를 HTTP 오류 메시지로 변환할 때 호출한다.
     *   3) 성공 시 기술 Where 절을 제거한 문구를 반환하고, 빈 입력이면 기본 문구를 반환한다.
     */
    public static String toUserMessage(
            // PostgreSQL JDBC 오류 원문 — 기술 정보를 제거할 입력
            // 호출부의 null·빈값 허용 여부와 변환 규칙은 메서드 본문의 기존 계약을 따른다
            String raw
    ) {
        // 조건식이 참일 때(= null 또는 공백이면 기본 안내 문구) 기존 분기 처리를 실행
        if (raw == null || raw.isBlank()) {
            return "처리할 수 없습니다.";
        }
        // 앞뒤 공백 제거
        String msg = raw.strip();
        // 조건식이 참일 때(= "ERROR:" 접두어(대소문자 무시) 제거) 기존 분기 처리를 실행
        if (msg.regionMatches(true, 0, "ERROR:", 0, 6)) {
            msg = msg.substring(6).strip();
        }
        // PL/pgSQL Where 절 위치 탐색
        int cut = indexOfWhereClause(msg);
        // 조건식이 참일 때(= 해당 업무 분기) 기존 처리 순서를 유지) 기존 분기 처리를 실행
        if (cut >= 0) {
            // Where 절 이전까지만 업무 메시지로 사용
            msg = msg.substring(0, cut).strip();
        }
        // 추출 결과가 비었으면 기본 문구, 아니면 정제된 메시지
        return msg.isEmpty() ? "처리할 수 없습니다." : msg;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-07-10
     * 코멘트:
     *   1) PostgreSQL 오류 메시지에서 기술 Where 절의 시작 위치를 찾는다.
     *   2) 사용자 문구를 자르기 위해 여러 JDBC 출력 형식을 순서대로 검사할 때 호출한다.
     *   3) 패턴을 찾으면 인덱스를 반환하고, 없으면 -1을 반환한다.
     */
    private static int indexOfWhereClause(
            // 오류 또는 사용자 메시지 — 응답 본문과 검증 예외에 사용
            // 호출부의 null·빈값 허용 여부와 변환 규칙은 메서드 본문의 기존 계약을 따른다
            String msg
    ) {
        // 줄바꿈+공백+Where: 패턴(가장 흔한 PG 형식)
        int i = msg.indexOf("\n  Where:");
        // 조건식이 참일 때(= 해당 업무 분기) 기존 처리 순서를 유지) 기존 분기 처리를 실행
        if (i >= 0) return i;
        // 줄바꿈+Where: 패턴
        i = msg.indexOf("\nWhere:");
        // 조건식이 참일 때(= 해당 업무 분기) 기존 처리 순서를 유지) 기존 분기 처리를 실행
        if (i >= 0) return i;
        // 한 줄 내 Where: PL/pgSQL 패턴
        i = msg.indexOf(" Where: PL/pgSQL");
        // 조건식이 참일 때(= 해당 업무 분기) 기존 처리 순서를 유지) 기존 분기 처리를 실행
        if (i >= 0) return i;
        // 일반 Where: 패턴(최후 수단)
        return msg.indexOf(" Where:");
    }
}
