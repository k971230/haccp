/**
 * CorrectiveSaveRow — 개선조치 저장 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 화면 그리드가 보내는 camelCase 키를 그대로 받는다
 *   2) 행 전체를 jsonb 로 넘긴다 — 칸이 늘어도 SP 만 고치면 된다
 *   3) coCd·작업자는 JWT 만 쓴다
 *
 * PIPELINE[HB94] 개선조치 DTO
 */
package com.haccp.flow.ca.dto;

import lombok.Data;

/** 개선조치 저장 행 — idx 없으면 신규 */
@Data
public class CorrectiveSaveRow {
    // 대리키 — 없으면 신규
    private Long idx;
    // 개선조치 번호
    private String caNo;
    // 발생일 YYYYMMDD
    private String occurDt;
    // 발생장소
    private String occurPlace;
    // 이탈내용
    private String deviationDesc;
    // 조치내용
    private String actionDesc;
    // 조치자 ID
    private String actionUserId;
    // 조치자명
    private String actionUserNm;
    // 조치일 YYYYMMDD
    private String actionDt;
    // 확인자명
    private String confirmUserNm;
    // 기한 YYYYMMDD
    private String dueDt;
    // 상태
    private String status;
    // 원본 문서 idx
    private Long srcDocIdx;
    // 원본 문서번호
    private String srcDocNo;
    // 원본 양식코드
    private String srcTmplCd;
    // 양식명
    private String tmplNm;
    // 기준일 YYYYMMDD
    private String baseDt;
    // 문서 상태
    private String docStatus;
    // 작성자 ID
    private String writerId;
    // 작성자명
    private String writerNm;
}
