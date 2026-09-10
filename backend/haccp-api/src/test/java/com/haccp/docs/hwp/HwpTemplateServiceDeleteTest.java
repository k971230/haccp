/**
 * HwpTemplateServiceDeleteTest — 사용양식 삭제.
 *
 * 개발자: 박승우
 * 일자: 2026-09-10
 * 코멘트:
 *   1) 이 경로는 **한 번도 동작한 적이 없었다** — FE 가 부르던 URL 을 서빙하는
 *      컨트롤러가 없어 500 이 났고, 2026-08-26 에 되살렸다 (E2E-008)
 *   2) 그때 시험이 「시스템 양식은 안 지워진다」만 봐서 기능이 죽어도 통과했다.
 *      여기서는 **되는 것과 막는 것을 같이** 본다
 *   3) DB 없이 매퍼를 가짜로 세워 서비스 판단만 본다
 *   4) 실물은 커밋 뒤에만 지운다 — 트랜잭션 안에서는 저장소를 안 부른다
 *
 * PIPELINE[HB123] 사용양식 업무 서비스
 */
package com.haccp.docs.hwp;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.haccp.common.context.LoginUser;
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
import com.haccp.common.validation.DeleteBlocker;
import com.haccp.docs.hwp.dto.HwpTemplateDeleteItem;
import com.haccp.docs.hwp.dto.HwpTemplateSaveRow;
import com.haccp.docs.templates.TemplateFileStorage;
import com.haccp.sys.logs.auditlog.AuditWriter;
import java.util.ArrayList;
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
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class HwpTemplateServiceDeleteTest {

    @Mock
    private HwpTemplateMapper mapper;

    @Mock
    private AuditWriter auditWriter;

    @Mock
    private TemplateFileStorage templateFileStorage;

    @InjectMocks
    private HwpTemplateService service;

    @BeforeEach
    void setUser() {
        LoginUserContext.set(LoginUser.builder().coCd("0003").userId("admin").build());
    }

    @AfterEach
    void clearUser() {
        LoginUserContext.clear();
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.clearSynchronization();
        }
    }

    private static List<HwpTemplateDeleteItem> key(String tmplCd) {
        HwpTemplateDeleteItem k = new HwpTemplateDeleteItem();
        k.setTmplCd(tmplCd);
        return List.of(k);
    }

    // ---------------------------------------------------------------- 되는 것

    @Test
    void 막을_것이_없으면_지운다() {
        // 이 시험이 없어서 삭제가 통째로 죽은 것을 못 잡았다
        when(mapper.selectDeleteBlocker(any(), any())).thenReturn(null);

        service.delete(key("hwp_usr_001"));

        verify(mapper, times(1)).deleteHwpTemplate(any(), eq("hwp_usr_001"), any());
    }

    @Test
    void 저장해도_감사_기록을_남긴다() {
        HwpTemplateSaveRow row = new HwpTemplateSaveRow();
        row.setTmplCd("hwp_usr_001");
        row.setTmplNm("자사양식");
        row.setUseYn("Y");
        service.saveHwpTemplate(row);
        verify(auditWriter, times(1)).record(eq("tbl_company_template"), any(), eq("U"), any());
    }

    @Test
    void 지운_뒤_감사_기록을_남긴다() {
        // 형제 화면과 같은 밀도로 남겨야 한다 — 안 남기면 누가 지웠는지 못 본다
        when(mapper.selectDeleteBlocker(any(), any())).thenReturn(null);

        service.delete(key("hwp_usr_001"));

        verify(auditWriter, times(1)).record(eq("tbl_company_template"), any(), eq("D"), any());
    }

    @Test
    void 같은_양식을_두_번_보내도_한_번만_지운다() {
        when(mapper.selectDeleteBlocker(any(), any())).thenReturn(null);

        List<HwpTemplateDeleteItem> keys = new ArrayList<>();
        keys.add(key("hwp_usr_001").get(0));
        keys.add(key("hwp_usr_001").get(0));
        service.delete(keys);

        verify(mapper, times(1)).deleteHwpTemplate(any(), eq("hwp_usr_001"), any());
    }

    // ---------------------------------------------------------------- 막는 것

    @Test
    void 차단_행이_있으면_막고_무엇이_왜인지_보여준다() {
        DeleteBlocker b = new DeleteBlocker();
        b.setRefKey("hwp_sys_001");
        b.setTarget("시스템 제공 양식");
        when(mapper.selectDeleteBlocker(any(), any())).thenReturn(b);

        BizException e = assertThrows(BizException.class, () -> service.delete(key("hwp_sys_001")));

        assertTrue(e.getMessage().contains("hwp_sys_001"), e.getMessage());
        assertTrue(e.getMessage().contains("시스템 제공 양식"), e.getMessage());
        verify(mapper, never()).deleteHwpTemplate(any(), any(), any());
    }

    @Test
    void 빈_목록은_막는다() {
        BizException e = assertThrows(BizException.class, () -> service.delete(List.of()));
        assertEquals("삭제할 양식을 선택하세요.", e.getMessage());
        verify(mapper, never()).deleteHwpTemplate(any(), any(), any());
    }

    @Test
    void 양식코드가_공백뿐이면_막는다() {
        // "  " 를 통과시키면 SP 가 0건을 지우고 성공을 돌려준다
        assertThrows(BizException.class, () -> service.delete(key("   ")));
        verify(mapper, never()).deleteHwpTemplate(any(), any(), any());
    }

    @Test
    void validate_delete_는_자료를_건드리지_않는다() {
        // 확인창을 열기 전 검사다 — 여기서 지우면 「확인」이 뜻을 잃는다
        when(mapper.selectDeleteBlocker(any(), any())).thenReturn(null);

        service.validateDelete(key("hwp_usr_001"));

        verify(mapper, never()).deleteHwpTemplate(any(), any(), any());
        verify(auditWriter, never()).record(any(), any(), any(), any());
        verify(templateFileStorage, never()).delete(any());
    }

    @Test
    void 트랜잭션_안에서는_커밋_전에_실물을_안_지운다() {
        when(mapper.selectDeleteBlocker(any(), any())).thenReturn(null);
        when(mapper.selectTemplateFormPaths(eq("0003"), any())).thenReturn(List.of(
                "CustomTemplates/0003/hwp_usr_001/a.hwpx"));
        TransactionSynchronizationManager.initSynchronization();

        service.delete(key("hwp_usr_001"));

        verify(mapper).deleteHwpTemplate(eq("0003"), eq("hwp_usr_001"), eq("admin"));
        verify(templateFileStorage, never()).delete(any());

        for (TransactionSynchronization sync : TransactionSynchronizationManager.getSynchronizations()) {
            sync.afterCommit();
        }
        verify(templateFileStorage).delete("CustomTemplates/0003/hwp_usr_001/a.hwpx");
    }
}
