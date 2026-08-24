/**
 * CcpVerifyDraftSaveRequest — CCP 검증점검 작성 저장 본문.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) tmplCd 로 어느 자사 양식을 쓰는지 정한다. 신규는 docIdx 생략
 *   2) items·하단 4칸은 payload JSON 으로 SP 에 넘긴다
 *   3) 전송 전이라 필수값은 검사하지 않는다. 필수값은 전송(REQUEST) 직전에 화면이 본다
 *
 * PIPELINE[HB137] CCP 검증점검 작성 DTO
 */
package com.haccp.draft.ccp.dto;

import com.haccp.docs.ccp.dto.DocCorrectiveDto;
import java.util.List;
import java.util.Map;
import lombok.Data;

@Data
public class CcpVerifyDraftSaveRequest {
    // 작성 양식코드 — tml_ccp_chk_NNN. 필수
    private String tmplCd;
    // 기존 문서 idx — 신규면 null/0
    private Long docIdx;
    // 일자(점검일자) YYYYMMDD
    private String baseDt;
    // 점검자 — 저장 시 이름=사용자면 서명 스냅샷
    private String checkerNm;
    // 승인자 — 헤더. 서명 규칙은 점검자와 같다
    private String approverNm;
    // 적용 버전 — 자사 양식은 1
    private Integer verNo;
    // 점검 행
    private List<Map<String, Object>> items;
    // 특이사항 — 개행 보존
    private String specialNote;
    // 개선조치 및 결과
    private String improveNote;
    // 조치
    private String actionNm;
    // 확인
    private String confirmNm;
    // 이탈·개선조치 푸터
    private DocCorrectiveDto corrective;
}
