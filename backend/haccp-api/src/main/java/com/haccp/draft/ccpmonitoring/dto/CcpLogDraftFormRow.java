/**
 * CcpLogDraftFormRow — 작성 가능 양식 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-08-24
 * 코멘트:
 *   1) CCP 포장·가열·금속검출 작성 3화면이 같은 DTO 를 쓴다. 화면마다 복제하지 않는다
 *   2) 모양은 HYG(draft.hyg)·CCP검증(draft.ccp)과 같다. 서버 테이블·SP 만 계열별로 다르다
 *   3) 양식관리에서 사용여부 예로 둔 자사 양식만 온다
 *
 * PIPELINE[HB139] CCP 모니터링 작성 DTO
 */
package com.haccp.draft.ccpmonitoring.dto;

import lombok.Data;

@Data
public class CcpLogDraftFormRow {
    // 양식코드 — tml_ccp_pkg_001 / tml_ccp_htg_001 / tml_ccp_mtl_001 …
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
