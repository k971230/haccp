/**
 * CorrectiveActionServiceTest — 개선조치관리 업무 서비스.
 *
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 삭제 키 검증과 snake_case → camelCase 변환을 고정한다 —
 *      키가 무르면 0건을 지우고 성공을 돌려주고, 변환이 틀리면 그리드 칸이 통째로 빈다
 *   2) 2026-08-26 에 com.haccp.tsk 에서 옮겨 온 서비스다. 옮길 때 시험이 없었다
 *   3) DB 없이 매퍼를 가짜로 세워 서비스 판단만 본다.
 *      회사코드·작업자는 JWT 에서 오는데 시험에는 요청이 없어 null 이다 —
 *      그래서 스텁은 anyString() 이 아니라 any() 로 받는다 (anyString 은 null 을 안 받는다)
 *
 * PIPELINE[HB94] 개선조치관리 업무 서비스
 */
package com.haccp.flow.ca;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.haccp.common.exception.BizException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.Spy;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class CorrectiveActionServiceTest {

    @Mock
    private CorrectiveActionMapper mapper;

    @Spy
    private ObjectMapper objectMapper = new ObjectMapper();

    @InjectMocks
    private CorrectiveActionService service;

    /** SP 가 돌려주는 모양 — snake_case 키의 Map */
    private static Map<String, Object> snakeRow() {
        Map<String, Object> row = new LinkedHashMap<>();
        row.put("ca_no", "CA-20260826-001");
        row.put("action_desc", "세척 후 재검사");
        row.put("src_doc_idx", 448L);
        row.put("occur_dt", "20260826");
        return row;
    }

    // ---------------------------------------------------------------- 삭제 키 검증

    @Test
    void 빈_목록으로_삭제하면_막고_매퍼를_부르지_않는다() {
        BizException e = assertThrows(
                BizException.class, () -> service.validateCorrectiveActionDelete(List.of()));
        assertEquals("삭제할 개선조치를 선택하세요.", e.getMessage());
        verify(mapper, never()).deleteCorrectiveAction(any(), any(), any());
    }

    @Test
    void idx_가_없는_키는_막는다() {
        // {} 를 통과시키면 SP 가 idx=null 로 0건을 지우고 성공을 돌려준다
        List<Map<String, Long>> keys = new ArrayList<>();
        keys.add(new LinkedHashMap<>());
        assertThrows(BizException.class, () -> service.validateCorrectiveActionDelete(keys));
    }

    @Test
    void idx_가_0_이하인_키도_막는다() {
        List<Map<String, Long>> keys = List.of(Map.of("idx", 0L));
        assertThrows(BizException.class, () -> service.validateCorrectiveActionDelete(keys));
    }

    @Test
    void 목록_중_하나라도_틀리면_전부_막는다() {
        // 앞 건이 멀쩡해도 뒤가 틀리면 아무것도 지우면 안 된다 — 반쯤 지워지는 게 제일 나쁘다
        List<Map<String, Long>> keys = new ArrayList<>();
        keys.add(Map.of("idx", 448L));
        keys.add(new LinkedHashMap<>());
        assertThrows(BizException.class, () -> service.deleteCorrectiveActions(keys));
        verify(mapper, never()).deleteCorrectiveAction(any(), any(), any());
    }

    // ---------------------------------------------------------------- 저장

    @Test
    void 저장할_자료가_없으면_막는다() {
        BizException e = assertThrows(
                BizException.class, () -> service.saveCorrectiveAction(1L, null));
        assertEquals("저장할 개선조치 자료가 없습니다.", e.getMessage());
    }

    // ---------------------------------------------------------------- 키 변환

    @Test
    void snake_case_를_화면_계약인_camelCase_로_바꾼다() {
        when(mapper.selectCorrectiveActions(any(), any(), any(), any(), any()))
                .thenReturn(List.of(snakeRow()));

        Map<String, Object> row = service.correctiveActions("", "", "", "").get(0);

        // 변환이 틀리면 그리드 field 와 안 맞아 칸이 통째로 빈다
        assertTrue(row.containsKey("caNo"), row.keySet().toString());
        assertTrue(row.containsKey("actionDesc"), row.keySet().toString());
        assertTrue(row.containsKey("srcDocIdx"), row.keySet().toString());
        assertTrue(row.containsKey("occurDt"), row.keySet().toString());
        // 원래 키는 남기지 않는다 — 남으면 화면이 어느 쪽을 읽는지 알 수 없다
        assertTrue(!row.containsKey("ca_no"), row.keySet().toString());
        assertEquals("세척 후 재검사", row.get("actionDesc"));
    }

    @Test
    void 목록이_null_이어도_빈_목록을_돌려준다() {
        // 화면이 .map 을 바로 부른다 — null 이 나가면 흰 화면이 된다
        when(mapper.selectCorrectiveActions(any(), any(), any(), any(), any()))
                .thenReturn(null);
        assertEquals(0, service.correctiveActions("", "", "", "").size());
    }
}
