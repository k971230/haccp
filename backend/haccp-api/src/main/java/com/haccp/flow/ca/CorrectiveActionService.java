/**
 * CorrectiveActionService — 개선조치관리 화면 업무 서비스.
 *
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 목록·저장·삭제만 담당한다 — 문서에 딸린 개선조치는 DocCorrectiveSupport 몫이다
 *   2) 회사코드·작업자는 JWT 에서만 읽는다 — 본문 값을 쓰면 남의 회사 자료를 만진다
 *   3) 삭제는 validate-delete → delete 두 단계이고 SP 가 완료 상태를 다시 막는다
 *
 * PIPELINE[HB94] 개선조치관리 업무 서비스
 */
package com.haccp.flow.ca;

// 역할 — 화면 행 JSON 직렬화
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
// 역할 — JWT 컨텍스트·업무 예외
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
// 역할 — 삭제 대상 검증 공통
import com.haccp.common.validation.DeleteValidation;
// 역할 — 목록·맵
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
// 역할 — Spring 서비스·트랜잭션
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CorrectiveActionService {

    private final CorrectiveActionMapper mapper;
    private final ObjectMapper objectMapper;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-26
     * 코멘트:
     *   1) 기간·양식·작성자 조건으로 개선조치 목록을 조회한다
     *   2) SP Map snake_case 를 camelCase 로 바꿔 그리드 field 가 비지 않게 한다
     *   3) 공백 조건은 SP 가 전체로 본다
     */
    public List<Map<String, Object>> correctiveActions(
            // 시작일 YYYYMMDD — 공백이면 전체
            String fromDt,
            // 종료일 YYYYMMDD — 공백이면 전체
            String toDt,
            // 양식코드 — 공백이면 전체
            String tmplCd,
            // 작성자 — 공백이면 전체
            String writer
    ) {
        return camelRows(mapper.selectCorrectiveActions(
                LoginUserContext.coCd(), text(fromDt), text(toDt), text(tmplCd), text(writer)));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-26
     * 코멘트:
     *   1) 개선조치를 신규·수정 저장한다 — idx 가 없으면 SP 가 신규로 본다
     *   2) 화면 저장 버튼이 신규·수정 구분 없이 호출한다
     *   3) 행 전체를 jsonb 로 넘긴다 — 칸이 늘어도 SP 만 고치면 된다
     */
    @Transactional
    public void saveCorrectiveAction(
            // 대리키 — null 이면 신규
            Long idx,
            // 화면 행
            Map<String, Object> payload
    ) {
        if (payload == null) throw new BizException("저장할 개선조치 자료가 없습니다.");
        try {
            mapper.saveCorrectiveAction(
                    LoginUserContext.coCd(), idx,
                    objectMapper.writeValueAsString(payload), LoginUserContext.userId());
        } catch (JsonProcessingException e) {
            throw new BizException("개선조치 저장 자료 형식이 올바르지 않습니다.");
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-26
     * 코멘트:
     *   1) 삭제 가능 여부만 검사하고 자료는 건드리지 않는다
     *   2) 화면이 삭제 확인창을 열기 전에 호출한다
     *   3) 완료 상태 검사는 SP 가 다시 한다 (Double Check)
     */
    public void validateCorrectiveActionDelete(
            // 삭제 키 객체 배열 — 단건도 [{ idx }]
            List<Map<String, Long>> keys
    ) {
        normalizeKeys(keys);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-26
     * 코멘트:
     *   1) validate-delete 와 같은 검사를 다시 한 뒤 지운다
     *   2) 화면 삭제 확인창에서 호출한다
     *   3) 완료된 건은 SP 가 막는다
     */
    @Transactional
    public void deleteCorrectiveActions(
            // 삭제 키 객체 배열 — 단건도 [{ idx }]
            List<Map<String, Long>> keys
    ) {
        normalizeKeys(keys);
        String coCd = LoginUserContext.coCd();
        String userId = LoginUserContext.userId();
        for (Map<String, Long> key : keys) mapper.deleteCorrectiveAction(coCd, key.get("idx"), userId);
    }

    /** 삭제 키를 검사한다 — 비었거나 idx 가 없으면 여기서 막는다 */
    private void normalizeKeys(List<Map<String, Long>> keys) {
        DeleteValidation.requireItems(keys, "삭제할 개선조치를 선택하세요.");
        for (Map<String, Long> key : keys) {
            DeleteValidation.requirePositive(
                    key == null ? null : key.get("idx"), "삭제할 개선조치를 선택하세요.");
        }
    }

    /** SP snake_case 결과를 화면 계약(camelCase)으로 바꾼다 */
    private List<Map<String, Object>> camelRows(List<Map<String, Object>> rows) {
        List<Map<String, Object>> out = new ArrayList<>();
        if (rows == null) return out;
        for (Map<String, Object> row : rows) {
            Map<String, Object> camel = new LinkedHashMap<>();
            if (row != null) {
                for (Map.Entry<String, Object> e : row.entrySet()) camel.put(toCamelKey(e.getKey()), e.getValue());
            }
            out.add(camel);
        }
        return out;
    }

    /** action_desc -> actionDesc */
    private String toCamelKey(String key) {
        if (key == null || key.isBlank() || !key.contains("_")) return key;
        StringBuilder sb = new StringBuilder();
        boolean upper = false;
        for (int i = 0; i < key.length(); i++) {
            char ch = key.charAt(i);
            if (ch == '_') { upper = true; continue; }
            sb.append(upper ? Character.toUpperCase(ch) : ch);
            upper = false;
        }
        return sb.toString();
    }

    private String text(String value) {
        return value == null ? "" : value.trim();
    }
}
