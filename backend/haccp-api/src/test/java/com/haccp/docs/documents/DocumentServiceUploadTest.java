/**
 * DocumentServiceUploadTest — HWP 본문 덮어쓰기가 방금 올린 파일을 지우지 않는지.
 *
 * 개발자: 박승우
 * 일자: 2026-09-04
 * 코멘트:
 *   1) 옛 실물 삭제는 커밋 뒤로 미룬다 — 업로드 도중에는 아무것도 안 지운다
 *   2) 옛 경로와 새 경로가 같으면 **지우면 안 된다.** 방금 올린 본문이 사라진다
 *   3) DB 없이 매퍼·저장소를 가짜로 세운다. 트랜잭션 동기화가 없는 상태라 afterCommit 이 안 돈다
 *
 * 시험이 없는 상태에서는 두 사고가 다 조용히 지나간다 —
 * 메타는 롤백으로 되살아나고 실물만 사라지거나, 새 본문이 지워진다.
 *
 * PIPELINE[HB86] Service
 */
package com.haccp.docs.documents;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
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
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class DocumentServiceUploadTest {

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
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.clearSynchronization();
        }
    }

    /** 이미 본문이 하나 있는 문서 */
    private void givenExistingSource(String oldPath) {
        DocumentFileRow old = new DocumentFileRow();
        old.setIdx(7L);
        old.setDocIdx(1L);
        old.setFileKind("HWP_SRC");
        old.setFileNm("old.hwpx");
        old.setFilePath(oldPath);
        when(mapper.selectFiles("0000", 1L)).thenReturn(List.of(old));
        DocumentHeaderRow header = new DocumentHeaderRow();
        header.setTmplCd("hwp_sys_001");
        when(mapper.selectDocument("0000", 1L)).thenReturn(header);
        when(mapper.insertFile(anyString(), anyLong(), anyString(), anyString(), anyString(),
                anyLong(), anyString(), anyString())).thenReturn(11L);
        DocumentFileRow saved = new DocumentFileRow();
        saved.setIdx(11L);
        saved.setDocIdx(1L);
        saved.setFileKind("HWP_SRC");
        when(mapper.selectFile("0000", 11L)).thenReturn(saved);
    }

    private MockMultipartFile hwpx() {
        return new MockMultipartFile("file", "본문.hwpx", "application/vnd.hancom.hwpx", new byte[] { 1, 2 });
    }

    @Test
    void 경로가_다르면_옛_실물을_지운다() {
        // 정리는 계속 돼야 한다 — 미루는 것이지 안 하는 것이 아니다
        String old = "HaccpLogBooks/0000/hwp_sys_001/20260904/old_001.hwpx";
        String neu = "HaccpLogBooks/0000/hwp_sys_001/20260904/new_002.hwpx";
        givenExistingSource(old);
        when(storage.save(anyString(), anyString(), any())).thenReturn(neu);

        service.upload(1L, "HWP_SRC", hwpx(), null);

        verify(storage).delete(old);
        verify(storage, never()).delete(neu);
    }

    @Test
    void 트랜잭션_안에서는_커밋_전에_안_지운다() {
        /*
         * 이 시험이 이 커밋의 알맹이다.
         *
         * 앞 두 건은 동기화가 없는 상태라 deleteAfterCommit 이 즉시 지운다 —
         * 그래서 **미룬다는 것 자체**는 안 태워진다. 여기서 동기화를 켜고
         * 커밋 전에는 안 지우는지, 커밋 뒤에야 지우는지를 나눠 본다.
         */
        String old = "HaccpLogBooks/0000/hwp_sys_001/20260904/old_001.hwpx";
        String neu = "HaccpLogBooks/0000/hwp_sys_001/20260904/new_002.hwpx";
        givenExistingSource(old);
        when(storage.save(anyString(), anyString(), any())).thenReturn(neu);
        TransactionSynchronizationManager.initSynchronization();

        service.upload(1L, "HWP_SRC", hwpx(), null);

        // 아직 커밋 전 — 메타가 롤백되면 실물도 남아 있어야 한다
        verify(storage, never()).delete(old);

        for (TransactionSynchronization sync : TransactionSynchronizationManager.getSynchronizations()) {
            sync.afterCommit();
        }
        verify(storage).delete(old);
    }

    @Test
    void 옛_경로와_새_경로가_같으면_지우지_않는다() {
        // 메타는 있는데 실물이 이미 없는 행이면 새 저장이 같은 _001 을 다시 집는다.
        // 그때 옛 경로를 지우면 **방금 올린 본문이 사라진다**
        String same = "HaccpLogBooks/0000/hwp_sys_001/20260904/본문_001.hwpx";
        givenExistingSource(same);
        when(storage.save(anyString(), anyString(), any())).thenReturn(same);

        service.upload(1L, "HWP_SRC", hwpx(), null);

        verify(storage, never()).delete(eq(same));
    }
}
