/**
 * HygProcessSaveRequest — 공정점검표 저장 본문.
 *
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) items·하단 4칸은 payload JSON으로 SP에 넘긴다
 *   2) 신규는 docIdx 생략. 승인자는 헤더 서명 스냅샷
 *   3) 이탈 푸터는 DocCorrectiveSupport가 따로 저장한다
 *
 * PIPELINE[HB131] 공정점검 DTO
 */
package com.haccp.docs.html.hygprocess.dto;

import com.haccp.ccp.dto.DocCorrectiveDto;
import java.util.List;
import java.util.Map;
import lombok.Data;

@Data
public class HygProcessSaveRequest {
    // 기존 문서 idx — 신규면 null/0
    private Long docIdx;
    // 점검일자 YYYYMMDD
    private String baseDt;
    // 점검자 — 저장 시 이름=사용자면 서명 스냅샷
    private String checkerNm;
    // 승인자 — 헤더. 서명 규칙은 점검자와 같다
    private String approverNm;
    // 적용 버전 — 0=표준
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
