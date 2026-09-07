/**
 * DocumentServiceApprovalTest — 결재 처리 전이.
 *
 * 개발자: 박승우
 * 일자: 2026-08-27
 * 코멘트:
 *   1) 문서 상태를 옮기는 유일한 문이다 — 여기가 무르면 결재선이 통째로 무너진다
 *   2) 결재취소(UNDO)만 다른 SP 를 탄다. 그 갈림길을 고정한다 —
 *      섞이면 취소가 승인으로 처리되거나 그 반대가 된다
 *   3) DB 없이 매퍼를 가짜로 세워 서비스 판단만 본다
 *
 * PIPELINE[HB60] 문서 결재 업무 서비스
 */
package com.haccp.docs.documents;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.haccp.common.exception.BizException;
import com.haccp.docs.documents.dto.DocumentApprovalRequest;
import com.haccp.docs.documents.dto.DocumentHeaderRow;
import com.haccp.sys.logs.auditlog.AuditWriter;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class DocumentServiceApprovalTest {

    @Mock
    private DocumentMapper mapper;

    @Mock
    private AuditWriter auditWriter;

    @InjectMocks
    private DocumentService service;

    private static DocumentApprovalRequest req(Long docIdx, String action, String opinion) {
        DocumentApprovalRequest r = new DocumentApprovalRequest();
        r.setDocIdx(docIdx);
        r.setActionCd(action);
        r.setOpinion(opinion);
        return r;
    }

    /** SP 가 돌려주는 문서 한 건 */
    private static DocumentHeaderRow doc(String status) {
        DocumentHeaderRow row = new DocumentHeaderRow();
        row.setDocIdx(448L);
        row.setStatus(status);
        return row;
    }

    /** 문서가 있는 상태로 세운다 */
    private void docExists(String status) {
        when(mapper.selectDocument(any(), any())).thenReturn(doc(status));
    }

    // ---------------------------------------------------------------- 막는 것

    @Test
    void 지원하지_않는_행위는_막는다() {
        // 새 코드가 오타로 들어오면 SP 까지 내려보내면 안 된다
        docExists("WRK");
        BizException e = assertThrows(
                BizException.class, () -> service.processApproval(req(448L, "DELETE_ALL", null), null));
        assertEquals("결재 처리 구분이 올바르지 않습니다.", e.getMessage());
        verify(mapper, never()).processApproval(any(), any(), any(), any(), any());
        verify(mapper, never()).undoApproval(any(), any(), any(), any());
    }

    @Test
    void 문서번호가_없거나_0_이하면_막는다() {
        assertThrows(BizException.class, () -> service.processApproval(req(null, "APPROVE", null), null));
        assertThrows(BizException.class, () -> service.processApproval(req(0L, "APPROVE", null), null));
        verify(mapper, never()).processApproval(any(), any(), any(), any(), any());
    }

    @Test
    void 없는_문서는_막는다() {
        when(mapper.selectDocument(any(), any())).thenReturn(null);
        BizException e = assertThrows(
                BizException.class, () -> service.processApproval(req(999L, "APPROVE", null), null));
        assertEquals("문서를 찾을 수 없습니다.", e.getMessage());
        verify(mapper, never()).processApproval(any(), any(), any(), any(), any());
    }

    // ---------------------------------------------------------------- 갈림길

    @Test
    void 결재취소만_전용_SP_를_탄다() {
        // 섞이면 취소가 전이 SP 를 타 상태가 엉뚱하게 움직인다
        docExists("APV");

        service.processApproval(req(448L, "UNDO", "잘못 승인함"), null);

        verify(mapper, times(1)).undoApproval(any(), eq(448L), any(), eq("잘못 승인함"));
        verify(mapper, never()).processApproval(any(), any(), any(), any(), any());
    }

    @Test
    void 취소가_아닌_행위는_전이_SP_를_탄다() {
        docExists("REQ");

        service.processApproval(req(448L, "APPROVE", null), null);

        verify(mapper, times(1)).processApproval(any(), eq(448L), eq("APPROVE"), any(), any());
        verify(mapper, never()).undoApproval(any(), any(), any(), any());
    }

    @Test
    void 소문자로_와도_같은_행위로_본다() {
        // 화면이 소문자로 보내도 SP 에는 대문자로 가야 한다
        docExists("REQ");

        service.processApproval(req(448L, "approve", null), null);

        verify(mapper, times(1)).processApproval(any(), any(), eq("APPROVE"), any(), any());
    }

    // ---------------------------------------------------------------- 감사 기록

    @Test
    void 승인은_APV_로_반려는_RJT_로_남긴다() {
        // 감사 이력에서 승인과 반려가 구분돼야 한다 — 둘 다 U 면 나중에 못 가린다
        docExists("REQ");

        service.processApproval(req(448L, "APPROVE", null), null);
        verify(auditWriter, times(1)).record(eq("tbl_document"), eq(448L), eq("APV"),
                any(), any(), any());

        service.processApproval(req(448L, "REJECT", "값이 비었음"), null);
        verify(auditWriter, times(1)).record(eq("tbl_document"), eq(448L), eq("RJT"),
                any(), any(), any());
    }

    @Test
    void 반려_사유는_감사_메모로_남는다() {
        // 사유가 안 남으면 왜 돌아왔는지 나중에 못 본다
        docExists("REQ");

        service.processApproval(req(448L, "REJECT", "온도 미기재"), null);

        verify(auditWriter, times(1)).record(eq("tbl_document"), any(), eq("RJT"),
                any(), any(), eq("온도 미기재"));
    }

    @Test
    void 전송은_사유를_메모로_남기지_않는다() {
        // REQUEST 에는 사유가 없다. 화면이 값을 실어 보내도 메모로 새면 안 된다 —
        // 반려·취소 사유만 남아야 감사 이력에서 「왜 돌아왔나」를 가릴 수 있다.
        // audit() 이 text(null) 로 빈 문자열을 넘기므로 "" 를 기대한다
        docExists("WRK");

        service.processApproval(req(448L, "REQUEST", "무시될 값"), null);

        verify(auditWriter, times(1)).record(eq("tbl_document"), any(), eq("REQ"),
                any(), any(), eq(""));
    }
}
