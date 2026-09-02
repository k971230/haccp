/**
 * ScreenAuthResolverTest — 경로 → 화면·권한 칸 정적 맵.
 *
 * 개발자: 박승우
 * 일자: 2026-09-01
 * 코멘트:
 *   1) draft·sys·기준정보 대표 3경로가 각각 삭제 권한으로 해석되는지 고정한다
 *   2) 화이트리스트와 문서 허브 우회 경로도 같이 본다 — 맵이 빠지면 403 테스트가 거짓 통과한다
 *   3) DB·Spring 없이 순수 함수만 실행한다
 *
 * PIPELINE[HB145] 화면 권한 인터셉터
 */
package com.haccp.common.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;

class ScreenAuthResolverTest {

    @Test
    void draft_ccp_mtl_삭제는_해당_화면_DELETE다() {
        ScreenAuthMatch m = ScreenAuthResolver.resolve(
                "POST",
                "/api/v1/draft/ccp-monitoring/ccp-mtl/delete"
        ).orElseThrow();
        assertFalse(m.hub());
        assertEquals("ccp-mtl", m.scrnCd());
        assertEquals(ScreenAuthAction.DELETE, m.action());
    }

    @Test
    void sys_사용자관리_삭제는_user_management_DELETE다() {
        ScreenAuthMatch m = ScreenAuthResolver.resolve(
                "POST",
                "/api/v1/sys/code/user-management/delete"
        ).orElseThrow();
        assertEquals("user-management", m.scrnCd());
        assertEquals(ScreenAuthAction.DELETE, m.action());
    }

    @Test
    void 사용양식_삭제는_hwp_template_management_DELETE다() {
        // 삭제도 형제 화면처럼 화면 자기 경로다. /bas 예외 맵은 2026-08-26 에 없앴다
        ScreenAuthMatch m = ScreenAuthResolver.resolve(
                "POST",
                "/api/v1/docs/hwp/hwp-template-management/delete"
        ).orElseThrow();
        assertEquals("hwp-template-management", m.scrnCd());
        assertEquals(ScreenAuthAction.DELETE, m.action());
    }

    @Test
    void 문서_허브_삭제는_hub_DELETE다() {
        ScreenAuthMatch m = ScreenAuthResolver.resolve(
                "POST",
                "/api/v1/docs/documents/delete"
        ).orElseThrow();
        assertTrue(m.hub());
        assertEquals(ScreenAuthMatch.HubKind.HWP, m.hubKind());
        assertEquals(ScreenAuthAction.DELETE, m.action());
    }

    @Test
    void 문서_허브_결재는_DOC_허브다() {
        ScreenAuthMatch m = ScreenAuthResolver.resolve(
                "PUT",
                "/api/v1/docs/documents/approval"
        ).orElseThrow();
        assertEquals(ScreenAuthMatch.HubKind.DOC, m.hubKind());
        assertEquals(ScreenAuthAction.MODIFY, m.action());
    }

    @Test
    void 본인_서명과_auth는_화이트리스트다() {
        assertTrue(ScreenAuthResolver.resolve("GET", "/api/v1/auth/me").isEmpty());
        assertTrue(ScreenAuthResolver.resolve("GET", "/api/v1/sys/users/me/sign").isEmpty());
        assertTrue(ScreenAuthResolver.resolve("POST", "/api/v1/sys/users/me/sign").isEmpty());
    }

    /*
     * 사용양식 목록은 공용 조회다. 여러 화면의 콤보가 쓴다.
     * 여기가 화면에 묶여 있어서 조회 전용(VIEWER)이 이탈·개선조치 화면에서 403 을 맞고
     * 양식 콤보가 비었다 — 정작 그 화면은 볼 권한이 있는데 남의 화면 권한에 걸렸다.
     */
    @Test
    void 사용양식_목록은_공용조회라_화면권한을_안본다() {
        assertTrue(
                ScreenAuthResolver.resolve("GET", "/api/v1/docs/templates/list").isEmpty(),
                "목록이 화면 권한에 묶이면 조회 전용 계정의 양식 콤보가 빈다"
        );
    }

    /*
     * GET 원본은 HWP 작성이 연다. 사용양식관리 권한이 없는 팀원도 양식을 열 수 있어야 한다.
     * 업로드 POST 만 사용양식관리에 남긴다.
     */
    @Test
    void 양식_원본_GET은_공용조회_업로드는_사용양식관리다() {
        assertTrue(
                ScreenAuthResolver.resolve("GET", "/api/v1/docs/templates/hwp_sys_001/form").isEmpty(),
                "원본 GET 이 사용양식관리에 묶이면 HWP 작성 팀원이 403 이다"
        );

        ScreenAuthMatch write = ScreenAuthResolver.resolve(
                "POST",
                "/api/v1/docs/templates/hwp_usr_001/form"
        ).orElseThrow();
        assertEquals("hwp-template-management", write.scrnCd());
    }

    @Test
    void 자사_서명_GET은_공용조회_업로드삭제는_사용자관리다() {
        assertTrue(
                ScreenAuthResolver.resolve("GET", "/api/v1/sys/users/rmausr/sign").isEmpty(),
                "지면 도장이 사용자관리 권한을 요구하면 작성 화면이 403 이다"
        );
        ScreenAuthMatch upload = ScreenAuthResolver.resolve(
                "POST",
                "/api/v1/sys/users/other/sign"
        ).orElseThrow();
        assertEquals("user-management", upload.scrnCd());
        ScreenAuthMatch del = ScreenAuthResolver.resolve(
                "POST",
                "/api/v1/sys/users/other/sign/delete"
        ).orElseThrow();
        assertEquals("user-management", del.scrnCd());
        assertEquals(ScreenAuthAction.DELETE, del.action());
    }

    @Test
    void 사용자_결재선_목록_GET은_공용조회다() {
        assertTrue(ScreenAuthResolver.resolve("GET", "/api/v1/sys/code/user-management/list").isEmpty());
        assertTrue(ScreenAuthResolver.resolve(
                "GET",
                "/api/v1/sys/code/approval-line-management/list"
        ).isEmpty());
        ScreenAuthMatch save = ScreenAuthResolver.resolve(
                "PUT",
                "/api/v1/sys/code/user-management/save"
        ).orElseThrow();
        assertEquals("user-management", save.scrnCd());
    }

    @Test
    void 화면_API는_URL_화면코드를_붙이고_헤더는_무시한다() {
        MockHttpServletRequest req = new MockHttpServletRequest("PUT", "/api/v1/sys/code/user-management/save");
        req.setRequestURI("/api/v1/sys/code/user-management/save");
        req.addHeader(ScreenAuthResolver.SCRN_HEADER, "sign-ready");
        ScreenAuthResolver.bindRequestScreen(
                req,
                ScreenAuthResolver.resolve("PUT", "/api/v1/sys/code/user-management/save")
        );
        assertEquals("user-management", ScreenAuthResolver.requestScreen(req));
    }

    @Test
    void 문서_허브는_허용_화면_헤더만_붙인다() {
        MockHttpServletRequest ok = new MockHttpServletRequest("PUT", "/api/v1/docs/documents/approval");
        ok.setRequestURI("/api/v1/docs/documents/approval");
        ok.addHeader(ScreenAuthResolver.SCRN_HEADER, "sign-ready");
        ScreenAuthResolver.bindRequestScreen(
                ok,
                ScreenAuthResolver.resolve("PUT", "/api/v1/docs/documents/approval")
        );
        assertEquals("sign-ready", ScreenAuthResolver.requestScreen(ok));

        MockHttpServletRequest bad = new MockHttpServletRequest("PUT", "/api/v1/docs/documents/approval");
        bad.setRequestURI("/api/v1/docs/documents/approval");
        bad.addHeader(ScreenAuthResolver.SCRN_HEADER, "common-code-management");
        ScreenAuthResolver.bindRequestScreen(
                bad,
                ScreenAuthResolver.resolve("PUT", "/api/v1/docs/documents/approval")
        );
        assertEquals("", ScreenAuthResolver.requestScreen(bad));
    }
}
