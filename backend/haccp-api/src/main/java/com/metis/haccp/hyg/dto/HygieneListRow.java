/**
 * HygieneListRow — 위생 양식 목록 행.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 문서번호·상태와 기준일·부적합 건수를 목록에 제공한다
 *   2) 기간형 양식은 baseDtTo를 함께 반환한다
 *   3) 조회 결과는 테넌트 범위를 SP에서 강제한다
 *
 * PIPELINE[HB83] 위생 DTO
 * PIPELINE[HB84] 연관 모듈
 */
package com.metis.haccp.hyg.dto;

import lombok.Data;

@Data
public class HygieneListRow {
    private Long docIdx;
    private Long hdrIdx;
    private String docNo;
    private String baseDt;
    private String baseDtTo;
    private String checkerNm;
    private String status;
    private Integer rowCnt;
    private Integer ngCnt;
}
