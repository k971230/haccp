/**
 * CcpVerifyDraftListRow — CCP 검증점검 작성 좌측 목록 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) SP 컬럼은 snake, 앱은 camelCase (map-underscore-to-camel-case)
 *   2) 좌측 그리드 표시는 결재 여부·일자·양식코드·양식명·작성자다
 *   3) 결재 여부 3단계(전송대기/전송/결재완료) 묶음은 화면이 status 로 계산한다
 *
 * PIPELINE[HB137] CCP 검증점검 작성 DTO
 */
package com.haccp.draft.ccp.dto;

import lombok.Data;

@Data
public class CcpVerifyDraftListRow {
    // tbl_document.idx — 그리드 행 키
    private Long docIdx;
    // tbl_ccp_verify_check.idx
    private Long hdrIdx;
    // 양식코드 — 좌측 팝업 버튼. 클릭하면 우측 지면이 이 양식으로 열린다
    private String tmplCd;
    // 양식명
    private String tmplNm;
    // 문서번호
    private String docNo;
    // 일자(점검일자) YYYYMMDD
    private String baseDt;
    // 점검자 스냅샷
    private String checkerNm;
    // 작성자 ID — tbl_document.writer_id
    private String writerId;
    // 작성자명 — 없으면 ID
    private String writerNm;
    // DOC_STATUS 원본 — WRK/RJT/REQ/REV/APV
    private String status;
    // 항목 수
    private Integer rowCnt;
    // 아니오 건수
    private Integer ngCnt;
}
