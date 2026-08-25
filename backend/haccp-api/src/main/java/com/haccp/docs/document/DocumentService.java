/**
 * DocumentService — 문서 허브·결재·첨부 업무 로직.
 *
 * 개발자: 박승우
 * 일자: 2026-08-06
 * 코멘트:
 *   1) DB형·HWP형 문서의 공통 목록·상세·결재·첨부·버전 조회를 한 서비스로 묶는다
 *   2) 파일은 물리 저장소와 DB 메타를 순서대로 처리하며, 실패 시 남은 물리 파일을 정리한다
 *   3) 결재·파일·삭제는 LoginUserContext의 coCd·userId만 사용하고 감사 로그를 남긴다
 *
 * PIPELINE[HB86] Service
 * PIPELINE[HB83, HB85, HB51] 연관 모듈
 */
package com.haccp.docs.document;

// 역할 — JSON 감사 스냅샷
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
// 역할 — 요청 사용자·접속 IP
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.context.RequestMeta;
// 역할 — 업무 예외·삭제 검증
import com.haccp.common.exception.BizException;
import com.haccp.common.validation.DeleteValidation;
// 역할 — 문서 DTO
import com.haccp.docs.document.dto.DocumentApprovalRequest;
import com.haccp.docs.document.dto.DocumentDeleteItem;
import com.haccp.docs.document.dto.DocumentFileRow;
import com.haccp.docs.document.dto.HwpDocumentSaveRequest;
// 역할 — HWP → PDF CLI
import com.haccp.docs.template.RhwpCliClient;
// 역할 — 파일 경로·크기
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
// 역할 — 컬렉션
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
// 역할 — 트랜잭션·서비스
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;
// 역할 — Multipart 업로드 파일
import org.springframework.web.multipart.MultipartFile;

/** 문서 허브 공통 서비스 */
@Service
@RequiredArgsConstructor
public class DocumentService {

    private final DocumentMapper mapper;
    private final DocumentFileStorage storage;
    private final RhwpCliClient rhwpCliClient;
    private final ObjectMapper objectMapper;
    // CLI 대기 중 DB 커넥션을 붙잡지 않도록 PDF 등록만 짧은 트랜잭션으로 연다
    private final PlatformTransactionManager transactionManager;

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 조건에 맞는 문서함 행을 반환한다
     *   2) document-inbox 문서함·관련 문서 선택 팝업에서 호출한다
     *   3) 성공 시 DB형·HWP형이 섞인 목록, 실패 시 SQL 업무 오류
     */
    public List<Map<String, Object>> list(
            // 기준일 시작 YYYYMMDD — 공백이면 전체
            String fromDt,
            // 기준일 종료 YYYYMMDD — 공백이면 전체
            String toDt,
            // 템플릿 코드 — 공백이면 전체
            String tmplCd,
            // 문서 상태 — 공백이면 전체
            String status,
            // 문서번호·제목 검색어 — 공백이면 전체
            String keyword,
            // 작성자 ID — 공백이면 전체
            String writerId
    ) {
        return mapper.selectDocuments(
                LoginUserContext.coCd(),
                text(fromDt),
                text(toDt),
                text(tmplCd),
                text(status),
                text(keyword),
                text(writerId)
        ).stream().map(this::camelMap).toList();
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 결재함 — 현재 사용자 차례의 REQ/REV 대기 문서만 반환한다
     *   2) approval-inbox 화면에서 호출한다
     *   3) 성공 시 목록 배열
     */
    public List<Map<String, Object>> approvalInbox(String fromDt, String toDt, String keyword) {
        return mapper.selectApprovalInbox(
                LoginUserContext.coCd(),
                LoginUserContext.userId(),
                text(fromDt),
                text(toDt),
                text(keyword)
        ).stream().map(this::camelMap).toList();
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 결재 이력 — 내가 승인·반려한 문서를 반환한다
     *   2) approval-history 화면에서 호출한다
     *   3) 성공 시 목록 배열
     */
    public List<Map<String, Object>> approvalHistory(String fromDt, String toDt, String keyword) {
        return mapper.selectApprovalHistory(
                LoginUserContext.coCd(),
                LoginUserContext.userId(),
                text(fromDt),
                text(toDt),
                text(keyword)
        ).stream().map(this::camelMap).toList();
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 문서 공통 헤더·결재·파일·버전을 한 응답으로 조립한다
     *   2) 문서함 행 클릭·결재함 상세·양식 공통 패널에서 호출한다
     *   3) 없는 문서는 BizException, 파일 물리 경로는 응답에서 제거한다
     */
    public Map<String, Object> detail(
            // 문서 대리키
            Long docIdx
    ) {
        Long requiredDocIdx = DeleteValidation.requirePositive(docIdx, "문서번호가 올바르지 않습니다.");
        String coCd = LoginUserContext.coCd();
        Map<String, Object> header = mapper.selectDocument(coCd, requiredDocIdx);
        if (header == null) {
            throw new BizException("문서를 찾을 수 없습니다.");
        }

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("header", camelMap(header));
        out.put("approvals", mapper.selectApprovals(coCd, requiredDocIdx).stream().map(this::camelMap).toList());
        out.put("files", publicFiles(mapper.selectFiles(coCd, requiredDocIdx)));
        out.put("versions", mapper.selectVersions(coCd, requiredDocIdx).stream().map(this::camelMap).toList());
        return out;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) rhwp 문서형의 공통 헤더를 신규 또는 수정 저장한다
     *   2) 문서 작성 화면이 HWPX 원본 업로드 전에 먼저 호출한다
     *   3) 성공 시 docIdx, 실패 시 템플릿·작성자·상태 검증 업무 오류
     */
    @Transactional
    public Long saveHwpDocument(
            // HWP 문서형 헤더 입력
            HwpDocumentSaveRequest req,
            // 감사 로그용 요청 IP
            RequestMeta requestMeta
    ) {
        String coCd = LoginUserContext.coCd();
        Map<String, Object> before = req.getDocIdx() == null || req.getDocIdx() <= 0
                ? null
                : mapper.selectDocument(coCd, req.getDocIdx());
        Long docIdx = mapper.saveHwpDocument(
                coCd,
                req.getDocIdx(),
                text(req.getTmplCd()),
                text(req.getBaseDt()),
                text(req.getBaseDtTo()),
                text(req.getTitle()),
                LoginUserContext.userId()
        );
        if (docIdx == null || docIdx <= 0) {
            throw new BizException("문서를 저장하지 못했습니다.");
        }
        audit(
                "tbl_document",
                docIdx,
                before == null ? "I" : "U",
                before,
                mapper.selectDocument(coCd, docIdx),
                null,
                requestMeta
        );
        return docIdx;
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 파일을 물리 볼륨에 저장한 뒤 문서 파일 메타를 등록한다
     *   2) HWP_SRC는 문서당 1건만 유지 — 기존 원본 메타·물리를 제거한 뒤 등록한다
     *   3) ATTACH/PHOTO/PDF는 추가 등록, DB 실패 시 방금 만든 물리 파일을 롤백한다
     */
    @Transactional
    public Map<String, Object> upload(
            // 연결 문서 idx
            Long docIdx,
            // 파일 분류 HWP_SRC/PDF/ATTACH/PHOTO
            String fileKind,
            // 업로드 파일
            MultipartFile file,
            // 감사 로그용 요청 IP
            RequestMeta requestMeta
    ) {
        Long requiredDocIdx = DeleteValidation.requirePositive(docIdx, "문서번호가 올바르지 않습니다.");
        String kind = requireFileKind(fileKind);
        String coCd = LoginUserContext.coCd();
        String userId = LoginUserContext.userId();
        // HWP 본원본일 때(= 문서당 1건) 기존 HWP_SRC를 먼저 제거
        if ("HWP_SRC".equals(kind)) {
            replaceExistingHwpSrc(coCd, requiredDocIdx, userId, requestMeta);
        }
        String path = storage.save(coCd, documentTmplCd(coCd, requiredDocIdx), file);
        try {
            Long fileIdx = mapper.insertFile(
                    coCd,
                    requiredDocIdx,
                    kind,
                    safeOriginalName(file.getOriginalFilename()),
                    path,
                    file.getSize(),
                    text(file.getContentType()),
                    userId
            );
            audit(
                    "tbl_document_file",
                    fileIdx,
                    "I",
                    null,
                    Map.of("docIdx", requiredDocIdx, "fileKind", kind, "fileNm", safeOriginalName(file.getOriginalFilename())),
                    null,
                    requestMeta
            );
            DocumentFileRow saved = mapper.selectFile(coCd, fileIdx);
            return publicFile(saved);
        } catch (RuntimeException e) {
            // DB 메타 등록이 실패했을 때(= 결재 잠금·SQL 오류) 물리 파일 롤백
            try {
                storage.delete(path);
            } catch (RuntimeException ignored) {
                // 원래 업무 오류를 우선하고, 고아 파일은 운영 정리 대상이다
            }
            throw e;
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 문서에 남은 HWP_SRC 물리 경로를 모은 뒤 메타를 종류별 일괄 삭제한다
     *   2) upload(HWP_SRC) 직전에 호출해 원본 1건만 남긴다 — 재저장 시 목록이 쌓이지 않는다
     *   3) ATTACH/PDF는 건드리지 않는다
     */
    private void replaceExistingHwpSrc(
            // JWT 회사코드
            String coCd,
            // 대상 문서 idx
            Long docIdx,
            // 삭제 감사 userId
            String userId,
            // 감사 로그용 요청 IP
            RequestMeta requestMeta
    ) {
        List<DocumentFileRow> oldSrc = mapper.selectFiles(coCd, docIdx).stream()
                .filter(row -> "HWP_SRC".equalsIgnoreCase(text(row.getFileKind())))
                .toList();
        // 기존 원본이 없을 때(= 첫 저장)
        if (oldSrc.isEmpty()) {
            return;
        }
        // 물리 파일 경로 — 메타 삭제 전에 모아 둔다
        List<String> paths = oldSrc.stream()
                .map(DocumentFileRow::getFilePath)
                .filter(path -> path != null && !path.isBlank())
                .toList();
        for (DocumentFileRow old : oldSrc) {
            audit("tbl_document_file", old.getIdx(), "D", publicFile(old), null, null, requestMeta);
        }
        // 종류별 일괄 삭제 — 결재 잠금이면 SP가 BizException
        mapper.deleteFilesByKind(coCd, docIdx, "HWP_SRC", userId);
        for (String path : paths) {
            try {
                storage.delete(path);
            } catch (RuntimeException ignored) {
                // 메타는 지웠고 물리만 남으면 운영 정리 대상 — 업로드는 계속
            }
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 문서의 최신 HWP_SRC를 rhwp CLI로 PDF로 변환한 뒤 file_kind=PDF로 보관한다
     *   2) hwp-document-editor의 서버 PDF 내보내기 버튼이 호출한다
     *   3) 성공 시 물리 경로를 제외한 파일 메타, 원본 없음·CLI 실패는 BizException
     */
    public Map<String, Object> exportPdf(
            // PDF로 내보낼 문서 대리키
            Long docIdx,
            // 감사 로그용 요청 IP
            RequestMeta requestMeta
    ) {
        Long requiredDocIdx = DeleteValidation.requirePositive(docIdx, "문서번호가 올바르지 않습니다.");
        String coCd = LoginUserContext.coCd();
        Map<String, Object> header = mapper.selectDocument(coCd, requiredDocIdx);
        if (header == null) {
            throw new BizException("문서를 찾을 수 없습니다.");
        }
        DocumentFileRow hwpSrc = mapper.selectFiles(coCd, requiredDocIdx).stream()
                .filter(file -> "HWP_SRC".equalsIgnoreCase(text(file.getFileKind())))
                .max(Comparator.comparing(DocumentFileRow::getIdx, Comparator.nullsFirst(Long::compareTo)))
                .orElse(null);
        if (hwpSrc == null) {
            throw new BizException("PDF로 변환할 HWP 본문이 없습니다. 먼저 HWPX 본문을 저장하세요.");
        }
        Path sourcePath = storage.read(hwpSrc.getFilePath());
        Path generatedPdf = rhwpCliClient.exportPdf(sourcePath);
        try {
            String pdfName = pdfFileName(hwpSrc.getFileNm(), header);
            TransactionTemplate tx = new TransactionTemplate(transactionManager);
            Map<String, Object> saved = tx.execute(status -> registerGeneratedPdf(
                    requiredDocIdx,
                    generatedPdf,
                    pdfName,
                    requestMeta
            ));
            if (saved == null) {
                throw new BizException("PDF를 저장하지 못했습니다.");
            }
            return saved;
        } finally {
            deleteGeneratedQuietly(generatedPdf);
        }
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-11
     * 코멘트:
     *   1) 선택 문서 PDF를 모아 미리보기용 파일을 만든다 (G-14 audit-export 동결)
     *   2) FE UI 미노출 — TaskController preview-pdf 전용 경로로만 남긴다
     *   3) 1건이면 PDF 단일, 2건 이상이면 zip — 기존 PDF 없으면 exportPdf로 생성
     */
    @Deprecated(since = "STEP-20-G14", forRemoval = false)
    public DownloadFile previewAuditPdfs(
            // 선택 문서 복합키 목록 — UI 단건이어도 List
            List<DocumentDeleteItem> keys,
            // 감사 IP — exportPdf 등록 시 사용
            RequestMeta requestMeta
    ) {
        DeleteValidation.requireItems(keys, "미리보기할 문서를 선택하세요.");
        List<Long> docIdxs = new ArrayList<>();
        for (DocumentDeleteItem key : keys) {
            docIdxs.add(DeleteValidation.requirePositive(
                    key == null ? null : key.getDocIdx(), "문서번호가 올바르지 않습니다."));
        }
        List<Path> pdfPaths = new ArrayList<>();
        List<String> pdfNames = new ArrayList<>();
        try {
            for (Long docIdx : docIdxs) {
                Path pdf = resolveOrExportPdf(docIdx, requestMeta);
                pdfPaths.add(pdf);
                Map<String, Object> header = mapper.selectDocument(LoginUserContext.coCd(), docIdx);
                Object docNo = header == null ? null : header.get("doc_no");
                if (docNo == null && header != null) docNo = header.get("docNo");
                String name = (docNo == null ? ("doc-" + docIdx) : String.valueOf(docNo)) + ".pdf";
                pdfNames.add(safeOriginalName(name));
            }
            if (pdfPaths.size() == 1) {
                return new DownloadFile(pdfNames.get(0), "application/pdf", pdfPaths.get(0));
            }
            Path zip = Files.createTempFile("audit-pdf-", ".zip");
            try (java.util.zip.ZipOutputStream zos = new java.util.zip.ZipOutputStream(
                    Files.newOutputStream(zip))) {
                for (int i = 0; i < pdfPaths.size(); i++) {
                    java.util.zip.ZipEntry entry = new java.util.zip.ZipEntry(pdfNames.get(i));
                    zos.putNextEntry(entry);
                    Files.copy(pdfPaths.get(i), zos);
                    zos.closeEntry();
                }
            }
            return new DownloadFile("audit-export.zip", "application/zip", zip);
        } catch (IOException e) {
            throw new BizException("감사 PDF 미리보기를 만들지 못했습니다.");
        }
    }

    /**
     * 문서에 등록된 최신 PDF를 쓰고, 없으면 HWP_SRC를 exportPdf한 뒤 다시 읽는다.
     */
    private Path resolveOrExportPdf(Long docIdx, RequestMeta requestMeta) {
        String coCd = LoginUserContext.coCd();
        DocumentFileRow pdf = mapper.selectFiles(coCd, docIdx).stream()
                .filter(file -> "PDF".equalsIgnoreCase(text(file.getFileKind())))
                .max(Comparator.comparing(DocumentFileRow::getIdx, Comparator.nullsFirst(Long::compareTo)))
                .orElse(null);
        if (pdf != null) {
            return storage.read(pdf.getFilePath());
        }
        Map<String, Object> exported = exportPdf(docIdx, requestMeta);
        Object idxObj = exported.get("idx");
        Long fileIdx = idxObj instanceof Number n ? n.longValue() : null;
        if (fileIdx == null) {
            throw new BizException("PDF를 준비하지 못했습니다. 문서번호 " + docIdx);
        }
        DocumentFileRow saved = mapper.selectFile(coCd, fileIdx);
        if (saved == null) {
            throw new BizException("PDF를 준비하지 못했습니다. 문서번호 " + docIdx);
        }
        return storage.read(saved.getFilePath());
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 파일 다운로드에 필요한 파일명·MIME·Path를 테넌트 범위로 반환한다
     *   2) Controller가 Content-Disposition 응답을 만들 때 호출한다
     *   3) 없거나 다른 회사 파일이면 BizException
     */
    public DownloadFile download(
            // 파일 대리키
            Long fileIdx
    ) {
        Long requiredFileIdx = DeleteValidation.requirePositive(fileIdx, "파일번호가 올바르지 않습니다.");
        DocumentFileRow file = mapper.selectFile(LoginUserContext.coCd(), requiredFileIdx);
        if (file == null) {
            throw new BizException("파일을 찾을 수 없습니다.");
        }
        Path path = storage.read(file.getFilePath());
        return new DownloadFile(file.getFileNm(), file.getMimeType(), path);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) DB 메타 잠금 검증 뒤 파일 메타·물리 파일을 제거한다
     *   2) 첨부 삭제 버튼의 validate-delete 이후 호출한다
     *   3) 결재 잠금이면 SP가 차단하고 물리 파일은 그대로 유지한다
     */
    @Transactional
    public void deleteFile(
            // 파일 대리키
            Long fileIdx,
            // 감사 로그용 요청 IP
            RequestMeta requestMeta
    ) {
        Long requiredFileIdx = DeleteValidation.requirePositive(fileIdx, "파일번호가 올바르지 않습니다.");
        String coCd = LoginUserContext.coCd();
        DocumentFileRow file = mapper.selectFile(coCd, requiredFileIdx);
        if (file == null) {
            throw new BizException("파일을 찾을 수 없습니다.");
        }
        mapper.deleteFile(coCd, requiredFileIdx, LoginUserContext.userId());
        storage.delete(file.getFilePath());
        audit("tbl_document_file", requiredFileIdx, "D", publicFile(file), null, null, requestMeta);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 상신·상신취소·검토·승인·반려·결재취소 중 하나를 처리한다
     *   2) 문서 결재 패널의 버튼이 호출한다
     *   3) 성공 시 문서 상태를 갱신하고 APV/RJT 감사 이력을 남긴다
     */
    @Transactional
    public void processApproval(
            // 결재 처리 요청
            DocumentApprovalRequest req,
            // 감사 로그용 요청 IP
            RequestMeta requestMeta
    ) {
        Long docIdx = DeleteValidation.requirePositive(req.getDocIdx(), "문서번호가 올바르지 않습니다.");
        String action = text(req.getActionCd()).toUpperCase();
        if (!List.of("REQUEST", "CANCEL", "REVIEW", "APPROVE", "REJECT", "UNDO").contains(action)) {
            throw new BizException("결재 처리 구분이 올바르지 않습니다.");
        }
        String coCd = LoginUserContext.coCd();
        Map<String, Object> before = mapper.selectDocument(coCd, docIdx);
        if (before == null) {
            throw new BizException("문서를 찾을 수 없습니다.");
        }
        // 결재취소는 되돌리기 규칙이 달라 전용 SP 를 탄다 — 전이 SP 는 손대지 않는다
        if ("UNDO".equals(action)) {
            mapper.undoApproval(coCd, docIdx, LoginUserContext.userId());
        } else {
            mapper.processApproval(coCd, docIdx, action, text(req.getOpinion()), LoginUserContext.userId());
        }
        Map<String, Object> after = mapper.selectDocument(coCd, docIdx);
        audit(
                "tbl_document",
                docIdx,
                switch (action) {
                    case "APPROVE" -> "APV";
                    case "REJECT" -> "RJT";
                    default -> "U";
                },
                before,
                after,
                // 반려 사유·결재취소 사유를 감사 이력 메모로 남긴다
                action.equals("REJECT") || action.equals("UNDO") ? text(req.getOpinion()) : null,
                requestMeta
        );
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-25
     * 코멘트:
     *   1) 문서 비고를 저장한다 — 첨부와 달리 결재 완료(APV) 직전까지 고칠 수 있다
     *   2) 결재 첨부(attach) 화면의 비고 저장 버튼이 호출한다
     *   3) 작성자 본인·잠금 검증은 SP가 하고, 여기서는 감사 이력만 남긴다
     */
    @Transactional
    public void saveRemark(
            // 문서 대리키
            Long docIdx,
            // 비고 본문 — null·빈 문자열이면 지운다
            String remark,
            // 감사 로그용 요청 IP
            RequestMeta requestMeta
    ) {
        Long requiredDocIdx = DeleteValidation.requirePositive(docIdx, "문서번호가 올바르지 않습니다.");
        String coCd = LoginUserContext.coCd();
        Map<String, Object> before = mapper.selectDocument(coCd, requiredDocIdx);
        if (before == null) {
            throw new BizException("문서를 찾을 수 없습니다.");
        }
        mapper.saveRemark(coCd, requiredDocIdx, text(remark), LoginUserContext.userId());
        audit("tbl_document", requiredDocIdx, "U", before, mapper.selectDocument(coCd, requiredDocIdx), null, requestMeta);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 문서형(HWP) 임시·반려 문서 삭제 가능 여부를 검사한다
     *   2) FE confirm 전에 호출하고 delete에서도 다시 호출한다
     *   3) DB형 문서는 도메인 전용 삭제 API로만 처리하게 차단한다
     */
    public void validateDelete(
            // 삭제 키 객체 배열
            List<DocumentDeleteItem> keys
    ) {
        assertDeletable(LoginUserContext.coCd(), keys);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-06
     * 코멘트:
     *   1) 문서형(HWP) 임시·반려 문서와 그 첨부 물리 파일을 삭제한다
     *   2) validateDelete와 같은 Double Check 뒤 키별 SP를 호출한다
     *   3) 성공 시 void, 실패하면 트랜잭션을 롤백한다
     */
    @Transactional
    public void delete(
            // 삭제 키 객체 배열
            List<DocumentDeleteItem> keys,
            // 감사 로그용 요청 IP
            RequestMeta requestMeta
    ) {
        String coCd = LoginUserContext.coCd();
        assertDeletable(coCd, keys);
        for (DocumentDeleteItem key : keys) {
            Map<String, Object> header = camelMap(mapper.selectDocument(coCd, key.getDocIdx()));
            // docKind 정본은 소문자 hwp/html — 과거 대문자(HWP) 잔존값도 같게 본다
            if (!"hwp".equalsIgnoreCase(String.valueOf(header.get("docKind")))) {
                throw new BizException("DB형 문서는 해당 양식 화면에서 삭제하세요.");
            }
            List<DocumentFileRow> files = mapper.selectFiles(coCd, key.getDocIdx());
            mapper.deleteDocument(coCd, key.getDocIdx(), LoginUserContext.userId());
            for (DocumentFileRow file : files) {
                storage.delete(file.getFilePath());
            }
            audit("tbl_document", key.getDocIdx(), "D", header, null, null, requestMeta);
        }
    }

    /** 삭제 대상 정규화·전송·결재완료 차단 — 보존기간은 초안 삭제 자물쇠가 아니다 */
    private void assertDeletable(String coCd, List<DocumentDeleteItem> keys) {
        DeleteValidation.requireItems(keys, "삭제할 문서를 선택하세요.");
        List<Long> docIdxs = new ArrayList<>();
        for (DocumentDeleteItem key : keys) {
            Long docIdx = DeleteValidation.requirePositive(key.getDocIdx(), "삭제할 문서번호가 올바르지 않습니다.");
            key.setDocIdx(docIdx);
            docIdxs.add(docIdx);
        }
        DeleteValidation.throwIfBlocked(mapper.selectDocumentDeleteBlocker(coCd, docIdxs), "문서");
    }

    /** CLI가 만든 PDF를 볼륨·DB·감사 로그에 등록하고 API 메타를 반환한다 */
    private Map<String, Object> registerGeneratedPdf(
            // 연결 문서 idx
            Long docIdx,
            // rhwp가 만든 임시 PDF
            Path generatedPdf,
            // 목록·다운로드용 파일명
            String pdfName,
            // 감사 IP
            RequestMeta requestMeta
    ) {
        String coCd = LoginUserContext.coCd();
        String userId = LoginUserContext.userId();
        long size;
        try {
            size = Files.size(generatedPdf);
        } catch (IOException e) {
            throw new BizException("변환된 PDF를 읽지 못했습니다.");
        }
        String path = storage.saveFromPath(coCd, documentTmplCd(coCd, docIdx), generatedPdf, pdfName);
        try {
            Long fileIdx = mapper.insertFile(
                    coCd,
                    docIdx,
                    "PDF",
                    pdfName,
                    path,
                    size,
                    "application/pdf",
                    userId
            );
            audit(
                    "tbl_document_file",
                    fileIdx,
                    "I",
                    null,
                    Map.of("docIdx", docIdx, "fileKind", "PDF", "fileNm", pdfName),
                    null,
                    requestMeta
            );
            return publicFile(mapper.selectFile(coCd, fileIdx));
        } catch (RuntimeException e) {
            // DB 메타 등록 실패 시(= 결재 잠금·SQL 오류) 방금 복사한 물리 PDF를 되돌린다
            try {
                storage.delete(path);
            } catch (RuntimeException ignored) {
                // 원래 업무 오류를 우선한다
            }
            throw e;
        }
    }

    /** HWP_SRC 파일명 또는 문서번호를 바탕으로 PDF 표시 파일명을 만든다 */
    private String pdfFileName(String sourceName, Map<String, Object> header) {
        String base = text(sourceName);
        if (base.toLowerCase().endsWith(".hwpx") || base.toLowerCase().endsWith(".hwp")) {
            int dot = base.lastIndexOf('.');
            base = base.substring(0, dot);
        }
        if (base.isBlank()) {
            Object docNo = header.get("doc_no");
            if (docNo == null) docNo = header.get("docNo");
            base = docNo == null ? "document" : String.valueOf(docNo);
        }
        return safeOriginalName(base + ".pdf");
    }

    /** rhwp 임시 PDF와 부모 폴더를 남기지 않는다 */
    private void deleteGeneratedQuietly(Path generatedPdf) {
        if (generatedPdf == null) return;
        try {
            Path parent = generatedPdf.getParent();
            Files.deleteIfExists(generatedPdf);
            if (parent != null) {
                Files.deleteIfExists(parent);
            }
        } catch (IOException ignored) {
            // 임시 잔여는 운영 정리 대상이다
        }
    }

    /** 파일 종류의 허용값 검증 */
    private String requireFileKind(String value) {
        String kind = text(value).toUpperCase();
        if (!List.of("HWP_SRC", "PDF", "ATTACH", "PHOTO").contains(kind)) {
            throw new BizException("파일 구분이 올바르지 않습니다.");
        }
        return kind;
    }

    /** 서버 내부 경로·감사 값은 빼고 API용 메타만 만든다 */
    private Map<String, Object> publicFile(DocumentFileRow file) {
        if (file == null) {
            throw new BizException("파일을 찾을 수 없습니다.");
        }
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("idx", file.getIdx());
        out.put("docIdx", file.getDocIdx());
        out.put("fileKind", file.getFileKind());
        out.put("fileNm", file.getFileNm());
        out.put("fileSize", file.getFileSize());
        out.put("mimeType", file.getMimeType());
        out.put("sortNo", file.getSortNo());
        out.put("insId", file.getInsId());
        out.put("insDt", file.getInsDt());
        return out;
    }

    /** 파일 목록을 API 노출 형태로 바꾼다 */
    private List<Map<String, Object>> publicFiles(List<DocumentFileRow> files) {
        return files.stream().map(this::publicFile).toList();
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-13
     * 코멘트:
     *   1) 문서 헤더에서 양식코드(tmplCd)만 읽어 저장 경로의 타입 폴더로 쓴다
     *   2) 첨부 업로드·PDF 등록이 물리 파일을 만들기 직전에 호출한다
     *   3) 헤더가 없을 때(= 삭제된 문서) 빈 문자열 — 경로는 타입 폴더 없이 조립된다
     */
    private String documentTmplCd(
            // JWT 회사코드
            String coCd,
            // 대상 문서 idx
            Long docIdx
    ) {
        Map<String, Object> header = camelMap(mapper.selectDocument(coCd, docIdx));
        return header == null ? "" : text(String.valueOf(header.getOrDefault("tmplCd", "")));
    }

    /** MyBatis Map의 DB lower_snake 키를 API camelCase 키로 한 번만 바꾼다 */
    private Map<String, Object> camelMap(Map<String, Object> source) {
        if (source == null) return null;
        Map<String, Object> out = new LinkedHashMap<>();
        source.forEach((key, value) -> out.put(camelKey(key), value));
        return out;
    }

    /** doc_idx → docIdx. DTO를 쓰지 않는 문서허브 조회 Map의 Two-Tier 경계다 */
    private String camelKey(String key) {
        if (key == null || key.isBlank()) return "";
        // DOC_NO·doc_no 모두 소문자화 후 변환 — 대문자 키면 docNo가 깨져 그리드가 빈다
        if (!key.contains("_")) return key;
        String lower = key.toLowerCase(java.util.Locale.ROOT);
        StringBuilder out = new StringBuilder();
        boolean upper = false;
        for (char ch : lower.toCharArray()) {
            if (ch == '_') {
                upper = true;
            } else if (upper) {
                out.append(Character.toUpperCase(ch));
                upper = false;
            } else {
                out.append(ch);
            }
        }
        return out.toString();
    }

    /** 감사 로그에서 파일 경로는 공개하지 않는다 */
    private Map<String, Object> publicFile(Map<String, Object> file) {
        return file == null ? null : new LinkedHashMap<>(file);
    }

    /** 감사 로그 SP 호출 — 감사 실패가 원 업무를 숨기지 않도록 같은 트랜잭션에서 처리 */
    private void audit(
            String tblNm,
            Long tgtIdx,
            String actionCd,
            Object before,
            Object after,
            String reason,
            RequestMeta requestMeta
    ) {
        mapper.insertAudit(
                LoginUserContext.coCd(),
                LoginUserContext.userId(),
                tblNm,
                tgtIdx,
                actionCd,
                json(before),
                json(after),
                text(reason),
                requestMeta == null ? null : requestMeta.ipAddr()
        );
    }

    /** Object → JSON. 실패하면 감사 이력의 정확성이 깨지므로 업무를 중단한다 */
    private String json(Object value) {
        if (value == null) return "";
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JsonProcessingException e) {
            throw new BizException("감사 자료를 저장 형식으로 변환하지 못했습니다.");
        }
    }

    /** 업로드 원본 파일명 정규화 — 저장소의 파일명 규칙과 맞춘다 */
    private String safeOriginalName(String name) {
        String safe = name == null ? "" : Path.of(name).getFileName().toString();
        safe = safe.replaceAll("[^0-9A-Za-z가-힣._() -]", "_").trim();
        if (safe.isBlank()) throw new BizException("파일명이 올바르지 않습니다.");
        return safe;
    }

    /** null → 공백·trim 공통화 */
    private String text(String value) {
        return value == null ? "" : value.trim();
    }

    /** 다운로드 응답에 필요한 서버 전용 값 */
    public record DownloadFile(String fileNm, String mimeType, Path path) {}
}
