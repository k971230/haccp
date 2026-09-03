/**
 * CycleScheduleGeneratorTest — 문서주기 예정일 계산 검증.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 말일·31일 보정, 비영업일 이동(prev/next·공휴일 JSON), 관리 시작일 경계를 값으로 고정한다
 *   2) 규칙 해석이 깨지면 이 테스트가 먼저 실패한다 — DB·Spring 컨텍스트 없이 순수 계산만 본다
 *   3) 실행: ./mvnw -Dtest=CycleScheduleGeneratorTest test
 */
package com.haccp.docs.sch;

// 역할 — 검증 대상 입력 타입
import com.haccp.docs.sch.CycleScheduleGenerator.Detail;
import com.haccp.docs.sch.CycleScheduleGenerator.Rule;
// 역할 — 날짜 비교
import java.time.LocalDate;
import java.util.List;
// 역할 — 단정
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import org.junit.jupiter.api.Test;

class CycleScheduleGeneratorTest {

    private final CycleScheduleGenerator generator = new CycleScheduleGenerator();

    /** 매월 31일 — 2월은 말일(28/29)로 당겨진다. keep이라 주말 이동은 없다. */
    @Test
    void monthlyDay31FallsBackToMonthEnd() {
        Rule rule = new Rule("M", "keep", LocalDate.of(2026, 1, 1), List.of(new Detail("month-day", 31, null)));
        List<LocalDate> dates = generator.generate(rule, LocalDate.of(2026, 1, 1), 3);

        assertTrue(dates.contains(LocalDate.of(2026, 1, 31)), "1월은 31일 그대로");
        assertTrue(dates.contains(LocalDate.of(2026, 2, 28)), "2월은 말일로 보정");
        assertTrue(dates.contains(LocalDate.of(2026, 3, 31)), "3월은 31일 그대로");
    }

    /** 말일 지정 — month-day 없이 month-end 만 있으면 각 월 말일 1건씩. */
    @Test
    void monthEndOnlyProducesLastDay() {
        Rule rule = new Rule("M", "keep", LocalDate.of(2026, 4, 10), List.of(new Detail("month-end", null, null)));
        List<LocalDate> dates = generator.generate(rule, LocalDate.of(2026, 4, 1), 2);

        assertEquals(List.of(LocalDate.of(2026, 4, 30), LocalDate.of(2026, 5, 31)), dates);
    }

    /** 비영업일 처리 — 2026-08-15는 토(광복절). prev는 14일(금), next는 17일 대체공휴일을 건너 18일(화). */
    @Test
    void nonWorkingDayShiftsToWeekday() {
        Rule prev = new Rule("M", "prev", LocalDate.of(2026, 8, 1), List.of(new Detail("month-day", 15, null)));
        Rule next = new Rule("M", "next", LocalDate.of(2026, 8, 1), List.of(new Detail("month-day", 15, null)));

        assertEquals(LocalDate.of(2026, 8, 14), generator.generate(prev, LocalDate.of(2026, 8, 1), 1).get(0));
        assertEquals(LocalDate.of(2026, 8, 18), generator.generate(next, LocalDate.of(2026, 8, 1), 1).get(0));
    }

    /** holidays-kr JSON — 2026-03-01은 일(3·1절), 3/2는 대체. NEXT는 3/3(화). */
    @Test
    void nextSkipsHolidayAndSubstitute() {
        Rule next = new Rule("M", "next", LocalDate.of(2026, 3, 1), List.of(new Detail("month-day", 1, null)));
        assertEquals(LocalDate.of(2026, 3, 3), generator.generate(next, LocalDate.of(2026, 3, 1), 1).get(0));
    }

    /** holidays-kr JSON — 2026-05-05는 화(어린이날). NEXT는 5/6. */
    @Test
    void nextSkipsWeekdayHoliday() {
        Rule next = new Rule("M", "next", LocalDate.of(2026, 5, 1), List.of(new Detail("month-day", 5, null)));
        assertEquals(LocalDate.of(2026, 5, 6), generator.generate(next, LocalDate.of(2026, 5, 1), 1).get(0));
    }

    /** JSON에 없는 연도 — 주말만 비영업일. 2030-01-01은 화요일이라 KEEP·NEXT 모두 그대로. */
    @Test
    void yearMissingFromJsonUsesWeekendOnly() {
        assertTrue(generator.isNonWorkingDay(LocalDate.of(2026, 3, 2)), "2026-03-02 대체공휴일");
        assertFalse(generator.isNonWorkingDay(LocalDate.of(2030, 1, 1)), "2030 JSON 없음·화");
        assertTrue(generator.isNonWorkingDay(LocalDate.of(2030, 1, 5)), "2030-01-05 토");
        assertFalse(
                generator.isNonWorkingDay(LocalDate.of(2030, 1, 5), java.util.Set.of(LocalDate.of(2030, 1, 5))),
                "전환된 토요일은 영업일");
    }

    /** 관리 시작일 경계 — 시작일 이전 예정일은 만들지 않는다. */
    @Test
    void skipsDatesBeforeStartDate() {
        Rule rule = new Rule("M", "keep", LocalDate.of(2026, 8, 20), List.of(new Detail("month-day", 10, null)));
        List<LocalDate> dates = generator.generate(rule, LocalDate.of(2026, 8, 1), 2);

        assertEquals(List.of(LocalDate.of(2026, 9, 10), LocalDate.of(2026, 10, 10)), dates);
    }

    /** 매주 — 요일 상세가 없으면 관리 시작일의 요일을 쓴다(2026-08-03은 월요일). */
    @Test
    void weeklyDefaultsToStartWeekday() {
        Rule rule = new Rule("W", "keep", LocalDate.of(2026, 8, 3), List.of());
        List<LocalDate> dates = generator.generate(rule, LocalDate.of(2026, 8, 3), 1);

        assertTrue(dates.contains(LocalDate.of(2026, 8, 3)));
        assertTrue(dates.contains(LocalDate.of(2026, 8, 10)));
        assertTrue(dates.stream().allMatch(d -> d.getDayOfWeek() == java.time.DayOfWeek.MONDAY));
    }

    /** 분기 — 분기 내 첫 달(1·4·7·10월) 5일. */
    @Test
    void quarterlyPicksFirstMonthOfEachQuarter() {
        Rule rule = new Rule("Q", "keep", LocalDate.of(2026, 1, 1), List.of(new Detail("quarter-month", 1, 5)));
        List<LocalDate> dates = generator.generate(rule, LocalDate.of(2026, 1, 1), 12);

        assertEquals(List.of(
                LocalDate.of(2026, 1, 5), LocalDate.of(2026, 4, 5),
                LocalDate.of(2026, 7, 5), LocalDate.of(2026, 10, 5)
        ), dates);
    }

    /** 분기 말일 — val2=0 이면 2월은 28/29일로 당긴다. */
    @Test
    void quarterlyMonthEndUsesFebruaryLastDay() {
        Rule rule = new Rule("Q", "keep", LocalDate.of(2026, 1, 1), List.of(new Detail("quarter-month", 2, 0)));
        List<LocalDate> dates = generator.generate(rule, LocalDate.of(2026, 1, 1), 3);

        assertTrue(dates.contains(LocalDate.of(2026, 2, 28)), "2026년 2월 말일");
    }

    /** 비정기 — 예정일을 만들지 않는다. 필요할 때 문서를 작성한다. */
    @Test
    void eventCycleProducesNoDates() {
        Rule rule = new Rule("E", "keep", LocalDate.of(2026, 8, 1), List.of());
        List<LocalDate> dates = generator.generate(rule, LocalDate.of(2026, 8, 1), 12);
        assertEquals(List.of(), dates);
    }
}
