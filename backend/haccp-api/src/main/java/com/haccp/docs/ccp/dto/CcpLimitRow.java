/**
 * CcpLimitRow — CCP 한계기준 행.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) sp_tbl_ccp_limit_r_000 결과 — 화면 한계기준·방법란 문구와 자동판정 원천
 *   2) TEMP_RANGE일 때 minVal·maxVal이 온도 판정에 쓰인다
 *   3) 회사별로 조정 가능하며 표준 시드를 직접 바꾸지 않는다
 *
 * PIPELINE[HB61] ccp DTO
 */
package com.haccp.docs.ccp.dto;

import java.math.BigDecimal;
import lombok.Data;

@Data
public class CcpLimitRow {
    private Long idx;
    private String coCd;
    private String ccpCd;
    private String ccpNm;
    private String procNm;
    private String limitType;
    private BigDecimal minVal;
    private BigDecimal maxVal;
    private String unitNm;
    private BigDecimal feSize;
    private BigDecimal stsSize;
    private Integer cycleMin;
    /** 일지 상단 제목 — DocPaper title */
    private String formTitle;
    /** 주기 서술 문구 — A4 주기란 */
    private String cycleRmk;
    private String limitRmk;
    private String methodRmk;
    private String useYn;
}
