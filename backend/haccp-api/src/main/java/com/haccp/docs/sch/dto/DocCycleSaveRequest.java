/**
 * DocCycleSaveRequest — 문서주기 저장 본문.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 우측 폼 1건을 camelCase 로 받는다
 *   2) details 는 반복 상세 배열. SP 가 전량 교체한다
 *   3) coCd·작업자는 JWT 만 쓴다
 *
 * PIPELINE[HB99] 문서주기 DTO
 */
package com.haccp.docs.sch.dto;

import java.util.List;
import lombok.Data;

/** 주기 업서트 폼 */
@Data
public class DocCycleSaveRequest {
    // 양식코드 — 필수
    private String tmplCd;
    // 관리 시작일 YYYYMMDD
    private String baseDt;
    // 주기코드
    private String cycleCd;
    // 비영업일 규칙
    private String nonworkRule;
    // 마감시각 HHMM
    private String dueTime;
    // 담당 부서코드
    private String deptCd;
    // 담당자 ID
    private String userId;
    // 사용여부 Y/N
    private String useYn;
    // 사용양식 결재선
    private String apprLineCd;
    // 반복 상세
    private List<DocCycleDetailRow> details;
}
