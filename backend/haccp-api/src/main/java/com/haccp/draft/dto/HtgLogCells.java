/**
 * HtgLogCells — CCP 가열 기록 행의 칸.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) FE cells 객체 키와 1:1 이다 — temp·time
 *   2) EAV 셀 표(tbl_ccp_htg_monitor_cell.item_cd)에 그대로 실린다
 *   3) 포장·금속 칸을 여기 두지 않는다
 *
 * PIPELINE[HB142] CCP 가열 작성 DTO
 */
package com.haccp.draft.dto;

import lombok.Data;

@Data
public class HtgLogCells {
    // 중심온도
    private String temp;
    // 유지시간
    private String time;
}
