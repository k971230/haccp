/**
 * CcpPkgDraftController — CCP 포장(CCP-1B) 모니터링일지 작성 REST.
 *
 * 개발자: 박승우
 * 일자: 2026-09-07
 * 코멘트:
 *   1) 경로 /api/v1/draft/ccp-monitoring/ccp-pkg — FE SCREEN_PATH 와 같은 칸
 *   2) 엔드포인트 6개는 CcpLogDraftControllerBase
 *   3) 업무는 CcpPkgDraftService
 *
 * PIPELINE[HB141 CCP 포장 작성 Controller]
 */
package com.haccp.draft.ccpmonitoring;

// 역할 — 생성자 주입
import lombok.RequiredArgsConstructor;
// 역할 — REST 등록·경로
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/draft/ccp-monitoring/ccp-pkg")
@RequiredArgsConstructor
public class CcpPkgDraftController extends CcpLogDraftControllerBase {

    private final CcpPkgDraftService service;

    @Override
    protected CcpMonitorDraftFacade service() {
        return service;
    }
}
