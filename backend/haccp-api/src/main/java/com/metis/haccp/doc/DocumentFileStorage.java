/**
 * DocumentFileStorage — 문서 첨부 로컬 볼륨 저장소.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) MultipartFile을 테넌트·연월 단위 하위 경로에 저장하고 내부 상대 경로만 DB에 남긴다
 *   2) 파일명은 경로 조작 문자를 제거하고 UUID를 앞에 붙여 같은 이름의 덮어쓰기를 막는다
 *   3) 읽기·삭제는 상대 경로가 root 안에 있을 때만 허용해 다른 파일 접근을 차단한다
 *
 * PIPELINE[HB85] doc 파일 저장
 * PIPELINE[HB82, HB86] 연관 모듈
 */
package com.metis.haccp.doc;

// 역할 — 업무 예외
import com.metis.haccp.common.exception.BizException;
// 역할 — 난수 파일명
import java.util.UUID;
// 역할 — 로컬 파일 입출력
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
// 역할 — 연월 경로
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
// 역할 — Spring 설정값 주입
import org.springframework.beans.factory.annotation.Value;
// 역할 — 업로드 파일 타입
import org.springframework.web.multipart.MultipartFile;
// 역할 — 컴포넌트 등록
import org.springframework.stereotype.Component;

/** HWPX·PDF·사진·첨부의 물리 파일을 안전하게 다루는 저장소 */
@Component
public class DocumentFileStorage {

    // 상대 경로의 연월 폴더 형식 — DB 저장 경로와 동일
    private static final DateTimeFormatter YEAR_MONTH = DateTimeFormatter.ofPattern("yyyy/MM");

    // 파일 저장 루트 — .env APP_FILE_ROOT에서만 받는다
    private final Path root;
    // 업로드 1건 최대 크기 — application.yml/.env에서만 받는다
    private final long maxBytes;

    public DocumentFileStorage(
            // 파일 볼륨 루트 — 운영은 Docker named volume 경로
            @Value("${app.file.root}") String root,
            // 업로드 파일 최대 크기 byte — multipart 한계와 같은 값으로 맞춘다
            @Value("${app.file.max-bytes}") long maxBytes
    ) {
        this.root = Path.of(root).toAbsolutePath().normalize();
        this.maxBytes = maxBytes;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 업로드 파일을 {root}/{coCd}/{yyyy}/{mm}에 저장한다
     *   2) DocumentService가 DB 메타 행을 만들기 직전에 호출한다
     *   3) 성공 시 DB에 저장할 상대 경로를 반환하고, 실패 시 BizException
     */
    public String save(
            // JWT 회사코드 — 첫 경로 세그먼트로 테넌트 파일을 물리 분리
            String coCd,
            // 브라우저가 올린 파일 — 요청 종료 뒤 임시 저장이 사라지므로 이 메서드에서 복사
            MultipartFile file
    ) {
        validate(file);
        String original = safeName(file.getOriginalFilename());
        String relative = coCd + "/" + YEAR_MONTH.format(LocalDate.now()) + "/"
                + UUID.randomUUID() + "_" + original;
        Path target = resolve(relative);

        try {
            Files.createDirectories(target.getParent());
            try (InputStream input = file.getInputStream()) {
                Files.copy(input, target, StandardCopyOption.REPLACE_EXISTING);
            }
            return relative.replace('\\', '/');
        } catch (IOException e) {
            throw new BizException("파일을 저장하지 못했습니다.");
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 로컬에 이미 생성된 파일(예: rhwp PDF)을 테넌트 볼륨으로 복사한다
     *   2) DocumentService.exportPdf가 CLI 산출물을 DB 등록 직전에 호출한다
     *   3) 성공 시 DB에 저장할 상대 경로, 실패 시 BizException
     */
    public String saveFromPath(
            // JWT 회사코드 — 테넌트 물리 분리 세그먼트
            String coCd,
            // CLI가 만든 임시 PDF 등 — 호출 후 삭제해도 되는 원본
            Path source,
            // 다운로드·목록에 보일 원본 파일명
            String originalName
    ) {
        if (source == null || !Files.isRegularFile(source)) {
            throw new BizException("저장할 파일을 찾을 수 없습니다.");
        }
        try {
            long size = Files.size(source);
            // maxBytes보다 클 때(= 운영 한도 초과) 복사 전 차단
            if (size > maxBytes) {
                throw new BizException("파일 크기가 허용 한도를 초과했습니다.");
            }
            String original = safeName(originalName);
            String relative = coCd + "/" + YEAR_MONTH.format(LocalDate.now()) + "/"
                    + UUID.randomUUID() + "_" + original;
            Path target = resolve(relative);
            Files.createDirectories(target.getParent());
            Files.copy(source, target, StandardCopyOption.REPLACE_EXISTING);
            return relative.replace('\\', '/');
        } catch (BizException e) {
            throw e;
        } catch (IOException e) {
            throw new BizException("파일을 저장하지 못했습니다.");
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 상대 경로를 root 안의 실제 Path로 해석한다
     *   2) 다운로드·DB 메타 삭제 뒤 물리 파일 삭제에서 호출한다
     *   3) 경로가 root 밖이거나 파일이 없으면 BizException
     */
    public Path read(
            // DB에 저장된 상대 경로
            String relativePath
    ) {
        Path path = resolve(relativePath);
        if (!Files.isRegularFile(path)) {
            throw new BizException("파일을 찾을 수 없습니다.");
        }
        return path;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) DB 메타가 삭제된 뒤 해당 물리 파일을 제거한다
     *   2) 이미 없을 때(= 재시도·운영자가 정리)도 성공으로 처리한다
     *   3) root 밖 경로는 resolve가 먼저 차단한다
     */
    public void delete(
            // DB에 저장된 상대 경로
            String relativePath
    ) {
        try {
            Files.deleteIfExists(resolve(relativePath));
        } catch (IOException e) {
            throw new BizException("저장 파일을 삭제하지 못했습니다.");
        }
    }

    /** 업로드 필수·크기 검증 */
    private void validate(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BizException("업로드할 파일을 선택하세요.");
        }
        // maxBytes보다 클 때(= 운영 한도 초과) 디스크 쓰기 전 차단
        if (file.getSize() > maxBytes) {
            throw new BizException("파일 크기가 허용 한도를 초과했습니다.");
        }
    }

    /** 경로 조작 문자·빈 파일명을 제거한다 */
    private String safeName(String original) {
        String name = original == null ? "" : Path.of(original).getFileName().toString();
        name = name.replaceAll("[^0-9A-Za-z가-힣._() -]", "_").trim();
        if (name.isBlank()) {
            throw new BizException("파일명이 올바르지 않습니다.");
        }
        return name;
    }

    /** root 밖 접근을 막는 공통 경로 해석 */
    private Path resolve(String relativePath) {
        if (relativePath == null || relativePath.isBlank()) {
            throw new BizException("파일 경로가 올바르지 않습니다.");
        }
        Path target = root.resolve(relativePath).normalize();
        // target이 root 밖일 때(= ../ 경로 조작) 즉시 차단
        if (!target.startsWith(root)) {
            throw new BizException("허용되지 않은 파일 경로입니다.");
        }
        return target;
    }
}
