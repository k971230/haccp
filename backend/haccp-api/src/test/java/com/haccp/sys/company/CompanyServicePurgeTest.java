/**
 * CompanyServicePurgeTest — 테넌트 삭제는 플랫폼 관리자만, 0000·자기 회사는 막힌다.
 *
 * 개발자: 박승우
 * 일자: 2026-09-11
 * 코멘트:
 *   1) 자사 ADMIN 이 다른 회사를 지우려 하면 확인창 전에 거절한다
 *   2) 플랫폼 0000 과 로그인 회사는 SP 를 부르기 전에 막는다
 *   3) DB 없이 매퍼만 가짜로 세운다
 *
 * PIPELINE[HB146] 업체 삭제 서비스
 */
package com.haccp.sys.company;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.haccp.common.context.LoginUser;
import com.haccp.common.context.LoginUserContext;
import com.haccp.common.exception.BizException;
import com.haccp.sys.company.dto.CompanyDeleteItem;
import com.haccp.sys.logs.auditlog.AuditWriter;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class CompanyServicePurgeTest {

    @Mock
    private CompanyMapper mapper;

    @Mock
    private AuditWriter auditWriter;

    @InjectMocks
    private CompanyService service;

    @AfterEach
    void clearUser() {
        LoginUserContext.clear();
    }

    private static CompanyDeleteItem item(String coCd) {
        CompanyDeleteItem key = new CompanyDeleteItem();
        key.setCoCd(coCd);
        return key;
    }

    private static void login(String coCd, String usrgrpCd) {
        LoginUserContext.set(LoginUser.builder()
                .coCd(coCd)
                .userId("admin")
                .usrgrpCd(usrgrpCd)
                .build());
    }

    @Test
    void 자사_ADMIN은_다른_회사를_못_지운다() {
        login("0001", "ADMIN");
        BizException ex = assertThrows(BizException.class, () -> service.validateDelete(List.of(item("0099"))));
        assertEquals("플랫폼 관리자만 업체를 삭제할 수 있습니다.", ex.getMessage());
        verify(mapper, never()).purgeCompany(any(), any());
    }

    @Test
    void 플랫폼_회사는_validateDelete에서_막는다() {
        login("0000", "ADMIN");
        BizException ex = assertThrows(BizException.class, () -> service.validateDelete(List.of(item("0000"))));
        assertEquals("플랫폼 회사는 삭제할 수 없습니다.", ex.getMessage());
        verify(mapper, never()).purgeCompany(any(), any());
    }

    @Test
    void 없는_회사는_validateDelete에서_막는다() {
        login("0000", "HACCP_MASTER");
        when(mapper.countCompany("0099")).thenReturn(0);
        BizException ex = assertThrows(BizException.class, () -> service.validateDelete(List.of(item("0099"))));
        assertEquals("업체를 찾을 수 없습니다.", ex.getMessage());
    }

    @Test
    void 플랫폼_ADMIN은_다른_회사를_지운다() {
        login("0000", "ADMIN");
        when(mapper.countCompany("0099")).thenReturn(1);
        service.delete(List.of(item("0099")));
        verify(mapper).purgeCompany("0099", "admin");
    }
}
