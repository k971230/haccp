/**
 * PkgLogCells — CCP 포장 기록 행의 칸.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) FE cells 객체 키와 1:1 이다 — temp·min·sec
 *   2) EAV 셀 표(tbl_ccp_pkg_monitor_cell.item_cd)에 그대로 실린다
 *   3) 금속·가열 칸을 여기 두지 않는다
 *
 * PIPELINE[HB139] CCP 포장 작성 DTO
 */
package com.haccp.draft.dto;

import lombok.Data;

@Data
public class PkgLogCells {
    // 중심온도
    private String temp;
    // 분
    private String min;
    // 초
    private String sec;
}
