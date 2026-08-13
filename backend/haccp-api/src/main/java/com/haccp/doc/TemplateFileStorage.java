/**
 * TemplateFileStorage — 표준·자사 HWP 템플릿 볼륨 저장소.
 *
 * 개발자: 박승우
 * 일자: 2026-08-10
 * 코멘트:
 *   1) APP_FILE_ROOT/{표준루트}·{자사루트} 아래만 읽고 쓰며 작성 문서(HaccpLogBooks) 트리와 경계를 둔다
 *   2) 덮어쓰기·신규 생성·자사 하위폴더를 지원한다 — 나중에 S3로 교체해도 동일 메서드 계약을 유지한다
 *   3) 디렉터리명은 app.template.standard-directory·custom-directory 로만 바꾼다
 *
 * PIPELINE[HB89] 템플릿 파일 저장
 * PIPELINE[HB88, HB90] 연관 모듈
 */
package com.haccp.doc;

// 역할 — 사용자 노출 업무 오류
import com.haccp.common.exception.BizException;
// 역할 — 원본 파일 부재를 404로 내리는 예외
import com.haccp.common.exception.NotFoundException;
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

    /**
     * 양식 원본이 아직 없을 때 쓰는 단일 문구.
     * form_path 공백(= 유형만 등록)과 파일 실물 부재(= 경로는 있는데 파일이 지워짐)를
     * 사용자 입장에서 같은 상황으로 보고 한 문구로 통일한다 — 09 G-05.
     */
    public static final String FORM_NOT_UPLOADED =
            "양식 파일이 아직 업로드되지 않았습니다. 좌측 상단에서 파일을 업로드해 주세요.";

    // APP_FILE_ROOT 정규화 경로
    private final Path appFileRoot;
    // 전 회사 공통 표준 양식 폴더명 — app.template.standard-directory
    private final String standardDirectory;
    // 회사별 자사 커스텀 양식 폴더명 — app.template.custom-directory
    private final String customDirectory;
    // APP_FILE_ROOT/{standardDirectory}
    private final Path standardRoot;
    // APP_FILE_ROOT/{customDirectory}
    private final Path customRoot;
    // 업로드 허용 바이트 상한 — app.file.max-bytes
    private final long maxBytes;

    public TemplateFileStorage(
            // 문서·첨부·템플릿이 함께 쓰는 운영 볼륨 루트
            @Value("${app.file.root}") String appFileRoot,
            // 표준 양식 루트 폴더명 — 전 회사 공통 1벌
            @Value("${app.template.standard-directory}") String standardDirectory,
            // 자사 양식 루트 폴더명 — 회사코드 하위로만 쓴다
            @Value("${app.template.custom-directory}") String customDirectory,
            // 운영 파일 크기 한도
            @Value("${app.file.max-bytes}") long maxBytes
    ) {
        this.appFileRoot = Path.of(appFileRoot).toAbsolutePath().normalize();
        this.standardDirectory = TemplateFileNames.segment(standardDirectory);
        this.customDirectory = TemplateFileNames.segment(customDirectory);
        this.standardRoot = this.appFileRoot.resolve(this.standardDirectory).normalize();
        this.customRoot = this.appFileRoot.resolve(this.customDirectory).normalize();
        this.maxBytes = maxBytes;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-13
     * 코멘트:
     *   1) 표준·자사 루트 이름을 알고 있는 이 저장소가 상대 form_path를 조립한다
     *   2) 표준 배포·자사 업로드가 볼륨에 쓰기 직전에 호출한다
     *   3) coCd가 공백일 때(= 전 회사 공통 표준) 표준 루트, 값이 있으면 자사 루트
     */
    public String formPath(
            // 회사코드 — 공백이면 표준 양식
            String coCd,
            // 양식코드 tmpl_cd — 타입 폴더
            String tmplCd,
            // safeTemplateFileName으로 정규화한 파일명
            String safeFileName
    ) {
        return TemplateFileNames.relativeFormPath(
                standardDirectory, customDirectory, coCd, tmplCd, safeFileName
        );
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
            // DB가 반환한 내부 상대 경로 — 표준·자사 루트 중 하나로 시작
            String formPath
    ) {
        Path target = resolveInsideTemplate(formPath, false);
        // 경로는 유효한데 실물이 없을 때(= 다른 사용자가 지웠거나 볼륨 미마운트) 400이 아니라 404
        if (!Files.isRegularFile(target)) {
            throw new NotFoundException(FORM_NOT_UPLOADED);
        }
        try {
            Path realTarget = target.toRealPath();
            // 심볼릭 링크로 루트 밖을 가리킬 때(= 링크 이탈) 차단 — 실경로로 다시 확인한다
            if (!startsWithRealRoot(realTarget, standardRoot)
                    && !startsWithRealRoot(realTarget, customRoot)) {
                throw new BizException("허용되지 않은 템플릿 경로입니다.");
            }
            return realTarget;
        } catch (IOException e) {
            throw new BizException("템플릿 원본 파일을 읽지 못했습니다.");
        }
    }

    /** 실경로 비교 — 루트 폴더가 아직 없을 때(= 해당 루트에 업로드 이력 없음) false */
    private boolean startsWithRealRoot(Path realTarget, Path root) {
        try {
            return realTarget.startsWith(root.toRealPath());
        } catch (IOException e) {
            return false;
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 기존 form_path 위치에 HWP/HWPX 바이트를 덮어쓴다
     *   2) 표준 양식 수정 저장·원본 부재 후 로컬열기 저장에서 호출한다
     *   3) 경로만 있고 실물이 없을 때(= 볼륨 미시드) 상위 폴더를 만들고 신규로 쓴다
     */
    public Path write(
            // DB form_path — 표준·자사 루트 안이면 실물 유무와 상관없이 이 위치에 쓴다
            String formPath,
            // 브라우저가 올린 수정본
            MultipartFile file
    ) {
        validateUpload(file);
        // 실물이 없어도 같은 경로에 저장해야 한다 — 없으면 create 와 같다
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
     *   1) 아직 없는 form_path에 신규 파일을 만든다 (자사 업로드·배포 초기화)
     *   2) 상위 디렉터리({자사루트}/{coCd}/{tmplCd})를 필요 시 생성한다
     *   3) 성공 시 실제 Path — DB에는 상대 formPath를 그대로 저장한다
     */
    public Path create(
            // 저장할 상대 경로 — formPath()가 만든 {표준루트}/{tmplCd}/... 또는 {자사루트}/{coCd}/{tmplCd}/...
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
     * form_path를 표준·자사 템플릿 루트 안 Path로 해석한다.
     * allowCreate=true이면(= 신규 생성) 파일 존재 여부는 검사하지 않는다.
     */
    private Path resolveInsideTemplate(String formPath, boolean allowCreate) {
        Path declaredPath = parseDeclaredPath(formPath);
        Path target = appFileRoot.resolve(declaredPath).normalize();
        // 정규화 후에도 두 루트 밖일 때(= ../ 경로 조작) 차단
        if (!target.startsWith(standardRoot) && !target.startsWith(customRoot)) {
            throw new BizException("허용되지 않은 템플릿 경로입니다.");
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
        // 첫 세그먼트가 표준·자사 루트가 아닐 때(= 문서 볼륨·절대경로) 차단
        String first = declaredPath.getNameCount() == 0 ? "" : declaredPath.getName(0).toString();
        if (declaredPath.isAbsolute()
                || declaredPath.getNameCount() < 2
                || !(standardDirectory.equals(first) || customDirectory.equals(first))) {
            throw new BizException("허용되지 않은 템플릿 경로입니다.");
        }
        return declaredPath;
    }
}
