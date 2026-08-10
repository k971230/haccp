/**
 * ColdMonitorHeader — CCP 냉장보관 일지 헤더.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) sp_tbl_ccp_cold_monitor_r_001 결과
 *   2) status가 TMP·RJT일 때만 수정·삭제 가능하다
 *   3) 상세 응답의 헤더 부분에 그대로 실는다
 *
 * PIPELINE[HB63] ccp DTO
 */
package com.metis.haccp.ccp.dto;

import java.time.LocalDateTime;
import lombok.Data;

@Data
public class ColdMonitorHeader {
    private Long docIdx;
    private Long hdrIdx;
    private String coCd;
    private String docNo;
    private String baseDt;
    private String ccpCd;
    private String title;
    private String status;
    private String mngUserId;
    private String mngNm;
    private String writerId;
    private LocalDateTime writeDt;
    private Integer verNo;
}
