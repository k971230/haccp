/**
 * DocumentServiceDeleteWriterTest — 남의 HWP 초안은 validate-delete에서 막힌다.
 *
 * 개발자: 박승우
 * 일자: 2026-09-09
 * 코멘트:
 *   1) attach 삭제 권한으로 허브 OR를 타도 작성자가 아니면 확인창 전에 거절한다
 *   2) SP 와 같은 문구다. ADMIN·HACCP_MASTER 는 퇴사자 초안을 치울 수 있다
 *   3) DB 없이 매퍼만 가짜로 세운다
 *
 * PIPELINE[HB86] Service
 */
package com.haccp.docs.documents;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.haccp.common.context.LoginUser;
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
import com.haccp.docs.documents.dto.DocumentDeleteItem;
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
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.transaction.PlatformTransactionManager;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class DocumentServiceDeleteWriterTest {

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
                .coCd("0001")
                .userId("user_a")
                .build());
    }

    @AfterEach
    void clearUser() {
        LoginUserContext.clear();
    }

    @Test
    void 남의_초안은_validateDelete에서_막는다() {
        DocumentHeaderRow header = new DocumentHeaderRow();
        header.setDocIdx(9L);
        header.setDocKind("HWP");
        header.setWriterId("user_b");
        when(mapper.selectDocumentDeleteBlocker(eq("0001"), any())).thenReturn(null);
        when(mapper.selectDocument("0001", 9L)).thenReturn(header);

        DocumentDeleteItem key = new DocumentDeleteItem();
        key.setDocIdx(9L);
        BizException ex = assertThrows(BizException.class, () -> service.validateDelete(List.of(key)));
        assertEquals("작성자 본인 또는 관리자만 삭제할 수 있습니다.", ex.getMessage());
        verify(mapper, never()).deleteDocument(any(), any(), any());
    }

    @Test
    void ADMIN은_남의_초안도_validateDelete를_통과한다() {
        LoginUserContext.set(LoginUser.builder()
                .coCd("0001")
                .userId("boss")
                .usrgrpCd("ADMIN")
                .build());
        DocumentHeaderRow header = new DocumentHeaderRow();
        header.setDocIdx(9L);
        header.setDocKind("HWP");
        header.setWriterId("user_b");
        when(mapper.selectDocumentDeleteBlocker(eq("0001"), any())).thenReturn(null);
        when(mapper.selectDocument("0001", 9L)).thenReturn(header);

        DocumentDeleteItem key = new DocumentDeleteItem();
        key.setDocIdx(9L);
        service.validateDelete(List.of(key));
    }

    @Test
    void HACCP_MASTER는_남의_초안도_validateDelete를_통과한다() {
        LoginUserContext.set(LoginUser.builder()
                .coCd("0001")
                .userId("master")
                .usrgrpCd("HACCP_MASTER")
                .build());
        DocumentHeaderRow header = new DocumentHeaderRow();
        header.setDocIdx(9L);
        header.setDocKind("HWP");
        header.setWriterId("user_b");
        when(mapper.selectDocumentDeleteBlocker(eq("0001"), any())).thenReturn(null);
        when(mapper.selectDocument("0001", 9L)).thenReturn(header);

        DocumentDeleteItem key = new DocumentDeleteItem();
        key.setDocIdx(9L);
        service.validateDelete(List.of(key));
    }

    @Test
    void 본인_초안은_validateDelete를_통과한다() {
        DocumentHeaderRow header = new DocumentHeaderRow();
        header.setDocIdx(9L);
        header.setDocKind("HWP");
        header.setWriterId("user_a");
        when(mapper.selectDocumentDeleteBlocker(eq("0001"), any())).thenReturn(null);
        when(mapper.selectDocument("0001", 9L)).thenReturn(header);

        DocumentDeleteItem key = new DocumentDeleteItem();
        key.setDocIdx(9L);
        service.validateDelete(List.of(key));
    }
}
