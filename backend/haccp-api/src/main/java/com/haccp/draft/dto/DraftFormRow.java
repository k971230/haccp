/**
 * DraftFormRow — 작성 가능 양식 1행 (양식 작성 5화면 공용).
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) HYG·CCP검증·CCP 모니터링 3종이 같은 모양을 쓴다. 화면별 dto 로 복제하지 않는다
 *   2) 양식관리에서 사용여부 예로 둔 자사 양식만 온다 — SQL 이 use_yn='Y' 로 좁힌다
 *   3) 양식 선택 팝업(일자·양식코드·양식명) 목록이자 신규 작성 대상 후보다
 *
 * 규칙 08 「공유 유틸은 영역 루트에 둔다」에 따라 com.haccp.draft.dto 에 둔다.
 * FE 대응 타입은 api/draft/htmlFormDraftTypes.ts 의 HtmlFormDraftForm 이다.
 *
 * PIPELINE[HB135] 양식 작성 공용 DTO
 */
package com.haccp.draft.dto;

import lombok.Data;

@Data
public class DraftFormRow {
    // 양식코드 — html_hyg_prc_001 / html_ccp_chk_001 / html_ccp_pkg_001 …
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
