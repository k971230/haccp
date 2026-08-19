/**
 * TemplateImportService — 이미지 시드 HWP를 파일 볼륨으로 복사한다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-19
 * 코멘트:
 *   1) import-root/sys + 매니페스트 → HaccpTemplates/{tmpl_cd}
 *   2) import-root/usr/{회사코드}/{양식코드}/* → CustomTemplates (대상 없을 때만)
 *   3) 원본이 없으면 건너뛴다 — 기동을 막지 않는다
 *
 * PIPELINE[HB92] 템플릿 배포 초기화
 * PIPELINE[HB89, HB90] 연관 모듈
 */
package com.haccp.doc;

// 역할 — 사용자 노출 업무 오류
import com.haccp.common.exception.BizException;
// 역할 — Spring 시작 후 초기화 계약
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
// 역할 — 설정값 주입·컴포넌트 등록
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
// 역할 — 경로
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;
import java.util.stream.Stream;
// 역할 — 기동 로그
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/** 매니페스트·사용자 시드 기반 템플릿 볼륨 초기화기 */
@Component
public class TemplateImportService implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(TemplateImportService.class);

    // 매니페스트 로더 — classpath/외부 TSV
    private final TemplateManifestLoader manifestLoader;
    // 볼륨 저장소 — 경로 경계·복사는 저장소에 위임 (S3 교체 대비)
    private final TemplateFileStorage storage;
    // 이미지 시드 루트 — /opt/haccp/template-src. 공백이면 초기화 안 함
    private final String importRoot;
    // true일 때(= 새 표준양식 배포) 기존 시스템 파일도 교체. 사용자시드는 항상 없을 때만 복사
    private final boolean overwrite;

    public TemplateImportService(
            TemplateManifestLoader manifestLoader,
            TemplateFileStorage storage,
            // APP_TEMPLATE_IMPORT_ROOT — 이미지 시드 또는 마운트 경로
            @Value("${app.template.import-root:}") String importRoot,
            // APP_TEMPLATE_IMPORT_OVERWRITE — 시스템 시드에만 적용
            @Value("${app.template.import-overwrite:false}") boolean overwrite
    ) {
        this.manifestLoader = manifestLoader;
        this.storage = storage;
        this.importRoot = importRoot == null ? "" : importRoot.trim();
        this.overwrite = overwrite;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) import-root가 있을 때만 sys·usr 시드를 볼륨에 반영한다
     *   2) Spring Boot 기동 직후 1회 실행한다
     *   3) 원본 누락은 건너뛰고 기동한다
     */
    @Override
    public void run(ApplicationArguments args) {
        if (importRoot.isBlank()) {
            log.info("템플릿 원본 초기화를 건너뜁니다: APP_TEMPLATE_IMPORT_ROOT가 설정되지 않았습니다.");
            return;
        }
        Path sourceRoot = Path.of(importRoot).toAbsolutePath().normalize();
        if (!Files.isDirectory(sourceRoot)) {
            throw new IllegalStateException("템플릿 원본 디렉터리를 찾을 수 없습니다.");
        }
        importSystem(sourceRoot.resolve("sys"));
        importUser(sourceRoot.resolve("usr"));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) 매니페스트 source_name 을 sys 폴더에서 찾아 표준 루트에 복사한다
     *   2) 기동 시 1회 호출한다
     *   3) sys 폴더가 없으면 건너뛴다
     */
    private void importSystem(
            // 이미지 안 docs/templates/new 복사본
            Path sysRoot
    ) {
        int imported = 0;
        int skipped = 0;
        if (!Files.isDirectory(sysRoot)) {
            log.warn("시스템 양식 시드 폴더가 없어 건너뜁니다: {}", sysRoot);
            return;
        }
        for (TemplateManifestEntry entry : manifestLoader.entries()) {
            Path source = sysRoot.resolve(entry.sourceName()).normalize();
            if (!source.startsWith(sysRoot)) {
                throw new IllegalStateException("템플릿 파일 경로가 올바르지 않습니다.");
            }
            if (!Files.isRegularFile(source)) {
                if (entry.required()) {
                    log.warn("필수 템플릿 원본이 없어 건너뜁니다: {}", entry.sourceName());
                }
                skipped++;
                continue;
            }
            String formPath = storage.formPath(null, entry.tmplCd(), entry.targetName());
            boolean wrote = storage.copyFromPath(source, formPath, overwrite);
            if (wrote) {
                imported++;
            } else {
                skipped++;
            }
        }
        log.info("표준 HWP 템플릿 {}건을 초기화했습니다. (건너뜀 {})", imported, skipped);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-19
     * 코멘트:
     *   1) usr/{회사코드}/{양식코드}/{파일} 을 CustomTemplates 로 복사한다
     *   2) 기동 시 1회 호출한다
     *   3) 대상이 이미 있으면 건너뛴다 — 서버에서 올린 버전을 덮지 않는다
     */
    private void importUser(
            // 이미지 안 docs/templates/usr 복사본
            Path usrRoot
    ) {
        if (!Files.isDirectory(usrRoot)) {
            log.info("사용자 양식 시드 폴더가 없어 건너뜁니다.");
            return;
        }
        int imported = 0;
        int skipped = 0;
        try (Stream<Path> walk = Files.walk(usrRoot)) {
            for (Path file : walk.filter(Files::isRegularFile).toList()) {
                Path relative = usrRoot.relativize(file).normalize();
                if (relative.getNameCount() != 3 || relative.startsWith("..")) {
                    skipped++;
                    continue;
                }
                String fileNm = relative.getFileName().toString();
                String lower = fileNm.toLowerCase(Locale.ROOT);
                if ("readme.md".equals(lower)
                        || !(lower.endsWith(".hwp") || lower.endsWith(".hwpx"))) {
                    skipped++;
                    continue;
                }
                String coCd = relative.getName(0).toString();
                String tmplCd = relative.getName(1).toString();
                String formPath = storage.formPath(coCd, tmplCd, fileNm);
                try {
                    boolean wrote = storage.copyFromPath(file, formPath, false);
                    if (wrote) {
                        imported++;
                    } else {
                        skipped++;
                    }
                } catch (BizException e) {
                    log.warn("사용자 양식 시드를 건너뜁니다: {} ({})", relative, e.getMessage());
                    skipped++;
                }
            }
        } catch (IOException e) {
            throw new IllegalStateException("사용자 양식 시드를 읽지 못했습니다.");
        }
        log.info("사용자 HWP 템플릿 {}건을 초기화했습니다. (건너뜀 {})", imported, skipped);
    }
}
