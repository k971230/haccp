/**
 * ColdMonitorTempCell — 보관고별 온도 셀.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 조회·저장 JSON 모두 같은 필드를 쓴다
 *   2) judgeCd는 저장 SP가 한계기준으로 다시 확정한다(수동 행 판정과 별개)
 *   3) tempVal null이면(= 미입력) 셀 판정 없음
 *
 * PIPELINE[HB64] ccp DTO
 */
package com.metis.haccp.ccp.dto;

import java.math.BigDecimal;
import lombok.Data;

@Data
public class ColdMonitorTempCell {
    // 보관고 코드 — tbl_storage.storage_cd
    private String storageCd;
    // 측정 온도(섭씨) — 소수 1자리
    private BigDecimal tempVal;
    // 셀 판정 P/F — 조회 시에만 의미 있음
    private String judgeCd;
}
