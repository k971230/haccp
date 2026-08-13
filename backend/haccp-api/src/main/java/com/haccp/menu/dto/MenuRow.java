/**
 * MenuRow.java — 메뉴 1건 Row DTO.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) sp_menu_nav_r_000 결과 1행 — 메뉴 자신의 정보와 연결된 화면의 권한을 함께 담는다
 *   2) 서버는 평면 목록만 보내고, 트리 조립은 프론트 SideMenu가 hMenuCd(상위 메뉴코드)로 수행한다
 *   3) 조회권한(readYn)이 없는 화면은 SP가 아예 제외하므로, 프론트는 목록에 온 것을 그릴 수 있다고 믿으면 된다
 *
 * PIPELINE[HB30] menu DTO
 */
package com.haccp.menu.dto;

// 역할 — @Getter/@Setter 접근자 (MyBatis 매핑 대상)
import lombok.Getter;
import lombok.Setter;

/** 메뉴 평면 목록 1건 — 프론트가 hMenuCd로 트리를 만든다 */
@Getter
@Setter
public class MenuRow {

    /** tbl_menu.idx — 대리키 */
    private Long idx;
    /** 메뉴코드 — 트리 노드 식별자 */
    private String menuCd;
    /** 메뉴명 — 사이드 메뉴 표시 문구 */
    private String menuNm;
    /** 상위 메뉴코드 — 비어 있으면(= 최상위) 루트 노드 */
    private String hMenuCd;
    /** 연결 화면코드 — null이면(= 분류 노드) 클릭해도 화면이 열리지 않는다 */
    private String scrnCd;
    /** 모듈 구분 — 메뉴 대분류(문서·기준정보·시스템 등) */
    private String moduleCd;
    /** 형제 노드 간 정렬 순서 */
    private Integer sortNo;
    /** 조회 권한 Y/N — 분류 노드는 N일 수 있다(화면이 없으므로) */
    private String readYn;
    /** 등록 권한 Y/N — 신규 버튼 활성 조건 */
    private String writeYn;
    /** 수정 권한 Y/N — 셀 편집 활성 조건 */
    private String modifyYn;
    /** 삭제 권한 Y/N — 삭제 버튼 활성 조건 */
    private String deleteYn;
    /** 출력 권한 Y/N — PDF 출력 버튼 활성 조건 */
    private String printYn;
}
