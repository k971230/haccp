/**
 * DocumentFileStorage — 문서 첨부 로컬 볼륨 저장소.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) MultipartFile을 HaccpLogBooks/{회사코드}/{양식코드}/{일자} 하위에 저장하고 상대 경로만 DB에 남긴다
 *   2) 파일명은 {일자}_{원본명}_{연번}.{확장자} — 연번은 같은 이름이 있으면 올라간다
 *   3) 읽기·삭제는 상대 경로가 root 안에 있을 때만 허용해 다른 파일 접근을 차단한다
 *
 * PIPELINE[HB85] doc 파일 저장
 * PIPELINE[HB82, HB86] 연관 모듈
 */
package com.haccp.docs.document;

// 역할 — 업무 예외
import com.haccp.common.exception.BizException;
// 역할 — 경로 세그먼트 정규화
import com.haccp.docs.template.TemplateFileNames;
// 역할 — 로컬 파일 입출력
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.FileAlreadyExistsException;
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

    // 상대 경로의 일자 폴더·파일명 접두 형식 — 하루 단위로 묶어 운영자가 눈으로 찾는다
    private static final DateTimeFormatter FILE_DATE = DateTimeFormatter.ofPattern("yyyy-MM-dd");

    // 같은 날 같은 이름의 최대 연번 — 넘으면 파일명을 바꾸라고 알린다
    private static final int SEQ_MAX = 999;

    // 파일 저장 루트 — .env APP_FILE_ROOT에서만 받는다
    private final Path root;
    // 작성 문서·첨부 루트 폴더명 — app.document.logbook-directory
    private final String logbookDirectory;
    // 업로드 1건 최대 크기 — application.yml/.env에서만 받는다
    private final long maxBytes;

    public DocumentFileStorage(
            // 파일 볼륨 루트 — 운영은 Docker named volume 경로
            @Value("${app.file.root}") String root,
            // 작성 문서 루트 폴더명 — 표준·자사 양식 루트와 분리한다
            @Value("${app.document.logbook-directory}") String logbookDirectory,
            // 업로드 파일 최대 크기 byte — multipart 한계와 같은 값으로 맞춘다
            @Value("${app.file.max-bytes}") long maxBytes
    ) {
        this.root = TemplateFileNames.absoluteRoot(root);
        this.logbookDirectory = TemplateFileNames.segment(logbookDirectory);
        this.maxBytes = maxBytes;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-13
     * 코멘트:
     *   1) {logbookDirectory}/{coCd}/{yyyy-MM-dd}/{tmplCd}/{uuid}_{원본명} 상대 경로를 만든다
     *   2) 문서 첨부·PDF 저장 직전에 쓴다 — DB에는 이 상대 경로만 남는다
     *   3) tmplCd가 공백일 때(= 양식과 무관한 첨부, 설비 사진 등) 타입 폴더를 생략한다
     */
    private String logbookFolder(
            // JWT 회사코드 — 테넌트 물리 분리 세그먼트. 절대 빼지 않는다
            String coCd,
            // 문서 양식코드 tmpl_cd — 양식 폴더. 양식과 무관한 첨부는 공백
            String tmplCd,
            // 저장일 YYYY-MM-DD
            String dateFolder
    ) {
        String type = TemplateFileNames.segment(tmplCd);
        return logbookDirectory
                + "/" + TemplateFileNames.segment(coCd)
                + (type.isBlank() ? "" : "/" + type)
                + "/" + dateFolder;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) {YYYY-MM-DD}_{원본명}_{연번}.{확장자} 로 이름을 짓고 비어 있는 연번에 실제로 쓴다
     *   2) save·saveFromPath 가 공통으로 호출한다 — 파일명 규칙이 두 곳으로 갈라지지 않게 한다
     *   3) 같은 이름이 이미 있으면 연번을 올려 다시 쓴다. 미리 존재를 확인하지 않고 생성 실패로
     *      판정하므로 두 사람이 같은 순간 저장해도 한쪽이 덮이지 않는다
     */
    private String storeWithSeq(
            // JWT 회사코드
            String coCd,
            // 문서 양식코드
            String tmplCd,
            // 경로 조작 문자를 제거한 원본 파일명
            String safeOriginalName,
            // 목적지에 실제로 쓰는 동작 — 이미 있으면 FileAlreadyExistsException 이 나야 한다
            TargetWriter writer
    ) {
        String dateFolder = FILE_DATE.format(LocalDate.now());
        String folder = logbookFolder(coCd, tmplCd, dateFolder);
        int dot = safeOriginalName.lastIndexOf('.');
        // 확장자는 원본을 따른다 — hwp·hwpx·pdf·jpg 가 한 저장소를 함께 쓴다
        String stem = dot > 0 ? safeOriginalName.substring(0, dot) : safeOriginalName;
        String ext = dot > 0 ? safeOriginalName.substring(dot) : "";
        for (int seq = 1; seq <= SEQ_MAX; seq++) {
            String relative = folder + "/" + dateFolder + "_" + stem
                    + "_" + String.format("%03d", seq) + ext;
            Path target = resolve(relative);
            try {
                Files.createDirectories(target.getParent());
                writer.writeTo(target);
                return relative.replace('\\', '/');
            } catch (FileAlreadyExistsException e) {
                // 그 연번이 이미 있을 때(= 같은 날 재저장·동시 저장) 다음 번호로 넘어간다
            } catch (IOException e) {
                throw new BizException("파일을 저장하지 못했습니다.");
            }
        }
        throw new BizException("같은 이름의 파일이 너무 많습니다. 파일명을 바꿔 저장하세요.");
    }

    /** 목적지에 쓰는 동작 — 이미 있으면 FileAlreadyExistsException 을 던지는 복사만 넘긴다 */
    @FunctionalInterface
    private interface TargetWriter {
        void writeTo(Path target) throws IOException;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 업로드 파일을 {logbookDirectory}/{coCd}/{일자}/{tmplCd} 아래에 저장한다
     *   2) DocumentService가 DB 메타 행을 만들기 직전에 호출한다
     *   3) 성공 시 DB에 저장할 상대 경로를 반환하고, 실패 시 BizException
     */
    public String save(
            // JWT 회사코드 — 테넌트 파일을 물리 분리하는 세그먼트
            String coCd,
            // 문서 양식코드 tmpl_cd — 타입 폴더. 양식과 무관한 첨부는 공백
            String tmplCd,
            // 브라우저가 올린 파일 — 요청 종료 뒤 임시 저장이 사라지므로 이 메서드에서 복사
            MultipartFile file
    ) {
        validate(file);
        String original = safeName(file.getOriginalFilename());
        // REPLACE_EXISTING 을 주지 않아야 이미 있는 이름에서 예외가 나고 연번이 올라간다
        return storeWithSeq(coCd, tmplCd, original, (target) -> {
            try (InputStream input = file.getInputStream()) {
                Files.copy(input, target);
            }
        });
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
            // 문서 양식코드 tmpl_cd — 타입 폴더. 양식과 무관한 산출물은 공백
            String tmplCd,
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
            // REPLACE_EXISTING 을 주지 않아야 이미 있는 이름에서 예외가 나고 연번이 올라간다
            return storeWithSeq(coCd, tmplCd, original, (target) -> Files.copy(source, target));
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
