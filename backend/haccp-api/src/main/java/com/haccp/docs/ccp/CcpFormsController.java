/**
 * CcpFormsController — CCP 금속검출·검증점검표 REST API.
 *
 * 개발자: 박승우
 * 일자: 2026-08-21
 * 코멘트:
 *   1) 화면 SCREEN_PATH 두 경로를 한 컨트롤러에서 받고 Service가 화면별 템플릿을 고정한다
 *   2) 목록·상세 GET, 저장 PUT, 삭제 검증·삭제 POST 규약을 동일하게 적용한다
 *   3) 삭제 본문은 항상 [{ docIdx }] 객체 배열이며 HTTP DELETE는 사용하지 않는다
 *
 * PIPELINE[HB90] CCP 추가 양식 Controller
 * PIPELINE[HB89, HF84] 연관 모듈
 */
package com.haccp.docs.ccp;

import com.haccp.common.exception.BizException;
import com.haccp.common.response.CommonResponse;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping({
        "/api/v1/docs/ccp/ccp-metal-monitor",
        "/api/v1/docs/ccp/ccp-verification-check"
})
@RequiredArgsConstructor
public class CcpFormsController {
    private final CcpFormsService service;

    @GetMapping("/list")
    public CommonResponse<List<Map<String, Object>>> list(
            HttpServletRequest request,
            @RequestParam(required = false) String fromDt,
            @RequestParam(required = false) String toDt,
            @RequestParam(required = false) String docNo,
            @RequestParam(required = false) String writer
    ) {
        return CommonResponse.ok(service.list(formOf(request), fromDt, toDt, docNo, writer));
    }

    @GetMapping("/detail")
    public CommonResponse<Map<String, Object>> detail(
            HttpServletRequest request,
            @RequestParam(required = false) Long docIdx
    ) {
        return CommonResponse.ok(service.detail(formOf(request), docIdx));
    }

    @PutMapping("/save")
    public CommonResponse<Map<String, Long>> save(
            HttpServletRequest request,
            @RequestBody Map<String, Object> body
    ) {
        return CommonResponse.ok(Map.of("docIdx", service.save(formOf(request), body)));
    }

    @PostMapping("/validate-delete")
    public CommonResponse<Void> validateDelete(
            HttpServletRequest request,
            @RequestBody List<Map<String, Long>> keys
    ) {
        service.validateDelete(formOf(request), keys);
        return CommonResponse.ok(null);
    }

    @PostMapping("/delete")
    public CommonResponse<Void> delete(
            HttpServletRequest request,
            @RequestBody List<Map<String, Long>> keys
    ) {
        service.delete(formOf(request), keys);
        return CommonResponse.ok(null);
    }

    /**
     * 개발자: 박승우
     * 일자: 2026-08-21
     * 코멘트:
     *   1) URL 마지막 화면코드를 Service 내부 키로 바꾼다
     *   2) 금속·검증 목록·저장·삭제에서 호출한다
     *   3) 허용 경로가 아니면 업무 오류
     */
    private static String formOf(
            // 현재 요청 — URI에 ccp-metal-monitor 또는 ccp-verification-check
            HttpServletRequest request
    ) {
        String uri = request.getRequestURI();
        if (uri.contains("ccp-metal-monitor")) return "metal-monitor";
        if (uri.contains("ccp-verification-check")) return "verification-check";
        throw new BizException("지원하지 않는 CCP 양식입니다.");
    }
}
