/**
 * DraftListRow — 작성 좌측 목록 1행 (양식 작성 5화면 공용).
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) SP 컬럼은 snake, 앱은 camelCase (map-underscore-to-camel-case)
 *   2) 좌측 그리드 표시는 결재 여부·일자·양식코드·양식명·작성자다
 *   3) 결재 여부 3단계(전송대기/전송/결재완료) 묶음은 서버가 아니라 화면이 status 로 계산한다
 *      — DOC_STATUS 를 그대로 내리고 새 코드 도메인을 만들지 않는다
 *
 * 계열마다 hdrIdx 가 가리키는 테이블이 다르다(tbl_hyg_process · tbl_ccp_verify_check ·
 * tbl_ccp_pkg_monitor · tbl_ccp_htg_monitor · tbl_ccp_metal_monitor). 목록 SP 가 자기 헤더 idx 를 넣는다.
 *
 * PIPELINE[HB135] 양식 작성 공용 DTO
 */
package com.haccp.draft.dto;

import lombok.Data;

@Data
public class DraftListRow {
    // tbl_document.idx — 그리드 행 키
    private Long docIdx;
    // 계열 헤더 idx — 상세 조회에서 하위 행을 찾는 키
    private Long hdrIdx;
    // 양식코드 — 좌측 팝업 버튼. 클릭하면 우측 지면이 이 양식으로 열린다
    private String tmplCd;
    // 양식명
    private String tmplNm;
    // 문서번호
    private String docNo;
    // 일자(작성일·점검일자) YYYYMMDD
    private String baseDt;
    // 점검자·관리자 스냅샷
    private String checkerNm;
    // 작성자 ID — tbl_document.writer_id. 전송·전송취소는 작성자만 가능하다(서버가 다시 막는다)
    private String writerId;
    // 작성자명 — 없으면 ID
    private String writerNm;
    // DOC_STATUS 원본 — WRK/RJT/REQ/APV. 화면이 3단계로 묶는다
    private String status;
    // 기록·점검 행 수
    private Integer rowCnt;
    // 부적합 건수 — 계열별로 yn='N' 또는 judge_cd='F'
    private Integer ngCnt;

    /** 이탈여부 Y/N — 개선조치가 붙어 있으면 Y. 미완료 수(ngCnt)와 다른 축이다 */
    private String deviationYn;
    // 제목 — tbl_document.title. 결재 첨부 remark 가 아니다
    private String title;
}
