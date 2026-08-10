/**
 * GridPrefRow.java — 그리드 열 설정 1건 Row DTO.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) sp_tbl_grid_pref_r_000 결과 1행 — 사용자가 조정한 열 너비·표시여부·정렬 상태를 담는다
 *   2) prefJson은 서버가 해석하지 않는 불투명 문자열이다. 구조는 프론트 그리드 컴포넌트가 정한다
 *   3) mes-api는 화면·그리드 1건씩 문자열로 주고받았으나, 여기서는 화면 진입 시 목록으로 한 번에 받는다
 *      (한 화면에 그리드가 여러 개인 마스터-디테일 구조가 많아 왕복 수를 줄이려는 목적)
 *
 * PIPELINE[HB38] pref DTO
 */
package com.metis.haccp.pref.dto;

// 역할 — @Getter/@Setter 접근자 (MyBatis 매핑 대상)
import lombok.Getter;
import lombok.Setter;

/** 그리드 열 설정 1건 — (화면코드, 그리드 식별자)당 JSON 한 덩어리 */
@Getter
@Setter
public class GridPrefRow {

    /** tbl_grid_pref.idx — 대리키 */
    private Long idx;
    /** 화면코드 — 프론트 screenRegistry 키 */
    private String scrnCd;
    /** 그리드 식별자 — 편집 그리드의 persistId (한 화면에 여러 개일 수 있다) */
    private String gridId;
    /** 열 설정 JSON 원문 — 서버는 저장·전달만 하고 내용을 해석하지 않는다 */
    private String prefJson;
}
