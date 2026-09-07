/**
 * CalendarTaskRow — 일정 캘린더 과제 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) sp_calendar_r_000 컬럼과 1:1
 *   2) mine 은 서비스가 JWT 로 붙인다
 *   3) docIdx 는 이미 쓴 문서
 *
 * PIPELINE[HB212] 일정 캘린더 DTO
 */
package com.haccp.board.dto;

import lombok.Data;

/** 월 과제 1건 */
@Data
public class CalendarTaskRow {
    private Long taskIdx;
    private String tmplCd;
    private String tmplNm;
    private String baseDt;
    private String dueDt;
    private String dueTime;
    private String status;
    private String userId;
    private String deptCd;
    private Long docIdx;
    // 담당자 일치 또는 담당 없고 부서 일치
    private Boolean mine;
}
