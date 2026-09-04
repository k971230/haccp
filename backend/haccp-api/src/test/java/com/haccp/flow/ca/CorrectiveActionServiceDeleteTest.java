/**
 * CorrectiveActionServiceDeleteTest — 개선조치 삭제가 확인창 **전에** 막히는지.
 *
 * 개발자: 박승우
 * 일자: 2026-09-04
 * 코멘트:
 *   1) validate-delete 와 delete 가 **같은 검사**를 한다 ([OPS_DELETE] Double Check)
 *   2) 완료(DONE) 건이 섞이면 둘 다 막고, 삭제 SP 는 아예 안 부른다
 *   3) DB 없이 매퍼만 가짜로 세운다
 *
 * 예전에는 validate-delete 가 키 모양만 봐서, 완료 건을 고르면 확인창을 누른 뒤에야
 * 실패했고 여러 건을 골랐으면 정상 건까지 같은 트랜잭션에서 롤백됐다.
 *
 * PIPELINE[HB94] Service
 */
package com.haccp.flow.ca;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.haccp.common.context.LoginUser;
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
import com.haccp.common.validation.DeleteBlocker;
import com.haccp.sys.logs.auditlog.AuditWriter;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
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
class CorrectiveActionServiceDeleteTest {

    @Mock
    private CorrectiveActionMapper mapper;

    @Mock
    private AuditWriter auditWriter;

    @Spy
    private ObjectMapper objectMapper = new ObjectMapper();

    @InjectMocks
    private CorrectiveActionService service;

    private final List<Map<String, Long>> keys = List.of(Map.of("idx", 5L), Map.of("idx", 6L));

    @BeforeEach
    void setUser() {
        LoginUserContext.set(LoginUser.builder().coCd("0000").userId("admin").build());
    }

    @AfterEach
    void clearUser() {
        LoginUserContext.clear();
    }

    /** 완료 건이 하나 섞였다 — SP 가 첫 위반만 돌려준다 */
    private void givenBlocked() {
        DeleteBlocker blocker = new DeleteBlocker();
        blocker.setRefKey("CA-20260904-001");
        blocker.setTarget("완료된 개선조치");
        when(mapper.selectDeleteBlocker(anyString(), any())).thenReturn(blocker);
    }

    @Test
    void 완료된_건이_섞이면_확인창_전에_막는다() {
        givenBlocked();

        BizException e = assertThrows(BizException.class,
                () -> service.validateCorrectiveActionDelete(keys));

        // 어느 건이 왜 막히는지 문구에 실려야 한다 — 예전에는 이 단계가 통과했다
        assertTrue(e.getMessage().contains("CA-20260904-001"), e.getMessage());
        assertTrue(e.getMessage().contains("완료된 개선조치"), e.getMessage());
    }

    @Test
    void 확인창을_지나도_같은_검사를_다시_한다() {
        givenBlocked();

        assertThrows(BizException.class, () -> service.deleteCorrectiveActions(keys));

        // 한 건도 지우면 안 된다 — 정상 건까지 롤백되는 일이 없어야 한다
        verify(mapper, never()).deleteCorrectiveAction(anyString(), anyLong(), anyString());
    }

    @Test
    void 막을_것이_없으면_고른_만큼_지운다() {
        when(mapper.selectDeleteBlocker(anyString(), any())).thenReturn(null);

        service.deleteCorrectiveActions(keys);

        verify(mapper).deleteCorrectiveAction("0000", 5L, "admin");
        verify(mapper).deleteCorrectiveAction("0000", 6L, "admin");
    }
}
