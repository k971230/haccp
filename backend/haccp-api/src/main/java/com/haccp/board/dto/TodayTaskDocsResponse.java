/**
 * TodayTaskDocsResponse — 오늘 할 일 최근 문서 페이지.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) JSON 키 rows·total 은 그대로다
 *   2) total 은 첫 행 totalCnt
 *   3) 0건이면 total 0
 *
 * PIPELINE[HB94] 오늘 할 일 DTO
 */
package com.haccp.board.dto;

import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/** 최근 문서 페이지 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class TodayTaskDocsResponse {
    private List<TodayTaskDocRow> rows;
    private int total;
}
