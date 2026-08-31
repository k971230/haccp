/**
 * CcpLogDraftServiceSaveTest — CCP 일지 저장.
 *
 * 개발자: 박승우
 * 일자: 2026-08-27
 * 코멘트:
 *   1) 이 저장소에서 업무상 제일 무거운 규칙이 여기 있다 —
 *      부적합(F) 행이 하나라도 있으면 이탈·개선조치가 자동으로 생겨야 한다.
 *      안 생기면 한계 이탈이 기록 없이 지나가고, 그게 HACCP 에서 제일 큰 사고다
 *   2) 지면 셀은 숫자·글자를 갈라 담는다. 온도가 글자칸에 들어가면
 *      한계 판정이 그 값을 못 읽는다 — 화면은 멀쩡해 보인다
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
import com.haccp.common.exception.BizException;
import com.haccp.draft.DraftPaperStampMapper;
import com.haccp.draft.dto.DraftLogRow;
import com.haccp.draft.dto.DraftSaveRequest;
import com.haccp.flow.ca.DocCorrectiveSupport;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
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

    @Mock private CcpLogDraftMapper mapper;
    @Mock private DocCorrectiveSupport correctiveSupport;
    @Mock private DraftPaperStampMapper paperStampMapper;

    private CcpLogDraftService service;

    private CcpLogDraftService service() {
        if (service == null) {
            service = new CcpLogDraftService(mapper, new ObjectMapper(), correctiveSupport, paperStampMapper);
            when(mapper.save(any(), any(), any(), any(), any(), any(), any())).thenReturn(448L);
        }
        return service;
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
        q.setTmplCd("tml_ccp_pkg_007");
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

    // ---------------------------------------------------------------- 부적합 → 이탈

    @Test
    void 부적합_행이_하나라도_있으면_이탈로_넘긴다() {
        // 여기가 무르면 한계 이탈이 기록 없이 지나간다
        service().save(CcpLogDraftService.Family.PKG, req(List.of(row("P"), row("F"), row("P"))));

        assertTrue(capturedHasNg(), "부적합 행이 있는데 이탈로 넘기지 않았다");
    }

    @Test
    void 전부_적합이면_이탈로_넘기지_않는다() {
        service().save(CcpLogDraftService.Family.PKG, req(List.of(row("P"), row("P"))));

        assertEquals(false, capturedHasNg());
    }

    @Test
    void 판정코드_소문자도_부적합으로_본다() {
        // 화면이나 가져오기가 소문자를 보낼 수 있다 — 대소문자로 이탈을 놓치면 안 된다
        service().save(CcpLogDraftService.Family.PKG, req(List.of(row("f"))));

        assertTrue(capturedHasNg(), "소문자 f 를 부적합으로 보지 않았다");
    }

    @Test
    void 판정이_비어_있으면_부적합이_아니다() {
        // 아직 판정 안 한 행을 이탈로 올리면 개선조치가 헛돈다
        service().save(CcpLogDraftService.Family.PKG, req(List.of(row(""), row(null))));

        assertEquals(false, capturedHasNg());
    }

    // ---------------------------------------------------------------- 숫자·글자 갈라 담기

    @Test
    void 숫자로_읽히는_셀은_숫자칸에_담는다() throws Exception {
        // 온도가 글자칸에 들어가면 한계 판정이 그 값을 못 읽는다
        DraftLogRow r = row("P");
        Map<String, String> cells = new LinkedHashMap<>();
        cells.put("temp", "72.5");
        cells.put("minus", "-3");
        r.setCells(cells);

        service().save(CcpLogDraftService.Family.PKG, req(List.of(r)));

        String json = savedRowsJson();
        assertTrue(json.contains("\"itemCd\":\"temp\",\"numVal\":\"72.5\""), json);
        assertTrue(json.contains("\"itemCd\":\"minus\",\"numVal\":\"-3\""), json);
    }

    @Test
    void 숫자가_아닌_셀은_글자칸에_담는다() throws Exception {
        DraftLogRow r = row("P");
        Map<String, String> cells = new LinkedHashMap<>();
        cells.put("note", "이상없음");
        cells.put("empty", "");
        r.setCells(cells);

        service().save(CcpLogDraftService.Family.PKG, req(List.of(r)));

        String json = savedRowsJson();
        assertTrue(json.contains("\"itemCd\":\"note\",\"numVal\":\"\",\"txtVal\":\"이상없음\""), json);
        // 빈 값은 숫자가 아니다 — 0 으로 읽히면 한계 판정이 거짓으로 통과한다
        assertTrue(json.contains("\"itemCd\":\"empty\",\"numVal\":\"\",\"txtVal\":\"\""), json);
    }

    @Test
    void 행_순번이_없으면_1부터_매긴다() {
        // 순번이 겹치면 SP 가 뒤 행으로 앞 행을 덮는다
        service().save(CcpLogDraftService.Family.PKG, req(List.of(row("P"), row("P"), row("P"))));

        String json = savedRowsJson();
        assertTrue(json.contains("\"rowSeq\":1"), json);
        assertTrue(json.contains("\"rowSeq\":2"), json);
        assertTrue(json.contains("\"rowSeq\":3"), json);
    }

    @Test
    void 화면이_준_행_순번은_그대로_쓴다() {
        DraftLogRow r = row("P");
        r.setRowSeq(7);

        service().save(CcpLogDraftService.Family.PKG, req(List.of(r)));

        assertTrue(savedRowsJson().contains("\"rowSeq\":7"), savedRowsJson());
    }

    // ---------------------------------------------------------------- 입력 검증

    @Test
    void 일자가_여덟_자리가_아니면_막는다() {
        DraftSaveRequest q = req(List.of(row("P")));
        q.setBaseDt("2026-08-27");

        assertThrows(BizException.class, () -> service().save(CcpLogDraftService.Family.PKG, q));
        verify(mapper, never()).save(any(), any(), any(), any(), any(), any(), any());
    }

    @Test
    void 점검_행이_없으면_막는다() {
        assertThrows(
                BizException.class,
                () -> service().save(CcpLogDraftService.Family.PKG, req(List.of())));
        verify(mapper, never()).save(any(), any(), any(), any(), any(), any(), any());
    }

    @Test
    void 예시_양식으로는_작성하지_못한다() {
        // 000 은 표준 예시다 — 여기에 쓰면 전 회사가 보는 자리에 실기록이 남는다
        DraftSaveRequest q = req(List.of(row("P")));
        q.setTmplCd("tml_ccp_pkg_000");

        assertThrows(BizException.class, () -> service().save(CcpLogDraftService.Family.PKG, q));
        verify(mapper, never()).save(any(), any(), any(), any(), any(), any(), any());
    }

    @Test
    void 다른_양식군_코드는_막는다() {
        // 포장 화면에서 가열 양식을 저장하면 조회가 영영 어긋난다
        DraftSaveRequest q = req(List.of(row("P")));
        q.setTmplCd("tml_ccp_htg_007");

        assertThrows(BizException.class, () -> service().save(CcpLogDraftService.Family.PKG, q));
        verify(mapper, never()).save(any(), any(), any(), any(), any(), any(), any());
    }

    @Test
    void 저장이_0을_돌려주면_실패로_본다() {
        // SP 가 0 을 주는데 성공으로 넘기면 화면은 저장됐다고 말하고 자료는 없다
        service();
        when(mapper.save(any(), any(), any(), any(), any(), any(), any())).thenReturn(0L);

        assertThrows(
                BizException.class,
                () -> service.save(CcpLogDraftService.Family.PKG, req(List.of(row("P")))));
        verify(correctiveSupport, never())
                .saveAutoIfNg(any(), anyLong(), any(), any(), any(), anyBoolean(), any());
    }

    // ---------------------------------------------------------------- 양식군

    @Test
    void 가열_양식군은_가열_접두만_받는다() {
        service().save(CcpLogDraftService.Family.HTG, htgReq());

        verify(mapper).save(any(), any(), eq("20260827"), eq("tml_ccp_htg_007"), any(), any(), any());
    }

    private static DraftSaveRequest htgReq() {
        DraftSaveRequest q = new DraftSaveRequest();
        q.setBaseDt("20260827");
        q.setTmplCd("tml_ccp_htg_007");
        q.setLogRows(List.of(row("P")));
        return q;
    }

    /** mapper.save 에 넘어간 기록행 JSON */
    private String savedRowsJson() {
        ArgumentCaptor<String> json = ArgumentCaptor.forClass(String.class);
        verify(mapper).save(any(), any(), any(), any(), any(), json.capture(), any());
        return json.getValue();
    }
}
