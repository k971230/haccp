/**
 * TodayTaskDocRow — 오늘 할 일 최근 문서 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) sp_tbl_today_task_doc_r_000 컬럼과 1:1
 *   2) totalCnt 는 첫 행만 쓰고 응답에서는 뺀다
 *   3) 조인 컬럼 tmplNm·writerNm·fileCnt 도 필드다
 *
 * PIPELINE[HB94] 오늘 할 일 DTO
 */
package com.haccp.board.dto;

import com.fasterxml.jackson.annotation.JsonIgnore;
import java.time.LocalDateTime;
import lombok.Data;

/** 최근 문서 1건 */
@Data
public class TodayTaskDocRow {
    private Long docIdx;
    private String coCd;
    private String tmplCd;
    private String tmplNm;
    private String docKind;
    private String docNo;
    private String baseDt;
    private String title;
    private String status;
    private String apprLineCd;
    private String writerId;
    private String writerNm;
    private LocalDateTime writeDt;
    private Integer verNo;
    private String retentionUntil;
    private Integer fileCnt;
    private Integer openCaCnt;
    // 기간 전체 건수 — 응답 rows 에서는 뺀다
    @JsonIgnore
    private Integer totalCnt;
}
