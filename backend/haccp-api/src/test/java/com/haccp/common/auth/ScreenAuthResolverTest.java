/**
 * ScreenAuthResolverTest — 경로 → 화면·권한 칸 정적 맵.
 *
 * 개발자: 박승우
 * 일자: 2026-08-25
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

    @Test
    void 타인_서명은_사용자관리_화면이다() {
        ScreenAuthMatch m = ScreenAuthResolver.resolve(
                "POST",
                "/api/v1/sys/users/other/sign/delete"
        ).orElseThrow();
        assertEquals("user-management", m.scrnCd());
        assertEquals(ScreenAuthAction.DELETE, m.action());
    }
}
