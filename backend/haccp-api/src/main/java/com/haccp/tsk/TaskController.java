/**
 * TaskController — 오늘 할 일·알림·개선조치·감사자료 REST API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-21
 * 코멘트:
 *   1) 세 역할 기반 화면의 API를 전용 경로로 제공한다
 *   2) 삭제는 POST validate-delete → POST delete 객체 배열 계약만 허용한다
 *   3) 회사·작업자 정보는 요청값이 아니라 JWT 컨텍스트에서 결정한다
 *
 * PIPELINE[HB95] 워크플로 작업 Controller
 * PIPELINE[HB93, HB94, HF87] 연관 모듈
 */
package com.haccp.tsk;

// 역할 — 요청 접속 메타
import com.haccp.common.context.RequestMeta;
// 역할 — 공통 응답
import com.haccp.common.response.CommonResponse;
// 역할 — 문서 PDF 미리보기
import com.haccp.docs.documents.DocumentService;
import com.haccp.docs.documents.dto.DocumentDeleteItem;
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

    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) 오늘 할 일 최근 문서를 기간 + OFFSET/LIMIT 으로 조회한다
     *   2) 랜딩 최근 문서 패널이 호출한다. 문서함 /docs/documents/list 는 그대로 둔다
     *   3) 성공 시 { rows, total }. total 은 기간 전체 건수
     */
    @GetMapping("/api/v1/tsk/today-tasks/recent-docs")
    public CommonResponse<Map<String, Object>> todayTaskDocs(
            // 기준일 시작 YYYYMMDD
            @RequestParam(required = false) String fromDt,
            // 기준일 종료 YYYYMMDD
            @RequestParam(required = false) String toDt,
            // 건너뛸 행 수 — 첫 페이지는 0
            @RequestParam(required = false) Integer offset,
            // 가져올 행 수 — 화면 기본 20
            @RequestParam(required = false) Integer limit
    ) {
        return CommonResponse.ok(service.todayTaskDocs(fromDt, toDt, offset, limit));
    }

    @GetMapping("/api/v1/tsk/notifications/list")
    public CommonResponse<List<Map<String, Object>>> notifications() { return CommonResponse.ok(service.notifications()); }

    @PutMapping("/api/v1/tsk/notifications/{idx}/read")
    public CommonResponse<Void> readNotification(@PathVariable Long idx) { service.readNotification(idx); return CommonResponse.ok(null); }

    @GetMapping("/api/v1/flow/ca/corrective-action-management/list")
    public CommonResponse<List<Map<String, Object>>> correctiveActions(
            // fromDt·toDt: 문서 기준일 구간 YYYYMMDD
            @RequestParam(required = false) String fromDt,
            @RequestParam(required = false) String toDt,
            // tmplCd: 양식코드. 빈 값이면 전체
            @RequestParam(required = false) String tmplCd,
            // writer: 작성자 ID·이름 부분검색
            @RequestParam(required = false) String writer) {
        return CommonResponse.ok(service.correctiveActions(fromDt, toDt, tmplCd, writer));
    }

    @PutMapping("/api/v1/flow/ca/corrective-action-management/save")
    public CommonResponse<Void> saveCorrectiveAction(@RequestBody Map<String, Object> row) {
        Long idx = row.get("idx") instanceof Number n ? n.longValue() : null;
        service.saveCorrectiveAction(idx, row);
        return CommonResponse.ok(null);
    }

    @PostMapping("/api/v1/flow/ca/corrective-action-management/validate-delete")
    public CommonResponse<Void> validateCorrectiveActionDelete(@RequestBody List<Map<String, Long>> keys) {
        service.validateCorrectiveActionDelete(keys);
        return CommonResponse.ok(null);
    }

    @PostMapping("/api/v1/flow/ca/corrective-action-management/delete")
    public CommonResponse<Void> deleteCorrectiveActions(@RequestBody List<Map<String, Long>> keys) {
        service.deleteCorrectiveActions(keys);
        return CommonResponse.ok(null);
    }

    @GetMapping("/api/v1/docs/documents/{docIdx}/relations")
    public CommonResponse<List<Map<String, Object>>> relations(@PathVariable Long docIdx) { return CommonResponse.ok(service.relations(docIdx)); }

    @PutMapping("/api/v1/docs/documents/{docIdx}/relations/save")
    public CommonResponse<Void> saveRelation(@PathVariable Long docIdx, @RequestBody Map<String, Object> row) {
        Object target = row.get("tgtDocIdx");
        Long tgtDocIdx = target instanceof Number n ? n.longValue() : null;
        service.saveRelation(docIdx, row.get("relType") == null ? "" : String.valueOf(row.get("relType")), tgtDocIdx);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-11
     * 코멘트:
     *   1) 감사자료 목록 API — FE UI 미노출(G-14 동결 유지)
     *   2) 규제·감사 대비로 엔드포인트는 남기고 @Deprecated 만 표시한다
     *   3) tbl_audit_log(audit-log 화면)와는 다른 기능 — 절대 혼동·삭제하지 않는다
     */
    @Deprecated(since = "STEP-20-G14", forRemoval = false)
    @GetMapping("/api/v1/docs/audit-export/list")
    public CommonResponse<List<Map<String, Object>>> auditExport(
            // 기간·상태 필터 — 비어 있을 때(= 전체) SP 조건으로 전달
            @RequestParam(required = false) String fromDt,
            @RequestParam(required = false) String toDt,
            @RequestParam(required = false) String status
    ) {
        return CommonResponse.ok(service.auditExport(fromDt, toDt, status));
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-11
     * 코멘트:
     *   1) 선택 문서 PDF를 단일 또는 zip으로 내려준다 (G-14 동결 · FE 미호출)
     *   2) 감사 대비 경로를 유지하므로 제거하지 않고 @Deprecated 만 단다
     *   3) HWP만 있고 PDF가 없으면 서버에서 export-pdf 후 포함한다
     */
    @Deprecated(since = "STEP-20-G14", forRemoval = false)
    @PostMapping("/api/v1/docs/audit-export/preview-pdf")
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
            throw new com.haccp.common.exception.BizException("미리보기 파일을 읽지 못했습니다.");
        }
    }
}
