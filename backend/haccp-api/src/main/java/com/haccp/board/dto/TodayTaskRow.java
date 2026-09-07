/**
 * TodayTaskRow — 오늘 할 일 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) sp_tbl_today_task_r_000 컬럼과 1:1
 *   2) 과제·미완료 개선조치를 한 목록으로 내린다
 *   3) linkScrnCd 로 화면이 연다
 *
 * PIPELINE[HB94] 오늘 할 일 DTO
 */
package com.haccp.board.dto;

import lombok.Data;

/** 오늘 과제 1건 */
@Data
public class TodayTaskRow {
    private Long taskIdx;
    private String taskType;
    private String title;
    private String status;
    private String dueDt;
    private String dueTime;
    private String linkScrnCd;
    private Long docIdx;
    private Long refIdx;
    private String content;
    private String tmplCd;
    private String baseDt;
}
