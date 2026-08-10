/**
 * GlobalExceptionHandler — REST 전역 예외 → ErrorResponse.
 *
 * 주요 역할:
 *     1. BizException → 400 업무 메시지
 *     2. SQLException → SqlUserMessage 변환
 *     3. 기타 → 500 + 서버 로그
 *
 * PIPELINE[HB6] 전역 예외 처리
 * PIPELINE[HB7] 연관 모듈
 */
package com.metis.haccp.common.exception;

// 역할 — API 오류 응답 DTO
import com.metis.haccp.common.response.ErrorResponse;
// 역할 — MyBatis 래핑 예외
import org.apache.ibatis.exceptions.PersistenceException;
// 역할 — SLF4J 로거
import org.slf4j.Logger;
// 역할 — 외부 타입을 현재 클래스의 선언과 처리 로직에서 사용
import org.slf4j.LoggerFactory;
// 역할 — Spring DAO 예외
import org.springframework.dao.DataAccessException;
// 역할 — HTTP 상태 코드
import org.springframework.http.HttpStatus;
// 역할 — ResponseEntity 래퍼
import org.springframework.http.ResponseEntity;
// 역할 — JSON 파싱 실패
import org.springframework.http.converter.HttpMessageNotReadableException;
// 역할 — 405 메서드 불일치
import org.springframework.web.HttpRequestMethodNotSupportedException;
// 역할 — @Valid 실패
import org.springframework.web.bind.MethodArgumentNotValidException;
// 역할 — 필수 @RequestParam 누락
import org.springframework.web.bind.MissingServletRequestParameterException;
// 역할 — @ExceptionHandler 등록
import org.springframework.web.bind.annotation.ExceptionHandler;
// 역할 — 전역 예외 처리 어드바이스
import org.springframework.web.bind.annotation.RestControllerAdvice;

// 역할 — JDBC SQL 예외
import java.sql.SQLException;

/** 전역 예외 처리 — WinForms try/catch + MessageBox 패턴을 단일 지점으로 통합. */
@RestControllerAdvice
public class GlobalExceptionHandler {

    // 서버 로그용 SLF4J Logger
    private static final Logger log = LoggerFactory.getLogger(
            GlobalExceptionHandler.class
    );

    /**
     * 개발자: 박승우
     * 일자: 2026-07-10
     * 코멘트:
     *   1) 업무 예외를 표준 400 오류 응답으로 변환한다.
     *   2) 서비스에서 BizException이 전파되었을 때 전역 예외 처리기가 호출한다.
     *   3) 성공 시 업무 코드·메시지를 반환하고 기술 상세는 사용자 응답에 노출하지 않는다.
     */
    @ExceptionHandler(BizException.class)
    public ResponseEntity<ErrorResponse> handleBiz(
            // 발생 예외 — 응답 분류와 서버 로그 기록의 원천
            // 호출부의 null·빈값 허용 여부와 변환 규칙은 메서드 본문의 기존 계약을 따른다
            BizException e
    ) {
        // 400 Bad Request + ErrorResponse(code, message)
        return ResponseEntity.badRequest().body(new ErrorResponse(e.getCode(), e.getMessage()));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) 대상 자원 부재를 404로 변환한다 — 입력 오류(400)와 구분해 프론트가 안내 문구를 고른다
     *   2) 템플릿 원본 미업로드 등 NotFoundException이 전파되었을 때 호출한다
     *   3) 사용자에게는 업무 문구만, 서버 로그에는 요청 맥락을 warn으로 남긴다
     */
    @ExceptionHandler(NotFoundException.class)
    public ResponseEntity<ErrorResponse> handleNotFound(
            // 발생 예외 — BizException 하위라 더 구체적인 이 핸들러가 먼저 매칭된다
            NotFoundException e
    ) {
        // 스택은 남기지 않는다 — 정상 업무 흐름(파일 미업로드)에서도 발생하기 때문
        log.warn("Resource not found: {}", e.getMessage());
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(new ErrorResponse(e.getCode(), e.getMessage()));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-07-10
     * 코멘트:
     *   1) Bean Validation 오류를 표준 400 응답으로 변환한다.
     *   2) 요청 DTO의 필드 제약조건 검증이 실패했을 때 호출한다.
     *   3) 첫 필드 메시지를 반환하고, 메시지가 없으면 공통 입력 오류 문구를 사용한다.
     */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidation(
            // 발생 예외 — 응답 분류와 서버 로그 기록의 원천
            // 호출부의 null·빈값 허용 여부와 변환 규칙은 메서드 본문의 기존 계약을 따른다
            MethodArgumentNotValidException e
    ) {
        // 첫 번째 필드 오류의 defaultMessage 추출
        String msg = e.getBindingResult().getFieldErrors().stream()
                .findFirst()
                .map(f -> f.getDefaultMessage())
                .orElse(
                        "입력값이 올바르지 않습니다."
                );
        // 400 + VALIDATION 코드
        return ResponseEntity.badRequest().body(new ErrorResponse("VALIDATION", msg));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-07-10
     * 코멘트:
     *   1) 지원하지 않는 HTTP 메서드 요청을 405 응답으로 변환한다.
     *   2) 경로는 존재하지만 매핑되지 않은 요청 방식이 들어왔을 때 호출한다.
     *   3) 성공 시 METHOD_NOT_ALLOWED 코드와 업무 문구를 반환한다.
     */
    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    public ResponseEntity<ErrorResponse> handleMethodNotSupported(
            // 발생 예외 — 응답 분류와 서버 로그 기록의 원천
            // 호출부의 null·빈값 허용 여부와 변환 규칙은 메서드 본문의 기존 계약을 따른다
            HttpRequestMethodNotSupportedException e
    ) {
        // 405 Method Not Allowed
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED)
                .body(
                        new ErrorResponse("METHOD_NOT_ALLOWED", "지원하지 않는 요청 방식입니다.")
                );
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) 필수 쿼리·폼 파라미터가 없을 때 500 대신 업무 400으로 내린다
     *   2) FE가 tmplCd 등 키를 빼먹고 GET 했을 때 GlobalExceptionHandler가 잡는다
     *   3) tmplCd면 양식 선택 안내, 그 외는 파라미터명을 포함한 일반 문구
     */
    @ExceptionHandler(MissingServletRequestParameterException.class)
    public ResponseEntity<ErrorResponse> handleMissingParam(
            // 누락된 요청 파라미터 예외 — 파라미터명으로 업무 문구를 고른다
            MissingServletRequestParameterException e
    ) {
        // 필수 파라미터명 — Spring이 해석한 이름
        String name = e.getParameterName();
        // tmplCd 누락일 때(= 점검항목·자사양식 목록 등) 업무 안내
        String msg = "tmplCd".equals(name)
                ? "양식 코드를 선택하세요."
                : ("필수 요청 값이 없습니다. (" + name + ")");
        return ResponseEntity.badRequest().body(new ErrorResponse("VALIDATION", msg));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-07-10
     * 코멘트:
     *   1) 읽을 수 없는 JSON 요청 본문을 400 응답으로 변환한다.
     *   2) 역직렬화 실패나 JSON 문법 오류가 발생했을 때 호출한다.
     *   3) 성공 시 BAD_REQUEST 코드와 일반화된 요청 형식 오류 문구를 반환한다.
     */
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ErrorResponse> handleBadJson(
            // 발생 예외 — 응답 분류와 서버 로그 기록의 원천
            // 호출부의 null·빈값 허용 여부와 변환 규칙은 메서드 본문의 기존 계약을 따른다
            HttpMessageNotReadableException e
    ) {
        // 요청 본문 형식 오류
        return ResponseEntity.badRequest().body(new ErrorResponse("BAD_REQUEST", "요청 형식이 올바르지 않습니다."));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-07-10
     * 코멘트:
     *   1) 직접 발생한 SQLException을 SQLSTATE 기준 응답으로 분류한다.
     *   2) JDBC 예외가 래핑되지 않고 전역 처리기로 전달될 때 호출한다.
     *   3) 성공 시 업무신호·충돌·서버오류 중 하나의 표준 응답을 반환한다.
     */
    @ExceptionHandler(SQLException.class)
    public ResponseEntity<ErrorResponse> handleSql(
            // 발생 예외 — 응답 분류와 서버 로그 기록의 원천
            // 호출부의 null·빈값 허용 여부와 변환 규칙은 메서드 본문의 기존 계약을 따른다
            SQLException e
    ) {
        // SQLSTATE 기반 분류
        return classify(e);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-07-10
     * 코멘트:
     *   1) MyBatis PersistenceException의 원인 SQL 예외를 분류한다.
     *   2) 매퍼 실행 실패가 MyBatis 예외로 래핑되어 전달될 때 호출한다.
     *   3) 성공 시 원인 SQLSTATE에 맞는 표준 응답을 반환한다.
     */
    @ExceptionHandler(PersistenceException.class)
    public ResponseEntity<ErrorResponse> handlePersistence(
            // 발생 예외 — 응답 분류와 서버 로그 기록의 원천
            // 호출부의 null·빈값 허용 여부와 변환 규칙은 메서드 본문의 기존 계약을 따른다
            PersistenceException e
    ) {
        // 원인 체인에서 SQLException 추출 후 분류
        return classify(e);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-07-10
     * 코멘트:
     *   1) Spring DataAccessException의 원인 SQL 예외를 분류한다.
     *   2) 데이터 접근 계층 예외가 Spring 예외로 변환되어 전달될 때 호출한다.
     *   3) 성공 시 원인 SQLSTATE에 맞는 표준 응답을 반환한다.
     */
    @ExceptionHandler(DataAccessException.class)
    public ResponseEntity<ErrorResponse> handleDataAccess(
            // 발생 예외 — 응답 분류와 서버 로그 기록의 원천
            // 호출부의 null·빈값 허용 여부와 변환 규칙은 메서드 본문의 기존 계약을 따른다
            DataAccessException e
    ) {
        // 원인 체인에서 SQLException 추출 후 분류
        return classify(e);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-07-10
     * 코멘트:
     *   1) 분류되지 않은 예외를 안전한 500 응답으로 변환한다.
     *   2) 전용 처리기가 없는 최종 예외가 전파되었을 때 호출한다.
     *   3) 기술 상세는 서버 로그에 남기고 사용자에게는 일반 안내 문구만 반환한다.
     */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleEtc(
            // 발생 예외 — 응답 분류와 서버 로그 기록의 원천
            // 호출부의 null·빈값 허용 여부와 변환 규칙은 메서드 본문의 기존 계약을 따른다
            Exception e
    ) {
        // 스택·root cause는 서버 로그에만 기록
        log.error(
                "Unhandled exception",
                e
        );
        // 500 Internal Server Error — 내부 정보 비노출
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(
                        new ErrorResponse("UNKNOWN", "처리 중 오류가 발생했습니다. 잠시 후 다시 시도하거나 관리자에게 문의하세요.")
                );
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-07-10
     * 코멘트:
     *   1) 예외 원인 체인의 SQLSTATE를 업무신호·충돌·서버오류로 분류한다.
     *   2) SQLException과 이를 감싼 MyBatis·Spring 예외 처리에서 공통 호출한다.
     *   3) 분류 결과에 맞는 HTTP 응답을 반환하고 알 수 없는 DB 오류는 상세 로그를 기록한다.
     */
    private ResponseEntity<ErrorResponse> classify(
            // 예외 원인 체인 시작점 — 내부 SQLException 탐색
            // 호출부의 null·빈값 허용 여부와 변환 규칙은 메서드 본문의 기존 계약을 따른다
            Throwable t
    ) {
        // 예외 체인에서 첫 SQLException 추출
        SQLException sql = sqlOf(t);
        // SQLSTATE(없으면 null)
        String state = (sql != null) ? sql.getSQLState() : null;

        // 조건식이 참일 때(= 45000: SP RAISE(업무 규칙 위반) — 업무 문구만 노출) 기존 분기 처리를 실행
        if ("45000".equals(state)) {
            // 원문·스택은 warn 로그
            log.warn(
                    "DB business signal (sqlState={}): {}",
                    state,
                    sql.getMessage(),
                    t
            );
            // 400 + SqlUserMessage 정제 메시지
            return ResponseEntity.badRequest()
                    .body(
                            new ErrorResponse("DB_SIGNAL", SqlUserMessage.toUserMessage(sql.getMessage()))
                    );
        }
        // 조건식이 참일 때(= 23505(중복키)·40P01(교착) — 동시 처리 충돌, 재시도 유도) 기존 분기 처리를 실행
        if ("23505".equals(state) || "40P01".equals(state)) {
            // 409 Conflict
            return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body(
                            new ErrorResponse("CONFLICT", "다른 사용자가 동시에 처리 중입니다. 잠시 후 다시 시도해 주세요.")
                    );
        }
        // 그 외 DB 오류 — 500 + 로그
        log.error(
                "DB error (sqlState={})",
                state,
                t
        );
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(
                        new ErrorResponse("DB_ERROR", "데이터 처리 중 오류가 발생했습니다.")
                );
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-07-10
     * 코멘트:
     *   1) 예외 원인 체인에서 최초 SQLException을 찾는다.
     *   2) SQLSTATE 분류 전에 래핑된 JDBC 원인을 추출할 때 호출한다.
     *   3) 발견 시 SQLException을 반환하고, 원인 체인에 없으면 null을 반환한다.
     */
    private static SQLException sqlOf(
            // 예외 원인 체인 시작점 — 내부 SQLException 탐색
            // 호출부의 null·빈값 허용 여부와 변환 규칙은 메서드 본문의 기존 계약을 따른다
            Throwable t
    ) {
        // cause 체인 순회
        for (Throwable c = t; c != null; c = c.getCause()) {
            // 조건식이 참일 때(= SQLException 인스턴스 발견 시 즉시 반환) 기존 분기 처리를 실행
            if (c instanceof SQLException s) return s;
        }
        // 체인에 SQLException 없음
        return null;
    }
}
