/**
 * CalendarSaveItem — 영업일 전환 저장 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 본문 [{ ymd, workYn }]
 *   2) 변경분만 온다
 *   3) coCd·작업자는 JWT 만 쓴다
 *
 * PIPELINE[HB212] 일정 캘린더 DTO
 */
package com.haccp.board.dto;

import lombok.Data;

/** 하루 영업일 전환 */
@Data
public class CalendarSaveItem {
    // 대상일 YYYYMMDD
    private String ymd;
    // Y 영업일 / N 해제
    private String workYn;
}
