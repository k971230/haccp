/**
 * DocCycleFormRow — 문서주기 좌측 양식 목록 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) SP 컬럼과 1:1. formTy 만 sys_yn 별칭이다
 *   2) 주기 없는 양식은 목록 행의 결재선을 우측이 쓴다
 *   3) ruleYn 이 주기 등록여부다
 *
 * PIPELINE[HB99] 문서주기 DTO
 */
package com.haccp.docs.sch.dto;

import lombok.Data;

/** 좌측 양식 1건 */
@Data
public class DocCycleFormRow {
    private String tmplCd;
    private String tmplNm;
    // sys_yn 별칭 — 화면 계약 formTy
    private String formTy;
    private String docKind;
    private String cycleCd;
    private String ruleYn;
    private String useYn;
    private String apprLineCd;
    private String apprLineNm;
}
