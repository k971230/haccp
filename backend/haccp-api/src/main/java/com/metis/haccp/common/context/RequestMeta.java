/**
 * RequestMeta.java — 요청 접속 메타(IP·User-Agent·기기구분) 추출.
 *
 * 개발자: 박승우
 * 일자: 2026-08-05
 * 코멘트:
 *   1) 로그인 이력·화면조회 로그에 남길 접속 정보를 HttpServletRequest에서 한 번에 뽑아낸다
 *   2) 컨트롤러가 만들어 서비스로 넘긴다 — 서비스가 서블릿 API에 직접 의존하지 않게 하기 위함
 *   3) 감사 대응 시 "누가 언제 어디서" 의 '어디서' 를 담당하는 값이다. 추정이 틀려도 업무를 막지 않는다
 *
 * PIPELINE[HB13] common 모듈
 */
package com.metis.haccp.common.context;

// 역할 — HTTP 요청에서 헤더·원격주소 추출
import jakarta.servlet.http.HttpServletRequest;

/**
 * 접속 메타 — 불변 레코드.
 *
 * @param ipAddr    접속 IP (프록시 뒤에서는 X-Forwarded-For 첫 값)
 * @param userAgent 브라우저 User-Agent 원문 (DB 컬럼 길이에 맞춰 잘라 담는다)
 * @param deviceGbn 기기 구분 — PC / MOBILE / TABLET
 */
public record RequestMeta(String ipAddr, String userAgent, String deviceGbn) {

    /** tbl_login_log.user_agent / tbl_view_log.user_agent 컬럼 길이 상한 — 초과분은 버린다 */
    private static final int USER_AGENT_MAX = 300;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) HTTP 요청에서 IP·User-Agent·기기구분을 추출해 RequestMeta를 만든다
     *   2) 로그인·로그아웃·화면조회 로그를 남기는 컨트롤러 진입 지점에서 호출한다
     *   3) 헤더가 없어도 예외 없이 null·PC 기본값으로 채운 객체를 반환한다
     */
    public static RequestMeta of(
            // 현재 HTTP 요청 — 헤더와 원격 주소만 읽고 본문은 건드리지 않는다
            // null을 넘기면 NullPointerException이 되므로, 컨트롤러 파라미터로 받은 값을 그대로 넘긴다
            HttpServletRequest req
    ) {
        return new RequestMeta(clientIp(req), shortUserAgent(req), deviceOf(req.getHeader("User-Agent")));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) 프록시·로드밸런서를 고려해 실제 클라이언트 IP를 판별한다
     *   2) 접속 로그를 남기기 직전에 호출한다
     *   3) X-Forwarded-For가 있으면 첫 항목, 없으면 소켓 원격주소를 반환한다
     */
    private static String clientIp(
            // 현재 HTTP 요청 — X-Forwarded-For 헤더와 getRemoteAddr를 확인한다
            HttpServletRequest req
    ) {
        // Nginx 프록시 경유 시 실제 IP는 이 헤더에 "클라이언트, 프록시1, 프록시2" 형태로 들어온다
        String xff = req.getHeader("X-Forwarded-For");
        // xff가 비어있지 않을 때(= 프록시 경유) 첫 항목이 최초 클라이언트다
        if (xff != null && !xff.isBlank()) {
            int comma = xff.indexOf(',');
            return (comma > 0 ? xff.substring(0, comma) : xff).trim();
        }
        return req.getRemoteAddr();
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) User-Agent 원문을 DB 컬럼 길이에 맞게 잘라 반환한다
     *   2) 접속 로그 적재 직전에 호출한다
     *   3) 헤더가 없으면 null, 상한 초과면 앞부분만 반환한다
     */
    private static String shortUserAgent(
            // 현재 HTTP 요청 — User-Agent 헤더만 읽는다
            HttpServletRequest req
    ) {
        String ua = req.getHeader("User-Agent");
        // ua가 null일 때(= 헤더 없는 비브라우저 호출) 그대로 null을 남긴다
        if (ua == null) return null;
        return ua.length() <= USER_AGENT_MAX ? ua : ua.substring(0, USER_AGENT_MAX);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-05
     * 코멘트:
     *   1) User-Agent 문자열로 접속 기기 종류를 추정한다
     *   2) 로그인·화면조회 로그의 기기구분 컬럼을 채울 때 호출한다
     *   3) 태블릿·모바일 신호가 없거나 헤더가 없으면 PC로 간주한다 (통계용 추정이라 오판을 허용한다)
     */
    private static String deviceOf(
            // User-Agent 원문 — null이면 PC로 처리한다
            String ua
    ) {
        // ua가 null일 때(= 헤더 없음) 서버 간 호출이거나 비브라우저 — PC로 집계한다
        if (ua == null) return "PC";
        String u = ua.toLowerCase();
        // iPad·Android 태블릿은 Mobile 문자열이 없는 경우가 있어 태블릿을 먼저 판정한다
        if (u.contains("ipad") || (u.contains("android") && !u.contains("mobile"))) return "TABLET";
        if (u.contains("mobi") || u.contains("iphone")) return "MOBILE";
        return "PC";
    }
}
