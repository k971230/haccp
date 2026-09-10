/**
 * TemplateFileStorageDeleteTest — 자사 양식 실물만 지운다.
 *
 * 개발자: 박승우
 * 일자: 2026-09-10
 * 코멘트:
 *   1) CustomTemplates 아래만 지운다. HaccpTemplates 표준 공유는 남긴다
 *   2) 한 업체 삭제가 전 업체 원본을 지우면 안 된다
 *   3) Spring 없이 임시 디렉터리로 저장소만 세운다
 *
 * PIPELINE[HB89] 템플릿 파일 저장
 */
package com.haccp.docs.templates;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class TemplateFileStorageDeleteTest {

    @TempDir
    Path root;

    private TemplateFileStorage storage() {
        return new TemplateFileStorage(root.toString(), "HaccpTemplates", "CustomTemplates", 1024);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-10
     * 코멘트:
     *   1) 자사 경로는 지우고 표준 공유는 그대로 둔다
     *   2) 이 분기가 없으면 사용양식 삭제가 전 업체 원본을 지운다
     *   3) 파일이 실제로 사라졌는지로만 본다
     */
    @Test
    void 자사_경로만_지우고_표준은_남긴다() throws Exception {
        Path customFile = root.resolve("CustomTemplates/0003/hwp_usr_001/a.hwpx");
        Path standardFile = root.resolve("HaccpTemplates/hwp_sys_001/b.hwpx");
        Files.createDirectories(customFile.getParent());
        Files.createDirectories(standardFile.getParent());
        Files.write(customFile, new byte[] { 1 });
        Files.write(standardFile, new byte[] { 1 });

        TemplateFileStorage storage = storage();
        storage.delete("CustomTemplates/0003/hwp_usr_001/a.hwpx");
        storage.delete("HaccpTemplates/hwp_sys_001/b.hwpx");

        assertFalse(Files.exists(customFile));
        assertTrue(Files.exists(standardFile));
    }
}
