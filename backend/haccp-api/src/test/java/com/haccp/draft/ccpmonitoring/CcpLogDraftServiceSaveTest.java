/**
 * CcpLogDraftServiceSaveTest — CCP 일지 저장.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 부적합(F) 행이 하나라도 있으면 이탈·개선조치가 자동으로 생겨야 한다
 *   2) 지면 셀은 숫자·글자를 갈라 담는다
 *   3) DB 없이 매퍼를 가짜로 세워 「무엇을 넘겼는가」만 본다
 *
 * PIPELINE[HB147] CCP 모니터링 작성 서비스
 */
package com.haccp.draft.ccpmonitoring;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.haccp.common.context.LoginUser;
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
import com.haccp.draft.DraftPaperStampMapper;
import com.haccp.draft.DraftSeenGuard;
import com.haccp.draft.dto.DraftLogRow;
import com.haccp.draft.dto.DraftSaveRequest;
import com.haccp.flow.ca.DocCorrectiveSupport;
import com.haccp.sys.logs.auditlog.AuditWriter;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class CcpLogDraftServiceSaveTest {

    @Mock private CcpPkgDraftMapper pkgMapper;
    @Mock private CcpHtgDraftMapper htgMapper;
    @Mock private DocCorrectiveSupport correctiveSupport;
    @Mock private DraftPaperStampMapper paperStampMapper;
    @Mock private AuditWriter auditWriter;
    @Mock private DraftSeenGuard seenGuard;

    private CcpPkgDraftService pkg;
    private CcpHtgDraftService htg;

    @BeforeEach
    void setUser() {
        LoginUserContext.set(LoginUser.builder().coCd("0000").userId("admin").build());
    }

    @AfterEach
    void clearUser() {
        LoginUserContext.clear();
    }

    private CcpPkgDraftService pkg() {
        if (pkg == null) {
            CcpMonitorDraftSupport support = new CcpMonitorDraftSupport(
                    new ObjectMapper(), correctiveSupport, auditWriter, paperStampMapper, seenGuard);
            pkg = new CcpPkgDraftService(pkgMapper, support);
            when(pkgMapper.save(any(), any(), any(), any(), any(), any(), any(), any())).thenReturn(448L);
        }
        return pkg;
    }

    private CcpHtgDraftService htg() {
        if (htg == null) {
            CcpMonitorDraftSupport support = new CcpMonitorDraftSupport(
                    new ObjectMapper(), correctiveSupport, auditWriter, paperStampMapper, seenGuard);
            htg = new CcpHtgDraftService(htgMapper, support);
            when(htgMapper.save(any(), any(), any(), any(), any(), any(), any(), any())).thenReturn(448L);
        }
        return htg;
    }

    /** 판정코드 하나짜리 기록행 — 나머지 칸은 이 시험과 무관하다 */
    private static DraftLogRow row(String judgeCd) {
        DraftLogRow r = new DraftLogRow();
        r.setJudgeCd(judgeCd);
        return r;
    }

    private static DraftSaveRequest req(List<DraftLogRow> rows) {
        DraftSaveRequest q = new DraftSaveRequest();
        q.setBaseDt("20260827");
        q.setTmplCd("html_ccp_pkg_007");
        q.setLogRows(rows);
        return q;
    }

    /** saveAutoIfNg 에 넘어간 hasNg 값을 꺼낸다 */
    private boolean capturedHasNg() {
        ArgumentCaptor<Boolean> ng = ArgumentCaptor.forClass(Boolean.class);
        verify(correctiveSupport)
                .saveAutoIfNg(any(), anyLong(), any(), any(), any(), ng.capture(), any());
        return ng.getValue();
    }

    @Test
    void 부적합_행이_하나라도_있으면_이탈로_넘긴다() {
        pkg().save(req(List.of(row("P"), row("F"), row("P"))));

        assertTrue(capturedHasNg(), "부적합 행이 있는데 이탈로 넘기지 않았다");
    }

    @Test
    void 전부_적합이면_이탈로_넘기지_않는다() {
        pkg().save(req(List.of(row("P"), row("P"))));

        assertEquals(false, capturedHasNg());
    }

    @Test
    void 판정코드_소문자도_부적합으로_본다() {
        pkg().save(req(List.of(row("f"))));

        assertTrue(capturedHasNg(), "소문자 f 를 부적합으로 보지 않았다");
    }

    @Test
    void 판정이_비어_있으면_부적합이_아니다() {
        pkg().save(req(List.of(row(""), row(null))));

        assertEquals(false, capturedHasNg());
    }

    @Test
    void 숫자로_읽히는_셀은_숫자칸에_담는다() {
        DraftLogRow r = row("P");
        Map<String, String> cells = new LinkedHashMap<>();
        cells.put("temp", "72.5");
        cells.put("min", "-3");
        r.setCells(cells);

        pkg().save(req(List.of(r)));

        String json = savedPkgRowsJson();
        assertTrue(json.contains("\"itemCd\":\"temp\",\"numVal\":\"72.5\""), json);
        assertTrue(json.contains("\"itemCd\":\"min\",\"numVal\":\"-3\""), json);
    }

    @Test
    void 숫자가_아닌_셀은_글자칸에_담는다() {
        DraftLogRow r = row("P");
        Map<String, String> cells = new LinkedHashMap<>();
        cells.put("temp", "이상없음");
        cells.put("sec", "");
        r.setCells(cells);

        pkg().save(req(List.of(r)));

        String json = savedPkgRowsJson();
        assertTrue(json.contains("\"itemCd\":\"temp\",\"numVal\":\"\",\"txtVal\":\"이상없음\""), json);
        assertTrue(json.contains("\"itemCd\":\"sec\",\"numVal\":\"\",\"txtVal\":\"\""), json);
    }

    @Test
    void 행_순번이_없으면_1부터_매긴다() {
        pkg().save(req(List.of(row("P"), row("P"), row("P"))));

        String json = savedPkgRowsJson();
        assertTrue(json.contains("\"rowSeq\":1"), json);
        assertTrue(json.contains("\"rowSeq\":2"), json);
        assertTrue(json.contains("\"rowSeq\":3"), json);
    }

    @Test
    void 화면이_준_행_순번은_그대로_쓴다() {
        DraftLogRow r = row("P");
        r.setRowSeq(7);

        pkg().save(req(List.of(r)));

        assertTrue(savedPkgRowsJson().contains("\"rowSeq\":7"), savedPkgRowsJson());
    }

    @Test
    void 일자가_여덟_자리가_아니면_막는다() {
        DraftSaveRequest q = req(List.of(row("P")));
        q.setBaseDt("2026-08-27");

        assertThrows(BizException.class, () -> pkg().save(q));
        verify(pkgMapper, never()).save(any(), any(), any(), any(), any(), any(), any(), any());
    }

    @Test
    void 점검_행이_없으면_막는다() {
        assertThrows(BizException.class, () -> pkg().save(req(List.of())));
        verify(pkgMapper, never()).save(any(), any(), any(), any(), any(), any(), any(), any());
    }

    @Test
    void 예시_양식으로는_작성하지_못한다() {
        DraftSaveRequest q = req(List.of(row("P")));
        q.setTmplCd("html_ccp_pkg_000");

        assertThrows(BizException.class, () -> pkg().save(q));
        verify(pkgMapper, never()).save(any(), any(), any(), any(), any(), any(), any(), any());
    }

    @Test
    void 다른_양식군_코드는_막는다() {
        DraftSaveRequest q = req(List.of(row("P")));
        q.setTmplCd("html_ccp_htg_007");

        assertThrows(BizException.class, () -> pkg().save(q));
        verify(pkgMapper, never()).save(any(), any(), any(), any(), any(), any(), any(), any());
    }

    @Test
    void 저장이_0을_돌려주면_실패로_본다() {
        pkg();
        when(pkgMapper.save(any(), any(), any(), any(), any(), any(), any(), any())).thenReturn(0L);

        assertThrows(BizException.class, () -> pkg.save(req(List.of(row("P")))));
        verify(correctiveSupport, never())
                .saveAutoIfNg(any(), anyLong(), any(), any(), any(), anyBoolean(), any());
    }

    @Test
    void 가열_양식군은_가열_접두만_받는다() {
        DraftSaveRequest q = new DraftSaveRequest();
        q.setBaseDt("20260827");
        q.setTmplCd("html_ccp_htg_007");
        q.setLogRows(List.of(row("P")));

        htg().save(q);

        verify(htgMapper).save(any(), any(), eq("20260827"), eq("html_ccp_htg_007"), any(), any(), any(), any());
    }

    private String savedPkgRowsJson() {
        ArgumentCaptor<String> json = ArgumentCaptor.forClass(String.class);
        verify(pkgMapper).save(any(), any(), any(), any(), any(), json.capture(), any(), any());
        return json.getValue();
    }
}
