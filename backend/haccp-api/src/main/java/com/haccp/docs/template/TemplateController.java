/**
 * TemplateController — 회사 사용 템플릿 목록·HWP 원본 스트림 API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-21
 * 코멘트:
 *   1) /api/v1/docs/templates에서 JWT 회사별 양식 목록과 원본 파일을 의미적으로 분리해 제공한다
 *   2) 목록은 formUrl·formFileNm만 공개하고, 원본은 서비스의 템플릿 전용 저장소를 통해서만 연다
 *   3) 파일 스트림은 UTF-8 Content-Disposition과 안전한 binary MIME으로 브라우저에 전달한다
 *
 * PIPELINE[HB91] 템플릿 REST Controller
 * PIPELINE[HB90, HB89, HB3] 연관 모듈
 */
package com.haccp.docs.template;

// 역할 — 공통 JSON 응답 래퍼
import com.haccp.common.response.CommonResponse;
// 역할 — 템플릿 목록 공개 DTO
import com.haccp.docs.document.dto.DocumentTemplateResponse;
// 역할 — 파일 길이 확인
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.List;
// 역할 — 실제 파일 스트림 리소스
import org.springframework.core.io.FileSystemResource;
// 역할 — 다운로드 헤더·응답 타입
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
// 역할 — REST 경로 매핑
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/** HWP 템플릿 전용 REST API */
@RestController
@RequestMapping("/api/v1/docs/templates")
public class TemplateController {

    // 템플릿 테넌트 인가·파일 경계·응답 조립 서비스
    private final TemplateService service;

    public TemplateController(
            // 생성자 주입 대상 — 컨트롤러는 JWT 컨텍스트·파일 경로를 직접 다루지 않는다
            TemplateService service
    ) {
        this.service = service;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 현재 JWT 회사가 사용 중인 구현 템플릿 목록을 반환한다
     *   2) hwp-document-editor 양식 선택 콤보가 화면 진입 시 호출한다
     *   3) 성공 시 formUrl·formFileNm 포함 목록, 내부 formPath는 절대 노출하지 않는다
     */
    @GetMapping("/list")
    public CommonResponse<List<DocumentTemplateResponse>> list() {
        return CommonResponse.ok(service.list());
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) JWT 회사에서 사용 가능한 표준 HWP 원본 한 건을 attachment 스트림으로 반환한다
     *   2) rhwp 편집기가 목록의 formUrl을 httpFile 인증 요청으로 열 때 호출한다
     *   3) 미등록·미사용·누락·루트 이탈은 서비스가 업무 오류로 차단하고 파일은 반환하지 않는다
     */
    @GetMapping("/{tmplCd}/form")
    public ResponseEntity<FileSystemResource> form(
            // URL 템플릿 업무키 — 서비스가 JWT 회사 사용여부를 SP로 검증한다
            @PathVariable String tmplCd
    ) {
        TemplateService.TemplateForm form = service.form(tmplCd);
        try {
            return ResponseEntity.ok()
                    .contentType(MediaType.APPLICATION_OCTET_STREAM)
                    .contentLength(Files.size(form.path()))
                    .header(
                            HttpHeaders.CONTENT_DISPOSITION,
                            ContentDisposition.attachment()
                                    .filename(form.formFileNm(), StandardCharsets.UTF_8)
                                    .build()
                                    .toString()
                    )
                    .body(new FileSystemResource(form.path()));
        } catch (IOException e) {
            throw new com.haccp.common.exception.BizException("템플릿 원본 파일을 읽지 못했습니다.");
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) JWT 회사가 사용하는 표준 템플릿 HWP/HWPX 원본을 같은 경로에 덮어쓴다
     *   2) HWP 문서 편집 화면이 템플릿 자체 수정 결과를 저장할 때 호출한다
     *   3) 성공 시 본문 없음, 미사용·확장자·크기 오류는 서비스가 업무 문구로 반환한다
     */
    @PostMapping(value = "/{tmplCd}/form", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public CommonResponse<Void> saveForm(
            // URL 템플릿 업무키 — 서비스가 JWT 회사 사용여부를 SP로 검증한다
            @PathVariable String tmplCd,
            // 수정된 표준양식 원본 — HWP 또는 HWPX만 허용
            @RequestPart MultipartFile file
    ) {
        service.saveForm(tmplCd, file);
        return CommonResponse.ok(null);
    }
}
