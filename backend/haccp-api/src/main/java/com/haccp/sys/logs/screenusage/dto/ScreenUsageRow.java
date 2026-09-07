/**
 * ScreenUsageRow — 화면 이용 통계 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) sp_screen_usage_statistics_r_000 컬럼과 1:1
 *   2) 조인 컬럼 menuNm·scrnNm 도 필드다
 *   3) 원시 로그가 아니라 일자 집계다
 *
 * PIPELINE[HB92] 화면 이용 통계 DTO
 */
package com.haccp.sys.logs.screenusage.dto;

import java.math.BigDecimal;
import lombok.Data;

/** 화면 이용 집계 행 */
@Data
public class ScreenUsageRow {
    private String statDt;
    private String scrnCd;
    private String menuCd;
    private String menuNm;
    private String scrnNm;
    private String moduleCd;
    private Integer pvCnt;
    private Integer uvCnt;
    private Integer sessCnt;
    private Integer ipCnt;
    private BigDecimal avgStaySec;
    private Integer maxStaySec;
}
