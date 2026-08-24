/**
 * CcpLogDraftListRow — 작성 좌측 목록 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) CCP 포장·가열·금속검출 작성 3화면이 같은 DTO 를 쓴다. 화면마다 복제하지 않는다
 *   2) 모양은 HYG(draft.hyg)·CCP검증(draft.ccp)과 같다. 서버 테이블·SP 만 계열별로 다르다
 *   3) 결재 여부 3단계 묶음은 화면이 status 로 계산한다
 *
 * PIPELINE[HB139] CCP 모니터링 작성 DTO
 */
package com.haccp.draft.ccpmonitoring.dto;

import lombok.Data;

@Data
public class CcpLogDraftListRow {
    // tbl_document.idx — 그리드 행 키
    private Long docIdx;
    // 계열 헤더 idx — generic monitor 또는 metal monitor
    private Long hdrIdx;
    // 양식코드 — 좌측 팝업 버튼
    private String tmplCd;
    // 양식명
    private String tmplNm;
    // 문서번호
    private String docNo;
    // 일자(작성일) YYYYMMDD
    private String baseDt;
    // 관리자·점검자 스냅샷
    private String checkerNm;
    // 작성자 ID — tbl_document.writer_id
    private String writerId;
    // 작성자명 — 없으면 ID
    private String writerNm;
    // DOC_STATUS 원본 — WRK/RJT/REQ/REV/APV
    private String status;
    // 기록 행 수
    private Integer rowCnt;
    // 부적합(F) 건수
    private Integer ngCnt;
}
