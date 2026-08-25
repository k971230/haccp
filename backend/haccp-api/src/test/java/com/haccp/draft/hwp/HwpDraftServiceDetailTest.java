/**
 * HwpDraftServiceDetailTest — HWP 작성 상세는 html 문서를 거절한다.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) documentService.detail 은 회사코드만 지킨다. 이 화면은 doc_kind=hwp 만 연다
 *   2) HTML 헤더가 오면 BizException 인지 고정한다
 *   3) DB 없이 DocumentService 만 목한다
 *
 * PIPELINE[HB144] HWP 작성 Service
 */
package com.haccp.draft.hwp;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.when;

import com.haccp.common.exception.BizException;
import com.haccp.docs.document.DocumentService;
import java.util.Map;
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

    @InjectMocks
    private HwpDraftService service;

    @Test
    void html_문서는_상세를_거절한다() {
        when(documentService.detail(1L)).thenReturn(Map.of("header", Map.of("docKind", "html")));
        BizException e = assertThrows(BizException.class, () -> service.detail(1L));
        assertEquals("HWP 문서가 아닙니다.", e.getMessage());
    }

    @Test
    void hwp_문서는_헤더를_그대로_돌린다() {
        Map<String, Object> body = Map.of("header", Map.of("docKind", "hwp"));
        when(documentService.detail(2L)).thenReturn(body);
        assertEquals(body, service.detail(2L));
    }
}
