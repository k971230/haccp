/**
 * HealthCertFileStorage — 보건증(인사) 전용 디스크 저장소.
 *
 * 개발자: 박승우
 * 일자: 2026-09-15
 * 코멘트:
 *   1) 일지 볼륨과 폴더를 가른다. HrDocs/{co_cd}/health-cert/{일자}/{uuid}.pdf
 *   2) PDF 원본 바이트를 파일별 DEK 로 AES-GCM 봉투만 씌운다. PDF 를 열어 다시 쓰지 않는다
 *   3) 먼저 .tmp 에 다 쓴 뒤 rename 한다. root 밖 경로는 거절한다
 *
 * PIPELINE[HB150] 보건증 파일 저장
 */
package com.haccp.flow.box.healthcert;

import com.haccp.common.exception.BizException;
import com.haccp.docs.templates.TemplateFileNames;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.FileAlreadyExistsException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.nio.file.StandardOpenOption;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.Arrays;
import java.util.HexFormat;
import java.util.Locale;
import java.util.UUID;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

/** 보건증 PDF 실물. DocumentFileStorage 를 쓰지 않는다 */
@Component
public class HealthCertFileStorage {

    private static final DateTimeFormatter FILE_DATE = DateTimeFormatter.ofPattern("yyyy-MM-dd");
    private static final int UUID_RETRY = 8;
    private static final byte[] ENVELOPE = {'H', 'C', '0', '1'};
    private static final int IV_LEN = 12;
    private static final int TAG_BITS = 128;
    private static final int KEY_MIN = 16;
    private static final int DEK_LEN = 32;

    private final Path root;
    private final String hrDirectory;
    private final long maxBytes;
    private final ZoneId zone;
    private final byte[] currentKey;
    private final int currentVersion;
    private final byte[] prevKey;

    public HealthCertFileStorage(
            @Value("${app.file.root}") String root,
            @Value("${app.hr.docs-directory:HrDocs}") String hrDirectory,
            @Value("${app.file.max-bytes}") long maxBytes,
            @Value("${app.timezone:Asia/Seoul}") String timezone,
            @Value("${app.hr.file-key:}") String fileKey,
            @Value("${app.hr.file-key-version:1}") int keyVersion,
            @Value("${app.hr.file-key-prev:}") String fileKeyPrev
    ) {
        this.root = TemplateFileNames.absoluteRoot(root);
        this.hrDirectory = TemplateFileNames.segment(hrDirectory);
        this.maxBytes = maxBytes;
        this.zone = ZoneId.of(timezone);
        this.currentKey = deriveKey(fileKey);
        this.currentVersion = keyVersion < 1 ? 1 : keyVersion;
        this.prevKey = deriveKey(fileKeyPrev);
    }

    public int currentVersion() {
        return currentVersion;
    }

    public boolean canRewrap() {
        return currentKey != null && prevKey != null;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-15
     * 코멘트:
     *   1) %PDF 만 받는다. 원본 해시를 유지하려고 파서를 쓰지 않는다
     *   2) 파일별 DEK 로 봉인하고 DEK 는 현재 마스터 키로 감싸 반환한다
     *   3) .tmp 에 다 쓴 뒤 uuid.pdf 로 옮긴다. 원본명은 DB file_nm 만
     */
    public SavedFile save(String coCd, MultipartFile file) {
        if (currentKey == null) {
            throw new BizException("보건증 파일 암호키가 없습니다. 관리자에게 문의하세요.");
        }
        if (file == null || file.isEmpty()) {
            throw new BizException("업로드할 파일을 선택하세요.");
        }
        if (file.getSize() > maxBytes) {
            throw new BizException("파일 크기가 허용 한도를 초과했습니다.");
        }
        byte[] plain;
        try {
            plain = file.getBytes();
        } catch (IOException e) {
            throw new BizException("파일을 읽지 못했습니다.");
        }
        assertMagic(plain, "pdf");
        // ponytail: 힙 상한 APP_FILE_MAX_BYTES. 문서함 다운로드와 같다. 한도를 올릴 때 청크 봉투
        byte[] dek = new byte[DEK_LEN];
        new SecureRandom().nextBytes(dek);
        byte[] sealed = seal(plain, dek);
        String wrappedDek = wrapDek(dek, currentKey);
        Arrays.fill(dek, (byte) 0);
        String dateFolder = FILE_DATE.format(LocalDate.now(zone));
        String folder = hrDirectory + "/" + TemplateFileNames.segment(coCd)
                + "/health-cert/" + dateFolder;
        for (int i = 0; i < UUID_RETRY; i++) {
            String relative = folder + "/" + UUID.randomUUID() + ".pdf";
            Path target = resolve(relative);
            Path tmp = resolve(relative + ".tmp");
            try {
                Files.createDirectories(target.getParent());
                Files.write(tmp, sealed, StandardOpenOption.CREATE_NEW);
                try {
                    Files.move(tmp, target, StandardCopyOption.ATOMIC_MOVE);
                } catch (AtomicMoveNotSupportedException e) {
                    Files.move(tmp, target, StandardCopyOption.REPLACE_EXISTING);
                }
                return new SavedFile(relative.replace('\\', '/'), wrappedDek, currentVersion);
            } catch (FileAlreadyExistsException e) {
                deleteQuietly(tmp);
            } catch (IOException e) {
                deleteQuietly(tmp);
                throw new BizException("파일을 저장하지 못했습니다.");
            }
        }
        throw new BizException("파일을 저장하지 못했습니다. 다시 시도하세요.");
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-15
     * 코멘트:
     *   1) wrappedDek 가 있으면 행의 key_version 키로 DEK 를 푼다
     *   2) 없으면 현재 키로 연다 — 키 도입 직후 봉인한 행
     *   3) GCM 태그는 open 이 끝난 뒤에만 평문이 나온다
     */
    public byte[] load(String relativePath, String wrappedDek, Integer keyVersion) {
        Path path = resolve(relativePath);
        if (!Files.isRegularFile(path)) {
            throw new BizException("파일을 찾을 수 없습니다.");
        }
        try {
            byte[] stored = Files.readAllBytes(path);
            if (!isEnvelope(stored)) {
                return stored;
            }
            byte[] master = masterFor(keyVersion);
            byte[] dek = wrappedDek == null || wrappedDek.isBlank()
                    ? master
                    : unwrapDek(wrappedDek, master);
            try {
                return open(stored, dek);
            } finally {
                if (dek != master) {
                    Arrays.fill(dek, (byte) 0);
                }
            }
        } catch (IOException e) {
            throw new BizException("파일을 읽을 수 없습니다.");
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-15
     * 코멘트:
     *   1) 이전 키로 감싼 DEK 를 현재 키로 다시 감싼다. 파일 바이트는 안 건드린다
     *   2) PREV 키가 없으면 거절
     *   3) 한 세대만. 두 세대 건너뛰면 못 연다
     */
    public String rewrapDek(String wrappedDek, int fromVersion) {
        byte[] oldMaster = masterFor(fromVersion);
        byte[] dek = unwrapDek(wrappedDek, oldMaster);
        try {
            return wrapDek(dek, currentKey);
        } finally {
            Arrays.fill(dek, (byte) 0);
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-15
     * 코멘트:
     *   1) DB 행을 지운 뒤 실물을 제거한다
     *   2) 이미 없어도 성공
     *   3) root 밖은 resolve 가 먼저 막는다
     */
    public void delete(String relativePath) {
        try {
            Files.deleteIfExists(resolve(relativePath));
        } catch (IOException e) {
            throw new BizException("저장 파일을 삭제하지 못했습니다.");
        }
    }

    static void assertMagic(byte[] body, String ext) {
        if (body == null || body.length < 4) {
            throw new BizException("PDF 파일만 업로드할 수 있습니다.");
        }
        String e = ext == null ? "" : ext.toLowerCase(Locale.ROOT);
        boolean ok = "pdf".equals(e)
                && body[0] == '%' && body[1] == 'P' && body[2] == 'D' && body[3] == 'F';
        if (!ok) {
            throw new BizException("PDF 파일만 업로드할 수 있습니다.");
        }
    }

    static String wrapDek(byte[] dek, byte[] master) {
        return HexFormat.of().formatHex(seal(dek, master));
    }

    static byte[] unwrapDek(String hex, byte[] master) {
        try {
            return open(HexFormat.of().parseHex(hex.trim()), master);
        } catch (IllegalArgumentException e) {
            throw new BizException("보건증 파일을 열 수 없습니다.");
        }
    }

    static byte[] seal(byte[] plain, byte[] key) {
        try {
            byte[] iv = new byte[IV_LEN];
            new SecureRandom().nextBytes(iv);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, new SecretKeySpec(key, "AES"),
                    new GCMParameterSpec(TAG_BITS, iv));
            byte[] ct = cipher.doFinal(plain);
            ByteBuffer buf = ByteBuffer.allocate(ENVELOPE.length + iv.length + ct.length);
            buf.put(ENVELOPE).put(iv).put(ct);
            return buf.array();
        } catch (GeneralSecurityException e) {
            throw new BizException("보건증 파일을 암호화하지 못했습니다.");
        }
    }

    static byte[] open(byte[] stored, byte[] key) {
        if (!isEnvelope(stored) || stored.length < ENVELOPE.length + IV_LEN + 16) {
            throw new BizException("보건증 파일이 손상되었습니다.");
        }
        byte[] iv = Arrays.copyOfRange(stored, ENVELOPE.length, ENVELOPE.length + IV_LEN);
        byte[] ct = Arrays.copyOfRange(stored, ENVELOPE.length + IV_LEN, stored.length);
        try {
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, new SecretKeySpec(key, "AES"),
                    new GCMParameterSpec(TAG_BITS, iv));
            return cipher.doFinal(ct);
        } catch (GeneralSecurityException e) {
            throw new BizException("보건증 파일을 열 수 없습니다.");
        }
    }

    static boolean isEnvelope(byte[] stored) {
        if (stored == null || stored.length < ENVELOPE.length) {
            return false;
        }
        return stored[0] == ENVELOPE[0] && stored[1] == ENVELOPE[1]
                && stored[2] == ENVELOPE[2] && stored[3] == ENVELOPE[3];
    }

    static byte[] deriveKey(String fileKey) {
        String key = fileKey == null ? "" : fileKey.trim();
        if (key.length() < KEY_MIN) {
            return null;
        }
        try {
            return MessageDigest.getInstance("SHA-256").digest(key.getBytes(StandardCharsets.UTF_8));
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException("SHA-256");
        }
    }

    private byte[] masterFor(Integer keyVersion) {
        if (currentKey == null) {
            throw new BizException("보건증 파일 암호키가 없습니다. 관리자에게 문의하세요.");
        }
        int ver = keyVersion == null || keyVersion < 1 ? 1 : keyVersion;
        if (ver == currentVersion) {
            return currentKey;
        }
        // ponytail: 한 세대 이전 키만. 두 세대 건너뛰면 못 연다
        if (prevKey != null && ver == currentVersion - 1) {
            return prevKey;
        }
        throw new BizException("보건증 파일 암호키 버전이 올바르지 않습니다.");
    }

    private void deleteQuietly(Path path) {
        try {
            Files.deleteIfExists(path);
        } catch (IOException ignored) {
            // 임시 파일 정리 실패는 운영이 .tmp 를 지운다
        }
    }

    private Path resolve(String relativePath) {
        if (relativePath == null || relativePath.isBlank()) {
            throw new BizException("파일 경로가 올바르지 않습니다.");
        }
        Path target = root.resolve(relativePath).normalize();
        if (!target.startsWith(root)) {
            throw new BizException("허용되지 않은 파일 경로입니다.");
        }
        return target;
    }

    /** 디스크 상대 경로, 감싼 DEK, 사용한 마스터 키 버전 */
    public record SavedFile(String relativePath, String wrappedDek, int keyVersion) {}
}
