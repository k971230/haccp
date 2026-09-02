/**
 * DocumentController — 문서함·결재·첨부 REST API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-21
 * 코멘트:
 *   1) 문서함은 /api/v1/docs/documents, 결재·첨부는 문서 idx 하위 경로로 제공한다
 *   2) 파일 업·다운로드만 httpFile 계층을 쓰고 나머지는 일반 CRUD 타임아웃에 맞춘다
 *   3) 삭제는 HTTP DELETE가 아닌 validate-delete → POST delete 객체 배열 계약을 지킨다
 *
 * PIPELINE[HB87] REST Controller
 * PIPELINE[HB86, HB80, HB81] 연관 모듈
 */
package com.haccp.docs.documents;

// 역할 — 요청 접속 메타
import com.haccp.common.context.RequestMeta;
// 역할 — 공통 응답 래퍼
import com.haccp.common.response.CommonResponse;
// 역할 — 결재·삭제 요청 DTO
import com.haccp.docs.documents.dto.DocumentApprovalRequest;
import com.haccp.docs.documents.dto.DocumentDeleteItem;
import com.haccp.docs.documents.dto.HwpDocumentSaveRequest;
// 역할 — HTTP 요청 원천
import jakarta.servlet.http.HttpServletRequest;
// 역할 — 목록·맵 타입
import java.nio.file.Files;
import java.util.List;
import java.util.Map;
// 역할 — 생성자 주입
import lombok.RequiredArgsConstructor;
// 역할 — 다운로드 HTTP 헤더·응답
import org.springframework.core.io.FileSystemResource;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
// 역할 — Multipart 업로드
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/** 문서·결재·첨부 공통 API */
@RestController
@RequestMapping("/api/v1/docs/documents")
@RequiredArgsConstructor
public class DocumentController {

    private final DocumentService service;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 기간·양식·상태·키워드 조건으로 통합 문서함을 조회한다
     *   2) document-inbox 문서함과 관련 문서 선택기에 호출된다
     *   3) 성공 시 DB형·HWP형을 구분한 목록 배열
     */
    @GetMapping("/list")
    public CommonResponse<List<Map<String, Object>>> list(
            // 기준일 시작 YYYYMMDD — 생략하면 전체
            @RequestParam(required = false) String fromDt,
            // 기준일 종료 YYYYMMDD — 생략하면 전체
            @RequestParam(required = false) String toDt,
            // 템플릿 코드 필터
            @RequestParam(required = false) String tmplCd,
            // 문서 상태 필터
            @RequestParam(required = false) String status,
            // 문서번호·제목 검색어
            @RequestParam(required = false) String keyword,
            // 작성자 ID 필터
            @RequestParam(required = false) String writerId
    ) {
        return CommonResponse.ok(service.list(fromDt, toDt, tmplCd, status, keyword, writerId));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 결재함 — 내 차례 대기 문서만 조회한다
     *   2) approval-inbox에서 호출한다
     *   3) 성공 시 목록 배열
     */
    @GetMapping("/approval-inbox")
    public CommonResponse<List<Map<String, Object>>> approvalInbox(
            @RequestParam(required = false) String fromDt,
            @RequestParam(required = false) String toDt,
            @RequestParam(required = false) String keyword
    ) {
        return CommonResponse.ok(service.approvalInbox(fromDt, toDt, keyword));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 결재 이력 — 내가 처리한 문서를 조회한다
     *   2) approval-history에서 호출한다
     *   3) 성공 시 목록 배열
     */
    @GetMapping("/approval-history")
    public CommonResponse<List<Map<String, Object>>> approvalHistory(
            @RequestParam(required = false) String fromDt,
            @RequestParam(required = false) String toDt,
            @RequestParam(required = false) String keyword
    ) {
        return CommonResponse.ok(service.approvalHistory(fromDt, toDt, keyword));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 문서 헤더·결재선·첨부·버전을 함께 조회한다
     *   2) 문서함 행과 양식 공통 결재 패널이 호출한다
     *   3) 성공 시 filePath를 제외한 상세 묶음
     */
    @GetMapping("/{docIdx}")
    public CommonResponse<Map<String, Object>> detail(
            // 문서 대리키
            @PathVariable Long docIdx
    ) {
        return CommonResponse.ok(service.detail(docIdx));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) HWP 문서형의 공통 메타를 신규·수정하고 docIdx를 반환한다
     *   2) hwp-document-editor rhwp 편집기가 HWPX 원본 업로드 전에 호출한다
     *   3) 성공 시 docIdx, 실패 시 양식·작성자·문서 상태 업무 오류
     */
    @PutMapping("/hwp/save")
    public CommonResponse<Map<String, Long>> saveHwpDocument(
            // HWP 문서형 헤더 입력
            @jakarta.validation.Valid @RequestBody HwpDocumentSaveRequest req,
            // 감사 IP 추출 원천
            HttpServletRequest http
    ) {
        Long docIdx = service.saveHwpDocument(req, RequestMeta.of(http));
        return CommonResponse.ok(Map.of("docIdx", docIdx));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 문서에 HWPX·PDF·사진·일반 첨부를 업로드한다
     *   2) 파일 업로드 패널이 multipart/form-data로 호출한다
     *   3) 성공 시 서버 물리 경로를 제외한 파일 메타를 반환한다
     */
    @PostMapping(value = "/{docIdx}/files", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public CommonResponse<Map<String, Object>> upload(
            // 연결 문서 idx
            @PathVariable Long docIdx,
            // 파일 분류 HWP_SRC/PDF/ATTACH/PHOTO
            @RequestPart String fileKind,
            // 실제 업로드 파일
            @RequestPart MultipartFile file,
            // 감사 IP 추출 원천
            HttpServletRequest http
    ) {
        return CommonResponse.ok(service.upload(docIdx, fileKind, file, RequestMeta.of(http)));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 문서의 최신 HWP_SRC를 서버 rhwp CLI로 PDF로 변환해 file_kind=PDF로 보관한다
     *   2) hwp-document-editor의 PDF 내보내기 버튼이 httpFile 타임아웃으로 호출한다
     *   3) 성공 시 물리 경로를 제외한 파일 메타, 원본 없음·CLI 미설정·변환 실패는 업무 오류
     */
    @PostMapping("/{docIdx}/export-pdf")
    public CommonResponse<Map<String, Object>> exportPdf(
            // PDF로 내보낼 문서 대리키
            @PathVariable Long docIdx,
            // 감사 IP 추출 원천
            HttpServletRequest http
    ) {
        return CommonResponse.ok(service.exportPdf(docIdx, RequestMeta.of(http)));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 테넌트 범위로 파일을 읽어 attachment 응답을 만든다
     *   2) 문서 첨부 목록의 다운로드 버튼에서 호출한다
     *   3) 파일이 없거나 다른 회사 파일이면 업무 오류, 성공 시 스트림 응답
     */
    @GetMapping("/files/{fileIdx}/download")
    public ResponseEntity<FileSystemResource> download(
            // 파일 대리키
            @PathVariable Long fileIdx
    ) {
        DocumentService.DownloadFile file = service.download(fileIdx);
        MediaType mediaType = toMediaType(file.mimeType());
        FileSystemResource body = new FileSystemResource(file.path());
        try {
            return ResponseEntity.ok()
                    .contentType(mediaType)
                    .contentLength(Files.size(file.path()))
                    .header(
                            HttpHeaders.CONTENT_DISPOSITION,
                            ContentDisposition.attachment()
                                    .filename(file.fileNm(), java.nio.charset.StandardCharsets.UTF_8)
                                    .build()
                                    .toString()
                    )
                    .body(body);
        } catch (java.io.IOException e) {
            throw new com.haccp.common.exception.BizException("파일을 읽지 못했습니다.");
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) 문서 첨부 1건을 삭제한다 — 메타와 물리 파일을 같이 지운다
     *   2) 결재 첨부(attach) 화면의 첨부 삭제 버튼이 호출한다
     *   3) 결재 진행·완료 문서는 SP가 막는다. 성공 시 void. HTTP DELETE 는 쓰지 않는다
     */
    @PostMapping("/files/{fileIdx}/delete")
    public CommonResponse<Void> deleteFile(
            // 파일 대리키
            @PathVariable Long fileIdx,
            // 감사 IP 추출 원천
            HttpServletRequest http
    ) {
        service.deleteFile(fileIdx, RequestMeta.of(http));
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) 문서 비고를 저장한다 — 결재 완료(APV) 전까지만 고칠 수 있다
     *   2) 결재 첨부(attach) 화면의 비고 저장 버튼이 호출한다
     *   3) 작성자 본인 문서만. 잠금·소유 검증은 SP가 한다
     */
    @PutMapping("/{docIdx}/remark")
    public CommonResponse<Void> saveRemark(
            // 문서 idx
            @PathVariable Long docIdx,
            // { remark } — 빈 문자열이면 지운다
            @RequestBody Map<String, String> body,
            // 감사 IP 추출 원천
            HttpServletRequest http
    ) {
        service.saveRemark(docIdx, body.get("remark"), RequestMeta.of(http));
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-09-02
     * 코멘트:
     *   1) 작성 목록 제목을 저장한다 — tbl_document.title
     *   2) 작성 화면 좌측 저장이 호출한다
     *   3) 결재 첨부 remark 와 다르다. 상태와 무관. 작성자만
     */
    @PutMapping("/{docIdx}/title")
    public CommonResponse<Void> saveTitle(
            // 문서 idx
            @PathVariable Long docIdx,
            // { title } — 빈 문자열이면 지운다
            @RequestBody Map<String, String> body,
            // 감사 IP 추출 원천
            HttpServletRequest http
    ) {
        service.saveTitle(docIdx, body.get("title"), RequestMeta.of(http));
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 결재 요청·검토·승인·반려를 한 API에서 처리한다
     *   2) 문서 상세 결재 패널 버튼에서 호출한다
     *   3) 성공 시 void, 실패 시 SP 업무 문구
     */
    @PutMapping("/approval")
    public CommonResponse<Void> processApproval(
            // 결재 처리 요청
            @RequestBody DocumentApprovalRequest req,
            // 감사 IP 추출 원천
            HttpServletRequest http
    ) {
        service.processApproval(req, RequestMeta.of(http));
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 문서형(HWP) 삭제 가능 여부를 사전 검사한다
     *   2) FE confirm 바로 전에 호출한다
     *   3) 통과 시 void, 결재·보존·DB형 문서는 업무 오류
     */
    @PostMapping("/validate-delete")
    public CommonResponse<Void> validateDelete(
            // 삭제 키 객체 배열
            @RequestBody List<DocumentDeleteItem> keys
    ) {
        service.validateDelete(keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 문서형(HWP) 임시·반려 문서와 첨부 파일을 삭제한다
     *   2) validate-delete 통과·사용자 확인 후 호출한다
     *   3) 성공 시 void — CALL 영향 행수(-1)를 사용자에게 노출하지 않는다
     */
    @PostMapping("/delete")
    public CommonResponse<Void> delete(
            // 삭제 키 객체 배열
            @RequestBody List<DocumentDeleteItem> keys,
            // 감사 IP 추출 원천
            HttpServletRequest http
    ) {
        service.delete(keys, RequestMeta.of(http));
        return CommonResponse.ok(null);
    }

    /** MIME 문자열이 비었거나 형식 오류일 때 안전한 바이너리 MIME으로 되돌린다 */
    private MediaType toMediaType(String value) {
        try {
            return value == null || value.isBlank()
                    ? MediaType.APPLICATION_OCTET_STREAM
                    : MediaType.parseMediaType(value);
        } catch (IllegalArgumentException e) {
            return MediaType.APPLICATION_OCTET_STREAM;
        }
    }
}
