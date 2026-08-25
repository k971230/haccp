/**
 * ScreenAuthAction — API 한 건이 요구하는 tbl_role_screen 권한 칸.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) URL 접미(/list · /save · /delete)를 권한 컬럼에 대응한다
 *   2) ScreenAuthResolver 가 경로를 해석한 뒤 인터셉터가 이 값으로 Y/N 을 본다
 *   3) SAVE 는 신규(write)와 수정(modify)을 한 PUT /save 가 겸하므로 둘 중 하나면 통과
 *
 * PIPELINE[HB145] 화면 권한 인터셉터
 */
package com.haccp.common.auth;

/** 화면 권한 5종 + 저장(등록·수정 겸용) */
public enum ScreenAuthAction {
    READ,
    WRITE,
    MODIFY,
    /** PUT/POST /save — write_yn 또는 modify_yn */
    SAVE,
    DELETE,
    PRINT
}
