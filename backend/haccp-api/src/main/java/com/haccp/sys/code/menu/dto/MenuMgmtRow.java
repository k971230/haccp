/**
 * MenuMgmtRow — 메뉴 관리 목록 1행.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 메뉴 관리 목록 SP 컬럼과 1:1
 *   2) 조인 컬럼도 필드다
 *   3) 로그인 트리 MenuRow 와 단순명이 겹치면 MyBatis alias 가 죽는다
 *
 * PIPELINE[HB93] 메뉴 관리 DTO
 */
package com.haccp.sys.code.menu.dto;

import lombok.Data;

@Data
public class MenuMgmtRow {
    private Long idx;
    private String menuCd;
    private String menuNm;
    private String hMenuCd;
    private String scrnCd;
    private Integer sortNo;
    private String useYn;
}
