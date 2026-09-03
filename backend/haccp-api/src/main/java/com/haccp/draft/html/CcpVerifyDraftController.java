/**
 * CcpVerifyDraftController — CCP 검증점검 양식 작성 REST.
 *
 * 개발자: 박승우
 * 일자: 2026-09-03
 * 코멘트:
 *   1) 경로 /api/v1/draft/html/ccp-verify — FE SCREEN_PATH 와 같은 칸. 회사코드는 JWT 만
 *   2) 엔드포인트 6개는 일반위생·공정점검과 글자까지 같아 HtmlDraftControllerBase 로 옮겼다.
 *      여기 남는 것은 URL 과 양식군뿐이다
 *   3) 업무는 HtmlDraftService 가 갖는다
 *
 * 중분류 슬러그는 ccp-chk 다(docs 아래 ccp 와 tbl_menu menu_cd 가 겹칠 수 없다).
 * 자바 패키지는 com.haccp.draft.html 이다 — FE SCREEN_PATH /draft/html 과 같은 칸.
 * 전송·전송취소는 이 컨트롤러가 아니라 문서 허브 /api/v1/docs/documents/approval 을 쓴다.
 *
 * PIPELINE[HB138] CCP 검증점검 작성 Controller
 */
package com.haccp.draft.html;

// 역할 — 생성자 주입
import lombok.RequiredArgsConstructor;
// 역할 — REST 등록·경로
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/draft/html/ccp-verify")
@RequiredArgsConstructor
public class CcpVerifyDraftController extends HtmlDraftControllerBase {

    private final HtmlDraftService service;

    /** 이 화면이 다루는 양식군 — CCP 검증점검 */
    @Override
    protected HtmlDraftService.Family family() {
        return HtmlDraftService.Family.CHK;
    }

    @Override
    protected HtmlDraftService service() {
        return service;
    }
}
