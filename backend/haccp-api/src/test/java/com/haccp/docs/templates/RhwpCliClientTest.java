/**
 * RhwpCliClientTest — CLI 경로 후보 해결.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) env 가 비면 저장소 tools/rhwp 를 cwd 상위로 찾는다
 *   2) env 가 실제 파일이면 그걸 우선한다 — Docker /opt 과 로컬 exe 가 섞이지 않게
 *   3) 후보가 없으면 공백을 그대로 돌려 호출 시점에 「설정되지 않았습니다」가 나게 한다
 *
 * PIPELINE[HB93] rhwp CLI PDF 변환
 */
package com.haccp.docs.templates;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class RhwpCliClientTest {

    @Test
    void env가_비면_tools_rhwp_exe를_찾는다(@TempDir Path root) throws IOException {
        Path exe = root.resolve("tools/rhwp/rhwp.exe");
        Files.createDirectories(exe.getParent());
        Files.createFile(exe);
        Path cwd = Files.createDirectories(root.resolve("backend/haccp-api"));
        String resolved = RhwpCliClient.resolveCliPath("  ", cwd);
        assertEquals(exe.toAbsolutePath().normalize().toString(), resolved);
    }

    @Test
    void env가_실제_파일이면_그걸_쓴다(@TempDir Path root) throws IOException {
        Path preferred = root.resolve("custom/rhwp.exe");
        Files.createDirectories(preferred.getParent());
        Files.createFile(preferred);
        Path decoy = root.resolve("tools/rhwp/rhwp.exe");
        Files.createDirectories(decoy.getParent());
        Files.createFile(decoy);
        String resolved = RhwpCliClient.resolveCliPath(preferred.toString(), root);
        assertEquals(preferred.toAbsolutePath().normalize().toString(), resolved);
    }

    @Test
    void 후보가_없으면_공백이다(@TempDir Path cwd) {
        String resolved = RhwpCliClient.resolveCliPath("", cwd);
        assertTrue(resolved.isBlank());
    }
}
