/**
 * TemplateFileNames — 템플릿 물리 파일명 정규화 유틸.
 *
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) docs 원본의 번호 접두만 제거하고 한글 본명은 그대로 둔다 (임의 작명 금지)
 *   2) 경로 조작 문자를 치환해 _template 하위 저장에만 쓰이게 한다
 *   3) 나중에 오브젝트스토리지로 옮겨도 동일 규칙으로 키를 만든다
 *
 * PIPELINE[HB89] 템플릿 파일명
 * PIPELINE[HB90, HB92] 연관 모듈
 */
package com.haccp.doc;

// 역할 — 정규식 접두 제거
import java.util.regex.Matcher;
import java.util.regex.Pattern;

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
     * 일자: 2026-08-10
     * 코멘트:
     *   1) APP_FILE_ROOT 기준 상대 form_path를 조립한다
     *   2) 표준은 _template/{파일}, 자사는 _template/{coCd}/{파일}
     *   3) 디렉터리명은 설정(app.template.directory)과 맞춘다
     */
    public static String relativeFormPath(
            // 템플릿 루트 디렉터리명 — 기본 _template
            String templateDirectory,
            // 회사코드 — null/공백이면 표준(공용) 경로
            String coCd,
            // 이미 정규화된 파일명
            String safeFileName
    ) {
        String dir = (templateDirectory == null || templateDirectory.isBlank())
                ? "_template"
                : templateDirectory.trim().replace('\\', '/');
        String file = basename(safeFileName);
        if (coCd == null || coCd.isBlank()) {
            return dir + "/" + file;
        }
        return dir + "/" + coCd.trim() + "/" + file;
    }
}
