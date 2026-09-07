/**
 * CalendarHolidayRow — 공휴일 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 서버가 KoreanHolidayDates 로 채운다
 *   2) JSON 키 ymd·name
 *   3) 월 조회 응답 holidays 배열
 *
 * PIPELINE[HB212] 일정 캘린더 DTO
 */
package com.haccp.board.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/** 공휴일 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class CalendarHolidayRow {
    private String ymd;
    private String name;
}
