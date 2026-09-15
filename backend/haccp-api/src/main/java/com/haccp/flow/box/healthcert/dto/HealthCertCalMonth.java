/**
 * HealthCertCalMonth — 보건증 월 캘린더 응답.
 *
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) days 는 최신 이력 등록·만료. holidays·workdays 는 일정 캘린더와 같은 출처다
 *   2) 일정 API 를 호출하지 않는다 — calendar 화면 권한이 없는 담당자가 있다
 *   3) 보건증 GET /calendar 한 곳만 이 모양이다
 *
 * PIPELINE[HB148] 보건증 DTO
 */
package com.haccp.flow.box.healthcert.dto;

import com.haccp.board.dto.CalendarHolidayRow;
import java.util.ArrayList;
import java.util.List;
import lombok.Data;

/** 월 캘린더 — 최신 이력 + 공휴일 + 영업일 전환 */
@Data
public class HealthCertCalMonth {
    // 사원별 최신 이력 등록·만료
    private List<HealthCertCalRow> days = new ArrayList<>();
    // 공휴일 ymd·name — KoreanHolidayDates
    private List<CalendarHolidayRow> holidays = new ArrayList<>();
    // 영업일 전환 YYYYMMDD
    private List<String> workdays = new ArrayList<>();
}
