/**
 * ScreenAuthResolver — 요청 경로 → 화면코드·권한 칸 정적 맵.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) FE SCREEN_PATH 와 같은 칸을 /api/v1 앞에 붙인 접두로 화면을 찾는다. 정책 테이블은 없다
 *   2) 문서 허브·기준정보 /bas/{type}·서명 /sys/users 는 화면 URL 이 아니라서 여기 예외 맵으로 둔다
 *   3) 맵에 없고 화이트리스트도 아니면 empty — 인터셉터는 통과시키고 로그만 남긴다
 *
 * PIPELINE[HB145] 화면 권한 인터셉터
 */
package com.haccp.common.auth;

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
            "legal-document-upload",
            "attach",
            "sign-ready",
            "sign-ok",
            "hwp-write",
            "process-hwp",
            "calib-self-hwp",
            "calib-ext-hwp",
            "waste-hwp",
            "verify-ca-hwp",
            "personal-hyg-hwp",
            "area-hyg-hwp",
            "water-hwp",
            "verify-plan-hwp",
            "verify-check-hwp",
            "verify-report-hwp",
            "prod-test-hwp",
            "surface-test-hwp",
            "receiving-insp-hwp",
            "submaterial-recv-hwp",
            "shipment-log-hwp",
            "inventory-hwp",
            "vehicle-hwp",
            "edu-plan-hwp",
            "edu-log-hwp",
            "bad-product-hwp",
            "claim-hwp",
            "recall-hwp",
            "eval-hwp",
            "handover-hwp"
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
        doc.add("ccp-cold-monitor");
        doc.add("ccp-metal-monitor");
        doc.add("ccp-heat-monitor");
        doc.add("ccp-sanitize-monitor");
        doc.add("ccp-filter-monitor");
        doc.add("ccp-verification-check");
        doc.add("hygiene-process-check");
        doc.add("daily-hygiene-check");
        doc.add("pest-control-check");
        doc.add("health-cert-record");
        DOC_HUB_SCREENS = Set.copyOf(doc);
    }

    // FE SCREEN_PATH — 값(경로) 길이 내림차순으로 최장 접두를 고른다
    private static final List<Map.Entry<String, String>> SCREEN_PREFIXES;
    // /api/v1/bas/{masterType} → scrnCd
    private static final Map<String, String> MASTER_SCRN = Map.ofEntries(
            Map.entry("product", "product-management"),
            Map.entry("material", "material-management"),
            Map.entry("partner", "partner-management"),
            Map.entry("storage", "storage-management"),
            Map.entry("measuring-device", "measuring-device-management"),
            Map.entry("vehicle", "vehicle-management"),
            Map.entry("work-area", "work-area-management"),
            Map.entry("equipment", "equipment-management"),
            Map.entry("pest-device", "pest-device-management"),
            Map.entry("ccp-limit", "ccp-cold-monitor")
    );

    static {
        Map<String, String> pathToScrn = new LinkedHashMap<>();
        pathToScrn.put("/today-tasks", "today-tasks");
        putAll(pathToScrn, "/docs/sch", "schedule-cycle-management");
        putAll(pathToScrn, "/docs/hwp", "hwp-template-management");
        putAll(
                pathToScrn,
                "/docs/html",
                "hyg-process-template",
                "ccp-verify-template",
                "ccp-pkg-template",
                "ccp-htg-template",
                "ccp-mtl-template"
        );
        putAll(
                pathToScrn,
                "/docs/ccp",
                "ccp-cold-monitor",
                "ccp-metal-monitor",
                "ccp-heat-monitor",
                "ccp-sanitize-monitor",
                "ccp-filter-monitor",
                "ccp-verification-check",
                "process-hwp"
        );
        putAll(
                pathToScrn,
                "/docs/prp",
                "hygiene-process-check",
                "daily-hygiene-check",
                "pest-control-check",
                "health-cert-record",
                "facility-equipment-check",
                "calibration-target-management",
                "equipment-history",
                "pest-device-history",
                "equipment-management",
                "pest-device-management",
                "visual-insp-standard",
                "calib-self-hwp",
                "calib-ext-hwp",
                "waste-hwp",
                "verify-ca-hwp",
                "personal-hyg-hwp",
                "area-hyg-hwp",
                "water-hwp",
                "verify-plan-hwp",
                "verify-check-hwp",
                "verify-report-hwp",
                "prod-test-hwp",
                "surface-test-hwp"
        );
        putAll(
                pathToScrn,
                "/docs/logis",
                "receiving-insp-hwp",
                "submaterial-recv-hwp",
                "shipment-log-hwp",
                "inventory-hwp",
                "vehicle-hwp"
        );
        putAll(
                pathToScrn,
                "/docs/admin",
                "visitor-log",
                "edu-plan-hwp",
                "edu-log-hwp",
                "bad-product-hwp",
                "claim-hwp",
                "recall-hwp",
                "eval-hwp",
                "handover-hwp"
        );
        putAll(pathToScrn, "/draft/hyg", "hyg-process");
        putAll(pathToScrn, "/draft/ccp-chk", "ccp-verify");
        putAll(pathToScrn, "/draft/ccp-monitoring", "ccp-pkg", "ccp-htg", "ccp-mtl");
        putAll(pathToScrn, "/draft/hwp-doc", "hwp-write");
        putAll(pathToScrn, "/flow/box", "document-inbox", "legal-document-upload");
        putAll(pathToScrn, "/flow/appr", "attach", "sign-ready", "sign-ok");
        putAll(pathToScrn, "/flow/ca", "corrective-action-management");
        putAll(
                pathToScrn,
                "/bas/master",
                "product-management",
                "material-management",
                "partner-management",
                "storage-management",
                "measuring-device-management",
                "vehicle-management",
                "work-area-management"
        );
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
            return Optional.of(ScreenAuthMatch.screen("hwp-template-management", action));
        }
        Optional<ScreenAuthMatch> bas = resolveBas(path, action);
        if (bas.isPresent()) {
            return bas;
        }
        if (path.startsWith("/api/v1/tsk/today-tasks") || path.startsWith("/api/v1/tsk/notifications")) {
            return Optional.of(ScreenAuthMatch.screen("today-tasks", action));
        }
        if (path.startsWith("/api/v1/sys/users/")) {
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
        return path.startsWith("/api/v1/sys/users/me");
    }

    /** /api/v1/bas 예외 — 기준정보 type · 사용양식 허브 */
    private static Optional<ScreenAuthMatch> resolveBas(String path, ScreenAuthAction action) {
        if (!path.startsWith("/api/v1/bas/")) {
            return Optional.empty();
        }
        if (path.startsWith("/api/v1/bas/company-templates")
                || path.startsWith("/api/v1/bas/company-check-items")
                || path.startsWith("/api/v1/bas/company-forms")
                || path.startsWith("/api/v1/bas/company-form-items")
                || path.startsWith("/api/v1/bas/template-export-hist")) {
            return Optional.of(ScreenAuthMatch.screen("hwp-template-management", action));
        }
        if (path.startsWith("/api/v1/bas/legal-types")) {
            return Optional.of(ScreenAuthMatch.screen("legal-document-upload", action));
        }
        if (path.startsWith("/api/v1/bas/schedule-rules")) {
            return Optional.of(ScreenAuthMatch.screen("schedule-cycle-management", action));
        }
        // /api/v1/bas/{type}/list|save|delete
        String rest = path.substring("/api/v1/bas/".length());
        int slash = rest.indexOf('/');
        String type = slash < 0 ? rest : rest.substring(0, slash);
        String scrn = MASTER_SCRN.get(type);
        if (scrn != null) {
            return Optional.of(ScreenAuthMatch.screen(scrn, action));
        }
        return Optional.empty();
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
