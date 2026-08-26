/**
 * DraftSupportSeedTest — 신규 문서 기본행 시드 검증.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 시드 행이 0건이거나 rowSeq 가 0 이하면 저장 SP 가 문서를 만들지 못한다 — 그 계약을 값으로 고정한다
 *   2) 구간(BEFORE·AFTER)마다 한 줄, rowSeq 는 1부터 유일해야 한다. 지면이 첫 줄을 라벨 행으로 쓴다
 *   3) 실행: ./mvnw -Dtest=DraftSupportSeedTest test — DB·Spring 컨텍스트 없이 순수 계산만 본다
 */
package com.haccp.draft;

// 역할 — 검증 대상 반환 타입
import com.haccp.draft.dto.DraftLogRow;
import com.haccp.draft.dto.DraftPassRow;
import java.util.List;
// 역할 — 단정
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import org.junit.jupiter.api.Test;

class DraftSupportSeedTest {

    /** 구간마다 한 줄, rowSeq 1부터 — SP 가 rowSeq 0 이하를 거부한다 */
    @Test
    void 기록행_시드는_구간마다_한줄이고_순번은_1부터다() {
        List<DraftLogRow> rows = DraftSupport.seedLogRows("BEFORE", "AFTER");

        assertEquals(2, rows.size());
        assertEquals("BEFORE", rows.get(0).getPhaseCd());
        assertEquals("AFTER", rows.get(1).getPhaseCd());
        assertEquals(1, rows.get(0).getRowSeq());
        assertEquals(2, rows.get(1).getRowSeq());
        for (DraftLogRow row : rows) {
            assertTrue(row.getRowSeq() > 0);
            // cells 가 null 이면 지면 입력이 첫 타이핑에서 깨진다
            assertNotNull(row.getCells());
            assertEquals("N", row.getJudgeModYn());
            assertEquals("N", row.getSignYn());
        }
    }

    /** 통과량 기본행 — 지면 PASS_CNT 와 같은 줄 수, 순번 1..n */
    @Test
    void 통과량_시드는_요청한_줄수만큼_순번이_이어진다() {
        List<DraftPassRow> rows = DraftSupport.seedPassRows(4);

        assertEquals(4, rows.size());
        for (int i = 0; i < rows.size(); i++) {
            assertEquals(i + 1, rows.get(i).getRowSeq());
        }
    }

    /** 시드를 요청하지 않으면 빈 목록 — 기록 표가 없는 화면은 그대로 둔다 */
    @Test
    void 구간을_주지_않으면_빈_목록이다() {
        assertTrue(DraftSupport.seedLogRows().isEmpty());
        assertEquals(0, DraftSupport.seedPassRows(0).size());
    }
}
