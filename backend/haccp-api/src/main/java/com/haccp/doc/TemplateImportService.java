/**
 * TemplateImportService — 매니페스트 기반 표준 HWP 볼륨 초기화.
 *
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) APP_TEMPLATE_IMPORT_ROOT의 매니페스트 원본만 APP_FILE_ROOT 템플릿 공간으로 복사한다
 *   2) TMPL_CD 하드코딩 목록 대신 templates/manifest.tsv를 읽어 확장한다
 *   3) required=N 행(LAW 등)은 원본이 없으면 건너뛰고, required=Y 누락만 기동을 중단한다
 *
 * PIPELINE[HB92] 템플릿 배포 초기화
 * PIPELINE[HB89, HB90] 연관 모듈
 */
package com.haccp.doc;

// 역할 — Spring 시작 후 초기화 계약
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
// 역할 — 설정값 주입·컴포넌트 등록
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
// 역할 — 경로
import java.nio.file.Files;
import java.nio.file.Path;
// 역할 — 기동 로그
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/** 매니페스트 기반 템플릿 볼륨 초기화기 */
@Component
public class TemplateImportService implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(TemplateImportService.class);

    // 매니페스트 로더 — classpath/외부 TSV
    private final TemplateManifestLoader manifestLoader;
    // 볼륨 저장소 — 경로 경계·복사는 저장소에 위임 (S3 교체 대비)
    private final TemplateFileStorage storage;
    // 배포 시 읽기 전용으로 마운트하는 원본 디렉터리 — 공백이면 초기화 안 함
    private final String importRoot;
    // true일 때(= 새 표준양식 배포) 기존 대상도 교체
    private final boolean overwrite;

    public TemplateImportService(
            TemplateManifestLoader manifestLoader,
            TemplateFileStorage storage,
            // APP_TEMPLATE_IMPORT_ROOT — docs 또는 배포 마운트 경로
            @Value("${app.template.import-root:}") String importRoot,
            // APP_TEMPLATE_IMPORT_OVERWRITE
            @Value("${app.template.import-overwrite:false}") boolean overwrite
    ) {
        this.manifestLoader = manifestLoader;
        this.storage = storage;
        this.importRoot = importRoot == null ? "" : importRoot.trim();
        this.overwrite = overwrite;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) import-root가 있을 때만 매니페스트 행을 볼륨에 반영한다
     *   2) Spring Boot 기동 직후 1회 실행한다
     *   3) required 원본 누락·경로 오류는 IllegalStateException으로 기동을 중단한다
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
        int imported = 0;
        int skipped = 0;
        for (TemplateManifestEntry entry : manifestLoader.entries()) {
            Path source = sourceRoot.resolve(entry.sourceName()).normalize();
            if (!source.startsWith(sourceRoot)) {
                throw new IllegalStateException("템플릿 파일 경로가 올바르지 않습니다.");
            }
            if (!Files.isRegularFile(source)) {
                // 선택 행이면 스킵, 필수 행이면 기동 실패
                if (entry.required()) {
                    throw new IllegalStateException("필수 템플릿 원본 파일을 찾을 수 없습니다: " + entry.sourceName());
                }
                skipped++;
                continue;
            }
            String formPath = TemplateFileNames.relativeFormPath(
                    storage.templateDirectory(), null, entry.targetName()
            );
            boolean wrote = storage.copyFromPath(source, formPath, overwrite);
            if (wrote) {
                imported++;
            } else {
                skipped++;
            }
        }
        log.info("표준 HWP 템플릿 {}건을 초기화했습니다. (건너뜀 {})", imported, skipped);
    }
}
