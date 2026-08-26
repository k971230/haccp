/**
 * TemplateManifestLoader — classpath 매니페스트 TSV 로더.
 *
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) templates/manifest.tsv를 읽어 배포·경로 갱신 목록을 만든다
 *   2) 코드에 TMPL_CD 배열을 하드코딩하지 않기 위한 확장 포인트다
 *   3) 경로·인코딩 오류는 기동 시 IllegalStateException으로 드러낸다
 *
 * PIPELINE[HB92] 템플릿 매니페스트 로더
 * PIPELINE[HB89, HB90] 연관 모듈
 */
package com.haccp.docs.templates;

// 역할 — classpath 리소스 읽기
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
// 역할 — Spring 설정·컴포넌트
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Component;

/** 매니페스트 TSV를 한 번 로드해 불변 목록으로 제공한다 */
@Component
public class TemplateManifestLoader {

    // classpath 기준 매니페스트 경로 — app.template.manifest 로 교체 가능
    private final String manifestLocation;
    // 로드된 행 — 기동 후 변경하지 않는다
    private final List<TemplateManifestEntry> entries;

    public TemplateManifestLoader(
            // 기본 templates/manifest.tsv — 양식 추가 시 이 파일만 편집
            @Value("${app.template.manifest:templates/manifest.tsv}") String manifestLocation
    ) {
        this.manifestLocation = manifestLocation == null || manifestLocation.isBlank()
                ? "templates/manifest.tsv"
                : manifestLocation.trim();
        this.entries = Collections.unmodifiableList(load(this.manifestLocation));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) 전체 매니페스트 행을 반환한다
     *   2) ImportService·경로 갱신 SQL 생성이 호출한다
     *   3) 빈 목록이면 매니페스트 누락으로 기동 전에 이미 실패한다
     */
    public List<TemplateManifestEntry> entries() {
        return entries;
    }

    /** required=Y 행만 — 표준 필수 원본 */
    public List<TemplateManifestEntry> requiredEntries() {
        List<TemplateManifestEntry> out = new ArrayList<>();
        for (TemplateManifestEntry entry : entries) {
            if (entry.required()) {
                out.add(entry);
            }
        }
        return out;
    }

    private static List<TemplateManifestEntry> load(String location) {
        Resource resource = new ClassPathResource(location);
        if (!resource.exists()) {
            // classpath 밖 절대경로도 허용 — 운영에서 외부 매니페스트 마운트 확장
            resource = new org.springframework.core.io.FileSystemResource(location);
        }
        if (!resource.exists()) {
            throw new IllegalStateException("템플릿 매니페스트를 찾을 수 없습니다: " + location);
        }
        List<TemplateManifestEntry> rows = new ArrayList<>();
        try (InputStream in = resource.getInputStream();
             BufferedReader reader = new BufferedReader(new InputStreamReader(in, StandardCharsets.UTF_8))) {
            String line;
            while ((line = reader.readLine()) != null) {
                String trimmed = line.trim();
                // 주석·빈 줄 건너뜀
                if (trimmed.isEmpty() || trimmed.startsWith("#")) {
                    continue;
                }
                String[] parts = trimmed.split("\t", -1);
                if (parts.length < 4) {
                    throw new IllegalStateException("매니페스트 형식이 올바르지 않습니다: " + trimmed);
                }
                String tmplCd = parts[0].trim();
                String source = parts[1].trim();
                String target = parts[2].trim();
                boolean required = "Y".equalsIgnoreCase(parts[3].trim());
                if (tmplCd.isEmpty() || source.isEmpty() || target.isEmpty()) {
                    throw new IllegalStateException("매니페스트 필수 열이 비어 있습니다: " + trimmed);
                }
                rows.add(new TemplateManifestEntry(tmplCd, source, target, required));
            }
        } catch (IOException e) {
            throw new IllegalStateException("템플릿 매니페스트를 읽지 못했습니다: " + location, e);
        }
        if (rows.isEmpty()) {
            throw new IllegalStateException("템플릿 매니페스트에 유효한 행이 없습니다: " + location);
        }
        return rows;
    }
}
