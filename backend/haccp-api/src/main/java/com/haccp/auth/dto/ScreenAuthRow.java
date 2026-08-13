/**
 * ScreenAuthRow.java — 화면 권한 Row DTO.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) sp_role_management_screen_r_000 결과 1행 — 화면 하나에 대한 조회·등록·수정·삭제·출력 권한
 *   2) 로그인 응답과 권한관리 화면이 같은 형태를 쓴다
 *   3) 권한 행이 없는 화면도 SP가 전부 'N'으로 채워 돌려주므로, 프론트는 누락 여부를 따질 필요가 없다
 *
 * PIPELINE[HB25] auth DTO
 */
package com.haccp.auth.dto;

// 역할 — @Getter/@Setter 접근자 (MyBatis 매핑 대상)
import lombok.Getter;
import lombok.Setter;

/** 화면 권한 1건 — 프론트 usePageCommands가 버튼 활성화 판정에 사용한다 */
@Getter
@Setter
public class ScreenAuthRow {

    /** tbl_role_screen.idx — 권한 미설정 화면이면 null */
    private Long idx;
    /** 화면코드 — 프론트 screenRegistry 키와 같다 */
    private String scrnCd;
    /** 화면명 */
    private String scrnNm;
    /** 모듈 구분 — 메뉴 대분류 */
    private String moduleCd;
    /** 조회 권한 Y/N — N이면 메뉴 자체가 보이지 않는다 */
    private String readYn;
    /** 등록 권한 Y/N — 신규 버튼 활성 조건 */
    private String writeYn;
    /** 수정 권한 Y/N — 셀 편집 활성 조건 */
    private String modifyYn;
    /** 삭제 권한 Y/N — 삭제 버튼 활성 조건 */
    private String deleteYn;
    /** 출력 권한 Y/N — PDF 출력 버튼 활성 조건 */
    private String printYn;
    /** 정렬 순서 */
    private Integer sortNo;
}
