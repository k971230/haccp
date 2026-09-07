/**
 * HwpDraftServiceDetailTest — HWP 작성 상세는 HTML 문서를 거절한다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) documentService.detail 은 회사코드만 지킨다. 이 화면은 doc_kind=HWP 만 연다
 *   2) HTML 헤더가 오면 BizException 인지 고정한다
 *   3) DB 없이 DocumentService 만 목한다
 *
 * PIPELINE[HB144] HWP 작성 Service
 */
package com.haccp.draft.hwpdoc;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.when;

import com.haccp.common.exception.BizException;
import com.haccp.docs.documents.DocumentService;
import com.haccp.docs.documents.dto.DocumentDetailResponse;
import com.haccp.docs.documents.dto.DocumentHeaderRow;
import com.haccp.draft.DraftSeenGuard;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class HwpDraftServiceDetailTest {

    @Mock
    private HwpDraftMapper mapper;

    @Mock
    private DocumentService documentService;

    @Mock
    private DraftSeenGuard seenGuard;

    @InjectMocks
    private HwpDraftService service;

    @Test
    void html_문서는_상세를_거절한다() {
        when(documentService.detail(1L)).thenReturn(detail("HTML"));
        BizException e = assertThrows(BizException.class, () -> service.detail(1L));
        assertEquals("HWP 문서가 아닙니다.", e.getMessage());
    }

    @Test
    void hwp_문서는_헤더를_그대로_돌린다() {
        DocumentDetailResponse body = detail("HWP");
        when(documentService.detail(2L)).thenReturn(body);
        assertEquals(body, service.detail(2L));
    }

    /** 문서 종류만 채운 상세 — 이 시험은 kind 분기만 본다 */
    private static DocumentDetailResponse detail(String docKind) {
        DocumentHeaderRow header = new DocumentHeaderRow();
        header.setDocKind(docKind);
        DocumentDetailResponse out = new DocumentDetailResponse();
        out.setHeader(header);
        return out;
    }
}
