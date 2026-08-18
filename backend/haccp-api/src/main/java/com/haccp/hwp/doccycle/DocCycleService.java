/**
 * DocCycleService — 문서주기관리(양식별 작성주기) 업무 서비스.
 *
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) 주기 저장 직후 CycleScheduleGenerator로 예정일을 다시 만들어 화면 저장과 배치 결과가 같게 한다
 *   2) 규칙 검증은 SP(45000 업무 예외)와 이 서비스 양쪽에서 하고, 삭제는 validate-delete·delete Double Check다
 *   3) coCd·작업자는 요청 본문을 믿지 않고 JWT LoginUserContext에서만 읽는다 (배치는 'system')
 *
 * PIPELINE[HB99] 문서주기 업무 서비스
 * PIPELINE[HB94, HB98] 연관 모듈
 */
package com.haccp.hwp.doccycle;

// 역할 — JSON 변환 (payload·details·dates)
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
// 역할 — 삭제 키 DTO
import com.haccp.hwp.doccycle.dto.DocCycleDeleteItem;
// 역할 — JWT 컨텍스트·업무 예외
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
// 역할 — 날짜 계산·컬렉션
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
// 역할 — Spring 서비스·설정 값·트랜잭션
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class DocCycleService {

    private static final DateTimeFormatter YMD = DateTimeFormatter.BASIC_ISO_DATE;

    private final DocCycleMapper mapper;
    private final CycleScheduleGenerator generator;
    private final ObjectMapper objectMapper;

    // 마감 몇 분 전에 알릴지 — 매직넘버 금지(OPS_GLOBAL_CONFIG), alarm_dt 계산에 그대로 쓴다
    @Value("${app.schedule.alarm-before-minutes:60}")
    private int alarmBeforeMinutes;

    // 예정일을 몇 개월치 미리 만들지 — 길면 규칙 변경 시 정리 대상이 늘고, 짧으면 달력이 비어 보인다
    @Value("${app.schedule.generate-months:12}")
    private int generateMonths;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 좌측 양식 목록 — 사용여부 검색 + 구분 + 주기 등록여부
     *   2) 화면 진입·조회 버튼에서 호출한다
     *   3) 성공 시 camelCase 행 배열, 조건이 비면 회사 전체(사용여부 기본은 화면이 Y)
     */
    public List<Map<String, Object>> forms(
            // 양식코드 검색어 — null·공백이면 전체
            String tmplCd,
            // 양식명 검색어 — null·공백이면 전체
            String tmplNm,
            // 사용여부 Y/N — null·공백이면 전체
            String useYn
    ) {
        return mapper.selectForms(LoginUserContext.coCd(), text(tmplCd), text(tmplNm), text(useYn));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 선택 양식의 주기 1건을 반복 상세 배열까지 펼쳐 반환한다
     *   2) 좌측 행 선택 시 우측 폼을 채우기 위해 호출한다
     *   3) 주기 미설정일 때(= 신규 등록 대상) null을 돌려 화면이 빈 폼을 띄운다
     */
    public Map<String, Object> cycle(
            // 좌측에서 선택한 양식코드 — 필수
            String tmplCd
    ) {
        String code = requireTmplCd(tmplCd);
        List<Map<String, Object>> rows = mapper.selectCycle(LoginUserContext.coCd(), code);
        if (rows == null || rows.isEmpty()) return null;
        Map<String, Object> row = rows.get(0);
        // details는 jsonb::text로 내려오므로 화면 계약(배열)으로 바꿔 준다
        row.put("details", parseDetails(row.get("details")));
        return row;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 주기 1건을 업서트하고 같은 트랜잭션에서 예정일을 다시 만든다
     *   2) 우측 폼 저장 버튼에서 호출하며, 사용유무가 N이면 미래 예정일이 정리된다
     *   3) 실패 시 규칙·예정일이 함께 롤백돼 반쪽 저장이 남지 않는다
     */
    @Transactional(timeout = 60)
    public void save(
            // 화면 폼 1건 — tmplCd·baseDt·cycleCd·nonworkRule·dueTime·deptCd·userId·useYn·details[]
            Map<String, Object> row
    ) {
        if (row == null) throw new BizException("저장할 문서주기 자료가 없습니다.");
        String coCd = LoginUserContext.coCd();
        String tmplCd = requireTmplCd(str(row.get("tmplCd")));
        String userId = LoginUserContext.userId();
        try {
            mapper.saveCycle(coCd, objectMapper.writeValueAsString(row), userId);
        } catch (JsonProcessingException e) {
            throw new BizException("문서주기 저장 자료 형식이 올바르지 않습니다.");
        }
        // 저장 결과를 다시 읽어 SP가 보정한 값(기본 마감시각·사용유무)으로 예정일을 만든다
        List<Map<String, Object>> saved = mapper.selectCycle(coCd, tmplCd);
        if (saved != null && !saved.isEmpty()) regenerate(coCd, saved.get(0), userId);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 삭제 전 키 형식과 주기 존재 여부를 검사한다
     *   2) FE가 확인창 앞에서 호출하며 delete에서도 같은 검증을 반복한다
     *   3) 성공 시 void — 주기가 없으면 업무 문구로 막는다
     */
    public void validateDelete(
            // 삭제 대상 복합키 배열 — UI 단건이어도 1건 배열
            List<DocCycleDeleteItem> keys
    ) {
        assertDeletable(keys);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 주기·반복 상세를 지우고 미래 미작성 예정일만 정리한다
     *   2) 확인창 이후 호출하며 validate-delete와 같은 검증을 다시 수행한다(Double Check)
     *   3) 실패 시 전건 롤백 — 일부만 지워진 상태를 남기지 않는다
     */
    @Transactional(timeout = 60)
    public void delete(
            // 삭제 대상 복합키 배열
            List<DocCycleDeleteItem> keys
    ) {
        assertDeletable(keys);
        String coCd = LoginUserContext.coCd();
        String userId = LoginUserContext.userId();
        for (DocCycleDeleteItem key : keys) mapper.deleteCycle(coCd, text(key.getTmplCd()), userId);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 활성 주기 전건의 예정일을 오늘 기준으로 다시 만든다
     *   2) DailyTaskGenerationJob이 오늘 과제 생성 직전에 호출한다
     *   3) TaskService.generateAllCompanies와 같이 배치 1회를 한 트랜잭션으로 묶는다
     */
    @Transactional(timeout = 60)
    public void regenerateAllCompanies() {
        List<Map<String, Object>> rules = mapper.selectActiveCycles();
        if (rules == null) return;
        for (Map<String, Object> rule : rules) {
            regenerate(str(rule.get("coCd")), rule, "system");
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 마감 임박 예정일의 알림을 적재한다
     *   2) DocumentAlarmScheduler가 주기적으로 호출한다
     *   3) 발송 플래그로 중복 알림을 막는다
     */
    @Transactional(timeout = 60)
    public void sendTaskAlarms() {
        mapper.sendTaskAlarms("system");
    }

    /** 규칙을 예정일 배열로 바꿔 tbl_schedule_task에 반영한다. */
    private void regenerate(String coCd, Map<String, Object> rule, String userId) {
        String tmplCd = str(rule.get("tmplCd"));
        // 사용유무 N일 때(= 주기 중지) 빈 배열을 넘겨 미래 미작성 예정일을 정리한다
        boolean active = !"N".equalsIgnoreCase(str(rule.get("useYn")));
        List<String> dates = active ? generateDates(rule) : List.of();
        try {
            mapper.regenerateTasks(
                    coCd, tmplCd, objectMapper.writeValueAsString(dates),
                    str(rule.get("dueTime")), nullIfBlank(str(rule.get("deptCd"))),
                    nullIfBlank(str(rule.get("userId"))), alarmBeforeMinutes, userId
            );
        } catch (JsonProcessingException e) {
            throw new BizException("문서주기 예정일 생성 자료 형식이 올바르지 않습니다.");
        }
    }

    /** 규칙 1건의 예정일을 yyyyMMdd 문자열 배열로 만든다. */
    private List<String> generateDates(Map<String, Object> rule) {
        LocalDate startDt = parseYmd(str(rule.get("baseDt")));
        if (startDt == null) throw new BizException("관리 시작일을 입력하세요.");
        List<CycleScheduleGenerator.Detail> details = new ArrayList<>();
        for (Map<String, Object> detail : parseDetails(rule.get("details"))) {
            details.add(new CycleScheduleGenerator.Detail(
                    str(detail.get("detailTy")), intOrNull(detail.get("val1")), intOrNull(detail.get("val2"))));
        }
        CycleScheduleGenerator.Rule spec = new CycleScheduleGenerator.Rule(
                str(rule.get("cycleCd")), str(rule.get("nonworkRule")), startDt, details);
        // LinkedHashSet — 생성기가 정렬해 주지만 문자열 변환 후에도 중복이 없음을 보장한다
        Set<String> out = new LinkedHashSet<>();
        for (LocalDate date : generator.generate(spec, LocalDate.now(), generateMonths)) out.add(date.format(YMD));
        return new ArrayList<>(out);
    }

    /** jsonb::text 또는 화면 배열을 상세 Map 목록으로 통일한다. */
    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> parseDetails(Object value) {
        if (value == null) return List.of();
        if (value instanceof List<?> list) return (List<Map<String, Object>>) list;
        String json = value.toString().trim();
        if (json.isEmpty()) return List.of();
        try {
            return objectMapper.readValue(json, new TypeReference<List<Map<String, Object>>>() {});
        } catch (JsonProcessingException e) {
            throw new BizException("문서주기 반복 설정 형식이 올바르지 않습니다.");
        }
    }

    /** 삭제 키 형식 + 주기 존재 여부 검사 — validate-delete·delete가 같은 메서드를 쓴다. */
    private void assertDeletable(List<DocCycleDeleteItem> keys) {
        if (keys == null || keys.isEmpty()) throw new BizException("삭제할 문서주기를 선택하세요.");
        String coCd = LoginUserContext.coCd();
        for (DocCycleDeleteItem key : keys) {
            if (key == null) throw new BizException("삭제할 문서주기 키가 올바르지 않습니다.");
            String tmplCd = requireTmplCd(key.getTmplCd());
            List<Map<String, Object>> rows = mapper.selectCycle(coCd, tmplCd);
            if (rows == null || rows.isEmpty()) {
                throw new BizException("삭제할 문서주기가 없습니다. 양식코드 '" + tmplCd + "'");
            }
        }
    }

    private String requireTmplCd(String tmplCd) {
        String code = text(tmplCd);
        if (code.isEmpty()) throw new BizException("양식을 선택하세요.");
        return code;
    }

    /** yyyyMMdd 또는 yyyy-MM-dd 를 LocalDate로 바꾼다. 형식이 아니면 null */
    private LocalDate parseYmd(String value) {
        String digits = text(value).replaceAll("[^0-9]", "");
        if (digits.length() != 8) return null;
        try {
            return LocalDate.parse(digits, YMD);
        } catch (java.time.format.DateTimeParseException e) {
            return null;
        }
    }

    private Integer intOrNull(Object value) {
        if (value == null) return null;
        String digits = value.toString().trim();
        if (digits.isEmpty()) return null;
        try {
            return Integer.valueOf(digits);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private String str(Object value) { return value == null ? "" : value.toString().trim(); }
    private String text(String value) { return value == null ? "" : value.trim(); }
    private String nullIfBlank(String value) { return value == null || value.isBlank() ? null : value; }
}
