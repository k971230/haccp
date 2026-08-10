/**
 * LoginUser.java — 로그인 사용자 DTO (JWT 클레임·요청 컨텍스트).
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 로그인 성공 시 조립되어 JWT 클레임으로 직렬화되고, 요청마다 JwtFilter가 복원한다
 *   2) mes-api LoginUser와 다른 점 — 사업장(plntCd)·언어(langCd)·사원코드(empCd)가 없고, 화면조회 통계용 sid가 있다
 *      (문서의 작성자·점검자란에는 사번이 아니라 user_nm을 출력하므로 토큰에 사번을 실을 이유가 없다)
 *   3) coCd는 서버가 JWT에서만 읽는다. 프론트가 보내는 회사코드는 절대 신뢰하지 않는다
 *
 * PIPELINE[HB11] common 모듈
 */
package com.metis.haccp.common.context;

// 역할 — @Builder 생성자
import lombok.Builder;
// 역할 — @Getter 접근자
import lombok.Getter;

/** 로그인 사용자 컨텍스트 — 테넌트(coCd)는 서버가 강제한다. */
@Getter
@Builder
public class LoginUser {
    /** 회사코드 — 테넌트 식별자. 전 SP의 첫 인자 p_co_cd 로 전달된다 */
    private String coCd;
    /** 회사명 — TopBar 표시용 */
    private String coNm;
    /** 사용자 ID — 전 업체 통틀어 유일. 로그인 시 회사 선택이 없는 근거 */
    private String userId;
    /** 사용자명 — TopBar·결재선 표시용 */
    private String userNm;
    /** 권한 그룹코드 — tbl_role.usrgrp_cd (ADMIN / USER 등) */
    private String usrgrpCd;
    /** 부서코드 — TopBar 표시용 */
    private String deptCd;
    /** 부서명 — TopBar 표시용 */
    private String deptNm;
    /**
     * 세션 식별자 — 로그인 1회당 1개(UUID).
     * tbl_login_log.sid / tbl_view_log.sid 를 잇는 키로, UV(순방문자) 집계의 기준이 된다.
     */
    private String sid;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 현재 사용자가 업체 관리자 권한인지 판별한다
     *   2) 메뉴·화면 권한을 전권으로 처리할지 결정할 때 호출한다
     *   3) usrgrpCd가 ADMIN이면 true, 그 외이거나 null이면 false를 반환한다
     */
    public boolean isAdmin() {
        // mes-api는 userId가 admin인지로 판별했으나, HACCP는 업체별 관리자가 여러 명일 수 있어
        // 아이디가 아닌 권한 그룹(usrgrp_cd = 'ADMIN')으로 판별한다
        return "ADMIN".equalsIgnoreCase(usrgrpCd);
    }
}
