/**
 * MenuSaveRow — 메뉴 저장 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 화면 그리드 camelCase 키를 그대로 받는다
 *   2) 메뉴코드·계층·화면코드는 화면에서 편집 불가
 *   3) coCd·작업자는 JWT 만
 *
 * PIPELINE[HB93] 메뉴 관리 DTO
 */
package com.haccp.sys.code.menu.dto;

import lombok.Data;

@Data
public class MenuSaveRow {
    // tbl_menu.idx — 없으면 신규
    private Long idx;
    // 메뉴코드
    private String menuCd;
    // 메뉴명
    private String menuNm;
    // 상위메뉴코드
    private String hMenuCd;
    // 화면코드
    private String scrnCd;
    // 정렬순서
    private Integer sortNo;
    // 사용여부 Y/N
    private String useYn;
}
