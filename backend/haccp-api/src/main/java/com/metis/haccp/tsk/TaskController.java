/**
 * TaskController — 오늘 할 일·알림·개선조치·감사자료 REST API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) 세 역할 기반 화면의 API를 전용 경로로 제공한다
 *   2) 삭제는 POST validate-delete → POST delete 객체 배열 계약만 허용한다
 *   3) 회사·작업자 정보는 요청값이 아니라 JWT 컨텍스트에서 결정한다
 *
 * PIPELINE[HB95] 워크플로 작업 Controller
 * PIPELINE[HB93, HB94, HF87] 연관 모듈
 */
package com.metis.haccp.tsk;

// 역할 — 요청 접속 메타
import com.metis.haccp.common.context.RequestMeta;
// 역할 — 공통 응답
import com.metis.haccp.common.response.CommonResponse;
// 역할 — 문서 PDF 미리보기
import com.metis.haccp.doc.DocumentService;
import com.metis.haccp.doc.dto.DocumentDeleteItem;
// 역할 — HTTP 요청
import jakarta.servlet.http.HttpServletRequest;
// 역할 — 파일·컬렉션
import java.nio.file.Files;
import java.util.List;
import java.util.Map;
// 역할 — Spring REST 매핑·파일 응답
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.FileSystemResource;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequiredArgsConstructor
public class TaskController {
    private final TaskService service;
    private final DocumentService documentService;

    @GetMapping("/api/v1/tsk/today-tasks/list")
    public CommonResponse<List<Map<String, Object>>> todayTasks() { return CommonResponse.ok(service.todayTasks()); }

    @GetMapping("/api/v1/tsk/notifications/list")
    public CommonResponse<List<Map<String, Object>>> notifications() { return CommonResponse.ok(service.notifications()); }

    @PutMapping("/api/v1/tsk/notifications/{idx}/read")
    public CommonResponse<Void> readNotification(@PathVariable Long idx) { service.readNotification(idx); return CommonResponse.ok(null); }

    @GetMapping("/api/v1/doc/corrective-actions/list")
    public CommonResponse<List<Map<String, Object>>> correctiveActions(@RequestParam(required = false) String status, @RequestParam(required = false) String fromDt, @RequestParam(required = false) String toDt) {
        return CommonResponse.ok(service.correctiveActions(status, fromDt, toDt));
    }

    @PutMapping("/api/v1/doc/corrective-actions/save")
    public CommonResponse<Void> saveCorrectiveAction(@RequestBody Map<String, Object> row) {
        Long idx = row.get("idx") instanceof Number n ? n.longValue() : null;
        service.saveCorrectiveAction(idx, row);
        return CommonResponse.ok(null);
    }

    @PostMapping("/api/v1/doc/corrective-actions/validate-delete")
    public CommonResponse<Void> validateCorrectiveActionDelete(@RequestBody List<Map<String, Long>> keys) {
        service.validateCorrectiveActionDelete(keys);
        return CommonResponse.ok(null);
    }

    @PostMapping("/api/v1/doc/corrective-actions/delete")
    public CommonResponse<Void> deleteCorrectiveActions(@RequestBody List<Map<String, Long>> keys) {
        service.deleteCorrectiveActions(keys);
        return CommonResponse.ok(null);
    }

    @GetMapping("/api/v1/doc/documents/{docIdx}/relations")
    public CommonResponse<List<Map<String, Object>>> relations(@PathVariable Long docIdx) { return CommonResponse.ok(service.relations(docIdx)); }

    @PutMapping("/api/v1/doc/documents/{docIdx}/relations/save")
    public CommonResponse<Void> saveRelation(@PathVariable Long docIdx, @RequestBody Map<String, Object> row) {
        Object target = row.get("tgtDocIdx");
        Long tgtDocIdx = target instanceof Number n ? n.longValue() : null;
        service.saveRelation(docIdx, row.get("relType") == null ? "" : String.valueOf(row.get("relType")), tgtDocIdx);
        return CommonResponse.ok(null);
    }

    @GetMapping("/api/v1/doc/audit-export/list")
    public CommonResponse<List<Map<String, Object>>> auditExport(@RequestParam(required = false) String fromDt, @RequestParam(required = false) String toDt, @RequestParam(required = false) String status) {
        return CommonResponse.ok(service.auditExport(fromDt, toDt, status));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 선택 문서의 PDF를 단일 또는 zip으로 내려준다
     *   2) AuditExportPage PDF 미리보기가 httpFile로 호출한다
     *   3) HWP만 있고 PDF가 없으면 서버에서 export-pdf 후 포함한다
     */
    @PostMapping("/api/v1/doc/audit-export/preview-pdf")
    public ResponseEntity<FileSystemResource> auditPreviewPdf(
            // 선택 문서 키 배열 — [{ docIdx }]
            @RequestBody List<DocumentDeleteItem> keys,
            HttpServletRequest http
    ) {
        DocumentService.DownloadFile file = documentService.previewAuditPdfs(keys, RequestMeta.of(http));
        MediaType mediaType;
        try {
            mediaType = MediaType.parseMediaType(file.mimeType());
        } catch (Exception e) {
            mediaType = MediaType.APPLICATION_OCTET_STREAM;
        }
        try {
            return ResponseEntity.ok()
                    .contentType(mediaType)
                    .contentLength(Files.size(file.path()))
                    .header(
                            HttpHeaders.CONTENT_DISPOSITION,
                            ContentDisposition.inline()
                                    .filename(file.fileNm(), java.nio.charset.StandardCharsets.UTF_8)
                                    .build()
                                    .toString()
                    )
                    .body(new FileSystemResource(file.path()));
        } catch (java.io.IOException e) {
            throw new com.metis.haccp.common.exception.BizException("미리보기 파일을 읽지 못했습니다.");
        }
    }
}
