/**
 * TaskService — 오늘 과제·알림 업무 서비스.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 오늘 할 일 조회 전에 해당 회사 과제를 멱등 보정해 배치 누락에도 업무가 끊기지 않는다
 *   2) 개선조치·알림 변경은 JWT 테넌트·사용자만 사용한다
 *   3) 삭제는 validate-delete와 delete에서 같은 키 검증을 수행한다
 *
 * PIPELINE[HB94] 워크플로 작업 서비스
 * PIPELINE[HB93, HB95, HF87] 연관 모듈
 */
package com.haccp.board;

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
    public List<com.haccp.board.dto.TodayTaskRow> todayTasks() {
        String coCd = LoginUserContext.coCd();
        mapper.generateTasks(coCd, today(), LoginUserContext.userId());
        return mapper.selectTodayTasks(coCd, LoginUserContext.userId(), today());
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-03
     * 코멘트:
     *   1) 오늘 할 일 최근 문서를 OFFSET/LIMIT 으로 조회한다 — 본인 작성분만
     *   2) 랜딩 최근 문서 패널이 fromDt·toDt·offset·limit 을 넘긴다
     *   3) 응답은 rows + total. total 은 첫 행 totalCnt, 0건이면 0
     */
    public com.haccp.board.dto.TodayTaskDocsResponse todayTaskDocs(
            // 기준일 시작 YYYYMMDD
            String fromDt,
            // 기준일 종료 YYYYMMDD
            String toDt,
            // 건너뛸 행 수 — null·음수면 0
            Integer offset,
            // 가져올 행 수 — 1 미만이면 1, 100 초과면 100
            Integer limit
    ) {
        int off = offset == null || offset < 0 ? 0 : offset;
        int lim = limit == null || limit < 1 ? 1 : Math.min(limit, 100);
        // coCd·userId: JWT — SP writer_id 필터로 내가 쓴 문서만
        List<com.haccp.board.dto.TodayTaskDocRow> rows = mapper.selectTodayTaskDocs(
                LoginUserContext.coCd(), LoginUserContext.userId(), text(fromDt), text(toDt), off, lim);
        if (rows == null) rows = List.of();
        int total = 0;
        if (!rows.isEmpty() && rows.get(0).getTotalCnt() != null) {
            total = rows.get(0).getTotalCnt();
            for (com.haccp.board.dto.TodayTaskDocRow row : rows) {
                row.setTotalCnt(null);
            }
        }
        com.haccp.board.dto.TodayTaskDocsResponse out = new com.haccp.board.dto.TodayTaskDocsResponse();
        out.setRows(rows);
        out.setTotal(total);
        return out;
    }

    /** 로그인 사용자의 알림 목록을 반환한다. */
    public List<com.haccp.board.dto.NotificationRow> notifications() {
        return mapper.selectNotifications(LoginUserContext.coCd(), LoginUserContext.userId());
    }

    /** 알림을 읽음으로 변경한다. */
    @Transactional
    public void readNotification(Long idx) {
        mapper.readNotification(LoginUserContext.coCd(), DeleteValidation.requirePositive(idx, "알림번호가 올바르지 않습니다."), LoginUserContext.userId());
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

    /** 목록 Map 행을 camelCase 키로 복사한다. */
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
