/**
 * CalendarMonthResponse — 일정 캘린더 월 조회.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) JSON 키 month·tasks·holidays·workdays 는 그대로다
 *   2) workdays 는 영업일 전환 ymd 목록
 *   3) 과제에 mine 을 붙인다
 *
 * PIPELINE[HB212] 일정 캘린더 DTO
 */
package com.haccp.board.dto;

import java.util.List;
import lombok.Data;

/** 한 달치 */
@Data
public class CalendarMonthResponse {
    private String month;
    private List<CalendarTaskRow> tasks;
    private List<CalendarHolidayRow> holidays;
    private List<String> workdays;
}
