/**
 * HygProcessDraftFormRow — 작성 가능 양식 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) 양식관리(hyg-process-template)에서 사용여부 예로 둔 자사 양식만 온다
 *   2) 신규 작성 콤보와 좌측 목록 양식명 표시에 쓴다
 *   3) 표준 예시 html_hyg_prc_000 은 SQL 이 제외한다
 *
 * PIPELINE[HB135] 위생공정 작성 DTO
 */
package com.haccp.draft.hyg.dto;

import lombok.Data;

@Data
public class HygProcessDraftFormRow {
    // 양식코드 — html_hyg_prc_001 …
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
