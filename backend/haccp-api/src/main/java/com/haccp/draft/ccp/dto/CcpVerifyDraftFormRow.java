/**
 * CcpVerifyDraftFormRow — 작성 가능 양식 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 양식관리(ccp-verify-template)에서 사용여부 예로 둔 자사 양식만 온다
 *   2) 양식 선택 팝업(일자·양식코드·양식명) 목록으로 쓴다
 *   3) 표준 예시 tml_ccp_chk_000 은 SQL 이 제외한다
 *
 * PIPELINE[HB137] CCP 검증점검 작성 DTO
 */
package com.haccp.draft.ccp.dto;

import lombok.Data;

@Data
public class CcpVerifyDraftFormRow {
    // 양식코드 — tml_ccp_chk_001 …
    private String tmplCd;
    // 양식명 — 자사 양식명(tmpl_nm_ovr) 우선
    private String verNm;
    // 회사 양식 버전 순번 — 자사는 1
    private Integer verNo;
    // 회사 사용여부 Y — SQL 이 Y 만 내린다
    private String useYn;
    // 양식 등록일자 YYYY-MM-DD — 양식 선택 팝업 첫 컬럼
    private String insDt;
}
