/**
 * CcpHtgDraftController — CCP 가열(CCP-2B) 모니터링일지 작성 REST.
 *
 * 개발자: 박승우
 * 일자: 2026-08-26
 * 코멘트:
 *   1) 경로 /api/v1/draft/ccp-monitoring/ccp-htg — FE SCREEN_PATH 와 같은 칸. 회사코드는 JWT 만
 *   2) 엔드포인트 6개는 포장(PKG) 와 글자까지 같아 CcpLogDraftControllerBase 로 옮겼다.
 *      여기 남는 것은 URL 과 양식군뿐이다
 *   3) 업무는 CcpLogDraftService 가 갖는다
 *
 * PIPELINE[HB142 CCP 가열 작성 Controller]
 */
package com.haccp.draft.ccpmonitoring;

// 역할 — 생성자 주입
import lombok.RequiredArgsConstructor;
// 역할 — REST 등록·경로
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/draft/ccp-monitoring/ccp-htg")
@RequiredArgsConstructor
public class CcpHtgDraftController extends CcpLogDraftControllerBase {

    private final CcpLogDraftService service;

    /** 이 화면이 다루는 양식군 — 가열 */
    @Override
    protected CcpLogDraftService.Family family() {
        return CcpLogDraftService.Family.HTG;
    }

    @Override
    protected CcpLogDraftService service() {
        return service;
    }
}
