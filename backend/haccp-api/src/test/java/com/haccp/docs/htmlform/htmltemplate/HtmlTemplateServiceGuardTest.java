/**
 * HtmlTemplateServiceGuardTest — 지면 양식의 표준 보호와 표 배정.
 *
 * 개발자: 박승우
 * 일자: 2026-08-27
 * 코멘트:
 *   1) 표준 양식은 못 고친다 — 여기가 무르면 한 회사가 고친 표준이
 *      그 코드를 쓰는 전 회사 지면에 번진다. 되돌릴 방법이 없다
 *   2) 양식코드가 표를 고른다 — 배정이 어긋나면 오류 없이 엉뚱한 표에 쌓인다.
 *      화면은 멀쩡해 보이고 조회만 비어 있어, 뜬 뒤에는 못 찾는다
 *   3) DB 없이 매퍼 다섯을 가짜로 세워 「어디로 갔는가」만 본다
 *
 * PIPELINE[HB131] 지면양식 업무 서비스
 */
package com.haccp.docs.htmlform.htmltemplate;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.haccp.docs.htmlform.ccphtgtemplate.CcpHtgTemplateMapper;
import com.haccp.docs.htmlform.ccpmtltemplate.CcpMtlTemplateMapper;
import com.haccp.docs.htmlform.ccppkgtemplate.CcpPkgTemplateMapper;
import com.haccp.docs.htmlform.ccpverifytemplate.CcpVerifyTemplateMapper;
import com.haccp.common.exception.BizException;
import com.haccp.sys.logs.auditlog.AuditWriter;
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
class HtmlTemplateServiceGuardTest {

    @Mock private HtmlTemplateMapper mapper;
    @Mock private CcpVerifyTemplateMapper ccpMapper;
    @Mock private CcpPkgTemplateMapper pkgMapper;
    @Mock private CcpHtgTemplateMapper htgMapper;
    @Mock private CcpMtlTemplateMapper mtlMapper;
    @Mock private AuditWriter auditWriter;

    private HtmlTemplateService service() {
        return new HtmlTemplateService(mapper, ccpMapper, pkgMapper, htgMapper, mtlMapper, new ObjectMapper(), auditWriter);
    }

    private static final List<Map<String, Object>> ITEMS = List.of(Map.of("itemNm", "온도"));

    // ---------------------------------------------------------------- 표준 보호

    @Test
    void 표준_양식_여덟_개는_항목을_못_고친다() {
        // 하나라도 빠지면 그 코드로 표준이 덮인다
        for (String std : List.of(
                "html_hyg_prc_000", "html_hyg_000", "html_sys_001",
                "tml_ccp_chk_000", "html_sys_006",
                "tml_ccp_pkg_000", "tml_ccp_htg_000", "tml_ccp_mtl_000")) {
            BizException e = assertThrows(
                    BizException.class, () -> service().saveItems(std, 1, ITEMS), std);
            assertEquals("표준 항목은 수정할 수 없습니다.", e.getMessage(), std);
        }
        verify(mapper, never()).saveItems(any(), any(), anyInt(), any(), any());
        verify(ccpMapper, never()).saveItems(any(), any(), anyInt(), any(), any());
    }

    @Test
    void 표준_양식은_이름도_못_고친다() {
        BizException e = assertThrows(
                BizException.class, () -> service().updateVerNm("tml_ccp_htg_000", 1, "내 양식", "Y"));
        assertEquals("표준 양식명은 수정할 수 없습니다.", e.getMessage());
    }

    @Test
    void 회사순번_0은_표준이라_막는다() {
        // 0번은 표준 자리다 — 여기를 열면 회사 양식이 표준을 밀어낸다
        assertThrows(BizException.class, () -> service().saveItems("tml_ccp_htg_007", 0, ITEMS));
        assertThrows(BizException.class, () -> service().updateVerNm("tml_ccp_htg_007", 0, "이름", "Y"));
    }

    @Test
    void 회사순번이_없거나_음수면_막는다() {
        assertThrows(BizException.class, () -> service().saveItems("tml_ccp_htg_007", null, ITEMS));
        assertThrows(BizException.class, () -> service().saveItems("tml_ccp_htg_007", -1, ITEMS));
    }

    @Test
    void 양식코드가_비면_표준으로_보고_막는다() {
        // 빈 값을 회사 양식으로 흘리면 표준 표에 쓰게 된다
        assertThrows(BizException.class, () -> service().saveItems("", 1, ITEMS));
        assertThrows(BizException.class, () -> service().saveItems(null, 1, ITEMS));
    }

    // ---------------------------------------------------------------- 표 배정

    @Test
    void 양식코드_머리글자가_저장할_표를_고른다() {
        service().saveItems("tml_ccp_mtl_007", 1, ITEMS);
        verify(mtlMapper, times(1)).saveItems(any(), eq("tml_ccp_mtl_007"), anyInt(), any(), any());

        service().saveItems("tml_ccp_htg_007", 1, ITEMS);
        verify(htgMapper, times(1)).saveItems(any(), eq("tml_ccp_htg_007"), anyInt(), any(), any());

        service().saveItems("tml_ccp_pkg_007", 1, ITEMS);
        verify(pkgMapper, times(1)).saveItems(any(), eq("tml_ccp_pkg_007"), anyInt(), any(), any());

        service().saveItems("tml_ccp_chk_007", 1, ITEMS);
        verify(ccpMapper, times(1)).saveItems(any(), eq("tml_ccp_chk_007"), anyInt(), any(), any());

        // 어느 가족도 아니면 공정점검(html_hyg_prc) 표로 간다
        service().saveItems("html_hyg_prc_007", 1, ITEMS);
        verify(mapper, times(1)).saveItems(any(), eq("html_hyg_prc_007"), anyInt(), any(), any());
    }

    @Test
    void 한_번_저장하면_한_표에만_쌓인다() {
        // 조건이 겹쳐 두 표에 같이 들어가면 조회가 둘로 갈린다
        service().saveItems("tml_ccp_mtl_007", 1, ITEMS);

        verify(mtlMapper, times(1)).saveItems(any(), any(), anyInt(), any(), any());
        verify(htgMapper, never()).saveItems(any(), any(), anyInt(), any(), any());
        verify(pkgMapper, never()).saveItems(any(), any(), anyInt(), any(), any());
        verify(ccpMapper, never()).saveItems(any(), any(), anyInt(), any(), any());
        verify(mapper, never()).saveItems(any(), any(), anyInt(), any(), any());
    }

    @Test
    void 옛_코드는_정식_코드로_바꿔_읽는다() {
        // html_hyg_000 북마크가 살아 있다 — 정식 코드와 같은 표준으로 봐야 한다
        BizException e = assertThrows(
                BizException.class, () -> service().saveItems("html_hyg_000", 1, ITEMS));
        assertEquals("표준 항목은 수정할 수 없습니다.", e.getMessage());
    }

    // ---------------------------------------------------------------- 저장 형식

    @Test
    void 항목을_JSON_배열로_넘긴다() {
        // SP 가 jsonb 로 받는다 — 배열이 아니면 통째로 실패한다
        service().saveItems("html_hyg_prc_007", 1, ITEMS);

        ArgumentCaptor<String> json = ArgumentCaptor.forClass(String.class);
        verify(mapper).saveItems(any(), any(), anyInt(), json.capture(), any());
        assertEquals("[{\"itemNm\":\"온도\"}]", json.getValue());
    }

    @Test
    void 항목이_null_이면_빈_배열로_넘긴다() {
        // null 을 그대로 넘기면 jsonb 변환에서 터진다
        service().saveItems("html_hyg_prc_007", 1, null);

        ArgumentCaptor<String> json = ArgumentCaptor.forClass(String.class);
        verify(mapper).saveItems(any(), any(), anyInt(), json.capture(), any());
        assertEquals("[]", json.getValue());
    }

    // ---------------------------------------------------------------- 이름·사용여부

    @Test
    void 양식명이_공백뿐이면_막는다() {
        assertThrows(BizException.class, () -> service().updateVerNm("tml_ccp_htg_007", 1, "   ", "Y"));
        verify(htgMapper, never()).updateVerNm(any(), any(), anyInt(), any(), any(), any());
    }

    @Test
    void 사용여부는_Y_또는_N_으로만_저장한다() {
        // 문서주기가 이 값을 본다 — 소문자나 빈 값이 들어가면 예정일이 안 생긴다
        ArgumentCaptor<String> yn = ArgumentCaptor.forClass(String.class);

        service().updateVerNm("tml_ccp_htg_007", 1, "내 양식", "n");
        verify(htgMapper).updateVerNm(any(), eq("tml_ccp_htg_007"), anyInt(), any(), yn.capture(), any());
        assertEquals("N", yn.getValue());

        service().updateVerNm("tml_ccp_htg_008", 1, "내 양식", "");
        verify(htgMapper).updateVerNm(any(), eq("tml_ccp_htg_008"), anyInt(), any(), yn.capture(), any());
        assertEquals("Y", yn.getValue());

        service().updateVerNm("tml_ccp_htg_009", 1, "내 양식", null);
        verify(htgMapper).updateVerNm(any(), eq("tml_ccp_htg_009"), anyInt(), any(), yn.capture(), any());
        assertEquals("Y", yn.getValue());
    }

    @Test
    void 양식명_앞뒤_공백은_떼고_저장한다() {
        service().updateVerNm("tml_ccp_htg_007", 1, "  내 양식  ", "Y");

        ArgumentCaptor<String> nm = ArgumentCaptor.forClass(String.class);
        verify(htgMapper).updateVerNm(any(), any(), anyInt(), nm.capture(), any(), any());
        assertEquals("내 양식", nm.getValue());
    }
}
