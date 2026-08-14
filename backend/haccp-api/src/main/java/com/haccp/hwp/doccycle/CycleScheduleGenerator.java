/**
 * CycleScheduleGenerator — 문서주기 규칙을 실제 예정일 목록으로 바꾸는 순수 계산기.
 *
 * 개발자: 박승우
 * 일자: 2026-08-14
 * 코멘트:
 *   1) 규칙 해석(말일 보정·31일·비영업일 이동·관리 시작일 경계)을 이 한 곳에만 둔다 — SQL/SP는 날짜 배열만 받는다
 *   2) 문서주기관리 저장 직후와 일일 배치(DailyTaskGenerationJob)가 같은 메서드를 호출해 결과가 어긋나지 않는다
 *   3) DB·JWT를 보지 않는 계산 전용 클래스라 CycleScheduleGeneratorTest로 값 검증이 가능하다
 *
 * PIPELINE[HB98] 문서주기 예정일 생성기
 * PIPELINE[HB94, HB99] 연관 모듈
 */
package com.haccp.hwp.doccycle;

// 역할 — 날짜 계산
import java.time.DayOfWeek;
import java.time.LocalDate;
// 역할 — 결과 중복 제거·정렬
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.TreeSet;
// 역할 — Spring 빈 등록 (상태 없음)
import org.springframework.stereotype.Component;

@Component
public class CycleScheduleGenerator {

    /** 반복 상세 1건 — tbl_schedule_rule_detail 1행에 대응한다. */
    public record Detail(
            // detail_ty: week-day | month-day | month-end | quarter-month | half-month | year-month
            String detailTy,
            // val1: week-day=ISO 요일(1 월 ~ 7 일) / month-day=일(1~31) / quarter·half=반기·분기 내 월 순번 / year-month=월(1~12)
            Integer val1,
            // val2: quarter-month·half-month·year-month의 실행일(1~31). 나머지 유형은 null
            Integer val2
    ) {}

    /** 주기 규칙 1건 — tbl_schedule_rule 1행 + 상세 목록. */
    public record Rule(
            // cycle_cd: D 매일 / W 매주 / M 매월 / Q 분기 / H 반기 / Y 매년 (대문자 도메인 유지)
            String cycleCd,
            // nonwork_rule: keep 그대로 / prev 이전 평일 / next 다음 평일
            String nonworkRule,
            // base_dt: 관리 시작일 — 이 날짜 이전 예정일은 만들지 않는다
            LocalDate startDt,
            // details: 비어 있으면 관리 시작일의 요일·일자를 기본값으로 쓴다(설정 누락으로 일정이 0건이 되는 것을 막는다)
            List<Detail> details
    ) {}

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 규칙을 해석해 from 부터 months 개월 구간의 예정일을 만든다
     *   2) 문서주기 저장·일일 배치가 호출하며, 반환 날짜는 비영업일 이동까지 끝난 최종 값이다
     *   3) 성공 시 오름차순·중복 없는 날짜 목록. 규칙이 없거나 구간이 비면 빈 목록
     */
    public List<LocalDate> generate(
            // rule: 주기·비영업일·관리 시작일·반복 상세 — null이면 빈 목록
            Rule rule,
            // from: 생성 시작일(보통 오늘) — 관리 시작일이 미래면 관리 시작일부터 만든다
            LocalDate from,
            // months: 생성 개월 수 — app.schedule.generate-months
            int months
    ) {
        if (rule == null || rule.startDt() == null || from == null || months <= 0) return List.of();
        String cycle = rule.cycleCd() == null ? "" : rule.cycleCd().trim().toUpperCase(java.util.Locale.ROOT);

        // 구간 시작 — 관리 시작일이 from 보다 늦을 때(= 아직 시작 안 한 주기) 관리 시작일부터 만든다
        LocalDate begin = rule.startDt().isAfter(from) ? rule.startDt() : from;
        LocalDate end = begin.plusMonths(months);

        Set<LocalDate> out = new TreeSet<>();
        for (LocalDate raw : rawDates(cycle, rule.details(), rule.startDt(), begin, end)) {
            LocalDate moved = shift(raw, rule.nonworkRule());
            // 비영업일 이동으로 관리 시작일 이전이 됐을 때(= 시작 경계) 제외한다
            if (moved.isBefore(rule.startDt()) || moved.isBefore(begin)) continue;
            out.add(moved);
        }
        return new ArrayList<>(out);
    }

    /** 토·일만 비영업일로 본다. 공휴일 반영이 필요해지면 이 메서드만 확장한다. */
    public boolean isNonWorkingDay(
            // date: 판정 대상 날짜
            LocalDate date
    ) {
        DayOfWeek dow = date.getDayOfWeek();
        return dow == DayOfWeek.SATURDAY || dow == DayOfWeek.SUNDAY;
    }

    /** 비영업일 처리 규칙에 따라 날짜를 옮긴다. keep이거나 영업일이면 그대로 둔다. */
    private LocalDate shift(LocalDate date, String nonworkRule) {
        String rule = nonworkRule == null ? "keep" : nonworkRule.trim().toLowerCase(java.util.Locale.ROOT);
        if (!isNonWorkingDay(date)) return date;
        LocalDate moved = date;
        // 토·일 연속 최대 2일이라 3회 이내에 끝난다 — 무한 루프 방지용 상한
        for (int i = 0; i < 7 && isNonWorkingDay(moved); i++) {
            if ("prev".equals(rule)) moved = moved.minusDays(1);
            else if ("next".equals(rule)) moved = moved.plusDays(1);
            else return date;
        }
        return moved;
    }

    /** 주기별 원본 예정일(비영업일 이동 전)을 만든다. */
    private List<LocalDate> rawDates(String cycle, List<Detail> details, LocalDate startDt, LocalDate begin, LocalDate end) {
        List<LocalDate> out = new ArrayList<>();
        switch (cycle) {
            case "D" -> {
                for (LocalDate d = begin; !d.isAfter(end); d = d.plusDays(1)) out.add(d);
            }
            case "W" -> {
                Set<Integer> weekDays = values(details, "week-day", startDt.getDayOfWeek().getValue());
                for (LocalDate d = begin; !d.isAfter(end); d = d.plusDays(1)) {
                    if (weekDays.contains(d.getDayOfWeek().getValue())) out.add(d);
                }
            }
            // 매월·분기·반기·매년은 월 단위로 훑고, 해당 월이 대상인지와 실행일만 다르다
            case "M", "Q", "H", "Y" -> {
                for (LocalDate month = begin.withDayOfMonth(1); !month.isAfter(end); month = month.plusMonths(1)) {
                    out.addAll(monthDates(cycle, details, startDt, month));
                }
                out.removeIf(d -> d.isBefore(begin) || d.isAfter(end));
            }
            default -> { }
        }
        return out;
    }

    /** 한 달치 예정일 — 월 대상 여부 판정 + 실행일 보정. */
    private List<LocalDate> monthDates(String cycle, List<Detail> details, LocalDate startDt, LocalDate month) {
        List<LocalDate> out = new ArrayList<>();
        if ("M".equals(cycle)) {
            // 말일 지정은 일자와 별개 상세로 들어온다(31일 지정과 말일 지정을 같이 걸 수 있다)
            boolean monthEnd = has(details, "month-end");
            if (monthEnd) out.add(month.withDayOfMonth(month.lengthOfMonth()));
            // 말일만 지정한 경우 관리 시작일 일자를 기본값으로 끼워 넣지 않는다(fallback 0 = 기본값 없음)
            for (int day : values(details, "month-day", monthEnd ? 0 : startDt.getDayOfMonth())) {
                if (day >= 1) out.add(clamp(month, day));
            }
            return out;
        }
        // 분기(3개월)·반기(6개월)는 주기 내 월 순번, 매년은 실제 월 번호로 대상 월을 고른다
        int step = switch (cycle) { case "Q" -> 3; case "H" -> 6; default -> 12; };
        String type = switch (cycle) { case "Q" -> "quarter-month"; case "H" -> "half-month"; default -> "year-month"; };
        int monthNo = month.getMonthValue();
        int position = ((monthNo - 1) % step) + 1;
        int defaultPosition = "Y".equals(cycle) ? startDt.getMonthValue() : ((startDt.getMonthValue() - 1) % step) + 1;
        List<Detail> targets = pick(details, type);
        if (targets.isEmpty()) {
            int compare = "Y".equals(cycle) ? monthNo : position;
            if (compare == defaultPosition) out.add(clamp(month, startDt.getDayOfMonth()));
            return out;
        }
        for (Detail detail : targets) {
            int wanted = detail.val1() == null ? defaultPosition : detail.val1();
            int compare = "Y".equals(cycle) ? monthNo : position;
            if (compare != wanted) continue;
            int day = detail.val2() == null ? startDt.getDayOfMonth() : detail.val2();
            out.add(clamp(month, day));
        }
        return out;
    }

    /** 31일처럼 해당 월에 없는 일자는 말일로 당긴다 — 2월 31일 같은 일정이 사라지지 않게 한다. */
    private LocalDate clamp(LocalDate month, int day) {
        return month.withDayOfMonth(Math.min(Math.max(day, 1), month.lengthOfMonth()));
    }

    private List<Detail> pick(List<Detail> details, String type) {
        List<Detail> out = new ArrayList<>();
        if (details == null) return out;
        for (Detail detail : details) {
            if (detail != null && type.equalsIgnoreCase(detail.detailTy())) out.add(detail);
        }
        return out;
    }

    /** 지정 유형의 val1 목록 — 없으면 fallback 1건(0이면 빈 값)을 쓴다. */
    private Set<Integer> values(List<Detail> details, String type, int fallback) {
        Set<Integer> out = new LinkedHashSet<>();
        for (Detail detail : pick(details, type)) {
            if (detail.val1() != null) out.add(detail.val1());
        }
        if (out.isEmpty() && fallback > 0) out.add(fallback);
        return out;
    }

    private boolean has(List<Detail> details, String type) { return !pick(details, type).isEmpty(); }
}
