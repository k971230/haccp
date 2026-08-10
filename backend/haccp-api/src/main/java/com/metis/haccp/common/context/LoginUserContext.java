/**
 * LoginUserContext.java — 요청 스코프 로그인 컨텍스트(ThreadLocal).
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) JwtFilter가 요청 진입 시 set, 종료 시 finally clear 한다. 서비스는 get/coCd/userId 로만 읽는다
 *   2) coCd()는 전 SP의 p_co_cd 로 넘어가는 테넌트 경계다 — 프론트 파라미터로 대체하면 타사 데이터가 열린다
 *   3) 스레드 풀 재사용 환경이므로 clear 누락은 다른 사용자에게 정보가 새는 사고로 이어진다
 *
 * PIPELINE[HB12] common 모듈
 */
package com.metis.haccp.common.context;

/** 요청 스코프 로그인 컨텍스트 보관소 (JwtFilter에서 set, 서비스에서 get). */
public final class LoginUserContext {

    // 스레드별 LoginUser 보관 — 요청당 1회 set/clear
    private static final ThreadLocal<LoginUser> HOLDER = new ThreadLocal<>();

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 정적 유틸리티 클래스이므로 인스턴스 생성을 막는다
     *   2) 외부에서 new 를 호출할 수 없도록 private 로 선언한다
     *   3) 호출 경로가 없으므로 항상 성공한다
     */
    private LoginUserContext() {}

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 현재 요청 스레드에 로그인 사용자를 저장한다
     *   2) JWT 검증이 성공한 뒤 컨트롤러·서비스 실행 전에 호출한다
     *   3) 성공 시 동일 스레드에서 사용자 정보를 조회할 수 있다. 요청 종료 시 clear 호출이 필수다
     */
    public static void set(
            // 저장할 로그인 사용자 — JwtProvider.parse 결과
            // null을 넣으면 이후 get()이 null을 돌려주므로, 인증 성공 시에만 호출한다
            LoginUser user
    ) {
        HOLDER.set(user);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 현재 요청 스레드의 로그인 사용자 전체를 조회한다
     *   2) /me 응답처럼 사용자 정보 전부가 필요할 때 호출한다
     *   3) 컨텍스트가 있으면 LoginUser, 인증 전(공개 경로)이면 null을 반환한다
     */
    public static LoginUser get() {
        return HOLDER.get();
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 현재 로그인 사용자의 회사코드(테넌트)를 조회한다
     *   2) 모든 SP 호출의 첫 인자 p_co_cd 를 채울 때 호출한다
     *   3) 컨텍스트가 있으면 회사코드, 미설정이면 null을 반환한다
     */
    public static String coCd() {
        LoginUser u = HOLDER.get();
        // u가 null일 때(= 인증 전 공개 경로) null 반환 — 호출부가 필수값 검증을 한다
        return u == null ? null : u.getCoCd();
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 현재 로그인 사용자의 아이디를 조회한다
     *   2) 저장자·수정자(ins_id/upd_id)와 사용자별 환경설정 키가 필요할 때 호출한다
     *   3) 컨텍스트가 있으면 사용자 ID, 미설정이면 null을 반환한다
     */
    public static String userId() {
        LoginUser u = HOLDER.get();
        return u == null ? null : u.getUserId();
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 현재 로그인 사용자의 권한 그룹코드를 조회한다
     *   2) 메뉴 트리·화면 권한을 권한 그룹 단위로 조회할 때 호출한다
     *   3) 컨텍스트가 있으면 권한 그룹코드, 미설정이면 null을 반환한다
     */
    public static String usrgrpCd() {
        LoginUser u = HOLDER.get();
        return u == null ? null : u.getUsrgrpCd();
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 현재 로그인 세션의 식별자(sid)를 조회한다
     *   2) 화면조회 로그(tbl_view_log)와 로그아웃 시각 기록에 세션 키가 필요할 때 호출한다
     *   3) 컨텍스트가 있으면 sid, 미설정이면 null을 반환한다
     */
    public static String sid() {
        LoginUser u = HOLDER.get();
        return u == null ? null : u.getSid();
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 현재 스레드의 로그인 사용자 정보를 제거한다
     *   2) JwtFilter의 요청 처리 finally 구간에서 반드시 호출한다
     *   3) 성공 시 스레드 풀 재사용 과정의 사용자 정보 누수를 방지한다
     */
    public static void clear() {
        HOLDER.remove();
    }
}
