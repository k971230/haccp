/**
 * HygProcessListRow — 공정점검표 좌측 목록 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) SP 컬럼은 snake, 앱은 camelCase
 *   2) ngCnt는 아니오(N) 건수다
 *   3) 목록 그리드와 DocForm 세션 키로 쓴다
 *
 * PIPELINE[HB131] 공정점검 DTO
 */
package com.haccp.docs.html.hygprocess.dto;

import lombok.Data;

@Data
public class HygProcessListRow {
    // tbl_document.idx
    private Long docIdx;
    // tbl_hyg_process.idx
    private Long hdrIdx;
    // 문서번호
    private String docNo;
    // 점검일자 YYYYMMDD
    private String baseDt;
    // 점검자 스냅샷
    private String checkerNm;
    // DOC_STATUS
    private String status;
    // 항목 수
    private Integer rowCnt;
    // 아니오 건수
    private Integer ngCnt;
}
