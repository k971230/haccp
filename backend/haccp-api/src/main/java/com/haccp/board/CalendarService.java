/**
 * CalendarService — 일정 캘린더 조회·영업일 전환.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 월 한 번에 과제·공휴일·영업일 전환을 모은다
 *   2) 저장은 전환 행만 쓰고, 같은 트랜잭션 밖에서 예정일을 다시 만든다
 *   3) 회사·작업자는 JWT만 쓴다
 *
 * PIPELINE[HB211] 일정 캘린더 서비스
 */
package com.haccp.board;

// 역할 — JWT
import com.haccp.common.context.LoginUserContext;
// 역할 — 업무 예외
import com.haccp.common.exception.BizException;
// 역할 — 공휴일 명칭
import com.haccp.docs.sch.KoreanHolidayDates;
// 역할 — 예정일 재생성
import com.haccp.board.dto.CalendarHolidayRow;
import com.haccp.board.dto.CalendarMonthResponse;
import com.haccp.board.dto.CalendarSaveItem;
import com.haccp.board.dto.CalendarTaskRow;
import com.haccp.docs.sch.DocCycleService;
// 역할 — 날짜
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.List;
// 역할 — Spring
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CalendarService {

    private static final DateTimeFormatter YMD = DateTimeFormatter.BASIC_ISO_DATE;

    private final CalendarMapper mapper;
    private final DocCycleService docCycleService;

    /**
     * 개발자: 박승우
     * 일자: 2026-09-03
     * 코멘트:
     *   1) 한 달치 과제·공휴일·영업일 전환을 한 응답으로 내린다
     *   2) 캘린더 화면 진입·월 이동에서 호출한다
     *   3) 각 과제에 mine 을 붙인다 — 담당자 일치 또는 담당자 없고 부서 일치
     */
    public CalendarMonthResponse list(
            // YYYYMM — 비면 이번 달
            String month
    ) {
        YearMonth ym = parseMonth(month);
        LocalDate from = ym.atDay(1);
        LocalDate to = ym.atEndOfMonth();
        String fromYmd = from.format(YMD);
        String toYmd = to.format(YMD);
        String coCd = LoginUserContext.coCd();
        String userId = text(LoginUserContext.userId());
        String deptCd = text(LoginUserContext.deptCd());

        List<CalendarTaskRow> tasks = new ArrayList<>();
        List<CalendarTaskRow> rows = mapper.selectTasks(coCd, fromYmd, toYmd);
        if (rows != null) {
            for (CalendarTaskRow task : rows) {
                if (task == null) continue;
                task.setMine(isMine(task, userId, deptCd));
                tasks.add(task);
            }
        }

        List<CalendarHolidayRow> holidays = new ArrayList<>();
        for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1)) {
            if (!KoreanHolidayDates.ALL.contains(d)) continue;
            CalendarHolidayRow h = new CalendarHolidayRow();
            h.setYmd(d.format(YMD));
            h.setName(KoreanHolidayDates.nameOf(d));
            holidays.add(h);
        }

        List<String> workdays = mapper.selectWorkdays(coCd, fromYmd, toYmd);
        CalendarMonthResponse out = new CalendarMonthResponse();
        out.setMonth(ym.toString().replace("-", ""));
        out.setTasks(tasks);
        out.setHolidays(holidays);
        out.setWorkdays(workdays == null ? List.of() : workdays);
        return out;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-03
     * 코멘트:
     *   1) 영업일 전환 변경분을 저장한다
     *   2) 캘린더 저장 버튼에서 호출한다
     *   3) 저장이 끝나면 해당 회사 예정일을 다시 만든다
     */
    @Transactional(timeout = 60)
    public void save(
            // { ymd, workYn } 배열 — 변경분만
            List<CalendarSaveItem> items
    ) {
        if (items == null || items.isEmpty()) throw new BizException("저장할 영업일 전환이 없습니다.");
        String coCd = LoginUserContext.coCd();
        String userId = LoginUserContext.userId();
        for (CalendarSaveItem item : items) {
            if (item == null) throw new BizException("저장할 영업일 전환이 올바르지 않습니다.");
            String ymd = digits(item.getYmd());
            if (ymd.length() != 8) throw new BizException("전환할 일자가 올바르지 않습니다.");
            String workYn = text(item.getWorkYn()).toUpperCase();
            if (!"Y".equals(workYn) && !"N".equals(workYn)) {
                throw new BizException("영업일 여부가 올바르지 않습니다.");
            }
            mapper.upsertWorkday(coCd, ymd, workYn, userId);
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-03
     * 코멘트:
     *   1) 저장이 커밋된 뒤 해당 회사 예정일을 다시 만든다
     *   2) Controller가 save 다음에 호출한다 — 재생성 실패가 전환 저장을 되돌리지 않게
     *   3) 활성 주기가 없으면 아무 것도 하지 않는다
     */
    public void regenerateAfterSave() {
        docCycleService.regenerateCompany(LoginUserContext.coCd());
    }

    /** YYYYMM → YearMonth. 비면 이번 달 */
    private YearMonth parseMonth(String month) {
        String digits = digits(month);
        if (digits.isEmpty()) return YearMonth.now();
        if (digits.length() != 6) throw new BizException("조회 월이 올바르지 않습니다.");
        try {
            return YearMonth.parse(digits, DateTimeFormatter.ofPattern("yyyyMM"));
        } catch (DateTimeParseException e) {
            throw new BizException("조회 월이 올바르지 않습니다.");
        }
    }

    /** 담당자 지정 시 본인, 없으면 같은 부서 */
    private boolean isMine(CalendarTaskRow task, String userId, String deptCd) {
        String assignUser = text(task.getUserId());
        String assignDept = text(task.getDeptCd());
        if (!assignUser.isEmpty()) return assignUser.equals(userId);
        if (!assignDept.isEmpty() && !deptCd.isEmpty()) return assignDept.equals(deptCd);
        return false;
    }

    private String digits(String value) { return text(value).replaceAll("[^0-9]", ""); }
    private String text(String value) { return value == null ? "" : value.trim(); }
}
