/**
 * TemplateFileNames — 템플릿 물리 파일명 정규화 유틸.
 *
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) docs 원본의 번호 접두만 제거하고 한글 본명은 그대로 둔다 (임의 작명 금지)
 *   2) 경로 조작 문자를 치환해 표준·자사 양식 루트 하위 저장에만 쓰이게 한다
 *   3) 나중에 오브젝트스토리지로 옮겨도 동일 규칙으로 키를 만든다
 *
 * PIPELINE[HB89] 템플릿 파일명
 * PIPELINE[HB90, HB92] 연관 모듈
 */
package com.haccp.docs.template;

// 역할 — 정규식 접두 제거
import java.util.regex.Matcher;
import java.util.regex.Pattern;
// 역할 — 상대 APP_FILE_ROOT를 모듈 절대경로로 고정
import java.nio.file.Path;

/** 템플릿 업로드·배포 시 공통 파일명 규칙 */
public final class TemplateFileNames {

    // 번호 접두 — 1. / 10. / 16-1. / "3. " 형태. 뒤 한글명은 캡처 그룹
    private static final Pattern NUMBER_PREFIX = Pattern.compile(
            "^(\\d+)([.\\-]\\d+)?\\s*[.\\s]\\s*(.+)$"
    );

    // 경로·제어문자만 치환 — 한글·공백·()[]는 유지 (제공 파일명 보존)
    private static final Pattern UNSAFE = Pattern.compile("[\\\\/:*?\"<>|\\r\\n\\t]+");

    private TemplateFileNames() {}

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) docs 원본 파일명에서 번호 접두만 벗긴다
     *   2) 매니페스트 target_name·업로드 표시명 생성 시 호출한다
     *   3) 접두가 없으면 원본 basename을 반환한다
     */
    public static String stripNumberPrefix(
            // docs 또는 업로드 원본 파일명 (경로 제외)
            String originalName
    ) {
        String name = basename(originalName);
        if (name.isBlank()) {
            return name;
        }
        Matcher matcher = NUMBER_PREFIX.matcher(name);
        if (matcher.matches()) {
            return matcher.group(3).trim();
        }
        return name.trim();
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) 경로 세그먼트로 쓸 안전한 한글 파일명을 만든다
     *   2) 자사 업로드·표준 배포 대상명에 공통 적용한다
     *   3) 확장자가 없으면 .hwp를 붙인다
     */
    public static String safeTemplateFileName(
            // 브라우저/docs 원본 파일명
            String originalName
    ) {
        String stripped = stripNumberPrefix(originalName);
        String safe = UNSAFE.matcher(stripped).replaceAll("_").trim();
        if (safe.isBlank()) {
            safe = "양식.hwp";
        }
        String lower = safe.toLowerCase();
        if (!(lower.endsWith(".hwp") || lower.endsWith(".hwpx"))) {
            safe = safe + ".hwp";
        }
        return safe;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 같은 폴더에서 이전 버전을 덮어쓰지 않도록 파일명에 업로드 시각을 끼운다
     *   2) 양식 파일 업로드가 이력 1건을 남길 때마다 호출한다 (초기화·불러오기가 과거 파일을 다시 열어야 한다)
     *   3) 확장자 앞에 _yyyyMMddHHmmss 를 붙이고, 확장자가 없으면 이름 끝에 붙인다
     */
    public static String versionedFileName(
            // 이미 safeTemplateFileName으로 정규화된 파일명
            String safeFileName,
            // 업로드 시각 문자열 yyyyMMddHHmmss — 호출부가 한 번만 만든다
            String stamp
    ) {
        String name = basename(safeFileName);
        String suffix = stamp == null || stamp.isBlank() ? "" : "_" + stamp.trim();
        int dot = name.lastIndexOf('.');
        if (dot <= 0) {
            return name + suffix;
        }
        return name.substring(0, dot) + suffix + name.substring(dot);
    }

    /** 경로가 섞여 와도 마지막 세그먼트만 취한다 */
    public static String basename(String pathOrName) {
        if (pathOrName == null) {
            return "";
        }
        String name = pathOrName.trim().replace('\\', '/');
        int slash = name.lastIndexOf('/');
        return slash >= 0 ? name.substring(slash + 1) : name;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-13
     * 코멘트:
     *   1) APP_FILE_ROOT 기준 상대 form_path를 조립한다
     *   2) 표준은 {표준루트}/{tmplCd}/{파일}, 자사는 {자사루트}/{coCd}/{tmplCd}/{파일}
     *   3) 회사명은 경로에 넣지 않는다 — 상호 변경 시 경로가 깨지므로 회사코드만 쓴다
     */
    public static String relativeFormPath(
            // 표준 양식 루트 디렉터리명 — app.template.standard-directory
            String standardDirectory,
            // 자사 양식 루트 디렉터리명 — app.template.custom-directory
            String customDirectory,
            // 회사코드 — null/공백일 때(= 전 회사 공통 표준 1벌) 표준 루트로 간다
            String coCd,
            // 양식코드 tmpl_cd — 타입 폴더 세그먼트. 공백이면 세그먼트를 생략한다
            String tmplCd,
            // 이미 safeTemplateFileName으로 정규화된 파일명
            String safeFileName
    ) {
        String type = segment(tmplCd);
        String file = basename(safeFileName);
        if (coCd == null || coCd.isBlank()) {
            return join(segment(standardDirectory), type, file);
        }
        return join(segment(customDirectory), segment(coCd), type, file);
    }

    /**
     * 경로 세그먼트 1개를 정규화한다 — 구분자·상위 이동 문자를 없애 루트 이탈을 막는다.
     * 공백일 때(= 선택 세그먼트 미지정) 빈 문자열을 돌려주고 join에서 빠진다.
     */
    public static String segment(
            // 디렉터리명·회사코드·양식코드 등 한 단계 이름
            String raw
    ) {
        if (raw == null) {
            return "";
        }
        String value = raw.trim().replace('\\', '/');
        int slash = value.lastIndexOf('/');
        if (slash >= 0) {
            value = value.substring(slash + 1);
        }
        return value.replace("..", "").trim();
    }

    /** 빈 세그먼트를 건너뛰고 / 로 잇는다 */
    private static String join(String... segments) {
        StringBuilder path = new StringBuilder();
        for (String segment : segments) {
            if (segment == null || segment.isBlank()) {
                continue;
            }
            if (path.length() > 0) {
                path.append('/');
            }
            path.append(segment);
        }
        return path.toString();
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) APP_FILE_ROOT를 절대경로로 고정한다. 상대값이면 실행 CWD가 아니라 haccp-api 모듈 디렉터리 기준이다
     *   2) DocumentFileStorage·TemplateFileStorage 기동 시 호출한다
     *   3) IntelliJ 작업 디렉터리가 저장소 루트여도 data/haccp-files 를 모듈 아래로 연다
     */
    public static Path absoluteRoot(
            // .env APP_FILE_ROOT — 상대 또는 절대
            String configured
    ) {
        Path path = Path.of(configured == null ? "" : configured.trim());
        if (path.isAbsolute()) {
            return path.normalize();
        }
        return moduleDir().resolve(path).normalize();
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) DB form_path가 운영 절대경로(/var/haccp/files/HaccpTemplates/...)여도 루트명부터만 남긴다
     *   2) TemplateFileStorage.parseDeclaredPath가 호출한다
     *   3) 이미 상대경로면 그대로 둔다
     */
    public static String toRelativeFormPath(
            // DB·설정에 들어온 경로 — 상대 또는 절대
            String formPath,
            // 표준 양식 루트 폴더명
            String standardDirectory,
            // 자사 양식 루트 폴더명
            String customDirectory
    ) {
        String normalized = formPath == null ? "" : formPath.trim().replace('\\', '/');
        while (normalized.startsWith("./")) {
            normalized = normalized.substring(2);
        }
        int std = indexOfDir(normalized, standardDirectory);
        int cst = indexOfDir(normalized, customDirectory);
        int cut = -1;
        if (std >= 0 && cst >= 0) {
            cut = Math.min(std, cst);
        } else {
            cut = Math.max(std, cst);
        }
        if (cut > 0) {
            normalized = normalized.substring(cut);
        }
        return normalized;
    }

    /** haccp-api 모듈 디렉터리 — target/classes 또는 jar 위치에서 한 단계 위 */
    private static Path moduleDir() {
        try {
            var source = TemplateFileNames.class.getProtectionDomain().getCodeSource();
            if (source == null) {
                return Path.of("").toAbsolutePath().normalize();
            }
            Path location = Path.of(source.getLocation().toURI());
            String asUnix = location.toString().replace('\\', '/');
            if (asUnix.endsWith("/target/classes") || asUnix.endsWith("/target/test-classes")) {
                Path module = location.getParent();
                return module == null ? location : module.getParent() == null ? module : module.getParent();
            }
            if (asUnix.endsWith(".jar") && location.getParent() != null) {
                return location.getParent();
            }
            return location;
        } catch (Exception ignored) {
            return Path.of("").toAbsolutePath().normalize();
        }
    }

    /** `/HaccpTemplates/` 또는 문자열 시작의 루트 폴더 위치. 없으면 -1 */
    private static int indexOfDir(String path, String directory) {
        String dir = segment(directory);
        if (dir.isBlank() || path.isBlank()) {
            return -1;
        }
        if (path.equals(dir) || path.startsWith(dir + "/")) {
            return 0;
        }
        String needle = "/" + dir + "/";
        int at = path.indexOf(needle);
        return at < 0 ? -1 : at + 1;
    }
}
