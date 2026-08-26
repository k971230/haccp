/**
 * DeleteValidationTest — 전 화면 삭제가 지나는 공용 검증.
 *
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 삭제는 화면마다 다르게 짜여 있어도 이 넷을 반드시 지난다 —
 *      여기가 무르면 화면 스물여덟 개가 같이 무른다
 *   2) 특히 「막는 문구」를 고정한다. 사용자가 무엇 때문에 못 지우는지 못 보면
 *      화면이 조용히 실패한 것과 같다
 *   3) DB·Spring 없이 순수 함수만 실행한다
 *
 * PIPELINE[HB51] common 모듈
 */
package com.haccp.common.validation;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;

import com.haccp.common.exception.BizException;
import java.util.List;
import org.junit.jupiter.api.Test;

class DeleteValidationTest {

    // ---------------------------------------------------------------- requireItems

    @Test
    void 빈_목록은_막고_문구를_그대로_보여준다() {
        BizException e = assertThrows(
                BizException.class,
                () -> DeleteValidation.requireItems(List.of(), "삭제할 양식을 선택하세요."));
        assertEquals("삭제할 양식을 선택하세요.", e.getMessage());
    }

    @Test
    void null_목록도_막는다() {
        // 화면이 키를 아예 안 보낸 경우다 — 빈 배열과 같이 다뤄야 한다
        assertThrows(
                BizException.class,
                () -> DeleteValidation.requireItems(null, "선택하세요."));
    }

    @Test
    void 한_건이라도_있으면_지나간다() {
        assertDoesNotThrow(() -> DeleteValidation.requireItems(List.of("x"), "선택하세요."));
    }

    // ---------------------------------------------------------------- requireText

    @Test
    void 공백만_있는_키는_비어_있는_것으로_본다() {
        // "   " 를 통과시키면 SP 가 WHERE tmpl_cd = '   ' 로 0건을 지우고 성공을 돌려준다
        assertThrows(
                BizException.class,
                () -> DeleteValidation.requireText("   ", "양식코드가 없습니다."));
    }

    @Test
    void null_키도_막는다() {
        assertThrows(
                BizException.class,
                () -> DeleteValidation.requireText(null, "양식코드가 없습니다."));
    }

    @Test
    void 앞뒤_공백은_떼고_돌려준다() {
        // 화면 입력에 공백이 섞여도 업무키는 같아야 한다
        assertEquals("hwp_usr_001", DeleteValidation.requireText("  hwp_usr_001 ", "없습니다."));
    }

    // ---------------------------------------------------------------- requirePositive

    @Test
    void 대리키는_양수만_받는다() {
        assertThrows(BizException.class, () -> DeleteValidation.requirePositive(null, "키가 없습니다."));
        assertThrows(BizException.class, () -> DeleteValidation.requirePositive(0L, "키가 없습니다."));
        // 음수를 통과시키면 SP 가 조건에 안 걸려 0건을 지우고 성공한다
        assertThrows(BizException.class, () -> DeleteValidation.requirePositive(-1L, "키가 없습니다."));
    }

    @Test
    void 양수는_그대로_돌려준다() {
        assertEquals(448L, DeleteValidation.requirePositive(448L, "키가 없습니다."));
    }

    // ---------------------------------------------------------------- throwIfBlocked

    @Test
    void 차단_행이_없으면_지나간다() {
        assertDoesNotThrow(() -> DeleteValidation.throwIfBlocked(null, "사용양식"));
    }

    @Test
    void 차단_행이_있으면_무엇이_왜_막는지_문구에_담는다() {
        DeleteBlocker b = new DeleteBlocker();
        b.setRefKey("hwp_sys_001");
        b.setTarget("시스템 제공 양식");

        BizException e = assertThrows(
                BizException.class,
                () -> DeleteValidation.throwIfBlocked(b, "사용양식"));

        // 사용자가 「무엇이」「왜」 막혔는지 볼 수 있어야 한다 — 셋 다 들어간다
        assertTrue(e.getMessage().contains("사용양식"), e.getMessage());
        assertTrue(e.getMessage().contains("hwp_sys_001"), e.getMessage());
        assertTrue(e.getMessage().contains("시스템 제공 양식"), e.getMessage());
    }

    @Test
    void 차단_행의_값이_비어도_터지지_않는다() {
        // SP 가 target 을 안 채워 보내는 경우가 있다 — NPE 로 500 이 되면 안 된다
        DeleteBlocker b = new DeleteBlocker();
        BizException e = assertThrows(
                BizException.class,
                () -> DeleteValidation.throwIfBlocked(b, "부서"));
        assertNotNull(e.getMessage());
        assertTrue(e.getMessage().contains("부서"), e.getMessage());
    }

    // ---------------------------------------------------------------- referenced

    @Test
    void 표준_차단_문구를_고정한다() {
        // 화면마다 다른 문구를 쓰면 사용자가 같은 상황을 다르게 읽는다
        assertEquals(
                "선택한 항목 중 부서 'QC'이(가) 사용자에서 참조 중이므로 삭제할 수 없습니다.",
                DeleteValidation.referenced("부서", "QC", "사용자"));
    }
}
