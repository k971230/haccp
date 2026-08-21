/**
 * TemplateService — 회사 사용 HWP 템플릿 조회·원본 읽기·원본 덮어쓰기 업무 서비스.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 템플릿 SP의 회사 사용여부와 파일 저장소의 물리 경계 검증을 한 흐름으로 묶는다
 *   2) 목록은 formPath 대신 인증된 API URL을 반환하고, 원본은 JWT 회사 범위에서만 연다
 *   3) 원본 수정은 덮어쓰지 않고 새 버전 파일 + 이력 1건으로 남긴다 — 불러오기·초기화의 원천
 *
 * PIPELINE[HB90] 템플릿 Service
 * PIPELINE[HB83, HB88, HB89] 연관 모듈
 */
package com.haccp.docs.template;

// 역할 — JWT 테넌트 컨텍스트
import com.haccp.common.context.LoginUserContext;
// 역할 — 사용자 노출 업무 오류
import com.haccp.common.exception.BizException;
// 역할 — 원본 미업로드를 404로 내리는 예외
import com.haccp.common.exception.NotFoundException;
// 역할 — 템플릿 DB·공개 응답 DTO
import com.haccp.docs.document.dto.DocumentTemplateResponse;
import com.haccp.docs.document.dto.DocumentTemplateRow;
// 역할 — 템플릿 목록 SP
import com.haccp.docs.document.DocumentMapper;
// 역할 — 파일 경로
import java.nio.file.Path;
// 역할 — 업로드 버전 파일명 시각 접미
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
// 역할 — 목록 타입
import java.util.List;
// 역할 — 서버 로그(요청 맥락 상세)
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
// 역할 — 생성자 주입·서비스 등록
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
// 역할 — 브라우저 업로드 파일
import org.springframework.web.multipart.MultipartFile;

/** 표준양식 원본의 테넌트 인가와 공개 응답 조립 서비스 */
@Service
@RequiredArgsConstructor
public class TemplateService {

    // 서버 로그 — 사용자 응답에는 담지 않는 회사코드·양식코드·경로를 남긴다
    private static final Logger log = LoggerFactory.getLogger(TemplateService.class);

    // 회사 사용 템플릿을 저장프로시저로 조회하는 경계
    private final DocumentMapper mapper;
    // APP_FILE_ROOT 의 표준·자사 양식 루트 밖 접근을 차단하는 원본 파일 저장소
    private final TemplateFileStorage storage;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 로그인 회사가 사용 중인 구현 템플릿을 선택 목록으로 변환한다
     *   2) HWP 문서 편집 화면이 양식 선택 콤보를 초기화할 때 호출한다
     *   3) 성공 시 formPath 없는 목록을 반환하고, 원본이 있을 때만 formUrl·formFileNm을 채운다
     */
    public List<DocumentTemplateResponse> list() {
        String coCd = LoginUserContext.coCd();
        return mapper.selectTemplates(coCd).stream()
                .map(this::toResponse)
                .toList();
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 요청 템플릿이 로그인 회사에서 사용 중인지 확인한 뒤 원본 경로를 연다
     *   2) TemplateController가 HWP 원본 스트림과 안전한 다운로드 헤더를 만들 때 호출한다
     *   3) 원본 미업로드·파일 누락은 404(NotFoundException), 루트 이탈은 400(BizException)
     */
    public TemplateForm form(
            // URL 템플릿 코드 — 공백·미등록이면 SP 결과가 없어 업무 오류
            String tmplCd
    ) {
        DocumentTemplateRow template = requireTemplate(tmplCd);
        String formPath = template.getFormPath() == null ? "" : template.getFormPath().trim();
        // form_path 공백일 때(= LAW 유형만 만들고 파일은 아직 안 올린 상태) 400이 아니라 404로 내린다.
        // 잘못된 요청이 아니라 "대상이 아직 없다"이므로 프론트가 업로드 안내를 띄울 수 있어야 한다 — 09 G-05
        if (formPath.isBlank()) {
            log.warn(
                    "Template form not uploaded — coCd={}, tmplCd={}, formPath=(blank)",
                    LoginUserContext.coCd(),
                    template.getTmplCd()
            );
            throw new NotFoundException(TemplateFileStorage.FORM_NOT_UPLOADED);
        }
        // 경로는 있는데 실물이 없을 때도 storage.read가 같은 문구로 404를 던진다
        Path path;
        try {
            path = storage.read(formPath);
        } catch (NotFoundException e) {
            log.warn(
                    "Template form file missing — coCd={}, tmplCd={}, formPath={}",
                    LoginUserContext.coCd(),
                    template.getTmplCd(),
                    formPath
            );
            throw e;
        }
        // 실제 검증을 통과한 파일명만 다운로드 헤더에 써 DB 표시값 주입 가능성을 제거한다
        return new TemplateForm(path.getFileName().toString(), path);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-14
     * 코멘트:
     *   1) 업로드본을 새 버전 파일로 저장하고 이력에 1건 남긴 뒤 현재 적용본으로 만든다
     *   2) 사용양식관리 업로드·법적서류 유형 업로드·HWP 편집기의 "템플릿 원본 저장"이 호출한다
     *   3) 기존 파일을 덮어쓰지 않는다 — 초기화·불러오기가 과거 버전을 다시 열 수 있어야 한다
     */
    @Transactional
    public void saveForm(
            // URL 템플릿 코드 — 공백·미등록이면 SP 결과가 없어 업무 오류
            String tmplCd,
            // rhwp가 내보낸 HWPX 또는 사용자가 고른 HWP 수정본
            MultipartFile file
    ) {
        DocumentTemplateRow template = requireTemplate(tmplCd);
        if (file == null || file.isEmpty()) {
            throw new BizException("업로드할 양식 파일을 선택하세요.");
        }
        String coCd = LoginUserContext.coCd();
        // 표시 이력에는 사용자가 올린 원본명을 남기고, 물리 파일만 시각 접미로 버전을 구분한다
        String safeName = TemplateFileNames.safeTemplateFileName(file.getOriginalFilename());
        String versionName = TemplateFileNames.versionedFileName(
                safeName, DateTimeFormatter.ofPattern("yyyyMMddHHmmss").format(LocalDateTime.now())
        );
        // 자사 업로드 — CustomTemplates/{회사코드}/{양식코드}/{버전 파일명}
        String formPath = storage.formPath(coCd, template.getTmplCd(), versionName);
        // 볼륨에 먼저 쓰고 DB 메타를 맞춘다 — SP 실패 시 트랜잭션 롤백(고아 파일은 운영 정리)
        storage.create(formPath, file);
        mapper.insertCompanyTemplateFile(
                coCd, template.getTmplCd(), safeName, formPath, file.getSize(), LoginUserContext.userId()
        );
        log.info(
                "Template form version saved — coCd={}, tmplCd={}, formPath={}",
                coCd, template.getTmplCd(), formPath
        );
    }

    /** 회사 사용 템플릿 단건을 강제한다 */
    private DocumentTemplateRow requireTemplate(String tmplCd) {
        String code = tmplCd == null ? "" : tmplCd.trim();
        if (code.isBlank()) {
            throw new BizException("템플릿 코드가 올바르지 않습니다.");
        }
        DocumentTemplateRow template = mapper.selectTemplate(LoginUserContext.coCd(), code);
        if (template == null) {
            throw new BizException("사용 가능한 템플릿을 찾을 수 없습니다.");
        }
        return template;
    }

    /** 서버 전용 formPath를 빼고 동일 API 서버의 인증 URL로 바꾼다 */
    private DocumentTemplateResponse toResponse(DocumentTemplateRow row) {
        DocumentTemplateResponse out = new DocumentTemplateResponse();
        out.setTmplCd(row.getTmplCd());
        out.setTmplNm(row.getTmplNm());
        out.setDocKind(row.getDocKind());
        out.setCategoryCd(row.getCategoryCd());
        out.setMngNo(row.getMngNo());
        // form_path 없을 때(= 법적서류 유형만 등록) formUrl을 비워 클라이언트가 빈 원본을 요청하지 않게 한다
        String formPath = row.getFormPath() == null ? "" : row.getFormPath().trim();
        if (!formPath.isBlank()) {
            out.setFormUrl("/api/v1/doc/templates/" + row.getTmplCd() + "/form");
            out.setFormFileNm(row.getFormFileNm());
        }
        out.setSysYn(row.getSysYn());
        return out;
    }

    /** Controller가 스트림 응답에만 쓰는 서버 내부 원본 정보 */
    public record TemplateForm(String formFileNm, Path path) {}
}
