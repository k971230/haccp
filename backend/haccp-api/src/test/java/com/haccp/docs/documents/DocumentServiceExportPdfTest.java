/**
 * DocumentServiceExportPdfTest — 문서함 HWP 인쇄용 PDF 재사용.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 결재완료 문서는 본문을 안 바꾸고 이미 있는 PDF 완료본을 돌려준다
 *   2) 다시 변환하면 SP 잠금 오류가 났었다 — 재사용 분기를 고정한다
 *   3) DB 없이 매퍼만 가짜로 세운다
 *
 * PIPELINE[HB86] Service
 */
package com.haccp.docs.documents;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.haccp.common.context.LoginUser;
import com.haccp.common.context.LoginUserContext;
import com.haccp.docs.documents.dto.DocumentFileRow;
import com.haccp.docs.documents.dto.DocumentHeaderRow;
import com.haccp.docs.templates.RhwpCliClient;
import com.haccp.sys.logs.auditlog.AuditWriter;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.transaction.PlatformTransactionManager;

@ExtendWith(MockitoExtension.class)
class DocumentServiceExportPdfTest {

    @Mock
    private DocumentMapper mapper;

    @Mock
    private DocumentFileStorage storage;

    @Mock
    private RhwpCliClient rhwpCliClient;

    @Mock
    private AuditWriter auditWriter;

    @Mock
    private PlatformTransactionManager transactionManager;

    @InjectMocks
    private DocumentService service;

    @BeforeEach
    void setUser() {
        LoginUserContext.set(LoginUser.builder()
                .coCd("0000")
                .userId("admin")
                .build());
    }

    @AfterEach
    void clearUser() {
        LoginUserContext.clear();
    }

    @Test
    void 결재완료에_PDF가_있으면_변환하지_않는다() {
        DocumentHeaderRow header = new DocumentHeaderRow();
        header.setStatus("APV");
        when(mapper.selectDocument("0000", 1L)).thenReturn(header);
        DocumentFileRow pdf = new DocumentFileRow();
        pdf.setIdx(9L);
        pdf.setDocIdx(1L);
        pdf.setFileKind("PDF");
        pdf.setFileNm("done.pdf");
        when(mapper.selectFiles("0000", 1L)).thenReturn(List.of(pdf));

        DocumentFileRow out = service.exportPdf(1L, null);

        assertEquals(9L, out.getIdx());
        assertEquals("PDF", out.getFileKind());
        verify(rhwpCliClient, never()).exportPdf(any());
    }
}
