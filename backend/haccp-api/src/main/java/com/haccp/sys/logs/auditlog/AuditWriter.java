/**
 * AuditWriter — 시스템 관리 저장·삭제를 변경 감사 이력에 남기는 공용 기록기.
 *
 * 개발자: 박승우
 * 일자: 2026-08-13
 * 코멘트:
 *   1) 공통코드·메뉴·권한그룹·부서·사용자·결재선·사용양식과 문서 허브가 같은 규칙으로 이력을 남긴다
 *   2) 회사코드·행위자는 JWT, 화면코드는 요청(URL 맵·허브 헤더), IP는 현재 요청에서 뽑는다
 *   3) 원 업무 트랜잭션 안에서 호출하므로 저장이 롤백되면 이력도 함께 사라진다
 *
 * PIPELINE[HB92] 변경 감사 적재
 */
package com.haccp.sys.logs.auditlog;

// 역할 — 요청 경로에서 확정한 화면코드
import com.haccp.common.auth.ScreenAuthResolver;
// 역할 — JWT 테넌트·행위자
import com.haccp.common.context.LoginUserContext;
// 역할 — 요청 IP 추출 (로그인 이력·조회 로그와 같은 규칙)
import com.haccp.common.context.RequestMeta;
// 역할 — 업무 예외
import com.haccp.common.exception.BizException;
// 역할 — 행 payload를 JSON 문자열로 직렬화
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
// 역할 — 생성자 주입
import lombok.RequiredArgsConstructor;
// 역할 — 스프링 빈 등록
import org.springframework.stereotype.Component;
// 역할 — 컨트롤러를 거치지 않고 현재 요청 참조
import org.springframework.web.context.request.RequestAttributes;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

// 역할 — 저장 payload 정리
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

@Component
@RequiredArgsConstructor
public class AuditWriter {

    /** 값을 가리는 필드 — 사용자 저장 행에는 해시 이전 평문 비밀번호가 실려 온다 */
    private static final Set<String> MASKED_KEYS = Set.of("userpw", "password", "newpw", "pw");
    /** 가린 값 표기 — 변경했다는 사실만 남기고 내용은 남기지 않는다 */
    private static final String MASK = "***";

    // 감사 적재 SP 호출
    private final AuditLogMapper auditLogMapper;
    // 행 payload → JSON 문자열
    private final ObjectMapper objectMapper;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-13
     * 코멘트:
     *   1) 변경 감사 이력 한 건을 남긴다 — 변경 후 값만 기록한다. before 는 비운다
     *   2) 시스템 관리 5화면의 save·delete 루프 안에서 행마다 호출한다
     *   3) 직렬화에 실패하면 이력이 비는 대신 업무를 중단한다 (BizException)
     */
    public void record(
            // 대상 테이블명 — tbl_ 접두 포함
            String tblNm,
            // 대상 행 idx — 신규 등록처럼 채번 전이면 null
            Long tgtIdx,
            // 행위 — I:등록, U:수정, D:삭제
            String actionCd,
            // 변경 후 값. 삭제일 때(= 남길 값 없음) null을 넘긴다
            Object after
    ) {
        record(tblNm, tgtIdx, actionCd, null, after, "");
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-02
     * 코멘트:
     *   1) 변경 전·후와 사유를 같이 남긴다 — 문서 허브 결재·첨부가 쓴다
     *   2) 화면코드는 요청 컨텍스트에서만 읽는다. 호출부가 넘기지 않는다
     *   3) 직렬화 실패면 업무를 중단한다
     */
    public void record(
            // 대상 테이블명 — tbl_ 접두 포함
            String tblNm,
            // 대상 행 idx — 신규 등록처럼 채번 전이면 null
            Long tgtIdx,
            // 행위 — I/U/D/REQ/REV/APV/RJT/CANCEL/UNDO
            String actionCd,
            // 변경 전 값. 등록이면 null
            Object before,
            // 변경 후 값. 삭제면 null
            Object after,
            // 사유 — 반려·결재취소. 없으면 빈 문자열
            String reason
    ) {
        auditLogMapper.insertAudit(
                LoginUserContext.coCd(),
                LoginUserContext.userId(),
                currentScrnCd(),
                tblNm,
                tgtIdx,
                actionCd,
                json(before),
                json(after),
                reason == null ? "" : reason,
                clientIp());
    }

    /** 인터셉터가 붙인 화면코드. 요청 밖이면 빈 문자열 */
    private static String currentScrnCd() {
        RequestAttributes attrs = RequestContextHolder.getRequestAttributes();
        return attrs instanceof ServletRequestAttributes servlet
                ? ScreenAuthResolver.requestScreen(servlet.getRequest())
                : "";
    }

    /** 행 payload를 JSON 문자열로 바꾼다 — null이면 빈 문자열이라 SP가 NULL로 넣는다 */
    private String json(Object after) {
        if (after == null) return "";
        try {
            return objectMapper.writeValueAsString(sanitize(after));
        } catch (JsonProcessingException e) {
            throw new BizException("감사 자료를 저장 형식으로 변환하지 못했습니다.");
        }
    }

    /** 그리드 전용 필드(_rowState 등)를 버리고 비밀번호를 가린다 — Map이 아니면 그대로 둔다 */
    private Object sanitize(Object after) {
        if (!(after instanceof Map<?, ?> row)) return after;
        Map<String, Object> safe = new LinkedHashMap<>();
        for (Map.Entry<?, ?> entry : row.entrySet()) {
            String key = String.valueOf(entry.getKey());
            // _ 로 시작할 때(= _key·_rowState 같은 화면 전용 필드) 이력에 남길 값이 아니다
            if (key.startsWith("_")) continue;
            Object value = entry.getValue();
            boolean masked = MASKED_KEYS.contains(key.toLowerCase(Locale.ROOT))
                    && value != null && !String.valueOf(value).isBlank();
            safe.put(key, masked ? MASK : value);
        }
        return safe;
    }

    /** 현재 요청의 클라이언트 IP — 요청 스레드가 아니면(= 배치·스케줄러) null */
    private String clientIp() {
        RequestAttributes attrs = RequestContextHolder.getRequestAttributes();
        return attrs instanceof ServletRequestAttributes servlet
                ? RequestMeta.of(servlet.getRequest()).ipAddr()
                : null;
    }
}
