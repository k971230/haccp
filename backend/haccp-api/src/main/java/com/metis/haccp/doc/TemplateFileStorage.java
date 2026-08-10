/**
 * TemplateFileStorage — 표준·자사 HWP 템플릿 볼륨 저장소.
 *
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) APP_FILE_ROOT/{templateDirectory} 아래만 읽고 쓰며 문서 첨부 트리와 경계를 둔다
 *   2) 덮어쓰기·신규 생성·자사 하위폴더를 지원한다 — 나중에 S3로 교체해도 동일 메서드 계약을 유지한다
 *   3) 디렉터리명은 app.template.directory 로만 바꾸며 코드에 _template 문자열을 흩뿌리지 않는다
 *
 * PIPELINE[HB89] 템플릿 파일 저장
 * PIPELINE[HB88, HB90] 연관 모듈
 */
package com.metis.haccp.doc;

// 역할 — 사용자 노출 업무 오류
import com.metis.haccp.common.exception.BizException;
// 역할 — 업로드 스트림
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
// 역할 — 애플리케이션 파일 루트·크기 한도 설정
import org.springframework.beans.factory.annotation.Value;
// 역할 — Spring 컴포넌트 등록
import org.springframework.stereotype.Component;
// 역할 — 브라우저 업로드 파일
import org.springframework.web.multipart.MultipartFile;

/**
 * 볼륨 기반 템플릿 저장소.
 * 확장: 동일 public 메서드를 구현하는 S3/MinIO 어댑터로 교체하면 된다.
 */
@Component
public class TemplateFileStorage {

    // APP_FILE_ROOT 정규화 경로
    private final Path appFileRoot;
    // 템플릿 전용 하위 폴더명 — 기본 _template (설정으로만 변경)
    private final String templateDirectory;
    // APP_FILE_ROOT/{templateDirectory}
    private final Path templateRoot;
    // 업로드 허용 바이트 상한 — app.file.max-bytes
    private final long maxBytes;

    public TemplateFileStorage(
            // 문서·첨부·템플릿이 함께 쓰는 운영 볼륨 루트
            @Value("${app.file.root}") String appFileRoot,
            // 템플릿 공간 디렉터리명 — 기본 _template
            @Value("${app.template.directory:_template}") String templateDirectory,
            // 운영 파일 크기 한도
            @Value("${app.file.max-bytes}") long maxBytes
    ) {
        this.appFileRoot = Path.of(appFileRoot).toAbsolutePath().normalize();
        this.templateDirectory = (templateDirectory == null || templateDirectory.isBlank())
                ? "_template"
                : templateDirectory.trim().replace('\\', '/');
        this.templateRoot = this.appFileRoot.resolve(this.templateDirectory).normalize();
        this.maxBytes = maxBytes;
    }

    /** 설정상 템플릿 디렉터리명 — form_path 조립에 재사용 */
    public String templateDirectory() {
        return templateDirectory;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) DB form_path를 템플릿 루트 내부의 존재하는 일반 파일로 해석한다
     *   2) TemplateService가 인증된 원본을 스트림하기 직전에 호출한다
     *   3) 절대경로·상위 이동·심볼릭 링크 이탈·누락은 업무 오류로 차단한다
     */
    public Path read(
            // DB가 반환한 내부 상대 경로 — 반드시 {templateDirectory}/ 로 시작
            String formPath
    ) {
        Path target = resolveInsideTemplate(formPath, false);
        if (!Files.isRegularFile(target)) {
            throw new BizException("템플릿 원본 파일을 찾을 수 없습니다.");
        }
        try {
            Path realTemplateRoot = templateRoot.toRealPath();
            Path realTarget = target.toRealPath();
            if (!realTarget.startsWith(realTemplateRoot)) {
                throw new BizException("허용되지 않은 템플릿 경로입니다.");
            }
            return realTarget;
        } catch (IOException e) {
            throw new BizException("템플릿 원본 파일을 읽지 못했습니다.");
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 기존 form_path 위치에 HWP/HWPX 바이트를 덮어쓴다
     *   2) 표준 양식 수정 저장 시 호출한다
     *   3) 확장자·크기·루트 이탈이 있으면 쓰기 전에 차단한다
     */
    public Path write(
            // DB form_path — 이미 존재하는 파일만
            String formPath,
            // 브라우저가 올린 수정본
            MultipartFile file
    ) {
        validateUpload(file);
        Path target = read(formPath);
        try (InputStream input = file.getInputStream()) {
            Files.copy(input, target, StandardCopyOption.REPLACE_EXISTING);
            return target;
        } catch (IOException e) {
            throw new BizException("템플릿 원본 파일을 저장하지 못했습니다.");
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) 아직 없는 form_path에 신규 파일을 만든다 (자사 업로드·배포 초기화)
     *   2) 상위 디렉터리(_template/{coCd})를 필요 시 생성한다
     *   3) 성공 시 실제 Path — DB에는 상대 formPath를 그대로 저장한다
     */
    public Path create(
            // 저장할 상대 경로 — {templateDirectory}/... 또는 {templateDirectory}/{coCd}/...
            String formPath,
            // 업로드 바이트
            MultipartFile file
    ) {
        validateUpload(file);
        Path target = resolveInsideTemplate(formPath, true);
        try {
            Files.createDirectories(target.getParent());
            try (InputStream input = file.getInputStream()) {
                Files.copy(input, target, StandardCopyOption.REPLACE_EXISTING);
            }
            return target;
        } catch (IOException e) {
            throw new BizException("템플릿 원본 파일을 저장하지 못했습니다.");
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-10
     * 코멘트:
     *   1) 로컬 Path 원본을 대상 form_path로 복사한다 (매니페스트 배포)
     *   2) ImportService가 docs/import-root → 볼륨 반영 시 호출한다
     *   3) overwrite=false이고 대상이 있으면 건너뛰고 false를 반환한다
     */
    public boolean copyFromPath(
            // 소스 절대/정규 Path — import-root 내부여야 한다
            Path source,
            // 대상 상대 form_path
            String formPath,
            // true면 기존 파일 교체
            boolean overwrite
    ) {
        if (source == null || !Files.isRegularFile(source)) {
            throw new BizException("템플릿 원본 파일을 찾을 수 없습니다.");
        }
        Path target = resolveInsideTemplate(formPath, true);
        try {
            if (!overwrite && Files.exists(target)) {
                return false;
            }
            Files.createDirectories(target.getParent());
            Files.copy(source, target, StandardCopyOption.REPLACE_EXISTING);
            return true;
        } catch (IOException e) {
            throw new BizException("템플릿 원본 파일을 저장하지 못했습니다.");
        }
    }

    private void validateUpload(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BizException("저장할 템플릿 파일을 선택하세요.");
        }
        if (file.getSize() > maxBytes) {
            throw new BizException("파일 크기가 허용 한도를 초과했습니다.");
        }
        String original = file.getOriginalFilename() == null ? "" : file.getOriginalFilename().toLowerCase();
        if (!(original.endsWith(".hwp") || original.endsWith(".hwpx"))) {
            throw new BizException("HWP 또는 HWPX 파일만 템플릿으로 저장할 수 있습니다.");
        }
    }

    /**
     * form_path를 템플릿 루트 안 Path로 해석한다.
     * allowMissingParent=true이면(= 신규 생성) 파일 존재 여부는 검사하지 않는다.
     */
    private Path resolveInsideTemplate(String formPath, boolean allowCreate) {
        Path declaredPath = parseDeclaredPath(formPath);
        Path target = appFileRoot.resolve(declaredPath).normalize();
        if (!target.startsWith(templateRoot)) {
            throw new BizException("허용되지 않은 템플릿 경로입니다.");
        }
        if (!allowCreate && !Files.exists(target)) {
            // 존재 검사는 read에서 다시 한다 — 여기서는 경로만
        }
        return target;
    }

    private Path parseDeclaredPath(String formPath) {
        if (formPath == null || formPath.isBlank()) {
            throw new BizException("템플릿 경로가 올바르지 않습니다.");
        }
        Path declaredPath;
        try {
            declaredPath = Path.of(formPath.replace('\\', '/')).normalize();
        } catch (RuntimeException e) {
            throw new BizException("템플릿 경로가 올바르지 않습니다.");
        }
        if (declaredPath.isAbsolute()
                || declaredPath.getNameCount() < 2
                || !templateDirectory.equals(declaredPath.getName(0).toString())) {
            throw new BizException("허용되지 않은 템플릿 경로입니다.");
        }
        return declaredPath;
    }
}
