/**
 * DocCycleRow — 문서주기 단건.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) sp_schedule_cycle_management_r_000 컬럼과 1:1
 *   2) details 는 jsonb 배열. 서비스가 객체 목록으로 펼친다
 *   3) 배치 활성 주기도 같은 행을 쓴다. coCd 는 배치만
 *
 * PIPELINE[HB99] 문서주기 DTO
 */
package com.haccp.docs.sch.dto;

import lombok.Data;

/** 주기 1건 + 반복 상세 */
@Data
public class DocCycleRow {
    // 배치만 — 화면 단건에는 없다
    private String coCd;
    private String tmplCd;
    private String tmplNm;
    private String baseDt;
    private String cycleCd;
    private String nonworkRule;
    private String dueTime;
    private String deptCd;
    private String deptNm;
    private String userId;
    private String userNm;
    private String useYn;
    private String apprLineCd;
    private String apprLineNm;
    // 반복 상세 — 매퍼는 jsonb 텍스트, 서비스가 배열로 펼친다
    private Object details;
}
