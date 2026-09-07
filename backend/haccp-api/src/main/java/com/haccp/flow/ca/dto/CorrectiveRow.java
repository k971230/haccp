/**
 * CorrectiveRow — 개선조치 목록 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) sp_tbl_corrective_action_r_000 컬럼과 1:1
 *   2) 조인 컬럼 tmplNm·writerNm 도 필드다
 *   3) 저장 행과 같은 칸을 쓰므로 CorrectiveSaveRow 와 키가 같다
 *
 * PIPELINE[HB93] Map API DTO
 */
package com.haccp.flow.ca.dto;

import lombok.Data;

@Data
public class CorrectiveRow {
    // 대리키
    private Long idx;
    // 개선조치번호
    private String caNo;
    // 발생일
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
    // 조치일
    private String actionDt;
    // 확인자명
    private String confirmUserNm;
    // 완료예정일
    private String dueDt;
    // 상태
    private String status;
    // 출처 문서 idx
    private Long srcDocIdx;
    // 출처 문서번호
    private String srcDocNo;
    // 출처 양식코드
    private String srcTmplCd;
    // 양식명
    private String tmplNm;
    // 기준일
    private String baseDt;
    // 문서상태
    private String docStatus;
    // 작성자 ID
    private String writerId;
    // 작성자명
    private String writerNm;
}
