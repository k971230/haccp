/**
 * TaskService — 오늘 과제·알림·개선조치·문서관계·감사자료 업무 서비스.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 오늘 할 일 조회 전에 해당 회사 과제를 멱등 보정해 배치 누락에도 업무가 끊기지 않는다
 *   2) 개선조치·알림·문서 관계 변경은 JWT 테넌트·사용자만 사용한다
 *   3) 삭제는 validate-delete와 delete에서 같은 키 검증을 수행한다
 *
 * PIPELINE[HB94] 워크플로 작업 서비스
 * PIPELINE[HB93, HB95, HF87] 연관 모듈
 */
package com.haccp.tsk;

// 역할 — JSON 변환
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
// 역할 — JWT 컨텍스트·업무 예외·삭제 키 검증
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
import com.haccp.common.validation.DeleteValidation;
// 역할 — 날짜·컬렉션
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
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
public class TaskService {
    private static final DateTimeFormatter YMD = DateTimeFormatter.BASIC_ISO_DATE;
    private final TaskMapper mapper;
    private final ObjectMapper objectMapper;

    /** 오늘 과제 생성 보정 뒤 과제 목록을 반환한다. */
    @Transactional
    public List<Map<String, Object>> todayTasks() {
        String coCd = LoginUserContext.coCd();
        mapper.generateTasks(coCd, today(), LoginUserContext.userId());
        return mapper.selectTodayTasks(coCd, LoginUserContext.userId(), today());
    }

    /** 로그인 사용자의 알림 목록을 반환한다. */
    public List<Map<String, Object>> notifications() {
        return mapper.selectNotifications(LoginUserContext.coCd(), LoginUserContext.userId());
    }

    /** 알림을 읽음으로 변경한다. */
    @Transactional
    public void readNotification(Long idx) {
        mapper.readNotification(LoginUserContext.coCd(), DeleteValidation.requirePositive(idx, "알림번호가 올바르지 않습니다."), LoginUserContext.userId());
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 기간·상태 조건으로 개선조치 목록을 조회한다
     *   2) SP Map snake_case를 camelCase로 바꿔 그리드 field가 비지 않게 한다
     *   3) 공백 조건은 SP에서 전체로 본다
     */
    public List<Map<String, Object>> correctiveActions(String status, String fromDt, String toDt) {
        return camelRows(mapper.selectCorrectiveActions(
                LoginUserContext.coCd(), text(status), text(fromDt), text(toDt)));
    }

    /** 개선조치를 신규·수정 저장한다. */
    @Transactional
    public void saveCorrectiveAction(Long idx, Map<String, Object> payload) {
        if (payload == null) throw new BizException("저장할 개선조치 자료가 없습니다.");
        try {
            mapper.saveCorrectiveAction(LoginUserContext.coCd(), idx, objectMapper.writeValueAsString(payload), LoginUserContext.userId());
        } catch (JsonProcessingException e) {
            throw new BizException("개선조치 저장 자료 형식이 올바르지 않습니다.");
        }
    }

    /** 삭제 전 키·완료 상태를 검사한다. SP도 완료 상태를 다시 검사한다. */
    public void validateCorrectiveActionDelete(List<Map<String, Long>> keys) {
        normalizeKeys(keys);
    }

    /** 미완료 개선조치를 삭제한다. */
    @Transactional
    public void deleteCorrectiveActions(List<Map<String, Long>> keys) {
        normalizeKeys(keys);
        for (Map<String, Long> key : keys) mapper.deleteCorrectiveAction(LoginUserContext.coCd(), key.get("idx"), LoginUserContext.userId());
    }

    /** 문서 상세 패널의 관계 목록을 반환한다. */
    public List<Map<String, Object>> relations(Long docIdx) {
        return mapper.selectRelations(LoginUserContext.coCd(), DeleteValidation.requirePositive(docIdx, "문서번호가 올바르지 않습니다."));
    }

    /** 고정 관계 유형과 두 문서를 연결한다. */
    @Transactional
    public void saveRelation(Long srcDocIdx, String relType, Long tgtDocIdx) {
        String type = text(relType);
        if (!List.of("PLAN_REPORT", "tmpl_admin-edu-plan_LOG", "tmpl_prp-calib-target_LOG", "RECV_INVENTORY").contains(type)) {
            throw new BizException("문서 관계 구분이 올바르지 않습니다.");
        }
        mapper.saveRelation(LoginUserContext.coCd(), DeleteValidation.requirePositive(srcDocIdx, "출발 문서번호가 올바르지 않습니다."), type, DeleteValidation.requirePositive(tgtDocIdx, "대상 문서번호가 올바르지 않습니다."), LoginUserContext.userId());
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-11
     * 코멘트:
     *   1) 감사 출력 문서 묶음 조회 — G-14 동결 유지(FE UI 없음)
     *   2) snake_case → camelCase 변환으로 계약키(docIdx)를 유지한다
     *   3) 기간·상태는 비어 있을 때(= 전체) SP 조건으로 그대로 전달한다
     */
    @Deprecated(since = "STEP-20-G14", forRemoval = false)
    public List<Map<String, Object>> auditExport(String fromDt, String toDt, String status) {
        return camelRows(mapper.selectAuditExport(
                LoginUserContext.coCd(), text(fromDt), text(toDt), text(status)));
    }

    /** Spring 정기 작업이 활성 회사 전체의 오늘 과제를 생성한다. */
    @Transactional
    public void generateAllCompanies() {
        for (String coCd : mapper.selectCompanyCodes()) mapper.generateTasks(coCd, today(), "system");
    }

    private void normalizeKeys(List<Map<String, Long>> keys) {
        if (keys == null || keys.isEmpty()) throw new BizException("삭제할 개선조치를 선택하세요.");
        for (Map<String, Long> key : keys) {
            if (key == null) throw new BizException("삭제할 개선조치 키가 올바르지 않습니다.");
            key.put("idx", DeleteValidation.requirePositive(key.get("idx"), "삭제할 개선조치 키가 올바르지 않습니다."));
        }
    }
    private String today() { return LocalDate.now().format(YMD); }
    private String text(String value) { return value == null ? "" : value.trim(); }

    /** 목록·관계 Map 행을 camelCase 키로 복사한다. */
    private List<Map<String, Object>> camelRows(List<Map<String, Object>> rows) {
        List<Map<String, Object>> out = new ArrayList<>();
        if (rows == null) return out;
        for (Map<String, Object> row : rows) {
            if (row == null) continue;
            Map<String, Object> camel = new LinkedHashMap<>();
            for (Map.Entry<String, Object> entry : row.entrySet()) {
                camel.put(toCamelKey(entry.getKey()), entry.getValue());
            }
            out.add(camel);
        }
        return out;
    }

    /** doc_idx → docIdx — MyBatis map 키를 프런트 API 계약의 camelCase로 변환한다. */
    private String toCamelKey(String key) {
        if (key == null || key.isBlank() || !key.contains("_")) return key;
        String lower = key.toLowerCase(java.util.Locale.ROOT);
        StringBuilder out = new StringBuilder();
        boolean upper = false;
        for (char ch : lower.toCharArray()) {
            if (ch == '_') {
                upper = true;
            } else {
                out.append(upper ? Character.toUpperCase(ch) : ch);
                upper = false;
            }
        }
        return out.toString();
    }
}
