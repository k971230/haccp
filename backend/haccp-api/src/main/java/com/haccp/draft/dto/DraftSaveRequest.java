/**
 * DraftSaveRequest — 작성 저장 본문 (양식 작성 5화면 공용).
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) FE api/draft/htmlFormDraftTypes.ts 의 HtmlFormDraftSaveRequest 와 1:1 이다.
 *      한쪽만 필드를 늘리면 조용히 누락되므로 두 파일을 같이 고친다
 *   2) 본문 배열 3종은 화면마다 쓰는 것이 다르다 — 안 쓰는 배열은 null 로 온다
 *      items    : HYG·CCP검증 (지면이 점검 항목을 그대로 그린다)
 *      logRows  : CCP 포장·가열·금속검출 기록 표
 *      passRows : CCP 금속검출 통과량 표
 *   3) 전송 전이라 서버는 필수값을 보지 않는다. 필수값은 전송(REQUEST) 직전 화면이 검사한다
 *
 * PIPELINE[HB135] 양식 작성 공용 DTO
 */
package com.haccp.draft.dto;

import com.haccp.flow.ca.dto.DocCorrectiveDto;
import java.util.List;
import lombok.Data;

@Data
public class DraftSaveRequest {
    // 작성 양식코드 — 자사 양식만. 서비스가 접두로 화면 범위를 검사한다. 필수
    private String tmplCd;
    // 기존 문서 idx — 신규면 null/0
    private Long docIdx;
    // 일자(작성일·점검일자) YYYYMMDD
    private String baseDt;
    // 점검자·관리자명 — 저장 시 이름=사용자면 서명 스냅샷
    private String checkerNm;
    // 승인자명 — 헤더. 서명 규칙은 점검자와 같다
    private String approverNm;
    // 적용 버전 — 자사 양식은 1
    private Integer verNo;
    // 점검 항목 행 — HYG·CCP검증만
    private List<DraftItemRow> items;
    // 기록 표 행 — CCP 모니터링일지만. phaseCd 로 작업 전/작업 종료를 가른다
    private List<DraftLogRow> logRows;
    // 통과량 표 행 — CCP 금속검출만
    private List<DraftPassRow> passRows;
    // 특이사항 — 개행 보존
    private String specialNote;
    // 개선조치 및 결과
    private String improveNote;
    // 조치자
    private String actionNm;
    // 확인자
    private String confirmNm;
    // 이탈·개선조치 푸터 — 화면이 따로 넘기면 우선한다
    private DocCorrectiveDto corrective;

    /**
     * 이탈여부 Y/N — HWP 작성 목록의 이탈여부 칸이 보낸다.
     * HTML 5화면은 지면 하단 시그널과 이탈내용으로 판단하므로 넘기지 않는다.
     */
    private String deviationYn;
    // 목록 제목 — tbl_document.title. 빈값이면 SP 가 신규는 양식명·수정은 기존값을 쓴다
    private String title;
    /**
     * 화면이 상세에서 받은 문서 스탬프 — 수정 저장 때 서버가 대조한다.
     * 신규·빈 값은 통과. 어긋나면 「다른 사용자가 먼저 저장했습니다」
     */
    private String seenUpdDt;
}
