/**
 * ScreenAuthInterceptorTest — write_yn=N 계정은 저장·삭제가 403.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
 * 코멘트:
 *   1) 대표 3화면(draft·sys·기준정보)에서 권한 N 이면 enforce 시 403 인지 고정한다
 *   2) ADMIN 은 권한 행이 비어도 통과한다 — 프론트 전권과 같게
 *   3) AuthMapper 만 목한다. DB·웹서버는 띄우지 않는다
 *
 * PIPELINE[HB145] 화면 권한 인터셉터
 */
package com.haccp.common.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

import com.haccp.auth.AuthMapper;
import com.haccp.auth.dto.ScreenAuthRow;
import com.haccp.common.context.LoginUser;
import com.haccp.common.context.LoginUserContext;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

@ExtendWith(MockitoExtension.class)
class ScreenAuthInterceptorTest {

    @Mock
    private AuthMapper authMapper;

    private ScreenAuthInterceptor interceptor;

    @BeforeEach
    void setUp() {
        interceptor = new ScreenAuthInterceptor(authMapper);
        interceptor.setEnforce(true);
    }

    @AfterEach
    void tearDown() {
        LoginUserContext.clear();
    }

    @Test
    void draft_저장_write_N_이면_403이다() throws Exception {
        loginUser("USER");
        when(authMapper.selectScreenAuths(anyString(), anyString()))
                .thenReturn(List.of(row("ccp-mtl", "N", "N")));
        MockHttpServletResponse res = new MockHttpServletResponse();
        boolean ok = interceptor.preHandle(
                request("PUT", "/api/v1/draft/ccp-monitoring/ccp-mtl/save"),
                res,
                new Object()
        );
        assertFalse(ok);
        assertEquals(403, res.getStatus());
    }

    @Test
    void sys_삭제_delete_N_이면_403이다() throws Exception {
        loginUser("USER");
        when(authMapper.selectScreenAuths(anyString(), anyString()))
                .thenReturn(List.of(row("user-management", "Y", "N")));
        MockHttpServletResponse res = new MockHttpServletResponse();
        boolean ok = interceptor.preHandle(
                request("POST", "/api/v1/sys/code/user-management/delete"),
                res,
                new Object()
        );
        assertFalse(ok);
        assertEquals(403, res.getStatus());
    }

    @Test
    void 사용양식_삭제_delete_N_이면_403이다() throws Exception {
        loginUser("USER");
        when(authMapper.selectScreenAuths(anyString(), anyString()))
                .thenReturn(List.of(row("hwp-template-management", "Y", "N")));
        MockHttpServletResponse res = new MockHttpServletResponse();
        boolean ok = interceptor.preHandle(
                request("POST", "/api/v1/docs/hwp/hwp-template-management/delete"),
                res,
                new Object()
        );
        assertFalse(ok);
        assertEquals(403, res.getStatus());
    }

    @Test
    void 맵에_없는_API는_USER가_403이다() throws Exception {
        loginUser("USER");
        MockHttpServletResponse res = new MockHttpServletResponse();
        boolean ok = interceptor.preHandle(
                request("POST", "/api/v1/unknown/secret/save"),
                res,
                new Object()
        );
        assertFalse(ok);
        assertEquals(403, res.getStatus());
    }

    @Test
    void 화이트리스트_auth는_맵이_없어도_통과한다() throws Exception {
        loginUser("USER");
        MockHttpServletResponse res = new MockHttpServletResponse();
        boolean ok = interceptor.preHandle(
                request("GET", "/api/v1/auth/me"),
                res,
                new Object()
        );
        assertTrue(ok);
        assertEquals(200, res.getStatus());
    }

    @Test
    void 맵에_없는_API는_ADMIN도_403이다() throws Exception {
        loginUser("ADMIN");
        MockHttpServletResponse res = new MockHttpServletResponse();
        boolean ok = interceptor.preHandle(
                request("POST", "/api/v1/unknown/secret/save"),
                res,
                new Object()
        );
        assertFalse(ok);
        assertEquals(403, res.getStatus());
    }

    @Test
    void ADMIN_은_권한행이_없어도_통과한다() throws Exception {
        loginUser("ADMIN");
        MockHttpServletResponse res = new MockHttpServletResponse();
        boolean ok = interceptor.preHandle(
                request("POST", "/api/v1/sys/code/user-management/delete"),
                res,
                new Object()
        );
        assertTrue(ok);
        assertEquals(200, res.getStatus());
    }

    private static void loginUser(String usrgrpCd) {
        LoginUserContext.set(LoginUser.builder()
                .coCd("C1")
                .userId("u1")
                .usrgrpCd(usrgrpCd)
                .build());
    }

    private static MockHttpServletRequest request(String method, String uri) {
        MockHttpServletRequest req = new MockHttpServletRequest(method, uri);
        req.setRequestURI(uri);
        return req;
    }

    private static ScreenAuthRow row(String scrnCd, String writeYn, String deleteYn) {
        ScreenAuthRow r = new ScreenAuthRow();
        r.setScrnCd(scrnCd);
        r.setReadYn("Y");
        r.setWriteYn(writeYn);
        r.setModifyYn("N");
        r.setDeleteYn(deleteYn);
        r.setPrintYn("N");
        return r;
    }
}
