/**
 * ScreenAuthResolver — 요청 경로 → 화면코드·권한 칸 정적 맵.
 *
 * 개발자: 박승우
 * 일자: 2026-09-01
 * 코멘트:
 *   1) FE SCREEN_PATH 와 같은 칸을 /api/v1 앞에 붙인 접두로 화면을 찾는다. 정책 테이블은 없다
 *   2) 문서 허브·서명 /sys/users 는 화면 URL 이 아니라서 여기 예외 맵으로 둔다
 *   3) 맵에 없고 화이트리스트도 아니면 empty — 인터셉터는 통과시키고 로그만 남긴다
 *
 * PIPELINE[HB145] 화면 권한 인터셉터
 */
package com.haccp.common.auth;

import jakarta.servlet.http.HttpServletRequest;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

/** URL 접두 → scrnCd. 화면 추가 시 SCREEN_PATH 와 이 맵을 같이 넣는다. */
public final class ScreenAuthResolver {

    /** 문서 허브 삭제·HWP 저장 — HTML 작성 권한으로 HWP 를 지·저장하지 못하게 한다 */
    public static final Set<String> HWP_HUB_SCREENS = Set.of(
            "document-inbox",
            "attach",
            "sign-ready",
            "sign-ok",
            "hwp-write"
    );

    /** 문서 허브 조회·결재·첨부 — HTML 작성 화면도 전송 API 가 허브를 탄다 */
    public static final Set<String> DOC_HUB_SCREENS;

    static {
        HashSet<String> doc = new HashSet<>(HWP_HUB_SCREENS);
        doc.add("today-tasks");
        doc.add("hyg-process");
        doc.add("ccp-verify");
        doc.add("ccp-pkg");
        doc.add("ccp-htg");
        doc.add("ccp-mtl");
        DOC_HUB_SCREENS = Set.copyOf(doc);
    }

    // FE SCREEN_PATH — 값(경로) 길이 내림차순으로 최장 접두를 고른다
    private static final List<Map.Entry<String, String>> SCREEN_PREFIXES;
    static {
        Map<String, String> pathToScrn = new LinkedHashMap<>();
        pathToScrn.put("/today-tasks", "today-tasks");
        putAll(pathToScrn, "/docs/sch", "schedule-cycle-management");
        putAll(pathToScrn, "/docs/hwp", "hwp-template-management");
        // 중분류 html 은 양식 작성(draft)이 쓴다 — tbl_menu UNIQUE (co_cd, menu_cd)
        putAll(
                pathToScrn,
                "/docs/html-form",
                "hyg-process-template",
                "ccp-verify-template",
                "ccp-pkg-template",
                "ccp-htg-template",
                "ccp-mtl-template"
        );
        putAll(pathToScrn, "/draft/html", "hyg-process", "ccp-verify");
        putAll(pathToScrn, "/draft/ccp-monitoring", "ccp-pkg", "ccp-htg", "ccp-mtl");
        putAll(pathToScrn, "/draft/hwp-doc", "hwp-write");
        putAll(pathToScrn, "/flow/box", "document-inbox");
        putAll(pathToScrn, "/flow/appr", "attach", "sign-ready", "sign-ok");
        putAll(pathToScrn, "/flow/ca", "corrective-action-management");
        putAll(
                pathToScrn,
                "/sys/code",
                "common-code-management",
                "menu-management",
                "role-management",
                "department-management",
                "user-management",
                "approval-line-management"
        );
        putAll(pathToScrn, "/sys/logs", "login-history", "screen-usage-statistics", "audit-log");
        List<Map.Entry<String, String>> ordered = new ArrayList<>(pathToScrn.entrySet());
        ordered.sort(Comparator.comparingInt((Map.Entry<String, String> e) -> e.getKey().length()).reversed());
        SCREEN_PREFIXES = List.copyOf(ordered);
    }

    private ScreenAuthResolver() {}

    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) HTTP 메서드와 URI 로 권한 검사 대상을 고른다
     *   2) 인터셉터가 로그인 사용자 권한과 대조하기 전에 호출한다
     *   3) 화이트리스트·미매핑이면 empty (검사 생략)
     */
    public static Optional<ScreenAuthMatch> resolve(
            // GET/POST/PUT — OPTIONS 는 호출부가 이미 걸렀다
            String method,
            // 컨텍스트 경로 없는 요청 URI — /api/v1/...
            String uri
    ) {
        if (uri == null || uri.isBlank()) {
            return Optional.empty();
        }
        String path = stripQuery(uri);
        if (isWhitelisted(path)) {
            return Optional.empty();
        }
        ScreenAuthAction action = actionOf(method, path);
        if (path.startsWith("/api/v1/docs/documents")) {
            String lower = path.toLowerCase(Locale.ROOT);
            if (lower.contains("/hwp/save")
                    || lower.contains("/validate-delete")
                    || lower.endsWith("/delete")) {
                return Optional.of(ScreenAuthMatch.hubHwp(action));
            }
            return Optional.of(ScreenAuthMatch.hubDoc(action));
        }
        if (path.startsWith("/api/v1/docs/templates")) {
            // GET 원본 — HWP 작성이 양식을 연다. JWT+SP 가 회사를 가른다.
            // 업로드 POST 는 사용양식 관리 화면이다.
            if (isGet(method) && path.endsWith("/form")) {
                return Optional.empty();
            }
            return Optional.of(ScreenAuthMatch.screen("hwp-template-management", action));
        }
        if (path.startsWith("/api/v1/tsk/today-tasks") || path.startsWith("/api/v1/tsk/notifications")) {
            return Optional.of(ScreenAuthMatch.screen("today-tasks", action));
        }
        if (path.startsWith("/api/v1/sys/users/")) {
            // GET 서명 이미지 — HTML 지면 도장이 자사 서명을 그린다.
            // 업로드·삭제는 사용자관리 화면이다. /me 는 이미 화이트리스트.
            if (isGet(method) && path.toLowerCase(Locale.ROOT).endsWith("/sign")) {
                return Optional.empty();
            }
            return Optional.of(ScreenAuthMatch.screen("user-management", action));
        }
        for (Map.Entry<String, String> e : SCREEN_PREFIXES) {
            String apiBase = "/api/v1" + e.getKey();
            if (path.equals(apiBase) || path.startsWith(apiBase + "/")) {
                return Optional.of(ScreenAuthMatch.screen(e.getValue(), action));
            }
        }
        return Optional.empty();
    }

    /** 감사 적재가 읽는 요청 화면코드 헤더 — FE 활성 탭. 허브 API 만 신뢰 집합으로 받는다 */
    public static final String SCRN_HEADER = "X-Haccp-Scrn";

    /** 요청에 붙인 확정 화면코드 — AuditWriter 가 읽는다 */
    static final String SCRN_ATTR = "haccp.audit.scrnCd";

    /**
     * 개발자: 박승우
     * 일자: 2026-09-02
     * 코멘트:
     *   1) 변경 감사 로그에 남길 화면코드를 요청에 붙인다
     *   2) 화면 API 는 URL 맵 값만 쓴다. 허브는 헤더가 허용 집합일 때만 받는다
     *   3) 헤더를 속여도 화면 API 는 URL 이 이기고, 허브는 허용 화면 밖이면 빈다
     */
    public static void bindRequestScreen(
            // 현재 요청 — 속성·헤더
            HttpServletRequest request,
            // resolve 결과. empty 면 화면코드를 안 붙인다
            Optional<ScreenAuthMatch> match
    ) {
        if (request == null || match == null || match.isEmpty()) {
            return;
        }
        ScreenAuthMatch m = match.get();
        if (m.hubKind() == ScreenAuthMatch.HubKind.NONE) {
            if (m.scrnCd() != null && !m.scrnCd().isBlank()) {
                request.setAttribute(SCRN_ATTR, m.scrnCd());
            }
            return;
        }
        String hdr = request.getHeader(SCRN_HEADER);
        if (hdr == null || hdr.isBlank()) {
            return;
        }
        String cd = hdr.trim();
        Set<String> allowed = m.hubKind() == ScreenAuthMatch.HubKind.HWP
                ? HWP_HUB_SCREENS
                : DOC_HUB_SCREENS;
        if (allowed.contains(cd)) {
            request.setAttribute(SCRN_ATTR, cd);
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-02
     * 코멘트:
     *   1) 인터셉터가 붙인 화면코드를 읽는다
     *   2) 감사 적재기가 호출한다
     *   3) 없으면 빈 문자열 — 배치·단위시험처럼 요청이 없을 때
     */
    public static String requestScreen(
            // 현재 요청. null 이면 빈 문자열
            HttpServletRequest request
    ) {
        if (request == null) {
            return "";
        }
        Object attr = request.getAttribute(SCRN_ATTR);
        if (attr instanceof String s && !s.isBlank()) {
            return s.trim();
        }
        return "";
    }

    /** 쿼리스트링을 떼어 경로만 남긴다 */
    static String stripQuery(String uri) {
        int q = uri.indexOf('?');
        return q < 0 ? uri : uri.substring(0, q);
    }

    /**
     * JWT 이후에도 화면 권한을 보지 않는 경로.
     * /auth/** · 셸 공용 · 본인 서명. UserController 의 /sys/users/me 를 여기 적는다.
     */
    static boolean isWhitelisted(String path) {
        if (path.startsWith("/api/v1/auth/")) return true;
        if (path.startsWith("/api/v1/menu/")) return true;
        if (path.startsWith("/api/v1/code/")) return true;
        if (path.startsWith("/api/v1/pref/")) return true;
        if (path.startsWith("/api/v1/log/")) return true;
        /*
         * 사용양식 목록은 공통코드와 같은 **공용 조회**다 — 여러 화면의 콤보가 쓴다.
         * HWP 작성(hwp-write)과 이탈·개선조치(corrective-action-management) 둘이 부른다.
         *
         * 아래에서 /api/v1/docs/templates 전체를 hwp-template-management 화면에 묶는 바람에,
         * 조회 전용(VIEWER)이 **자기가 볼 권한을 가진 이탈·개선조치 화면에서**
         * 남의 화면 권한 때문에 403 을 맞고 양식 콤보가 비었다.
         *
         * 목록은 여기. GET 원본(/{tmplCd}/form)은 resolve 에서 GET 만 연다(업로드 POST 는 화면).
         * 회사 범위는 JWT 로 SP 가 이미 가른다.
         */
        if (path.equals("/api/v1/docs/templates/list")) return true;
        /*
         * 자사 사용자·결재선 목록도 콤보다. 문서주기 담당자·로그인 이력 트리가 부른다.
         * 사용자관리·결재선관리 화면에 묶이면 작성 계정은 메뉴는 있는데 403 이다.
         * 저장·삭제는 그대로 그 화면 권한이다.
         */
        if (path.equals("/api/v1/sys/code/user-management/list")) return true;
        if (path.equals("/api/v1/sys/code/approval-line-management/list")) return true;
        return path.startsWith("/api/v1/sys/users/me");
    }

    /** GET·HEAD 이면 조회. 업로드 POST 와 나눠 공용 조회만 열 때 쓴다 */
    static boolean isGet(String method) {
        String m = method == null ? "GET" : method.toUpperCase(Locale.ROOT);
        return "GET".equals(m) || "HEAD".equals(m);
    }

    /**
     * 메서드 + 경로 접미로 권한 칸을 고른다.
     * /delete · /validate-delete → DELETE, /save → SAVE, export-pdf → PRINT, GET → READ.
     */
    static ScreenAuthAction actionOf(String method, String path) {
        String lower = path.toLowerCase(Locale.ROOT);
        if (lower.contains("/validate-delete") || lower.endsWith("/delete") || lower.contains("/delete/")) {
            return ScreenAuthAction.DELETE;
        }
        if (lower.contains("export-pdf") || lower.endsWith("/print") || lower.contains("/print/")) {
            return ScreenAuthAction.PRINT;
        }
        String m = method == null ? "GET" : method.toUpperCase(Locale.ROOT);
        if (lower.endsWith("/save") || lower.contains("/save/")) {
            return ScreenAuthAction.SAVE;
        }
        if ("GET".equals(m) || "HEAD".equals(m)) {
            return ScreenAuthAction.READ;
        }
        if ("PUT".equals(m) || "PATCH".equals(m)) {
            return ScreenAuthAction.MODIFY;
        }
        return ScreenAuthAction.WRITE;
    }

    private static void putAll(Map<String, String> into, String prefix, String... cds) {
        for (String cd : cds) {
            into.put(prefix + "/" + cd, cd);
        }
    }
}
