/**
 * HealthCertFileStorageTest — 보건증 파일 암호·매직 검사.
 *
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) 디스크에는 평문 PDF 가 없어야 한다
 *   2) 파일별 DEK 를 감싸 개봉하면 원문 해시가 같다
 *   3) 키 세대·tmp 잔존·경로 탈출을 본다
 *
 * PIPELINE[HB150] 보건증 파일 저장
 */
package com.haccp.flow.box.healthcert;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.haccp.common.exception.BizException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.SecureRandom;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;

class HealthCertFileStorageTest {

    private static final byte[] PDF = "%PDF-1.4 signed-bytes".getBytes(StandardCharsets.US_ASCII);
    private static final String KEY_V1 = "changeme-hr-file-key-16";
    private static final String KEY_V2 = "rotated-hr-file-key-16";

    /**
     * 개발자: 박승우
     * 일자: 2026-09-15
     * 코멘트:
     *   1) 같은 키로 봉인·개봉하면 원문이 나온다
     *   2) 디스크에 쓸 값이 봉투인지 본다
     *   3) 키가 바뀌면 개봉이 실패해야 한다
     */
    @Test
    void 암호문과_평문이_왕복한다() {
        byte[] key = HealthCertFileStorage.deriveKey(KEY_V1);
        byte[] sealed = HealthCertFileStorage.seal(PDF, key);
        assertTrue(HealthCertFileStorage.isEnvelope(sealed));
        assertArrayEquals(PDF, HealthCertFileStorage.open(sealed, key));
        assertThrows(BizException.class, () -> HealthCertFileStorage.open(sealed,
                HealthCertFileStorage.deriveKey(KEY_V2)));
    }

    @Test
    void 파일별_DEK를_감싸_원문이_왕복하고_tmp가_안_남는다(
            @org.junit.jupiter.api.io.TempDir Path root
    ) throws Exception {
        HealthCertFileStorage storage = storage(root, KEY_V1, 1, "");
        MockMultipartFile file = new MockMultipartFile(
                "file", "주민번호.pdf", "application/pdf", PDF);
        HealthCertFileStorage.SavedFile saved = storage.save("0000", file);
        Path onDisk = root.resolve(saved.relativePath());
        byte[] stored = Files.readAllBytes(onDisk);
        assertTrue(HealthCertFileStorage.isEnvelope(stored));
        assertFalse(new String(stored, StandardCharsets.US_ASCII).contains("%PDF"));
        assertTrue(saved.relativePath().endsWith(".pdf"));
        assertFalse(saved.relativePath().endsWith(".tmp"));
        assertFalse(saved.relativePath().contains("주민번호"));
        assertEquals(1, saved.keyVersion());
        assertArrayEquals(PDF, storage.load(saved.relativePath(), saved.wrappedDek(), 1));
        try (Stream<Path> walk = Files.walk(root)) {
            assertTrue(walk.noneMatch(p -> p.getFileName().toString().endsWith(".tmp")));
        }
        byte[] otherDek = new byte[32];
        new SecureRandom().nextBytes(otherDek);
        byte[] master = HealthCertFileStorage.deriveKey(KEY_V1);
        String wrong = HealthCertFileStorage.wrapDek(otherDek, master);
        assertThrows(BizException.class,
                () -> storage.load(saved.relativePath(), wrong, 1));
    }

    @Test
    void 이전_키세대로_개봉하고_현재_키로_다시_감싼다(
            @org.junit.jupiter.api.io.TempDir Path root
    ) throws Exception {
        HealthCertFileStorage v1 = storage(root, KEY_V1, 1, "");
        MockMultipartFile file = new MockMultipartFile("file", "a.pdf", "application/pdf", PDF);
        HealthCertFileStorage.SavedFile saved = v1.save("0000", file);
        HealthCertFileStorage v2 = storage(root, KEY_V2, 2, KEY_V1);
        assertArrayEquals(PDF, v2.load(saved.relativePath(), saved.wrappedDek(), 1));
        String next = v2.rewrapDek(saved.wrappedDek(), 1);
        assertArrayEquals(PDF, v2.load(saved.relativePath(), next, 2));
        assertThrows(BizException.class,
                () -> v2.load(saved.relativePath(), saved.wrappedDek(), 99));
    }

    @Test
    void PDF가_아니면_거절한다() {
        byte[] html = "<html>".getBytes(StandardCharsets.US_ASCII);
        assertThrows(BizException.class, () -> HealthCertFileStorage.assertMagic(html, "pdf"));
        byte[] jpeg = new byte[]{(byte) 0xff, (byte) 0xd8, 0, 0};
        assertThrows(BizException.class, () -> HealthCertFileStorage.assertMagic(jpeg, "jpg"));
    }

    @Test
    void 짧은_키는_없다() {
        assertNull(HealthCertFileStorage.deriveKey("short"));
    }

    @Test
    void 생성자_경로만_잡는다(@org.junit.jupiter.api.io.TempDir Path root) {
        HealthCertFileStorage storage = storage(root, KEY_V1, 1, "");
        assertThrows(BizException.class, () -> storage.load("../escape.pdf", null, 1));
    }

    private static HealthCertFileStorage storage(Path root, String key, int version, String prev) {
        return new HealthCertFileStorage(
                root.toString(), "HrDocs", 1024, "Asia/Seoul", key, version, prev);
    }
}
